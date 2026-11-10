clua_version = 2.056

-- Callback Registration
set_callback("command", "OnCommand")
set_callback("frame", "OnFrame")
set_callback("map load", "OnMapLoad")
set_callback("map preload", "OnMapPreload")
set_callback("precamera", "OnPreCamera")
set_callback("preframe", "OnPreFrame")
set_callback("prespawn", "OnPreSpawn")
set_callback("pretick", "OnPreTick")
set_callback("rcon_message", "OnRconMessage")
set_callback("spawn", "OnSpawn")
set_callback("tick", "OnTick")
set_callback("unload", "OnScriptUnload")

-- Called when a command is typed into the console.
-- Open the console with the `~` key.
---@param cmd string The command entered into the console
function OnCommand(cmd) end

-- Called once per rendered frame.
-- Runs after `preframe`.
function OnFrame() end

-- Called before rendering each frame.
function OnPreFrame() end

-- Called immediately before camera calculations are applied.
---@param x number
---@param y number
---@param z number
---@param fov number
---@param ox1 number
---@param oy1 number
---@param oz1 number
---@param ox2 number
---@param oy2 number
---@param oz2 number
---@return number, number, number, number, number, number, number, number, number, number
function OnPreCamera(x, y, z, fov, ox1, oy1, oz1, ox2, oy2, oz2)
    return x, y, z, fov, ox1, oy1, oz1, ox2, oy2, oz2
end

-- Called approximately 30 times per second.
-- Main gameplay update loop.
function OnTick() end

-- Called immediately before the main tick update.
function OnPreTick() end

-- Called before a map begins loading.
function OnMapPreload() end

-- Called after a map has fully loaded.
-- Use this to reset or initialize gameplay state.
function OnMapLoad() end

-- Called before a player spawns.
---@param player number The player index
function OnPreSpawn(player) end

-- Called when a player finishes spawning.
---@param player number The player index
function OnSpawn(player) end

-- Called when an incoming RCON message is received.
---@param msg string The RCON message
---@return boolean|nil allow # Return `false` to block the message
function OnRconMessage(msg) return true end

-- Called when the script is unloaded.
function OnScriptUnload() end