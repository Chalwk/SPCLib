--[[
=====================================================================================
SCRIPT NAME:      taunt_your_players.lua
DESCRIPTION:      Sends humorous taunts to players during gameplay, with customizable
                  messages and event triggers.

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START ----------------------------------------------------------------------

local TAUNT_ON_DEATH = true
local TAUNT_ON_END = true

-- Taunts shown to the player who just died.
-- Messages containing %s are formatted with the victim's name.
local DEATH_MESSAGES = {
    "Aw, %s, I've seen better shooting at the county fair!", "Too bad you've got manure for brains!!",
    "Hell's full of retired gamers, %s. Time you joined them!", "My horse pisses straighter than you shoot!!",
    "Can't you do better than that? Worms move faster!", "Not good enough, %s. Not good enough!",
    "I can already smell your rotting corpse.", "Today is a good day to die, %s!", "Too slow! You'll regret that!!",
    "You insult me, %s!!", "I'm sending you to an early grave!!", "Had enough yet?!",
    "Hope you plant better than you shoot!!", "Damn you and the horse you rode in on!!",
    "Time to fit you for a coffin!!", "You have a date with the undertaker!!", "Your life ends in the wasteland...",
    "Rest in peace, %s.", "You fought valiantly... but in vain.", "You're dead. Again, %s!", "Dead as a doornail.",
    "Time to reload, %s.", "Here's a picture of your corpse. Not pretty.", "Wow. Dead and stupid.",
    "Ha ha ha ha ha. You're dead, moron!", "Couldn't charm your way out of that one, %s.", "Nope. Just nope.",
    "You have perished. What a shame.", "Sell your PC. Just do it.", "You disappoint me, %s."
}

-- Taunts shown to a player based on their final kill count.
local END_MESSAGES = {
    ["0"] = "Zero kills. Noob alert!",
    ["1"] = "One kill? Must be your first time here...",
    ["2"] = "Two kills... not bad. But still bad!",
    ["3"] = "Three kills? Relax, bro. You mad?",
    ["4"] = "Four kills. Dun dun dun...",
    ["5"] = "Five kills! Achieving the impossible!"
}

-- Fallback for players with more than five kills.
local END_MESSAGE_FALLBACK = "Only %d kills? That's it?"

-- CONFIG END ------------------------------------------------------------------------

local math_random = math.random
local string_format = string.format
local string_find = string.find

-- Picks a random death taunt.
local function pickRandom()
    return DEATH_MESSAGES[math_random(#DEATH_MESSAGES)]
end

--- Sends a taunt to a player, substituting %s with their name if present.
local function tauntPlayer(player_id, message)
    if not player_present(player_id) then return end

    if string_find(message, "%s", 1, true) then
        message = string_format(message, get_var(player_id, "$name"))
    end

    rprint(player_id, message)
end

function OnDie(victim_id)
    ---@diagnostic disable-next-line: unnecessary-if
    if not TAUNT_ON_DEATH then return end
    if not victim_id or victim_id < 1 or victim_id > 16 then return end

    tauntPlayer(victim_id, pickRandom())
end

function OnEnd()
    ---@diagnostic disable-next-line: unnecessary-if
    if not TAUNT_ON_END then return end

    for i = 1, 16 do
        if player_present(i) then
            local kills = get_var(i, "$kills")
            local message = END_MESSAGES[kills] or string_format(END_MESSAGE_FALLBACK, kills)

            tauntPlayer(i, message)
        end
    end
end

function OnScriptLoad()
    math.randomseed(os.time())

    register_callback(cb.EVENT_DIE, "OnDie")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
end

function OnScriptUnload() end
