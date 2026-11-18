"""Exercise library preservation and runtime settings without touching user data."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

SOURCE = Path(sys.argv.pop(1)).resolve()


class LibraryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.env = os.environ | {
            "HOME": str(self.base),
            "XDG_CONFIG_HOME": str(self.base / "config"),
            "XDG_DATA_HOME": str(self.base / "data"),
        }
        self.root = self.base / "My Stuff/EMU/ROMS"
        for name in ("GC", "N64", "FDS", "GBA"):
            (self.root / name).mkdir(parents=True)
        self.original = self.root / "GBA/Example Game.gba"
        self.original.write_bytes(b"test fixture, not a ROM")
        self.view = self.base / "data/hon-retro/roms"

    def run_cli(self, *args, success=True):
        result = subprocess.run(
            [sys.executable, str(SOURCE), *map(str, args)],
            env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_root_with_spaces_and_case_aliases(self):
        self.run_cli("set-root", self.root)
        self.assertEqual((self.view / "gba").resolve(), self.root / "GBA")
        self.assertEqual((self.view / "gc").resolve(), self.root / "GC")
        self.assertEqual(self.original.read_bytes(), b"test fixture, not a ROM")
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), ["FDS", "GBA", "GC", "N64"])

    def test_settings_and_metadata_survive_repeated_preparation(self):
        self.run_cli("set-root", self.root)
        self.run_cli("prepare")
        settings = self.base / "data/hon-retro/frontend/settings/es_settings.xml"
        tree = ET.parse(settings)
        self.assertEqual(tree.getroot().tag, "settings")
        self.assertEqual(tree.find("string[@name='ROMDirectory']").get("value"), str(self.view))
        settings.write_text("user settings must survive\n")
        save = self.base / "data/hon-retro/saves/example.srm"
        save.parent.mkdir()
        save.write_bytes(b"save data")
        self.run_cli("prepare")
        self.assertEqual(settings.read_text(), "user settings must survive\n")
        self.assertEqual(save.read_bytes(), b"save data")

    def test_unavailable_root_preserves_view(self):
        self.run_cli("set-root", self.root)
        self.root.rename(self.root.with_name("disconnected"))
        self.run_cli("refresh", success=False)
        self.assertTrue((self.view / "gba").is_symlink())

    def test_foreign_entry_aborts_without_partial_changes(self):
        self.view.mkdir(parents=True)
        (self.view / "gba").mkdir()
        self.run_cli("set-root", self.root, success=False)
        self.assertFalse((self.view / "fds").exists())
        self.assertTrue((self.view / "gba").is_dir())
        self.assertFalse((self.base / "config/hon-retro/library.json").exists())

    def test_ambiguous_aliases_require_explicit_mapping(self):
        (self.root / "gba").mkdir()
        self.run_cli("set-root", self.root, success=False)
        self.run_cli("map", "gba", self.root / "GBA")
        self.run_cli("set-root", self.root)
        self.assertEqual((self.view / "gba").resolve(), self.root / "GBA")

    def test_foreign_symlink_is_preserved(self):
        self.view.mkdir(parents=True)
        other = self.base / "other"
        other.mkdir()
        (self.view / "gba").symlink_to(other)
        self.run_cli("set-root", self.root, success=False)
        self.assertEqual((self.view / "gba").resolve(), other)

    def test_recursive_mapping_rejected(self):
        self.view.mkdir(parents=True)
        self.run_cli("map", "gba", self.view, success=False)

    def test_invalid_settings_fail_without_replacing_them(self):
        config = self.base / "config/hon-retro/library.json"
        config.parent.mkdir(parents=True)
        config.write_text("broken json")
        self.run_cli("prepare", success=False)
        self.assertEqual(config.read_text(), "broken json")


unittest.main()
