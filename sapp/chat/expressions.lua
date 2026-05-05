--[[
=====================================================================================
SCRIPT NAME:      expressions.lua
DESCRIPTION:      Chat command system that responds to triggers with random phrases.
                  Available commands:
                  - !cuss   (family-friendly exclamations)
                  - !anger  (rage expressions)
                  - !taunt  (competitive taunts)

                  Output format includes player name and supports global/team/vehicle chat.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFGIGURATION --

local Expressions = {

    --- Chat triggers and their phrase lists.
    --- Add more triggers by replicating the structure below.
    phrases = {

        ["!cuss"] = {
            "Shnookerdookies!",
            "Fudge nuggets!",
            "Cheese and rice!",
            "Sugar!",
            "Poo!",
            "Snickerdoodle!",
            "Banana shenanigans!",
            "Six and two is eight!",
            "God bless it!",
            "Barbara Streisand!",
            "Fiddlesticks!",
            "Jiminy Crickets!",
            "Son of a gun!",
            "Egad!",
            "Great Scott!",
            "Caesar's ghost!",
            "Merlin's beard!",
            "Merlin's pants!",
            "Shucks!",
            "Darn!",
            "Dagnabbit!",
            "Dang rabbit!",
            "Dadgummit!",
            "Jumpin' Jiminy!"
        },

        ["!anger"] = {
            "FOR GOODNESS SAKES",
            "OUH C'MON!",
            "ARE YOU SERIOUS!?",
            "WHAT A LOAD OF BOLLOCKS",
            "OH HELL NAH!",
            "GRRRRRRR!!",
            "*FLARES NOSTRILS*",
            "*SCREAMS AT TOP OF LUNGS*",
            "BOLLOCKS"
        },

        ["!taunt"] = {
            "Ees too bad you got manure for brains!!",
            "Hell's full a' retired Gamers, And it's time you join em!",
            "Hell! My horse pisses straighter than you shoot!!",
            "Can't you do better than that! I've seen worms move faster!",
            "Not good enough!",
            "Hell - I can already smell your rotting corpse.",
            "Today is a good day to die, Mr!",
            "I'm going to send ya to an early grave",
            "Had enough yet?!",
            "Damn you and the horse you rode in on!",
            "Time to fit you for a coffin!",
            "Your life ends in the wasteland...",
            "Sell your PC. Just do it.",
            "Don't be shy! You can shoot at me next time, I don't mind!",
            "You must be new at this!",
            "Is that really a gun in your hand or is it just wishful thinkin'!"
        }
    },

    --- Message output formats by chat type:
    --- 0 = Global, 1 = Team, 2 = Vehicle
    outputFormats = {
        [0] = "$name: $msg",
        [1] = "[$name]: $msg",
        [2] = "[$name]: $msg"
    },

    serverPrefix = "**SAPP**"
}

-- CONFIG ENDS

api_version = "1.12.0.0"

local function formatMessage(chatType, playerName, message)
    return Expressions.outputFormats[chatType]
        :gsub("$name", playerName)
        :gsub("$msg", message)
end

local function getRandomPhrase(phrases)
    return phrases[rand(1, #phrases + 1)]
end

local function broadcast(message)
    execute_command('msg_prefix ""')
    say_all(message)
    execute_command('msg_prefix "' .. Expressions.serverPrefix .. '"')
end

function OnChat(playerId, message, chatType)
    local command = message:lower()
    local phrases = Expressions.phrases[command]

    if phrases then
        local randomPhrase = getRandomPhrase(phrases)
        local playerName   = get_var(playerId, "$name")
        local output       = formatMessage(chatType, playerName, randomPhrase)

        broadcast(output)
        return false -- suppress original message
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnChat")
end

function OnScriptUnload() end
