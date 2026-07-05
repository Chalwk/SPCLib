--[[
===============================================================================
SCRIPT NAME:      tactical_insert.lua
DESCRIPTION:      Allows players to set a custom respawn point using /tac.
                  Point can be toggled, cleared, or checked; one-time or persistent.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG start ----------------------------------------------------------------------------
local COMMAND = "tac"         -- chat command
local ONE_TIME_USE = true     -- if true, point is cleared after first use
local DELETE_ON_DEATH = false -- if true, point is cleared on death (overrides ONE_TIME_USE)
-- CONFIG end ------------------------------------------------------------------------------

local player_data = {}

local function parse_cmd(s)
    s = s:gsub("^[\\/]+", "")
    local args = {}
    for w in s:gmatch("[^%s]+") do
        args[#args + 1] = w:lower()
    end
    return args
end

function OnScriptLoad() end

function OnScriptUnload() end

function GetRequiredVersion()
    return 200
end

function OnNewGame()
    player_data = {}
end

function OnPlayerLeave(id)
    player_data[id] = nil
end

function OnPlayerSpawn(id)
    local p = player_data[id]
    if not p or not p.active or not p.x then return end

    local obj = getplayerobjectid(id)
    if obj then
        movobjectcoords(obj, p.x, p.y, p.z)
        privatesay(id, "Tactical Insert: Spawn at marked point.")
        if ONE_TIME_USE and not DELETE_ON_DEATH then
            player_data[id] = nil -- one-time use
        end
    end
end

function OnPlayerKill(_, victim)
    if not DELETE_ON_DEATH then return end
    local data = player_data[victim]
    if data then player_data[victim] = nil end
end

function OnServerChat(id, _, message)
    local args = parse_cmd(message)

    if args[1] ~= COMMAND then return end

    local sub = args[2]
    local p = player_data[id] or {}

    if not sub then -- toggle
        if p.x then
            p.active = not p.active
            privatesay(id, "Tactical Insertion " .. (p.active and "ENABLED" or "DISABLED"))
            player_data[id] = p
        else
            privatesay(id, "No insertion point set. Use /tac set to place one.")
        end
    elseif sub == "set" then
        local obj = getplayerobjectid(id)
        if not obj then
            privatesay(id, "You must be alive to set an insertion point.")
            return false
        end
        local x, y, z = getobjectcoords(obj)
        player_data[id] = { x = x, y = y, z = z, active = true }
        privatesay(id, "Insertion point set. It will be used on your next spawn.")
    elseif sub == "clear" then
        player_data[id] = nil
        privatesay(id, "Insertion point cleared.")
    elseif sub == "status" then
        if p.x then
            local status = p.active and "enabled" or "disabled"
            privatesay(id, string.format("Insertion %s at %.2f, %.2f, %.2f", status, p.x, p.y, p.z))
        else
            privatesay(id, "No insertion point set. Use /tac set to create one.")
        end
    else
        privatesay(id, "Usage: /tac [set|clear|status] - toggles or manages your respawn point.")
    end

    return false
end
