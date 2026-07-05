--[[
=====================================================================================
SCRIPT NAME:      player_count_timer.lua
DESCRIPTION:      Periodically broadcasts the current number of players in the server.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
local INTERVAL = 1500
local MESSAGE = "There are currently: (%d / %d players online)"
-- CONFIG END --

local network_struct = 0x6C7980
local current_players_addr, max_players_addr

function OnScriptLoad(_, game)
    local ce = 0
    if game == "CE" then ce = 0x40 end

    current_players_addr = network_struct + (0x1A8 + ce)
    max_players_addr = network_struct + (0x1A5 + ce)
    registertimer(INTERVAL, "StatusTimer")
end

function StatusTimer()
    local current = readword(current_players_addr)
    local max = readbyte(max_players_addr)
    respond(MESSAGE:format(current, max))
    return true
end

function GetRequiredVersion()
    return 200
end
