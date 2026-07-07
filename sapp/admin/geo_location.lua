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
                  - SAPP HTTP Client: https://github.com/Chalwk/SAPP-HTTP

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
local ffi = require("ffi")
local sapp_http = ffi.load("sapp_http")

-- Define the C API (from sapp_http.h)
ffi.cdef [[
    typedef struct sapp_http_header {
        const char *name;
        const char *value;
    } sapp_http_header;

    typedef struct sapp_http_response {
        int curl_code;
        long http_status;
        size_t body_size;
        char *body;
        char *content_type;
        char *error_message;
    } sapp_http_response;

    typedef struct sapp_http_request sapp_http_request;

    int sapp_http_global_init(void);
    void sapp_http_global_cleanup(void);
    sapp_http_request* sapp_http_create_get(const char *url,
                                            const sapp_http_header *headers,
                                            size_t header_count);
    int sapp_http_process(void);
    int sapp_http_request_is_done(sapp_http_request *req);
    int sapp_http_request_get_response(sapp_http_request *req,
                                       sapp_http_response *out);
    void sapp_http_request_free(sapp_http_request *req);
    void sapp_http_free_response(sapp_http_response *response);
]]

local API_URL = "http://ip-api.com/json/%s"

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

-- Keep the API results so we don't hammer the free tier!
local cache = {}
-- Stores ongoing async lookups, keyed by request handle (pointer)
-- Each entry: { type = "join" or "manual", id = player/admin id, ip = string, admin = optional }
local pending = {}
local http_initialized = false

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

-- Process completed HTTP requests
function process_pending()
    -- First, drive the multi handle
    sapp_http.sapp_http_process()

    local done_list = {}
    for req, ctx in pairs(pending) do
        if sapp_http.sapp_http_request_is_done(req) == 1 then
            table.insert(done_list, { req = req, ctx = ctx })
        end
    end

    for _, item in ipairs(done_list) do
        local req = item.req
        local ctx = item.ctx
        local resp = ffi.new("sapp_http_response")
        local status = sapp_http.sapp_http_request_get_response(req, resp)

        if status == 0 and resp.body_size > 0 then
            local raw = ffi.string(resp.body, resp.body_size)
            local data, err = parse_json_response(raw)

            if data then
                -- Cache the successful result
                cache[ctx.ip] = { data = data, timestamp = os_time() }

                if ctx.type == "join" then
                    local id = ctx.id
                    local name = get_var(id, "$name")
                    announce(id, name, data)
                    block_if_needed(id, data)
                elseif ctx.type == "manual" then
                    local admin = ctx.admin
                    local tell = respond(admin)
                    tell(fmt("%s: %s", ctx.ip, format_data(data)))
                end
            else
                local msg = "API query failed for IP " .. ctx.ip .. " -> " .. (err or "unknown error")
                if ctx.type == "join" then
                    cprint("[GeoLocation] " .. msg)
                else
                    local tell = respond(ctx.admin)
                    tell(msg)
                end
            end
        else
            -- Request failed or got empty response
            local err_msg = "HTTP request failed for IP " .. ctx.ip
            if ctx.type == "join" then
                cprint("[GeoLocation] " .. err_msg)
            else
                local tell = respond(ctx.admin)
                tell(err_msg)
            end
        end

        -- Clean up
        sapp_http.sapp_http_free_response(resp)
        sapp_http.sapp_http_request_free(req)
        pending[req] = nil
    end

    return true
end

-- Kick off an async lookup (for join or manual)
local function start_lookup(ctx)
    local url = fmt(API_URL, ctx.ip)
    local req = sapp_http.sapp_http_create_get(url, nil, 0)
    if req == nil then
        local err = "Failed to create HTTP request for IP " .. ctx.ip
        if ctx.type == "join" then
            cprint("[GeoLocation] " .. err)
        else
            local tell = respond(ctx.admin)
            tell(err)
        end
        return
    end
    pending[req] = ctx
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

    -- No fresh cache, ask the internet asynchronously
    local ctx = { type = "join", id = id, ip = ip }
    start_lookup(ctx)
end

-- Manual lookup via /country command
local function manual_lookup(admin_id, ip)
    local tell = respond(admin_id)

    if not is_admin(admin_id) then
        tell("Insufficient permissions.")
        return
    end

    -- Check cache first
    local entry = cache[ip]
    if entry and os_time() - entry.timestamp < CACHE_TTL then
        tell(fmt("%s: %s", ip, format_data(entry.data)))
        return
    end

    -- Launch async request
    local ctx = { type = "manual", admin = admin_id, ip = ip }
    start_lookup(ctx)
    tell("Lookup in progress for " .. ip .. " ...")
end

function OnScriptLoad()
    -- Initialize HTTP client (once)
    if not http_initialized then
        local rc = sapp_http.sapp_http_global_init()
        if rc ~= 0 then
            cprint("[GeoLocation] HTTP global init failed with code " .. tostring(rc), 12)
            return
        end
        http_initialized = true
    end

    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_COMMAND, "OnCommand")

    -- Precompute blocked codes for a quick O(1) check later
    for _, code in ipairs(BLOCK_LIST) do
        block_set[code:upper()] = true
    end

    -- Start the processing timer (runs every 200 ms)
    timer(200, "process_pending")
end

function OnJoin(id)
    local ip = get_var(id, "$ip"):match("%d+%.%d+%.%d+%.%d+")
    if DEBUG_FORCE_IP ~= "" then ip = DEBUG_FORCE_IP end
    if ip then lookup_ip(id, ip) end
end

function OnCommand(id, command)
    local args = parse_args(command)
    if #args == 0 then return true end

    if args[1]:lower() == "country" and args[2] then
        local ip = args[2]

        -- If it's not a raw IP, treat it as a player ID and resolve their IP
        if not ip:match("^%d+%.%d+%.%d+%.%d+$") then
            local target = tonumber(ip)
            if target and player_present(target) then
                ip = get_var(target, "$ip"):match("%d+%.%d+%.%d+%.%d+")
            else
                respond(id)("Invalid IP or player ID.")
                return false
            end
        end

        manual_lookup(id, ip)
        return false
    end

    return true
end

function OnScriptUnload()
    for req, _ in pairs(pending) do
        sapp_http.sapp_http_request_free(req)
    end
    pending = {}

    if http_initialized then
        sapp_http.sapp_http_global_cleanup()
        http_initialized = false
    end
end