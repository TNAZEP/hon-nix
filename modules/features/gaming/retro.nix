{
  flake.nixosModules.retro = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      dolphin-emu
      shipwright
      _2ship2harkinian
      gnome-disk-utility
    ];
    # Dolphin ships upstream USB access rules for the Wii U GameCube adapter.
    services.udev.packages = [ pkgs.dolphin-emu ];
  };
}
