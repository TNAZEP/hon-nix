{
  flake.nixosModules.minecraft = { pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.prismlauncher.override {
        jdks = with pkgs; [
          (zulu8.override { gtkSupport = false; })
          zulu17
          zulu21
          zulu25
        ];
      })
    ];
  };
}
