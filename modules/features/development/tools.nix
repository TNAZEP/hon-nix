{
  flake.nixosModules.devTools = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      nodejs
      go-task
      nixfmt
      godot
    ];
  };
}
