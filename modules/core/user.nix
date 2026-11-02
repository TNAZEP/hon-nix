{
  flake.nixosModules.user = { config, pkgs, ... }: {
    programs.zsh.enable = true;
    users.users.${config.hon.user.username} = {
      isNormalUser = true;
      description = config.hon.user.name;
      home = "/home/${config.hon.user.username}";
      shell = pkgs.zsh;
      extraGroups = [ "wheel" ];
    };
  };
}
