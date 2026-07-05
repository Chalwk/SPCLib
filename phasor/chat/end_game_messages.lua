--[[
=====================================================================================
SCRIPT NAME:      end_game_messages.lua
DESCRIPTION:      Sends messages to players when the game ends.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config start ------------------------------------------------
local DEFAULT_MSG = "Well, you've got more than 4 kills... #AchievingTheImpossible"
local MESSAGES = {
    [0] = "You have no kills... noob alert!",
    [1] = "One kill? You must be new at this...",
    [2] = "Eh, two kills... not bad. But you still suck.",
    [3] = "Relax sonny! 3 kills, and you be like... mad bro?",
    [4] = "Dun dun dun... them 4 kills though!"
}
-- Config end --------------------------------------------------

function OnGameEnd(stage)
    if stage ~= 2 then return end

    for i = 0, 15 do
        local player = getplayer(i)
        if player then
            local kills = readword(player + 0x9C)
            local msg = MESSAGES[kills] or DEFAULT_MSG
            privatesay(i, msg)
        end
    end
end

function GetRequiredVersion()
    return 200
end

function OnScriptLoad() end

function OnScriptUnload() end
