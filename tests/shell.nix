{ flake, pkgs }:
let
  config = flake.nixosConfigurations.midgar.config;
  home = config.home-manager.users.${config.hon.user.username};
  service = home.systemd.user.services.hon-shell;
  session = "wayland-session@hyprland.desktop.target";
  source = home.xdg.configFile."quickshell/hon-shell".source;
  # With no physical mouse, Qt must bind the newly advertised pointer before
  # wlrctl sends its first click. The upstream tool sends both in one roundtrip.
  testPointer = pkgs.wlrctl.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace pointer.c \
        --replace-fail '#include <assert.h>' '#include <assert.h>
      #include <poll.h>' \
        --replace-fail 'pointer_press(cmd->device, cmd->button);' 'wl_display_roundtrip(state->display);
      poll(NULL, 0, 250);
      pointer_press(cmd->device, cmd->button);'
    '';
  });
in
assert service.Unit.PartOf == [ session ];
assert service.Install.WantedBy == [ session ];
assert service.Unit.X-Restart-Triggers == [ "${source}" ];
pkgs.runCommand "hon-shell-checks"
  {
    nativeBuildInputs = with pkgs; [
      quickshell
      sway
      wtype
      testPointer
      dbus
      glib
      python3
      pipewire
    ];
  }
  ''
    mkdir harness
    cp ${./shell.py} harness/shell.py
    cp ${./WifiHarness.qml} harness/WifiHarness.qml
    cp ${./BluetoothHarness.qml} harness/BluetoothHarness.qml
    python harness/shell.py ${source}
    touch "$out"
  ''
