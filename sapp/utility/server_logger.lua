--[[
=====================================================================================
SCRIPT NAME:    server_logger.lua
DESCRIPTION:    Advanced server logging system that replaces SAPP's default logs.
                Tracks player activity, game events, and admin commands with
                customizable verbosity.

LAST UPDATED:   18 Nov 2026

Copyright (c) 2024-2026 Jericho Crosby (Chalwk)
LICENSE:        MIT License
                https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

-- CONFIG START
local CONFIG = {

    -- See `#Console Colors` for a list of color names and their corresponding numbers.
    -- https://chalwk.github.io/halo/sapp/guide/#console-colors

    CONSOLE_COLORS = {
        black = 0,
        dark_blue = 1,
        dark_green = 2,
        dark_aqua = 3,
        dark_red = 4,
        dark_purple = 5,
        dark_yellow = 6,
        light_gray = 7,
        gray = 8,
        blue = 9,
        green = 10,
        aqua = 11,
        red = 12,
        light_purple = 13,
        yellow = 14,
        white = 15
    },

    --
    -- When false, nothing is sent to that output, whatever the per-event settings say.
    --
    CONSOLE = {
        enabled = true
    },

    --
    -- Log file settings
    --
    LOG = {
        enabled = true,
        file_name = 'server_log.txt',

        -- true = one file per day, e.g. server_log_2026-11-18.txt
        -- false = a single file, e.g. server_log.txt
        daily_files = false,

        -- Rotate the active file once it grows past this many KiB (0 = never rotate).
        -- The old file is renamed with a timestamp, e.g. server_log_20261118_140509.txt
        max_size_kb = 4096,

        -- Flush after every line so the file can be tailed live and survives a crash.
        flush = true
    },

    TIMESTAMP = {
        utc = true,

        -- Prefix on every log file line, e.g. "[Wed 18 Nov 2026 14:05:09] [JOIN] ..."
        format = '%a %d %b %Y %H:%M:%S',

        -- Prefix every console notification with the time, e.g. "[14:05:09] [JOIN] ..."
        console_prefix = false,
        console_prefix_format = '%H:%M:%S',

        -- Used in file names when LOG.daily_files is on, and for rotated archive names.
        file_date_format = '%Y-%m-%d',
        archive_format = '%Y%m%d_%H%M%S'
    },

    --
    -- Event type -> console color mapping
    --
    EVENT_COLORS = {
        OnLoad = 'green',
        OnScriptUnload = 'dark_red',
        OnStart = 'dark_green',
        OnEnd = 'dark_red',
        OnRoster = 'dark_green',
        OnJoin = 'green',
        OnLeave = 'red',
        OnSpawn = 'gray',
        OnTeamSwitch = 'dark_yellow',
        OnWarp = 'dark_purple',
        OnMapReset = 'white',
        OnLogin = 'aqua',
        OnSnap = 'light_purple',
        OnCommand = 'dark_aqua',
        OnChat = 'light_gray',
        OnScore = 'yellow',
        OnDie = 'dark_red'
    },

    --
    -- Event message templates | Format: { "Message", console?, file? }
    -- The same message is used for both outputs. Set console and/or file to false to silence an event there.
    --
    EVENTS = {
        OnLoad = { "[LOGGER] Logging started | Server: $serverName | Halo $halo", false, true },
        OnScriptUnload = { "[LOGGER] Logging stopped", false, true },
        OnStart = { "[START] New game on $map - $mode | $gt | $ffa | Players: $total/16", true, true },
        OnEnd = { "[END] Game ended on $map - $mode | Players: $total/16", true, true },

        -- Logged for every player already connected when a game starts (or when this script loads
        -- mid-game). Those players did not just join, so they get their own tag.
        OnRoster = {
            "[ROSTER] $name ($id) | IP: $ip | Hash: $hash | Pirated: $pirated | Players: $total/16",
            false,
            false
        },

        OnJoin = { "[JOIN] $name ($id) | IP: $ip | Hash: $hash | Pirated: $pirated | Players: $total/16", true, true },
        OnLeave = { "[QUIT] $name ($id) | IP: $ip | Hash: $hash | Pirated: $pirated | Players: $total/16", true, true },
        OnSpawn = { "[SPAWN] $name spawned", false, false },
        OnTeamSwitch = { "[SWITCH] $name switched to $team", false, true },
        OnWarp = { "[WARP] $name warped", false, true },
        OnMapReset = { "[RESET] Map reset: $map / $mode", false, true },
        OnLogin = { "[LOGIN] $name ($id) logged in | Level: $lvl", false, true },
        OnSnap = { "[SNAP] $name ($id) snapped", true, true },
        OnCommand = { "[$type CMD] $name ($id): $cmd", true, true },
        OnChat = { "[$type MSG] $name ($id): $msg", true, true },

        -- Score Type: 1 = CTF, 2 = Team Race, 3 = FFA Race, 4 = Team Slayer,
        --             5 = FFA Slayer, 6 = Oddball, 7 = King of the Hill
        OnScore = {
            [1] = {
                "[CTF SCORE] $name | $team team | Reds: $redScore Blues: $blueScore | Limit: $scorelimit",
                false,
                true
            },
            [2] = {
                "[TEAM RACE SCORE] $name | $team team | $lap_time | Team Laps: $totalTeamLaps/$scorelimit",
                false,
                true
            },
            [3] = { "[FFA RACE SCORE] $name | Lap: $lap_time | Laps: $score/$scorelimit", false, true },
            [4] = {
                "[TEAM SLAYER SCORE] $name | $team team | Reds: $redScore | Blues: $blueScore | Limit: $scorelimit",
                false,
                true
            },
            [5] = { "[FFA SCORE] $name | $score/$scorelimit", false, true },
            [6] = { "[ODDBALL SCORE] $name | $score/$scorelimit", false, true },
            [7] = { "[KOTH SCORE] $name | $score/$scorelimit", false, true }
        },

        -- Death Type:  1 = first blood,    2 = from the grave,     3 = run over,
        --              4 = killed,         5 = suicide,            6 = betrayed,
        --              7 = squashed,       8 = fall,               9 = server,
        --              10 = died
        OnDie = {
            [1] = { "[DEATH] $killerName drew first blood on $victimName", true, true },
            [2] = { "[DEATH] $victimName was killed from the grave by $killerName", true, true },
            [3] = { "[DEATH] $victimName was run over by $killerName", true, true },
            [4] = { "[DEATH] $victimName was killed by $killerName", true, true },
            [5] = { "[DEATH] $victimName committed suicide", true, true },
            [6] = { "[DEATH] $victimName was betrayed by $killerName", true, true },
            [7] = { "[DEATH] $victimName was squashed by a vehicle", true, true },
            [8] = { "[DEATH] $victimName fell to their death", true, true },
            [9] = { "[DEATH] $victimName was killed by the server", true, true },
            [10] = { "[DEATH] $victimName died", true, true }
        }
    },

    -- Commands whose arguments are replaced with COMMAND_MASK in the OnCommand output.
    -- Keep this in sync with anything on your server that takes a password.
    SENSITIVE_COMMANDS = {
        login = true,
        change_password = true,
        admin_add = true,
        admin_add_manually = true,
        admin_change_pw = true,
        sv_password = true,
        sv_rcon_password = true
    },
    COMMAND_MASK = '********',

    -- Known CD-key hashes from pirated/cracked Halo copies.
    -- Used to flag players with "$pirated = YES".
    KNOWN_PIRATED_HASHES = {
        ['388e89e69b4cc08b3441f25959f74103'] = true,
        ['81f9c914b3402c2702a12dc1405247ee'] = true,
        ['c939c09426f69c4843ff75ae704bf426'] = true,
        ['13dbf72b3c21c5235c47e405dd6e092d'] = true,
        ['29a29f3659a221351ed3d6f8355b2200'] = true,
        ['d72b3f33bfb7266a8d0f13b37c62fddb'] = true,
        ['76b9b8db9ae6b6cacdd59770a18fc1d5'] = true,
        ['55d368354b5021e7dd5d3d1525a4ab82'] = true,
        ['d41d8cd98f00b204e9800998ecf8427e'] = true,
        ['c702226e783ea7e091c0bb44c2d0ec64'] = true,
        ['f443106bd82fd6f3c22ba2df7c5e4094'] = true,
        ['10440b462f6cbc3160c6280c2734f184'] = true,
        ['3d5cd27b3fa487b040043273fa00f51b'] = true,
        ['b661a51d4ccf44f5da2869b0055563cb'] = true,
        ['740da6bafb23c2fbdc5140b5d320edb1'] = true,
        ['7503dad2a08026fc4b6cfb32a940cfe0'] = true,
        ['4486253cba68da6786359e7ff2c7b467'] = true,
        ['f1d7c0018e1648d7d48f257dc35e9660'] = true,
        ['40da66d41e9c79172a84eef745739521'] = true,
        ['2863ab7e0e7371f9a6b3f0440c06c560'] = true,
        ['34146dc35d583f2b34693a83469fac2a'] = true,
        ['b315d022891afedf2e6bc7e5aaf2d357'] = true,
        ['63bf3d5a51b292cd0702135f6f566bd1'] = true,
        ['6891d0a75336a75f9d03bb5e51a53095'] = true,
        ['325a53c37324e4adb484d7a9c6741314'] = true,
        ['0e3c41078d06f7f502e4bb5bd886772a'] = true,
        ['fc65cda372eeb75fc1a2e7d19e91a86f'] = true,
        ['f35309a653ae6243dab90c203fa50000'] = true,
        ['50bbef5ebf4e0393016d129a545bd09d'] = true,
        ['a77ee0be91bd38a0635b65991bc4b686'] = true,
        ['3126fab3615a94119d5fe9eead1e88c1'] = true
    },

    --
    -- Logo. Each line is { text, console color }.
    --
    LOGO = {
        -- console: shown once when the script loads
        console = true,
        file = false,
        lines = {
            { "================================================================================", 'dark_green' },
            { "$timeStamp", 'dark_yellow' },
            { "", 'black' },
            { "     '||'  '||'     |     '||'       ..|''||           ..|'''.| '||''''|  ", 'dark_red' },
            { "      ||    ||     |||     ||       .|'    ||        .|'     '   ||  .    ", 'dark_red' },
            { "      ||''''||    |  ||    ||       ||      ||       ||          ||''|    ", 'dark_red' },
            { "      ||    ||   .''''|.   ||       '|.     ||       '|.      .  ||       ", 'dark_red' },
            { "     .||.  .||. .|.  .||. .||.....|  ''|...|'         ''|....'  .||.....| ", 'dark_red' },
            { "               ->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-", 'gray' },
            { "                                      $serverName", 'dark_green' },
            { "               ->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-", 'gray' },
            { "", 'black' },
            { "================================================================================", 'dark_green' }
        }
    }
}
-- CONFIG ENDS

---@class LoggerPlayer
---@field id          number  Player Index
---@field name        string  Player Name
---@field ip          string  Player IP
---@field hash        string  Player Hash
---@field team        string  Player team
---@field last_damage number  Tag id of the most recent damage taken, 0 after a spawn
---@field switched    boolean True when a team switch is what killed the player

---@type table<number, LoggerPlayer | nil>
local players = {}

local ticks_per_second = 30
local lap_ticks_offset = 0xC4

local gametype_base, network_struct
local gametype, mode, map
local ffa, falling, distance
local first_blood = false

-- Log file state
local log_directory = nil
local log_file, log_path, log_bytes = nil, nil, 0
local has_opened_before, rotation_failed, failed_path = false, false, nil

local command_names = { [0] = 'CONSOLE', [1] = 'RCON', [2] = 'CHAT' }
local chat_names = { [0] = 'GLOBAL', [1] = 'TEAM', [2] = 'VEHICLE' }
local score_types = { ctf = 1, oddball = 6, king = 7 }

local os_date, os_rename = os.date, os.rename
local io_open, pcall, tonumber, tostring, ipairs, type = io.open, pcall, tonumber, tostring, ipairs, type
local string_format, string_char, table_concat = string.format, string.char, table.concat
local math_floor = math.floor
local read_byte, read_word, read_dword, read_string = read_byte, read_word, read_dword, read_string
local get_var, get_player, get_dynamic_player = get_var, get_player, get_dynamic_player
local player_present, player_alive, lookup_tag, cprint = player_present, player_alive, lookup_tag, cprint

local COLORS, EVENT_COLORS = CONFIG.CONSOLE_COLORS, CONFIG.EVENT_COLORS
local CONSOLE, LOG, EVENTS = CONFIG.CONSOLE, CONFIG.LOG, CONFIG.EVENTS
local TIMESTAMP, LOGO = CONFIG.TIMESTAMP, CONFIG.LOGO
local PIRATED = CONFIG.KNOWN_PIRATED_HASHES
local SENSITIVE, COMMAND_MASK = CONFIG.SENSITIVE_COMMANDS, CONFIG.COMMAND_MASK

-- Returns the pointer at sig_scan(pattern) + offset, or fallback if the scan fails
-- or the value falls outside Halo's data range.
---@param pattern  string       Signature to scan for.
---@param offset   number       Offset from the match to the pointer.
---@param fallback number | nil Hardcoded address used when the scan fails (nil = no fallback).
---@return number | nil address
local function safeSigScan(pattern, offset, fallback)
    local hit = sig_scan(pattern)
    if hit == 0 then return fallback end

    local value = read_dword(hit + offset)
    if type(value) ~= 'number' then return fallback end
    if value < 0x400000 or value > 0x800000 then return fallback end
    return value
end

---@param color string | number | nil Color name from CONSOLE_COLORS, a raw color number, or nil.
---@return number color_number
local function getColor(color)
    if type(color) == 'number' then return color end
    if type(color) ~= 'string' then return COLORS.white end
    return COLORS[color] or COLORS.white
end

---@param message string
local function reportError(message)
    cprint('[server_logger] ' .. tostring(message), COLORS.red)
end

-- Reads a UTF-16LE string. Stops at the first null code unit.
---@param address   number Memory address of the string.
---@param max_chars number Maximum number of characters to read.
---@return string value
local function readWideString(address, max_chars)
    local chars = {}
    for i = 0, (max_chars - 1) * 2, 2 do
        local lo = read_byte(address + i)
        if lo == 0 then break end
        chars[#chars + 1] = string_char(math_floor(lo))
    end
    return table_concat(chars)
end

---@return string server_name
local function getServerName()
    if not network_struct then return '' end
    return readWideString(network_struct + 0x8, 0x42)
end

-- Replaces $tokens in the template. Unknown tokens are left as they are.
---@param template string
---@param args     table<string, any>
---@return string message
local function formatMessageVars(template, args)
    return (template:gsub("%$[%w_]+", function (token)
        local value = args[token]
        return value ~= nil and tostring(value) or token
    end))
end

---@param format string os.date format string.
---@return string timestamp
local function getTimestamp(format)
    return os_date(TIMESTAMP.utc and '!' .. format or format)
end

-- Strips control characters so players cannot inject extra lines or odd bytes into the file.
---@param text any
---@return string clean
local function sanitize(text)
    return (tostring(text):gsub('%c', ''))
end

-- Builds the full path of the active log file, or of an archive when suffix is given.
---@param suffix string | nil Appended to the file name, e.g. "_20261118_140509".
---@return string path
local function buildPath(suffix)
    local name = LOG.file_name
    if LOG.daily_files then name = name .. '_' .. getTimestamp(TIMESTAMP.file_date_format) end
    return log_directory .. name .. (suffix or '')
end

local function closeLog()
    if log_file then pcall(log_file.close, log_file) end
    log_file, log_path, log_bytes = nil, nil, 0
end

---@param path string
---@return boolean opened
local function openLog(path)
    local file, err = io_open(path, 'a')
    if not file then
        -- Report once per path so a bad folder does not spam the console on every event.
        if failed_path ~= path then
            failed_path = path
            reportError('Cannot open log file "' .. path .. '": ' .. tostring(err))
        end
        return false
    end

    failed_path = nil
    log_file, log_path = file, path
    log_bytes = file:seek('end') or 0
    return true
end

-- Renames the active file to a timestamped archive once it passes the size limit.
local function rotateIfNeeded()
    local max_bytes = (tonumber(LOG.max_size_kb) or 0) * 1024
    if max_bytes <= 0 or rotation_failed or log_bytes < max_bytes then return end

    local path = log_path
    closeLog()

    local archive = buildPath('_' .. getTimestamp(TIMESTAMP.archive_format))
    local ok, renamed = false, nil
    if os_rename then ok, renamed = pcall(os_rename, path, archive) end

    -- If the rename is not possible, stop trying and keep appending to the same file.
    if not ok or not renamed then
        rotation_failed = true
        reportError('Log rotation failed, the log will keep growing: ' .. path)
    end
end

---@param line string
---@return boolean written
local function writeLine(line)
    local path = buildPath()

    -- The date rolled over (daily files) or the file was rotated: switch files.
    if log_file and path ~= log_path then closeLog() end

    if not log_file then
        if not openLog(path) then return false end
        if has_opened_before then
            pcall(log_file.write, log_file, '-- Log continued --\n')
        end
        has_opened_before = true
    end

    local ok, result = pcall(log_file.write, log_file, line, '\n')
    if not ok or not result then
        closeLog()
        reportError('Failed to write to log file: ' .. path)
        return false
    end

    log_bytes = log_bytes + #line + 1
    if LOG.flush then pcall(log_file.flush, log_file) end

    rotateIfNeeded()
    return true
end

---@param event_name string       Key in CONFIG.EVENTS.
---@param event_type number | nil Sub-type for events that have several templates.
---@return table | nil entry { template, log }
local function getEvent(event_name, event_type)
    local event = EVENTS[event_name]
    if not event then return nil end
    if event_type then return event[event_type] end
    return event
end

---@param event_name string             Key in CONFIG.EVENTS.
---@param args       table<string, any> Placeholder values. `event_type` selects the template.
local function log(event_name, args)
    args = args or {}

    local event = getEvent(event_name, args.event_type)
    if not event or type(event[1]) ~= 'string' then return end

    local to_console = CONSOLE.enabled and event[2]
    local to_file = LOG.enabled and event[3]
    if not to_console and not to_file then return end

    local message = formatMessageVars(event[1], args)

    if to_console then
        local line = message
        if TIMESTAMP.console_prefix then
            line = string_format('[%s] %s', getTimestamp(TIMESTAMP.console_prefix_format), message)
        end
        cprint(line, getColor(EVENT_COLORS[event_name]))
    end

    if to_file then
        writeLine(string_format('[%s] %s', getTimestamp(TIMESTAMP.format), message))
    end
end

---@param to_console boolean Print the logo to the console (if LOGO.console and CONSOLE.enabled allow it).
---@param to_file    boolean Write the logo to the file (if LOGO.file and LOG.enabled allow it).
local function displayLogo(to_console, to_file)
    to_console = to_console and LOGO.console and CONSOLE.enabled
    to_file = to_file and LOGO.file and LOG.enabled
    if not to_console and not to_file then return end

    local args = { ["$timeStamp"] = getTimestamp(TIMESTAMP.format), ["$serverName"] = getServerName() }

    for _, line in ipairs(LOGO.lines) do
        local text = formatMessageVars(line[1], args)
        if to_console then cprint(text, getColor(line[2])) end
        if to_file then writeLine(text) end
    end
end

function DisplayLogo()
    displayLogo(true, false)
end

---@param class string Tag class, e.g. "jpt!".
---@param name  string Tag path.
---@return number | nil tag_id Tag meta ID, or nil if the tag does not exist.
local function getTagId(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

---@return number score_limit
local function getScoreLimit()
    if not gametype_base then return 0 end
    return read_byte(gametype_base + 0x58)
end

---@return number total Players currently on the server.
local function getPlayerCount()
    return tonumber(get_var(0, '$pn')) or 0
end

---@return table<string, string | number | nil> args
local function getGameArgs()
    return {
        ["$map"] = map,
        ["$mode"] = mode,
        ["$gt"] = gametype,
        ["$ffa"] = ffa and 'FFA' or 'Team Play',
        ["$total"] = getPlayerCount()
    }
end

---@param hash string
---@return string answer "YES" or "NO"
local function isPirated(hash)
    return PIRATED[hash] and 'YES' or 'NO'
end

---@param id number Player index.
---@return number level Admin level, 0 if none.
local function getAdminLevel(id)
    return tonumber(get_var(id, '$lvl')) or 0
end

---@param player  LoggerPlayer
---@param leaving boolean | nil True during EVENT_LEAVE, when $pn has not dropped yet.
---@return table<string, string | number> args
local function getPlayerData(player, leaving)
    local total = getPlayerCount()
    if leaving then total = total - 1 end

    return {
        ["$total"] = total,
        ["$name"] = player.name,
        ["$ip"] = player.ip,
        ["$hash"] = player.hash,
        ["$id"] = player.id,
        ["$lvl"] = getAdminLevel(player.id),
        ["$ping"] = get_var(player.id, '$ping'),
        ["$pirated"] = isPirated(player.hash)
    }
end

---@param id       number Player index.
---@param name     string Variable name, e.g. "$ip".
---@param fallback string Returned when the variable is empty or "n/a".
---@return string value
local function safeGetVar(id, name, fallback)
    local value = get_var(id, name)
    return value ~= nil and value ~= 'n/a' and value ~= '' and value or fallback
end

---@param id number Player index.
---@return LoggerPlayer
local function newPlayer(id)
    return {
        id = id,
        last_damage = 0,
        switched = false,
        ip = safeGetVar(id, '$ip', 'unknown'),
        name = sanitize(safeGetVar(id, '$name', 'Unknown')),
        team = safeGetVar(id, '$team', 'FFA'),
        hash = safeGetVar(id, '$hash', '')
    }
end

---@param id number Player index.
---@return LoggerPlayer player
local function registerPlayer(id)
    players[id] = newPlayer(id)
    return players[id]
end

---@param ticks number Lap time in ticks.
---@return string lap_time MM:SS.mmm
local function formatLapTime(ticks)
    local ms = math_floor(ticks * 1000 / ticks_per_second + 0.5)
    local minutes = math_floor(ms / 60000)
    local seconds = math_floor((ms % 60000) / 1000)
    return string_format('%02d:%02d.%03d', minutes, seconds, ms % 1000)
end

---@param id number Player index.
---@return number ticks
local function readLapTicks(id)
    local static_player = get_player(id)
    if not static_player or static_player == 0 then return 0 end
    return read_word(static_player + lap_ticks_offset)
end

---@return number | nil score_type Index into CONFIG.EVENTS.OnScore, nil for unsupported gametypes.
local function getScoreType()
    if gametype == 'race' then return ffa and 3 or 2 end
    if gametype == 'slayer' then return ffa and 5 or 4 end
    return score_types[gametype]
end

-- Hides the arguments of commands listed in SENSITIVE_COMMANDS.
---@param command string
---@return string safe_command
local function maskCommand(command)
    local name = command:match('^%s*[\\/]*(%S+)')
    if name and SENSITIVE[name:lower()] and command:find('%S+%s+%S') then
        return name .. ' ' .. COMMAND_MASK
    end
    return command
end

---@param message string
---@return boolean is_command
local function isCommand(message)
    local first = message:sub(1, 1)
    return first == '/' or first == '\\'
end

---@param id number Player index.
---@return boolean in_vehicle
local function inVehicle(id)
    local dyn_player = get_dynamic_player(id)
    if not dyn_player or dyn_player == 0 then return false end
    return read_dword(dyn_player + 0x11C) ~= 0xFFFFFFFF
end

-- Used when the script loads mid-game, to decide whether first blood is already gone.
---@return boolean any_kills
local function hasAnyKills()
    for i = 1, 16 do
        if player_present(i) and (tonumber(get_var(i, '$kills')) or 0) > 0 then return true end
    end
    return false
end

---@return string | nil directory Instance CG directory (same location as mapcycle.txt)
local function getSappFolder()
    local ptr = safeSigScan('68??????008D54245468', 0x1)
    if not ptr then return nil end

    local base = read_string(ptr)
    if type(base) ~= 'string' or base == '' then return nil end

    return base:gsub('[\\/]+$', '') .. '\\sapp\\'
end

---@param script_load boolean True when the script loaded mid-game (no start event to log).
function OnStart(script_load)
    gametype = get_var(0, '$gt')
    if gametype == 'n/a' then return end

    players = {}
    ffa = get_var(0, '$ffa') == '1'
    mode, map = get_var(0, '$mode'), get_var(0, '$map')
    falling = getTagId('jpt!', 'globals\\falling')
    distance = getTagId('jpt!', 'globals\\distance')
    first_blood = not (script_load and hasAnyKills())

    if not script_load then log("OnStart", getGameArgs()) end

    for i = 1, 16 do
        if player_present(i) then
            log("OnRoster", getPlayerData(registerPlayer(i)))
        end
    end
end

function OnEnd()
    log("OnEnd", getGameArgs())
end

---@param player_id number
function OnJoin(player_id)
    log("OnJoin", getPlayerData(registerPlayer(player_id)))
end

---@param player_id number
function OnLeave(player_id)
    local player = players[player_id]
    if not player then return end

    log("OnLeave", getPlayerData(player, true))
    players[player_id] = nil
end

---@param player_id number
function OnSpawn(player_id)
    local player = players[player_id]
    if not player then return end

    player.last_damage, player.switched = 0, false
    log("OnSpawn", { ["$name"] = player.name })
end

---@param player_id number
function OnTeamSwitch(player_id)
    local player = players[player_id]
    if not player then return end

    player.team, player.switched = get_var(player_id, '$team'), true
    log("OnTeamSwitch", { ["$name"] = player.name, ["$team"] = player.team })
end

---@param player_id number
function OnWarp(player_id)
    local player = players[player_id]
    if player then log("OnWarp", { ["$name"] = player.name }) end
end

function OnMapReset()
    log("OnMapReset", getGameArgs())
end

---@param player_id number
function OnLogin(player_id)
    local player = players[player_id]
    if player then
        log("OnLogin", {
            ["$name"] = player.name,
            ["$id"] = player_id,
            ["$lvl"] = getAdminLevel(player_id)
        })
    end
end

---@param suspect_id number
function OnSnap(suspect_id)
    local player = players[suspect_id]
    if player then log("OnSnap", { ["$name"] = player.name, ["$id"] = suspect_id }) end
end

---@param executor_id number 0 for the console, otherwise a player index
---@param command     string
---@param environment number 0 = console, 1 = rcon, 2 = chat
---@return boolean allow
function OnCommand(executor_id, command, environment)
    local player = players[executor_id]

    log("OnCommand", {
        ["$lvl"] = player and getAdminLevel(executor_id) or 0,
        ["$name"] = player and player.name or (executor_id == 0 and 'SERVER' or 'Unknown'),
        ["$id"] = executor_id,
        ["$type"] = command_names[environment] or 'UNKNOWN',
        ["$cmd"] = maskCommand(sanitize(command))
    })

    return true
end

---@param player_id number
---@param message   string
---@param chat_type number 0 = global, 1 = team, 2 = vehicle
function OnChat(player_id, message, chat_type)
    local player = players[player_id]
    if not player or isCommand(message) then return end

    log("OnChat", {
        ["$type"] = chat_names[chat_type] or 'UNKNOWN',
        ["$name"] = player.name,
        ["$id"] = player_id,
        ["$msg"] = sanitize(message)
    })
end

---@param player_id number
function OnScore(player_id)
    local player = players[player_id]
    local score_type = getScoreType()
    if not player or not score_type then return end

    local red_score = get_var(0, '$redscore')
    local blue_score = get_var(0, '$bluescore')
    local lap_time = gametype == 'race' and formatLapTime(readLapTicks(player_id)) or formatLapTime(0)

    log("OnScore", {
        event_type = score_type,
        ["$lap_time"] = lap_time,
        ["$totalTeamLaps"] = player.team == 'red' and red_score or blue_score,
        ["$score"] = get_var(player_id, '$score'),
        ["$name"] = player.name,
        ["$team"] = player.team,
        ["$redScore"] = red_score,
        ["$blueScore"] = blue_score,
        ["$scorelimit"] = getScoreLimit()
    })
end

---@param victim_id     number
---@param _             number Causer index (unused).
---@param damage_tag_id number
function OnDamageApplication(victim_id, _, damage_tag_id)
    local victim = players[tonumber(victim_id)]
    if victim then victim.last_damage = damage_tag_id end
end

---@param victim_id number
---@param killer_id string "-1" = falling, server or distance damage, "0" = non-player source, "1+" = player index
function OnDie(victim_id, killer_id)
    local victim_index = tonumber(victim_id)
    local victim = players[victim_index]
    if not victim then return end

    local killer_index = tonumber(killer_id)
    local killer = killer_index and players[killer_index]
    local event_type = 10

    if killer_index == -1 and not victim.switched then
        local last = victim.last_damage
        event_type = (last == falling or last == distance) and 8 or 9
    elseif killer_index == 0 then
        event_type = 7
    elseif killer_index and killer_index > 0 then
        if killer_index == victim_index then
            event_type = 5
        elseif not ffa and killer and victim.team == killer.team then
            event_type = 6
        elseif first_blood then
            first_blood, event_type = false, 1
        elseif not player_alive(killer_index) then
            event_type = 2
        elseif inVehicle(killer_index) then
            event_type = 3
        else
            event_type = 4
        end
    end

    log("OnDie", {
        event_type = event_type,
        ["$killerName"] = killer and killer.name or 'Unknown',
        ["$victimName"] = victim.name
    })
end

---@param error_message string
function OnError(error_message)
    reportError('Lua error: ' .. tostring(error_message))
    if LOG.enabled then
        writeLine(string_format('[%s] [ERROR] Lua error: %s', getTimestamp(TIMESTAMP.format), sanitize(error_message)))
    end
end

function OnScriptLoad()
    gametype_base = safeSigScan("B9360000008BF3BF????????", 0x8, halo_type == 'PC' and 0x671320 or 0x5F5478)
    network_struct = safeSigScan(
        "F3ABA1????????BA????????C740??????????E8????????668B0D", 0x3, halo_type == 'PC' and 0x745B80 or 0x6C7960
    )

    log_directory = getSappFolder()
    if not log_directory then
        reportError('Could not resolve the sapp folder, file logging is disabled.')
        LOG.enabled = false
    end

    log("OnLoad", { ["$serverName"] = getServerName(), ["$halo"] = halo_type })
    timer(50, "DisplayLogo")

    register_callback(cb.EVENT_CHAT, 'OnChat')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_DAMAGE_APPLICATION, 'OnDamageApplication')
    register_callback(cb.EVENT_DIE, 'OnDie')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnLeave')
    register_callback(cb.EVENT_LOGIN, 'OnLogin')
    register_callback(cb.EVENT_MAP_RESET, 'OnMapReset')
    register_callback(cb.EVENT_SCORE, 'OnScore')
    register_callback(cb.EVENT_SNAP, 'OnSnap')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_TEAM_SWITCH, 'OnTeamSwitch')
    register_callback(cb.EVENT_WARP, 'OnWarp')

    OnStart(true) -- in case the script was loaded mid-game
end

function OnScriptUnload()
    log("OnScriptUnload")
    closeLog()
    players = {}
end
