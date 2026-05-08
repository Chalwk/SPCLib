--[[
===============================================================================
SCRIPT NAME:      command_spy.lua
DESCRIPTION:      Command execution alerts

FEATURES:         - Customizable admin notification levels
                  - Sensitive command filtering

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config start --------------------------------------------
local NOTIFICATION = "[SPY] $name: $cmd"

-- Admin levels allowed to see spy messages:
local SPY_LEVELS = {
    [1] = false,
    [2] = false,
    [3] = false,
    [4] = true
}

-- Blacklisted commands that will not be monitored:
local BLACKLIST = {
    ["login"] = true,
    ["admin_add"] = true,
    ["sv_password"] = true,
    ["change_password"] = true,
    ["admin_change_pw"] = true,
    ["admin_add_manually"] = true
}
-- Config end ----------------------------------------------

local players = {}

api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb['EVENT_JOIN'], "OnJoin")
    register_callback(cb['EVENT_LEAVE'], "OnQuit")
    register_callback(cb['EVENT_COMMAND'], "OnCommand")
    register_callback(cb['EVENT_GAME_START'], "OnStart")
    OnStart() -- incase script is loaded mid game
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    players = {}
    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnJoin(id)
    players[id] = {
        name = get_var(id, "$name"),
        level = function()
            return tonumber(get_var(id, "$lvl")) or 0
        end
    }
end

function OnQuit(id)
    players[id] = nil
end

local function isBlacklisted(cmd)
    cmd = cmd:lower():match("^(%S+)")
    return BLACKLIST[cmd]
end

function OnCommand(id, command)
    if id > 0 then
        if isBlacklisted(command) then return end

        for i = 1, 16 do
            if player_present(i) then
                local player = players[i]
                if player and SPY_LEVELS[player.level()] and i ~= id then
                    local msg = NOTIFICATION
                    msg = msg:gsub("$name", players[id].name)
                    msg = msg:gsub("$cmd", command)
                    rprint(i, msg)
                end
            end
        end
    end
end

function OnScriptUnload() end