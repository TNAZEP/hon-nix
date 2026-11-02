{
  flake.nixosModules.hyprlandKeybinds =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      lua = lib.generators.mkLuaInline;
      bind = key: action: {
        _args = [
          key
          (lua action)
        ];
      };
      exec = key: command: bind key "hl.dsp.exec_cmd(${builtins.toJSON command})";
      app = key: command: exec key "${pkgs.uwsm}/bin/uwsm app -- ${command}";
      media = key: command: {
        _args = [
          key
          (lua "hl.dsp.exec_cmd(${builtins.toJSON command})")
          {
            locked = true;
            repeating = true;
          }
        ];
      };
      wpctl = "${pkgs.wireplumber}/bin/wpctl";
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
      playerctl = "${pkgs.playerctl}/bin/playerctl";
    in
    {
      environment.systemPackages = [
        pkgs.hyprshot
        pkgs.brightnessctl
        pkgs.playerctl
      ];
      home-manager.users.${config.hon.user.username}.wayland.windowManager.hyprland.settings.bind = [
        (bind "SUPER + Q" "hl.dsp.window.close()")
        (exec "SUPER + M" "${pkgs.uwsm}/bin/uwsm stop")
        (exec "SUPER + L" "${pkgs.systemd}/bin/loginctl lock-session")
        (bind "SUPER + W" "hl.dsp.window.float({ action = 'toggle' })")
        (bind "SUPER + P" "hl.dsp.window.pseudo()")
        (bind "SUPER + J" "hl.dsp.layout('togglesplit')")
        (bind "SUPER + SHIFT + F" "hl.dsp.window.fullscreen({ action = 'toggle' })")
        (exec "SUPER + SHIFT + S" "${pkgs.hyprshot}/bin/hyprshot --mode region")
        (app "SUPER + RETURN" config.hon.desktop.terminal)
        (app "SUPER + E" config.hon.desktop.fileManager)
        (app "SUPER + F" config.hon.desktop.browser)
        (app "SUPER + C" config.hon.desktop.editor)
        (bind "SUPER + mouse_down" "function() require('workspaces').cycle(1) end")
        (bind "SUPER + mouse_up" "function() require('workspaces').cycle(-1) end")
        {
          _args = [
            "SUPER + mouse:272"
            (lua "hl.dsp.window.drag()")
            { mouse = true; }
          ];
        }
        {
          _args = [
            "SUPER + mouse:273"
            (lua "hl.dsp.window.resize()")
            { mouse = true; }
          ];
        }
        (media "XF86AudioRaiseVolume" "${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
        (media "XF86AudioLowerVolume" "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-")
        (media "XF86AudioMute" "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle")
        (media "XF86AudioMicMute" "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
        (media "XF86MonBrightnessUp" "${brightnessctl} --class=backlight -e4 -n2 set 5%+")
        (media "XF86MonBrightnessDown" "${brightnessctl} --class=backlight -e4 -n2 set 5%-")
        (media "XF86AudioNext" "${playerctl} next")
        (media "XF86AudioPrev" "${playerctl} previous")
        (media "XF86AudioPlay" "${playerctl} play-pause")
        (media "XF86AudioPause" "${playerctl} play-pause")
      ]
      ++ map (direction: bind "SUPER + ${direction}" "hl.dsp.focus({ direction = '${direction}' })") [
        "left"
        "right"
        "up"
        "down"
      ]
      ++ lib.concatMap (
        label:
        let
          key = if label == 10 then "0" else toString label;
        in
        [
          (bind "SUPER + ${key}" "function() require('workspaces').focus(${toString label}) end")
          (bind "SUPER + SHIFT + ${key}" "function() require('workspaces').focus(${toString label}, true) end")
        ]
      ) (lib.range 1 10);
    };
}
