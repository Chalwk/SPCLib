--[[
=====================================================================================
SCRIPT NAME:      name_ban.lua
DESCRIPTION:      Kicks (or optionally bans) players who join with a disallowed name.
                  Names are matched case-insensitively; optional wildcard support.

Copyright (c) 2024-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

---@class NameBanConfig
---@field action            string   "kick" | "hashban" | "ipban" | "both"
---@field ban_duration      number   Ban duration (seconds) for non-kick actions; 0 = indefinite.
---@field kick_reason       string   Reason shown in the announcement / ban entry.
---@field log_rejections    boolean  Print a red server-console line on each rejection.
---@field banned_names      string[] Exact-match disallowed names (case-insensitive).
---@field wildcard_patterns string[] Optional case-insensitive wildcard patterns ("*" and "?").

-- Config start -----------------------------------------

---@type NameBanConfig
local CONFIG = {
    action = "kick",
    ban_duration = 0,
    kick_reason = "Name not allowed.",
    log_rejections = true,

    -- Default profile name + Halo's built-in placeholder name pool
    -- See: https://chalwk.github.io/halo/common-reference/#default-profile-name
    banned_names = {
        "Butcher", "Caboose", "Crazy", "Cupid", "Darling",
        "Dasher", "Disco", "Donut", "Dopey", "Ghost",
        "Goat", "Grumpy", "Hambone", "Hollywood", "Howard",
        "Jack", "Killer", "King", "Mopey", "New001",
        "Noodle", "Nuevo001", "Penguin", "Pirate", "Prancer",
        "Saucy", "Shadow", "Sleepy", "Snake", "Sneak",
        "Stompy", "Stumpy", "The Bear", "The Big L", "Tooth",
        "Walla Walla", "Weasel", "Wheezy", "Whicker", "Whisp",
        "Wilshire"
    },
    
    -- Example: { "bot*", "*clan*", "player??" }
    wildcard_patterns = {}
}

---@type boolean
local has_wildcards = #CONFIG.wildcard_patterns > 0

---@type table<string, true | nil>
local BANNED_SET = {}

-- Case-insensitive wildcard match. Supports "*" and "?".
-- Mirrors the shared helper in Common Reference > String Utilities.
---@param str     string
---@param pattern string
---@return boolean
local function wildcardMatch(str, pattern)
    if not str or not pattern then return false end
    str, pattern = str:lower(), pattern:lower()

    if pattern:sub(1, 1) == "?" then
        pattern = str:sub(1, 1) .. pattern:sub(2)
    end
    if pattern:sub(-1) == "?" then
        pattern = pattern:sub(1, -2) .. str:sub(-1)
    end

    if not pattern:find("*", 1, true) and not pattern:find("?", 1, true) then
        return str == pattern
    end

    if pattern:sub(1, 1) ~= str:sub(1, 1) and pattern:sub(1, 1) ~= "*" then return false end
    if pattern:sub(-1) ~= str:sub(-1) and pattern:sub(-1) ~= "*" then return false end

    local subpatterns, cur = {}, ""
    for i = 1, #pattern do
        local c = pattern:sub(i, i)
        if c == "*" then
            if cur ~= "" then
                subpatterns[#subpatterns + 1] = cur
                cur = ""
            end
        else
            cur = cur .. c
        end
    end
    if cur ~= "" then subpatterns[#subpatterns + 1] = cur end

    local start = 1
    for _, subp in ipairs(subpatterns) do
        local sublen = #subp
        local found, ts = false, start
        while ts + sublen - 1 <= #str do
            local match = true
            for j = 1, sublen do
                local pc = subp:sub(j, j)
                if pc ~= "?" and pc ~= str:sub(ts + j - 1, ts + j - 1) then
                    match = false
                    break
                end
            end
            if match then
                found = true
                start = ts + sublen
                break
            end
            ts = ts + 1
        end
        if not found then return false end
    end
    return true
end

-- Trim surrounding whitespace and lowercase. Returns "" for nil/empty input.
---@param name string | nil
---@return string
local function normalizeName(name)
    if not name then return "" end
    return (name:match("^%s*(.-)%s*$") or ""):lower()
end

---@param name string Normalized (lowercased, trimmed) player name.
---@return boolean banned
local function isNameBanned(name)
    if name == "" then return false end

    if BANNED_SET[name] then return true end

    if has_wildcards then
        for _, pattern in ipairs(CONFIG.wildcard_patterns) do
            if wildcardMatch(name, pattern) then return true end
        end
    end

    return false
end

-- Apply the configured response. `b` takes [reason] [time]; `ipban` takes [time] [reason].
---@param player_id number
---@param reason    string
local function rejectPlayer(player_id, reason)
    if CONFIG.action == "kick" then
        execute_command('k ' .. player_id .. ' "' .. reason .. '"')
    elseif CONFIG.action == "hashban" then
        local cmd = 'b ' .. player_id .. ' "' .. reason .. '"'
        if CONFIG.ban_duration > 0 then cmd = cmd .. ' ' .. CONFIG.ban_duration end
        execute_command(cmd)
    elseif CONFIG.action == "ipban" then
        execute_command('ipban ' .. player_id .. ' ' .. CONFIG.ban_duration .. ' "' .. reason .. '"')
    elseif CONFIG.action == "both" then
        execute_command('ipban ' .. player_id .. ' ' .. CONFIG.ban_duration .. ' "' .. reason .. '"')
        local cmd = 'b ' .. player_id .. ' "' .. reason .. '"'
        if CONFIG.ban_duration > 0 then cmd = cmd .. ' ' .. CONFIG.ban_duration end
        execute_command(cmd)
    else
        -- Unknown CONFIG.action: kick as a safe fallback.
        execute_command('k ' .. player_id .. ' "' .. reason .. '"')
    end
end

function OnScriptLoad()
    for _, name in ipairs(CONFIG.banned_names) do
        BANNED_SET[normalizeName(name)] = true
    end
    register_callback(cb.EVENT_JOIN, "OnJoin")
end

---@param player_id number
function OnJoin(player_id)
    local raw_name = get_var(player_id, "$name")
    local name = normalizeName(raw_name)

    if not isNameBanned(name) then return end

    rejectPlayer(player_id, CONFIG.kick_reason)

    if CONFIG.log_rejections then
        cprint(string.format('name_ban: rejected player %d (name: %q)', player_id, raw_name), 12)
    end
end

function OnScriptUnload()
    BANNED_SET = {}
end
