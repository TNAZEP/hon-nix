{
  flake.nixosModules.theming =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      appearance = config.hon.appearance;
    in
    {
      options.hon.appearance.palette = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        description = "Shared Kanagawa Dragon colors for directly owned desktop UI.";
      };
      config = {
        hon.appearance.palette = {
          bg = "#181616";
          bgAlt = "#252525";
          fg = "#c5c9c5";
          muted = "#a6a69c";
          accent = "#c4746e";
          accentAlt = "#e46876";
          error = "#e82424";
          warning = "#e98a00";
          border = "#a6a69c";
          borderInactive = "#353535";
        };

        fonts.packages = with pkgs; [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          nerd-fonts.jetbrains-mono
          nerd-fonts.fira-code
          nerd-fonts.bigblue-terminal
        ];
        fonts.fontconfig.defaultFonts = {
          sansSerif = [ appearance.font.sans ];
          monospace = [ appearance.font.monospace ];
        };

        home-manager.users.${config.hon.user.username} = { lib, ... }: {
          # Apply the complete KDE color scheme, including its Colors:* groups.
          # Setting only General/ColorScheme is insufficient outside Plasma.
          home.activation.breezeDark = lib.hm.dag.entryBetween [ "kconfig" ] [ "writeBoundary" ] ''
            run env QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
              XDG_DATA_DIRS="${pkgs.kdePackages.breeze}/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}" \
              ${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme BreezeDark
          '';
          qt = {
            enable = true;
            platformTheme.name = "kde";
            style.name = "breeze";
            kde.settings = {
              # KDED 6 still reads kded5rc. Home Manager owns GTK settings;
              # avoid KDE's late GTK/XSettings rewrite when Dolphin starts
              # KDED, which coincides with GTK client crashes in Hyprland.
              kded5rc."Module-gtkconfig".autoload = false;
              kdeglobals = {
                General = {
                  ColorScheme = "BreezeDark";
                  font = "${appearance.font.sans},10,-1,5,50,0,0,0,0,0";
                  fixed = "${appearance.font.monospace},10,-1,5,50,0,0,0,0,0";
                };
                KDE.widgetStyle = "Breeze";
                Icons.Theme = appearance.icons;
              };
              kcminputrc.Mouse = {
                cursorTheme = appearance.cursor.name;
                cursorSize = appearance.cursor.size;
              };
              plasmarc.Theme.name = "breeze-dark";
            };
          };
          gtk = {
            enable = true;
            colorScheme = "dark";
            theme = {
              name = "Breeze-Dark";
              package = pkgs.kdePackages.breeze-gtk;
            };
            iconTheme = {
              name = appearance.icons;
              package = pkgs.papirus-icon-theme;
            };
            font = {
              name = appearance.font.sans;
              size = 10;
            };
            gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
            gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
            gtk4.theme = null;
          };
          home.pointerCursor = {
            enable = true;
            name = appearance.cursor.name;
            size = appearance.cursor.size;
            package = pkgs.kdePackages.breeze;
            gtk.enable = true;
            x11.enable = true;
          };
          xdg.userDirs = {
            enable = true;
            createDirectories = true;
            setSessionVariables = false;
          };
        };
      };
    };
}
