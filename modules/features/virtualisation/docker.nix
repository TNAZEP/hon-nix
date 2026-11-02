{
  flake.nixosModules.docker = { config, ... }: {
    virtualisation.docker.enable = true;
    users.users.${config.hon.user.username}.extraGroups = [ "docker" ];
  };
}
