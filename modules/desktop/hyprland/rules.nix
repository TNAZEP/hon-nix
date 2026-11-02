{
  flake.nixosModules.hyprlandRules = { config, ... }: {
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
      ];
  };
}
