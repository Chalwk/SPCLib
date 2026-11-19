--[[
=====================================================================================
SCRIPT NAME:    json.lua
DESCRIPTION:    Dependency-free JSON encoder/decoder in pure Lua.
                
USAGE:          local json = require("json")
                local text, err = json.encode({ name = "Chalwk", scores = {1,2,3} })
                local data, err = json.decode(text)

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
			https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

local json = { _VERSION = "1.0.0" }

local type, tostring, tonumber, pairs = type, tostring, tonumber, pairs
local error, pcall, setmetatable, getmetatable = error, pcall, setmetatable, getmetatable
local str_char, str_byte, str_find, str_sub = string.char, string.byte, string.find, string.sub
local str_format, str_gsub, str_match, str_rep = string.format, string.gsub, string.match, string.rep
local floor, huge = math.floor, math.huge
local concat, sort = table.concat, table.sort

--- Represents JSON `null`. Compare with `==`.
---@type table
json.null = setmetatable({}, {
    __tostring = function () return "null" end,
    __newindex = function () error("json.null is read-only", 2) end
})

local array_mt = { __jsontype = "array" }
local object_mt = { __jsontype = "object" }

--- Marks a table so it always encodes as a JSON array (even when empty).
---@param t table | nil Table to mark. A new table is created if omitted.
---@return table t The same table.
function json.array(t)
    return setmetatable(t or {}, array_mt)
end

--- Marks a table so it always encodes as a JSON object (even when empty).
---@param t table | nil Table to mark. A new table is created if omitted.
---@return table t The same table.
function json.object(t)
    return setmetatable(t or {}, object_mt)
end

-- Encoder stuff:
local escape_map = {
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\127'] = '\\u007f'
}
for i = 0, 31 do
    local c = str_char(i)
    if not escape_map[c] then escape_map[c] = str_format("\\u%04x", i) end
end

---@param s string
---@return string
local function encodeString(s)
    return '"' .. str_gsub(s, '[%c"\\]', escape_map) .. '"'
end

---@param n number
---@return string
local function encodeNumber(n)
    if n ~= n or n == huge or n == -huge then
        error("cannot encode NaN or infinity", 0)
    end
    if n == floor(n) and n > -1e15 and n < 1e15 then
        return str_format("%d", n)
    end
    local s = str_format("%.14g", n)
    if tonumber(s) ~= n then s = str_format("%.17g", n) end -- only when 14 digits lose precision
    return s
end

-- Decides how a table is encoded. Returns "array", length  or  "object".
---@param t table
---@return string kind, number | nil length
local function classify(t)
    local mt = getmetatable(t)
    local forced = mt and mt.__jsontype

    if forced == "object" then return "object" end
    if forced == "array" then return "array", #t end

    local count, sequence = 0, true
    ---@type number
    local max = 0
    for k in pairs(t) do
        count = count + 1
        if type(k) ~= "number" or k < 1 or k ~= floor(k) then
            sequence = false
        elseif k > max then
            max = k
        end
    end

    if sequence and max == count then return "array", count end
    return "object"
end

---@class JsonEncodeCtx
---@field indent    string | nil
---@field sort_keys boolean
---@field max_depth integer

-- Forward declaration; assigned below. The explicit type stops need-check-nil on recursive calls.
---@type fun(v: any, buf: string[], ctx: JsonEncodeCtx, level: integer, stack: table<table, boolean>)
local encodeValue

---@param v     table
---@param buf   string[]
---@param ctx   JsonEncodeCtx
---@param level integer
---@param stack table<table, boolean>
local function encodeTable(v, buf, ctx, level, stack)
    if stack[v] then error("circular reference detected", 0) end
    if level >= ctx.max_depth then error("maximum nesting depth exceeded", 0) end
    stack[v] = true

    local indent = ctx.indent
    local nl_inner = indent and ("\n" .. str_rep(indent, level + 1)) or ""
    local nl_outer = indent and ("\n" .. str_rep(indent, level)) or ""
    local kind, length = classify(v)

    if kind == "array" then
        if length == 0 then
            buf[#buf + 1] = "[]"
        else
            buf[#buf + 1] = "["
            for i = 1, length do
                if i > 1 then buf[#buf + 1] = "," end
                buf[#buf + 1] = nl_inner
                encodeValue(v[i], buf, ctx, level + 1, stack)
            end
            buf[#buf + 1] = nl_outer
            buf[#buf + 1] = "]"
        end
    else
        local keys, values = {}, {}
        for k, val in pairs(v) do
            local key_type = type(k)
            local key
            if key_type == "string" then
                key = k
            elseif key_type == "number" then
                key = encodeNumber(k)
            else
                error("object keys must be strings or numbers, got " .. key_type, 0)
            end
            keys[#keys + 1] = key
            values[key] = val
        end

        if #keys == 0 then
            buf[#buf + 1] = "{}"
        else
            if ctx.sort_keys then sort(keys) end
            local colon = indent and ": " or ":"
            buf[#buf + 1] = "{"
            for i = 1, #keys do
                if i > 1 then buf[#buf + 1] = "," end
                buf[#buf + 1] = nl_inner
                buf[#buf + 1] = encodeString(keys[i])
                buf[#buf + 1] = colon
                encodeValue(values[keys[i]], buf, ctx, level + 1, stack)
            end
            buf[#buf + 1] = nl_outer
            buf[#buf + 1] = "}"
        end
    end

    stack[v] = nil
end

encodeValue = function (v, buf, ctx, level, stack)
    if v == nil or v == json.null then
        buf[#buf + 1] = "null"
        return
    end

    local t = type(v)
    if t == "string" then
        buf[#buf + 1] = encodeString(v)
    elseif t == "number" then
        buf[#buf + 1] = encodeNumber(v)
    elseif t == "boolean" then
        buf[#buf + 1] = v and "true" or "false"
    elseif t == "table" then
        encodeTable(v, buf, ctx, level, stack)
    else
        error("cannot encode value of type " .. t, 0)
    end
end

--- Encodes a Lua value as a JSON string.
---@param value any Value to encode (nil, boolean, number, string, table, or json.null).
---@param opts? { indent?: number | string, sort_keys?: boolean, max_depth?: integer }
---   `indent`: spaces per level (number) or indent string for pretty output. Default: compact.
---   `sort_keys`: sort object keys for stable output. Default: true.
---   `max_depth`: maximum nesting depth. Default: 200.
---@return string | nil json_string, string | nil error_message
function json.encode(value, opts)
    opts = opts or {}

    local indent = opts.indent
    if type(indent) == "number" then indent = indent > 0 and str_rep(" ", floor(indent)) or nil end
    if indent == "" then indent = nil end

    local ctx = { indent = indent, sort_keys = opts.sort_keys ~= false, max_depth = opts.max_depth or 200 }

    local buf = {}
    local ok, err = pcall(encodeValue, value, buf, ctx, 0, {})
    if not ok then return nil, tostring(err) end

    return concat(buf)
end

-- Decoder stuff:
local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }

-- Raises a decode error with line and column information (caught by json.decode).
---@param str string
---@param pos integer
---@param msg string
---@return never
local function fail(str, pos, msg)
    local line, last, i = 1, 0, 1
    while true do
        local nl = str_find(str, "\n", i, true)
        if not nl or nl >= pos then break end
        line = line + 1
        last = nl
        i = nl + 1
    end
    error(str_format("%s at line %d, column %d", msg, line, pos - last), 0)
end

---@param str string
---@param pos integer
---@return integer pos Position of the next non-whitespace character.
local function skip(str, pos)
    return str_find(str, "[^ \t\r\n]", pos) or (#str + 1)
end

-- Converts a Unicode code point to UTF-8 bytes (no `utf8` library in Lua 5.1).
---@param cp integer
---@return string
local function utf8Encode(cp)
    if cp < 0x80 then
        return str_char(cp)
    elseif cp < 0x800 then
        return str_char(0xC0 + floor(cp / 0x40), 0x80 + cp % 0x40)
    elseif cp < 0x10000 then
        return str_char(0xE0 + floor(cp / 0x1000), 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return str_char(
        0xF0 + floor(cp / 0x40000), 0x80 + floor(cp / 0x1000) % 0x40, 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40
    )
end

---@param str string
---@param pos integer Position of the opening quote.
---@return string value, integer next_pos
local function parseString(str, pos)
    local buf, n = {}, 0
    local i = pos + 1

    while true do
        -- %z = \0 (Lua 5.1 patterns cannot contain a literal NUL)
        local s = str_find(str, '[%z\1-\31"\\]', i)
        if not s then fail(str, pos, "unterminated string") end

        if s > i then
            n = n + 1
            buf[n] = str_sub(str, i, s - 1)
        end

        local c = str_byte(str, s)
        if c == 34 then -- closing quote
            return concat(buf), s + 1
        elseif c == 92 then -- backslash
            local e = str_sub(str, s + 1, s + 1)
            if e == "u" then
                local hex = str_match(str, "^%x%x%x%x", s + 2)
                if not hex then fail(str, s, "invalid unicode escape") end

                local cp = tonumber(hex, 16)
                ---@cast cp integer
                i = s + 6

                if cp >= 0xD800 and cp <= 0xDBFF then -- high surrogate: needs a low surrogate
                    local lo_hex = str_match(str, "^\\u(%x%x%x%x)", i)
                    local lo = lo_hex and tonumber(lo_hex, 16)
                    if not lo or lo < 0xDC00 or lo > 0xDFFF then
                        fail(str, s, "invalid surrogate pair")
                    end
                    ---@cast lo integer
                    cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                    i = i + 6
                elseif cp >= 0xDC00 and cp <= 0xDFFF then
                    fail(str, s, "unexpected low surrogate")
                end

                n = n + 1
                buf[n] = utf8Encode(cp)
            else
                local r = escapes[e]
                if not r then fail(str, s, "invalid escape sequence") end
                n = n + 1
                buf[n] = r
                i = s + 2
            end
        else
            fail(str, s, "control character in string")
        end
    end
end

---@param str string
---@param pos integer
---@return number value, integer next_pos
local function parseNumber(str, pos)
    local _, e = str_find(str, "^-?0", pos)
    if e then
        if str_find(str, "^%d", e + 1) then fail(str, pos, "leading zeros are not allowed") end
    else
        _, e = str_find(str, "^-?[1-9]%d*", pos)
        if not e then fail(str, pos, "invalid number") end
    end

    local _, frac_end = str_find(str, "^%.%d+", e + 1)
    if frac_end then
        e = frac_end
    elseif str_sub(str, e + 1, e + 1) == "." then
        fail(str, e + 1, "digits required after decimal point")
    end

    local _, exp_end = str_find(str, "^[eE][+-]?%d+", e + 1)
    if exp_end then
        e = exp_end
    elseif str_find(str, "^[eE]", e + 1) then
        fail(str, e + 1, "invalid exponent")
    end

    local value = tonumber(str_sub(str, pos, e))
    ---@cast value number
    return value, e + 1
end

---@class JsonDecodeCtx
---@field null      table | nil
---@field max_depth integer

-- Forward declaration; assigned below. The explicit type stops need-check-nil on recursive calls.
---@type fun(str: string, pos: integer, depth: integer, ctx: JsonDecodeCtx): any, integer
local parseValue

---@param str   string
---@param pos   integer Position of the opening bracket.
---@param depth integer
---@param ctx   JsonDecodeCtx
---@return table value, integer next_pos
local function parseArray(str, pos, depth, ctx)
    local arr, n = {}, 0

    pos = skip(str, pos + 1)
    if str_byte(str, pos) == 93 then return arr, pos + 1 end

    while true do
        local v
        v, pos = parseValue(str, pos, depth, ctx)
        n = n + 1
        arr[n] = v

        pos = skip(str, pos)
        local c = str_byte(str, pos)
        if c == 44 then
            pos = skip(str, pos + 1)
        elseif c == 93 then
            return arr, pos + 1
        else
            fail(str, pos, "expected ',' or ']'")
        end
    end
end

---@param str   string
---@param pos   integer Position of the opening brace.
---@param depth integer
---@param ctx   JsonDecodeCtx
---@return table value, integer next_pos
local function parseObject(str, pos, depth, ctx)
    local obj = {}

    pos = skip(str, pos + 1)
    if str_byte(str, pos) == 125 then
        return setmetatable(obj, object_mt), pos + 1 -- keep {} as {} when re-encoded
    end

    while true do
        if str_byte(str, pos) ~= 34 then fail(str, pos, "expected string key") end

        local key
        key, pos = parseString(str, pos)

        pos = skip(str, pos)
        if str_byte(str, pos) ~= 58 then fail(str, pos, "expected ':'") end
        pos = skip(str, pos + 1)

        local v
        v, pos = parseValue(str, pos, depth, ctx)
        obj[key] = v -- duplicate keys: last one wins

        pos = skip(str, pos)
        local c = str_byte(str, pos)
        if c == 44 then
            pos = skip(str, pos + 1)
        elseif c == 125 then
            return obj, pos + 1
        else
            fail(str, pos, "expected ',' or '}'")
        end
    end
end

---@param str   string
---@param pos   integer
---@param depth integer
---@param ctx   JsonDecodeCtx
---@return any value, integer next_pos
parseValue = function (str, pos, depth, ctx)
    local c = str_byte(str, pos)

    if c == 34 then -- "
        return parseString(str, pos)
    elseif c == 123 or c == 91 then -- { [
        if depth >= ctx.max_depth then fail(str, pos, "maximum nesting depth exceeded") end
        if c == 123 then return parseObject(str, pos, depth + 1, ctx) end
        return parseArray(str, pos, depth + 1, ctx)
    elseif c == 45 or (c and c >= 48 and c <= 57) then -- - or digit
        return parseNumber(str, pos)
    elseif c == 116 then -- t
        if str_sub(str, pos, pos + 3) == "true" then return true, pos + 4 end
    elseif c == 102 then -- f
        if str_sub(str, pos, pos + 4) == "false" then return false, pos + 5 end
    elseif c == 110 then -- n
        if str_sub(str, pos, pos + 3) == "null" then return ctx.null, pos + 4 end
    elseif c == nil then
        fail(str, pos, "unexpected end of input")
    end

    fail(str, pos, "unexpected character '" .. str_sub(str, pos, pos) .. "'")
    return nil, pos -- unreachable (fail always throws); satisfies the 2-value return annotation
end

---@param str string
---@param ctx JsonDecodeCtx
local function parseDocument(str, ctx)
    local pos = 1
    if str_sub(str, 1, 3) == "\239\187\191" then pos = 4 end -- skip UTF-8 BOM

    pos = skip(str, pos)
    local v
    v, pos = parseValue(str, pos, 0, ctx)

    pos = skip(str, pos)
    if pos <= #str then fail(str, pos, "unexpected trailing characters") end

    return v
end

--- Decodes a JSON string into a Lua value.
---@param str   string JSON text.
---@param opts? { null_as_nil?: boolean, max_depth?: integer }
---   `null_as_nil`: decode `null` as `nil` instead of `json.null`. Default: false.
---   `max_depth`: maximum nesting depth. Default: 200.
---@return any value, string | nil error_message On failure: `nil, error_message`.
function json.decode(str, opts)
    if type(str) ~= "string" then
        return nil, "expected a string, got " .. type(str)
    end

    opts = opts or {}
    local ctx = { null = (not opts.null_as_nil) and json.null or nil, max_depth = opts.max_depth or 200 }

    local ok, result = pcall(parseDocument, str, ctx)
    if not ok then return nil, tostring(result) end

    return result, nil
end

return json
