# Wrapped by writeShellApplication, which enables errexit, nounset and pipefail.
flake_dir="${ZEPBUILD_FLAKE:-$ZEPBUILD_DEFAULT_FLAKE}"
cleanup=true
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      printf 'Usage: zepbuild [nixos-rebuild options]\nSwitch the local host, then keep the newest 10 system generations and collect garbage.\nCheckout: %s\nOverride the checkout with ZEPBUILD_FLAKE. Dry runs do not clean up.\n' "$flake_dir"
      exit 0
      ;;
    --dry-run|--version) cleanup=false ;;
    --target-host|--target-host=*)
      printf 'zepbuild only switches the local host; use nixos-rebuild directly for remote hosts.\n' >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$flake_dir/flake.nix" ]]; then
  printf 'No flake.nix in %s. Set hon.user.dotfilesDir in preferences.nix or ZEPBUILD_FLAKE.\n' "$flake_dir" >&2
  exit 1
fi
cd -- "$flake_dir"
host=$(hostname)
privilege=()
if (( EUID != 0 )); then
  privilege=(sudo)
  sudo -v
fi
printf 'Building %s from %s...\n' "$host" "$flake_dir"
if "${privilege[@]}" "$(command -v nixos-rebuild)" switch --flake ".#$host" --log-format internal-json -v "$@" 2>&1 | nom --json; then
  if [[ "$cleanup" == false ]]; then
    printf 'Command completed. Skipping garbage collection for this invocation.\n'
    exit 0
  fi
  printf 'Build successful. Keeping the newest 10 system generations...\n'
  "${privilege[@]}" "$(command -v nix-env)" -p /nix/var/nix/profiles/system --delete-generations +10
  "${privilege[@]}" "$(command -v nix-collect-garbage)"
  printf 'Done.\n'
else
  printf 'Rebuild or output monitor failed. Skipping garbage collection.\n' >&2
  exit 1
fi
