--[[
=====================================================================================
SCRIPT NAME:      vpn_blocker.lua
DESCRIPTION:      Advanced IP screening system to detect and block VPNs/proxies.

FEATURES:
                  - Real-time IP reputation analysis
                  - Integration with IPQualityScore API
                  - Customizable risk thresholds
                  - Detailed connection logging
                  - Fraud scoring system
                  - IP exclusion list
                  - Multiple detection methods

CONFIGURATION:
                  api_key = 'YOUR_KEY'    - IPQualityScore API key
                  action = 'k'            - Kick ('k') or ban ('b')
                  ban_time = 10           - Ban duration in minutes
                  minChecks = 2           - Minimum failed checks required

DETECTION METHODS:
                  - VPN detection
                  - Proxy detection
                  - Tor node detection
                  - Crawler detection
                  - Fraud scoring
                  - Bot activity detection

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:        http://regex.info/blog/lua/json
                  - SAPP HTTP Client:       https://github.com/Chalwk/SAPP-HTTP
                  - IPQualityScore API Key: https://www.ipqualityscore.com/

Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local config = {

    --------------------------------------------------------------------------
    -- I recommend reading the API Documentation before changing any settings:
    -- https://www.ipqualityscore.com/documentation/proxy-detection/overview
    --------------------------------------------------------------------------

    -------------------
    -- config starts --
    -------------------

    -- IP Quality Score api key for authentication and API requests:
    api_key = 'PASTE_API_KEY_HERE',

    -- Action to be taken on the player (e.g., 'k' for kick, 'b' for ban):
    action = 'k',

    -- Ban time in minutes for the 'b' action
    ban_time = 10,

    -- Reason to be provided when taking action against a player:
    reason = 'VPN Connection',

    -- Feedback messages for players and the server console:
    player_feedback = "We've detected that you're using a VPN or Proxy - we do not allow these!'",
    console_feedback = '%s was %s for using a VPN or Proxy (IP: %s)',

    -- Log verbose details to the console?
    -- Includes: IP Address, Fraud Score, Bot Status, etc.
    log_verbose = true,

    -- The minimum number of failed checks required to kick or ban a player.
    -- (This is a safety feature to prevent false positives)
    minChecks = 2,

    -- Request Parameters (ADVANCED USERS ONLY):
    -- https://www.ipqualityscore.com/documentation/proxy-detection/overview
    checks = {

        -- Check if IP is associated with being a confirmed crawler
        -- such as Googlebot, Bingbot, etc based on hostname or IP address verification.
        is_crawler = true,

        -- Check if IP suspected of being a VPN connection?
        vpn = true,

        -- Check if IP suspected of being a Tor connection?
        tor = true,

        -- Check if IP address suspected to be a proxy? (SOCKS, Elite, Anonymous, VPN, Tor, etc.)
        proxy = true,

        -- Fraud Score Threshold:
        -- Fraud Scores >= 75 are suspicious, but not necessarily fraudulent.
        -- I recommend flagging or blocking traffic with Fraud Scores >= 85,
        -- but you may find it beneficial to use a higher or lower threshold:
        fraud_score = 85,

        -- Premium Account Feature:
        -- Indicates if bots or non-human traffic has recently used this IP address to engage
        -- in automated fraudulent behavior. Provides stronger confidence that the IP address is suspicious:
        bot_status = true
    },

    -- Request Parameters (ADVANCED USERS ONLY):
    -- Refer to the documentation for details.
    parameters = {

        -- How in depth (strict) do you want this query to be?
        -- Higher values take longer to process and may provide a higher false-positive rate.
        -- It is recommended to start at "0", the lowest strictness setting, and increasing to "1" or "2" depending on your needs:
        strictness = 1,

        -- Bypasses certain checks for IP addresses from education and research institutions, schools, and some corporate connections
        -- to better accommodate audiences that frequently use public connections:
        allow_public_access_points = true,

        -- Enable this setting to lower detection rates and Fraud Scores for mixed quality IP addresses.
        -- If you experience any false-positives with your traffic then enabling this feature will provide better results:
        lighter_penalties = false,

        -- This setting is used for time-sensitive lookups that require a faster response time.
        -- Accuracy is slightly degraded with the "fast" approach, but not significantly noticeable:
        fast = false,

        -- You can optionally specify that this lookup should be treated as a mobile device:
        mobile = false
    },

    -- Exclude IP Addresses from being checked:
    -- Set the value of each IP address to true to exclude it from being checked.
    -- This is useful for allowing VPNs for specific players.
    exclusion_list = {
        ['127.0.0.1'] = false,  -- Example: Exclude localhost IP address
        ['192.168.1.1'] = false -- Example: Exclude a specific local IP address
    }

    -----------------
    -- config ends --
    -----------------
}

local json = (loadfile 'json.lua')()
local ffi = require('ffi')
local sapp_http = ffi.load('sapp_http')
local apiRequestUrl = 'https://www.ipqualityscore.com/api/json/ip/' .. config.api_key .. '/'

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

api_version = "1.12.0.0"

local http_initialized = false
local pending = {} -- key: request handle, value: { player = {id, name, ip} }

local function is_excluded(ip)
    return config.exclusion_list[ip] == true
end

local function should_take_action(data)
    local failed = 0
    -- Check boolean flags
    for key, enabled in pairs(config.checks) do
        if type(enabled) == 'boolean' and enabled then
            if data[key] == true then
                failed = failed + 1
            end
        end
    end
    -- Check fraud score threshold
    if config.checks.fraud_score and type(config.checks.fraud_score) == 'number' then
        if data.fraud_score and data.fraud_score >= config.checks.fraud_score then
            failed = failed + 1
        end
    end
    return failed >= config.minChecks
end

local function log_verbose(data)
    if config.log_verbose then
        for k, v in pairs(data) do
            print(k, v)
        end
    end
end

local function take_action(player)
    local id = player.id
    if config.action == 'k' then
        execute_command('k ' .. id .. ' "' .. config.reason .. '"')
    else
        execute_command('b ' .. id .. ' ' .. config.ban_time .. ' "' .. config.reason .. '"')
    end

    say(id, config.player_feedback)

    local state = (config.action == 'k' and 'kicked' or 'banned')
    local msg = string.format(config.console_feedback, player.name, state, player.ip)
    cprint(msg, 12)
end

-- Build the API URL with parameters
local function build_url(ip)
    local url = apiRequestUrl .. ip .. '?'
    local params = {}
    for k, v in pairs(config.parameters) do
        table.insert(params, k .. '=' .. tostring(v))
    end
    return url .. table.concat(params, '&')
end

-- Start lookup for a player
local function start_lookup(player)
    local url = build_url(player.ip)
    local req = sapp_http.sapp_http_create_get(url, nil, 0)
    if req == nil then
        cprint("[VPNBlocker] Failed to create HTTP request for " .. player.ip, 12)
        return
    end
    pending[req] = { player = player }
end

function process_pending()
    -- Drive the multi handle
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
        local player = ctx.player

        local resp = ffi.new("sapp_http_response")
        local status = sapp_http.sapp_http_request_get_response(req, resp)

        if status == 0 and resp.body_size > 0 then
            local raw = ffi.string(resp.body, resp.body_size)
            local ok, data = pcall(json.decode, json, raw)
            if ok and data then
                -- Check if API returned an error
                if data.success == false then
                    local err = data.message or "unknown API error"
                    cprint("[VPNBlocker] API error for " .. player.ip .. ": " .. err, 12)
                else
                    -- Log verbose if enabled
                    log_verbose(data)
                    -- Evaluate risk
                    if should_take_action(data) then
                        take_action(player)
                    end
                end
            else
                cprint("[VPNBlocker] Failed to parse JSON for " .. player.ip, 12)
            end
        else
            cprint("[VPNBlocker] HTTP request failed for " .. player.ip, 12)
        end

        -- Clean up
        sapp_http.sapp_http_free_response(resp)
        sapp_http.sapp_http_request_free(req)
        pending[req] = nil
    end

    return true
end

function OnScriptLoad()
    if not http_initialized then
        local rc = sapp_http.sapp_http_global_init()
        if rc ~= 0 then
            cprint("[VPNBlocker] HTTP global init failed with code " .. tostring(rc), 12)
            return
        end
        http_initialized = true
    end

    register_callback(cb.EVENT_PREJOIN, 'PreJoin')

    timer(200, 'process_pending')
end

function PreJoin(id)
    local ip = get_var(id, '$ip'):match('%d+.%d+.%d+.%d+')
    if not ip then return end
    if is_excluded(ip) then return end
    local player = { id = id, name = get_var(id, '$name'), ip = ip }
    start_lookup(player)
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
