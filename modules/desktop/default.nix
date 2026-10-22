{ inputs, ... }:
{
  flake.nixosModules.desktop = {
    imports = with inputs.self.nixosModules; [
      audio
      portals
      plasma
      theming
      hyprland
      honShell
    ];
  };
}
