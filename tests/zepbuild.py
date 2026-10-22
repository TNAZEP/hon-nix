"""Exercise maintenance ordering with inert commands; never touch a real Nix store."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).read_text()
with tempfile.TemporaryDirectory(prefix="zepbuild-test-") as tmp:
    root = Path(tmp)
    checkout = root / "checkout with spaces"
    checkout.mkdir()
    (checkout / "flake.nix").touch()
    bindir = root / "bin"
    bindir.mkdir()
    log = root / "calls.jsonl"
    fixture = bindir / "fixture"
    fixture.write_text("#!" + sys.executable + "\n" + '''
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
with open(os.environ["TEST_LOG"], "a") as f:
    f.write(json.dumps([name, *sys.argv[1:]]) + "\\n")
if name == "sudo":
    if sys.argv[1:] == ["-v"]: sys.exit(0)
    sys.exit(subprocess.call(sys.argv[1:]))
if name == "hostname": print("midgar")
if name == "nom": sys.stdin.read()
if os.environ.get("FAIL_COMMAND") == name: sys.exit(7)
''')
    fixture.chmod(0o755)
    for name in ["hostname", "sudo", "nixos-rebuild", "nom", "nix-env", "nix-collect-garbage"]:
        (bindir / name).symlink_to(fixture)
    script = root / "zepbuild"
    script.write_text("set -euo pipefail\n" + source)
    env = dict(os.environ, PATH=str(bindir) + ":" + os.environ["PATH"],
               ZEPBUILD_DEFAULT_FLAKE=str(root / "missing"),
               ZEPBUILD_FLAKE=str(checkout), TEST_LOG=str(log))

    def run(args=(), fail="", directory=None):
        log.write_text("")
        invocation = dict(env, FAIL_COMMAND=fail)
        if directory is not None:
            invocation["ZEPBUILD_FLAKE"] = str(directory)
        result = subprocess.run(["bash", str(script), *args], env=invocation,
                                capture_output=True, text=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, calls

    result, calls = run(["--option", "test-option", "value with spaces"])
    assert result.returncode == 0, result.stderr
    rebuild = next(c for c in calls if c[0] == "nixos-rebuild")
    assert rebuild[1:] == ["switch", "--flake", ".#midgar", "--log-format", "internal-json", "-v",
                           "--option", "test-option", "value with spaces"]
    cleanup = [c for c in calls if c[0] in ("nix-env", "nix-collect-garbage")]
    assert cleanup == [["nix-env", "-p", "/nix/var/nix/profiles/system", "--delete-generations", "+10"],
                       ["nix-collect-garbage"]]
    for failure in ["nixos-rebuild", "nom"]:
        result, calls = run(fail=failure)
        assert result.returncode != 0
        assert not any(c[0] in ("nix-env", "nix-collect-garbage") for c in calls), calls
    result, calls = run(fail="nix-env")
    assert result.returncode != 0 and not any(c[0] == "nix-collect-garbage" for c in calls)
    result, calls = run(["--dry-run"])
    assert result.returncode == 0
    assert not any(c[0] in ("nix-env", "nix-collect-garbage") for c in calls)
    for args, directory in [(["--help"], None), ([], root / "missing"),
                            (["--target-host", "remote"], None)]:
        result, calls = run(args, directory=directory)
        assert not calls, calls
        assert (result.returncode == 0) == (args == ["--help"])
print("zepbuild checks passed: arguments, paths, ordering, pipeline failures, pruning failures, dry run and validation")
