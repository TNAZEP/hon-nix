"""Exercise report-only auditing with synthetic data, links and changing files."""

import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(sys.argv.pop(1)).resolve()
spec = importlib.util.spec_from_file_location("retro_audit", SOURCE)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AuditTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / "My Stuff/ROMS"
        self.root.mkdir(parents=True)

    def run_cli(self, *args, expected=0):
        result = subprocess.run([sys.executable, "-B", str(SOURCE), str(self.root), *map(str, args)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def test_exact_bytes_not_names_or_equal_sizes(self):
        files = {"Game (USA).bin": b"same data", "Game (Japan).bin": b"same data",
                 "Other.bin": b"different", "Unique.bin": b"unique size"}
        for name, data in files.items():
            (self.root / name).write_bytes(data)
        before = {p.name: p.stat() for p in self.root.iterdir()}
        report = json.loads(self.run_cli().stdout)
        self.assertEqual(report["files_scanned"], 4)
        self.assertEqual(report["files_hashed"], 3)
        self.assertEqual(len(report["duplicates"]), 1)
        self.assertEqual(report["duplicates"][0]["files"], ["Game (Japan).bin", "Game (USA).bin"])
        self.assertEqual(report["duplicates"][0]["distinct_inodes"], 2)
        for name, data in files.items():
            path = self.root / name
            self.assertEqual(path.read_bytes(), data)
            self.assertEqual(audit.identity(path.stat()), audit.identity(before[name]))

    def test_links_loops_and_special_files_are_skipped(self):
        (self.root / "first.bin").write_bytes(b"same")
        os.link(self.root / "first.bin", self.root / "hardlink.bin")
        (self.root / "loop").symlink_to(self.root, target_is_directory=True)
        (self.root / "outside").symlink_to(self.base, target_is_directory=True)
        (self.root / "missing").symlink_to(self.base / "missing")
        os.mkfifo(self.root / "pipe")
        report = json.loads(self.run_cli().stdout)
        self.assertEqual(report["files_scanned"], 2)
        self.assertEqual(report["duplicates"][0]["distinct_inodes"], 1)
        self.assertEqual(len(report["skipped"]), 4)

    def test_new_private_report_and_existing_report_preserved(self):
        output = self.base / "report.json"
        self.run_cli("--output", output)
        original = output.read_bytes()
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)
        self.run_cli("--output", output, expected=2)
        self.assertEqual(output.read_bytes(), original)

    def test_report_cannot_be_inside_library_or_link_to_it(self):
        self.run_cli("--output", self.root / "report.json", expected=2)
        alias = self.base / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        self.run_cli("--output", alias / "report.json", expected=2)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_existing_output_symlink_is_preserved(self):
        source = self.root / "game.bin"
        source.write_bytes(b"unchanged")
        output = self.base / "report.json"
        output.symlink_to(source)
        self.run_cli("--output", output, expected=2)
        self.assertEqual(source.read_bytes(), b"unchanged")
        self.assertTrue(output.is_symlink())

    def test_changed_file_and_nested_directory_link_are_refused(self):
        directory = self.root / "nested"
        directory.mkdir()
        source = directory / "game.bin"
        source.write_bytes(b"before")
        expected = source.stat()
        source.write_bytes(b"after")
        with self.assertRaises(ValueError):
            audit.digest(self.root, source, expected)
        directory.rename(self.root / "moved")
        directory.symlink_to(self.root / "moved", target_is_directory=True)
        with self.assertRaises(OSError):
            audit.digest(self.root, source, source.stat())

    def test_hash_failure_marks_report_incomplete(self):
        for name in ("one", "two"):
            (self.root / name).write_bytes(b"same")
        with patch.object(audit, "digest", side_effect=ValueError("File changed while hashing")):
            report = audit.audit(self.root)
        self.assertEqual(len(report["errors"]), 2)
        self.assertEqual(report["duplicates"], [])

    def test_incomplete_audit_returns_failure_with_report(self):
        for name in ("one", "two"):
            (self.root / name).write_bytes(b"same")
        output = io.StringIO()
        with patch.object(sys, "argv", [str(SOURCE), str(self.root)]), \
             patch.object(audit, "digest", side_effect=OSError("unreadable")), \
             contextlib.redirect_stdout(output):
            self.assertEqual(audit.main(), 1)
        self.assertEqual(len(json.loads(output.getvalue())["errors"]), 2)

    def test_file_modified_during_hashing_is_refused(self):
        source = self.root / "game.bin"
        source.write_bytes(b"before")
        expected = source.stat()
        real_fstat = os.fstat
        calls = 0

        def changing_fstat(descriptor):
            nonlocal calls
            calls += 1
            if calls == 2:
                source.write_bytes(b"different")
            return real_fstat(descriptor)

        with patch.object(audit.os, "fstat", side_effect=changing_fstat):
            with self.assertRaisesRegex(ValueError, "while hashing"):
                audit.digest(self.root, source, expected)

    def test_missing_root_fails_without_report(self):
        self.root.rmdir()
        output = self.base / "report.json"
        self.run_cli("--output", output, expected=2)
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
