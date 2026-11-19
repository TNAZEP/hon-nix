{
  flake.nixosModules.media = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      kdePackages.ffmpegthumbs
      kdePackages.audiocd-kio
      kdePackages.kimageformats
      kdePackages.kdenlive
      kdePackages.kamoso
      mpv
      yt-dlp
      (pkgs.callPackage ../../../pkgs/capture-view.nix { })
    ];
  };
}
