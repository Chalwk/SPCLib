---@diagnostic disable: param-type-mismatch, assign-type-mismatch
--[[
=====================================================================================
SCRIPT NAME:      phasor_util.lua
DESCRIPTION:      A collection of common utility functions for Phasor Lua scripting.

                  Functions cover player state checks, coordinate manipulation,
                  string handling, memory reading, wildcard matching, time conversion,
                  and more. Designed to be used via require() to keep other scripts
                  clean and DRY.

                  Example usage:
                      local util = require("phasor_util")

                      function OnScriptLoad(processid, game, persistent)
                          -- Tell phasor_util whether this is PC or CE
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
            hash_duplicate_patch = 0x59C516
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
            hash_duplicate_patch = 0x5302E6
        }
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

-- Phasor API locals
local getplayerobjectid = getplayerobjectid
local getobject = getobject
local readfloat = readfloat
local readword = readword
local readdword = readdword
local readbyte = readbyte
local getplayer = getplayer
local getname = getname
local getteam = getteam
local getobjectcoords = getobjectcoords
local map_pointer

--- Initialises game-dependent memory addresses for PC and CE. Pointers are pre-defined
-- in util.pointers; this function simply selects the appropriate map pointer for the current game.
-- @param game (string) "PC" or "CE" (as provided by Phasor).
-- @usage
--   function OnScriptLoad(processid, game, persistent)
--       util.init_game(game)
--   end
function util.init_game(game)
    map_pointer = util.pointers[game].map_pointer
end

----------------------------------------------------------------------
-- PLAYER STATE / INFO
----------------------------------------------------------------------

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
    local obj_id = getplayerobjectid(id)
    if not obj_id or obj_id == 0 then return nil end

    local obj = getobject(obj_id)
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
    local player_object_id = getplayerobjectid(id)
    if not player_object_id or player_object_id == 0 then return nil end

    local player_object = getobject(player_object_id)
    if not player_object then return nil end

    return readfloat(player_object + 0x37C) == 1.0
end

--- Returns a table with the player's kill, death, and assist counts for the current game.
-- @param id (number)
-- @return table|nil { kills = number, deaths = number, assists = number } or nil if player invalid
function util.get_player_stats(id)
    local p = getplayer(id)
    if not p then return nil end

    return {
        kills = readword(p + 0x9C),
        deaths = readword(p + 0xAE),
        assists = readword(p + 0xA4),
    }
end

--- Returns the player's current killstreak (consecutive kills without dying).
-- @param id (number)
-- @return number streak, or 0 on error
function util.get_player_killstreak(id)
    local p = getplayer(id)
    if not p then return 0 end
    return readword(p + 0x98)
end

--- Returns the object ID of the vehicle the player is currently riding in,
-- or nil if the player is not in a vehicle.
-- @param id (number)
-- @return number vehicle_object_id or nil
function util.get_player_vehicle(id)
    local obj_id = getplayerobjectid(id)
    if not obj_id then return nil end

    local obj = getobject(obj_id)
    if not obj then return nil end

    local vehicle_id = readdword(obj + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    return vehicle_id
end

--- Resolves player expressions (names, wildcards, "me", "red", "blue", "random", "*").
-- Example: get_players_by_expression("Player*") returns all players whose names start with "Player".
-- @param expression (string) player identifier
-- @param self_id (number|nil) player ID of the caller (used for "me" and "random" exclusion)
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
    else
        -- Numeric ID (1-16)
        local num = tonumber(expression)
        if num and num >= 1 and num <= 16 then
            local id = num - 1
            if getplayer(id) then return { id } end
            return nil
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
-- Useful for normalising chat commands.
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
-- Strips the prefix first, then splits by whitespace.
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
-- Usage: local parts = util.split_string("a,b;c", ",", ";") -> {"a","b","c"}
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

----------------------------------------------------------------------
-- MEMORY UTILITIES
----------------------------------------------------------------------

--- Reads a C-style null-terminated string from a memory address.
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

----------------------------------------------------------------------
-- MISC
----------------------------------------------------------------------

-- TODO: Add util stuff here (I'll do this soon).

return util
