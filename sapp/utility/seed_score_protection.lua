--[[
=====================================================================================
SCRIPT NAME:      seed_score_protection.lua
DESCRIPTION:      Prevents score loss when players kill seed (bot) clients.
                  Automatically corrects stats (score, kills, assists, deaths) to prevent negative values.

CONFIGURATION:    - Edit 'bots' table to customize protected seed names
                  - Set 'preventNegatives' to false to allow negative scores

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local preventNegatives = true
local bots = {
    "Butcher", "Caboose", "Crazy", "Cupid", "Darling", "Dasher", "Disco", "Donut", "Dopey", "Ghost",
    "Goat", "Grumpy", "Hambone", "Hollywood", "Howard", "Jack", "Killer", "King", "Mopey", "New001",
    "Noodle", "Nuevo001", "Penguin", "Pirate", "Prancer", "Saucy", "Shadow", "Sleepy", "Snake", "Sneak",
    "Stompy", "Stumpy", "The Bear", "The Big L", "Tooth", "Walla Walla", "Weasel", "Wheezy", "Whicker",
    "Whisp", "Wilshire"
}

-- Script load event handler
function OnScriptLoad()
    register_callback(cb["EVENT_DIE"], "OnPlayerDeath")
end

-- Script unload event handler
function OnScriptUnload()
    -- N/A
end

-- Check if the victim is a bot
local function isBot(victim)
    local victimIP = get_var(victim, "$ip"):match("%d+%.%d+%.%d+%.%d+")
    local victimName = get_var(victim, "$name")

    return victimIP == "127.0.0.1" and table.contains(bots, victimName)
end

-- Adjusts score values to prevent negatives based on configuration
local function adjust(value)
    return preventNegatives and math.max(0, value) or value
end

-- Prevents scoring adjustments for specific players
local function preventScoring(killer, victim)
    local newScore = adjust(tonumber(get_var(killer, "$score")) - 1)
    local newKills = adjust(tonumber(get_var(killer, "$kills")) - 1)
    local newAssists = adjust(tonumber(get_var(killer, "$assists")) - 1)
    local newDeaths = adjust(tonumber(get_var(victim, "$deaths")) - 1)

    -- Update player stats
    execute_command("score " .. killer .. " " .. newScore)
    execute_command("kills " .. killer .. " " .. newKills)
    execute_command("deaths " .. victim .. " " .. newDeaths)
    execute_command("assists " .. killer .. " " .. newAssists)
end

-- Player death event handler
function OnPlayerDeath(victim, killer)
    local victimIndex = tonumber(victim)
    local killerIndex = tonumber(killer)

    -- Check if the killer is valid and if the victim is a bot
    if killerIndex > 0 and killerIndex ~= victimIndex and isBot(victimIndex) then
        preventScoring(killerIndex, victimIndex)
    end
end

-- Helper function to check if a value exists in a table
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end