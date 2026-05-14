--[[
=====================================================================================
SCRIPT NAME:      timed_authentication.lua
DESCRIPTION:      This script enforces a timed authentication challenge for players
                  using clan tags (e.g. LIB-) in their name. When such a player
                  joins, they must type a predefined secret phrase in chat within a
                  set number of seconds. If they fail to do so, they are
                  automatically kicked.

                  Authenticated players are remembered by IP address to avoid
                  repeated authentication challenges.

                  Intended as a lightweight deterrent to unauthorized tag usage.
                  This implementation uses a static secret phrase and should not
                  be considered highly secure for sensitive use-cases.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start ---------------------------------------------------------------
local CLAN_TAG = 'LIB-'
local AUTH_TIME = 20                        -- seconds allowed to authenticate
local SECRET_PHRASE = "!your_secret_phrase" -- phrase a player must type
-- Config End -----------------------------------------------------------------

api_version = "1.12.0.0"

local pending_auth = {} -- tracks players awaiting authentication
local ip_cache = {}     -- cache of authenticated IP addresses

local function hasUnauthorizedTag(name)
    return name:sub(1, #CLAN_TAG) == CLAN_TAG
end

local function getIP(ip)
    return ip:match("(%d+%.%d+%.%d+%.%d+)")
end

function OnJoin(id)
    local name = get_var(id, "$name")
    local ip = getIP(get_var(id, "$ip"))

    -- Check if player has the clan tag
    if hasUnauthorizedTag(name) then
        -- Check if IP is in cache (already authenticated)
        if ip_cache[ip] then return end

        -- Otherwise, require authentication
        pending_auth[id] = ip

        rprint(id, CLAN_TAG .. " recognised.")
        rprint(id, "Type secret phrase in chat within " .. AUTH_TIME .. " seconds.")
        timer(1000 * AUTH_TIME, "CheckAuth", id)
    end
end

function CheckAuth(id)
    id = tonumber(id)
    if pending_auth and pending_auth[id] then
        execute_command("k " .. id .. ' "Failed to authenticate in time"')
        pending_auth[id] = nil
    end
    return false -- always stop the timer after first execution
end

function OnChat(id, msg)
    if not pending_auth or not pending_auth[id] then return true end
    if pending_auth[id] and msg:lower():gsub("%s+", "") == SECRET_PHRASE:lower() then
        -- Add IP to cache and clear pending auth
        ip_cache[pending_auth[id]] = true
        pending_auth[id] = nil
        rprint(id, "Authentication successful. Welcome!")
        return false -- block phrase from appearing in public chat
    end
end

function OnQuit(id)
    pending_auth[id] = nil
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_CHAT, "OnChat")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
end

function OnScriptUnload() end
