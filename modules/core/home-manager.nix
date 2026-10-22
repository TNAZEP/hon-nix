{ inputs, ... }:
{
  flake.nixosModules.homeManager = { config, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.${config.hon.user.username} = {
        home.username = config.hon.user.username;
        home.homeDirectory = config.users.users.${config.hon.user.username}.home;
        home.stateVersion = "25.11";
        programs.home-manager.enable = true;
      };
    };
  };
}
