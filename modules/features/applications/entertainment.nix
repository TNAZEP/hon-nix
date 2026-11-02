{
  flake.nixosModules.entertainment = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      stremio-linux-shell
      kdePackages.elisa
      kdePackages.dragon
    ];
  };
}
