--[[
=====================================================================================
SCRIPT NAME:      taunt_your_players.lua
DESCRIPTION:      Sends humorous taunts to players during gameplay, with fully
                  customizable messages and event triggers.

CONFIGURATION:
                  TAUNT_ON_DEATH  - Enable/disable death taunts
                  TAUNT_ON_END    - Enable/disable end-game taunts

FEATURES:
                  - 30+ unique death taunt messages
                  - End-game taunts based on kill count
                  - Customizable event triggers
                  - Randomized message selection
                  - Kill-count specific end messages
                  - Lightweight and server-friendly

USAGE:
                  Place in your Lua scripts directory and load with SAPP.
                  Messages are triggered automatically according to configuration.

REQUIREMENTS:     SAPP (Lua API enabled)

AUTHOR:           Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ----------------------------------------------------------------------

local TAUNT_ON_DEATH = true
local TAUNT_ON_END   = true

local DEATH_MESSAGES = {
    "Aw, %s, I've seen better shooting at the county fair!",
    "Too bad you've got manure for brains!!",
    "Hell's full of retired gamers, %s. Time you joined them!",
    "My horse pisses straighter than you shoot!!",
    "Can't you do better than that? Worms move faster!",
    "Not good enough, %s. Not good enough!",
    "I can already smell your rotting corpse.",
    "Today is a good day to die, %s!",
    "Too slow! You'll regret that!!",
    "You insult me, %s!!",
    "I'm sending you to an early grave!!",
    "Had enough yet?!",
    "Hope you plant better than you shoot!!",
    "Damn you and the horse you rode in on!!",
    "Time to fit you for a coffin!!",
    "You have a date with the undertaker!!",
    "Your life ends in the wasteland...",
    "Rest in peace, %s.",
    "You fought valiantly... but in vain.",
    "You're dead. Again, %s!",
    "Dead as a doornail.",
    "Time to reload, %s.",
    "Here's a picture of your corpse. Not pretty.",
    "Wow. Dead and stupid.",
    "Ha ha ha ha ha. You're dead, moron!",
    "Couldn't charm your way out of that one, %s.",
    "Nope. Just nope.",
    "You have perished. What a shame.",
    "Sell your PC. Just do it.",
    "You disappoint me, %s."
}

local END_MESSAGES = {
    [0] = "Zero kills. Noob alert!",
    [1] = "One kill? Must be your first time here...",
    [2] = "Two kills... not bad. But still bad!",
    [3] = "Three kills? Relax, bro. You mad?",
    [4] = "Four kills. Dun dun dun...",
    [5] = "Five kills! Achieving the impossible!"
}

-- CONFIG END ------------------------------------------------------------------------

api_version = "1.12.0.0"

local function getMessage(tbl)
    return tbl[math.random(#tbl)]
end

local function formatMessage(msg, id)
    return string.format(msg, get_var(id, "$name"))
end

function OnDeath(victim)
    if not TAUNT_ON_DEATH then return end
    local id = tonumber(victim)
    if not id then return end
    rprint(id, formatMessage(getMessage(DEATH_MESSAGES), id))
end

function OnEnd()
    if not TAUNT_ON_END then return end
    for i = 1, 16 do
        if player_present(i) then
            local kills = tonumber(get_var(i, "$kills"))
            local msg = END_MESSAGES[kills]
            if msg then
                rprint(i, msg)
            end
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_DIE, "OnDeath")
end

function OnScriptUnload() end
