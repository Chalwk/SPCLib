--[[
===============================================================================
SCRIPT NAME:      disable_fall_damage.lua
DESCRIPTION:      Disables fall damage on configured maps

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
               https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

--- CONFIG start -----------------------------------------
local maps = {
    ["putput"]         = { "game_mode_here", "another_game_mode" },
    ["wizard"]         = { "game_mode_here" },
    ["longest"]        = { "game_mode_here" },
    ["ratrace"]        = { "game_mode_here" },
    ["carousel"]       = { "game_mode_here" },
    ["infinity"]       = { "game_mode_here" },
    ["chillout"]       = { "game_mode_here" },
    ["prisoner"]       = { "game_mode_here" },
    ["damnation"]      = { "game_mode_here" },
    ["icefields"]      = { "game_mode_here" },
    ["bloodgulch"]     = { "game_mode_here" },
    ["hangemhigh"]     = { "game_mode_here" },
    ["sidewinder"]     = { "game_mode_here" },
    ["timberland"]     = { "game_mode_here" },
    ["beavercreek"]    = { "game_mode_here" },
    ["deathisland"]    = { "game_mode_here" },
    ["dangercanyon"]   = { "game_mode_here" },
    ["gephyrophobia"]  = { "game_mode_here" },
    ["boardingaction"] = { "game_mode_here" }
}
-- CONFIG end -----------------------------------------

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    execute_command("cheat_jetpack false")

    local map  = get_var(0, "$map")
    local mode = get_var(0, "$mode")

    if maps[map] then
        for _, gametype in ipairs(maps[map]) do
            if mode == gametype then
                execute_command("cheat_jetpack true")
                break
            end
        end
    end
end

function OnScriptUnload() end
