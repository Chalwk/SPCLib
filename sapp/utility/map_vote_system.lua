--[[
=====================================================================================
SCRIPT NAME:      map_vote_system.lua
DESCRIPTION:      Advanced map voting system with the following features:
                  - Configurable vote limits and re-voting
                  - Supports more than 6 map options
                  - Map repeat prevention
                  - Customizable vote timing and messaging
                  - Multiple game modes per map
                  - Minimum Player Requirement per map (first element in each map's list)
                  - Periodic re-display of vote options (fixes the "flash" issue)

FEATURES:
                  - Players vote by typing numbers in chat
                  - Re-vote capability with configurable limits
                  - Dynamic map selection that prevents excessive repeats
                  - Customizable vote thresholds and timing controls
                  - Clear console option for better visibility
                  - Maps only appear in vote if enough players are online

USAGE:
                  - Configure settings in the MapVoteConfig table
                  - For each map, set minimum players as the FIRST element, then list modes:
                    Example: bloodgulch = { 8, 'ctf', 'slayer', 'koth' }
                  - System automatically activates at game end
                  - Players vote by typing the map number (1-8 by default)

Copyright (c) 2022-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start --------------------------------------------------
local MapVoteConfig = {
    re_vote_allowed = true,   -- Allow players to recast votes.
    max_re_votes = 1,         -- Maximum re-votes allowed per player.
    display_vote_options = 8, -- Number of maps to display for voting.
    clear_console = false,    -- Clear player's console when displaying votes.
    message_format = {
        vote_message = "$name voted for [#$id] $map ($mode)",
        re_vote_message = "$name changed vote to [#$id] $map ($mode)",
        map_option_message = "[$id] $map ($mode)",
        vote_winner = "$map ($mode) won with $votes votes",
        no_votes_message = "No votes cast. Choosing $map ($mode)...",
        invalid_vote = "Invalid vote id. Please enter a number between 1 and $max",
        vote_limit_reached = "You have reached the re-vote limit."
    },
    timers = {
        time_to_show_votes = 7,   -- Time to show votes after game ends.
        time_to_tally_votes = 13, -- Time to tally votes after voting period ends.
        re_show_interval = 4.2    -- Time interval to re-show vote options.
    },
    map_repeats_limit = 2,    -- Maximum number of times a map can be played consecutively.

    --
    -- Map List Settings:
    -- Example: bloodgulch = { 8, 'ctf', 'slayer', 'koth' }  (needs at least 8 players)
    -- If you don't want a minimum, set it to 0 or 1.
    --

    map_list = {
        bloodgulch = { 0, 'ctf', 'slayer', 'koth' },
        deathisland = { 0, 'ctf', 'slayer' },
        sidewinder = { 0, 'ctf', 'slayer', 'race' },
        icefields = { 0, 'ctf' },
        infinity = { 0, 'ctf', 'slayer' },
        timberland = { 0, 'ctf', 'slayer' },
        dangercanyon = { 0, 'ctf' },
        beavercreek = { 0, 'ctf', 'slayer' },
        boardingaction = { 0, 'ctf' },
        carousel = { 0, 'ctf' },
        chillout = { 0, 'ctf', 'slayer' },
        damnation = { 0, 'ctf' },
        gephyrophobia = { 0, 'ctf' },
        hangemhigh = { 0, 'ctf', 'slayer' },
        longest = { 0, 'ctf' },
        prisoner = { 0, 'ctf', 'slayer' },
        putput = { 0, 'ctf' },
        ratrace = { 0, 'ctf' },
        wizard = { 0, 'ctf', 'slayer' }
    }
}

-- Config End --------------------------------------------------

api_version = "1.12.0.0"

local server_prefix = "**SAPP** "
local player_votes = {}
local map_results = {}
local vote_active = false
local map_streak = { last_map = nil, streak_count = 0 }
local current_vote_options = {}

local pairs, ipairs, tonumber = pairs, ipairs, tonumber
local table_insert, math_random = table.insert, math.random

local rprint = rprint
local player_present, get_var, say_all, timer = player_present, get_var, say_all, timer

local function clear_console(id)
    for _ = 1, 25 do
        rprint(id, " ")
    end
end

local function announce(msg)
    execute_command('msg_prefix ""')
    say_all(msg)
    execute_command('msg_prefix "' .. server_prefix .. '"')
end

local function GetPlayerCount()
    return tonumber(get_var(0, "$num")) or 0
end

local function BroadcastVoteOptions()
    for i = 1, 16 do
        if player_present(i) then
            if MapVoteConfig.clear_console then clear_console(i) end
            rprint(i, "Vote for the next map by typing the number:")
            for j, option in ipairs(current_vote_options) do
                local message = MapVoteConfig.message_format.map_option_message
                message = message:gsub("$id", j):gsub("$map", option.map):gsub("$mode", option.mode)
                rprint(i, message)
            end
        end
    end
end

local function contains(table, element)
    for _, value in pairs(table) do
        if value.map == element.map and value.mode == element.mode then
            return true
        end
    end
    return false
end

local function GenerateMapOptions()
    local maps = MapVoteConfig.map_list
    local player_count = GetPlayerCount()
    local vote_options = {}
    local count = 0

    -- Create a flat list of all map-mode combinations that meet player requirements
    local all_options = {}
    for map_name, entry in pairs(maps) do
        local min_players
        local modes

        if type(entry[1]) == "number" then
            min_players = entry[1]
            modes = { unpack(entry, 2) }
        else
            min_players = 1
            modes = entry
        end

        if player_count >= min_players then
            for _, mode in ipairs(modes) do
                table_insert(all_options, { map = map_name, mode = mode })
            end
        end
    end

    -- Fallback: if no maps meet the player requirement, include all maps (ignore minimum)
    if #all_options == 0 then
        for map_name, entry in pairs(maps) do
            local modes
            if type(entry[1]) == "number" then
                modes = { unpack(entry, 2) }
            else
                modes = entry
            end
            for _, mode in ipairs(modes) do
                table_insert(all_options, { map = map_name, mode = mode })
            end
        end
    end

    -- Shuffle the options to ensure random selection each time
    for i = #all_options, 2, -1 do
        local j = math_random(i)
        all_options[i], all_options[j] = all_options[j], all_options[i]
    end

    -- Select options while considering repeat limits
    for _, option in ipairs(all_options) do
        -- Exclude options that have exceeded the repeat limit
        if map_streak.last_map ~= option.map or map_streak.streak_count < MapVoteConfig.map_repeats_limit then
            if not contains(vote_options, option) then
                table_insert(vote_options, option)
                count = count + 1
            end
        end
        if count >= MapVoteConfig.display_vote_options then
            break
        end
    end

    -- If not enough options were found, allow options that were excluded due to streak
    if count < MapVoteConfig.display_vote_options then
        for _, option in ipairs(all_options) do
            if not contains(vote_options, option) then
                table_insert(vote_options, option)
                count = count + 1
            end
            if count >= MapVoteConfig.display_vote_options then
                break
            end
        end
    end

    return vote_options
end

local function ProcessPlayerVote(id, vote_id)
    if vote_id < 1 or vote_id > #current_vote_options then
        rprint(id, MapVoteConfig.message_format.invalid_vote:gsub("$max", #current_vote_options))
        return
    end

    local player_vote_data = player_votes[id]

    -- First-time vote:
    if not player_vote_data.vote_id then
        player_vote_data.vote_id = vote_id
        player_vote_data.re_votes = MapVoteConfig.max_re_votes

        local voted_option = current_vote_options[vote_id]
        local vote_message = MapVoteConfig.message_format.vote_message
        vote_message = vote_message:gsub("$name", get_var(id, "$name"))
            :gsub("$id", vote_id)
            :gsub("$map", voted_option.map)
            :gsub("$mode", voted_option.mode)
        announce(vote_message)

        -- Tally the votes
        map_results[vote_id] = (map_results[vote_id] or 0) + 1
        return
    end

    -- Already voted before:
    if not MapVoteConfig.re_vote_allowed then
        rprint(id, MapVoteConfig.message_format.vote_limit_reached)
        return
    end

    -- Re-voting enabled:
    if player_vote_data.re_votes > 0 then
        -- Remove previous vote
        if player_vote_data.vote_id then
            map_results[player_vote_data.vote_id] = (map_results[player_vote_data.vote_id] or 1) - 1
        end

        -- Add new vote
        player_vote_data.vote_id = vote_id
        player_vote_data.re_votes = player_vote_data.re_votes - 1

        local voted_option = current_vote_options[vote_id]
        local vote_message = MapVoteConfig.message_format.re_vote_message
        vote_message = vote_message:gsub("$name", get_var(id, "$name"))
            :gsub("$id", vote_id)
            :gsub("$map", voted_option.map)
            :gsub("$mode", voted_option.mode)
        announce(vote_message)

        map_results[vote_id] = (map_results[vote_id] or 0) + 1
    else
        rprint(id, MapVoteConfig.message_format.vote_limit_reached)
    end
end

function RedisplayVoteOptions()
    if vote_active and #current_vote_options > 0 then
        BroadcastVoteOptions()
        return true
    end
    return false
end

function DisplayVoteOptions()
    current_vote_options = GenerateMapOptions()
    map_results = {}

    -- Reset all player votes
    for i = 1, 16 do
        if player_present(i) then
            player_votes[i] = { vote_id = nil, re_votes = MapVoteConfig.max_re_votes }
        end
    end

    -- Show vote options immediately, then schedule periodic re-display
    BroadcastVoteOptions()
    if MapVoteConfig.timers.re_show_interval > 0 then
        timer(MapVoteConfig.timers.re_show_interval * 1000, "RedisplayVoteOptions")
    end

    -- Schedule the final tally
    timer(MapVoteConfig.timers.time_to_tally_votes * 1000, "TallyVotesAndSelectMap")
end

function OnPlayerVote(id, msg)
    if not vote_active then return true end

    local vote_id = tonumber(msg)
    if vote_id and vote_id >= 1 and vote_id <= #current_vote_options then
        ProcessPlayerVote(id, vote_id)
        return false
    end

    return true
end

local function load_map(map, mode)
    execute_command('map ' .. map .. ' "' .. mode .. '"')
end

function TallyVotesAndSelectMap()
    vote_active = false -- this stops any further RedisplayVoteOptions calls

    local highest_vote = 0
    local winning_index = 1

    for i, votes in pairs(map_results) do
        if votes > highest_vote then
            highest_vote = votes
            winning_index = i
        end
    end

    local winning_option = current_vote_options[winning_index]

    -- Handle case where no votes were cast
    if highest_vote == 0 then
        -- Select a random option if no votes
        winning_index = math_random(1, #current_vote_options)
        winning_option = current_vote_options[winning_index]
        announce(MapVoteConfig.message_format
                .no_votes_message
                :gsub("$map", winning_option.map)
                :gsub("$mode", winning_option.mode))
    else
        announce(MapVoteConfig.message_format
                .vote_winner
                :gsub("$map", winning_option.map)
                :gsub("$mode", winning_option.mode)
                :gsub("$votes", highest_vote))
    end

    -- Update map streak
    if map_streak.last_map == winning_option.map then
        map_streak.streak_count = map_streak.streak_count + 1
    else
        map_streak.last_map = winning_option.map
        map_streak.streak_count = 1
    end

    load_map(winning_option.map, winning_option.mode)
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    vote_active = false -- ensure no stray redisplay timers continue
    map_results = {}
    current_vote_options = {}

    for i = 1, 16 do
        if player_present(i) then
            player_votes[i] = { vote_id = nil, re_votes = MapVoteConfig.max_re_votes }
        end
    end
end

function OnEnd()
    vote_active = true
    timer(MapVoteConfig.timers.time_to_show_votes * 1000, "DisplayVoteOptions")
end

function OnJoin(id)
    player_votes[id] = { vote_id = nil, re_votes = MapVoteConfig.max_re_votes }
end

function OnQuit(id)
    player_votes[id] = nil
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_CHAT, "OnPlayerVote")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnScriptUnload() end
