{
  flake.nixosModules.onepassword = { config, ... }: {
    programs._1password.enable = true;
    home-manager.users.${config.hon.user.username}.xdg.configFile."autostart/1password.desktop".text =
      ''
        [Desktop Entry]
        Type=Application
        Name=1Password
        Exec=${config.programs._1password-gui.package}/bin/1password --silent
        Terminal=false
      '';
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ config.hon.user.username ];
    };
  };
}
