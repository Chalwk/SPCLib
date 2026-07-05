--[[
=====================================================================================
SCRIPT NAME:      set_flag_limit.lua
DESCRIPTION:      Forces a custom score (flag capture) limit for CTF games.
                  Works on both PC and CE, and reapplies on every new game.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config:
-- Score needed to win
local FLAG_LIMIT = 21
--

local gametype_base

function GetRequiredVersion()
    return 200
end

local function apply_limit()
    if gametype_base then
        writebyte(gametype_base, 0x58, FLAG_LIMIT)
    end
end

function OnScriptLoad(_, game)
    gametype_base = (game == "PC") and 0x671340 or 0x5F5498
    apply_limit()
end

function OnNewGame()
    apply_limit()
end

function OnScriptUnload() end
