--[[
=====================================================================================
SCRIPT NAME:      deployable_mines.lua
DESCRIPTION:      Tactical mine deployment system allowing players to place
                  explosive traps that trigger when enemies approach.

FEATURES:         - Vehicle-based mine deployment system
                  - Configurable mine count per life
                  - Timed despawn for placed mines
                  - Adjustable explosion radius
                  - Team damage toggle
                  - Death message customization
                  - Vehicle-specific deployment restrictions

                  Technical note:
                  - The default object to represent mines is 'powerups\\full-spectrum vision'
                    The full-spectrum vision naturally despawns after 30 seconds.

                    An alternative object that won't despawn is 'powerups\\health pack'

                    [!] Important: Ensure your maps have the tag addresses for the objects you want to use.

LAST UPDATED:     18/12/2025

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START -----------------------------------------------

-- Maximum number of mines a player can deploy in a single life
-- Set to 0 for unlimited mines, or any positive integer to limit mine usage
local MINES_PER_LIFE = 20

-- Time in seconds before a deployed mine automatically despawns
local DESPAWN_RATE = 30

-- Detection radius in world units for mine activation
local TRIGGER_RADIUS = 0.7

-- Time in seconds after deployment before the mine becomes active
local MINE_ARM_DELAY = 1.0

-- Team damage control for mine explosions
local MINES_KILL_TEAMMATES = false

-- Set to false to use default death message
local ENABLE_CUSTOM_DEATH_MESSAGE = true
local DEATH_MESSAGE_FORMAT = "$victim was blown up by $killer's mine"

-- When broadcasting a custom death message, the script temporarily removes the msg_prefix, and will
-- restore it to this when the rely is finished.
local SERVER_PREFIX = "**SAPP**"

-- Object tag used to visually represent mines (Must be a valid equipment tag from your maps)
-- 'powerups\\full-spectrum vision' - Naturally despawns after 30 seconds
local MINE_OBJECT = 'powerups\\full-spectrum vision'

-- Fallback mine object if the primary MINE_OBJECT tag is not found
-- Provides redundancy if the primary object isn't available in certain maps
local MINE_OBJECT_FALLBACK = 'powerups\\health pack'

-- Projectile tag used for the mine explosion effect
-- Creates the visual and damage effect when a mine is triggered
local PROJECTILE_OBJECT = 'weapons\\rocket launcher\\rocket'

-- Deployment mode: Determines when players can deploy mines
-- Options: "vehicle_only", "on_foot_only", "both"
local DEPLOYMENT_MODE = "both"

-- List of vehicles that are permitted to deploy mines
-- Only vehicles in this list will have mine deployment capability
-- Add or remove vehicle tags to control which vehicles can deploy mines
-- Format: ['vehicle_tag_path'] = true (enabled) / false (disabled)
local VEHICLES = {
    ['vehicles\\ghost\\ghost_mp'] = true,                                                  -- stock maps
    ['vehicles\\rwarthog\\rwarthog'] = true,                                               -- stock maps
    ['vehicles\\warthog\\mp_warthog'] = true,                                              -- stock maps
    ['halo3\\vehicles\\warthog\\mp_warthog'] = true,                                       -- [h3]_sandtrap
    ['halo3\\vehicles\\mongoose\\mongoose'] = true,                                        -- [h3]_sandtrap
    ['levels\\test\\racetrack\\custom_hogs\\mp_warthog_green'] = true,                     -- bc_raceway_final_mp
    ['levels\\test\\racetrack\\custom_hogs\\mp_warthog_blue'] = true,                      -- bc_raceway_final_mp
    ['levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi1'] = true,                    -- bc_raceway_final_mp
    ['levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi2'] = true,                    -- bc_raceway_final_mp
    ['levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi3'] = true,                    -- bc_raceway_final_mp
    ['vehicles\\rwarthog\\boogerhawg'] = true,                                             -- cityscape-adrenaline
    ['vehicles\\g_warthog\\g_warthog'] = true,                                             -- hypothermia_race
    ['vehicles\\m257_multvp\\m257_multvp'] = true,                                         -- mongoose_point
    ['vehicles\\puma\\puma_lt'] = true,                                                    -- mystic_mod
    ['vehicles\\puma\\rpuma_lt'] = true,                                                   -- mystic_mod
    ['cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_mp\\warthog_mp'] = true,         -- tsce_multiplayerv1
    ['cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_rocket\\warthog_rocket'] = true, -- tsce_multiplayerv1
    ['halo3\\vehicles\\warthog\\rwarthog'] = true,                                         -- hornets_nest
    ['vehicles\\warthog\\art_cwarthog'] = true,                                            -- grove_final
    ['vehicles\\rwarthog\\art_rwarthog_shiny'] = true,                                     -- grove_final
}
-- CONFIG END -------------------------------------------------

api_version = '1.12.0.0'

local map_name
local MINE_TAG_ID, PROJECTILE_TAG_ID
local active_mines, jpt_data, players = {}, {}, {}

local death_message_address
local original_death_message_address

local os_time, pairs = os.time, pairs

local read_vector3d = read_vector3d
local read_string, read_bit = read_string, read_bit
local read_dword, read_word = read_dword, read_word
local write_dword, write_float = write_dword, write_float

local destroy_object = destroy_object
local get_var, rprint = get_var, rprint
local player_present, player_alive = player_present, player_alive
local spawn_projectile, spawn_object = spawn_projectile, spawn_object
local get_object_memory, get_dynamic_player = get_object_memory, get_dynamic_player

local event_handlers = {
    [cb.EVENT_TICK] = 'OnTick',
    [cb.EVENT_JOIN] = 'OnJoin',
    [cb.EVENT_LEAVE] = 'OnQuit',
    [cb.EVENT_SPAWN] = 'OnSpawn',
    [cb.EVENT_TEAM_SWITCH] = 'OnTeamSwitch'
}

local function patchDeathMessages(address, value)
    safe_write(true)
    write_dword(address, value)
    safe_write(false)
end

function restoreDeathMessages()
    patchDeathMessages(death_message_address, original_death_message_address)
end

local function patchDeathMessageForMine(victim_id, killer_id)
    if not ENABLE_CUSTOM_DEATH_MESSAGE then return end

    patchDeathMessages(death_message_address, 0x03EB01B1)

    local message = DEATH_MESSAGE_FORMAT

    local v_name = get_var(victim_id, "$name")
    local k_name = get_var(killer_id, "$name")

    message = message:gsub("$victim", v_name):gsub("$killer", k_name)

    execute_command('msg_prefix ""')
    say_all(message)
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')

    timer(50, "restoreDeathMessages") -- 50ms delay
end

local function fmt(str, ...)
    return select('#', ...) > 0 and str:format(...) or str
end

local function registerEventCallbacks(should_register)
    for event, handler in pairs(event_handlers) do
        if should_register then
            register_callback(event, handler)
        else
            unregister_callback(event)
        end
    end
end

local function getPos(dyn_player)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)
    local pos = {}

    if vehicle_id == 0xFFFFFFFF then
        pos.x, pos.y, pos.z = read_vector3d(dyn_player + 0x5c)
        pos.vehicle = nil; pos.seat = nil
    elseif vehicle_obj ~= 0 then
        pos.vehicle = vehicle_obj
        pos.seat = read_word(dyn_player + 0x2F0)
        pos.x, pos.y, pos.z = read_vector3d(vehicle_obj + 0x5c)
    end

    return pos
end

local function inRange(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return (dx * dx + dy * dy + dz * dz) <= TRIGGER_RADIUS
end

local function getTagID(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function createExplosion(mine_x, mine_y, mine_z, owner_id)
    -- Edit jpt values with modified values
    EditRocket()

    -- Spawn projectile (rocket)
    local projectile_id = spawn_projectile(PROJECTILE_TAG_ID, owner_id, mine_x, mine_y, mine_z)

    if projectile_id ~= 0xFFFFFFFF then
        local projectile_object = get_object_memory(projectile_id)
        if projectile_object ~= 0 then
            write_float(projectile_object + 0x68, 0)     -- Velocity X
            write_float(projectile_object + 0x6C, 0)     -- Velocity Y
            write_float(projectile_object + 0x70, -9999) -- Velocity Z
        end
    end

    -- Restore jpt values after 1 second
    timer(1000, "EditRocket", "true")
end

local function deployMine(player_id, pos, current_time)
    local player = players[player_id]
    if not player then return end

    if MINES_PER_LIFE > 0 and player.mines_remaining <= 0 then
        rprint(player_id, "No more mines for this life!")
        return
    end

    -- Check deployment mode restrictions
    if DEPLOYMENT_MODE == "vehicle_only" then
        if not pos.vehicle then
            rprint(player_id, "You must be in a vehicle to deploy mines")
            return
        end

        if not pos.seat or pos.seat ~= 0 then
            rprint(player_id, "You must be in the driver's seat")
            return
        end

        local vehicle_tag = read_string(read_dword(read_word(pos.vehicle) * 32 + 0x40440038))
        if not VEHICLES[vehicle_tag] then
            rprint(player_id, "This vehicle cannot deploy mines")
            return
        end
    elseif DEPLOYMENT_MODE == "on_foot_only" then
        if pos.vehicle then
            rprint(player_id, "You must be on foot to deploy mines")
            return
        end
    elseif DEPLOYMENT_MODE == "both" then
        if pos.vehicle then
            if not pos.seat or pos.seat ~= 0 then
                rprint(player_id, "You must be in the driver's seat")
                return
            end

            local vehicle_tag = read_string(read_dword(read_word(pos.vehicle) * 32 + 0x40440038))
            if not VEHICLES[vehicle_tag] then
                rprint(player_id, "This vehicle cannot deploy mines")
                return
            end
        end
    else
        rprint(player_id, "Deployment mode error. Contact server admin.")
        return
    end

    -- Spawn mine object
    local mine_id = spawn_object('', '', pos.x, pos.y, pos.z, 0, MINE_TAG_ID)
    if mine_id == 0xFFFFFFFF then
        rprint(player_id, "Failed to deploy mine")
        return
    end

    -- Register mine
    active_mines[mine_id] = {
        owner_id = player_id,
        creation_time = current_time,
        arm_time = current_time + MINE_ARM_DELAY,
        expiration_time = current_time + DESPAWN_RATE
    }

    player.mines_remaining = player.mines_remaining - 1
    rprint(player_id, 'Mine Deployed! ' .. player.mines_remaining .. '/' .. MINES_PER_LIFE)
end

local function destroyMine(mine_id, trigger_explosion, x, y, z, victim_id)
    local mine_data = active_mines[mine_id]
    if not mine_data then return end

    destroy_object(mine_id)

    -- Check if mine should explode
    if trigger_explosion and x and y and z then
        createExplosion(x, y, z, mine_data.owner_id)
        patchDeathMessageForMine(victim_id, mine_data.owner_id)
    end

    active_mines[mine_id] = nil
end

local function monitorMines(player_id, current_time)
    local player = players[player_id]
    if not player or not player_alive(player_id) then return end

    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return end

    local pos = getPos(dyn_player)
    if not pos.x then return end

    for mine_id, mine_data in pairs(active_mines) do
        -- Skip if mine isn't armed yet
        if current_time < mine_data.arm_time then goto continue end

        -- Skip if this is the mine owner
        if mine_data.owner_id == player_id then goto continue end

        -- Skip if team damage is disabled and players are on same team
        if not MINES_KILL_TEAMMATES then
            local mine_owner_team = get_var(mine_data.owner_id, '$team')
            if player.team == mine_owner_team then goto continue end
        end

        -- Check if mine still exists in game world
        local mine_object = get_object_memory(mine_id)
        if mine_object == 0 then
            active_mines[mine_id] = nil
            goto continue
        end

        -- Check if player is in range of mine
        local mine_x, mine_y, mine_z = read_vector3d(mine_object + 0x5C)
        if inRange(pos.x, pos.y, pos.z, mine_x, mine_y, mine_z) then
            destroyMine(mine_id, true, mine_x, mine_y, mine_z, player_id)
        end

        ::continue::
    end
end

local function mineExpiration(current_time)
    for mine_id, mine_data in pairs(active_mines) do
        -- Check if mine still exists (necessary if it despawns naturally, or the map is reset)
        local mine_object = get_object_memory(mine_id)
        if mine_object == 0 then
            active_mines[mine_id] = nil
            goto continue
        end

        if current_time >= mine_data.expiration_time then
            destroyMine(mine_id, false)
        end

        :: continue ::
    end
end

local function flashlightCheck(player_id, current_time)
    local player = players[player_id]
    if not player or not player_alive(player_id) then return end

    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return end

    local current_flashlight = read_bit(dyn_player + 0x208, 4)

    -- Detect flashlight press (rising edge)
    if player.flashlight_state ~= current_flashlight and current_flashlight == 1 then
        local pos = getPos(dyn_player)
        deployMine(player_id, pos, current_time)
    end

    player.flashlight_state = current_flashlight
end

-- JPT data collection (explosion effect modification)
local function initJPTData()
    jpt_data = {}

    local tag_count = read_dword(0x4044000C)
    local tag_address = read_dword(0x40440000)

    for i = 0, tag_count - 1 do
        local tag = tag_address + 0x20 * i
        local tag_name = read_string(read_dword(tag + 0x10))
        local tag_class = read_dword(tag)

        if tag_class == 1785754657 and tag_name == 'weapons\\rocket launcher\\explosion' then
            local tag_data = read_dword(tag + 0x14)
            jpt_data = {
                [tag_data + 0x1d0] = { 1148846080, 1117782016 }, -- Store original and modified values
                [tag_data + 0x1d4] = { 1148846080, 1133903872 },
                [tag_data + 0x1d8] = { 1148846080, 1134886912 },
                [tag_data + 0x1f4] = { 1092616192, 1086324736 }
            }
            break
        end
    end
end

local function initAllPlayers()
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

local function initGame()
    if get_var(0, '$gt') == 'n/a' then return false end

    map_name = get_var(0, '$map')
    players = {};
    jpt_data = {};
    active_mines = {}

    -- Set mine object representation
    MINE_TAG_ID = getTagID('eqip', MINE_OBJECT)
    if not MINE_TAG_ID then
        MINE_TAG_ID = getTagID('eqip', MINE_OBJECT_FALLBACK)
        print(fmt(
            "Deployable Mines [%s]: Failed to find (%s). Trying fallback mine tag (%s)",
            map_name,
            MINE_OBJECT,
            MINE_OBJECT_FALLBACK))
    end

    PROJECTILE_TAG_ID = getTagID('proj', PROJECTILE_OBJECT)

    if not MINE_TAG_ID or not PROJECTILE_TAG_ID then
        return false, 'Deployable Mines [%s]: Failed to load! Could not find valid mine or projectile tags.'
    end

    -- Initialize JPT data for explosion effects
    initJPTData()

    -- Initialize existing players
    initAllPlayers()

    return true
end

function OnScriptLoad()
    death_message_address = sig_scan('8B42348A8C28D500000084C9') + 3
    original_death_message_address = read_dword(death_message_address)

    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart() -- in case script is loaded mid-game
end

function OnTick()
    local current_time = os_time()

    for player_id, player_data in pairs(players) do
        if player_data then
            flashlightCheck(player_id, current_time)
            monitorMines(player_id, current_time)
        end
    end

    mineExpiration(current_time)
end

function OnJoin(player_id)
    players[player_id] = {
        id = player_id,
        name = get_var(player_id, '$name'),
        team = get_var(player_id, '$team'),
        flashlight_state = 0,
        last_mine_time = 0,
        mines_remaining = MINES_PER_LIFE
    }
end

function OnQuit(player_id)
    for mine_id, mine_data in pairs(active_mines) do
        if mine_data.owner_id == player_id then
            destroy_object(mine_id)
            active_mines[mine_id] = nil
        end
    end
    players[player_id] = nil
end

function OnSpawn(player_id)
    local player = players[player_id]
    if player then
        player.mines_remaining = MINES_PER_LIFE
    end
end

function OnTeamSwitch(player_id)
    local player = players[player_id]
    if player then
        player.team = get_var(player_id, '$team')
    end
end

function OnStart()
    local success, error_message = initGame()

    if success then
        registerEventCallbacks(true)
        execute_command('disable_object "' .. MINE_OBJECT .. '"')
    else
        registerEventCallbacks(false)
        if error_message then
            error(fmt(error_message, map_name))
        end
    end
end

function EditRocket(rollback)
    for address, values in pairs(jpt_data) do
        write_dword(address, rollback and values[2] or values[1])
    end
    return false -- just in case
end

function OnScriptUnload()
    for mine_id, _ in pairs(active_mines) do destroy_object(mine_id) end
    active_mines = {};
    players = {}
end
