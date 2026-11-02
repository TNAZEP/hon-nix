{
  flake.nixosModules.ssh = { config, ... }: {
    programs.ssh.startAgent = false;
    services.gnome.gcr-ssh-agent.enable = false;
    home-manager.users.${config.hon.user.username} = {
      services.ssh-agent.enable = false;
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*".IdentityAgent = "~/.1password/agent.sock";
      };
    };
  };
}
