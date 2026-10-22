{
  description = "hon-nix: a NixOS workstation configuration";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];
      imports = [
        (inputs.import-tree ./modules)
        # Other host files are ordinary NixOS modules, imported by their host.
        (inputs.import-tree.filter (path: builtins.baseNameOf path == "default.nix") ./hosts)
      ];
      perSystem = { pkgs, ... }: {
        formatter = pkgs.nixfmt-tree;
        checks.maintenance = import ./tests/maintenance.nix { inherit pkgs; };
        checks.foundation = import ./tests/foundation.nix {
          flake = inputs.self;
          inherit pkgs;
        };
        checks.desktop = import ./tests/desktop.nix {
          flake = inputs.self;
          inherit pkgs;
        };
        checks.shell = import ./tests/shell.nix {
          flake = inputs.self;
          inherit pkgs;
        };
      };
    };
}
