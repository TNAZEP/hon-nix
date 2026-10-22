{
  flake.nixosModules.media =
    { pkgs, ... }:
    let
      # Blackmagic replaced the 21.1 archive with v21.1-1. Keep the correction
      # local to this release; review/remove it when updating nixpkgs.
      resolve =
        assert pkgs.davinci-resolve.version == "21.1";
        pkgs.davinci-resolve.override {
          runCommandLocal =
            name: attrs:
            pkgs.runCommandLocal name (
              attrs
              // pkgs.lib.optionalAttrs (name == "davinci-resolve-src.zip") {
                outputHash = "sha256-+3SB32EHpH9/0hM3h8CrO6f7V4ZAmxUFh3P8m6QDeO0=";
              }
            );
        };
    in
    {
      environment.systemPackages = with pkgs; [
        kdePackages.elisa
        kdePackages.dragon
        kdePackages.ffmpegthumbs
        kdePackages.audiocd-kio
        kdePackages.kimageformats
        kdePackages.kdenlive
        kdePackages.kamoso
        resolve
      ];
    };
}
