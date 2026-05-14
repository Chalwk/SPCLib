--[[
=====================================================================================
SCRIPT NAME:      remove_grenades.lua
DESCRIPTION:      Removes grenades after spawn on a per-gamemode basis.

FEATURES:
                  - Removes grenades after player spawn
                  - Configurable per gamemode
                  - Preserves grenade pickups (only removes spawned grenades)

CONFIGURATION:
                  modes:            Table of gamemodes where grenades should be disabled
                                   Format: ["Gamemode Name"] = true/false

USAGE:
                  Add gamemodes to the 'modes' table at the top of the script
                  Script will automatically handle grenade removal during gameplay

LIMITATIONS:
                  Does not prevent players from picking up grenades
                  Only removes grenades after spawn

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local modes = {

    --
    -- Simply list all of the game modes you want this script to disable grenades on.
    -- [MODE NAME] = ENABLED/DISABLED (true/false)
    --

    ["FFA Swat"] = true,
    ["put game mode here"] = true,
}

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then

        local mode = get_var(0, "$mode")
        if (modes[mode]) then
            register_callback(cb.EVENT_SPAWN, "OnSpawn")
            cprint('Disabling grenades', 10)
            return true
        end
        unregister_callback(cb.EVENT_SPAWN)
    end
end

function OnSpawn(Ply)
    execute_command('nades ' .. Ply .. ' 0')
end