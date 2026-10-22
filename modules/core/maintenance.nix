{
  flake.nixosModules.maintenance =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services.fwupd.enable = true;
      services.fstrim.enable = true;
      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "zepbuild";
          # sudo comes from NixOS /run/wrappers/bin, not the unprivileged store binary.
          runtimeInputs = [
            config.system.build.nixos-rebuild
            config.nix.package
            pkgs.nix-output-monitor
            pkgs.inetutils
          ];
          text = ''
            export ZEPBUILD_DEFAULT_FLAKE=${lib.escapeShellArg config.hon.user.dotfilesDir}
          ''
          + builtins.readFile ./maintenance/zepbuild.sh;
        })
      ];
    };
}
