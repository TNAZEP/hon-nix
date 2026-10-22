{ inputs, ... }:
{
  flake.nixosModules.nix = { config, pkgs, ... }: {
    nixpkgs.config.allowUnfree = true;
    _module.args.pkgsStable = import inputs.nixpkgs-stable {
      system = pkgs.stdenv.hostPlatform.system;
      config = config.nixpkgs.config;
    };
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };
}
