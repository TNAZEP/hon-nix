{
  flake.nixosModules.hyprlandRules =
    { config, lib, ... }:
    let
      primaryMonitor = lib.findFirst (
        monitor: monitor.primary
      ) (builtins.head config.hon.monitors) config.hon.monitors;
    in
    {
      home-manager.users.${config.hon.user.username}.wayland.windowManager.hyprland.settings.window_rule =
        [
          {
            name = "audio-controls";
            match.class = "org.pulseaudio.pavucontrol";
            float = true;
            size = "800 600";
          }
          {
            name = "browser-workspace";
            match.class = "firefox";
            workspace = "1 silent";
          }
          {
            name = "chat-workspace";
            match.class = "vesktop";
            workspace = "2 silent";
          }
          {
            name = "steam-workspace";
            match.class = "steam";
            workspace = "5 silent";
          }
          {
            name = "world-of-warcraft";
            match = {
              # Faugus assigns a launcher-specific steam_app_ ID.
              class = "^steam_app_.*$";
              initial_title = "^World of Warcraft$";
            };
            monitor = primaryMonitor.name;
            workspace = "3";
            fullscreen = true;
          }
        ];
    };
}
