{
  flake.nixosModules.bluetooth = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
