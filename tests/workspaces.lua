local active_monitor
local dispatched
hl = {
    get_active_monitor = function() return active_monitor end,
    dispatch = function(action) dispatched = action end,
    dsp = {
        focus = function(args) return { kind = "focus", id = args.workspace } end,
        window = {
            move = function(args) return { kind = "move", id = args.workspace } end,
        },
    },
}

local workspaces = assert(loadfile(arg[1]))()
local function expect(kind, id)
    assert(dispatched and dispatched.kind == kind and dispatched.id == id,
        "unexpected workspace dispatch: expected " .. kind .. " " .. id)
    dispatched = nil
end

for _, monitor in ipairs({ { name = "DP-1", first = 1 }, { name = "DP-2", first = 11 } }) do
    active_monitor = { name = monitor.name, active_workspace = { id = monitor.first } }
    for label = 1, 10 do
        workspaces.focus(label)
        expect("focus", monitor.first + label - 1)
        workspaces.focus(label, true)
        expect("move", monitor.first + label - 1)
    end
    workspaces.cycle(-1)
    expect("focus", monitor.first + 9)
    active_monitor.active_workspace.id = monitor.first + 9
    workspaces.cycle(1)
    expect("focus", monitor.first)
    active_monitor.active_workspace.id = monitor.first + 4
    workspaces.cycle(1)
    expect("focus", monitor.first + 5)
    workspaces.focus(0)
    assert(dispatched == nil)
    workspaces.focus(11)
    assert(dispatched == nil)
end

-- No focused display or an unconfigured hotplugged display must not steal
-- workspaces from a configured monitor.
active_monitor = nil
workspaces.focus(1)
workspaces.cycle(1)
assert(dispatched == nil)
active_monitor = { name = "HDMI-A-1" }
workspaces.focus(1, true)
workspaces.cycle(-1)
assert(dispatched == nil)
print("Workspace focus, movement, cycling, and missing-monitor checks passed")
