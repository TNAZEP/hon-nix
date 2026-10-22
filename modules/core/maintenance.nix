{
  flake.nixosModules.maintenance = {
    services.fwupd.enable = true;
    services.fstrim.enable = true;
  };
}
