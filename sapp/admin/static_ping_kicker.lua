--[[
=======================================================================
SCRIPT NAME:      static_ping_kicker.lua
DESCRIPTION:      Kicks non-members when ping > 240 ms.
                  Members (listed in MEMBERS) are fully immune.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=======================================================================
]]

-- ========================= CONFIGURATION =========================

local KICK_REASON = "High Ping (exceeds 240 ms)"
local WARNING_MESSAGE = "HIGH PING: %s | Warning %s/%s"
local CHECK_INTERVAL = 5                                -- Seconds between ping checks
local WARNINGS = 5                                      -- Warnings before kick
local GRACE_PERIOD = 20                                 -- Seconds after a warning to reset strikes
local PING_LIMIT = 240                                  -- Hard-coded ping limit (ms)
local MEMBERS = { -- List of immune members (case-sensitive as in game)
    ["EXAMPLE_NAME_HERE"] = true
}

-- CONFIG ENDS -----------------------------------------------------

api_version = '1.12.0.0'

local players = {}
local game_running = false
local clock = os.clock

local function is_player_immune(name)
    return MEMBERS[name] == true
end

local function send_warning(id, ping, strikes_left)
    local formatted = string.format(WARNING_MESSAGE, ping, strikes_left, WARNINGS)
    rprint(id, formatted)
end

local function notify_grace_expired(id)
    rprint(id, "Grace period expired. Ping warnings reset.")
end

function CheckPings()
    if not game_running then return true end

    local now = clock()
    for i = 1, 16 do
        local p = players[i]
        if p and not is_player_immune(p.name) then
            if now >= p.check_time then
                p.check_time = now + CHECK_INTERVAL
                local ping = tonumber(get_var(i, "$ping"))
                if ping and ping > PING_LIMIT then
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
    return true
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
    if game_running then
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
end

function OnQuit(id)
    players[id] = nil
end

function OnScriptUnload() end
