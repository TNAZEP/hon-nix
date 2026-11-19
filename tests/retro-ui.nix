{ pkgs, flake }:
let
  config = flake.nixosConfigurations.midgar.config;
  home = config.home-manager.users.${config.hon.user.username};
  frontend = pkgs.lib.findFirst (
    package: pkgs.lib.getName package == "hon-retro-es-de"
  ) (throw "Configured ES-DE entry is missing") config.environment.systemPackages;
  # The theme has no blanket redistribution grant; use the host's existing policy.
  themePkgs = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = package: pkgs.lib.getName package == "iisu-interpreted";
  };
  theme = themePkgs.callPackage ../pkgs/iisu-interpreted.nix { };
in
pkgs.runCommand "hon-retro-frontend-checks"
  {
    nativeBuildInputs = with pkgs; [
      (python3.withPackages (ps: [ ps.pillow ]))
      sway
      grim
      wtype
      dbus
    ];
  }
  ''
    export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
    for platform in gba ps3 ps4 switch psvita mame atari5200 pcfx; do
      dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- python ${./retro-ui.py} \
        ${frontend}/bin/es-de \
        ${theme}/share/es-de/themes/iisu-interpreted-es-de \
        ${../modules/features/gaming/retro/library.py} "$out/$platform" "$platform" \
        ${home.xdg.dataFile."hon-retro/frontend/custom_systems/es_systems.xml".source} \
        ${home.xdg.dataFile."hon-retro/frontend/custom_systems/es_find_rules.xml".source}
    done
  ''
