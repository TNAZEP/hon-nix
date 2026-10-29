{
  flake.nixosModules.communication = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      vesktop
      discord
      element-desktop
      chromium
    ];
  };
}
