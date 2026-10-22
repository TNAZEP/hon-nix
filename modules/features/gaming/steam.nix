{
  flake.nixosModules.steam = { pkgs, ... }: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
    };
    programs.gamemode.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      protontricks
      protonup-qt
      faugus-launcher
      lsfg-vk
      lsfg-vk-ui
      heroic
    ];
  };
}
