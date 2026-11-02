{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.cpu.amd.updateMicrocode = true;
}
