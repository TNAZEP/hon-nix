{
  flake.nixosModules.kdeApps = { config, pkgs, ... }: {
    environment.systemPackages = with pkgs.kdePackages; [
      dolphin
      dolphin-plugins
      ark
      pkgs.unrar
      gwenview
      okular
      spectacle
      filelight
      partitionmanager
      plasma-systemmonitor
      kcharselect
      kcalc
      kdialog
      kfind
      ksystemlog
      kio-extras
      kio-fuse
      kget
      kio-gdrive
      print-manager
      plasma-browser-integration
    ];
    services.udisks2.enable = true;
    home-manager.users.${config.hon.user.username}.xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
        "application/pdf" = [ "org.kde.okular.desktop" ];
      };
    };
  };
}
