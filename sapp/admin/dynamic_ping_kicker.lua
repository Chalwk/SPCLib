--[[
===============================================================================
SCRIPT NAME:      dynamic_ping_kicker.lua
DESCRIPTION:      Automatically enforces ping limits with:
                  - Player count-based thresholds
                  - Warning system with grace periods
                  - Admin immunity options

FEATURES:
                  - Dynamic ping limits that adjust as players join/leave
                  - Multiple warnings before kicking
                  - Configurable grace periods
                  - Detailed logging options

CONFIGURATION:    Adjust these settings:
                  - limits: Ping thresholds by player count
                  - warnings: Number of warnings before kick
                  - grace_period: Time to improve ping
                  - admin_immunity: Admin protection settings

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = '1.12.0.0'

-- Configuration:
local PingKicker = {
    check_interval = 5, -- Interval to check pings (in seconds)
    warnings = 5, -- Warnings before kicking the player
    grace_period = 20, -- Grace period to reset warnings (in seconds)
    default_limit = 1000, -- Default ping limit
    admin_immunity = true, -- Whether to give admins immunity
    admin_level = 1, -- Admin level for immunity (if admin_immunity = true)
    immune_admins = { "Admin1", "Admin2" }, -- List of admins with name-based immunity
    kick_message = "Ping too high! Limit: $limit ms, Your Ping: $ping ms.",
    warning_message = {
        "--- [ HIGH PING WARNING ] ---",
        "Ping limit: $limit ms, Your Ping: $ping ms.",
        "Please reduce your ping. Warnings Left: $strikes/$max_warnings"
    },
    reset_on_player_change = true, -- Reset player warnings when player count changes
    limits = {                     -- Dynamic ping limits by player count
        { min = 1, max = 4, limit = 750 },
        { min = 5, max = 8, limit = 450 },
        { min = 9, max = 12, limit = 375 },
        { min = 13, max = 16, limit = 200 }
    },
    log_kicks = true, -- Log kicks to server
    log_file = "ping_kick_log.txt" -- File for logging kicks (optional)
}

local players = {}
local limit
local game_running = false
local clock = os.clock

-- Register script events:
function OnScriptLoad()
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_TICK'], 'CheckPings')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

-- Log kick to server and file:
local function logKick(player, ping)
    if PingKicker.log_kicks then
        local log_msg = string.format("%s was kicked for high ping (%d ms), Limit: %d ms", player.name, ping, limit)
        cprint(log_msg)

        -- Append to log file:
        local file = io.open(PingKicker.log_file, "a+")
        if file then
            file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. log_msg .. "\n")
            file:close()
        end
    end
end

-- Check if player is immune (by level or name):
function PingKicker:IsImmune()
    if PingKicker.admin_immunity then
        local level = tonumber(get_var(self.id, "$lvl"))
        if level >= PingKicker.admin_level then
            return true
        end
    end
    for _, admin in ipairs(PingKicker.immune_admins) do
        if admin == self.name then
            return true
        end
    end
    return false
end

-- Initialize new player:
function PingKicker:NewPlayer(o)
    setmetatable(o, { __index = self })
    o.strikes = self.warnings
    o.check = clock() + self.check_interval
    o.grace = clock() + self.grace_period
    return o
end

-- Get the current ping limit based on player count:
function PingKicker:GetLimit()
    local player_count = #players
    for _, entry in ipairs(self.limits) do
        if player_count >= entry.min and player_count <= entry.max then
            return entry.limit
        end
    end
    return self.default_limit
end

-- Send warning message to the player:
function PingKicker:SendWarning(ping)
    for _, msg in ipairs(self.warning_message) do
        local formatted = msg:gsub("$ping", ping):gsub("$limit", limit)
                             :gsub("$strikes", self.strikes):gsub("$max_warnings", self.warnings)
        rprint(self.id, formatted)
    end
end

-- Kick player for exceeding ping limit:
function PingKicker:Kick(ping)
    local msg = self.kick_message:gsub("$ping", ping):gsub("$limit", limit)
    execute_command('k ' .. self.id .. ' "' .. msg .. '"')
    logKick(self, ping)
end

-- Notify player that grace period expired:
function PingKicker:NotifyGracePeriodExpired()
    rprint(self.id, "Grace period expired. Ping warnings reset.")
end

-- Check pings and issue warnings or kicks:
function CheckPings()
    if game_running then
        limit = PingKicker:GetLimit()

        for _, player in pairs(players) do
            if not player:IsImmune() then
                if clock() >= player.check then
                    player.check = clock() + PingKicker.check_interval
                    local ping = tonumber(get_var(player.id, "$ping"))

                    if ping > limit then
                        if player.strikes <= 0 then
                            player:Kick(ping)
                        else
                            player.grace = clock() + PingKicker.grace_period
                            player.strikes = player.strikes - 1
                            player:SendWarning(ping)
                        end
                    end
                elseif player.grace and clock() >= player.grace then
                    player.strikes = PingKicker.warnings
                    player.grace = nil
                    player:NotifyGracePeriodExpired()
                end
            end
        end
    end
end

-- Handle game start event:
function OnStart()
    game_running = get_var(0, "$gt") ~= "n/a"
    if game_running then
        players = {}
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

-- Handle game end event:
function OnEnd()
    game_running = false
end

-- Handle player join event:
function OnJoin(playerId)
    local new_player = PingKicker:NewPlayer({
        id = playerId,
        name = get_var(playerId, "$name")
    })
    players[playerId] = new_player

    if PingKicker.reset_on_player_change then
        limit = PingKicker:GetLimit()
    end
end

-- Handle player leave event:
function OnQuit(playerId)
    players[playerId] = nil
    if PingKicker.reset_on_player_change then
        limit = PingKicker:GetLimit()
    end
end

-- Placeholder for script unload event:
function OnScriptUnload()
    -- No actions required for unload.
end