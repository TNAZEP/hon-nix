{
  flake.nixosModules.graphics = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      krita
    ];
  };
}
