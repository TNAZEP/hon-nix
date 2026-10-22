{
  flake.nixosModules.communication = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      vesktop
      element-desktop
    ];
  };
}
