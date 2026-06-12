--[[
=======================================================================
SCRIPT NAME:      dynamic_ping_kicker.lua
DESCRIPTION:      Enforces server ping limits with optional scaling
                  based on player count. Includes warning system,
                  grace periods, and basic admin/name immunity.

Copyright (c) 2020-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=======================================================================
]]

-- ========================= CONFIGURATION =========================

local CHECK_INTERVAL = 5            -- Seconds between ping checks
local WARNINGS = 5                  -- Warnings before kicking the player
local GRACE_PERIOD = 20             -- Seconds after a warning to reset strikes
local DEFAULT_LIMIT = 250           -- Hard limit (used when DYNAMIC_MODE = false)
local DYNAMIC_MODE = true           -- If true, use LIMITS based on player count; if false, use DEFAULT_LIMIT.

-- IMMUNITY --
-- Note: A player is immune IF admin level >= ADMIN_LEVEL OR name in IMMUNE_ADMINS
local ADMIN_LEVEL = 1 -- Minimum admin level required for immunity
local IMMUNE_ADMINS = {
    ["EXAMPLE_NAME"]  = true,
}

-- MESSAGES --
local KICK_REASON = "High Ping" -- SAPP will show: **SAPP** NAME was kicked for "High Ping"
local WARNING_MESSAGES = {
    "--- [ HIGH PING WARNING ] ---", "Ping limit: $limit ms, Your Ping: $ping ms.",
    "Please reduce your ping. Warnings Left: $strikes/$max_warnings"
}

-- Dynamic ping limits by player count (used only if DYNAMIC_MODE = true)
local LIMITS = {
    { min = 1,  max = 4,  limit = 500 },
    { min = 5,  max = 8,  limit = 400 },
    { min = 9,  max = 12, limit = 300 },
    { min = 13, max = 16, limit = 200 }
}
-- CONFIG ENDS -----------------------------------------------------

api_version = '1.12.0.0'

local players = {}
local current_limit = DEFAULT_LIMIT
local game_running = false
local clock = os.clock
local ipairs = ipairs

local function get_current_limit(quit)
    if not DYNAMIC_MODE then return DEFAULT_LIMIT end
    local total_players = tonumber(get_var(0, '$pn')) - (quit and 1 or 0)
    for i = 1, #LIMITS do
        local entry = LIMITS[i]
        if total_players >= entry.min and total_players <= entry.max then
            return entry.limit
        end
    end
    return DEFAULT_LIMIT
end

local function is_player_immune(id, player_name)
    local level = tonumber(get_var(id, "$lvl"))
    return level >= ADMIN_LEVEL or IMMUNE_ADMINS[player_name]
end

local function send_warning(id, ping, strikes_left)
    for _, msg in ipairs(WARNING_MESSAGES) do
        local formatted = msg:gsub("$ping", ping)
            :gsub("$limit", current_limit)
            :gsub("$strikes", strikes_left)
            :gsub("$max_warnings", WARNINGS)
        rprint(id, formatted)
    end
end

local function notify_grace_expired(id)
    rprint(id, "Grace period expired. Ping warnings reset.")
end

function CheckPings()
    if not game_running then return true end -- continue, but don't check
    local now = clock()

    for i = 1, 16 do
        local p = players[i]
        if p and not is_player_immune(i, p.name) then

            if now >= p.check_time then
                p.check_time = now + CHECK_INTERVAL
                local ping = tonumber(get_var(i, "$ping"))
                if ping and ping > current_limit then
                    if p.strikes <= 0 then
                        execute_command(string.format('k %d "%s"', i, KICK_REASON))
                    else
                        p.grace_time = now + GRACE_PERIOD
                        p.strikes = p.strikes - 1
                        send_warning(i, ping, p.strikes)
                    end
                end
            elseif p.grace_time and now >= p.grace_time then
                p.strikes = WARNINGS
                p.grace_time = nil
                notify_grace_expired(i)
            end
        end
    end
end

function OnScriptLoad()
    timer(1000, "CheckPings")
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    game_running = get_var(0, "$gt") ~= "n/a"
    players = {}
    if game_running then -- in case script is loaded mid-game
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function OnEnd()
    game_running = false
end

function OnJoin(id)
    players[id] = {
         name = get_var(id, "$name"),
         strikes = WARNINGS,
         check_time = clock() + CHECK_INTERVAL,
         grace_time = nil
    }
    current_limit = get_current_limit()
end

function OnQuit(id)
    players[id] = nil
    current_limit = get_current_limit(true)
end

function OnScriptUnload() end
