{ pkgs }:
let
  frontend = pkgs.callPackage ../pkgs/es-de.nix { };
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
      python3
      sway
      grim
      wtype
      dbus
    ];
  }
  ''
    export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- python ${./retro-ui.py} \
      ${frontend}/bin/es-de \
      ${theme}/share/es-de/themes/iisu-interpreted-es-de \
      ${../modules/features/gaming/retro/library.py} "$out"
  ''
