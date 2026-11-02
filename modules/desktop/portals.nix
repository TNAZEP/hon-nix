{
  flake.nixosModules.portals = { pkgs, ... }: {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
      config = {
        hyprland = {
          default = [
            "hyprland"
            "kde"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
          "org.freedesktop.impl.portal.Settings" = [ "kde" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        };
        KDE.default = [ "kde" ];
      };
    };
    environment.systemPackages = [ pkgs.xdg-utils ];
  };
}
