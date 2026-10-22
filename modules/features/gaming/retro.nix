{
  flake.nixosModules.retro = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      shipwright
      _2ship2harkinian
    ];
  };
}
