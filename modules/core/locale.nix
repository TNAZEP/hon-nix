{
  flake.nixosModules.locale = { config, ... }: {
    time.timeZone = config.hon.locale.timezone;
    i18n.defaultLocale = config.hon.locale.language;
    console.keyMap = config.hon.locale.consoleKeyMap;
    services.xserver.xkb.layout = config.hon.locale.keyboard;
  };
}
