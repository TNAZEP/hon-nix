{
  flake.nixosModules.hyprlandMonitors =
    { config, lib, ... }:
    let
      monitors = config.hon.monitors;
      ordered = builtins.filter (m: m.primary) monitors ++ builtins.filter (m: !m.primary) monitors;
      workspaces = lib.concatLists (
        lib.imap0 (
          index: monitor:
          builtins.genList (localIndex: {
            id = index * 10 + localIndex + 1;
            label = localIndex + 1;
            monitor = monitor.name;
          }) 10
        ) ordered
      );
    in
    {
      options.hon.workspaces = lib.mkOption {
        readOnly = true;
        description = "Authoritative workspace IDs and monitor-local labels for the compositor and shell.";
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              id = lib.mkOption { type = lib.types.ints.positive; };
              label = lib.mkOption { type = lib.types.ints.between 1 10; };
              monitor = lib.mkOption { type = lib.types.str; };
            };
          }
        );
      };
      config = {
        hon.workspaces = workspaces;
        home-manager.users.${config.hon.user.username}.wayland.windowManager.hyprland = {
          settings = {
            monitor = map (
              m:
              {
                output = m.name;
                mode = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
                position = "${toString m.x}x${toString m.y}";
                scale = toString m.scale;
              }
              // lib.optionalAttrs (m.bitDepth != null) { bitdepth = m.bitDepth; }
            ) monitors;
            workspace_rule = map (workspace: {
              workspace = toString workspace.id;
              inherit (workspace) monitor;
              default = workspace.label == 1;
              persistent = true;
            }) workspaces;
          };
          extraLuaFiles.workspaces = {
            autoLoad = true;
            content =
              "local workspaces = ${lib.generators.toLua { } workspaces}\n" + builtins.readFile ./workspaces.lua;
          };
        };
      };
    };
}
