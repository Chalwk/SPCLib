--[[
=====================================================================================
SCRIPT NAME:      mapcycle_manager.lua
DESCRIPTION:      Advanced map rotation system with multiple rotation modes and admin controls.

FEATURES:
                  - Multiple rotation modes (classic, custom, size-based)
                  - Dynamic player count-based adjustments
                  - Comprehensive admin commands:
                    * Cycle control: /custom, /classic, /small, /medium, /large
                    * Navigation: /nextmap, /prev, /restart
                    * Information: /whatis
                    * Direct loading: /loadmap
                  - Configurable randomization and permissions

USAGE:
                  - Configure rotation settings in the config table
                  - Use admin commands to control rotation
                  - System automatically handles player count adjustments when enabled

Copyright (c) 2024 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--------------------------------------------
-- Configuration starts
--------------------------------------------

local config = {

    ------------------------
    -- Command Configuration
    ------------------------
    -- Each command has a permission level, aliases for ease of use, and a cooldown period.
    commands = {
        custom = { level = 4, aliases = { 'set_custom', 'use_custom', 'sv_set_custom' }, cooldown = 10 },
        classic = { level = 4, aliases = { 'set_classic', 'use_classic', 'sv_set_classic' }, cooldown = 10 },
        small = { level = 4, aliases = { 'set_small', 'use_small', 'sv_set_small' }, cooldown = 10 },
        medium = { level = 4, aliases = { 'set_medium', 'use_medium', 'sv_set_medium' }, cooldown = 10 },
        large = { level = 4, aliases = { 'set_large', 'use_large', 'sv_set_large' }, cooldown = 10 },
        whatis = { level = -1, aliases = { 'next_map_info', 'sv_next_map_info' }, cooldown = 10 },
        next = { level = 4, aliases = { 'next_map', 'nextmap', 'sv_next_map' }, cooldown = 10 },
        prev = { level = 4, aliases = { 'prevmap', 'prev_map', 'sv_prev_map' }, cooldown = 10 },
        restart = { level = 4, aliases = { 'restart_map_cycle', 'sv_restart_map_cycle' }, cooldown = 10 },
        loadmap = { level = 4, aliases = { 'load_map', 'sv_load_map' }, cooldown = 10 }
    },

    -----------------------------
    -- Default Map Configuration
    -----------------------------
    -- Sets the default map cycle upon loading (options: 'CLASSIC', 'CUSTOM', etc.).
    default_mapcycle = 'CLASSIC',
    -- Specifies the default map to load when the script starts (e.g., 'beavercreek').
    default_map = 'beavercreek',
    -- Defines the default gametype to use (e.g., 'ctf').
    default_gametype = 'ctf',

    --------------------------
    -- Map Cycle Configuration
    --------------------------
    -- Allows enabling/disabling randomization for each map cycle type:
    mapcycle_randomization = {
        shuffle_on_load = false,
        -- Only applies to these commands: /classic, /custom, /small, /medium, /large
        shuffle_on_command = true,
        cycles = {
            CLASSIC = false,
            CUSTOM = false,
            SMALL = false,
            MEDIUM = false,
            LARGE = false
        }
    },

    -- Defines the maps and gametypes for each rotation (CLASSIC, CUSTOM, SMALL, MEDIUM, LARGE).
    mapcycle = {
        CLASSIC = {
            { 'beavercreek', 'ctf' },
            { 'bloodgulch', 'ctf' },
            { 'boardingaction', 'slayer' },
            { 'carousel', 'king' },
            { 'chillout', 'race' },
            { 'damnation', 'slayer' },
            { 'dangercanyon', 'king' },
            { 'deathisland', 'oddball' },
            { 'gephyrophobia', 'race' },
            { 'hangemhigh', 'ctf' },
            { 'icefields', 'slayer' },
            { 'infinity', 'oddball' },
            { 'longest', 'race' },
            { 'prisoner', 'king' },
            { 'putput', 'slayer' },
            { 'ratrace', 'ctf' },
            { 'sidewinder', 'slayer' },
            { 'timberland', 'king' },
            { 'wizard', 'oddball' }
        },
        CUSTOM = {
            { 'custom_map1', 'ctf' },
            { 'custom_map2', 'king' },
            { 'custom_map3', 'oddball' },
            { 'custom_map4', 'race' },
            { 'custom_map5', 'slayer' }
        },
        SMALL = {
            { 'beavercreek', 'oddball' },
            { 'chillout', 'ctf' },
            { 'longest', 'race' },
            { 'prisoner', 'slayer' },
            { 'wizard', 'king' },


        },
        MEDIUM = {
            { 'carousel', 'king' },
            { 'damnation', 'oddball' },
            { 'putput', 'race' },
            { 'hangemhigh', 'slayer' },
            { 'ratrace', 'ctf' },
            { 'sidewinder', 'slayer' },
        },
        LARGE = {
            { 'bloodgulch', 'race' },
            { 'boardingaction', 'slayer' },
            { 'deathisland', 'king' },
            { 'icefields', 'oddball' },
            { 'infinity', 'ctf' },
            { 'gephyrophobia', 'race' },
            { 'timberland', 'slayer' },
        }
    },

    ------------------------------------
    -- Automatic Map Cycle Configuration
    ------------------------------------
    -- Enables or disables automatic map cycle adjustments based on player count.
    automatic_map_adjustments = {
        enabled = false,
        small = { min = 1, max = 4 },  -- 1 to 4 players for small maps
        medium = { min = 5, max = 10 }, -- 5 to 10 players for medium maps
        large = { min = 11, max = 16 }  -- 11 to 16 players for large maps
    },

    --------------------------
    -- Customizable Messages
    --------------------------
    messages = {
        permission_denied = "You do not have permission to execute this command!",
        command_on_cooldown = "Command is on cooldown! Please wait {seconds} seconds.",
        invalid_map_cycle_type = "Invalid map cycle type: [{cycle_type}]",
        map_loaded = "Loading [{map_name}/{gametype}] in [{cycle_type}] cycle.",
        map_not_found = "[{map_name}/{gametype}] not found in [{cycle_type}] cycle.",
        next_map_info = "Next map: [{map_name}/{gametype}] -> {time_remaining} in [{cycle_type}] cycle.",
        map_cycle_set = {
            "Cycle set to [{cycle_type}]. Loading [{map_name}/{gametype}]",
            "Cycle set to [{cycle_type} (shuffled)]. Loading [{map_name}/{gametype}]"
        },
        loading_next_map = "Loading next map: [{map_name}/{gametype}] in [{cycle_type}] cycle.",
        loading_previous_map = "Loading previous map: [{map_name}] in [{cycle_type}] cycle.",
        map_cycle_restarted = "Cycle [{cycle_type}] has been restarted.",
        loadmap_usage = "Usage: /loadmap <map_name> <gametype_name> <mapcycle_type>"
    }
}

--------------------------------------------
-- Configuration ends
--------------------------------------------

local mapcycleType
local mapcycleIndex
local next_map_flag
local commandCooldowns
local timelimit_address
local tick_counter_address
local sv_map_reset_tick_address

api_version = '1.12.0.0'

local function initializeCooldowns()
    for i = 1, 16 do
        if player_present(i) then
            commandCooldowns[i] = {}
        end
    end
end

local function getMapIndex(current_map, current_gametype)
    for i, cycle in ipairs(config.mapcycle[mapcycleType]) do
        if cycle[1] == current_map and cycle[2] == current_gametype then
            return i
        end
    end
    error('No map cycle found for ' .. current_map .. ' ' .. current_gametype .. ' in ' .. mapcycleType .. ' cycle.')
end

local function shuffle(cycle)
    for i = #cycle, 2, -1 do
        local j = math.random(1, i)
        cycle[i], cycle[j] = cycle[j], cycle[i]
    end
end

local function shuffleAllMapCycles()
    for cycle_type, should_shuffle in pairs(config.mapcycle_randomization.cycles) do
        if should_shuffle then
            shuffle(config.mapcycle[cycle_type])
        end
    end
end

local function loadMapAndGametype(type, index)
    local map, gametype = unpack(config.mapcycle[type][index])
    execute_command('map ' .. map .. ' ' .. gametype)
end

local function initializeMapCycle()
    next_map_flag = false

    local shuffle_on_load = config.mapcycle_randomization.shuffle_on_load
    if shuffle_on_load then
        shuffleAllMapCycles()
    end

    mapcycleType = config.default_mapcycle
    local map = config.default_map
    local gametype = config.default_gametype

    local shuffle_flag = config.mapcycle_randomization.cycles[mapcycleType] and shuffle_on_load
    mapcycleIndex = shuffle_flag and 1 or getMapIndex(map, gametype)

    loadMapAndGametype(mapcycleType, mapcycleIndex)
end

local function loadTimelimitAddresses()
    local tick_counter_sig = sig_scan("8B2D????????807D0000C644240600")
    if (tick_counter_sig == 0) then
        return
    end

    local sv_map_reset_tick_sig = sig_scan("8B510C6A018915????????E8????????83C404")
    if (sv_map_reset_tick_sig == 0) then
        return
    end

    local timelimit_location_sig = sig_scan("8B0D????????83C8FF85C97E17")
    if (timelimit_location_sig == 0) then
        return
    end

    timelimit_address = read_dword(timelimit_location_sig + 2)
    sv_map_reset_tick_address = read_dword(sv_map_reset_tick_sig + 7)
    tick_counter_address = read_dword(read_dword(tick_counter_sig + 2)) + 0xC
end

local floor, format = math.floor, string.format
local function SecondsToTime(seconds)
    local hr = floor(seconds / 3600)
    local min = floor((seconds % 3600) / 60)
    local sec = floor(seconds % 60)
    return format("%02d:%02d:%02d", hr, min, sec)
end

local function getTimeRemaining()
    local timelimit = read_dword(timelimit_address)
    local tick_counter = read_dword(tick_counter_address)
    local sv_map_reset_tick = read_dword(sv_map_reset_tick_address)
    local time_remaining_in_seconds = floor((timelimit - (tick_counter - sv_map_reset_tick)) / 30)
    return SecondsToTime(time_remaining_in_seconds)
end

function OnScriptLoad()

    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_END'], 'OnGameEnd')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')

    commandCooldowns = {}
    initializeMapCycle()
    initializeCooldowns()
    loadTimelimitAddresses()
end

function OnJoin(playerId)
    commandCooldowns[playerId] = {}
end

function OnQuit(playerId)
    commandCooldowns[playerId] = nil
end

local function replacePlaceholders(message, placeholders)
    for key, value in pairs(placeholders) do
        message = message:gsub("{" .. key .. "}", tostring(value))
    end
    return message
end

local function inform(playerId, message, placeholders)
    message = replacePlaceholders(message, placeholders or {})
    return playerId == 0 and cprint(message) or rprint(playerId, message)
end

local function loadSpecificMap(playerId, map_name, gametype_name, mapcycle_type)
    next_map_flag = false

    local cycle_type = mapcycle_type:upper()
    local cycle = config.mapcycle[cycle_type]

    if not cycle then
        inform(playerId, config.messages.invalid_map_cycle_type, { cycle_type = mapcycle_type })
        return false
    end

    for i, entry in ipairs(cycle) do
        local map, gametype = entry[1], entry[2]
        if map == map_name and gametype == gametype_name then
            mapcycleIndex = i
            mapcycleType = cycle_type
            loadMapAndGametype(mapcycleType, mapcycleIndex)

            inform(playerId, config.messages.map_loaded, {
                map_name = map_name,
                gametype = gametype_name,
                cycle_type = mapcycle_type
            })
            return true
        end
    end

    inform(playerId, config.messages.map_not_found, {
        map_name = map_name,
        gametype = gametype_name,
        cycle_type = mapcycle_type
    })
    return false
end

local function loadMap(playerId, direction)
    next_map_flag = false

    local count = #config.mapcycle[mapcycleType]
    mapcycleIndex = (mapcycleIndex + (direction == 'next' and 1 or -1)) % count
    mapcycleIndex = mapcycleIndex < 1 and count or mapcycleIndex  -- Handle index wrap-around

    if playerId then
        local map, gametype = unpack(config.mapcycle[mapcycleType][mapcycleIndex])
        local msg = config.messages[direction == 'next' and 'loading_next_map' or 'loading_previous_map']
        inform(playerId, msg, {
            map_name = map,
            gametype = gametype,
            cycle_type = mapcycleType
        })
    end

    loadMapAndGametype(mapcycleType, mapcycleIndex)
end

local function adjustMapCycleBasedOnPlayerCount()
    if not config.automatic_map_adjustments.enabled then
        return false
    end

    local playerCount = tonumber(get_var(0, '$pn'))
    local adjustments = config.automatic_map_adjustments

    local cycles = {
        { type = 'SMALL', min = adjustments.small.min, max = adjustments.small.max },
        { type = 'MEDIUM', min = adjustments.medium.min, max = adjustments.medium.max },
        { type = 'LARGE', min = adjustments.large.min, max = adjustments.large.max },
    }

    for _, cycle in ipairs(cycles) do
        if playerCount >= cycle.min and playerCount <= cycle.max then
            mapcycleType = cycle.type
            mapcycleIndex = 1
            return true
        end
    end
    return false
end

function OnGameEnd()
    adjustMapCycleBasedOnPlayerCount()
    if next_map_flag then
        loadMap(nil, 'next')
    end
    next_map_flag = false
end

function OnStart()
    next_map_flag = true
end

local function isAlias(commandString, aliasTable)
    for _, alias in ipairs(aliasTable) do
        if commandString == alias then
            return true
        end
    end
    return false
end

local function hasPermission(playerId, commandKey)
    local level = tonumber(get_var(playerId, '$lvl')) or 0
    local requiredLevel = config.commands[commandKey].level
    if playerId == 0 or level >= requiredLevel then
        return true
    end
    inform(playerId, config.messages.permission_denied)
    return false
end

function string.split(str)
    local t = {}
    for word in str:gmatch("%S+") do
        t[#t + 1] = word
    end
    return t
end

local function restartMapCycle()
    next_map_flag = false
    mapcycleIndex = 1
    loadMapAndGametype(mapcycleType, mapcycleIndex)
end

local function getNextMap()
    local nextIndex = (mapcycleIndex % #config.mapcycle[mapcycleType]) + 1
    return unpack(config.mapcycle[mapcycleType][nextIndex])
end

local function commandOnCooldown(playerId, key, cmdInfo)
    if playerId == 0 then
        return false
    end

    local currentTime = os.time()
    local lastUsed = commandCooldowns[playerId][key] or 0
    local cooldownTime = lastUsed + cmdInfo.cooldown

    if currentTime < cooldownTime then
        inform(playerId, config.messages.command_on_cooldown, { seconds = cooldownTime - currentTime })
        return true
    end

    commandCooldowns[playerId][key] = currentTime
    return false
end

local function changeMapCycle(playerId, type)

    next_map_flag = false
    mapcycleType = type:upper()

    local isShuffleEnabled = config.mapcycle_randomization.cycles[mapcycleType]
            and config.mapcycle_randomization.shuffle_on_command

    local message = isShuffleEnabled and config.messages.map_cycle_set[2] or config.messages.map_cycle_set[1]

    if isShuffleEnabled then
        shuffle(config.mapcycle[mapcycleType])
    end

    local map, gametype = unpack(config.mapcycle[mapcycleType][mapcycleIndex])

    inform(playerId, message, { cycle_type = mapcycleType, map_name = map, gametype = gametype})
    loadMapAndGametype(mapcycleType, mapcycleIndex)
end

local function handleWhatIs(playerId)
    local map, gametype = getNextMap()
    local time_remaining = getTimeRemaining()
    inform(playerId, config.messages.next_map_info, {
        map_name = map,
        gametype = gametype,
        cycle_type = mapcycleType,
        time_remaining = time_remaining
    })
end

local function handleRestart(playerId)
    restartMapCycle()
    inform(playerId, config.messages.map_cycle_restarted, { cycle_type = mapcycleType })
end

local function handleLoadMap(playerId, args)
    if #args < 4 then
        inform(playerId, config.messages.loadmap_usage)
    else
        loadSpecificMap(playerId, args[2], args[3], args[4])
    end
end

function OnCommand(playerId, command)
    local args = string.split(command)
    local commandString = args[1]:lower()

    for key, cmdInfo in pairs(config.commands) do
        if commandString == key or isAlias(commandString, cmdInfo.aliases) then

            if not hasPermission(playerId, key) or commandOnCooldown(playerId, key, cmdInfo) then
                return false
            end

            if key == 'custom' or key == 'classic' or key == 'small' or key == 'medium' or key == 'large' then
                changeMapCycle(playerId, key)
            elseif key == 'next' then
                loadMap(playerId, 'next')
            elseif key == 'prev' then
                loadMap(playerId, 'prev')
            elseif key == 'whatis' then
                handleWhatIs(playerId)
            elseif key == 'restart' then
                handleRestart(playerId)
            elseif key == 'loadmap' then
                handleLoadMap(playerId, args)
            end

            return false
        end
    end
end