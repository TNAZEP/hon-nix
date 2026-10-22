{
  flake.nixosModules.retro = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      shipwright
      _2ship2harkinian
      perfect_dark
      retroarch-full
      ironwail
    ];
  };
}
