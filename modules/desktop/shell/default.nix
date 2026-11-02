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
        font = config.hon.appearance.font.monospace;
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
          awww = "${pkgs.awww}/bin/awww";
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
        home.packages = [
          pkgs.quickshell
          pkgs.awww
        ];
        systemd.user.services.hon-wallpaper = {
          Unit = {
            Description = "awww wallpaper daemon";
            PartOf = [ session ];
            After = [ session ];
          };
          Service = {
            ExecStart = "${pkgs.awww}/bin/awww-daemon";
            ExecStartPost = pkgs.writeShellScript "wait-for-awww" ''
              for attempt in {1..50}; do
                ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && exit 0
                ${pkgs.coreutils}/bin/sleep 0.1
              done
              exit 1
            '';
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ session ];
        };
        xdg.configFile."quickshell/hon-shell".source = source;
        systemd.user.services.hon-shell = {
          Unit = {
            Description = "hon-shell desktop shell";
            PartOf = [ session ];
            After = [
              session
              "hon-wallpaper.service"
            ];
            Wants = [ "hon-wallpaper.service" ];
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
