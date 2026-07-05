--[[
=====================================================================================
SCRIPT NAME:      name_ban.lua
DESCRIPTION:      Automatically kicks players who attempt to join with a disallowed name

Copyright (c) 2024-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration: Case-insensitive list of disallowed player names
local BANNED_NAMES = {
    "Butcher",
    "Caboose",
    "Crazy",
    "Cupid",
    "Darling",
    "Dasher",
    "Disco",
    "Donut",
    "Dopey",
    "Ghost",
    "Goat",
    "Grumpy",
    "Hambone",
    "Hollywood",
    "Howard",
    "Jack",
    "Killer",
    "King",
    "Mopey",
    "New001",
    "Noodle",
    "Nuevo001",
    "Penguin",
    "Pirate",
    "Prancer",
    "Saucy",
    "Shadow",
    "Sleepy",
    "Snake",
    "Sneak",
    "Stompy",
    "Stumpy",
    "The Bear",
    "The Big L",
    "Tooth",
    "Walla Walla",
    "Weasel",
    "Wheezy",
    "Whicker",
    "Whisp",
    "Wilshire"
    -- Additional names may be appended as necessary
}

api_version = "1.12.0.0"

local BANNED_LOWER = {}

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnPlayerJoin")

    for _, name in ipairs(BANNED_NAMES) do
        table.insert(BANNED_LOWER, name:lower())
    end
end

function OnPlayerJoin(playerId)
    local playerName = get_var(playerId, "$name"):lower()

    for _, bannedName in ipairs(BANNED_LOWER) do
        if playerName == bannedName then
            execute_command('k ' .. playerId .. ' "Invalid player name detected"')
            return
        end
    end
end

function OnScriptUnload() end
