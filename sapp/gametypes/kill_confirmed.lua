--[[
=====================================================================================
SCRIPT NAME:    kill_confirmed.lua
DESCRIPTION:    Team-based objective mode where players must collect enemy skulls
                to score points, inspired by Call of Duty's Kill Confirmed.
                
                Requires a team Slayer gametype on a map that contains the oddball
                weapon tag (every stock map does).

LAST UPDATED:   20 Nov 2026

Copyright (c) 2020-2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
            https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

-- CONFIG STARTS -------------------------------------------------------------
local SCORE_LIMIT = 65           -- Score needed to win
local POINTS_ON_CONFIRM = 2      -- Points for confirming a kill
local TEAMKILL_PENALTY = 1       -- Points lost for a team kill
local DESPAWN_DELAY = 30         -- Seconds before skulls disappear
local BLOCK_FRIENDLY_FIRE = true -- Prevent team damage (true/false)

local CONFIRM_OWN = "$name confirmed a kill on $victim"
local CONFIRM_ALLY = "$name confirmed $killer's kill on $victim"
local DENY = "$name denied $killer's kill"
local SUICIDE = "$name committed SUICIDE!"
local FRIENDLY_FIRE = "$name team-killed $victim!"
local TOP_CONFIRMER = "Most kills confirmed: $name ($count)"
local SERVER_PREFIX = " " -- Prefix for server announcements
-- CONFIG ENDS --------------------------------------------------------------

api_version = "1.12.0.0"

local os_time = os.time
local pairs, next, tonumber, tostring = pairs, next, tonumber, tostring
local string_format = string.format
local get_var, say_all, execute_command, cprint = get_var, say_all, execute_command, cprint
local player_present = player_present
local get_dynamic_player, get_object_memory = get_dynamic_player, get_object_memory
local read_dword, read_float, read_byte, read_bit = read_dword, read_float, read_byte, read_bit
local read_vector3d, spawn_object, destroy_object = read_vector3d, spawn_object, destroy_object

local TICKS_PER_SECOND = 30
local DESPAWN_TICKS = DESPAWN_DELAY * TICKS_PER_SECOND

local NO_OBJECT = 0xFFFFFFFF
local WEAPON_SLOTS = 4
local WEAPON_SLOTS_OFFSET = 0x2F8
local VEHICLE_ID_OFFSET = 0x11C
local CROUCH_OFFSET = 0x50C
local POSITION_OFFSET = 0x5C

local TAG_LIFT = 0.3
local EYE_HEIGHT = 0.65
local CROUCH_DROP = 0.3

local BASE_TAG_TABLE = 0x40440000
local TAG_ENTRY_SIZE, TAG_DATA_OFFSET = 0x20, 0x14
local WEAPON_CLASS = 0x77656170 -- "weap"
local OBJECTIVE_FLAG_OFFSET, OBJECTIVE_FLAG_BIT = 0x308, 3
local OBJECTIVE_TYPE_OFFSET, ODDBALL_TYPE = 0x2, 4

local players, skulls = {}, {}

local oddball_tag_id
local game_active = false

local function getFallbackTick()
    return os_time() * TICKS_PER_SECOND
end
local getCurrentTick = getFallbackTick

local function registerCallbacks(enable)
    if enable then
        register_callback(cb.EVENT_TICK, "OnTick")
        register_callback(cb.EVENT_DIE, "OnDie")
        register_callback(cb.EVENT_LEAVE, "OnLeave")
        register_callback(cb.EVENT_GAME_END, "OnEnd")
        register_callback(cb.EVENT_TEAM_SWITCH, "OnTeamSwitch")
        register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")
        register_callback(cb.EVENT_WEAPON_PICKUP, "OnWeaponPickup")
        return
    end

    unregister_callback(cb.EVENT_TICK)
    unregister_callback(cb.EVENT_DIE)
    unregister_callback(cb.EVENT_LEAVE)
    unregister_callback(cb.EVENT_GAME_END)
    unregister_callback(cb.EVENT_TEAM_SWITCH)
    unregister_callback(cb.EVENT_DAMAGE_APPLICATION)
    unregister_callback(cb.EVENT_WEAPON_PICKUP)
end

local function findOddballTagId()
    local tag_array = read_dword(BASE_TAG_TABLE)
    local tag_count = read_dword(BASE_TAG_TABLE + 0xC)

    for i = 0, tag_count - 1 do
        local entry = tag_array + TAG_ENTRY_SIZE * i
        if read_dword(entry) == WEAPON_CLASS then
            local tag_data = read_dword(entry + TAG_DATA_OFFSET)
            if tag_data ~= 0 and read_bit(tag_data + OBJECTIVE_FLAG_OFFSET, OBJECTIVE_FLAG_BIT) == 1
                and read_byte(tag_data + OBJECTIVE_TYPE_OFFSET) == ODDBALL_TYPE then
                return read_dword(entry + 0xC)
            end
        end
    end

    return nil
end

local function formatMessage(message, vars)
    return (message:gsub("%$(%w+)", function (key)
        local value = vars[key]
        return value ~= nil and tostring(value) or ("$" .. key)
    end))
end

local function announce(message, vars)
    execute_command('msg_prefix ""')
    say_all(formatMessage(message, vars))
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')
end

local function logInvalid(event_name, details)
    cprint(string_format("kill_confirmed: invalid data in %s (%s)", event_name, details), 14)
end

local function addScore(player, points)
    local amount = string_format("%+d", points)
    execute_command(string_format("score %d %s", player.id, amount))
    execute_command(string_format("team_score %s %s", player.team, amount))
end

local function newPlayer(player_id)
    return {
        id = player_id,
        name = get_var(player_id, "$name"),
        team = get_var(player_id, "$team"),
        confirms = 0,
        denies = 0
    }
end

local function getPlayer(player_id)
    local player = players[player_id]
    ---@diagnostic disable-next-line: unnecessary-if
    if player then return player end

    if player_present(player_id) then
        player = newPlayer(player_id)
        players[player_id] = player
        return player
    end

    return nil
end

local function removeDogTag(object_id)
    if get_object_memory(object_id) ~= 0 then -- just in case
        destroy_object(object_id)
    end
    skulls[object_id] = nil
end

local function removeAllDogTags()
    for object_id in pairs(skulls) do
        removeDogTag(object_id)
    end
end

local function getDropPosition(player_id)
    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return nil end

    local object = dyn_player
    local vehicle_id = read_dword(dyn_player--[[@cast -?]] + VEHICLE_ID_OFFSET)
    if vehicle_id ~= NO_OBJECT then
        object = get_object_memory(vehicle_id)
        if object == 0 then return nil end
    end

    local crouch = read_float(dyn_player--[[@cast -?]] + CROUCH_OFFSET)
    local x, y, z = read_vector3d(object--[[@cast -?]] + POSITION_OFFSET)
    return x, y, z + EYE_HEIGHT - CROUCH_DROP * crouch
end

local function spawnDogTag(killer, victim)
    local x, y, z = getDropPosition(victim.id)
    if not x then return end

    local object_id = spawn_object('', '', x, y, z + TAG_LIFT, 0, oddball_tag_id)
    if object_id == 0 then return end

    skulls[object_id] = {
        killer_id = killer.id,
        killer_name = killer.name,
        victim_name = victim.name,
        killer_team = killer.team,
        victim_team = victim.team,
        expires_at = getCurrentTick() + DESPAWN_TICKS
    }
end

local function collectDogTag(collector, object_id, tag)
    if collector.team == tag.killer_team then
        collector.confirms = collector.confirms + 1
        addScore(collector, POINTS_ON_CONFIRM)

        local message = collector.id == tag.killer_id and CONFIRM_OWN or CONFIRM_ALLY
        announce(message, {
            name = collector.name,
            killer = tag.killer_name,
            victim = tag.victim_name
        })
    else
        collector.denies = collector.denies + 1
        announce(DENY, {
            name = collector.name,
            killer = tag.killer_name
        })
    end

    removeDogTag(object_id)
end

local function announceTopConfirmer()
    local top
    for _, player in pairs(players) do
        if player.confirms > 0 and (not top or player.confirms > top.confirms) then
            top = player
        end
    end

    ---@diagnostic disable-next-line: unnecessary-if
    if top then
        announce(TOP_CONFIRMER, { name = top.name, count = top.confirms })
    end
end

local function isTeamSlayer()
    return get_var(0, "$gt") == "slayer" and get_var(0, "$ffa") == "0"
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")

    local sig = sig_scan("8B2D????????807D0000C644240600")
    local pointer = sig ~= 0 and read_dword(sig + 2) or 0

    if pointer < 0x400000 or pointer > 0x800000 then
        cprint("kill_confirmed: tick counter signature failed, using os.time fallback", 14)
        return
    end

    getCurrentTick = function ()
        return read_dword(read_dword(pointer) + 0xC)
    end

    OnStart() -- in case the script was loaded mid-game
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    game_active = false
    players, skulls = {}, {}

    if not isTeamSlayer() then
        cprint("kill_confirmed: requires Team Slayer, idle for this game", 12)
        registerCallbacks(false)
        return
    end

    oddball_tag_id = findOddballTagId()
    if not oddball_tag_id then
        cprint("kill_confirmed: oddball tag (dog tag) not found on this map", 12)
        registerCallbacks(false)
        return
    end

    for i = 1, 16 do
        if player_present(i) then
            players[i] = newPlayer(i)
        end
    end

    game_active = true
    registerCallbacks(true)
    execute_command("scorelimit " .. SCORE_LIMIT)
end

function OnEnd()
    if not game_active then return end

    game_active = false
    removeAllDogTags()
    announceTopConfirmer()
end

function OnLeave(player_id)
    player_id = tonumber(player_id)
    if not player_id then return end

    for _, tag in pairs(skulls) do
        if tag.killer_id == player_id then
            tag.killer_id = nil
        end
    end

    players[player_id] = nil
end

function OnTeamSwitch(player_id)
    local player = getPlayer(player_id)
    if player then
        player.team = get_var(player.id, "$team")
    end
end

function OnTick()
    if not game_active then return end

    local current_tick = getCurrentTick()

    for object_id, tag in pairs(skulls) do
        if current_tick >= tag.expires_at then
            removeDogTag(object_id)
        end
    end
end

function OnDie(victim_id, killer_id)
    if not game_active then return end

    victim_id, killer_id = tonumber(victim_id), tonumber(killer_id)
    if not victim_id or not killer_id or killer_id < 1 then return end

    local victim, killer = getPlayer(victim_id), getPlayer(killer_id)
    if not victim or not killer then
        logInvalid("OnDie", string_format("victim %d, killer %d", victim_id, killer_id))
        return
    end

    if victim_id == killer_id then
        announce(SUICIDE, { name = victim.name })
        return
    end

    if killer.team == victim.team then
        announce(FRIENDLY_FIRE, { name = killer.name, victim = victim.name })
        addScore(killer, -TEAMKILL_PENALTY)
        return
    end

    spawnDogTag(killer, victim)
    addScore(killer, -1)
end

function OnWeaponPickup(player_id, _weapon_slot, weapon_type)
    if not game_active or next(skulls) == nil then return end
    if tonumber(weapon_type) ~= 1 then return end

    player_id = tonumber(player_id)
    local collector = getPlayer(player_id)
    if not collector then
        logInvalid("OnWeaponPickup", "player " .. tostring(player_id))
        return
    end

    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return end

    for slot = 0, WEAPON_SLOTS - 1 do
        local weapon_id = read_dword(dyn_player + WEAPON_SLOTS_OFFSET + slot * 4)
        local tag = skulls[weapon_id]

        ---@diagnostic disable-next-line: unnecessary-if
        if tag then
            collectDogTag(collector, weapon_id, tag)
            return
        end
    end
end

function OnDamageApplication(victim_id, causer_id)
    if not game_active or not BLOCK_FRIENDLY_FIRE then return end

    victim_id, causer_id = tonumber(victim_id), tonumber(causer_id)
    if not victim_id or not causer_id or victim_id == causer_id then return end

    local victim, causer = getPlayer(victim_id), getPlayer(causer_id)
    if victim and causer and victim.team == causer.team then
        return false
    end
end

function OnScriptUnload()
    removeAllDogTags()
end
