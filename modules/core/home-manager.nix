{ inputs, ... }:
{
  flake.nixosModules.homeManager = { config, pkgs, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # Preserve earlier backups when desktop applications replace managed files.
      backupCommand = pkgs.writeShellScript "home-manager-backup" ''
        exec ${pkgs.coreutils}/bin/mv --backup=numbered -- "$1" "$1.backup"
      '';
      users.${config.hon.user.username} = {
        home.username = config.hon.user.username;
        home.homeDirectory = config.users.users.${config.hon.user.username}.home;
        home.stateVersion = "25.11";
        programs.home-manager.enable = true;
      };
    };
  };
}
