{ inputs, ... }:
{
  flake.nixosModules.core = {
    imports = with inputs.self.nixosModules; [
      preferences
      nix
      locale
      user
      networking
      homeManager
      maintenance
    ];
  };
}
