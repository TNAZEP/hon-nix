"""Verify private runtime login handling without using an account or network."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(sys.argv.pop(1)).resolve()


class AchievementsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.env = os.environ | {"XDG_CONFIG_HOME": str(self.base / "config")}
        self.root = self.base / "config/hon-retro/achievements"
        self.config = self.base / "private.cfg"
        self.config.write_text('cheevos_username = "fixture-user"\ncheevos_token = "fixture-token"\n'
                               'cheevos_password = "never-copy-this"\nvideo_driver = "null"\n')
        self.config.chmod(0o600)
        self.main_config = self.root.parent / "retroarch.cfg"
        self.main_config.parent.mkdir(parents=True)
        self.main_config.write_text("# writable experiment\n")

    def run_cli(self, *args, success=True):
        result = subprocess.run([sys.executable, "-B", str(SOURCE), *map(str, args)],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        for secret in ("fixture-user", "fixture-token", "never-copy-this"):
            self.assertNotIn(secret, result.stdout + result.stderr)
        return result

    def test_import_only_token_and_username_private_and_source_unchanged(self):
        original = self.config.read_bytes()
        self.run_cli("import", self.config)
        saved = self.root / "account.json"
        self.assertEqual(json.loads(saved.read_text()), {
            "cheevos_username": "fixture-user", "cheevos_token": "fixture-token"})
        self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.config.read_bytes(), original)

    def test_mode_default_and_hardcore_cannot_be_persisted(self):
        self.assertEqual(self.run_cli("resolve-mode").stdout.strip(), "off")
        self.run_cli("mode", "softcore", success=False)
        self.run_cli("import", self.config)
        self.run_cli("mode", "softcore")
        self.assertEqual(self.run_cli("resolve-mode").stdout.strip(), "softcore")
        self.run_cli("mode", "hardcore", success=False)
        self.assertEqual(self.run_cli("resolve-mode").stdout.strip(), "softcore")

    def test_session_fragments_and_base_preservation(self):
        self.run_cli("import", self.config)
        for mode in ("softcore", "hardcore"):
            path = Path(self.run_cli("fragment", mode).stdout.strip())
            text = path.read_text()
            self.assertIn('cheevos_password = ""', text)
            self.assertNotIn("never-copy-this", text)
            self.assertIn('config_save_on_exit = "false"', text)
            self.assertIn(f'cheevos_hardcore_mode_enable = "{str(mode == "hardcore").lower()}"', text)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.main_config.read_text(), "# writable experiment\n")
        self.assertEqual(self.main_config.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.root / "mode").exists())

    def test_public_source_and_symlink_refused(self):
        self.config.chmod(0o644)
        self.run_cli("import", self.config, success=False)
        self.config.chmod(0o600)
        link = self.base / "link.cfg"
        link.symlink_to(self.config)
        self.run_cli("import", link, success=False)
        self.assertFalse((self.root / "account.json").exists())

    def test_invalid_or_missing_token_preserves_existing_account(self):
        self.run_cli("import", self.config)
        original = (self.root / "account.json").read_bytes()
        self.config.write_text('cheevos_username = "fixture-user"\ncheevos_password = "never-copy-this"\n')
        self.run_cli("import", self.config, success=False)
        self.assertEqual((self.root / "account.json").read_bytes(), original)

    def test_first_token_wins_and_invalid_json_is_not_printed(self):
        with self.config.open("a") as stream:
            stream.write('cheevos_token = "other-token"\n')
        self.run_cli("import", self.config)
        self.assertEqual(json.loads((self.root / "account.json").read_text())["cheevos_token"], "fixture-token")
        (self.root / "account.json").write_text('{"fixture-token": invalid-json}')
        self.run_cli("fragment", "softcore", success=False)

    def test_foreign_entry_and_linked_base_preserved(self):
        self.root.mkdir()
        target = self.base / "do-not-change"
        target.write_text("original")
        (self.root / "account.json").symlink_to(target)
        self.run_cli("import", self.config, success=False)
        self.assertEqual(target.read_text(), "original")
        (self.root / "account.json").unlink()
        self.run_cli("import", self.config)
        self.main_config.unlink()
        self.main_config.symlink_to(target)
        self.run_cli("fragment", "softcore", success=False)
        self.assertEqual(target.read_text(), "original")


if __name__ == "__main__":
    unittest.main()
