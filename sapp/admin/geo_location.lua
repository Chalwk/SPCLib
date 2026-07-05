--[[
=====================================================================================
SCRIPT NAME:      geo_location.lua
DESCRIPTION:      Geolocate joining players and optionally block countries.
                  - Shows selected details in console and to admins/player
                  - /country <player id>   - manual lookup (admin)
                  - Cache with TTL to stay within free API limits
                  - Uses ip-api.com JSON format

REQUIREMENTS:     Install in the same folder as sapp.dll.
                  - Lua JSON Parser:  http://regex.info/blog/lua/json
                  - SAPP HTTP Client: https://opencarnage.net/index.php?/topic/5998-sapp-http-client/

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START --
api_version = "1.12.0.0"

-- Minimum admin level to use /country command
local ADMIN_LEVEL = 1

-- Show selected fields to the player on join
local SHOW_TO_PLAYER = true

-- Show selected fields to admins on join
local NOTIFY_ADMINS = true

-- Fields to show in chat / console.
-- Available keys:
--      status, message, country, countryCode,
--      region, regionName, city, zip, lat, lon,
--      timezone, offset, currency, isp, org, as,
--      asname, reverse, mobile, proxy, hosting, query
-- You can reorder or remove any of them.
-- Pick what you want to see, order matters for the output string
local SHOW_FIELDS = { "country", "countryCode", "regionName", "city", "isp" }

-- Countries to block (two-letter ISO codes in UPPERCASE). Example: {"CN","RU"}
-- Default empty - nobody's banned until you fill this in
local BLOCK_LIST = {}

-- Message shown to blocked players
local BLOCK_MESSAGE = "Your country is not allowed on this server."

-- Cache responses for this many seconds (free API limit is 45/min)
-- 3600 seconds = 1 hour, pretty safe for a game server
local CACHE_TTL = 3600

-- Debug: set to an IP string to force all join lookups to use this IP (for testing)
-- Leave empty ("") to use real player IPs.
-- Handy when you want to pretend to be from Timbuktu without VPN
local DEBUG_FORCE_IP = ""
-- END CONFIG --

local json = (loadfile "json.lua")()
local API_URL = "http://ip-api.com/json/%s"
local ffi = require("ffi")
ffi.cdef [[
    typedef void http_response;
    http_response *http_get(const char *url, bool async);
    void http_destroy_response(http_response *);
    void http_wait_async(const http_response *);
    bool http_response_is_null(const http_response *);
    bool http_response_received(const http_response *);
    const char *http_read_response(const http_response *);
]]
local http = ffi.load("lua_http_client")

local get_var = get_var
local player_present = player_present
local register_callback = register_callback
local rprint, cprint = rprint, cprint
local execute_command = execute_command
local timer = timer
local os_time = os.time
local fmt = string.format
local table_concat = table.concat
local tostring, tonumber = tostring, tonumber
local pcall = pcall
local ipairs = ipairs

-- Keep the API results so we don't hammer the free tier
local cache = {}
-- Stores ongoing async lookups, keyed by player id
local pending = {}
-- Quick lookup set for blocked country codes
local block_set = {}

local function is_admin(id)
    return id == 0 or tonumber(get_var(id, "$lvl")) >= ADMIN_LEVEL
end

local function respond(id)
    if id == 0 then return cprint end
    return function (msg)
        rprint(id, msg)
    end
end

local function parse_args(cmd)
    local parts = {}
    for w in cmd:gmatch("([^%s]+)") do
        parts[#parts + 1] = w
    end
    return parts
end

-- Decode and check if the API was nice to us
local function parse_json_response(raw)
    if not raw then return nil, "empty response" end

    local ok, data = pcall(json.decode, json, raw)
    if not ok or not data then
        return nil, "invalid JSON"
    end

    if data.status ~= "success" then
        local err = data.message or data.status or "unknown error"
        return nil, err
    end

    return data, nil
end

-- Build the display string from SHOW_FIELDS, skipping empty bits
local function format_data(data)
    local parts = {}
    for _, key in ipairs(SHOW_FIELDS) do
        if data[key] and data[key] ~= "" then
            parts[#parts + 1] = data[key]
        end
    end
    return table_concat(parts, ", ")
end

-- Boot blocked countries
local function block_if_needed(id, data)
    if data.countryCode and block_set[data.countryCode:upper()] then
        execute_command("k " .. id .. ' "' .. BLOCK_MESSAGE .. '"')
        return true
    end
    return false
end

local function announce(id, name, data)
    local info = format_data(data)

    if NOTIFY_ADMINS then
        local msg = fmt("%s joined from %s", name, info)
        for i = 1, 16 do
            if player_present(i) and is_admin(i) then
                rprint(i, msg)
            end
        end
        if id == 0 then cprint(msg) end
    end

    if SHOW_TO_PLAYER and player_present(id) then
        rprint(id, fmt("Your location: %s", info))
    end
end

-- Check cache first, otherwise fire off an async HTTP request
local function lookup_ip(id, ip)
    local entry = cache[ip]
    if entry and os_time() - entry.timestamp < CACHE_TTL then
        local data = entry.data
        local name = get_var(id, "$name")
        announce(id, name, data)
        block_if_needed(id, data)
        return
    end

    -- No fresh cache, ask the internet
    local url = fmt(API_URL, ip)
    local resp = http.http_get(url, true)

    pending[tostring(id)] = { resp = resp, ip = ip, id = id }
    -- Kick off a timer to poll for the async result
    timer(1000, "PollLookup", id)
end

-- Called every second until the HTTP response arrives, might keep respawning the timer
function PollLookup(id)
    id = tonumber(id)
    local job = pending[tostring(id)]
    if not job then return end

    if http.http_response_received(job.resp) then
        if not http.http_response_is_null(job.resp) then
            local raw = ffi.string(http.http_read_response(job.resp))
            local data, err = parse_json_response(raw)
            if data then
                cache[job.ip] = { data = data, timestamp = os_time() }

                local name = get_var(job.id, "$name")
                announce(job.id, name, data)
                block_if_needed(job.id, data)
            else
                -- Something went wrong with the API (or we got gibberish)
                cprint("[GeoLocation] API returned failure for IP " .. job.ip .. " -> " .. err, 12)
            end
        end

        -- Clean up the C memory and remove the pending job
        http.http_destroy_response(job.resp)
        pending[tostring(id)] = nil
    else
        -- Still waiting, keep polling
        timer(1000, "PollLookup", id)
    end
end

local function manual_lookup(admin_id, ip)
    local tell = respond(admin_id)

    if not is_admin(admin_id) then
        tell("Insufficient permissions.")
        return
    end

    local url = fmt(API_URL, ip)
    local resp = http.http_get(url, false) -- async = false, wait for it

    if not http.http_response_is_null(resp) then
        local raw = ffi.string(http.http_read_response(resp))
        local data, err = parse_json_response(raw)
        if data then
            tell(fmt("%s: %s", ip, format_data(data)))
        else
            tell("API query failed: " .. err)
        end
        http.http_destroy_response(resp)
    else
        tell("Could not reach API.")
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_COMMAND, "OnCommand")

    -- Precompute blocked codes for a quick O(1) check later
    for _, code in ipairs(BLOCK_LIST) do
        block_set[code:upper()] = true
    end
end

function OnJoin(id)
    local ip = get_var(id, "$ip"):match("%d+%.%d+%.%d+%.%d+")
    if DEBUG_FORCE_IP ~= "" then ip = DEBUG_FORCE_IP end
    if ip then lookup_ip(id, ip) end
end

function OnCommand(id, command)
    local args = parse_args(command)
    if #args == 0 then return true end

    local tell = respond(id)

    if args[1]:lower() == "country" and args[2] then
        local ip = args[2]

        -- If it's not a raw IP, treat it as a player ID and resolve their IP
        if not ip:match("^%d+%.%d+%.%d+%.%d+$") then
            local target = tonumber(ip)
            if target and player_present(target) then
                ip = get_var(target, "$ip"):match("%d+%.%d+%.%d+%.%d+")
            else
                tell("Invalid IP or player ID.")
                return false
            end
        end

        manual_lookup(id, ip)
        return false
    end

    return true
end

function OnScriptUnload() end
