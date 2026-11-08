--[[
=====================================================================================
SCRIPT NAME:      tea_bagging.lua
DESCRIPTION:      Detects repeated crouching near a player's death location and
                  announces a random taunt.

COMMANDS:
                  /tbag [on|off|toggle|status|help] - Admin-only system control

Copyright (c) 2019-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIGURATION --

local config = {
    enabled = true,              -- Enable detection on script load
    admin_level_required = 4,    -- Minimum SAPP admin level allowed to control the script
    radius = 2.5,                -- Detection radius in world units
    expire_time = 120,           -- Seconds a death location remains eligible
    required_crouches = 3,       -- Distinct crouch starts needed to trigger
    cooldown_time = 30,          -- Minimum seconds between announcements per player
    crouch_threshold = 0.75,     -- Crouch-scale value treated as fully crouched

    messages = {
        "$attacker is lap-dancing on $victim's body!",
        "$attacker is giving $victim a one-way ticket to the ground!",
        "$attacker is practicing their dance moves on $victim!",
        "$attacker thinks $victim needs a little 'up close' attention!",
        "$attacker is trying to revive $victim with their dance skills!",
        "$attacker is making $victim their personal dance floor!",
        "$attacker is showing $victim how to 'drop it like it's hot!'"
    }
}

-- CONFIGURATION ENDS --

api_version = "1.12.0.0"

local players = {}
local corpses = {}
local min = math.min
local time = os.time

local function getPlayerPosition(dyn)
    if dyn == 0 then return nil end
    return read_vector3d(dyn + 0x5C)
end

local function distanceSquared(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return dx * dx + dy * dy + dz * dz
end

local function getClosestCorpse(player, x, y, z)
    local closest, closest_distance
    local radius_squared = config.radius * config.radius

    for index, corpse in ipairs(corpses) do
        if corpse.victim_id ~= player.id then
            local distance = distanceSquared(x, y, z, corpse.x, corpse.y, corpse.z)
            if distance <= radius_squared and (not closest_distance or distance < closest_distance) then
                closest, closest_distance = index, distance
            end
        end
    end

    return closest and corpses[closest] or nil, closest
end

local function resetProgress(player)
    player.crouch_count = 0
    player.target_corpse = nil
end

local function resetAllProgress()
    for _, player in pairs(players) do
        resetProgress(player)
        player.last_crouched = false
    end
end

local function removeExpiredCorpses(now)
    for index = #corpses, 1, -1 do
        if corpses[index].expires_at <= now then
            table.remove(corpses, index)
        end
    end
end

local function removePlayerCorpses(player_id)
    for index = #corpses, 1, -1 do
        if corpses[index].victim_id == player_id then
            table.remove(corpses, index)
        end
    end
end

local function getRandomMessage(attacker_name, victim_name)
    if #config.messages == 0 then return nil end

    local template = config.messages[rand(1, #config.messages + 1)]
    local names = {
        attacker = attacker_name,
        victim = victim_name
    }

    return (template:gsub("%$([%a_]+)", function(key)
        return names[key] or "$" .. key
    end))
end

local function announceTeaBag(attacker, corpse, corpse_index, now)
    local message = getRandomMessage(attacker.name, corpse.victim_name)
    if message then
        say_all(message)
    else
        cprint("[Tea Bagging] No announcement messages are configured.")
    end

    attacker.last_tbag_time = now
    resetProgress(attacker)
    table.remove(corpses, corpse_index)
end

local function updatePlayer(player, dyn, now)
    local x, y, z = getPlayerPosition(dyn)
    if not x then
        player.last_crouched = false
        resetProgress(player)
        return
    end

    player.last_x, player.last_y, player.last_z = x, y, z

    local crouch_scale = read_float(dyn + 0x50C) or 0
    local crouching = crouch_scale >= config.crouch_threshold
    local crouch_started = crouching and not player.last_crouched
    player.last_crouched = crouching

    if not config.enabled then
        resetProgress(player)
        return
    end

    local corpse, corpse_index = getClosestCorpse(player, x, y, z)
    if not corpse then
        resetProgress(player)
        return
    end

    if player.target_corpse ~= corpse then
        player.target_corpse = corpse
        player.crouch_count = 0
    end

    if crouch_started then
        player.crouch_count = min(player.crouch_count + 1, config.required_crouches)
        if player.crouch_count >= config.required_crouches and
            now - player.last_tbag_time >= config.cooldown_time then
            announceTeaBag(player, corpse, corpse_index, now)
        end
    end
end

local function isAdmin(id)
    if id == 0 then return true end
    local level = tonumber(get_var(id, "$lvl"))
    return level ~= nil and level >= config.admin_level_required
end

local function replyToExecutor(id, message)
    if id == 0 then
        cprint(message)
    elseif player_present(id) then
        rprint(id, message)
    end
end

local function setEnabled(enabled, actor_name)
    if config.enabled == enabled then return false end

    config.enabled = enabled
    resetAllProgress()
    say_all("[Tea Bagging] has been " .. (enabled and "ENABLED" or "DISABLED") .. " by " .. actor_name .. ".")
    return true
end

function OnCommand(id, command)
    local command_name, argument = command:match("^%s*(%S+)%s*(.-)%s*$")
    if not command_name or command_name:lower() ~= "tbag" then return true end

    if not isAdmin(id) then
        replyToExecutor(id, "You do not have permission to use this command.")
        return false
    end

    argument = argument:lower()
    if argument == "" then argument = "toggle" end

    if argument == "help" then
        replyToExecutor(id, "Usage: /tbag [on|off|toggle|status|help]")
    elseif argument == "status" then
        replyToExecutor(id, "Tea Bagging is " .. (config.enabled and "enabled." or "disabled."))
    elseif argument == "toggle" then
        local actor_name = id == 0 and "the server console" or (get_var(id, "$name") or "an administrator")
        setEnabled(not config.enabled, actor_name)
    elseif argument == "on" or argument == "off" then
        local enabled = argument == "on"
        local actor_name = id == 0 and "the server console" or (get_var(id, "$name") or "an administrator")
        if not setEnabled(enabled, actor_name) then
            replyToExecutor(id, "Tea Bagging is already " .. (enabled and "enabled." or "disabled."))
        end
    else
        replyToExecutor(id, "Usage: /tbag [on|off|toggle|status|help]")
    end

    return false
end

function OnJoin(id)
    players[id] = {
        id = id,
        name = get_var(id, "$name") or "Unknown",
        crouch_count = 0,
        last_crouched = false,
        last_tbag_time = 0,
        target_corpse = nil
    }
end

function OnLeave(id)
    players[id] = nil
    removePlayerCorpses(id)
end

function OnSpawn(id)
    local player = players[id]
    if not player then return end

    player.last_x, player.last_y, player.last_z = nil, nil, nil
    player.name = get_var(id, "$name") or player.name
    player.last_crouched = false
    resetProgress(player)
end

function OnDeath(id)
    local player = players[id]
    if not player then return end

    local dyn = get_dynamic_player(id)
    local x, y, z = getPlayerPosition(dyn)
    if not x then
        x, y, z = player.last_x, player.last_y, player.last_z
    end
    if not x then return end

    player.name = get_var(id, "$name") or player.name
    corpses[#corpses + 1] = {
        victim_id = id,
        victim_name = player.name,
        x = x,
        y = y,
        z = z,
        expires_at = time() + config.expire_time
    }
end

function OnGameStart()
    corpses = {}
    for _, player in pairs(players) do
        player.last_x, player.last_y, player.last_z = nil, nil, nil
    end
    resetAllProgress()
end

function OnGameEnd()
    corpses = {}
    resetAllProgress()
end

function OnTick()
    local now = time()
    removeExpiredCorpses(now)

    for id = 1, 16 do
        if player_present(id) then
            local player = players[id]
            if not player then
                OnJoin(id)
                player = players[id]
            end

            if player_alive(id) then
                local dyn = get_dynamic_player(id)
                if dyn ~= 0 then
                    updatePlayer(player, dyn, now)
                else
                    player.last_crouched = false
                    resetProgress(player)
                end
            else
                player.last_crouched = false
                resetProgress(player)
            end
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_DIE, "OnDeath")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_GAME_END, "OnGameEnd")

    if get_var(0, "$gt") ~= "n/a" then
        OnGameStart()
        for id = 1, 16 do
            if player_present(id) then
                OnJoin(id)
            end
        end
    end
end

function OnScriptUnload()
    unregister_callback(cb.EVENT_JOIN)
    unregister_callback(cb.EVENT_LEAVE)
    unregister_callback(cb.EVENT_SPAWN)
    unregister_callback(cb.EVENT_DIE)
    unregister_callback(cb.EVENT_TICK)
    unregister_callback(cb.EVENT_COMMAND)
    unregister_callback(cb.EVENT_GAME_START)
    unregister_callback(cb.EVENT_GAME_END)
end
