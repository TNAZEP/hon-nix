{
  flake.nixosModules.devTools = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      nodejs
      nixfmt
      godot
    ];
  };
}
