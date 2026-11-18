{
  flake.nixosModules.retro =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      frontend = pkgs.callPackage ../../../pkgs/es-de.nix { };
      theme = pkgs.callPackage ../../../pkgs/iisu-interpreted.nix { };
      controllerProfiles = pkgs.runCommand "retro-controller-profiles" { } ''
        mkdir -p "$out"
        cp -rs ${pkgs.retroarch-joypad-autoconfig}/share/libretro/autoconfig/. "$out/"
        chmod u+w "$out/udev" "$out/sdl2"
        cp ${./retro/controllers/8bitdo-64-udev.cfg} "$out/udev/hon-8bitdo-64.cfg"
        cp ${./retro/controllers/ultimate2-sdl2.cfg} "$out/sdl2/hon-ultimate2.cfg"
      '';
      retroarchSettings = {
        config_save_on_exit = "false";
        cheevos_hardcore_mode_enable = "false";
        sort_savefiles_enable = "true";
        sort_savestates_enable = "true";
        core_info_cache_enable = "false";
        assets_directory = "${pkgs.retroarch-assets}/share/retroarch/assets";
        libretro_info_path = "${pkgs.libretro-core-info}/share/retroarch/cores";
        joypad_autoconfig_dir = "${controllerProfiles}";
        input_joypad_driver = "sdl2";
        input_player1_device_reservation_type = "1";
        input_player1_reserved_device = "2dc8:6012 8Bitdo Ultimate 2 Wireless Controller";
      };
      # RetroArch uses only the last --appendconfig argument, including the
      # one added by the nixpkgs wrapper. Profiles must retain its defaults.
      renderSettings =
        settings:
        lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: ''${name} = "${value}"'') settings)
        + "\n";
      # RetroArch takes the first occurrence of a key within a config file.
      n64Controller = pkgs.writeText "retro-n64-controller.cfg" (
        renderSettings (
          retroarchSettings
          // {
            input_joypad_driver = "udev";
            input_player1_reserved_device = "2dc8:3019 8BitDo 64 BT";
          }
        )
      );
      ultimateController = pkgs.writeText "retro-ultimate2-controller.cfg" (
        renderSettings retroarchSettings
      );
      retroarch = pkgs.wrapRetroArch {
        cores = config.hon.retro.cores;
        settings = retroarchSettings;
      };
      library = pkgs.writeShellApplication {
        name = "retro-library";
        text = ''
          exec ${lib.getExe pkgs.python3} ${./retro/library.py} "$@"
        '';
      };
      play = pkgs.writeShellApplication {
        name = "retro-play";
        text = ''
          config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/hon-retro"
          data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/hon-retro"
          mkdir -p "$config_dir" "$data_dir"/{bios,saves,states}
          if [[ ! -e "$config_dir/retroarch.cfg" ]]; then
            # Seed a writable base once; rebuilding never replaces experiments.
            (set -o noclobber
              cat > "$config_dir/retroarch.cfg" <<EOF
          video_driver = "vulkan"
          savefile_directory = "$data_dir/saves"
          savestate_directory = "$data_dir/states"
          system_directory = "$data_dir/bios"
          EOF
            ) || true
          fi
          profile_args=()
          if [[ "''${1:-}" == --profile ]]; then
            case "''${2:-}" in
              n64) profile_args=(--appendconfig ${n64Controller}) ;;
              ultimate2) profile_args=(--appendconfig ${ultimateController}) ;;
              *) echo 'retro-play: expected --profile n64 or ultimate2' >&2; exit 2 ;;
            esac
            shift 2
          fi
          exec ${lib.getExe retroarch} --config "$config_dir/retroarch.cfg" "''${profile_args[@]}" "$@"
        '';
      };
      home = pkgs.writeShellApplication {
        name = "retro-home";
        text = ''
          ${lib.getExe library} prepare >/dev/null
          export ESDE_APPDATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/hon-retro/frontend"
          # Keep the official adapter available to Dolphin's native USB backend.
          export SDL_JOYSTICK_HIDAPI_GAMECUBE=0
          exec ${lib.getExe frontend} "$@"
        '';
      };
      console = pkgs.writeShellApplication {
        name = "retro-console";
        text = ''
          exec ${pkgs.systemd}/bin/systemd-inhibit --what=idle --mode=block \
            --who="Retro gaming" --why="Controller gaming session" \
            ${lib.getExe home} "$@"
        '';
      };
      findRules = pkgs.writeText "retro-es-find-rules.xml" ''
        <?xml version="1.0"?>
        <ruleList>
          <emulator name="RETROARCH">
            <rule type="staticpath"><entry>${lib.getExe play}</entry></rule>
          </emulator>
          <core name="RETROARCH">
            <rule type="corepath"><entry>${retroarch}/lib/retroarch/cores</entry></rule>
          </core>
          <emulator name="DOLPHIN">
            <rule type="staticpath"><entry>${lib.getExe pkgs.dolphin-emu}</entry></rule>
          </emulator>
        </ruleList>
      '';
    in
    {
      options.hon.retro = {
        enable = lib.mkEnableOption "the retro gaming environment" // {
          default = true;
        };
        cores = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs.libretro; [
            mesen
            mgba
            mupen64plus
          ];
          description = "RetroArch cores installed with the retro environment.";
        };
      };
      config = lib.mkIf config.hon.retro.enable {
        environment.systemPackages =
          (with pkgs; [
            dolphin-emu
            shipwright
            _2ship2harkinian
            gnome-disk-utility
          ])
          ++ [
            frontend
            retroarch
            library
            play
            home
            console
          ];
        # Dolphin ships upstream USB access rules for the Wii U GameCube adapter.
        services.udev.packages = [ pkgs.dolphin-emu ];
        home-manager.users.${config.hon.user.username} = {
          xdg.dataFile = {
            "hon-retro/frontend/themes/iisu-interpreted-es-de".source =
              "${theme}/share/es-de/themes/iisu-interpreted-es-de";
            "hon-retro/frontend/custom_systems/es_find_rules.xml".source = findRules;
            # Standalone Dolphin is required for the native GC adapter and Wiimotes.
            "hon-retro/frontend/custom_systems/es_systems.xml".text = ''
                <?xml version="1.0"?>
                <systemList>
              <system>
                <name>n64</name><fullname>Nintendo 64</fullname>
                <path>%ROMPATH%/n64</path>
                <extension>.n64 .N64 .v64 .V64 .z64 .Z64 .zip .ZIP .7z .7Z</extension>
                <command label="Mupen64Plus-Next">%EMULATOR_RETROARCH% --profile n64 -L %CORE_RETROARCH%/mupen64plus_next_libretro.so %ROM%</command>
                <platform>n64</platform><theme>n64</theme>
              </system>
                  <system>
                    <name>gc</name><fullname>Nintendo GameCube</fullname>
                    <path>%ROMPATH%/gc</path>
                    <extension>.gcm .GCM .iso .ISO .rvz .RVZ .gcz .GCZ .wia .WIA .ciso .CISO .dol .DOL .elf .ELF .m3u .M3U</extension>
                    <command label="Dolphin (Standalone)">%EMULATOR_DOLPHIN% -b -e %ROM%</command>
                    <platform>gc</platform><theme>gc</theme>
                  </system>
                </systemList>
            '';
          };
          xdg.desktopEntries = {
            retro-home = {
              name = "Retro Home";
              comment = "Browse and play your emulation library";
              exec = lib.getExe home;
              icon = "es-de";
              categories = [ "Game" ];
            };
            retro-console = {
              name = "Retro Console";
              comment = "Fullscreen retro library with idle inhibition";
              exec = lib.getExe console;
              icon = "es-de";
              categories = [ "Game" ];
            };
          };
        };
      };
    };
}
