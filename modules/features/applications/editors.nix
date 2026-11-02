{
  flake.nixosModules.editors = { config, pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      antigravity-ide
      code-cursor
      nil
      nixd
    ];
    home-manager.users.${config.hon.user.username}.programs.vscodium = {
      enable = true;
      package = pkgs.vscodium;
    };
  };
}
