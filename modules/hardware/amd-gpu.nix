{
  flake.nixosModules.amdGpu = {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };
    services.xserver.videoDrivers = [ "amdgpu" ];
  };
}
