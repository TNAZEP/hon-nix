"""Report byte-identical files without modifying a source library."""

import argparse
from collections import defaultdict
import hashlib
import json
import lzma
import os
from pathlib import Path
import re
import stat
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib


def identity(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def open_source(root, path, flags):
    """Open beneath the chosen root without following nested directory links."""
    descriptor = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        parts = path.relative_to(root).parts
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        if parts:
            return os.open(parts[-1], flags | os.O_NOFOLLOW, dir_fd=descriptor)
        result = descriptor
        descriptor = -1
        return result
    finally:
        if descriptor != -1:
            os.close(descriptor)


def stream_sums(stream, limit=None, algorithms=("md5", "sha1", "sha256")):
    checksums = {name: hashlib.new(name, usedforsecurity=False)
                 for name in algorithms}
    count = crc = 0
    while block := stream.read(1024 * 1024):
        count += len(block)
        if limit is not None and count > limit:
            raise ValueError("ZIP member exceeds the configured byte limit")
        crc = zlib.crc32(block, crc)
        for checksum in checksums.values():
            checksum.update(block)
    return {"size": count, "crc": f"{crc:08x}"} | {
        name: checksum.hexdigest() for name, checksum in checksums.items()}


def file_sums(root, path, expected, algorithms=("md5", "sha1", "sha256")):
    # Refuse a file replaced with a link/FIFO between discovery and opening.
    descriptor = open_source(root, path, os.O_RDONLY | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or identity(before) != identity(expected):
            raise ValueError("File changed before hashing")
        sums = stream_sums(stream, algorithms=algorithms)
        after = os.fstat(stream.fileno())
        if identity(before) != identity(after) or sums["size"] != before.st_size:
            raise ValueError("File changed while hashing")
    return sums


def digest(root, path, expected):
    return file_sums(root, path, expected, ("sha256",))["sha256"]


def load_dat(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError("DAT must be a regular file")
        data = stream.read(64 * 1024 * 1024 + 1)
    if len(data) > 64 * 1024 * 1024:
        raise ValueError("DAT exceeds the 64 MiB limit")
    # UTF-8 Logiqx XML, with external DOCTYPE declarations allowed but never
    # resolved. Reject internal DTDs/entities before giving XML to the parser.
    source = data.decode("utf-8-sig")
    if re.search(r"<!\s*ENTITY|<!DOCTYPE[^>]*\[", source, re.I):
        raise ValueError("DAT internal DTD/entity declarations are not supported")
    tree = ET.fromstring(source)
    if tree.tag != "datafile":
        raise ValueError("Expected a Logiqx XML datafile DAT")
    entries, ignored = [], []
    for game in tree:
        if game.tag not in ("game", "machine"):
            continue
        for rom in game.findall("rom"):
            label = {"game": game.get("name", ""), "rom": rom.get("name", "")}
            if not all(label.values()):
                raise ValueError("DAT game/ROM names are required")
            if rom.get("status") == "nodump":
                ignored.append(label | {"reason": "nodump"})
                continue
            size = int(rom.attrib["size"])
            hashes = {key: rom.get(key).lower() for key in ("crc", "md5", "sha1", "sha256")
                      if rom.get(key)}
            if size < 0 or any(not re.fullmatch(rf"[0-9a-f]{{{length}}}", hashes[key])
                              for key, length in (("crc", 8), ("md5", 32), ("sha1", 40), ("sha256", 64))
                              if key in hashes):
                raise ValueError("Invalid DAT size/checksum")
            if not hashes:
                ignored.append(label | {"reason": "no checksum"})
                continue
            entries.append(label | {"size": size, "hashes": hashes,
                                    "status": rom.get("status", "good"), "merge": rom.get("merge")})
    if not entries:
        raise ValueError("DAT has no verifiable ROM entries")
    return {"path": str(path), "sha256": hashlib.sha256(data).hexdigest(),
            "name": tree.findtext("header/name"), "version": tree.findtext("header/version"),
            "entries": entries, "ignored": ignored}


def verify_dat(root, sizes, dat, zip_members, member_limit, errors):
    entries = dat["entries"]
    by_size = defaultdict(list)
    for index, entry in enumerate(entries):
        by_size[entry["size"]].append(index)
    matches = defaultdict(list)
    unknown, skipped = [], []

    def compare(location, sums):
        found = [index for index in by_size.get(sums["size"], [])
                 if all(sums.get(key) == value for key, value in entries[index]["hashes"].items())]
        for index in found:
            matches[index].append(location)
        if not found:
            unknown.append(location | {"size": sums["size"]})

    for size in sorted(sizes):
        for path, expected in sizes[size]:
            location = {"path": str(path.relative_to(root))}
            try:
                if zip_members and path.suffix.lower() == ".zip":
                    records = []
                    descriptor = open_source(root, path, os.O_RDONLY | os.O_NONBLOCK)
                    with os.fdopen(descriptor, "rb") as stream:
                        before = os.fstat(stream.fileno())
                        if not stat.S_ISREG(before.st_mode) or identity(before) != identity(expected):
                            raise ValueError("Archive changed before verification")
                        with zipfile.ZipFile(stream) as archive:
                            for member in archive.infolist():
                                item = location | {"member": member.filename, "header_offset": member.header_offset}
                                if member.is_dir():
                                    continue
                                if stat.S_ISLNK(member.external_attr >> 16):
                                    skipped.append(item | {"reason": "archive symlink"})
                                elif member.file_size > member_limit:
                                    skipped.append(item | {"reason": "member byte limit"})
                                elif member.file_size not in by_size:
                                    records.append((item, {"size": member.file_size}))
                                else:
                                    with archive.open(member) as content:
                                        sums = stream_sums(content, member_limit)
                                    if sums["size"] != member.file_size:
                                        raise ValueError("ZIP member size mismatch")
                                    records.append((item, sums))
                        if identity(before) != identity(os.fstat(stream.fileno())):
                            raise ValueError("Archive changed during verification")
                    for item, sums in records:
                        compare(item, sums)
                else:
                    sums = file_sums(root, path, expected) if size in by_size else {"size": size}
                    compare(location, sums)
            except (OSError, ValueError, RuntimeError, NotImplementedError, zipfile.BadZipFile,
                    zlib.error, lzma.LZMAError, EOFError) as error:
                errors.append(location | {"error": str(error)})
    return {key: value for key, value in dat.items() if key != "entries"} | {
        "scope": "ROM size/checksums only; no parent/CHD dependencies or emulator compatibility claim",
        "zip_members": zip_members, "max_member_bytes": member_limit,
        "matched": [entry | {"matches": matches[index]} for index, entry in enumerate(entries) if index in matches],
        "missing": [entry for index, entry in enumerate(entries) if index not in matches],
        "unrecognized": unknown, "skipped": skipped,
    }


def audit(root, dat=None, zip_members=False, member_limit=512 * 1024 * 1024):
    sizes = defaultdict(list)
    skipped = []
    errors = []
    pending = [root]

    def walk(directory):
        try:
            descriptor = open_source(root, directory, os.O_RDONLY | os.O_DIRECTORY)
        except OSError as error:
            errors.append({"path": str(directory.relative_to(root)), "error": str(error)})
            return
        try:
            with os.scandir(descriptor) as entries:
                children = sorted(entries, key=lambda entry: entry.name)
            for entry in children:
                path = directory / entry.name
                relative = str(path.relative_to(root))
                try:
                    info = entry.stat(follow_symlinks=False)
                    if stat.S_ISLNK(info.st_mode):
                        skipped.append({"path": relative, "reason": "symlink"})
                    elif stat.S_ISDIR(info.st_mode):
                        pending.append(path)
                    elif stat.S_ISREG(info.st_mode):
                        sizes[info.st_size].append((path, info))
                    else:
                        skipped.append({"path": relative, "reason": "not a regular file"})
                except OSError as error:
                    errors.append({"path": relative, "error": str(error)})
        except OSError as error:
            errors.append({"path": str(directory.relative_to(root)), "error": str(error)})
        finally:
            os.close(descriptor)

    while pending:
        walk(pending.pop())
    hashes = defaultdict(list)
    hashed = 0
    for size in sorted(sizes):
        candidates = sizes[size]
        # A unique byte count cannot have an exact duplicate in this inventory.
        if len(candidates) < 2:
            continue
        for path, info in candidates:
            try:
                checksum = digest(root, path, info)
                hashed += 1
                hashes[(size, checksum)].append((str(path.relative_to(root)), info))
            except (OSError, ValueError) as error:
                errors.append({"path": str(path.relative_to(root)), "error": str(error)})
    duplicates = []
    for (size, checksum), files in sorted(hashes.items()):
        if len(files) > 1:
            duplicates.append({
                "size": size, "sha256": checksum,
                "files": sorted(name for name, _ in files),
                "distinct_inodes": len({(info.st_dev, info.st_ino) for _, info in files}),
            })
    report = {
        "schema": 1, "root": str(root), "algorithm": "sha256",
        "scope": "whole-file bytes; archives are not unpacked; no DAT verification",
        "files_scanned": sum(map(len, sizes.values())), "files_hashed": hashed,
        "duplicates": duplicates, "skipped": skipped, "errors": errors,
    }
    if dat is not None:
        report["dat"] = verify_dat(root, sizes, dat, zip_members, member_limit, errors)
        report["scope"] = "whole-file duplicate detection plus supplied DAT verification"
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="Source library to inspect recursively")
    parser.add_argument("--output", type=Path, help="New JSON report outside the library; default stdout")
    parser.add_argument("--dat", type=Path, help="User-supplied UTF-8 Logiqx XML DAT; no downloads")
    parser.add_argument("--zip-members", action="store_true", help="Verify ZIP members against --dat, without extraction")
    parser.add_argument("--max-member-bytes", type=int, default=512 * 1024 * 1024,
                        help="Maximum decompressed bytes per ZIP member (default 512 MiB)")
    args = parser.parse_args()
    try:
        root = args.root.expanduser().resolve(strict=True)
        if not root.is_dir():
            raise ValueError("Audit root must be a directory")
        output = None
        if args.output is not None:
            # Resolve only the parent; refuse both existing files and symlinks.
            output = args.output.expanduser()
            output = output.parent.resolve(strict=True) / output.name
            if output.is_relative_to(root):
                raise ValueError("Report must be outside the source library")
            if os.path.lexists(output):
                raise ValueError("Report already exists; choose a new filename")
        if args.zip_members and args.dat is None:
            raise ValueError("--zip-members requires --dat")
        if args.max_member_bytes <= 0:
            raise ValueError("Member byte limit must be positive")
        dat = load_dat(args.dat.expanduser().resolve(strict=True)) if args.dat else None
        report = audit(root, dat, args.zip_members, args.max_member_bytes)
        rendered = json.dumps(report, indent=2) + "\n"
        if output is None:
            sys.stdout.write(rendered)
        else:
            # Exclusive creation also protects against races after validation.
            descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "w") as stream:
                stream.write(rendered)
        mismatch = report.get("dat", {})
        return 1 if (report["errors"] or mismatch.get("missing")
                     or mismatch.get("unrecognized") or mismatch.get("skipped")
                     or any(entry["reason"] == "no checksum" for entry in mismatch.get("ignored", []))) else 0
    except (OSError, ValueError, KeyError, ET.ParseError) as error:
        print(f"retro-audit: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
