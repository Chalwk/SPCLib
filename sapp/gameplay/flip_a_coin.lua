--[[
=====================================================================================
SCRIPT NAME:      flip_a_coin.lua
DESCRIPTION:      Simulates coin flips with statistical results
                  - Usage: !flip (default: 10,000 flips)
                  - Shows heads/tails count and percentages
                  - Includes execution time measurement
                  - Configurable permission level

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config starts here:
local COMMAND = 'flip'
local PERMISSION_LEVEL = -1
local OUTPUT = {
    "Flipping %d times...",
    "Heads: %d/%d - %.2f%%",
    "Tails: %d/%d - %.2f%%",
    "This took %.2f seconds"
}

local FLIPS = 10000
api_version = '1.12.0.0'

-- Config ends here.

local function hasPermission(player)
    local player_level = tonumber(get_var(player, '$lvl'))
    return player_level >= PERMISSION_LEVEL
end

local function send(player, str, ...)
    return (player == 0 and cprint(str:format(...), 10) or rprint(player, str:format(...)))
end

local function flipCoins(flips, player)
    local start_time = os.time()
    local head_count, tail_count = 0, 0
    local results = {}

    math.randomseed(os.time())

    for _ = 1, flips do
        local result = (math.random(2) == 1) and 'Heads' or 'Tails'
        results[#results + 1] = result
        if result == 'Heads' then
            head_count = head_count + 1
        else
            tail_count = tail_count + 1
        end
    end
    local end_time = os.time()

    local total_percent = (head_count / flips * 100)

    send(player, OUTPUT[1], flips)
    send(player, OUTPUT[2], head_count, flips, total_percent)
    send(player, OUTPUT[3], tail_count, flips, 100 - total_percent)
    send(player, OUTPUT[4], end_time - start_time)

    return results
end

function OnScriptLoad()
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
end

function OnCommand(player, cmd)
    if cmd:lower():sub(1, COMMAND:len()) == COMMAND then
        if hasPermission(player) then
            flipCoins(FLIPS, player)
            return true
        else
            send(player, 'Insufficient Permission')
            return false
        end
    end
end

function OnScriptUnload()
    -- N/A
end
