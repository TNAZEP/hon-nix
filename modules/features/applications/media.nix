{
  flake.nixosModules.media = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      kdePackages.ffmpegthumbs
      kdePackages.audiocd-kio
      kdePackages.kimageformats
      kdePackages.kdenlive
      kdePackages.kamoso
      (pkgs.callPackage ../../../pkgs/capture-view.nix { })
    ];
  };
}
