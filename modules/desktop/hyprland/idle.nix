{
  flake.nixosModules.hyprlandIdle =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      palette = config.hon.appearance.palette;
      rgb = color: "rgb(${lib.removePrefix "#" color})";
      hyprctl = "${config.programs.hyprland.package}/bin/hyprctl";
      dpms = action: "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"${action}\" })'";
      lock = "${pkgs.systemd}/bin/loginctl lock-session";
    in
    {
      programs.hyprlock.enable = true;
      home-manager.users.${config.hon.user.username} = {
        services.hypridle = {
          enable = true;
          systemdTarget = "wayland-session@hyprland.desktop.target";
          settings = {
            general = {
              lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
              before_sleep_cmd = lock;
              after_sleep_cmd = dpms "on";
            };
            listener = [
              {
                timeout = 480;
                on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl --class=backlight -s set 10%";
                on-resume = "${pkgs.brightnessctl}/bin/brightnessctl --class=backlight -r";
              }
              {
                timeout = 600;
                on-timeout = lock;
              }
              {
                timeout = 630;
                on-timeout = dpms "off";
                on-resume = dpms "on";
              }
              {
                timeout = 7200;
                on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
              }
            ];
          };
        };
        programs.hyprlock = {
          enable = true;
          settings = {
            general.hide_cursor = true;
            background = [
              {
                monitor = "";
                color = rgb palette.bg;
              }
            ];
            input-field = [
              {
                monitor = "";
                size = "300, 50";
                outline_thickness = 2;
                rounding = 0;
                outer_color = rgb palette.border;
                inner_color = rgb palette.bgAlt;
                font_color = rgb palette.fg;
                check_color = rgb palette.accentAlt;
                fail_color = rgb palette.error;
                font_family = config.hon.appearance.font.monospace;
                placeholder_text = "Password…";
                position = "0, -20";
                halign = "center";
                valign = "center";
              }
            ];
            label = [
              {
                monitor = "";
                text = "$TIME";
                font_size = 90;
                font_family = config.hon.appearance.font.monospace;
                color = rgb palette.fg;
                position = "0, 150";
                halign = "center";
                valign = "center";
              }
            ];
          };
        };
      };
    };
}
