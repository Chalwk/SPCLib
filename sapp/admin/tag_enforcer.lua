--[[
=====================================================================================
SCRIPT NAME:      tag_enforcer.lua
DESCRIPTION:      This script prevents unauthorized players from using the clan tag
                  (e.g. LIB-) in their name. It verifies each joining player against a
                  whitelist of official members identified by their IP address and/or
                  CD hash. If a player has the clan tag but is not recognized as an
                  official member, they are automatically kicked.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start ---------------------------------------------------------------
local CLAN_TAG = 'LIB-'
local OFFICIAL_MEMBERS = { -- table of authorised members
    '127.1.0.1',                       -- example IP
    'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -- example hash
}
-- Config End  ----------------------------------------------------------------

api_version = "1.12.0.0"

local function isAuthorizedMember(ip, hash)
    for i = 1, #OFFICIAL_MEMBERS do
        local entry = OFFICIAL_MEMBERS[i]
        if entry == ip or entry == hash then
            return true
        end
    end
    return false
end

local function hasUnauthorizedTag(name, hash, ip)
    return name:sub(1, #CLAN_TAG) == CLAN_TAG and not isAuthorizedMember(ip, hash)
end

function OnPreJoin(playerId)
    local name = get_var(playerId, '$name')
    local hash = get_var(playerId, '$hash')
    local ip = get_var(playerId, '$ip'):match('%d+%.%d+%.%d+%.%d+')

    if hasUnauthorizedTag(name, hash, ip) then
        execute_command('k ' .. playerId .. ' "Unauthorized tag detected"')
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_PREJOIN, 'OnPreJoin')
end

function OnScriptUnload() end
