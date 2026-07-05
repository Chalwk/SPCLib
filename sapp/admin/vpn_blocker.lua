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
                  - SAPP HTTP Client:       https://opencarnage.net/index.php?/topic/5998-sapp-http-client/)
                  - IPQualityScore API Key: https://www.ipqualityscore.com/

Copyright (c) 2023-2025 Jericho Crosby (Chalwk)
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

    -- A message relay function temporarily removes the "msg_prefix"
    -- and will restore it to this when the relay is finished:
    prefix = '**SAPP**',

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

        -- Check if IP suspected of being a Tor connection?--
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
    -- Refer to the documentation for details: https://www.ipqualityscore.com/documentation/proxy-detection/overview
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

local apiRequestUrl = 'https://www.ipqualityscore.com/api/json/ip/' .. config.api_key .. '/'
local async_table = {}

local json = (loadfile 'json.lua')()
local ffi = require('ffi')

--[[
    @section HTTP API functions

    This section contains FFI definitions for functions that interact with HTTP requests and responses.
]]
ffi.cdef [[
    typedef void http_response;
    http_response *http_get(const char *url, bool async);
    void http_destroy_response(http_response *);
    void http_wait_async(const http_response *);
    bool http_response_is_null(const http_response *);
    bool http_response_received(const http_response *);
    const char *http_read_response(const http_response *);
]]
local client = ffi.load('lua_http_client')

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_PREJOIN, 'PreJoin')
end

--[[
    @function shouldTakeAction

    Determines if action should be taken against a player based on VPN or proxy checks.

    @param {table} 'data' The data containing the player's information and check results.
    @returns {boolean} True if action should be taken, false otherwise.
]]
local function shouldTakeAction(data)
    local flagChecks = {}
    local fraudScoreChecks = {}

    for k, v in pairs(config.checks) do
        if type(v) == 'boolean' then
            flagChecks[#flagChecks + 1] = { k, v }
        elseif type(v) == 'number' then
            fraudScoreChecks[#fraudScoreChecks + 1] = { k, v }
        end
    end
    local failedChecks = 0
    -- Process flag checks
    for i = 1, #flagChecks do
        local check = flagChecks[i]
        if check[2] and data[check[1]] then
            failedChecks = failedChecks + 1
        end
    end
    -- Process fraud score check
    for i = 1, #fraudScoreChecks do
        local check = fraudScoreChecks[i]
        if data[check[1]] >= check[2] then
            failedChecks = failedChecks + 1
        end
    end
    return failedChecks >= config.minChecks
end

--[[
    @function logVerbose

    Logs the provided data if verbose logging is enabled in the config.

    @param {table} 'data' The data to be logged.
    @returns {void}
]]
local function logVerbose(data)
    if config.log_verbose then
        for k, v in pairs(data) do
            print(k, v)
        end
    end
end

local help = [[HTTP RESPONSE IS NULL ->
-- * Possible loss of internet (check it).
-- * Possible End Point error (verify settings or contact IP Quality Score).

-- Sometimes small hiccups with the internet will cause this error.
-- Most of the time you can ignore it.]]

local function executeCommand(cmd)
    execute_command(cmd)
end

local function informPlayer(id)
    executeCommand('msg_prefix ""')
    say(id, config.player_feedback)
    executeCommand('msg_prefix "' .. config.prefix .. '"')
end

local function buildConsoleResponse(player)
    local state = (config.action == 'k' and 'kicked' or 'banned')
    return string.format(config.console_feedback, player.name, state, player.ip)
end

--[[
    @function processPlayerData

    Processes the player data based on the specified action and provides feedback.

    @param {table} 'player' Player data containing the player's ID and other relevant information.
]]
local function processPlayerData(player)
    local id = tonumber(player.id)

    if config.action == 'k' then
        executeCommand('k ' .. id .. ' "' .. config.reason .. '"')
    else
        executeCommand('b ' .. id .. ' ' .. config.ban_time .. ' "' .. config.reason .. '"')
    end

    informPlayer(id)
    cprint(buildConsoleResponse(player), 12)
end

--[[
    @function processAsyncResponse

    Processes the asynchronous response for a player, handles player data, and performs necessary actions.

    @param {string} 'id' Player index as a string.
    @returns {boolean} True if the response is not yet received or does not exist; false otherwise.
]]
function processAsyncResponse(id)
    local response = async_table[id]
    if response and response[1] and client.http_response_received(response[1]) then
        if client.http_response_is_null(response[1]) then
            cprint(help, 12)
            async_table[tostring(id)] = nil
            return false
        end

        local results = ffi.string(client.http_read_response(response[1]))
        local data = json:decode(results)
        if data and shouldTakeAction(data) then
            logVerbose(data)
            local player = response[2]
            processPlayerData(player)
        end

        client.http_destroy_response(response[1])
        async_table[tostring(id)] = nil
        return false
    end

    return true
end

--[[
    @function generateLink

    Generates a URL query string containing IP address and additional parameters for API requests.

    @param {table} 'player' Player information containing the IP address.
    @returns {string} The generated URL query string.
]]
local function generateLink(player)
    local i = 0
    local link = tostring(apiRequestUrl .. player.ip .. '?')
    for k, v in pairs(config.parameters) do
        link = (i < 1) and (link .. k .. '=' .. tostring(v)) or (link .. '&' .. k .. '=' .. tostring(v))
    end
    return link
end

local function ignorePlayer(ip)
    return config.exclusion_list[ip] and true or false
end

--[[
    @function getPlayer

    Retrieves player information based on the provided player index.

    @param {number} 'id' Player index.
    @returns {table | nil} A table containing the player's IP, ID, and name, or nil if the player should be ignored.
]]
local function getPlayer(id)
    local ip = get_var(id, '$ip'):match('%d+.%d+.%d+.%d+')
    return (not ignorePlayer(ip)) and { ip = ip, id = id, name = get_var(id, '$name') } or nil
end

--[[
    @function PreJoin

    Performs an asynchronous request to the IP Quality Score API to check if the player is using a VPN or Proxy.

    @param {number} 'id' Player index (1-16).
]]
function PreJoin(id)
    local player = getPlayer(id)
    if (not player) then
        return
    end

    id = tostring(id)
    local link = generateLink(player)
    async_table[id] = { client.http_get(link, true), player }

    timer(1, 'processAsyncResponse', id)
end

function OnScriptUnload()
    -- N/A
end
