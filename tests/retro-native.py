"""Check native launch translation without running emulators or game content."""

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("retro_native", sys.argv.pop(1))
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


class NativeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name) / "My Stuff"
        self.base.mkdir()

    def test_vita_marker_uses_contents_not_filename_and_preserves_source(self):
        path = self.base / "Display Name.PSVITA"
        path.write_text("PCSF00007\n")
        self.assertEqual(native.command("vita", "/fake/vita3k", path),
                         ["/fake/vita3k", "--fullscreen", "-r", "PCSF00007"])
        self.assertEqual(path.read_text(), "PCSF00007\n")

    def test_vita_rejects_archives_options_and_multiple_ids(self):
        path = self.base / "Game.psvita"
        for value in ("", "--install", "ID;touch /tmp/never", "PCSF00007\nPCSF00008", "X" * 129):
            path.write_text(value)
            with self.assertRaises(ValueError):
                native.command("vita", "/fake/vita3k", path)
        path = self.base / "Game.vpk"
        path.write_bytes(b"inert archive")
        with self.assertRaises(ValueError):
            native.command("vita", "/fake/vita3k", path)

    def test_ps4_folder_alias_launches_eboot_with_spaced_path(self):
        game = self.base / "Original Game Name"
        (game / "sce_sys").mkdir(parents=True)
        (game / "sce_sys/param.sfo").write_bytes(b"inert metadata")
        (game / "eboot.bin").write_bytes(b"inert binary")
        alias = self.base / "Frontend Name.ps4dir"
        alias.symlink_to(game, target_is_directory=True)
        self.assertEqual(native.command("ps4", "/fake/shadps4", alias),
                         ["/fake/shadps4", "--fullscreen", "true", "--game", str(game / "eboot.bin")])
        self.assertEqual((game / "eboot.bin").read_bytes(), b"inert binary")

    def test_ps4_incomplete_folder_and_installation_package_are_refused(self):
        game = self.base / "Incomplete"
        game.mkdir()
        (game / "eboot.bin").write_bytes(b"inert")
        with self.assertRaises(ValueError):
            native.command("ps4", "/fake/shadps4", game)
        package = self.base / "Install.pkg"
        package.write_bytes(b"inert")
        with self.assertRaises(ValueError):
            native.command("ps4", "/fake/shadps4", package)


if __name__ == "__main__":
    unittest.main()
