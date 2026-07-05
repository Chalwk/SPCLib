--[[
=====================================================================================
SCRIPT NAME:      flag_capture_notify.lua
DESCRIPTION:      Prints a console message when a player captures a flag in CTF.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local gametype_base
local previous_scores = {}

local function is_ctf()
    return readbyte(gametype_base + 0x30) == 1
end

local function is_teamplay()
    return readbyte(gametype_base + 0x34) == 1
end

local function get_team_name(id)
    return getteam(id) == 0 and "Red" or "Blue"
end

function OnScriptLoad(_, game)
    gametype_base = (game == "PC") and 0x671340 or 0x5F5498
end

function OnNewGame()
    previous_scores = {}
end

function OnPlayerLeave(id)
    previous_scores[id] = nil
end

function OnClientUpdate(id)
    if not is_ctf() or not is_teamplay() then return end

    local player_struct = getplayer(id)
    if not player_struct then return end

    local current_score = readword(player_struct + 0xC8)
    local last_score = previous_scores[id] or 0

    if current_score > last_score then
        local name = getname(id)
        local team = get_team_name(id)
        respond(team .. " player " .. name .. " captured the flag! (Total: " .. current_score .. ")")
        previous_scores[id] = current_score
    end

    previous_scores[id] = current_score
end

function OnScriptUnload() end

function GetRequiredVersion()
    return 200
end
