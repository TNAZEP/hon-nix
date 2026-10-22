{ inputs, ... }:
{
  flake.nixosModules.gaming = {
    imports = with inputs.self.nixosModules; [
      steam
      minecraft
      retro
    ];
  };
}
