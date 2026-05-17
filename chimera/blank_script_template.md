# Chimera Blank Script Template

Every Chimera Lua script **must** define `clua_version` and set it to the API-specific version (e.g. `2.056`). Without
this, the script will not load.

```lua
clua_version = 2.056 -- * required: tells Chimera which API version you expect

set_callback("command", "OnCommand")
set_callback("frame", "OnFrame")
set_callback("map load", "OnMapLoad")
set_callback("map_preload", "OnMapPreload")
set_callback("precamera", "OnPreCamera")
set_callback("preframe", "OnPreFrame")
set_callback("prespawn", "OnPreSpawn")
set_callback("pretick", "OnPreTick")
set_callback("rcon_message", "OnRconMessage")
set_callback("spawn", "OnSpawn")
set_callback("tick", "OnTick")
set_callback("unload", "OnScriptUnload")

function OnCommand(cmd)
    -- called when you type a command in the console (press ~ key)
end

function OnFrame()
    -- called after preframe, once per rendered frame
end

function OnMapLoad()
    -- called after the map has fully loaded (reset or init gameplay state here)
end

function OnMapPreload(map_name)
    -- called before a map fully loads (early initialization point)
end

function OnPreCamera()
    -- called right before camera calculations are applied
end

function OnPreFrame()
    -- called before rendering each frame
end

function OnPreSpawn(player)
    -- called before a player spawns
end

function OnPreTick()
    -- called just before the main tick update
end

function OnRconMessage(msg)
    -- called when an incoming RCON message is received; return false to block it
end

function OnSpawn(player)
    -- called when a player finishes spawning
end

function OnTick()
    -- called ~30 times per second (main gameplay update loop)
end

function OnScriptUnload()
    -- called when the script is unloaded
end
```

---
