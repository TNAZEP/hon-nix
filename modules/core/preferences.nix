{
  flake.nixosModules.preferences =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      string =
        description:
        mkOption {
          type = types.nonEmptyStr;
          inherit description;
        };
      positiveNumber = types.addCheck types.number (value: value > 0);
    in
    {
      options.hon = {
        user = {
          username = string "Primary login name.";
          name = string "Full name used by the account and Git.";
          email = string "Primary email address.";
        };
        locale = {
          timezone = string "IANA time zone.";
          language = string "Default UTF-8 locale.";
          keyboard = string "XKB keyboard layout.";
          consoleKeyMap = string "Linux virtual-console keymap.";
        };
        desktop = {
          terminal = string "Preferred terminal command.";
          browser = string "Preferred browser command.";
          editor = string "Preferred editor command.";
          fileManager = string "Preferred file manager command.";
        };
        appearance = {
          mode = mkOption {
            type = types.enum [ "dark" ];
            description = "Supported desktop appearance mode.";
          };
          theme = mkOption {
            type = types.enum [ "kanagawa-dragon" ];
            description = "Palette for the compositor, terminal, and shell UI.";
          };
          icons = string "Toolkit icon theme name.";
          font = {
            sans = string "UI font family.";
            monospace = string "Terminal and shell UI monospace font family.";
          };
          cursor = {
            name = string "Cursor theme name.";
            size = mkOption {
              type = types.ints.positive;
              description = "Cursor size in pixels.";
            };
          };
        };
        monitors = mkOption {
          default = [ ];
          description = "Host display facts; exactly one configured monitor must be primary.";
          type = types.listOf (
            types.submodule {
              options = {
                name = string "Compositor connector name.";
                width = mkOption {
                  type = types.ints.positive;
                  description = "Native width in pixels.";
                };
                height = mkOption {
                  type = types.ints.positive;
                  description = "Native height in pixels.";
                };
                refreshRate = mkOption {
                  type = positiveNumber;
                  description = "Refresh rate in hertz.";
                };
                x = mkOption {
                  type = types.int;
                  default = 0;
                  description = "Logical horizontal position.";
                };
                y = mkOption {
                  type = types.int;
                  default = 0;
                  description = "Logical vertical position.";
                };
                scale = mkOption {
                  type = positiveNumber;
                  default = 1.0;
                  description = "Display scale factor.";
                };
                primary = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Owns the first workspace block.";
                };
                bitDepth = mkOption {
                  type = types.nullOr (
                    types.enum [
                      8
                      10
                    ]
                  );
                  default = null;
                  description = "Explicit output bit depth, or the compositor default.";
                };
              };
            }
          );
        };
      };
      config = {
        hon = import ../../preferences.nix;
        assertions = [
          {
            assertion =
              config.hon.monitors == [ ]
              || builtins.length (builtins.filter (monitor: monitor.primary) config.hon.monitors) == 1;
            message = "hon.monitors must have exactly one primary monitor when nonempty.";
          }
          {
            assertion =
              let
                names = map (monitor: monitor.name) config.hon.monitors;
              in
              builtins.length names == builtins.length (lib.unique names);
            message = "hon.monitors connector names must be unique.";
          }
        ];
      };
    };
}
