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

    def test_additional_platform_aliases_preserve_original_folders(self):
        folders = {"wii": "Wii", "ps2": "PS2", "xbox": "Xbox", "nds": "DS",
                   "psp": "PSP", "ps3": "PS3", "xbox360": "Xbox 360",
                   "wiiu": "Wii U", "n3ds": "3DS"}
        for folder in folders.values():
            (self.root / folder).mkdir()
        before = sorted(p.name for p in self.root.iterdir())
        self.run_cli("set-root", self.root)
        for system, folder in folders.items():
            target = self.base / "data/hon-retro/ps3" if system == "ps3" else self.root / folder
            self.assertEqual((self.view / system).resolve(), target)
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), before)

    def test_classic_platforms_preserve_disc_tracks_and_playlists(self):
        folders = {"nes": "Famicom", "snes": "Super Famicom", "gb": "Game Boy",
                   "gbc": "Game Boy Color", "mastersystem": "SMS", "megadrive": "Genesis",
                   "gamegear": "Game Gear", "segacd": "Mega CD", "sega32x": "32X",
                   "psx": "PS1", "saturn": "Saturn", "dreamcast": "DC",
                   "pcengine": "PCE", "pcenginecd": "PC Engine CD", "supergrafx": "SGX",
                   "neogeo": "Neo Geo", "neogeocd": "Neo Geo CD", "arcade": "FBNeo",
                   "atari2600": "Atari 2600", "atari7800": "Atari 7800",
                   "atarilynx": "Lynx", "ngp": "NGP", "ngpc": "NGPC",
                   "wonderswan": "WS", "wonderswancolor": "WSC"}
        for folder in folders.values():
            (self.root / folder).mkdir()
        disc = self.root / "Mega CD/Disc Game"
        disc.mkdir()
        originals = {disc / "Track 01.bin": b"inert track fixture",
                     disc / "Disc One.cue": b'FILE "Track 01.bin" BINARY\n',
                     disc / "Example.m3u": b"Disc One.cue\n"}
        for path, content in originals.items():
            path.write_bytes(content)
        self.run_cli("set-root", self.root)
        self.run_cli("refresh")
        for system, folder in folders.items():
            self.assertEqual((self.view / system).resolve(), self.root / folder)
        for path, content in originals.items():
            self.assertEqual(path.read_bytes(), content)
            self.assertEqual((self.view / "segacd/Disc Game" / path.name).read_bytes(), content)

    def test_regional_alias_ambiguity_preserves_view_until_mapped(self):
        for name in ("Genesis", "Mega Drive"):
            (self.root / name).mkdir()
        self.run_cli("set-root", self.root, success=False)
        self.assertFalse(self.view.exists())
        self.run_cli("map", "megadrive", self.root / "Genesis")
        self.run_cli("set-root", self.root)
        self.assertEqual((self.view / "megadrive").resolve(), self.root / "Genesis")

    def ps3_dump(self, name="Example Game"):
        game = self.root / "PS3" / name
        (game / "PS3_GAME/USRDIR").mkdir(parents=True)
        (game / "PS3_GAME/PARAM.SFO").write_bytes(b"inert metadata fixture")
        (game / "PS3_GAME/USRDIR/EBOOT.BIN").write_bytes(b"inert executable fixture")
        return game

    def test_ps3_dump_and_iso_view_preserves_originals(self):
        game = self.ps3_dump()
        disc = game.parent / "Disc Game.ISO"
        disc.write_bytes(b"inert disc fixture")
        self.run_cli("set-root", self.root)
        self.assertEqual((self.view / "ps3/Example Game.ps3dir").resolve(), game)
        self.assertEqual((self.view / "ps3/Disc Game.ISO").resolve(), disc)
        self.assertEqual(sorted(p.name for p in game.parent.iterdir()), ["Disc Game.ISO", "Example Game"])
        self.assertEqual((game / "PS3_GAME/USRDIR/EBOOT.BIN").read_bytes(), b"inert executable fixture")
        self.run_cli("refresh")
        self.assertEqual(disc.read_bytes(), b"inert disc fixture")

    def test_single_ps3_dump_mapping_and_disconnected_preservation(self):
        game = self.ps3_dump("Already Named.ps3dir")
        self.run_cli("map", "ps3", game)
        link = self.view / "ps3/Already Named.ps3dir"
        self.assertEqual(link.resolve(), game)
        game.rename(game.with_name("disconnected"))
        self.run_cli("refresh", success=False)
        self.assertTrue(link.is_symlink())

    def test_existing_ps3_root_link_upgrades_without_changing_metadata(self):
        game = self.ps3_dump()
        self.view.mkdir(parents=True)
        (self.view / "ps3").symlink_to(game.parent, target_is_directory=True)
        manifest = self.view.parent / "library-view.json"
        manifest.write_text(json.dumps({"ps3": str(game.parent)}))
        metadata = self.view.parent / "frontend/gamelists/ps3/gamelist.xml"
        metadata.parent.mkdir(parents=True)
        metadata.write_text("user metadata must survive\n")
        self.run_cli("set-root", self.root)
        self.assertEqual((self.view / "ps3/Example Game.ps3dir").resolve(), game)
        self.assertEqual(metadata.read_text(), "user metadata must survive\n")
        self.assertTrue(game.is_dir())

    def test_ps3_collision_aborts_before_any_view_changes(self):
        self.ps3_dump("Same Name")
        self.ps3_dump("Same Name.ps3dir")
        self.run_cli("set-root", self.root, success=False)
        self.assertFalse(self.view.exists())
        self.assertFalse((self.base / "data/hon-retro/ps3").exists())

    def test_ps3_foreign_entry_and_global_conflict_preserve_both_views(self):
        self.ps3_dump()
        ps3_view = self.base / "data/hon-retro/ps3"
        ps3_view.mkdir(parents=True)
        foreign = ps3_view / "Example Game.ps3dir"
        foreign.mkdir()
        self.run_cli("set-root", self.root, success=False)
        self.assertTrue(foreign.is_dir())
        self.assertFalse(self.view.exists())
        foreign.rmdir()
        self.view.mkdir()
        (self.view / "gba").mkdir()
        self.run_cli("set-root", self.root, success=False)
        self.assertEqual(list(ps3_view.iterdir()), [])

    def test_symlinked_managed_view_is_rejected(self):
        self.view.parent.mkdir(parents=True)
        foreign = self.base / "foreign"
        foreign.mkdir()
        self.view.symlink_to(foreign, target_is_directory=True)
        self.run_cli("set-root", self.root, success=False)
        self.assertEqual(list(foreign.iterdir()), [])

    def test_recursive_ps3_mapping_is_rejected(self):
        index = self.base / "data/hon-retro/ps3"
        index.mkdir(parents=True)
        self.run_cli("map", "ps3", index, success=False)

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
