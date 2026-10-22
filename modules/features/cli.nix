{
  flake.nixosModules.cli = { config, pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      vim
      wget
      curl
      htop
      btop
      fastfetch
      superfile
      nix-output-monitor
      speedtest-cli
    ];
    home-manager.users.${config.hon.user.username}.programs.pay-respects.enable = true;
  };
}
