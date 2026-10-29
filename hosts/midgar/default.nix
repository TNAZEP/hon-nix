{ inputs, ... }:
{
  flake.nixosConfigurations.midgar = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      ./hardware.nix
      ./disko.nix
      inputs.disko.nixosModules.disko
      inputs.self.nixosModules.core
      inputs.self.nixosModules.amdGpu
      inputs.self.nixosModules.bluetooth
      inputs.self.nixosModules.cli
      inputs.self.nixosModules.shell
      inputs.self.nixosModules.desktop
      inputs.self.nixosModules.kdeApps
      inputs.self.nixosModules.terminal
      inputs.self.nixosModules.browsers
      inputs.self.nixosModules.editors
      inputs.self.nixosModules.communication
      inputs.self.nixosModules.media
      inputs.self.nixosModules.graphics
      inputs.self.nixosModules.devTools
      inputs.self.nixosModules.git
      inputs.self.nixosModules.java
      inputs.self.nixosModules.onepassword
      inputs.self.nixosModules.ssh
      inputs.self.nixosModules.gaming
      inputs.self.nixosModules.libvirt
      inputs.self.nixosModules.docker
      inputs.self.nixosModules.tailscale
      inputs.self.nixosModules.appimage
      {
        networking.hostName = "midgar";
        system.stateVersion = "25.11";
        hon.monitors = [
          {
            name = "DP-1";
            width = 2560;
            height = 1440;
            refreshRate = 240;
            x = 1920;
            y = 0;
            scale = 1.0;
            bitDepth = 10;
            primary = true;
          }
          {
            name = "DP-2";
            width = 1920;
            height = 1080;
            refreshRate = 144;
            x = 0;
            y = 360;
            scale = 1.0;
          }
        ];
      }
    ];
  };
}
