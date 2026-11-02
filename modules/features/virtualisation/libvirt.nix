{
  flake.nixosModules.libvirt = { config, pkgs, ... }: {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };
    programs.virt-manager.enable = true;
    environment.systemPackages = [ pkgs.virt-viewer ];
    users.users.${config.hon.user.username}.extraGroups = [ "libvirtd" ];
  };
}
