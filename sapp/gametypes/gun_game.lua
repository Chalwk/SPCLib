--[[
=====================================================================================
SCRIPT NAME:      gun_game.lua
DESCRIPTION:      Competitive weapon progression mode where players advance through
                  weapon tiers by scoring kills. The first player to complete all
                  levels is declared the winner.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- ========== CONFIG START ========== --
local CONFIG = {
    MESSAGES = {
        LEVEL_UP = "Level: $level/$max [$label]",
        MAX_LEVEL = "$name is max level!",
        DEMOTED = "$name was demoted to level $level",
        VICTORY = "$name won the game!"
    },

    SETTINGS = {
        STARTING_LEVEL = 1,   -- Starting level for players
        INFINITE_AMMO = true, -- Set to false to disable infinite ammo
        REFILL_RATE = 1       -- Time (in seconds) between ammo refills
    },

    WEAPON_LEVELS = {
        { -- level 1
            TAG = "weapons\\rocket launcher\\rocket launcher",
            LABEL = "Rocket Launcher",
            FRAG_GRENADES = 1,
            PLASMA_GRENADES = 1,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 2
            TAG = "weapons\\plasma_cannon\\plasma_cannon",
            LABEL = "Plasma Cannon",
            FRAG_GRENADES = 1,
            PLASMA_GRENADES = 1,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 3
            TAG = "weapons\\sniper rifle\\sniper rifle",
            LABEL = "Sniper Rifle",
            FRAG_GRENADES = 1,
            PLASMA_GRENADES = 1,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 4
            TAG = "weapons\\shotgun\\shotgun",
            LABEL = "Shotgun",
            FRAG_GRENADES = 1,
            PLASMA_GRENADES = 0,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 5
            TAG = "weapons\\pistol\\pistol",
            LABEL = "Pistol",
            FRAG_GRENADES = 1,
            PLASMA_GRENADES = 0,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 6
            TAG = "weapons\\assault rifle\\assault rifle",
            LABEL = "Assault Rifle",
            FRAG_GRENADES = 1,
            PLASMA_GRENADES = 0,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 7
            TAG = "weapons\\flamethrower\\flamethrower",
            LABEL = "Flamethrower",
            FRAG_GRENADES = 0,
            PLASMA_GRENADES = 1,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 8
            TAG = "weapons\\needler\\mp_needler",
            LABEL = "Needler",
            FRAG_GRENADES = 0,
            PLASMA_GRENADES = 1,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 9
            TAG = "weapons\\plasma rifle\\plasma rifle",
            LABEL = "Plasma Rifle",
            FRAG_GRENADES = 0,
            PLASMA_GRENADES = 1,
            DAMAGE_MULTIPLIER = 1
        },
        { -- level 10
            TAG = "weapons\\plasma pistol\\plasma pistol",
            LABEL = "Plasma Pistol",
            FRAG_GRENADES = 0,
            PLASMA_GRENADES = 0,
            DAMAGE_MULTIPLIER = 1
        }
    },

    -- List of restricted objects (weapons, grenades, and vehicles)
    -- Players will not be able to interact with these objects
    RESTRICTED_OBJECTS = {
        'weapons\\assault rifle\\assault rifle',
        'weapons\\flamethrower\\flamethrower',
        'weapons\\needler\\mp_needler',
        'weapons\\pistol\\pistol',
        'weapons\\plasma pistol\\plasma pistol',
        'weapons\\plasma rifle\\plasma rifle',
        'weapons\\plasma_cannon\\plasma_cannon',
        'weapons\\rocket launcher\\rocket launcher',
        'weapons\\shotgun\\shotgun',
        'weapons\\sniper rifle\\sniper rifle',
        'weapons\\frag grenade\\frag grenade',
        'weapons\\plasma grenade\\plasma grenade',
        'vehicles\\ghost\\ghost_mp',
        'vehicles\\rwarthog\\rwarthog',
        'vehicles\\banshee\\banshee_mp',
        'vehicles\\warthog\\mp_warthog',
        'vehicles\\scorpion\\scorpion_mp',
        'vehicles\\c gun turret\\c gun turret_mp'
    }
}

-- ========== CONFIG ENDS ========== --

api_version = '1.12.0.0'

-- Game State Management
local game = {
    players = {},
    game_over = false,
    weapon_tag_ids = {},
    restricted_object_ids = {},
    last_ammo_refill = 0,
    maxLevel = #CONFIG.WEAPON_LEVELS
}

local os_time = os.time
local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local execute_command = execute_command
local read_dword = read_dword
local lookup_tag = lookup_tag
local spawn_object = spawn_object
local assign_weapon = assign_weapon
local destroy_object = destroy_object
local get_object_memory = get_object_memory

local function getTagId(class, path)
    local tag = lookup_tag(class, path)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function initializeTagIds()
    for _, level in ipairs(CONFIG.WEAPON_LEVELS) do
        game.weapon_tag_ids[level.TAG] = getTagId("weap", level.TAG)
    end
    for _, object in ipairs(CONFIG.RESTRICTED_OBJECTS) do
        game.restricted_object_ids[object] = true
    end
end

local function setObjectInteractionState(enabled)
    local command = enabled and "enable_object" or "disable_object"
    for objectPath, _ in pairs(game.restricted_object_ids) do
        execute_command(command .. " '" .. objectPath .. "'")
    end
end

local function levelUp(player)
    player.level = player.level + 1

    if player.level >= game.maxLevel then
        execute_command("sv_map_next")
    else
        local level_data = CONFIG.WEAPON_LEVELS[player.level]
        rprint(
            player.id,
            CONFIG.MESSAGES
                .LEVEL_UP
                :gsub("$level", player.level)
                :gsub("$max", game.maxLevel)
                :gsub("$label", level_data.LABEL)
        )

        if player.level == game.maxLevel then
            say_all(CONFIG.MESSAGES.MAX_LEVEL:gsub("$name", player.name))
        end
        player.assign = true
    end
end

local function levelDown(player)
    if player.level > CONFIG.SETTINGS.STARTING_LEVEL then
        player.level = player.level - 1
        say_all(CONFIG.MESSAGES
                .DEMOTED
                :gsub("$name", player.name)
                :gsub("$level", player.level))
    else
        player.level = CONFIG.SETTINGS.STARTING_LEVEL
    end
    player.assign = true
end

local function assignWeapon(player)
    local level_data = CONFIG.WEAPON_LEVELS[player.level]
    if not level_data then return end

    execute_command("wdel " .. player.id)
    execute_command("nades " .. player.id .. " 0")

    if level_data.FRAG_GRENADES > 0 then
        execute_command("nades " .. player.id .. " " .. level_data.FRAG_GRENADES .. " 1")
    end
    if level_data.PLASMA_GRENADES > 0 then
        execute_command("nades " .. player.id .. " " .. level_data.PLASMA_GRENADES .. " 2")
    end

    local weapon_id = game.weapon_tag_ids[level_data.TAG]
    if weapon_id then
        local object = spawn_object('', '', 0, 0, 0, 0, weapon_id)
        assign_weapon(object, player.id)
    end

    player.assign = false
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_DIE, "OnDeath")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_OBJECT_SPAWN, "OnObjectSpawn")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")

    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    game.weapon_tag_ids = {}
    game.restricted_object_ids = {}
    initializeTagIds()
    setObjectInteractionState(false)
    execute_command("scorelimit 99999")

    game.players = {}
    game.game_over = false
    game.last_ammo_refill = os_time()

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnEnd()
    game.game_over = true
end

function OnTick()
    if game.game_over then return end

    local now = os_time()

    for i, player in pairs(game.players) do
        if player_alive(i) then
            if player.assign then
                assignWeapon(player)
            elseif CONFIG.SETTINGS.INFINITE_AMMO then
                if now >= game.last_ammo_refill + CONFIG.SETTINGS.REFILL_RATE then
                    game.last_ammo_refill = now
                    execute_command("ammo " .. i .. " 999")
                    execute_command("battery " .. i .. " 100")
                end
            end
        end
    end
end

function OnJoin(playerId)
    game.players[playerId] = {
        id = playerId,
        name = get_var(playerId, "$name"),
        level = CONFIG.SETTINGS.STARTING_LEVEL,
        assign = true
    }
end

function OnQuit(playerId)
    game.players[playerId] = nil
end

function OnSpawn(playerId)
    local player = game.players[playerId]
    if player then
        player.assign = true
    end
end

function OnDeath(victimId, killerId)
    if game.game_over then return end

    victimId = tonumber(victimId)
    killerId = tonumber(killerId)

    local victim = game.players[victimId]
    if not victim then return end

    if victimId == killerId then
        levelDown(victim)
    else
        local killer = game.players[killerId]
        if killer then
            levelUp(killer)
        end
    end
end

local function handleBacktap(victim, killer, backtap)
    if backtap == 1 then
        levelDown(victim)
        levelUp(killer)
    end
end

function OnDamage(victimId, killerId, _, damage, _, backtap)
    if game.game_over then return end

    victimId = tonumber(victimId)
    killerId = tonumber(killerId)

    local victim = game.players[victimId]
    local killer = game.players[killerId]

    if killer and victim then
        handleBacktap(victim, killer, backtap)
        return true, damage * CONFIG.WEAPON_LEVELS[killer.level].DAMAGE_MULTIPLIER
    end
end

function OnObjectSpawn(objectId)
    local object = get_object_memory(objectId)
    if object ~= 0 then
        local objectTagId = read_dword(object)
        for _, tagId in pairs(game.weapon_tag_ids) do
            if tagId == objectTagId then
                destroy_object(objectId)
                return false
            end
        end
    end
end

function OnScriptUnload()
    setObjectInteractionState(true)
end
