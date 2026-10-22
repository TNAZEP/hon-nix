{
  flake.nixosModules.honShell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      session = "wayland-session@hyprland.desktop.target";
      data = {
        inherit (config.hon) workspaces monitors;
        inherit (config.hon.appearance) palette;
        font = config.hon.appearance.font.sans;
        terminal = config.hon.desktop.terminal;
        keyboard = config.hon.locale.keyboard;
        commands = {
          lock = [
            "loginctl"
            "lock-session"
          ];
          logout = [
            "uwsm"
            "stop"
          ];
          suspend = [
            "systemctl"
            "suspend"
          ];
          reboot = [
            "systemctl"
            "reboot"
          ];
          shutdown = [
            "systemctl"
            "poweroff"
          ];
          bluetoothPair = [ "bluedevil-wizard" ];
          bluetoothSettings = [
            "kcmshell6"
            "kcm_bluetooth"
          ];
          networkSettings = [
            "kcmshell6"
            "kcm_networkmanagement"
          ];
          hyprctl = "hyprctl";
          brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
        };
      };
      settings = pkgs.writeText "hon-shell-settings.qml" ''
        import QtQml
        QtObject {
          readonly property var values: (${builtins.toJSON data})
        }
      '';
      source = pkgs.runCommand "hon-shell" { } ''
        mkdir -p "$out"
        cp -r ${./src}/. "$out/"
        chmod -R u+w "$out"
        cp ${settings} "$out/theme/Settings.qml"
      '';
      bind = key: method: {
        _args = [
          key
          (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON "${pkgs.quickshell}/bin/qs --config hon-shell ipc call shell ${method}"})")
        ];
      };
    in
    {
      services.upower.enable = true;
      home-manager.users.${config.hon.user.username} = {
        home.packages = [ pkgs.quickshell ];
        xdg.configFile."quickshell/hon-shell".source = source;
        systemd.user.services.hon-shell = {
          Unit = {
            Description = "hon-shell desktop shell";
            PartOf = [ session ];
            After = [ session ];
            X-Restart-Triggers = [ "${source}" ];
          };
          Service = {
            ExecStart = "${pkgs.quickshell}/bin/qs --config hon-shell";
            Restart = "on-failure";
            RestartSec = 2;
            Environment = [
              "PATH=${
                lib.makeBinPath [
                  pkgs.systemd
                  pkgs.uwsm
                  pkgs.kdePackages.kde-cli-tools
                  pkgs.kdePackages.bluedevil
                  config.programs.hyprland.package
                ]
              }:/etc/profiles/per-user/${config.hon.user.username}/bin:/run/current-system/sw/bin"
            ];
          };
          Install.WantedBy = [ session ];
        };
        wayland.windowManager.hyprland.settings.bind = [
          (bind "SUPER + SPACE" "launcher")
          (bind "SUPER + SHIFT + SPACE" "power")
          (bind "SUPER + A" "controls")
          (bind "SUPER + N" "notifications")
        ];
      };
    };
}
