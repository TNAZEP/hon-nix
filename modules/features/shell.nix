{
  flake.nixosModules.shell = { config, pkgs, ... }: {
    programs.zsh.enable = true;
    home-manager.users.${config.hon.user.username}.programs.zsh = {
      enable = true;
      initContent = ''
        source ${../../assets/zsh/p10k.zsh}
      '';
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };
      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
      ];
    };
  };
}
