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
      nativeEmulators = lib.optionalAttrs config.hon.retro.standalone.enable {
        PCSX2 = pkgs.pcsx2;
        XEMU = pkgs.xemu;
        MELONDS = pkgs.melonds;
        PPSSPP = pkgs.ppsspp;
        RPCS3 = pkgs.rpcs3;
        XENIA = pkgs.xenia-canary;
        CEMU = pkgs.cemu;
        AZAHAR = pkgs.azahar;
      };
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
        ui_companion_start_on_boot = "false";
        desktop_menu_enable = "false";
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
      shaders = "${pkgs.libretro-shaders-slang}/share/libretro/shaders/shaders_slang";
      crtPreset = pkgs.writeText "retro-crt.slangp" ''
        #reference "${shaders}/bezel/Mega_Bezel/Presets/MBZ__3__STD.slangp"
        HSM_INTRO_WHEN_TO_SHOW = "0"
        HSM_REFLECT_GLOBAL_AMOUNT = "20"
      '';
      crtPresentation = pkgs.writeText "retro-crt.cfg" (renderSettings {
        video_shader_enable = "true";
        video_scale_integer = "false";
        # Mega Bezel owns the inner content ratio, within a full viewport.
        aspect_ratio_index = "24";
      });
      lcdPresentation = pkgs.writeText "retro-gba-lcd.cfg" (renderSettings {
        video_shader_enable = "true";
        video_scale_integer = "false";
        aspect_ratio_index = "22";
      });
      rawPresentation = pkgs.writeText "retro-raw.cfg" (renderSettings {
        video_shader_enable = "false";
        aspect_ratio_index = "22";
      });
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
          mkdir -p "$config_dir" "$data_dir"/{bios,saves,states,shaders}
          if [[ ! -e "$config_dir/retroarch.cfg" ]]; then
            # Seed a writable base once; rebuilding never replaces experiments.
            (set -o noclobber
              cat > "$config_dir/retroarch.cfg" <<EOF
          video_driver = "vulkan"
          savefile_directory = "$data_dir/saves"
          savestate_directory = "$data_dir/states"
          system_directory = "$data_dir/bios"
          video_shader_dir = "$data_dir/shaders"
          EOF
            ) || true
          fi
          profile_config=${ultimateController}
          presentation_config=
          shader_args=()
          while [[ $# -gt 0 ]]; do
            case "$1" in
              --profile)
                case "''${2:-}" in
                  n64) profile_config=${n64Controller} ;;
                  ultimate2) profile_config=${ultimateController} ;;
                  *) echo 'retro-play: expected --profile n64 or ultimate2' >&2; exit 2 ;;
                esac
                shift 2
                ;;
              --presentation)
                shader_args=()
                case "''${2:-}" in
                  crt)
                    presentation_config=${crtPresentation}
                    shader_args=(--set-shader ${crtPreset})
                    ;;
                  gba-lcd)
                    presentation_config=${lcdPresentation}
                    shader_args=(--set-shader ${shaders}/presets/handheld-plus-color-mod/lcd-grid-v2-gba-color.slangp)
                    ;;
                  raw) presentation_config=${rawPresentation} ;;
                  *) echo 'retro-play: expected --presentation crt, gba-lcd or raw' >&2; exit 2 ;;
                esac
                shift 2
                ;;
              *) break ;;
            esac
          done
          if [[ -n "$presentation_config" ]]; then
            profile_config+="|$presentation_config"
          fi
          exec ${lib.getExe retroarch} --config "$config_dir/retroarch.cfg" \
            --appendconfig "$profile_config" "''${shader_args[@]}" "$@"
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
      dolphin = pkgs.writeShellApplication {
        name = "retro-dolphin";
        text = ''
          adapter_mode=auto
          if [[ "''${1:-}" == --adapter ]]; then
            case "''${2:-}" in
              auto|native|configured) adapter_mode="$2" ;;
              *) echo 'retro-dolphin: expected --adapter auto, native or configured' >&2; exit 2 ;;
            esac
            shift 2
          fi
          native_adapter=false
          if [[ "$adapter_mode" == native ]]; then
            native_adapter=true
          elif [[ "$adapter_mode" == auto ]]; then
            for device in /sys/bus/usb/devices/*; do
              if [[ -r "$device/idVendor" && -r "$device/idProduct" ]] &&
                 [[ "$(<"$device/idVendor")" == 057e && "$(<"$device/idProduct")" == 0337 ]]; then
                native_adapter=true
                break
              fi
            done
          fi
          adapter_args=()
          if "$native_adapter"; then
            export SDL_JOYSTICK_HIDAPI_GAMECUBE=0
            # Dolphin's command-line layer never saves these port overrides.
            for port in 0 1 2 3; do
              adapter_args+=(-C "Dolphin.Core.SIDevice$port=12")
            done
          fi
          exec ${lib.getExe pkgs.dolphin-emu} "''${adapter_args[@]}" "$@"
        '';
      };
      xenia = pkgs.writeShellApplication {
        name = "retro-xenia";
        text = ''
          data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/hon-retro/xenia"
          cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/hon-retro/xenia"
          mkdir -p "$data_dir" "$cache_dir"
          exec ${lib.getExe pkgs.xenia-canary} \
            "--storage_root=$data_dir" "--cache_root=$cache_dir" --discord=false "$@"
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
            <rule type="staticpath"><entry>${lib.getExe dolphin}</entry></rule>
          </emulator>
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: package: ''
              <emulator name="${name}">
              <rule type="staticpath"><entry>${
                lib.getExe (if name == "XENIA" then xenia else package)
              }</entry></rule>
              </emulator>
            '') nativeEmulators
          )}
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
            bsnes
            sameboy
            genesis-plus-gx
            picodrive
            mgba
            mupen64plus
          ];
          description = "RetroArch cores installed with the retro environment.";
        };
        standalone.enable =
          lib.mkEnableOption "additional native PS2, Xbox, DS, PSP, PS3, Xbox 360, Wii U and 3DS emulators"
          // {
            default = true;
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
            dolphin
          ]
          ++ lib.attrValues nativeEmulators
          ++ lib.optional config.hon.retro.standalone.enable xenia;
        # Dolphin ships upstream USB access rules for the Wii U GameCube adapter.
        services.udev.packages = [ pkgs.dolphin-emu ];
        home-manager.users.${config.hon.user.username} = {
          xdg.dataFile = {
            "hon-retro/shaders/pinned".source = shaders;
            "hon-retro/frontend/themes/iisu-interpreted-es-de".source =
              "${theme}/share/es-de/themes/iisu-interpreted-es-de";
            "hon-retro/frontend/custom_systems/es_find_rules.xml".source = findRules;
            # Standalone Dolphin is required for the native GC adapter and Wiimotes.
            "hon-retro/frontend/custom_systems/es_systems.xml".text = ''
              <?xml version="1.0"?>
              <systemList>
                <system>
                  <name>fds</name><fullname>Nintendo Famicom Disk System</fullname>
                  <path>%ROMPATH%/fds</path>
                  <extension>.nes .NES .fds .FDS .unf .UNF .unif .UNIF .7z .7Z .zip .ZIP</extension>
                  <command label="Mesen (CRT)">%EMULATOR_RETROARCH% --presentation crt -L %CORE_RETROARCH%/mesen_libretro.so %ROM%</command>
                  <command label="Mesen (Unfiltered)">%EMULATOR_RETROARCH% --presentation raw -L %CORE_RETROARCH%/mesen_libretro.so %ROM%</command>
                  <platform>fds</platform><theme>fds</theme>
                </system>
                <system>
                  <name>n64</name><fullname>Nintendo 64</fullname>
                  <path>%ROMPATH%/n64</path>
                  <extension>.n64 .N64 .v64 .V64 .z64 .Z64 .zip .ZIP .7z .7Z</extension>
                  <command label="Mupen64Plus-Next (CRT)">%EMULATOR_RETROARCH% --profile n64 --presentation crt -L %CORE_RETROARCH%/mupen64plus_next_libretro.so %ROM%</command>
                  <command label="Mupen64Plus-Next (Unfiltered)">%EMULATOR_RETROARCH% --profile n64 --presentation raw -L %CORE_RETROARCH%/mupen64plus_next_libretro.so %ROM%</command>
                  <platform>n64</platform><theme>n64</theme>
                </system>
                <system>
                  <name>gba</name><fullname>Nintendo Game Boy Advance</fullname>
                  <path>%ROMPATH%/gba</path>
                  <extension>.agb .AGB .bin .BIN .gba .GBA .7z .7Z .zip .ZIP</extension>
                  <command label="mGBA (LCD)">%EMULATOR_RETROARCH% --presentation gba-lcd -L %CORE_RETROARCH%/mgba_libretro.so %ROM%</command>
                  <command label="mGBA (Unfiltered)">%EMULATOR_RETROARCH% --presentation raw -L %CORE_RETROARCH%/mgba_libretro.so %ROM%</command>
                  <platform>gba</platform><theme>gba</theme>
                </system>
                <system>
                  <name>gc</name><fullname>Nintendo GameCube</fullname>
                  <path>%ROMPATH%/gc</path>
                  <extension>.gcm .GCM .iso .ISO .rvz .RVZ .gcz .GCZ .wia .WIA .ciso .CISO .dol .DOL .elf .ELF .m3u .M3U</extension>
                  <command label="Dolphin (Standalone)">%EMULATOR_DOLPHIN% -b -e %ROM%</command>
                  <command label="Dolphin (Configured)">%EMULATOR_DOLPHIN% --adapter configured -b -e %ROM%</command>
                  <platform>gc</platform><theme>gc</theme>
                </system>
                <system>
                  <name>wii</name><fullname>Nintendo Wii</fullname>
                  <path>%ROMPATH%/wii</path>
                  <extension>.iso .ISO .rvz .RVZ .wbfs .WBFS .gcz .GCZ .wia .WIA .ciso .CISO .dol .DOL .elf .ELF .wad .WAD</extension>
                  <command label="Dolphin (Standalone)">%EMULATOR_DOLPHIN% -b -e %ROM%</command>
                  <command label="Dolphin (Configured)">%EMULATOR_DOLPHIN% --adapter configured -b -e %ROM%</command>
                  <platform>wii</platform><theme>wii</theme>
                </system>
                ${builtins.readFile ./retro/es_classic_systems.xml}
                ${lib.optionalString config.hon.retro.standalone.enable (
                  builtins.readFile ./retro/es_standalone_systems.xml
                )}
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
