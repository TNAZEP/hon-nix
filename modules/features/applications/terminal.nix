{
  flake.nixosModules.terminal = { config, ... }: {
    home-manager.users.${config.hon.user.username}.programs.alacritty = {
      enable = true;
      theme = "kanagawa_dragon";
      settings.font.normal.family = config.hon.appearance.font.monospace;
    };
  };
}
