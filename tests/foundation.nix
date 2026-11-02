{ flake, pkgs }:
let
  inherit (pkgs) lib;
  host = flake.nixosConfigurations.midgar;
  config = host.config;
  monitors = config.hon.monitors;
  hostPkgs = host.pkgs;
  home = config.home-manager.users.${config.hon.user.username};
  primaryMessage = "hon.monitors must have exactly one primary monitor when nonempty.";
  duplicateMessage = "hon.monitors connector names must be unique.";

  rejectsMonitors =
    values: message:
    let
      changed = host.extendModules {
        modules = [ { hon.monitors = lib.mkForce values; } ];
      };
    in
    builtins.any (entry: entry.message == message && !entry.assertion) changed.config.assertions;

  packageProbe = host.extendModules {
    modules = [
      ({ pkgsStable, ... }: {
        options.validation.stableVersion = lib.mkOption {
          type = lib.types.str;
          default = pkgsStable.lib.version;
        };
      })
    ];
  };

  failures = lib.runTests {
    testStableModuleArgument = {
      expr = lib.hasPrefix "26.05" packageProbe.config.validation.stableVersion;
      expected = true;
    };
    testNoPrimaryRejected = {
      expr = rejectsMonitors (map (monitor: monitor // { primary = false; }) monitors) primaryMessage;
      expected = true;
    };
    testMultiplePrimariesRejected = {
      expr = rejectsMonitors (map (monitor: monitor // { primary = true; }) monitors) primaryMessage;
      expected = true;
    };
    testDuplicateConnectorsRejected = {
      expr = rejectsMonitors [ (builtins.head monitors) (builtins.head monitors) ] duplicateMessage;
      expected = true;
    };
    testDiskoOwnsFilesystems = {
      expr = map (mount: config.fileSystems.${mount}.fsType) [
        "/"
        "/home"
        "/nix"
        "/boot"
      ];
      expected = [
        "btrfs"
        "btrfs"
        "btrfs"
        "vfat"
      ];
    };
    testHomeManagerFeatureComposition = {
      expr =
        let
          home = config.home-manager.users.${config.hon.user.username};
        in
        home.programs.zsh.oh-my-zsh.enable
        && home.programs.pay-respects.enable
        && builtins.any (plugin: plugin.name == "powerlevel10k") home.programs.zsh.plugins;
      expected = true;
    };
    testJavaDefaultWithoutExecutableCollisions = {
      expr =
        toString config.programs.java.package == toString hostPkgs.zulu25
        &&
          builtins.all
            (jdk: !(builtins.elem jdk.name (map (package: package.name) config.environment.systemPackages)))
            [
              hostPkgs.zulu8
              hostPkgs.zulu17
              hostPkgs.zulu21
            ]
        &&
          map (version: toString config.environment.etc."jdks/${version}".source) [
            "8"
            "17"
            "21"
            "25"
          ] == map toString [
            hostPkgs.zulu8
            hostPkgs.zulu17
            hostPkgs.zulu21
            hostPkgs.zulu25
          ];
      expected = true;
    };
    testOnePasswordOwnsSshAndSigning = {
      expr =
        home.programs.ssh.settings."*".data.IdentityAgent == "~/.1password/agent.sock"
        && !config.programs.ssh.startAgent
        && !config.services.gnome.gcr-ssh-agent.enable
        && !home.services.ssh-agent.enable
        && home.programs.git.signing.format == "ssh"
        && home.programs.git.signing.signByDefault
        &&
          home.programs.git.signing.signer == lib.getExe' config.programs._1password-gui.package "op-ssh-sign"
        && home.programs.git.settings.user.name == config.hon.user.name
        && home.programs.git.settings.user.email == config.hon.user.email;
      expected = true;
    };
    testNativeAppImageRegistration = {
      expr =
        builtins.all
          (
            name:
            config.boot.binfmt.registrations.${name}.interpreter == lib.getExe config.programs.appimage.package
          )
          [
            "appimage_type_1"
            "appimage_type_2"
          ];
      expected = true;
    };
    testFeatureGroupsMerge = {
      expr =
        builtins.all (group: builtins.elem group config.users.users.${config.hon.user.username}.extraGroups)
          [
            "wheel"
            "networkmanager"
            "libvirtd"
          ];
      expected = true;
    };
  };
in
assert lib.assertMsg (failures == [ ]) "Foundation checks failed: ${builtins.toJSON failures}";
pkgs.runCommand "hon-nix-foundation-checks" { } ''
  touch "$out"
''
