{ flake, pkgs }:
let
  config = flake.nixosConfigurations.midgar.config;
  home = config.home-manager.users.${config.hon.user.username};
  disabled = flake.nixosConfigurations.midgar.extendModules {
    modules = [ { hon.retro.enable = false; } ];
  };
  play = pkgs.lib.findFirst (
    package: pkgs.lib.getName package == "retro-play"
  ) (throw "retro-play is missing") config.environment.systemPackages;
in
assert home.xdg.dataFile ? "hon-retro/frontend/themes/iisu-interpreted-es-de";
assert home.xdg.desktopEntries ? retro-home;
assert home.xdg.desktopEntries ? retro-console;
assert
  !(disabled.config.home-manager.users.${config.hon.user.username}.xdg.desktopEntries ? retro-home);
pkgs.runCommand "hon-retro-library-checks"
  {
    nativeBuildInputs = [
      pkgs.python3
      play
    ];
  }
  ''
    python ${./retro.py} ${../modules/features/gaming/retro/library.py}
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_DATA_HOME="$TMPDIR/data"
    retro-play --version
    retro-play --profile n64 --version
    retro-play --profile ultimate2 --version
    retro-play --profile n64 --presentation crt --version
    retro-play --presentation gba-lcd --profile ultimate2 --version
    retro-play --presentation raw --version
    test -f "$XDG_CONFIG_HOME/hon-retro/retroarch.cfg"
    printf '%s\n' '# User experiment' > "$XDG_CONFIG_HOME/hon-retro/retroarch.cfg"
    retro-play --version
    test "$(cat "$XDG_CONFIG_HOME/hon-retro/retroarch.cfg")" = '# User experiment'
    touch "$out"
  ''
