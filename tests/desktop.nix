{ flake, pkgs }:
let
  inherit (pkgs) lib;
  host = flake.nixosConfigurations.midgar;
  config = host.config;
  home = config.home-manager.users.${config.hon.user.username};
  reversed = host.extendModules {
    modules = [ { hon.monitors = lib.mkForce (lib.reverseList config.hon.monitors); } ];
  };
  workspaceFile = pkgs.writeText "workspaces.lua" home.xdg.configFile."hypr/workspaces.lua".text;
in
assert config.hon.workspaces == reversed.config.hon.workspaces;
assert builtins.length config.hon.workspaces == 20;
assert config.programs.hyprland.withUWSM;
assert !home.wayland.windowManager.hyprland.systemd.enable;
assert config.services.desktopManager.plasma6.enable;
assert home.qt.platformTheme.name == "kde";
assert config.xdg.portal.config.hyprland."org.freedesktop.impl.portal.ScreenCast" == "hyprland";
assert config.xdg.portal.config.KDE.default == "kde";
pkgs.runCommand "hon-nix-desktop-checks" { nativeBuildInputs = [ pkgs.lua ]; } ''
  lua ${./workspaces.lua} ${workspaceFile}
  touch "$out"
''
