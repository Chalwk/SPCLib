--[[
=====================================================================================
SCRIPT NAME:      name_replacer.lua
DESCRIPTION:      Automated player name randomization system with blacklist protection.

FEATURES:
                  - Automatic detection and replacement of blacklisted names
                  - Randomized name assignment from predefined list
                  - Fallback random name generation when list is exhausted
                  - Name length enforcement (configurable max length)
                  - Name tracking to prevent duplicates

CONFIGURATION:
                  - Edit blacklist for prohibited names
                  - Customize replacement name pool
                  - Adjust maximum name length (default: 11)
                  - No admin commands needed - runs automatically

USAGE:
                  - Configure blacklist and name list at top of script
                  - System activates automatically on player join
                  - Names are tracked throughout game session

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-----------------------------------------
-- Config starts here, edit as needed --
-----------------------------------------

-- List of blacklisted names that should be replaced.
-- Players with any of these names will have their names changed.
local blacklist = {
    'Butcher', 'Caboose', 'Crazy', 'Cupid', 'Darling', 'Dasher',
    'Disco', 'Donut', 'Dopey', 'Ghost', 'Goat', 'Grumpy',
    'Hambone', 'Hollywood', 'Howard', 'Jack', 'Killer', 'King',
    'Mopey', 'New001', 'Noodle', 'Nuevo001', 'Penguin', 'Pirate',
    'Prancer', 'Saucy', 'Shadow', 'Sleepy', 'Snake', 'Sneak',
    'Stompy', 'Stumpy', 'The Bear', 'The Big L', 'Tooth',
    'Walla Walla', 'Weasel', 'Wheezy', 'Whicker', 'Whisp',
    'Wilshire'
}

-- List of random names that can be assigned to players.
local random_names = {
    'Liam', 'Noah', 'Oliver', 'Elijah', 'William', 'James',
    'Benjamin', 'Lucas', 'Henry', 'Alexander', 'Mason',
    'Michael', 'Ethan', 'Daniel', 'Jacob', 'Logan',
    'Jackson', 'Levi', 'Sebastian', 'Mateo', 'Jack',
    'Owen', 'Theodore', 'Aiden', 'Samuel', 'Joseph',
    'John', 'David', 'Wyatt', 'Matthew', 'Luke',
    'Asher', 'Carter', 'Julian', 'Grayson', 'Leo',
    'Jayden', 'Gabriel', 'Isaac', 'Lincoln', 'Anthony'
}

-- Maximum allowed name length.
-- Names longer than this limit will be truncated.
-- Ensure this matches the in-game name length limit (default: 11).
-- Do not set this value higher than 11, as it may cause issues with in-game display.
local MAX_NAME_LENGTH = 11

-----------------------------------------
-- Config ends here, do not edit below --
-----------------------------------------

api_version = "1.12.0.0"

local random_names_status = {} -- Holds name usage status (used flag).
local players = {} -- Tracks players and their assigned names.
local network_struct
local ce
local byte = string.byte
local char = string.char

-- Script initialization logic.
function OnScriptLoad()

    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_PREJOIN, 'OnPreJoin')
    register_callback(cb.EVENT_GAME_START, 'OnStart')

    players = {}
    network_struct = read_dword(sig_scan("F3ABA1????????BA????????C740??????????E8????????668B0D") + 3)
    ce = (halo_type == 'PC' and 0x0 or 0x40)

    -- Initialize the random_names_status table.
    for _, name in ipairs(random_names) do
        random_names_status[name] = { used = false }
    end

    OnStart()
end

-- Generate a random string of a specified length (fallback for random names).
-- Used when no clean random names are available.
local function generateRandomString(length)
    local name = ''
    for _ = 1, length do
        name = name .. char(rand(97, 123)) -- Generate lowercase letters a-z.
    end
    return name
end

-- Get an available random name for a player or fallback to a generated string.
local function getRandomName(player)
    local availableNames = {}

    -- Collect all unused names from the random_names table.
    for name, status in pairs(random_names_status) do
        if not status.used then
            table.insert(availableNames, name)
        end
    end

    -- If there are available names, pick one randomly.
    if #availableNames > 0 then
        local chosenName = availableNames[rand(1, #availableNames + 1)]
        random_names_status[chosenName].used = true
        players[player] = chosenName
        return chosenName
    end

    -- If no clean names are available, generate a random string.
    return generateRandomString(MAX_NAME_LENGTH)
end

-- Mark a name as used in the random_names_status table.
local function checkName(name)
    if random_names_status[name] then
        random_names_status[name].used = true
        players[name] = true
    end
end

-- Assign a new name to a player and update the in-game display.
local function setNewName(playerId, old_name, new_name)

    local address = network_struct + 0x1AA + ce + to_real_index(playerId) * 0x20

    for i = 0, 12 - 1 do
        write_byte(address + i * 2, 0)
    end
    for i = 1, #new_name do
        write_byte(address + (i - 1) * 2, byte(new_name, i))
    end

    cprint(string.format("[Name Replacer] Player %s's name [%s] changed to %s.", playerId, old_name, new_name), 10)
end

-- Handle the pre-join event to check and replace blacklisted names.
function OnPreJoin(playerId)
    local name = get_var(playerId, '$name')
    checkName(name)

    -- Check if the player's name is blacklisted.
    for _, blacklisted_name in ipairs(blacklist) do
        if name == blacklisted_name then
            local new_name = getRandomName(playerId)
            setNewName(playerId, name, new_name)
            break
        end
    end
end

-- Handle player quit events to free up their name.
function OnQuit(playerId)
    local name = players[playerId]
    if name then
        random_names_status[name].used = false
        players[playerId] = nil
    end
end

-- Initialize the script and reset name states at the start of a game.
function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        players = {}
        -- Reset all names to unused.
        for _, status in pairs(random_names_status) do
            status.used = false
        end
        -- Check the names of currently present players.
        for i = 1, 16 do
            if player_present(i) then
                checkName(get_var(i, '$name'))
            end
        end
    end
end