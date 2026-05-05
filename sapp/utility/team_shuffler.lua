--[[
=====================================================================================
SCRIPT NAME:      team_shuffler.lua
DESCRIPTION:      Advanced team balancing system with automatic and manual shuffling,
                  configurable rules, and FFA mode detection.

FEATURES:
                  - Automatic shuffling after configurable delay
                  - Manual shuffle command with permissions
                  - Minimum player count requirement
                  - Game frequency controls (every X games)
                  - Smart FFA mode detection
                  - Customizable notification messages
                  - Anti-duplicate team assignment protection
                  - Death message suppression during shuffles

COMMANDS:
                  /shuffle - Manually shuffle teams (requires permission)

CONFIGURATION:
                  shuffle_command = 'shuffle'        - Command name
                  shuffle_command_permission = 3     - Required permission level
                  auto_shuffle = true                - Enable auto-shuffle
                  shuffle_after_games = 1            - Auto-shuffle frequency
                  shuffle_delay = 3                  - Shuffle delay (seconds)
                  min_players_required = 2           - Minimum players to shuffle
                  show_shuffle_message = true        - Toggle shuffle notifications

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

---------------------------------
-- CONFIGURATION
---------------------------------

local shuffle_command = 'shuffle'    -- Command to manually shuffle teams
local shuffle_command_permission = 3 -- Permission level for shuffle command
local auto_shuffle = true            -- Enable auto-shuffle [true/false]
local shuffle_after_games = 1        -- Auto-shuffle every X games (min 1)
local shuffle_delay = 3              -- Delay after game start (seconds)
local show_shuffle_message = true    -- Show shuffle messages [true/false]
local min_players_required = 2       -- Minimum players required to shuffle teams

---------------------------------
-- MESSAGES
---------------------------------

local messages = {
    shuffle_auto = "Teams have been shuffled automatically!",
    shuffle_manual = "Teams have been shuffled by $name!",
    shuffle_soon = "Shuffling teams in $delay seconds!",
    not_enough_players = "Not enough players to shuffle teams",
    no_permission = "You don't have permission to shuffle teams!",
    not_team_game = "Team shuffling is only available in team games!"
}

---------------------------------
-- END CONFIGURATION
---------------------------------

api_version = "1.12.0.0"
local game_count = 0
local death_message_hook_enabled = false
local death_message_address = nil
local original_death_message_bytes = nil
local DEATH_MESSAGE_SIGNATURE = "8B42348A8C28D500000084C9"

-- Death message handling
local function SetupDeathMessageHook()
    local address = sig_scan(DEATH_MESSAGE_SIGNATURE)
    if address == 0 then
        cprint("Team Shuffler: Death message signature not found!", 4)
        return false
    end

    death_message_address = address + 3
    original_death_message_bytes = read_dword(death_message_address)

    if not original_death_message_bytes or original_death_message_bytes == 0 then
        cprint("Team Shuffler: Failed to read original death message bytes!", 4)
        death_message_address = nil
        return false
    end

    return true
end

local function disableDeathMessages()
    if death_message_hook_enabled and death_message_address then
        safe_write(true)
        write_dword(death_message_address, 0x03EB01B1)
        safe_write(false)
    end
end

local function restoreDeathMessages()
    if death_message_hook_enabled and death_message_address and original_death_message_bytes then
        safe_write(true)
        write_dword(death_message_address, original_death_message_bytes)
        safe_write(false)
    end
end

function OnScriptLoad()
    math.randomseed(os.time()) -- Ensure proper randomness
    death_message_hook_enabled = SetupDeathMessageHook()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    game_count = 0
end

function OnScriptUnload()
    if death_message_hook_enabled then
        restoreDeathMessages()
    end
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Check if this is a team-based game
local function is_team_game()
    return get_var(0, "$ffa") == "0"
end

-- Returns true if shuffle succeeded, false if not enough players
local function shuffleTeams()
    local players = {}
    local original_teams = {} -- Store original team for each player

    for i = 1, 16 do
        if player_present(i) then
            original_teams[i] = get_var(i, "$team")
            table.insert(players, i)
        end
    end

    if #players < min_players_required then
        if show_shuffle_message then
            say_all(messages.not_enough_players)
        end
        return false
    end

    players = shuffle(players)

    -- Check if new assignment is identical to original
    local identical = true
    for i, id in ipairs(players) do
        local new_team = (i <= #players / 2) and "red" or "blue"
        if new_team ~= original_teams[id] then
            identical = false
            break
        end
    end

    -- Force change by swapping first/last players if identical
    if identical then
        players[1], players[#players] = players[#players], players[1]
    end

    disableDeathMessages()
    for i, id in ipairs(players) do
        local desired_team = (i <= #players / 2) and "red" or "blue"
        execute_command("st " .. id .. " " .. desired_team)
    end
    restoreDeathMessages()
    return true
end

function DelayedShuffle()
    if not is_team_game() then return end
    local success = shuffleTeams()

    if success and show_shuffle_message then
        say_all(messages.shuffle_auto)
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    if not is_team_game() then return end

    game_count = game_count + 1
    if auto_shuffle and game_count % shuffle_after_games == 0 then
        if show_shuffle_message then
            say_all(messages.shuffle_soon:gsub('$delay', shuffle_delay))
        end
        timer(shuffle_delay * 1000, "DelayedShuffle")
    end
end

local function has_permission(id)
    local level = tonumber(get_var(id, '$lvl'))
    return id == 0 or level >= shuffle_command_permission
end

function OnCommand(id, command)
    if command:lower() == shuffle_command:lower() then
        if not is_team_game() then
            rprint(id, messages.not_team_game)
            return false
        end

        if has_permission(id) then
            local success = shuffleTeams()

            if success and show_shuffle_message then
                say_all(messages.shuffle_manual:gsub('$name', get_var(id, '$name')))
            end
        else
            rprint(id, messages.no_permission)
        end
        return false
    end
end