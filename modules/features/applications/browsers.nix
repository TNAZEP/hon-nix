{
  flake.nixosModules.browsers = { config, ... }: {
    home-manager.users.${config.hon.user.username} = {
      programs.firefox = {
        enable = true;
        configPath = ".mozilla/firefox";
        policies = {
          DisableTelemetry = true;
          DisablePocket = true;
        };
        profiles.default = {
          isDefault = true;
          settings = {
            "toolkit.telemetry.enabled" = false;
            "signon.rememberSignons" = false;
            "browser.formfill.enable" = false;
            "browser.search.suggest.enabled" = true;
            "browser.aboutConfig.showWarning" = false;
            "browser.discovery.enabled" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
            "extensions.htmlaboutaddons.recommendations.enabled" = false;
          };
        };
      };
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = [ "firefox.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
        };
      };
    };
  };
}
