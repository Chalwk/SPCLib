--[[
=====================================================================================
SCRIPT NAME:      phasor_util.lua
DESCRIPTION:      A collection of common utility functions for Phasor Lua scripting.
                  Functions cover player state checks, coordinate manipulation,
                  string handling, memory reading, wildcard matching, time conversion,
                  network utilities, object type detection, player health/shields,
                  bit manipulation, game timers, and more. Designed to be used via
                  require() to keep other scripts clean and DRY.

                  Example usage:
                      local util = require("phasor_util")

                      function OnScriptLoad(processid, game, persistent)
                          util.init_game(game)

                          if util.is_alive(1) then
                              local x, y, z = util.get_player_pos(1)
                          end
                      end

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/HALO-SCRIPT-PROJECTS/blob/master/LICENSE
=====================================================================================
]]

local util = {
    pointers = {
        ["PC"] = {
            oddball_globals = 0x639E18,
            slayer_globals = 0x63A0E8,
            name_base = 0x745D4A,
            specs_addr = 0x662D04,
            hashcheck_addr = 0x59c280,
            versioncheck_addr = 0x5152E7,
            map_pointer = 0x63525c,
            gametype_base = 0x671340,
            gametime_base = 0x671420,
            machine_pointer = 0x745BA0,
            timelimit_address = 0x626630,
            special_chars = 0x517D6B,
            gametype_patch = 0x481F3C,
            devmode_patch1 = 0x4A4DBF,
            devmode_patch2 = 0x4A4E7F,
            hash_duplicate_patch = 0x59C516,
            ctf_globals = 0x639B98,
            koth_globals = 0x639BD0,
            race_globals = 0x639FA0,
            race_locs = 0x670F40,
            stats_globals = 0x639898
        },
        ["CE"] = {
            oddball_globals = 0x5BDEB8,
            slayer_globals = 0x5BE108,
            name_base = 0x6C7B6A,
            specs_addr = 0x5E6E63,
            hashcheck_addr = 0x530130,
            versioncheck_addr = 0x4CB587,
            map_pointer = 0x5B927C,
            gametype_base = 0x5F5498,
            gametime_base = 0x5F55BC,
            machine_pointer = 0x6C7980,
            timelimit_address = 0x5AA5B0,
            special_chars = 0x4CE0CD,
            gametype_patch = 0x45E50C,
            devmode_patch1 = 0x47DF0C,
            devmode_patch2 = 0x47DFBC,
            hash_duplicate_patch = 0x5302E6,
            ctf_globals = 0x5BDBB8,
            koth_globals = 0x5BDBF0,
            race_globals = 0x5BDFC0,
            race_locs = 0x5F5098,
            stats_globals = 0x5BD8B8
        }
    },
    player_colours = {
        white = 0,
        black = 1,
        red = 2,
        blue = 3,
        grey = 4,
        yellow = 5,
        green = 6,
        pink = 7,
        purple = 8,
        cyan = 9,
        cobalt = 10,
        orange = 11,
        teal = 12,
        sage = 13,
        brown = 14,
        tan = 15,
        maroon = 16,
        salmon = 17
    }
}

-- Local aliases for frequently used library and Phasor API functions
local floor = math.floor
local random = math.random
local sub = string.sub
local gsub = string.gsub
local gmatch = string.gmatch
local char = string.char
local format = string.format
local tonumber = tonumber
local tostring = tostring
local concat = table.concat
local insert = table.insert
local unpack = table.unpack
local math_min = math.min
local math_max = math.max
local math_huge = math.huge

-- Phasor API locals
local getplayerobjectid = getplayerobjectid
local getobject = getobject
local readfloat = readfloat
local readword = readword
local readdword = readdword
local readbyte = readbyte
local readshort = readshort
local readint = readint
local readchar = readchar
local getplayer = getplayer
local getname = getname
local getteam = getteam
local getobjectcoords = getobjectcoords
local writefloat = writefloat
local writeword = writeword
local writeshort = writeshort
local writebyte = writebyte
local writedword = writedword
local writeint = writeint
local writechar = writechar

-- Game-specific memory addresses
local map_pointer
local gametype_base
local gametime_base
local slayer_globals
local oddball_globals
local koth_globals
local race_globals
local ctf_globals

--- Initialises game-dependent memory addresses for PC and CE.
-- @param game (string) "PC" or "CE" (as provided by Phasor).
function util.init_game(game)
    map_pointer = util.pointers[game].map_pointer
    gametype_base = util.pointers[game].gametype_base
    gametime_base = util.pointers[game].gametime_base
    slayer_globals = util.pointers[game].slayer_globals
    oddball_globals = util.pointers[game].oddball_globals
    koth_globals = util.pointers[game].koth_globals
    race_globals = util.pointers[game].race_globals
    ctf_globals = util.pointers[game].ctf_globals
end

----------------------------------------------------------------------
-- PLAYER STATE / INFO
----------------------------------------------------------------------

-- Returns the player's biped object and its ID, or nil if dead/invalid
local function get_player_biped(id)
    local obj_id = getplayerobjectid(id)
    if not obj_id or obj_id == 0 then return nil end
    return getobject(obj_id), obj_id
end

--- Returns true if the player is alive (has a valid biped object).
-- @param id (number)
-- @return boolean
function util.is_alive(id)
    if id == nil then return false end
    return getplayerobjectid(id) ~= nil
end

--- Returns the player's position (x, y, z), compensating for crouch.
-- @param id (number)
-- @return number x, number y, number z, or nil if player invalid
function util.get_player_pos(id)
    local obj, obj_id = get_player_biped(id)
    if not obj then return nil end

    local x = readfloat(obj, 0x5C)
    local y = readfloat(obj, 0x60)
    local z = readfloat(obj, 0x64)
    local crouch = readfloat(obj + 0x50C)

    -- 0.65 is the standing eye height, 0.35 is crouching adjustment
    local z_offset = (crouch == 0) and 0.65 or 0.35 * crouch
    return x, y, z + z_offset
end

--- Returns the player's base biped coordinates without crouch offset.
-- @param id (number)
-- @return number x, number y, number z, or nil
function util.get_player_base_pos(id)
    local player_obj = getplayer(id)
    if not player_obj then return nil end
    local px = readfloat(player_obj + 0xF8)
    local py = readfloat(player_obj + 0xFC)
    local pz = readfloat(player_obj + 0x100)
    return px, py, pz
end

--- Checks whether a player is currently camouflaged (invisible).
-- @param id (number)
-- @return boolean (true if invisible) or false (not invisible)
function util.is_player_camouflaged(id)
    local obj = get_player_biped(id)
    if not obj then return nil end
    return readfloat(obj + 0x37C) == 1.0
end

--- Returns a table with the player's kill, death, assist and streak counts.
-- @param id (number)
-- @return table|nil { kills = number, deaths = number, assists = number, streaks = number }
function util.get_player_stats(id)
    local p = getplayer(id)
    if not p then return nil end

    return {
        kills = readword(p + 0x9C),
        deaths = readword(p + 0xAE),
        assists = readword(p + 0xA4),
        streaks = readword(p + 0x98)
    }
end

--- Returns the object ID of the vehicle the player is currently riding in, or nil.
-- @param id (number)
-- @return number vehicle_object_id or nil
function util.get_player_vehicle(id)
    local obj, obj_id = get_player_biped(id)
    if not obj then return nil end

    local vehicle_id = readdword(obj + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    return vehicle_id
end

--- Returns true if the player is currently in any vehicle.
-- @param id (number)
-- @return boolean
function util.is_in_vehicle(id)
    return util.get_player_vehicle(id) ~= nil
end

--- Returns the player's current health (0.0 to 1.0).
-- @param id (number)
-- @return number|nil health, or nil if player dead/invalid
function util.get_player_health(id)
    local obj = get_player_biped(id)
    if not obj then return nil end
    return readfloat(obj + 0xE0)
end

--- Returns the player's current shields (0.0 to ~3.0 with overshield).
-- @param id (number)
-- @return number|nil shields, or nil if player dead/invalid
function util.get_player_shields(id)
    local obj = get_player_biped(id)
    if not obj then return nil end
    return readfloat(obj + 0xE4)
end

--- Sets the player's health (0.0 to 1.0). Does nothing if player is dead.
-- @param id (number)
-- @param value (number) desired health level
function util.set_player_health(id, value)
    local obj = get_player_biped(id)
    if obj then
        writefloat(obj + 0xE0, value)
    end
end

--- Sets the player's shields (0.0 to 3.0). Does nothing if player is dead.
-- @param id (number)
-- @param value (number) desired shield level
function util.set_player_shields(id, value)
    local obj = get_player_biped(id)
    if obj then
        writefloat(obj + 0xE4, value)
    end
end

--- Returns the player's ping in milliseconds.
-- @param id (number)
-- @return number|nil ping, or nil if player invalid
function util.get_player_ping(id)
    local p = getplayer(id)
    if not p then return nil end
    return readword(p + 0xDC)
end

--- Returns the object ID of the weapon in the given slot, or the current weapon if slot nil.
-- Slots: 1 = primary, 2 = secondary, 3 = tertiary, 4 = quaternary.
-- @param id (number) player index
-- @param slot (number|nil) weapon slot 1-4, or nil for current weapon
-- @return number weapon_object_id or 0xFFFFFFFF if none/invalid
function util.get_player_weapon(id, slot)
    local obj, obj_id = get_player_biped(id)
    if not obj then return 0xFFFFFFFF end

    -- If the player is in a vehicle, return the vehicle's weapon.
    local vehicle_id = util.get_player_vehicle(id)
    if vehicle_id then
        local veh_obj = getobject(vehicle_id)
        if veh_obj then
            return readdword(veh_obj + 0x2F8)
        end
    end

    if not slot then
        return readdword(obj + 0x118) -- current weapon
    end

    -- Slot index 1..4 maps to offset 0x2F8+ (slot-1)*4
    if slot >= 1 and slot <= 4 then
        return readdword(obj + 0x2F8 + (slot - 1) * 4)
    end

    return 0xFFFFFFFF
end

--- Resolves player expressions (names, wildcards, "me", "red", "blue", "random", "*",
--  colour names, "nearest", "farthest").
-- @param expression (string) player identifier
-- @param self_id (number|nil) player ID of the caller (used for "me", "random" exclusion,
-- and as reference for "nearest"/"farthest")
-- @return table|nil a list of player indices (0-15), or nil if no match
function util.get_players_by_expression(expression, self_id)
    if not expression then return nil end

    -- All players
    if expression == "*" then
        local t = {}
        for i = 0, 15 do
            if getplayer(i) then t[#t + 1] = i end
        end
        return #t > 0 and t or nil

        -- Self
    elseif expression == "me" then
        if self_id and getplayer(self_id) then return { self_id } end
        return nil

        -- Red team
    elseif expression == "red" then
        local t = {}
        for i = 0, 15 do
            if getplayer(i) and getteam(i) == 0 then t[#t + 1] = i end
        end
        return #t > 0 and t or nil

        -- Blue team
    elseif expression == "blue" then
        local t = {}
        for i = 0, 15 do
            if getplayer(i) and getteam(i) == 1 then t[#t + 1] = i end
        end
        return #t > 0 and t or nil

        -- Random player
    elseif expression == "random" or expression == "rand" then
        local t = {}
        for i = 0, 15 do
            if getplayer(i) and i ~= self_id then t[#t + 1] = i end
        end
        if #t > 0 then return { t[random(#t)] } end
        return nil

        -- Nearest player to self
    elseif expression == "nearest" or expression == "closest" then
        if not self_id or not util.get_player_pos(self_id) then return nil end
        local sx, sy, sz = util.get_player_pos(self_id)
        local min_dist, closest = math_huge, nil
        for i = 0, 15 do
            if i ~= self_id and getplayer(i) then
                local x, y, z = util.get_player_pos(i)
                if x then
                    local d = (x - sx) ^ 2 + (y - sy) ^ 2 + (z - sz) ^ 2
                    if d < min_dist then
                        min_dist = d
                        closest = i
                    end
                end
            end
        end
        return closest and { closest } or nil

        -- Farthest player from self
    elseif expression == "farthest" then
        if not self_id or not util.get_player_pos(self_id) then return nil end
        local sx, sy, sz = util.get_player_pos(self_id)
        local max_dist, farthest = -1, nil
        for i = 0, 15 do
            if i ~= self_id and getplayer(i) then
                local x, y, z = util.get_player_pos(i)
                if x then
                    local d = (x - sx) ^ 2 + (y - sy) ^ 2 + (z - sz) ^ 2
                    if d > max_dist then
                        max_dist, farthest = d, i
                    end
                end
            end
        end
        return farthest and { farthest } or nil
    else
        -- Numeric ID (1-16)
        local num = tonumber(expression)
        if num and num >= 1 and num <= 16 then
            local id = num - 1
            if getplayer(id) then return { id } end
            return nil
        end

        -- Player colour name (e.g. "white", "yellow", "green", "orange", "purple", etc.)
        local colour_index = util.player_colours[expression]
        if colour_index then
            local t = {}
            for i = 0, 15 do
                local p = getplayer(i)
                if p and readword(p + 0x60) == colour_index then
                    t[#t + 1] = i
                end
            end
            return #t > 0 and t or nil
        end

        -- Wildcard name matching (case-insensitive)
        local t = {}
        for i = 0, 15 do
            if getplayer(i) then
                local name = getname(i)
                if util.wildcard_match(name, expression) then
                    t[#t + 1] = i
                end
            end
        end
        return #t > 0 and t or nil
    end
end

--- Returns the player's current colour index (0-17) as seen by others.
-- @param id (number)
-- @return number|nil colour index, or nil if player invalid
function util.get_player_color(id)
    local p = getplayer(id)
    if p then return readword(p + 0x60) end
    return nil
end

--- Returns the player's memory struct and object ID together.
-- @param id (number) player index
-- @return table object_struct, number object_id, or nil if invalid/dead
function util.get_player_object(id)
    return get_player_biped(id)
end

--- Returns the vehicle struct and object ID of the vehicle the player is in.
-- @param id (number) player index
-- @return table vehicle_struct, number vehicle_id, or nil if not in vehicle
function util.get_player_vehicle_object(id)
    local obj, obj_id = util.get_player_object(id)
    if not obj then return nil end
    local veh_id = readdword(obj + 0x11C)
    if veh_id == 0xFFFFFFFF then return nil end
    local veh_obj = getobject(veh_id)
    if not veh_obj then return nil end
    return veh_obj, veh_id
end

--- Returns the weapon struct and object ID for the player's weapon.
-- Slots: 1 = primary, 2 = secondary, 3 = tertiary, 4 = quaternary.
-- If no slot given, returns the current weapon (including vehicle weapon).
-- @param id (number) player index
-- @param slot (number|nil) weapon slot (1-4), or nil for current weapon
-- @return table weapon_struct, number weapon_id, or nil if no weapon
function util.get_player_weapon_object(id, slot)
    local weapon_id = util.get_player_weapon(id, slot)
    if weapon_id == 0xFFFFFFFF then return nil end
    local weapon_obj = getobject(weapon_id)
    if not weapon_obj then return nil end
    return weapon_obj, weapon_id
end

--- Returns the current speed of the player.
-- @param id (number) player index
-- @return number speed, or nil if player invalid
function util.get_player_speed(id)
    local p = getplayer(id)
    if not p then return nil end
    return readfloat(p + 0x6C)
end

--- Sets the player's movement speed.
-- @param id (number) player index
-- @param speed (number) desired speed (clamped to avoid extreme values)
function util.set_player_speed(id, speed)
    local p = getplayer(id)
    if not p then return end
    speed = tonumber(speed) or 1
    -- safety clamp; the game can handle very large values but we cap to avoid crashes
    if speed > 999999 then speed = 999999 end
    writefloat(p + 0x6C, speed)
end

--- Object coordinate retrieval. If the object is attached to a parent
-- (e.g. a player in a vehicle), returns the parent's coordinates instead.
-- @param object_id (number) the object ID
-- @return number x, number y, number z, or nil if object invalid
function util.get_object_coords(object_id)
    local obj = getobject(object_id)
    if not obj then return nil end

    -- Check for a parent vehicle (offset 0x11C)
    local parent_id = readdword(obj + 0x11C)
    if parent_id ~= 0xFFFFFFFF then
        local parent_obj = getobject(parent_id)
        if parent_obj then obj = parent_obj end
    end

    return readfloat(obj + 0x5C), readfloat(obj + 0x60), readfloat(obj + 0x64)
end

--- Sets the player's colour. This change is immediate for players who join after, but
-- for the player themselves a respawn is usually required to fully apply the colour.
-- @param id (number) player index
-- @param colour (number) colour index (0-17) or name from the player_colours table
function util.set_player_color(id, colour)
    local p = getplayer(id)
    if not p then return end

    if type(colour) == "string" then
        colour = util.player_colours[colour:lower()]
    end
    if not colour or type(colour) ~= "number" then return end

    writebyte(p + 0x60, colour)
end

----------------------------------------------------------------------
-- STRING / COMMAND UTILITIES
----------------------------------------------------------------------

--- Simple string formatter with $var substitution.
-- Replaces placeholders like $name, $id, $msg with values from the args table.
-- @param template (string) the format string
-- @param args (table) key-value pairs for substitution
-- @return string formatted output
function util.format(template, args)
    if not args then return template end
    return (template:gsub("%$([%w_]+)", function(key)
        local value = args[key] or args[key:lower()] or args[key:upper()]
        return value ~= nil and tostring(value) or "$" .. key
    end))
end

--- Checks if a string begins with '/' or '\' (typical command prefix).
-- @param str (string)
-- @return boolean
function util.is_command(str)
    if not str then return false end
    local first = sub(str, 1, 1)
    return first == "/" or first == "\\"
end

--- Strips leading slash(es) or backslash(es) from a string.
-- @param msg (string) raw input
-- @return string cleaned string
function util.strip_prefix(msg)
    if not msg then return "" end
    return gsub(msg, "^[\\/]+", "")
end

--- Splits a message into lowercase words, ignoring whitespace.
-- @param msg (string)
-- @return table array of lowercased words
function util.split_message(msg)
    local words = {}
    if not msg then return words end
    for w in gmatch(msg, "[^%s]+") do
        words[#words + 1] = w:lower()
    end
    return words
end

--- Parses a chat command into a lowercase argument array.
-- @param s (string) raw chat input
-- @return table args
function util.parse_cmd(s)
    s = util.strip_prefix(s)
    local args = {}
    for w in gmatch(s, "([^%s]+)") do
        args[#args + 1] = w:lower()
    end
    return args
end

--- Splits a string by any of the given delimiter strings.
-- @param str (string) the string to split
-- @param ... delimiter strings
-- @return table array of substrings
function util.split_string(str, ...)
    local delims = { ... }
    if #delims == 0 then return { str } end

    -- Split into individual characters if any delimiter is empty
    for _, d in ipairs(delims) do
        if d == "" then
            local chars = {}
            for i = 1, #str do
                chars[#chars + 1] = sub(str, i, i)
            end
            return chars
        end
    end

    -- Sort delimiters by length descending so the longest match wins
    table.sort(delims, function(a, b) return #a > #b end)

    -- Escape magic characters in each delimiter for Lua pattern
    local escaped = {}
    for _, d in ipairs(delims) do
        escaped[#escaped + 1] = gsub(d, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    end
    local sep_pattern = concat(escaped, "|")

    -- Split using the complement of the delimiter pattern
    local tokens = {}
    for token in gmatch(str, "([^" .. sep_pattern .. "]+)") do
        tokens[#tokens + 1] = token
    end

    -- Strip all delimiter characters from each token (legacy behaviour)
    for i = 1, #tokens do
        local token = tokens[i]
        for _, d in ipairs(delims) do
            token = gsub(token, gsub(d, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"), "")
        end
        tokens[i] = token
    end

    return tokens
end

--- Tokenizes a string like command line arguments, respecting double quotes.
-- e.g., tokenize_cmd_string('say "hello world" foo') -> {"say", "hello world", "foo"}
-- @param str (string)
-- @return table array of tokens
function util.tokenize_cmd_string(str)
    local tokens = {}
    str = str:gsub("^%s*(.-)%s*$", "%1") .. " " -- trim and add sentinel
    local pos = 1
    while pos <= #str do
        local token, newPos
        -- try double-quoted string
        token, newPos = str:match('^"([^"]*)"%s+()', pos)
        if not token then
            token, newPos = str:match('^([^%s]+)%s+()', pos)
        end
        if not token then break end
        tokens[#tokens + 1] = token
        pos = newPos
    end
    return tokens
end

--- Returns all indices where a character appears in a string.
-- @param str (string)
-- @param char (string) single character to search
-- @return number ... index list
function util.find_char(str, character)
    local indices = {}
    for i = 1, #str do
        if sub(str, i, i) == character then
            indices[#indices + 1] = i
        end
    end
    return unpack(indices)
end

--- Performs case-insensitive wildcard matching with '*' and '?'.
-- @param str (string) the string to test
-- @param pattern (string) wildcard pattern (e.g., "Hel*o?")
-- @param case_sensitive (boolean) optional, default false
-- @return boolean match result
function util.wildcard_match(str, pattern, case_sensitive)
    if not case_sensitive then
        str = str:lower()
        pattern = pattern:lower()
    end

    -- Quick shortcut: handle leading/trailing '?' by substituting them with
    -- the actual character from str (non-standard but kept for compatibility)
    if sub(pattern, 1, 1) == "?" then
        pattern = gsub(pattern, "?", sub(str, 1, 1), 1)
    end
    if sub(pattern, -1) == "?" then
        pattern = gsub(pattern, "?", sub(str, -1), 1)
    end

    -- No wildcards -> simple equality check
    if not pattern:find("*") and not pattern:find("?") then
        return str == pattern
    end

    -- Quick mismatch checks
    if sub(pattern, 1, 1) ~= sub(str, 1, 1) and sub(pattern, 1, 1) ~= "*" then
        return false
    end
    if sub(pattern, -1) ~= sub(str, -1) and sub(pattern, -1) ~= "*" then
        return false
    end

    -- Split pattern into subpatterns by '*'
    local subpatterns = {}
    local plen = #pattern
    local cur = ""
    for i = 1, plen do
        local c = sub(pattern, i, i)
        if c == "*" then
            if cur ~= "" then
                subpatterns[#subpatterns + 1] = cur
                cur = ""
            end
        else
            cur = cur .. c
        end
    end
    if cur ~= "" then
        subpatterns[#subpatterns + 1] = cur
    end

    -- Greedy match for each subpattern
    local start = 1
    local slen = #str
    for _, subp in ipairs(subpatterns) do
        local sublen = #subp
        local found = false
        local ts = start
        local te = start + sublen - 1
        while te <= slen do
            -- Check if subp matches the current slice (with '?' wildcard)
            local match = true
            for j = 1, sublen do
                local pc = sub(subp, j, j)
                if pc ~= "?" and pc ~= sub(str, ts + j - 1, ts + j - 1) then
                    match = false
                    break
                end
            end
            if match then
                found = true
                start = ts + sublen -- advance past the matched part
                break
            end
            ts = ts + 1
            te = te + 1
        end
        if not found then return false end
    end
    return true
end

--- Splits a string by a delimiter (default comma), returning an array of substrings.
-- @param input (string) the string to split
-- @param delimiter (string) optional delimiter pattern, defaults to ","
-- @return table token list
function util.tokenize_string(input, delimiter)
    local args = {}
    for substring in gmatch(input, "([^" .. delimiter .. "]+)") do
        args[#args + 1] = substring
    end
    return args
end

--- Converts a time-duration string (e.g., "5m30s", "2h", "1d12h") to seconds.
-- Supports 's' (seconds), 'm' (minutes), 'h' (hours), 'd' (days).
-- @param time_string (string) human-readable duration
-- @return number total seconds, or -1 if invalid
function util.word_to_time(time_string)
    if not time_string then return -1 end
    local s, num = 0, ""
    for i = 1, #time_string do
        local c = sub(time_string, i, i)
        if tonumber(c) then
            num = num .. c
        else
            local amount = tonumber(num) or 0
            if c == "s" then
                s = s + amount
            elseif c == "m" then
                s = s + amount * 60
            elseif c == "h" then
                s = s + amount * 3600
            elseif c == "d" then
                s = s + amount * 86400
            end
            num = ""
        end
    end
    return s > 0 and s or -1
end

--- Converts a number of seconds to a human-readable string like "5m 30s".
-- @param s (number) total seconds
-- @return string formatted time or "-1" if invalid
function util.time_to_word(s)
    if s == -1 or not tonumber(s) then return "-1" end
    s = tonumber(s)
    local days = floor(s / 86400)
    s = s % 86400
    local hours = floor(s / 3600)
    s = s % 3600
    local mins = floor(s / 60)

    local secs = s % 60
    local parts = {}

    if days > 0 then parts[#parts + 1] = days .. "d" end
    if hours > 0 then parts[#parts + 1] = hours .. "h" end
    if mins > 0 then parts[#parts + 1] = mins .. "m" end
    if secs > 0 or #parts == 0 then parts[#parts + 1] = secs .. "s" end

    return concat(parts, " ")
end

--- Formats a duration given in seconds as a "HH:MM:SS" string.
-- @param seconds (number) total seconds
-- @return string formatted time (e.g., "01:30:45")
function util.format_duration(seconds)
    seconds = tonumber(seconds) or 0
    local h = floor(seconds / 3600)
    local m = floor((seconds % 3600) / 60)
    local s = floor(seconds % 60)
    return format("%02d:%02d:%02d", h, m, s)
end

----------------------------------------------------------------------
-- IP / NETWORK UTILITIES
----------------------------------------------------------------------

--- Validates an IPv4 address (supports wildcards, CIDR, and ranges).
-- Normalizes 1.2.*.* to 1.2.0.0/16, etc. Returns formatted string or false.
-- @param ip (string) IP string
-- @return string|boolean normalized IP, or false if invalid
function util.validate_ipv4(ip)
    if not ip then return false end
    ip = gsub(gsub(ip, "[%s]*", ""), "x+", "*")
    local a, b, c, slash, d, finish = ip:match("^([^%.]+)%.([^%.]*)%.?([^%./]*)%.?(/?)([^%.]*)()")
    a = a == "" and "*" or a:match("[%d%*]+")
    b = b == "" and "*" or b:match("[%d%*]+")
    c = c == "" and "*" or c:match("[%d%*]+")
    slash = slash ~= ""
    d = d or ""
    if slash then
        if d:find("/") or not d:match("[%d%*]+") then return false end
        d = "0/" .. d
    else
        d = d == "" and "*" or d:match("[%d%*/]+")
    end

    if not a or not b or not c then return false end

    local found, a2, b2, c2, d2 = ip:match("(%-)(%d+)%.(%d*)%.?(%d*)%.?(%d*)%c*$", finish)
    if not found then
        if a2 and a ~= "" then return false end
        return format("%s.%s.%s.%s", a, b, c, d)
    elseif slash then
        return false
    end
    a2 = a2 == "" and "*" or a2:match("[%d%*]+")
    b2 = b2 == "" and "*" or b2:match("[%d%*]+")
    c2 = c2 == "" and "*" or c2:match("[%d%*]+")
    d2 = d2 == "" and "*" or d2:match("[%d%*]+")

    if not a2 or not b2 or not c2 then return false end
    if c2:find("/") and d2:find("/") then return false end
    return format("%s.%s.%s.%s-%s.%s.%s.%s", a, b, c, d, a2, b2, c2, d2)
end

--- Converts a dotted IPv4 address to a 32-bit integer.
-- @param ip_addr (string) IPv4 address
-- @return number|nil IP as 32-bit unsigned integer, or nil on error
function util.ip_to_long(ip_addr)
    local a, b, c, d = ip_addr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not (a and b and c and d) then return nil end
    return bit32.bor(bit32.lshift(a, 24), bit32.lshift(b, 16), bit32.lshift(c, 8), d)
end

--- Converts a 32-bit integer to a dotted IPv4 address.
-- @param addr (number) 32-bit unsigned integer
-- @return string IPv4 dotted notation
function util.long_to_ip(addr)
    local a = bit32.rshift(bit32.band(addr, 0xFF000000), 24)
    local b = bit32.rshift(bit32.band(addr, 0x00FF0000), 16)
    local c = bit32.rshift(bit32.band(addr, 0x0000FF00), 8)
    local d = bit32.band(addr, 0x000000FF)
    return format("%i.%i.%i.%i", a, b, c, d)
end

local function wildcard_to_cidr(addr)
    local count = select(2, addr:gsub("%*", "*"))
    if count == 1 then
        return addr:gsub("%*", "0") .. "/24"
    elseif count == 2 then
        return addr:gsub("%*", "0") .. "/16"
    elseif count == 3 then
        return addr:gsub("%*", "0") .. "/8"
    elseif count > 3 then
        return "0.0.0.0/0"
    end
    return addr
end

--- Checks whether an IP address matches a network definition (CIDR, wildcard, range).
-- @param network (string) network pattern (e.g., "192.168.1.0/24", "10.*.*.*", "10.0.0.1-10.0.0.255")
-- @param ip (string) IP address to test
-- @return string|boolean matched network string, or false
function util.ip_matches_network(network, ip)
    network = util.validate_ipv4(network)
    if not ip then return network end
    ip = util.validate_ipv4(ip)
    if not network or not ip then return false end

    -- Normalize wildcard to CID
    if network:find("%*") then network = wildcard_to_cidr(network) end
    if ip:find("%*") then ip = wildcard_to_cidr(ip) end

    local dash = network:find("-")
    if not dash then
        local net_part, mask_len = network:match("^(.-)/(%d+)$")
        mask_len = tonumber(mask_len) or 32
        local net_long = util.ip_to_long(net_part)
        if not net_long then return false end
        local ip_part, ip_mask_len = ip:match("^(.-)/(%d+)$")
        ip_mask_len = tonumber(ip_mask_len) or 32
        local ip_long = util.ip_to_long(ip_part)
        if not ip_long then return false end
        local mask = bit32.lshift(0xFFFFFFFF, (32 - mask_len))
        local ip_mask = bit32.lshift(0xFFFFFFFF, (32 - ip_mask_len))
        return bit32.band(net_long, mask, ip_mask) == bit32.band(ip_long, mask, ip_mask)
    else
        local from = util.ip_to_long(network:sub(1, dash - 1))
        local to = util.ip_to_long(network:sub(dash + 1))
        if not from or not to then return false end
        local ip_long = util.ip_to_long(ip)
        if not ip_long then return false end
        return ip_long >= from and ip_long <= to
    end
end

----------------------------------------------------------------------
-- MATH / GEOMETRY
----------------------------------------------------------------------

--- Checks if a point is inside a sphere.
-- @param px, py, pz (number) point coordinates
-- @param ox, oy, oz (number) sphere center
-- @param radius (number) sphere radius
-- @return boolean
function util.in_sphere(px, py, pz, ox, oy, oz, radius)
    local dx, dy, dz = ox - px, oy - py, oz - pz
    return (dx * dx + dy * dy + dz * dz) <= radius * radius
end

--- Checks if an object is within a given sphere.
-- @param object_id (number) an existing game object id
-- @param cx, cy, cz (number) center of sphere
-- @param radius (number) radius of sphere
-- @return boolean true if inside, false otherwise or if object invalid
function util.object_in_sphere(object_id, cx, cy, cz, radius)
    if not getobject(object_id) then return false end
    local x, y, z = getobjectcoords(object_id)
    return util.in_sphere(x, y, z, cx, cy, cz, radius)
end

--- Checks if a point (px, py) lies within a circle on the XY plane.
-- @param px, py (number) point coordinates
-- @param cx, cy (number) circle center
-- @param radius (number) circle radius
-- @return boolean
function util.check_in_circle(px, py, cx, cy, radius)
    return (px - cx) ^ 2 + (py - cy) ^ 2 <= radius ^ 2
end

--- Rounds a number to a specified number of decimal places.
-- @param val (number)
-- @param decimal (number) number of decimal places (optional)
-- @return number rounded value
function util.round(val, decimal)
    if decimal then
        return floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    end
    return floor(val + 0.5)
end

--- Converts a hexadecimal string to a number.
-- @param hex (string) hexadecimal representation
-- @return number|nil decimal value, or nil on failure
function util.to_decimal(hex) return tonumber(hex, 16) end

----------------------------------------------------------------------
-- OBJECT UTILITIES
----------------------------------------------------------------------

-- Cached tag lookup table (populated once per game)
local tag_lookup_cache

--- Returns the tag name and tag class of a game object.
-- @param object_id (number) object id
-- @return string tag_name, string tag_class or nil
function util.get_object_tag(object_id)
    if not object_id then return nil end
    local obj = getobject(object_id)
    if not obj then return nil end
    local object_map_id = readdword(obj)

    if not tag_lookup_cache then
        local map_base = readdword(map_pointer)
        if not map_base then return nil end

        local map_tag_count = util.to_decimal(util.read_string_reverse(map_base + 0xC, 3))
        if not map_tag_count then return nil end

        local tag_table_base = map_base + 0x28
        local tag_table_size = 0x20
        tag_lookup_cache = {}

        for i = 0, map_tag_count - 1 do
            local base = tag_table_base + (tag_table_size * i)
            local tag_id = util.to_decimal(util.read_string_reverse(base + 0xC, 3))
            local tag_class = util.read_string(base, 4, true)
            local tag_name_addr = util.to_decimal(util.read_string_reverse(base + 0x10, 3))
            local tag_name = util.read_tag_name(tag_name_addr)
            tag_lookup_cache[tag_id] = { name = tag_name, class = tag_class }
        end
    end

    local entry = tag_lookup_cache[object_map_id]
    if entry then return entry.name, entry.class end
    return nil
end

--- Returns the tag map ID for a given tag class and name.
-- Scans the in-memory tag table (cached on first call per game).
-- @param tag_class (string) e.g. "vehi", "weap"
-- @param tag_name (string) e.g. "vehicles\\ghost\\ghost_mp"
-- @return number|nil tag map ID, or nil if not found
function util.get_tag_id(tag_class, tag_name)
    if not tag_class or not tag_name then return nil end
    -- ensure cache is built
    if not tag_lookup_cache then
        -- dummy object to trigger cache build, will fail but cache is empty
        local map_base = readdword(map_pointer)
        if not map_base then return nil end
        local map_tag_count = util.to_decimal(util.read_string_reverse(map_base + 0xC, 3))
        if not map_tag_count then return nil end

        local tag_table_base = map_base + 0x28
        local tag_table_size = 0x20
        tag_lookup_cache = {}
        for i = 0, map_tag_count - 1 do
            local base = tag_table_base + (tag_table_size * i)
            local tag_id = util.to_decimal(util.read_string_reverse(base + 0xC, 3))
            local cls = util.read_string(base, 4, true)
            local tname_addr = util.to_decimal(util.read_string_reverse(base + 0x10, 3))
            local tname = util.read_tag_name(tname_addr)
            tag_lookup_cache[tag_id] = { name = tname, class = cls }
        end
    end

    for id, info in pairs(tag_lookup_cache) do
        if info.class == tag_class and (
                info.name == tag_name or
                info.name:gsub("\\", "/") == tag_name:gsub("\\", "/")
            ) then
            return id
        end
    end
    return nil
end

--- Returns the type of an object (0=biped, 1=vehicle, 2=weapon, 3=equipment, etc.).
-- @param object_id (number) object id
-- @return number|nil type identifier, or nil if invalid
function util.get_object_type(object_id)
    local obj = getobject(object_id)
    if not obj then return nil end
    return readword(obj + 0xB4)
end

--- Sets a vehicle upright by zeroing angular velocity and enabling physics.
-- @param vehicle_id (number) object id of the vehicle
function util.upright_vehicle(vehicle_id)
    local obj = getobject(vehicle_id)
    if not obj then return end
    -- zero angular velocity
    writefloat(obj + 0x8A, 2.3 * (10 ^ -41))
    writefloat(obj + 0x8C, 2.3 * (10 ^ -41))
    writefloat(obj + 0x90, 2.3 * (10 ^ -41))
    writefloat(obj + 0x94, 2.3 * (10 ^ -41))
    -- re-enable physics
    util.write_bit(obj + 0x10, 0, 0) -- noCollisions bit off
    util.write_bit(obj + 0x10, 5, 0) -- ignorePhysics bit off
end

--- Sets the player's current vehicle upright (if any).
-- @param player_id (number) player index
function util.upright_player_vehicle(player_id)
    local veh_id = util.get_player_vehicle(player_id)
    if veh_id then
        util.upright_vehicle(veh_id)
    end
end

----------------------------------------------------------------------
-- MEMORY UTILITIES
----------------------------------------------------------------------

--- Reads a C-style null-terminated ASCII string from a memory address.
-- @param address (number) starting memory address
-- @param length (number) maximum length to read (optional)
-- @param reverse (boolean) reverse byte order for endianness (optional)
-- @return string the decoded string
function util.read_string(address, length, reverse)
    local t, i = {}, 0
    local max = length or 256
    while i < max do
        local b = readbyte(address + i)
        if b == 0 then break end
        t[#t + 1] = char(b)
        i = i + 1
    end
    if reverse then
        local rev = {}
        for j = #t, 1, -1 do rev[#rev + 1] = t[j] end
        return concat(rev)
    end
    return concat(t)
end

--- Reads a tag name from a memory address. Identical to read_string but without length cap.
-- @param address (number) memory location of null-terminated string
-- @return string tag name
function util.read_tag_name(address)
    if not address or address == 0 then return "" end
    return util.read_string(address)
end

--- Reads a specified number of bytes from memory and returns a hex string in reversed order (big-endian).
-- @param address (number) base address
-- @param offset (number) offset from base
-- @param length (number) number of bytes to read
-- @return string hex representation
function util.read_string_reverse(address, offset, length)
    local hex = {}
    for i = 0, length - 1 do
        local b = readbyte(address + offset + i)
        hex[#hex + 1] = format("%02X", b)
    end
    local result = ""
    for i = #hex, 1, -1 do result = result .. hex[i] end
    return result
end

--- Reads a null-terminated wide-character string (UTF-16LE with ASCII assumption).
-- @param address (number) memory start
-- @param length (number|nil) max bytes, optional (default 256)
-- @return string decoded ASCII string
function util.read_widestring(address, length)
    length = length or 256
    local chars = {}
    local pos = 0
    while pos < length do
        local b1 = readbyte(address + pos)
        if b1 == 0 then break end
        local b2 = readbyte(address + pos + 1)
        -- wide char: assume low byte is ASCII, high byte is 0
        if b2 == 0 then
            chars[#chars + 1] = char(b1)
        else
            chars[#chars + 1] = char(b1) -- fallback, non-ASCII will be ignored
        end
        pos = pos + 2
    end
    return concat(chars)
end

--- Writes a null-terminated ASCII string to memory.
-- @param address (number) start address
-- @param str (string) string to write
-- @param offset (number) optional offset from address
function util.write_string(address, str, offset)
    offset = offset or 0
    local addr = address + offset
    for i = 1, #str do
        writebyte(addr + i - 1, str:byte(i))
    end
    writebyte(addr + #str, 0) -- null terminator
end

--- Writes a wide (UTF-16LE) string to memory (null-terminated).
-- @param address (number) start address
-- @param str (string) ASCII string to write as wide
-- @param offset (number) optional offset
function util.write_widestring(address, str, offset)
    offset = offset or 0
    local addr = address + offset
    for i = 1, #str do
        local byte = str:byte(i)
        writebyte(addr + (i - 1) * 2, byte)
        writebyte(addr + (i - 1) * 2 + 1, 0)
    end
    writeword(addr + #str * 2, 0) -- null terminator (two bytes)
end

--- Reads a single bit from a memory address.
-- @param address (number) memory address
-- @param bit_index (number) 0-based bit index (0 = LSB)
-- @return number 0 or 1
function util.read_bit(address, bit_index)
    local byte_addr = address + floor(bit_index / 8)
    local bit_pos = bit_index % 8
    local val = readbyte(byte_addr)
    return bit32.band(bit32.rshift(val, bit_pos), 1)
end

--- Writes a single bit to a memory address.
-- @param address (number) memory address
-- @param bit_index (number) 0-based bit index
-- @param value (number) 0 or 1
function util.write_bit(address, bit_index, value)
    local byte_addr = address + floor(bit_index / 8)
    local bit_pos = bit_index % 8
    local old = readbyte(byte_addr)
    if value == 1 then
        writebyte(byte_addr, bit32.bor(old, bit32.lshift(1, bit_pos)))
    else
        writebyte(byte_addr, bit32.band(old, bit32.bnot(bit32.lshift(1, bit_pos))))
    end
end

--- Safe write functions that clamp value to the type's valid range.
-- These mirror Phasor's write API but avoid crashes due to out-of-range values.
-- @param address (number) memory address
-- @param offset (number) optional offset
-- @param value (number) value to write

function util.safe_write_byte(address, offset, value)
    if value then address = address + offset else value = offset end
    value = math_min(math_max(value, 0), 0xFF)
    writebyte(address, value)
end

function util.safe_write_char(address, offset, value)
    if value then address = address + offset else value = offset end
    value = math_min(math_max(value, -0x80), 0x7F)
    writechar(address, value)
end

function util.safe_write_short(address, offset, value)
    if value then address = address + offset else value = offset end
    value = math_min(math_max(value, -0x8000), 0x7FFF)
    writeshort(address, value)
end

function util.safe_write_word(address, offset, value)
    if value then address = address + offset else value = offset end
    value = math_min(math_max(value, 0), 0xFFFF)
    writeword(address, value)
end

function util.safe_write_int(address, offset, value)
    if value then address = address + offset else value = offset end
    value = math_min(math_max(value, -0x80000000), 0x7FFFFFFF)
    writeint(address, value)
end

function util.safe_write_dword(address, offset, value)
    if value then address = address + offset else value = offset end
    value = math_min(math_max(value, 0), 0xFFFFFFFF)
    writedword(address, value)
end

function util.safe_write_float(address, offset, value)
    if value then address = address + offset else value = offset end
    writefloat(address, value)
end

----------------------------------------------------------------------
-- GAME TIME / STATE
----------------------------------------------------------------------

--- Returns the numeric gametype id (0=none, 1=ctf, 2=slayer, 3=oddball, 4=king, 5=race).
-- @return number gametype id
function util.get_gametype_id()
    return readbyte(gametype_base + 0x30)
end

--- Returns the score limit of the current gametype.
-- @return number score_limit
function util.get_scorelimit()
    return readbyte(gametype_base + 0x58)
end

--- Sets the score limit for the current gametype.
-- @param score (number) new score limit (0-255)
function util.set_scorelimit(score)
    writebyte(gametype_base + 0x58, score)
end

--- Checks whether the current gametype is Free-For-All.
-- @return boolean true if FFA (0), false if Team (1)
function util.is_ffa()
    return readbyte(gametype_base + 0x34) == 0
end

--- Returns the gametype mode name as a string (e.g., "ctf", "slayer").
-- @return string gametype name
function util.get_gametype_name()
    local type = readbyte(gametype_base + 0x30)
    return type == 0 and "none"
        or type == 1 and "ctf"
        or type == 2 and "slayer"
        or type == 3 and "oddball"
        or type == 4 and "king"
        or type == 5 and "race"
end

--- Returns the remaining game time in seconds (based on the current gametype).
-- @return number seconds remaining, or 0 if time is up
function util.get_game_time_remaining()
    local time_passed = readdword(readdword(gametime_base) + 0xC) / 30 -- in seconds
    local time_limit = readdword(gametype_base + 0x78) / 30
    local remaining = time_limit - time_passed
    return remaining > 0 and remaining or 0
end

--- Returns the elapsed game time in seconds.
-- @return number seconds since game start
function util.get_game_time_elapsed()
    return readdword(readdword(gametime_base) + 0xC) / 30
end

--- Returns the player's current score (gametype-dependent).
-- @param player_id (number) player index (0-15)
-- @return number score, or nil if player invalid
function util.get_player_score(player_id)
    local p = getplayer(player_id)
    if not p then return nil end
    local gt = util.get_gametype_id()
    if gt == 1 then -- ctf
        return readshort(p + 0xC8)
    elseif gt == 2 then -- slayer
        return readint(slayer_globals + 0x40 + player_id * 4)
    elseif gt == 3 then -- oddball
        local oddball_game = readbyte(gametype_base + 0x8C)
        if oddball_game == 0 or oddball_game == 1 then
            return readint(oddball_globals + 0x84 + player_id * 4) / 30
        else
            return readint(oddball_globals + player_id * 4 + 0x104)
        end
    elseif gt == 4 then -- king
        return readshort(p + 0xC4)
    elseif gt == 5 then -- race
        return readshort(p + 0xC6)
    end
    return 0
end

--- Sets the player's score (gametype-dependent).
-- @param player_id (number) player index
-- @param score (number) new score
function util.set_player_score(player_id, score)
    local p = getplayer(player_id)
    if not p then return end
    local gt = util.get_gametype_id()
    if gt == 1 then
        writeshort(p + 0xC8, score)
    elseif gt == 2 then
        writeint(slayer_globals + 0x40 + player_id * 4, score)
    elseif gt == 3 then
        local oddball_game = readbyte(gametype_base + 0x8C)
        if oddball_game == 0 or oddball_game == 1 then
            writeint(oddball_globals + 0x84 + player_id * 4, score * 30)
        else
            writeint(oddball_globals + player_id * 4 + 0x104, score)
        end
    elseif gt == 4 then
        writeshort(p + 0xC4, score)
    elseif gt == 5 then
        writeshort(p + 0xC6, score)
    end
end

--- Returns the team score for the given team (0=red, 1=blue) – gametype-dependent.
-- @param team (number) 0 or 1
-- @return number score
function util.get_team_score(team)
    local gt = util.get_gametype_id()
    if gt == 1 then     -- ctf
        return readint(ctf_globals + team * 4 + 0x10)
    elseif gt == 2 then -- slayer
        return readint(slayer_globals + team * 4)
    elseif gt == 3 then -- oddball
        return readint(oddball_globals + team * 4 + 0x4) / 30
    elseif gt == 4 then -- king
        return readint(koth_globals + team * 4) / 30
    elseif gt == 5 then -- race
        return readint(race_globals + team * 4 + 0x88) / 30
    end
    return 0
end

--- Sets the team score for the given team (0=red, 1=blue).
-- @param team (number) 0 or 1
-- @param score (number) new score
function util.set_team_score(team, score)
    local gt = util.get_gametype_id()
    if gt == 1 then
        writeint(ctf_globals + team * 4 + 0x10, score)
    elseif gt == 2 then
        writeint(slayer_globals + team * 4, score)
    elseif gt == 3 then
        writeint(oddball_globals + team * 4 + 0x4, score * 30)
    elseif gt == 4 then
        writeint(koth_globals + team * 4, score * 30)
    elseif gt == 5 then
        writeint(race_globals + team * 4 + 0x88, score * 30)
    end
end

----------------------------------------------------------------------
-- MISC
----------------------------------------------------------------------

--- Returns the world position of a biped body part given its offset into the biped
-- object's unknown floats block (0x28 base). Example offsets: 0x8C4 = right hand.
-- @param biped_object (table) the player's biped object struct (from get_player_object)
-- @param body_part_offset (number) offset from the object's start + 0x28
-- @return number x, number y, number z, or nil if object invalid
function util.get_body_part_position(biped_object, body_part_offset)
    if not biped_object then return nil end
    local x = readfloat(biped_object, body_part_offset + 0x28)
    local y = readfloat(biped_object, body_part_offset + 0x2C)
    local z = readfloat(biped_object, body_part_offset + 0x30)
    return x, y, z
end

return util
