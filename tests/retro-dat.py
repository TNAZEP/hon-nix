"""Verify DAT/ZIP reports with generated payloads and no extraction or source writes."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
import zlib

SOURCE = Path(sys.argv.pop(1)).resolve()


class DatTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / "My Stuff/ROMS"
        self.root.mkdir(parents=True)
        self.payload = b"inert ROM verification fixture"
        self.dat = self.base / "user-supplied.dat"
        self.make_dat()

    def make_dat(self, **overrides):
        tree = ET.Element("datafile")
        header = ET.SubElement(tree, "header")
        ET.SubElement(header, "name").text = "Synthetic DAT"
        ET.SubElement(header, "version").text = "fixture-1"
        game = ET.SubElement(tree, "game", name="Fixture Game")
        attrs = {"name": "Expected.bin", "size": str(len(self.payload)),
                 "crc": f"{zlib.crc32(self.payload):08x}",
                 "md5": hashlib.md5(self.payload).hexdigest(),
                 "sha1": hashlib.sha1(self.payload).hexdigest()}
        ET.SubElement(game, "rom", attrs | overrides)
        ET.SubElement(game, "rom", name="Undumped.bin", status="nodump", size="0")
        ET.ElementTree(tree).write(self.dat, encoding="utf-8", xml_declaration=True)

    def run_cli(self, *args, expected=0):
        result = subprocess.run([sys.executable, "-B", str(SOURCE), str(self.root),
                                 "--dat", str(self.dat), *map(str, args)],
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return json.loads(result.stdout) if result.stdout else None

    def test_matching_bytes_with_different_name_and_provenance(self):
        source = self.root / "Preserve My Name.bin"
        source.write_bytes(self.payload)
        before = source.stat()
        report = self.run_cli()
        self.assertEqual(report["dat"]["missing"], [])
        self.assertEqual(report["dat"]["unrecognized"], [])
        self.assertEqual(report["dat"]["matched"][0]["matches"], [{"path": source.name}])
        self.assertEqual(report["dat"]["sha256"], hashlib.sha256(self.dat.read_bytes()).hexdigest())
        self.assertEqual(report["dat"]["version"], "fixture-1")
        self.assertEqual(report["dat"]["ignored"][0]["reason"], "nodump")
        self.assertEqual(source.read_bytes(), self.payload)
        self.assertEqual(source.stat().st_mtime_ns, before.st_mtime_ns)

    def test_matching_name_with_wrong_bytes_is_not_accepted(self):
        (self.root / "Expected.bin").write_bytes(b"x" * len(self.payload))
        report = self.run_cli(expected=1)
        self.assertEqual(len(report["dat"]["missing"]), 1)
        self.assertEqual(len(report["dat"]["unrecognized"]), 1)
        self.assertEqual(report["dat"]["matched"], [])

    def test_all_declared_checksums_must_match(self):
        (self.root / "renamed.bin").write_bytes(self.payload)
        self.make_dat(crc="00000000")
        self.assertEqual(self.run_cli(expected=1)["dat"]["matched"], [])

    def test_zip_members_match_across_compression_without_extraction(self):
        originals = {}
        for name, compression in (("stored.zip", zipfile.ZIP_STORED), ("compressed.zip", zipfile.ZIP_DEFLATED)):
            path = self.root / name
            with zipfile.ZipFile(path, "w", compression=compression) as archive:
                archive.writestr("../../never-extract.bin", self.payload)
            originals[name] = path.read_bytes()
        report = self.run_cli("--zip-members")
        self.assertEqual(len(report["dat"]["matched"][0]["matches"]), 2)
        self.assertFalse((self.base / "never-extract.bin").exists())
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), sorted(originals))
        for name, content in originals.items():
            self.assertEqual((self.root / name).read_bytes(), content)

    def test_zip_members_are_opt_in(self):
        with zipfile.ZipFile(self.root / "game.zip", "w") as archive:
            archive.writestr("Expected.bin", self.payload)
        self.assertEqual(len(self.run_cli(expected=1)["dat"]["missing"]), 1)

    def test_member_limit_and_archive_symlink_are_reported(self):
        with zipfile.ZipFile(self.root / "game.zip", "w") as archive:
            archive.writestr("Expected.bin", self.payload)
            link = zipfile.ZipInfo("link.bin")
            link.create_system = 3
            link.external_attr = 0o120777 << 16
            archive.writestr(link, "Expected.bin")
        report = self.run_cli("--zip-members", "--max-member-bytes", "1", expected=1)
        self.assertEqual({item["reason"] for item in report["dat"]["skipped"]},
                         {"member byte limit", "archive symlink"})
        self.assertEqual(report["dat"]["matched"], [])

    def test_corrupt_zip_and_bad_crc_are_incomplete(self):
        source = self.root / "game.zip"
        source.write_bytes(b"not a ZIP")
        self.assertEqual(len(self.run_cli("--zip-members", expected=1)["errors"]), 1)
        with zipfile.ZipFile(source, "w") as archive:
            archive.writestr("Expected.bin", self.payload)
        source.write_bytes(source.read_bytes().replace(self.payload, b"x" * len(self.payload)))
        report = self.run_cli("--zip-members", expected=1)
        self.assertEqual(len(report["errors"]), 1)
        self.assertEqual(report["dat"]["matched"], [])

    def test_internal_entities_refused_external_doctype_not_resolved(self):
        original = self.dat.read_text()
        self.dat.write_text('<!DOCTYPE datafile [<!ENTITY x "unsafe">]>' + original)
        self.run_cli(expected=2)
        self.dat.write_text('<!DOCTYPE datafile SYSTEM "file:///does-not-exist.dtd">' +
                            original[original.index("<datafile"):])
        (self.root / "Game.bin").write_bytes(self.payload)
        self.run_cli()

    def test_invalid_dat_preserves_existing_report(self):
        output = self.base / "report.json"
        output.write_text("manual report")
        self.dat.write_text("broken XML")
        self.run_cli("--output", output, expected=2)
        self.assertEqual(output.read_text(), "manual report")
        self.run_cli(expected=2)

    def test_unverifiable_entries_and_dump_status_are_visible(self):
        (self.root / "Game.bin").write_bytes(self.payload)
        self.make_dat(status="baddump", merge="parent.bin")
        tree = ET.parse(self.dat)
        ET.SubElement(tree.find("game"), "rom", name="NoChecksum.bin", size="1")
        tree.write(self.dat, encoding="utf-8", xml_declaration=True)
        report = self.run_cli(expected=1)
        self.assertEqual(report["dat"]["matched"][0]["status"], "baddump")
        self.assertEqual(report["dat"]["matched"][0]["merge"], "parent.bin")
        self.assertIn("no checksum", [entry["reason"] for entry in report["dat"]["ignored"]])

    def test_fifo_dat_and_invalid_member_limit_fail_without_blocking(self):
        self.dat.unlink()
        os.mkfifo(self.dat)
        self.run_cli(expected=2)
        self.dat.unlink()
        self.make_dat()
        self.run_cli("--max-member-bytes", "0", expected=2)


if __name__ == "__main__":
    unittest.main()
