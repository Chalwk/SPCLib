--[[
===============================================================================
SCRIPT NAME:      anti_impersonator.lua
DESCRIPTION:      Prevents players from impersonating trusted community members.
                  Verifies joining players against a whitelist of approved names
                  and their corresponding IPs and/or hashes.

FEATURES:         - Detects and punishes impersonators trying to use whitelisted names
                  - Supports multiple enforcement types (kick, ipban, hashban)
                  - Configurable ban duration (temporary or permanent)
                  - Customizable punishment reason for logging and commands
                  - Flexible whitelist: each member can have multiple IPs/hashes

NOTE:             - Shared hashes may trigger false positives
                  - Dynamic IPs may require regular updates to the whitelist

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config Start ---------------------------------------------------------------
local CONFIG = {

    -- Type of punishment to apply ('kick', 'ipban', 'hashban'):
    BAN_TYPE = 'kick',

    -- Ban duration in minutes (0 for permanent ban):
    BAN_DURATION = 10,

    -- Reason for punishment (used in command execution):
    PUNISHMENT_REASON = 'Impersonating',

    --[[
    MEMBERS WHITELIST:
    ---------------------------------------------------------------------------
    This is the trusted community members list.
    Format:
        ['ExactPlayerName'] = {
            'IP_Address_1',
            'IP_Address_2',
            'Hash_1',
            'Hash_2',
            ...
        }

    Rules:
    - The table key must be the EXACT player name (case-sensitive).
    - Each entry (value) is a list of that member's allowed identifiers.
    - Allowed identifiers are:
        * IPv4 address (e.g. "127.0.0.1")
        * Hash string (32 characters, e.g. "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
    - At least ONE valid IP or hash must be listed for a member.
    - A player is considered LEGIT if:
        * Their name matches a whitelisted member, AND
        * Their IP OR hash is found in that member's list.
    - Otherwise, they are treated as an IMPERSONATOR and punished.

    Notes:
    - Members may have multiple IPs/hashes (e.g., home + laptop, or dynamic IP).
    - Keep this list updated as trusted members' IPs/hashes change.
    - If someone shares their game copy, it may trigger false positives.
    ---------------------------------------------------------------------------
    ]]
    MEMBERS = {
        ['Chalwk'] = {
            '127.0.0.1',                        -- example IP
            'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', -- example hash
        },
        ['someone'] = {
            'ip1',   -- replace with real IP
            'hash1', -- replace with real hash
            'hash2',
        }
    }
}
-- End Config ----------------------------------------------------------------

api_version = "1.12.0.0"

local function enforcePenalty(playerId, name, ban_type, reason, ban_duration)
    -- Build command:
    local command
    if ban_type == "kick" then
        command = string.format('k %d "%s"', playerId, reason)
    elseif ban_type == "ipban" then
        command = string.format('ipban %d %d "%s"', playerId, ban_duration, reason)
    elseif ban_type == "hashban" then
        command = string.format('b %d %d "%s"', playerId, ban_duration, reason)
    end
    execute_command(command)

    -- Console logs:
    if ban_type == "kick" then
        cprint(string.format("[Anti-Impersonator] %s was kicked.", name), 12)
    else
        cprint(string.format("[Anti-Impersonator] %s was banned for %s minute(s).", name, ban_duration), 12)
    end
end

local function isImpersonator(name, hash, ip)
    local member_data = CONFIG.MEMBERS[name]
    if member_data then
        for _, value in ipairs(member_data) do
            if value == hash or value == ip then
                return false -- Legit member
            end
        end
        return true -- Impersonator detected
    end
    return false    -- Name not in whitelist
end

function OnJoin(playerId)
    local name = get_var(playerId, '$name')
    local hash = get_var(playerId, '$hash')
    local ip = get_var(playerId, '$ip'):match('%d+%.%d+%.%d+%.%d+')
    if isImpersonator(name, hash, ip) then
        enforcePenalty(playerId, name, CONFIG.BAN_TYPE, CONFIG.PUNISHMENT_REASON, CONFIG.BAN_DURATION)
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, 'OnJoin')
end

function OnScriptUnload() end
