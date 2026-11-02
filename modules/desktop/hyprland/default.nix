{ inputs, ... }:
{
  flake.nixosModules.hyprland =
    {
      config,
      lib,
      pkgs,
      pkgsStable,
      ...
    }:
    let
      # The upstream Hyprland overlay omits the toolkit overlay. Include its
      # locked revision so GUI utilities do not mix newer nixpkgs toolkit APIs
      # with the compositor's older, pinned hyprutils.
      hyprlandPkgs = pkgs.extend (
        lib.composeManyExtensions [
          inputs.hyprland.overlays.hyprland-packages
          inputs.hyprland.inputs.hyprland-guiutils.inputs.hyprtoolkit.overlays.default
          inputs.hyprland.overlays.hyprland-extras
          # Hyprland 0.56 requires Glaze 7; unstable has already moved to 8.
          (_final: _prev: {
            glaze-hyprland = pkgsStable.glaze.override {
              enableSSL = false;
              enableInterop = false;
            };
          })
        ]
      );
      palette = config.hon.appearance.palette;
      rgb = color: "rgb(${lib.removePrefix "#" color})";
    in
    {
      imports = with inputs.self.nixosModules; [
        hyprlandMonitors
        hyprlandInput
        hyprlandKeybinds
        hyprlandRules
        hyprlandIdle
      ];
      programs.hyprland = {
        enable = true;
        withUWSM = true;
        package = hyprlandPkgs.hyprland;
        portalPackage = hyprlandPkgs.xdg-desktop-portal-hyprland;
      };
      services.displayManager.defaultSession = "hyprland-uwsm";
      security.polkit.enable = true;

      home-manager.users.${config.hon.user.username} = {
        wayland.windowManager.hyprland = {
          enable = true;
          package = null;
          portalPackage = null;
          configType = "lua";
          systemd.enable = false; # UWSM owns the session and its lifetime.
          settings.config = {
            general = {
              gaps_in = 4;
              gaps_out = 8;
              border_size = 2;
              col.active_border = rgb palette.border;
              col.inactive_border = rgb palette.borderInactive;
              resize_on_border = true;
              layout = "dwindle";
              allow_tearing = true;
            };
            dwindle.preserve_split = true;
            decoration = {
              rounding = 0;
              blur.enabled = false;
              shadow = {
                enabled = true;
                range = 20;
                render_power = 4;
                color = "rgba(0000002a)";
              };
            };
            misc = {
              vrr = 2;
              disable_hyprland_logo = true;
              force_default_wallpaper = 0;
            };
            render = {
              cm_enabled = true;
              cm_auto_hdr = 2;
            };
            animations.enabled = true;
          };
          extraConfig = ''
            hl.curve("hon_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
            hl.curve("hon_accel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
            hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "hon_decel", style = "popin 60%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "hon_accel", style = "popin 60%" })
            hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "hon_decel" })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "hon_decel", style = "slide" })
            hl.on("hyprland.start", function()
              hl.exec_cmd("${pkgs.uwsm}/bin/uwsm finalize")
            end)
          '';
        };
        systemd.user.services.hon-polkit-agent = {
          Unit = {
            Description = "KDE authentication agent for Hyprland";
            PartOf = [ "wayland-session@hyprland.desktop.target" ];
            After = [ "wayland-session@hyprland.desktop.target" ];
          };
          Service = {
            ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
            Restart = "on-failure";
          };
          Install.WantedBy = [ "wayland-session@hyprland.desktop.target" ];
        };
      };
    };
}
