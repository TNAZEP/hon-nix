{
  flake.nixosModules.hyprlandInput = { config, ... }: {
    home-manager.users.${config.hon.user.username}.wayland.windowManager.hyprland.settings.config = {
      input = {
        kb_layout = config.hon.locale.keyboard;
        numlock_by_default = true;
        repeat_delay = 250;
        repeat_rate = 35;
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          clickfinger_behavior = true;
          scroll_factor = 0.5;
        };
      };
      binds.scroll_event_delay = 0;
    };
  };
}
