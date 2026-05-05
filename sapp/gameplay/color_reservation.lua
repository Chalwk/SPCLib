--[[
=====================================================================================
SCRIPT NAME:      color_reservation.lua
DESCRIPTION:      Reserves specific armor colors for VIP players based on their unique
                  hash identifiers, preventing unauthorized use of reserved colors.

FEATURES:
                  - Exclusive color assignment by player hash
                  - 18 reservable armor colors (0-17)
                  - Automatic color reassignment for non-VIP players
                  - FFA game mode support (team play disabled)
                  - Hash-based VIP system

CONFIGURATION:
                  - Edit color_table to assign colors to player hashes
                  - Format: color_table[index] = {colorID, "hash1", "hash2", ...}
                  - Supports multiple hashes per color
                  - Color IDs must remain unchanged (0-17)

COLOR REFERENCE:
                  0:white   1:black   2:red      3:blue     4:gray
                  5:yellow  6:green   7:pink     8:purple   9:cyan
                  10:cobalt 11:orange 12:teal    13:sage    14:brown
                  15:tan    16:maroon 17:salmon

USAGE:
                  1. Add player hashes to desired color entries
                  2. Non-VIP players automatically assigned random colors (excluding teal)
                  3. VIPs always get their reserved colors when spawning

NOTE:             Only works in Free-For-All (FFA) game modes

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.11.0.0"
color_table = {}
bool = {}

-- Configuration [starts] [!] DO NOT TOUCH THE "Color ID"
--             Color ID     Hash
color_table[1] = { 0, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }  -- white (both of these hashes will trigger white)
color_table[2] = { 1, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- black
color_table[3] = { 2, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- red
color_table[4] = { 3, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- blue
color_table[5] = { 4, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- gray
color_table[6] = { 5, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- yellow
color_table[7] = { 6, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- green
color_table[8] = { 7, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- pink
color_table[9] = { 8, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- purple
color_table[10] = { 9, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- cyan
color_table[11] = { 10, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- cobalt
color_table[12] = { 11, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- orange
color_table[13] = { 12, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- teal
color_table[14] = { 13, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- sage
color_table[15] = { 14, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- brown
color_table[16] = { 15, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- tan
color_table[17] = { 16, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- maroon
color_table[18] = { 17, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }    -- salmon
-- Note: Make sure you encapsulate hashes in quotes and separate entries with a comma!
-- Like so: color_table[1] = {0, "player hash 1", "player hash 2"}
-- Configuration [ends] -----------------------------------------------------------------

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], "OnNewGame")
end

function OnScriptUnload()

end

function OnNewGame()
    if (get_var(1, "$gt") == "slayer") then
        -- Call getTeamPlay() | Returns true/false (is team play / not team play)
        if not getTeamPlay() then
            -- Game is FFA, register SAPP events to listener functions.
            register_callback(cb['EVENT_JOIN'], "OnPlayerConnect")
            register_callback(cb['EVENT_SPAWN'], "OnPlayerSpawn")
        else
            cprint("[!] Warning: Color Reservation doesn't support Team Play!", 4 + 8)
        end
    else
        cprint("[!] Warning: Color Reservation doesn't support " .. get_var(0, "$gt") .. "!", 4 + 8)
    end
end

function OnPlayerConnect(PlayerIndex)
    local hash = getHash(PlayerIndex)
    local player = getPlayer(PlayerIndex)
    for k, v in ipairs(color_table) do
        for i = 1, #v do
            if not string.find(v[i], tostring(hash)) then
                -- Check if their color is TEAL | if TRUE then set new color (Shoo's color reservation)
                if (read_byte(player + 0x60) == 12) then
                    bool[PlayerIndex] = true
                    setColor(PlayerIndex, nil, true, hash)
                end
            else
                -- player's hash IS LISTED in the color table | execute: setColor()
                setColor(PlayerIndex, nil, false, hash)
            end
        end
    end
end

function OnPlayerSpawn(PlayerIndex)
    if (bool[PlayerIndex] == true) then
        bool[PlayerIndex] = false
        local player_object = read_dword(get_player(PlayerIndex) + 0x34)
        destroy_object(player_object)
    end
end

-- Set this player's color to something random (EXCLUDING TEAL)
function setColor(PlayerIndex, ColorID, param, hash)
    local player = getPlayer(PlayerIndex)
    if (param == true) then
        write_byte(player + 0x60, tonumber(selectRandomColor(12)))
    else

        -- Iterates over the entire array 
        -- and determines the appropriate color.

        local color
        for k, v in pairs(color_table) do
            for i = 1, #v do
                -- v[1] is determined by the table index that this player's hash was located on.
                if string.find(v[i], tostring(hash)) then
                    write_byte(player + 0x60, tonumber(v[1]))
                    bool[PlayerIndex] = true
                end
            end
        end
    end
end

-- math.random() generates pseudo-random numbers uniformly distributed.
-- The math.randomseed() function sets a seed for the pseudo-random generator.
function selectRandomColor(exclude)
    math.randomseed(os.time())
    math.random();
    math.random();
    math.random()
    local num = math.random(0, 17)
    -- If the 'num' chosen is equal to the value of "exclude", repeat.
    if num == tonumber(exclude) then
        selectRandomColor(exclude)
    else
        return num
    end
end

-- Returns the static memory address of the player table entry.
function getPlayer(PlayerIndex)
    if tonumber(PlayerIndex) then
        if tonumber(PlayerIndex) ~= 0 then
            local player = get_player(PlayerIndex)
            if player ~= 0 then
                return player
            end
        end
    end
    return nil
end

-- Returns player hash
function getHash(PlayerIndex)
    if PlayerIndex ~= nil and PlayerIndex ~= "-1" then
        local hash = get_var(PlayerIndex, "$hash")
        return hash
    end
    return nil
end

-- Determines team play
function getTeamPlay()
    -- Game mode is team based.
    if (get_var(0, "$ffa") == "0") then
        return true
    else
        -- Game mode is NOT team based.
        return false
    end
end

function OnError(Message)
    print(debug.traceback())
end
