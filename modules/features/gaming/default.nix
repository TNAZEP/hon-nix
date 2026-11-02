{ inputs, ... }:
{
  flake.nixosModules.gaming = { pkgs, ... }: {
    imports = with inputs.self.nixosModules; [
      steam
      minecraft
      retro
    ];
    environment.systemPackages = [ pkgs.wowup-cf ];
  };
}
