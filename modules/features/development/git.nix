{
  flake.nixosModules.git =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home-manager.users.${config.hon.user.username} = {
        home.packages = [ pkgs.github-desktop ];
        programs.gh.enable = true;
        programs.git = {
          enable = true;
          settings = {
            user.name = config.hon.user.name;
            user.email = config.hon.user.email;
            init.defaultBranch = "master";
          };
          signing = {
            format = "ssh";
            signer = lib.getExe' config.programs._1password-gui.package "op-ssh-sign";
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEclWROAzXXuA3fE8qIWW55pJLOewedBGS6bT6Sf3xG4";
            signByDefault = true;
          };
        };
      };
    };
}
