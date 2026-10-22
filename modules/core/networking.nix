{
  flake.nixosModules.networking = { config, ... }: {
    networking.networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
    networking.nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNSOverTLS = "opportunistic";
        Domains = [ "~." ];
      };
    };
    users.users.${config.hon.user.username}.extraGroups = [ "networkmanager" ];
  };
}
