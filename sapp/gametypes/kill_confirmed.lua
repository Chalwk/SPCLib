--[[
=====================================================================================
SCRIPT NAME:      kill_confirmed.lua
DESCRIPTION:      Team-based objective mode where players must collect enemy dog tags
                  to score points, inspired by Call of Duty's Kill Confirmed.

LAST UPDATED:     21/09/2025

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG STARTS -------------------------------------------------------------
local SCORE_LIMIT = 65           -- Score needed to win
local POINTS_ON_CONFIRM = 2      -- Points for confirming a kill
local DESPAWN_DELAY = 30         -- Seconds before dog tags disappear
local BLOCK_FRIENDLY_FIRE = true -- Prevent team damage (true/false)
local CONFIRM_OWN = "$name confirmed a kill on $victim"
local CONFIRM_ALLY = "$name confirmed $killer's kill on $victim"
local DENY = "$name denied $killer's kill"
local SUICIDE = "$name committed SUICIDE!"
local FRIENDLY_FIRE = "$name team-killed $victim!"
local SERVER_PREFIX = " " -- Prefix for server announcements
-- CONFIG ENDS --------------------------------------------------------------

local players = {}
local dog_tags = {}
local dog_tag_id
local game_active = false
local os_time = os.time

api_version = "1.12.0.0"

local tonumber, ipairs, table_remove = tonumber, ipairs, table.remove
local get_var, say_all, execute_command = get_var, say_all, execute_command
local get_dynamic_player, get_object_memory = get_dynamic_player, get_object_memory
local read_dword, read_string = read_dword, read_string
local read_vector3d, spawn_object, destroy_object = read_vector3d, spawn_object, destroy_object

local BASE_TAG_TABLE = 0x40440000
local TAG_ENTRY_SIZE, TAG_DATA_OFFSET, BIT_CHECK_OFFSET, BIT_INDEX = 0x20, 0x14, 0x308, 3

local sapp_events = {
    [cb.EVENT_TICK] = 'OnTick',
    [cb.EVENT_JOIN] = 'OnJoin',
    [cb.EVENT_DIE] = 'OnDeath',
    [cb.EVENT_LEAVE] = 'OnQuit',
    [cb.EVENT_GAME_END] = 'OnEnd',
    [cb.EVENT_DAMAGE_APPLICATION] = 'OnDamage',
    [cb.EVENT_WEAPON_PICKUP] = 'OnWeaponPickup'
}

local function registerCallbacks(enable)
    for event, callback in pairs(sapp_events) do
        if enable then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function getFlagAndOddballData()
    local tag_array = read_dword(BASE_TAG_TABLE)
    local tag_count = read_dword(BASE_TAG_TABLE + 0xC)
    local oddball_id, oddball_name

    for i = 0, tag_count - 1 do
        local tag = tag_array + TAG_ENTRY_SIZE * i
        local tag_class = read_dword(tag)
        if tag_class == 0x77656170 then
            local tag_data = read_dword(tag + TAG_DATA_OFFSET)
            if read_bit(tag_data + BIT_CHECK_OFFSET, BIT_INDEX) == 1 then
                local item_type = read_byte(tag_data + 2)
                local meta_id = read_dword(tag + 0xC)
                local tag_name = read_string(read_dword(tag + 0x10))
                if item_type == 4 then
                    oddball_id, oddball_name = meta_id, tag_name
                    break
                end
            end
        end
    end

    return oddball_id, oddball_name
end

local function fmt(msg, vars)
    return (msg:gsub("%$(%w+)", function(key)
        return vars[key] or ("$" .. key)
    end))
end

local function announce(msg, vars)
    execute_command('msg_prefix ""')
    say_all(fmt(msg, vars))
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')
end

local function updateScsore(player, points)
    local current_score = tonumber(get_var(player.id, "$score"))
    execute_command("score " .. player.id .. " " .. (current_score + points))

    local team = player.team == "red" and 0 or 1
    local team_score = tonumber(get_var(0, player.team == "red" and "$redscore" or "$bluescore"))
    execute_command("team_score " .. team .. " " .. (team_score + points))
end

local function newPlayer(id)
    return {
        id = id,
        name = get_var(id, "$name"),
        team = get_var(id, "$team"),
        kills = 0,
        deaths = 0,
        confirms = 0,
        denies = 0
    }
end

local function destroyDogTag(tag)
    if tag.object_id then
        destroy_object(tag.object_id)
    end
end

local function shouldDespawn(tag)
    return (os_time() - tag.spawn_time) >= DESPAWN_DELAY
end

local function getPos(player_id)

    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return end

    local crouch = read_float(dyn_player + 0x50C)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn_player + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    end

    return x, y, z + 0.65 - (0.3 * crouch)
end

local function spawnDogTag(tag)
    local x, y, z = getPos(tag.victim_id)
    if not x then return end
    tag.object_id = spawn_object('', '', x, y, z + 0.3, 0, dog_tag_id)
    tag.object_memory = get_object_memory(tag.object_id)
end

local function newDogTag(killer_id, victim_id)
    local killer = players[killer_id]
    local victim = players[victim_id]

    local tag = {
        killer_id = killer_id,
        victim_id = victim_id,
        killer_name = killer.name,
        victim_name = victim.name,
        killer_team = killer.team,
        victim_team = victim.team,
        spawn_time = os_time(),
        object_id = nil,
        object_memory = nil
    }
    spawnDogTag(tag)
    return tag
end

local function collectDogTag(player_id, object_memory)
    for i, tag in ipairs(dog_tags) do
        if tag.object_memory == object_memory then
            local collector = players[player_id]
            local is_confirmation = collector.team == tag.killer_team
            local is_denial = collector.team == tag.victim_team

            if is_confirmation then
                collector.confirms = collector.confirms + 1
                updateScsore(collector, POINTS_ON_CONFIRM)

                local msg = (player_id == tag.killer_id) and
                    CONFIRM_OWN or
                    CONFIRM_ALLY

                announce(msg, {
                    name = collector.name,
                    killer = tag.killer_name,
                    victim = tag.victim_name
                })
            elseif is_denial then
                collector.denies = collector.denies + 1

                announce(DENY, {
                    name = collector.name,
                    killer = tag.killer_name
                })
            end

            destroyDogTag(tag)
            table_remove(dog_tags, i)
            return true
        end
    end
    return false
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    game_active, players, dog_tags = true, {}, {}

    dog_tag_id = getFlagAndOddballData()
    if dog_tag_id == nil then
        cprint("Dog Tag (oddball) not found on this map", 10)
        registerCallbacks(false)
        return
    end

    for i = 1, 16 do
        if player_present(i) then
            players[i] = newPlayer(i)
        end
    end

    registerCallbacks(true)
    execute_command("scorelimit " .. SCORE_LIMIT)
end

function OnEnd()
    game_active = false
    for _, tag in ipairs(dog_tags) do
        destroyDogTag(tag)
    end
    dog_tags = {}
end

function OnJoin(id)
    players[id] = newPlayer(id)
end

function OnQuit(id)
    for i = #dog_tags, 1, -1 do
        local tag = dog_tags[i]
        if tag.killer_id == id or tag.victim_id == id then
            destroyDogTag(tag)
            table_remove(dog_tags, i)
        end
    end

    players[id] = nil
end

function OnTick()
    if not game_active then return end

    for i = #dog_tags, 1, -1 do
        if shouldDespawn(dog_tags[i]) then
            destroyDogTag(dog_tags[i])
            table_remove(dog_tags, i)
        end
    end
end

function OnDeath(victim_id, killer_id)
    if not game_active then return end

    victim_id = tonumber(victim_id)
    killer_id = tonumber(killer_id)
    if killer_id == 0 or killer_id == -1 then return end -- server/environmental kill

    local victim = players[victim_id]
    local killer = players[killer_id]

    if not victim or not killer then return end

    if victim_id == killer_id then
        announce(SUICIDE, { name = victim.name })
        victim.deaths = victim.deaths + 1
        return
    end

    if not BLOCK_FRIENDLY_FIRE then
        if killer.team == victim.team then
            announce(FRIENDLY_FIRE, {
                name = killer.name,
                victim = victim.name
            })
            killer.kills = killer.kills + 1
            victim.deaths = victim.deaths + 1
            updateScsore(killer, -1)
            return
        end
    end

    killer.kills = killer.kills + 1
    victim.deaths = victim.deaths + 1

    table.insert(dog_tags, newDogTag(killer_id, victim_id))
    updateScsore(killer, -1)
end

function OnWeaponPickup(player_id, slot_index, weapon_type)
    if not game_active or tonumber(weapon_type) ~= 1 then return true end

    local dyn = get_dynamic_player(player_id)
    if dyn == 0 then return end

    local weapon_id = read_dword(dyn + 0x2F8 + (slot_index - 1) * 4)
    local object_memory = get_object_memory(weapon_id)

    if weapon_id == 0xFFFFFFFF or object_memory == 0 then return nil end

    collectDogTag(player_id, object_memory)
end

function OnDamage(victim_id, killer_id)
    if not game_active or not BLOCK_FRIENDLY_FIRE then return true end

    victim_id = tonumber(victim_id)
    killer_id = tonumber(killer_id)
    if killer_id == 0 then return true end

    local victim = players[victim_id]
    local killer = players[killer_id]
    if not victim or not killer then return true end

    if victim_id ~= killer_id and victim.team == killer.team then return false end

    return true
end

function OnScriptUnload()
    for _, tag in ipairs(dog_tags) do
        destroyDogTag(tag)
    end
end
