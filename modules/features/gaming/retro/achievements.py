"""Keep a RetroArch login token in private runtime files, outside Nix."""

import argparse
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


def location():
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hon-retro/achievements"


def private_read(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "r") as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                or info.st_mode & 0o077):
            raise ValueError("Expected an owned regular file with private permissions (chmod 600)")
        value = stream.read(1024 * 1024 + 1)
        if len(value) > 1024 * 1024:
            raise ValueError("Credential input is too large")
        return value


def save(path, value):
    parent = path.parent
    parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    info = parent.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError("Credential directory must be an owned directory, not a link")
    parent.chmod(0o700)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError("Existing non-regular credential entry preserved")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(value)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def account(value):
    if (not isinstance(value, dict) or set(value) != {"cheevos_username", "cheevos_token"}
            or any(not isinstance(item, str) or not item or len(item) > 4096
                   or any(character in item for character in '\\"\r\n\0')
                   for item in value.values())):
        raise ValueError("Expected a nonempty RetroArch username and login token")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    login = commands.add_parser("import", help="Import only username/token from a private RetroArch config")
    login.add_argument("config", type=Path)
    mode = commands.add_parser("mode", help="Persist off or softcore; hardcore is session-only")
    mode.add_argument("value", choices=("off", "softcore"))
    commands.add_parser("status", help="Show mode and whether an account is configured, without credentials")
    commands.add_parser("resolve-mode", help=argparse.SUPPRESS)
    fragment = commands.add_parser("fragment", help=argparse.SUPPRESS)
    fragment.add_argument("value", choices=("softcore", "hardcore"))
    args = parser.parse_args()
    root = location()
    try:
        if args.command == "import":
            values = {}
            for line in private_read(args.config.expanduser()).splitlines():
                match = re.fullmatch(r'\s*(cheevos_username|cheevos_token)\s*=\s*"([^"\\]*)"\s*(?:#.*)?', line)
                if match:
                    # Match RetroArch's first-occurrence precedence.
                    values.setdefault(match[1], match[2])
            save(root / "account.json", json.dumps(account(values)) + "\n")
            print("Private RetroArch login token imported; no password was copied")
        elif args.command == "mode":
            if args.value == "softcore":
                account(json.loads(private_read(root / "account.json")))
            save(root / "mode", args.value + "\n")
            print(f"Default achievements mode: {args.value}")
        elif args.command in ("status", "resolve-mode"):
            selected = private_read(root / "mode").strip() if (root / "mode").exists() else "off"
            if selected not in ("off", "softcore"):
                raise ValueError("Invalid stored achievements mode")
            if args.command == "resolve-mode":
                print(selected)
            else:
                configured = (root / "account.json").is_file()
                print(f"Default mode: {selected}; account configured: {'yes' if configured else 'no'}")
        else:
            values = account(json.loads(private_read(root / "account.json")))
            # Explicit config saving can merge appended credentials into the base.
            # Secure its permissions without replacing or reading its contents.
            base = root.parent / "retroarch.cfg"
            descriptor = os.open(base, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(descriptor) as stream:
                info = os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                    raise ValueError("RetroArch base config must be an owned regular file")
                os.fchmod(stream.fileno(), 0o600)
            path = root / f"{args.value}.cfg"
            if "|" in str(path) or "\n" in str(path):
                raise ValueError("Credential path cannot contain RetroArch config delimiters")
            settings = values | {
                "cheevos_password": "", "cheevos_enable": "true",
                "cheevos_custom_host": "",
                "cheevos_hardcore_mode_enable": "true" if args.value == "hardcore" else "false",
                "cheevos_verbose_enable": "false", "cheevos_richpresence_enable": "false",
                "log_verbosity": "false", "log_to_file": "false",
                "config_save_on_exit": "false",
            }
            if args.value == "hardcore":
                settings["savestate_auto_load"] = "false"
            save(path, "".join(f'{key} = "{value}"\n' for key, value in settings.items()))
            print(path)
        return 0
    except (OSError, ValueError, TypeError):
        # Deliberately omit exception details, which can contain credential input.
        print("retro-achievements: private account/config unavailable or invalid; check file ownership, permissions and login token", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
