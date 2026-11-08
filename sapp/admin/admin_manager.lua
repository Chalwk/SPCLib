--[[
=====================================================================================
SCRIPT NAME:      admin_manager.lua
DESCRIPTION:      A drop-in replacement for SAPP's built-in admin system.

                  Features:
                  - Custom admin levels (unlimited, hierarchical).
                  - Authentication by IP, hash, or username & password.
                  - IP/hash/text/name bans with optional durations and reasons.
                  - Command spy (see commands run by lower/equal level admins).
                  - Custom per-level join messages.
                  - Admin chat (private channel for admins).
                  - Alias lookup by IP or hash.

                  Passwords are hashed with a lightweight djb2-style hash. This is
                  NOT cryptographically secure, it just keeps plain text passwords
                  out of the admins file. Do not reuse passwords from anywhere else.

                  Databases (all plain text, auto-created in the sapp folder):
                  - admins.txt    (manual editing OK, restart required after)
                  - commands.txt  (manual editing OK, restart required after)
                  - bans.txt      (do not edit, use commands)
                  - aliases.txt   (do not edit, use commands)
                  - logs.txt      (do not edit, verbose admin activity log)

                  File format:
                  - Fields are separated by a single semicolon (;).
                  - Lists inside a field are separated by commas (,).
                  - Literal semicolons, commas, backslashes and newlines inside a
                    field are escaped with a backslash: \; \\ \n \r
                  - One record per line.

                  Commands and permissions:
                  -----------------------------------------------------------------------
                  | Command                | Description                        | Level |
                  -----------------------------------------------------------------------
                  | login                  | Login with a password              |   1   |
                  | logout                 | Logout of the server               |   1   |
                  | admin_chat             | Toggle admin chat on/off           |   2   |
                  | change_password        | Change your own password           |   2   |
                  | ip_mute                | Mute a player by IP                |   3   |
                  | ip_unmute              | Unmute a player's IP               |   3   |
                  | ip_mutes               | List all muted players by IP       |   3   |
                  | hash_mute              | Mute a player by hash              |   3   |
                  | hash_unmute            | Unmute a player's hash             |   3   |
                  | hash_mutes             | List all muted players by hash     |   3   |
                  | command_spy            | Toggle command spy on/off          |   3   |
                  | alias_ip               | Lookup aliases by player id or ip  |   4   |
                  | alias_hash             | Lookup aliases by player id or hash|   4   |
                  | ip_ban                 | Ban a player by IP                 |   4   |
                  | ip_unban               | Unban a player's IP                |   4   |
                  | ip_bans                | List all IP-bans                   |   4   |
                  | hash_admin_add         | Add player as a hash-admin         |   5   |
                  | hash_admin_delete      | Remove player as a hash-admin      |   5   |
                  | hash_admins            | List all hash-admins               |   5   |
                  | ip_admin_add           | Add player as an ip-admin          |   5   |
                  | ip_admin_delete        | Remove player as an ip-admin       |   5   |
                  | ip_admins              | List all ip-admins                 |   5   |
                  | hash_ban               | Ban a player by hash               |   5   |
                  | hash_unban             | Unban a player's hash              |   5   |
                  | hash_bans              | List all hash-bans                 |   5   |
                  | name_ban               | Ban a player's name by ID or name  |   5   |
                  | name_unban             | Unban a name                       |   5   |
                  | name_bans              | List all name bans                 |   5   |
                  | pw_admin_add           | Add player as a password-admin     |   5   |
                  | pw_admin_delete        | Remove player as a password-admin  |   5   |
                  | pw_admins              | List all password-admins           |   5   |
                  | confirm                | Confirm a pending action           |   5   |
                  | change_level           | Change a player's admin level      |   6   |
                  | change_admin_password  | Change another player's password   |   6   |
                  | level_add              | Add an admin level                 |   6   |
                  | level_delete           | Delete an admin level              |   6   |
                  | disable_command        | Disable a command                  |   6   |
                  | enable_command         | Enable a command                   |   6   |
                  | set_command            | Set a command to a new level       |   6   |
                  -----------------------------------------------------------------------

                  Getting started:
                  -----------------------------------------------------------------------
                  You must add yourself as an admin from the server terminal first.
                  Join the server, then run one of the admin-add commands from console.

                  Examples:
                  - /hash_admin_add 1 -l 6
                  - /hash_admin_add -u "the Juan" -l 5 -h 073949b8eb4c822cc71dbd3965009a2d
                  - /ip_admin_add 1 -l 6
                  - /ip_admin_add -u "daisy101" -l 2 -ip 127.0.0.5
                  - /pw_admin_add 1 -l 3 -p "my password"
                  - /pw_admin_add -u "thyme 2 die" -l 3 -p "cheap as chips"

                  Banning:
                  -----------------------------------------------------------------------
                  Ban by IP, hash, or text (name). Bans can be permanent or timed.
                  Duration flags (order doesn't matter, player id must come first):
                      -y <n>   years
                      -mo <n>  months
                      -d <n>   days
                      -h <n>   hours
                      -m <n>   minutes
                      -s <n>   seconds
                      -r "<reason>"

                  Examples:
                  - /hash_ban 1 -y 1 -mo 6 -r "caught cheating"
                  - /hash_ban 1                              (permanent)
                  - /ip_ban 1 -h 1 -m 30 -r "caught cheating"
                  - /ip_ban 1                                (permanent)
                  - /name_ban 1 -r "explicit name"
                  - /name_ban penis
                  - /ip_mute 1 -m 10 -r "spamming"
                  - /hash_mute 1 -d 5 -r "constant swearing"

                  Pirated hashes:
                  Shared CD-KEY hashes are detected automatically and cannot be
                  banned, as doing so would affect all players sharing that hash.

                  Default command permissions:
                  -----------------------------------------------------------------------
                  1: Public
                  2: Moderator
                  3: Admin
                  4: Senior Admin
                  5: Head Admin
                  6: Owner

                  Add custom levels in commands.txt or with level_add / level_delete.
                  There is no limit on the number of levels. Just keep at least one
                  level with the "1" key. A command set to true is enabled for that
                  level. Set to false to disable it for everyone except the console.

                  WARNING:
                  For this system to work, all players are given SAPP level 4.
                  In the rare event this script crashes, all players would have
                  unrestricted access to SAPP's commands. No known crashes currently,
                  just something worth noting.

                  INSTALLATION:
                  Drop admin_manager.lua into your server's Lua folder and load it.
                  Nothing else is needed. Databases are generated automatically in
                  the sapp folder next to the Lua folder.

                  CONFIGURATION:
                  Edit the `AdminManager` table at the top of this file.

Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

-- ============================================================================
-- SETTINGS
-- ============================================================================

local AdminManager = {
    -- Console runs at this level. Console bypasses most permission checks anyway.
    console_default_level = 6,

    -- Min and max length for user-chosen passwords.
    password_length_limit = { 8, 32 },

    -- Seconds before a pending /confirm action times out.
    confirmation_timeout = 10,

    -- Fallback ban duration when no flags are given. All zeros = permanent.
    default_ban_duration = {
        y = 0,
        mo = 0,
        d = 0,
        h = 0,
        m = 0,
        s = 0
    },

    -- Database filenames. All live in the sapp folder.
    files = {
        [1] = 'admins.txt',
        [2] = 'commands.txt',
        [3] = 'bans.txt',
        [4] = 'logs.txt',
        [5] = 'aliases.txt'
    },

    -- SAPP var used to expose a player's level to other scripts.
    custom_level_var = 'admin_level',

    -- management: admin actions and permission failures.
    -- default: every other command and its result.
    logging = {
        management = true,
        default = true
    },

    -- Join messages per level. Format string plus a show/hide flag.
    -- Disable the whole thing with enabled = false.
    admin_join_messages = {
        enabled = true,
        [1] = { '[PUBLIC] %s joined the server.', false },
        [2] = { '[ADMIN] %s just showed up. Hold my beer!', true },
        [3] = { '[MOD] %s just joined. Hide your bananas!', true },
        [4] = { '[VIP] %s joined the server. Sexy is as sexy does.', true },
        [5] = { '[PRO] %s joined the server. Pro noob.', true },
        [6] = { '[OWNER] %s joined the server. Everybody hide!', true }
    },

    -- Which levels can see other players' commands. True means visible.
    command_spy = {
        [1] = false,
        [2] = false,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true
    },

    -- Which levels can use admin chat. True means allowed.
    admin_chat = {
        [1] = false,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true
    },

    -- Default level required for each plugin command.
    -- Real permissions live in commands.txt, this is just the seed.
    management_commands = {
        ['1'] = {
            ['login'] = true,
            ['logout'] = true,
            ['my_level'] = true,
            ['admins_online'] = true
        },
        ['2'] = {
            ['admin_chat'] = true,
            ['change_password'] = true
        },
        ['3'] = {
            ['command_spy'] = true,
            ['ip_mute'] = true,
            ['ip_mutes'] = true,
            ['ip_unmute'] = true,
            ['hash_mute'] = true,
            ['hash_mutes'] = true,
            ['hash_unmute'] = true
        },
        ['4'] = {
            ['alias_ip'] = true,
            ['alias_hash'] = true,
            ['ip_ban'] = true,
            ['ip_bans'] = true,
            ['ip_unban'] = true
        },
        ['5'] = {
            ['confirm'] = true,
            ['hash_admin_add'] = true,
            ['hash_admin_delete'] = true,
            ['hash_admins'] = true,
            ['hash_ban'] = true,
            ['hash_bans'] = true,
            ['hash_unban'] = true,
            ['ip_admin_add'] = true,
            ['ip_admin_delete'] = true,
            ['ip_admins'] = true,
            ['name_ban'] = true,
            ['name_bans'] = true,
            ['name_unban'] = true,
            ['pw_admin_add'] = true,
            ['pw_admins'] = true,
            ['pw_admin_delete'] = true
        },
        ['6'] = {
            ['change_admin_password'] = true,
            ['level_add'] = true,
            ['level_delete'] = true,
            ['change_level'] = true,
            ['set_command'] = true,
            ['disable_command'] = true,
            ['enable_command'] = true,
            ['reload'] = true
        }
    },

    -- Default level required for every stock SAPP command.
    -- Written to commands.txt on first run, edit there afterwards.
    default_commands = {
        ['1'] = {
            ['login'] = true,
            ['logout'] = true,
            ['whatsnext'] = true,
            ['unstfu'] = true,
            ['stats'] = true,
            ['stfu'] = true,
            ['sv_stats'] = true,
            ['info'] = true,
            ['lead'] = true,
            ['clead'] = true
        },
        ['2'] = {
            ['kdr'] = true,
            ['mapcycle'] = true,
            ['pl'] = true,
            ['say'] = true
        },
        ['3'] = {
            ['afk'] = true,
            ['afks'] = true,
            ['skips'] = true,
            ['aimbot_scores'] = true,
            ['k'] = true
        },
        ['4'] = {
            ['ip'] = true,
            ['tell'] = true,
            ['uptime'] = true,
            ['balance_teams'] = true,
            ['st'] = true,
            ['inf'] = true
        },
        ['5'] = {
            ['map'] = true,
            ['maplist'] = true
        },
        ['6'] = {
            ['teamup'] = true,
            ['report'] = true,
            ['admin_prefix'] = true,
            ['usage'] = true,
            ['afk_kick'] = true,
            ['about'] = true,
            ['aimbot_ban'] = true,
            ['ammo'] = true,
            ['anticamp'] = true,
            ['anticaps'] = true,
            ['anticheat'] = true,
            ['antiglitch'] = true,
            ['antihalofp'] = true,
            ['antilagspawn'] = true,
            ['antispam'] = true,
            ['antiwar'] = true,
            ['area_add_cuboid'] = true,
            ['area_add_sphere'] = true,
            ['area_del'] = true,
            ['area_list'] = true,
            ['area_listall'] = true,
            ['assists'] = true,
            ['auto_update'] = true,
            ['ayy lmao'] = true,
            ['battery'] = true,
            ['beep'] = true,
            ['block_all_objects'] = true,
            ['block_all_vehicles'] = true,
            ['block_object'] = true,
            ['block_tc'] = true,
            ['boost'] = true,
            ['camo'] = true,
            ['cevent'] = true,
            ['chat_console_echo'] = true,
            ['cmd_add'] = true,
            ['cmd_del'] = true,
            ['cmdstart1'] = true,
            ['cmdstart2'] = true,
            ['color'] = true,
            ['console_input'] = true,
            ['coord'] = true,
            ['cpu'] = true,
            ['custom_sleep'] = true,
            ['d'] = true,
            ['deaths'] = true,
            ['debug_strings'] = true,
            ['disable_all_objects'] = true,
            ['disable_all_vehicles'] = true,
            ['disable_backtap'] = true,
            ['disable_object'] = true,
            ['disable_timer_offsets'] = true,
            ['disabled_objects'] = true,
            ['dns'] = true,
            ['enable_object'] = true,
            ['eventdel'] = true,
            ['events'] = true,
            ['files'] = true,
            ['gamespeed'] = true,
            ['god'] = true,
            ['gravity'] = true,
            ['hill_timer'] = true,
            ['hp'] = true,
            ['kill'] = true,
            ['kills'] = true,
            ['lag'] = true,
            ['loc_add'] = true,
            ['loc_del'] = true,
            ['loc_list'] = true,
            ['loc_listall'] = true,
            ['log'] = true,
            ['log_name'] = true,
            ['log_note'] = true,
            ['log_rotation'] = true,
            ['lua'] = true,
            ['lua_api_v'] = true,
            ['lua_call'] = true,
            ['lua_list'] = true,
            ['lua_load'] = true,
            ['lua_unload'] = true,
            ['m'] = true,
            ['mag'] = true,
            ['map_download'] = true,
            ['map_load'] = true,
            ['map_next'] = true,
            ['map_prev'] = true,
            ['map_query'] = true,
            ['map_skip'] = true,
            ['map_spec'] = true,
            ['mapcycle_add'] = true,
            ['mapcycle_begin'] = true,
            ['mapcycle_del'] = true,
            ['mapvote'] = true,
            ['mapvote_add'] = true,
            ['mapvote_begin'] = true,
            ['mapvote_del'] = true,
            ['mapvotes'] = true,
            ['max_idle'] = true,
            ['max_votes'] = true,
            ['motd'] = true,
            ['msg_prefix'] = true,
            ['mtv'] = true,
            ['nades'] = true,
            ['network_thread'] = true,
            ['no_lead'] = true,
            ['object_sync_cleanup'] = true,
            ['packet_limit'] = true,
            ['ping_kick'] = true,
            ['query_add'] = true,
            ['query_del'] = true,
            ['query_list'] = true,
            ['reload'] = true,
            ['reload_gametypes'] = true,
            ['remote_console'] = true,
            ['remote_console_list'] = true,
            ['remote_console_port'] = true,
            ['rprint'] = true,
            ['s'] = true,
            ['sapp_console'] = true,
            ['sapp_mapcycle'] = true,
            ['sapp_rcon'] = true,
            ['save_respawn_time'] = true,
            ['save_scores'] = true,
            ['say_prefix'] = true,
            ['score'] = true,
            ['scorelimit'] = true,
            ['scrim_mode'] = true,
            ['set_ccolor'] = true,
            ['setcmd'] = true,
            ['sh'] = true,
            ['sj_level'] = true,
            ['spawn'] = true,
            ['spawn_protection'] = true,
            ['t'] = true,
            ['team_score'] = true,
            ['text'] = true,
            ['timelimit'] = true,
            ['tp'] = true,
            ['unblock_object'] = true,
            ['ungod'] = true,
            ['unlag'] = true,
            ['unlock_console_log'] = true,
            ['v'] = true,
            ['var_add'] = true,
            ['var_conv'] = true,
            ['var_del'] = true,
            ['var_list'] = true,
            ['var_set'] = true,
            ['vdel'] = true,
            ['vdel_all'] = true,
            ['venter'] = true,
            ['vexit'] = true,
            ['wadd'] = true,
            ['wdel'] = true,
            ['wdrop'] = true,
            ['yeye'] = true,
            ['zombies'] = true
        }
    },

    -- Which method getIPFormat uses for the session key.
    -- 1 = raw $ip, 2 = strip the port off it.
    cache_session_index = 1,

    -- Hours a password-admin stays logged in before the session expires.
    login_timeout = 24
}

local _ceil = math.ceil
local _concat = table.concat
local _date = os.date
local _difftime = os.difftime
local _format = string.format
local _gsub = string.gsub
local _ipairs = ipairs
local _lower = string.lower
local _match = string.match
local _open = io.open
local _pairs = pairs
local _setmetatable = setmetatable
local _sort = table.sort
local _sub = string.sub
local _time = os.time
local _tonumber = tonumber
local _tostring = tostring
local _type = type

-- ============================================================================
-- PLAIN TEXT SERIALIZATION
--
-- I decided to drop JSON support entirely.
-- All database files are now plain text, one record per line.
-- Fields are separated by ';'. Lists within a field are comma-separated.
-- Literal metacharacters inside a field are backslash-escaped.
-- ============================================================================

-- Escape a value for inclusion in a text record.
local function esc(s)
    if s == nil then return '' end
    if _type(s) ~= 'string' then s = _tostring(s) end
    s = _gsub(s, '\\', '\\\\')
    s = _gsub(s, ';', '\\;')
    s = _gsub(s, '\n', '\\n')
    s = _gsub(s, '\r', '\\r')
    return s
end

-- Reverse of esc(). Returns '' for nil input.
local function unesc(s)
    if not s then return '' end
    local out = {}
    local i = 1
    local n = #s
    while i <= n do
        local c = _sub(s, i, i)
        if c == '\\' and i < n then
            local e = _sub(s, i + 1, i + 1)
            if e == 'n' then
                out[#out + 1] = '\n'
            elseif e == 'r' then
                out[#out + 1] = '\r'
            elseif e == ';' then
                out[#out + 1] = ';'
            elseif e == '\\' then
                out[#out + 1] = '\\'
            else
                out[#out + 1] = e
            end
            i = i + 2
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return _concat(out)
end

-- Split a line into unescaped fields by ';'.
local function split_fields(line)
    local fields = {}
    local chunk = {}
    local i = 1
    local n = #line
    while i <= n do
        local c = _sub(line, i, i)
        if c == '\\' and i < n then
            chunk[#chunk + 1] = c .. _sub(line, i + 1, i + 1)
            i = i + 2
        elseif c == ';' then
            fields[#fields + 1] = unesc(_concat(chunk))
            chunk = {}
            i = i + 1
        else
            chunk[#chunk + 1] = c
            i = i + 1
        end
    end
    fields[#fields + 1] = unesc(_concat(chunk))
    return fields
end

-- Split a comma-separated list, trimming empty entries.
local function split_list(s)
    local out = {}
    if not s or s == '' then return out end
    for item in s:gmatch('[^,]+') do
        out[#out + 1] = item
    end
    return out
end

-- Iterate over non-empty lines in a text blob.
local function iterate_lines(text)
    return text:gmatch('[^\r\n]+')
end

-- admins.txt: TYPE;KEY;NAME;LEVEL;PASSWORD;ID;ADDED_ON
local function serializeAdmins(admins)
    local lines = {}
    for _, admin_type in _ipairs({ 'hash_admins', 'ip_admins', 'password_admins' }) do
        local entries = admins[admin_type] or {}
        for key, v in _pairs(entries) do
            lines[#lines + 1] = _concat({
                esc(admin_type),
                esc(key),
                esc(v.name),
                esc(v.level),
                esc(v.password),
                esc(v.id),
                esc(v.added_on)
            }, ';')
        end
    end
    return _concat(lines, '\n')
end

local function deserializeAdmins(text)
    local admins = { hash_admins = {}, ip_admins = {}, password_admins = {} }
    if not text or text == '' then return admins end
    for line in iterate_lines(text) do
        local f = split_fields(line)
        local admin_type, key = f[1], f[2]
        if admin_type and key and key ~= '' and admins[admin_type] then
            admins[admin_type][key] = {
                name = (f[3] ~= '' and f[3] or nil),
                level = _tonumber(f[4]),
                password = (f[5] ~= '' and f[5] or nil),
                id = _tonumber(f[6]),
                added_on = (f[7] ~= '' and f[7] or nil)
            }
        end
    end
    return admins
end

-- commands.txt: LEVEL;enabled_cmd1,enabled_cmd2;disabled_cmd1,disabled_cmd2
local function serializeCommands(commands)
    local lines = {}
    local levels = {}
    for k in _pairs(commands) do levels[#levels + 1] = k end
    _sort(levels, function (a, b) return (_tonumber(a) or 0) < (_tonumber(b) or 0) end)

    for _, level in _ipairs(levels) do
        local enabled, disabled = {}, {}
        for name, on in _pairs(commands[level]) do
            if on then
                enabled[#enabled + 1] = name
            else
                disabled[#disabled + 1] = name
            end
        end
        _sort(enabled)
        _sort(disabled)
        lines[#lines + 1] = _concat({
            esc(level),
            esc(_concat(enabled, ',')),
            esc(_concat(disabled, ','))
        }, ';')
    end
    return _concat(lines, '\n')
end

local function deserializeCommands(text)
    local commands = {}
    if not text or text == '' then return commands end
    for line in iterate_lines(text) do
        local f = split_fields(line)
        local level = _tonumber(f[1])
        if level then
            commands[level] = commands[level] or {}
            for _, cmd in _ipairs(split_list(f[2])) do
                commands[level][cmd] = true
            end
            for _, cmd in _ipairs(split_list(f[3])) do
                commands[level][cmd] = false
            end
        end
    end
    return commands
end

-- bans.txt
--   ip;IP;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;OFFENDER_HASH;Y;MO;D;H;M;S
--   hash;HASH;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;OFFENDER_IP;Y;MO;D;H;M;S
--   name;NAME;ID;ADDED_BY;ADDED_ON;ADMIN_IP;ADMIN_HASH
--   mute_ip;IP;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;Y;MO;D;H;M;S
--   mute_hash;HASH;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;Y;MO;D;H;M;S
local function time_columns(v)
    local t = v.time
    if not t then return esc(nil), esc(nil), esc(nil), esc(nil), esc(nil), esc(nil) end
    return esc(t.year), esc(t.month), esc(t.day), esc(t.hour), esc(t.min), esc(t.sec)
end

local function serializeBans(bans)
    local lines = {}

    for key, v in _pairs(bans.ip or {}) do
        local y, mo, d, h, m, s = time_columns(v)
        lines[#lines + 1] = _concat({
            'ip',
            esc(key),
            esc(v.id),
            esc(v.offender),
            esc(v.added_by),
            esc(v.added_on),
            esc(v.reason),
            esc(v.hash),
            y, mo, d, h, m, s
        }, ';')
    end

    for key, v in _pairs(bans.hash or {}) do
        local y, mo, d, h, m, s = time_columns(v)
        lines[#lines + 1] = _concat({
            'hash',
            esc(key),
            esc(v.id),
            esc(v.offender),
            esc(v.added_by),
            esc(v.added_on),
            esc(v.reason),
            esc(v.ip),
            y, mo, d, h, m, s
        }, ';')
    end

    for key, v in _pairs(bans.name or {}) do
        lines[#lines + 1] = _concat({
            'name',
            esc(key),
            esc(v.id),
            esc(v.added_by),
            esc(v.added_on),
            esc(v.ip),
            esc(v.hash)
        }, ';')
    end

    for key, v in _pairs((bans.mute or {}).ip or {}) do
        local y, mo, d, h, m, s = time_columns(v)
        lines[#lines + 1] = _concat({
            'mute_ip',
            esc(key),
            esc(v.id),
            esc(v.offender),
            esc(v.added_by),
            esc(v.added_on),
            esc(v.reason),
            y, mo, d, h, m, s
        }, ';')
    end

    for key, v in _pairs((bans.mute or {}).hash or {}) do
        local y, mo, d, h, m, s = time_columns(v)
        lines[#lines + 1] = _concat({
            'mute_hash',
            esc(key),
            esc(v.id),
            esc(v.offender),
            esc(v.added_by),
            esc(v.added_on),
            esc(v.reason),
            y, mo, d, h, m, s
        }, ';')
    end

    return _concat(lines, '\n')
end

local function parse_time(f, base)
    return {
        year = _tonumber(f[base]) or 0,
        month = _tonumber(f[base + 1]) or 0,
        day = _tonumber(f[base + 2]) or 0,
        hour = _tonumber(f[base + 3]) or 0,
        min = _tonumber(f[base + 4]) or 0,
        sec = _tonumber(f[base + 5]) or 0
    }
end

local function deserializeBans(text)
    local bans = { ip = {}, hash = {}, name = {}, mute = { ip = {}, hash = {} } }
    if not text or text == '' then return bans end
    for line in iterate_lines(text) do
        local f = split_fields(line)
        local btype = f[1]
        if btype == 'ip' then
            bans.ip[f[2]] = {
                id = _tonumber(f[3]),
                offender = f[4],
                added_by = f[5],
                added_on = f[6],
                reason = f[7],
                hash = f[8],
                time = parse_time(f, 9)
            }
        elseif btype == 'hash' then
            bans.hash[f[2]] = {
                id = _tonumber(f[3]),
                offender = f[4],
                added_by = f[5],
                added_on = f[6],
                reason = f[7],
                ip = f[8],
                time = parse_time(f, 9)
            }
        elseif btype == 'name' then
            bans.name[f[2]] = {
                name = f[2],
                id = _tonumber(f[3]),
                added_by = f[4],
                added_on = f[5],
                ip = f[6],
                hash = f[7]
            }
        elseif btype == 'mute_ip' then
            bans.mute.ip[f[2]] = {
                id = _tonumber(f[3]),
                offender = f[4],
                added_by = f[5],
                added_on = f[6],
                reason = f[7],
                time = parse_time(f, 8)
            }
        elseif btype == 'mute_hash' then
            bans.mute.hash[f[2]] = {
                id = _tonumber(f[3]),
                offender = f[4],
                added_by = f[5],
                added_on = f[6],
                reason = f[7],
                time = parse_time(f, 8)
            }
        end
    end
    return bans
end

-- aliases.txt: PARENT;KEY;NAME;JOINED;LEVEL;LAST_ACTIVITY
local function serializeAliases(aliases)
    local lines = {}
    for parent, group in _pairs(aliases) do
        for key, names in _pairs(group) do
            for name, v in _pairs(names) do
                lines[#lines + 1] = _concat({
                    esc(parent),
                    esc(key),
                    esc(name),
                    esc(v.joined),
                    esc(v.level),
                    esc(v.last_activity)
                }, ';')
            end
        end
    end
    return _concat(lines, '\n')
end

local function deserializeAliases(text)
    local aliases = { IP_ALIASES = {}, HASH_ALIASES = {} }
    if not text or text == '' then return aliases end
    for line in iterate_lines(text) do
        local f = split_fields(line)
        local parent, key, name = f[1], f[2], f[3]
        if parent and key and name and aliases[parent] then
            aliases[parent][key] = aliases[parent][key] or {}
            aliases[parent][key][name] = {
                joined = (f[4] ~= '' and f[4] or nil),
                level = _tonumber(f[5]),
                last_activity = (f[6] ~= '' and f[6] or nil)
            }
        end
    end
    return aliases
end

-- logs.txt: DATE;ENTRY
-- Kept as an ordered list so multiple events in the same second don't collide.
local function serializeLogs(logs)
    local lines = {}
    for i = 1, #logs do
        lines[#lines + 1] = esc(logs[i][1]) .. ';' .. esc(logs[i][2])
    end
    return _concat(lines, '\n')
end

local function deserializeLogs(text)
    local logs = {}
    if not text or text == '' then return logs end
    for line in iterate_lines(text) do
        local f = split_fields(line)
        if f[1] and f[1] ~= '' then
            logs[#logs + 1] = { f[1], f[2] or '' }
        end
    end
    return logs
end

local function emptyAdmins()
    return { hash_admins = {}, ip_admins = {}, password_admins = {} }
end

local function emptyBans()
    return { ip = {}, hash = {}, name = {}, mute = { ip = {}, hash = {} } }
end

local function emptyAliases()
    return { IP_ALIASES = {}, HASH_ALIASES = {} }
end

local function simple_hash(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + str:byte(i)) % 4294967296
    end
    return _format('%08x', hash)
end

local M = {} -- method table; both AdminManager and player objects use this

M.flags = { ['-u'] = 'username', ['-p'] = 'password', ['-l'] = 'level', ['-ip'] = 'ip', ['-h'] = 'hash' }

function M:setAdminID(admin_table)
    local id = 0
    for _, entry in _pairs(admin_table) do
        if entry.id and entry.id > id then id = entry.id end
    end
    return id + 1
end

function M:hasPermission(level, command)
    local id = self.id
    local current_level = self.level or 1

    if id == 0 or current_level >= level then return true end

    self:send('Insufficient Permission.')
    self:send('You must be level (' .. level .. ') or higher.')
    self:log(self.name
            .. ' is attempting to execute ('
            .. _tostring(command) .. ') but is not a high enough level (current level: '
            .. current_level .. ') (Required level: '
            .. level .. ')', self.logging.management)
    return false
end

function M:send(msg)
    if msg == nil or msg == '' then return end
    return (self.id == 0 and cprint(msg) or rprint(self.id, msg))
end

function M:getSimpleHash(raw_password)
    return simple_hash(raw_password)
end

function M:stringSplit(str)
    local t = {}
    for param in str:gmatch('([^%s]+)') do
        t[#t + 1] = param
    end
    return t
end

function M:adminChat(message)
    local name = self.name
    local their_level = self.level
    local players = self.players
    local levels = self.admin_chat

    for i, v in _pairs(players) do
        local level = v.level
        local console = (i == 0)
        local enabled = v.a_chat
        local show = (level >= their_level and levels[level])
        if enabled and not console and show then
            local output = self.management['admin_chat'].output
            v:send(_gsub(_gsub(output, '$name', name), '$message', message))
        end
    end
end

function M:commandSpy(msg)
    local name = self.name
    local their_level = self.level
    local players = self.players
    local levels = self.command_spy

    for i, v in _pairs(players) do
        local level = v.level
        local console = (i == 0)
        local enabled = v.spy
        local show = (level >= their_level and levels[level])
        if enabled and not console and show then
            local output = self.management['command_spy'].output
            v:send(_gsub(_gsub(output, '$name', name), '$message', msg))
        end
    end
end

function M:checkLevel()
    local levels = self.admin_chat
    if levels[self.level] then return true end

    local required = {}
    for i = 1, 20 do
        if levels[i] then
            required[#required + 1] = i
        end
    end
    return false, 'Required levels: ' .. _concat(required, ', ') .. '.'
end

function M:findCommand(command)
    for level, commands in _pairs(self.commands) do
        if commands[command] ~= nil then
            return level, commands[command]
        end
    end
    return nil
end

function M:getDate(log)
    return _date(log and '%Y/%m/%d %H:%M:%S' or '%Y/%m/%d at %I:%M %p (%z)')
end

function M:kick(reason)
    if reason then self:send(reason) end
    if self.id and self.id > 0 then
        execute_command('sv_kick ' .. self.id)
    end
end

function M:vipMessages()
    local vip = self.admin_join_messages
    local message_table = vip[self.level]

    if not vip.enabled or not message_table or not message_table[2] then return end

    local str = _format(message_table[1], self.name)
    for i, v in _pairs(self.players) do
        if i ~= 0 then
            v:send(str)
        end
    end
end

local function convert(table)
    local t = {}
    for _, v in _pairs(table) do
        t[#t + 1] = v
    end
    return t
end

function M:getPageResults(bans, page, number_to_show)
    local total_pages = _ceil(#bans / number_to_show)
    local start_index = (page - 1) * number_to_show + 1
    local end_index = start_index + number_to_show - 1

    if start_index > #bans then return false end
    if end_index > #bans then end_index = #bans end

    local results = {}
    for i = start_index, end_index do
        results[#results + 1] = bans[i]
    end
    return results, total_pages
end

function M:showBanList(bans, page, number_to_show, admin)
    local ban_table = convert(bans)
    local results, total_pages = self:getPageResults(ban_table, page, number_to_show)

    if not results or #results == 0 then return false end

    admin:send(_format(self.header, page, total_pages))
    for _, v in _pairs(results) do
        local id = v.id
        local offender = v.offender
        local time = v.time
        local pirated = v.pirated
        local result = self:banSTDOUT({
            id = id,
            offender_name = offender,
            expiration = time,
            pirated = pirated
        })
        admin:send(result)
    end
    return true
end

function M:showAdminList(type, page, number_to_show, admin)
    local admins = convert(self.admins[type])
    local results, total_pages = self:getPageResults(admins, page, number_to_show)

    if not results or #results == 0 then return false end

    admin:send(_format(self.header, page, total_pages))
    for _, v in _pairs(results) do
        admin:send(_format(self.output, v.id, v.name or 'N/A', v.level))
    end
    return true
end

function M:getAdminByID(admin_table, id)
    for type, v in _pairs(admin_table) do
        if v.id == id then
            return { type = type, id = v.id, ip = v.ip, hash = v.hash, name = v.name }
        end
    end
    self:send('Admin ID not found.')
    return nil
end

function M:showNameBans(page, number_to_show, admin)
    local names = convert(self.bans['name'])
    local results, total_pages = self:getPageResults(names, page, number_to_show)

    if not results or #results == 0 then return false end

    admin:send(_format(self.header, page, total_pages))
    for _, v in _pairs(results) do
        admin:send(_format(self.output, v.id, v.name))
    end
    return true
end

function M:showAliases(args)
    local page = args.page
    local group = args.type
    local admin = args.admin
    local header = args.header
    local target = args.target
    local number_to_show = args.number_to_show

    local t = self.aliases[group][target]
    if not t then return false end

    local aliases = {}
    for name, v in _pairs(t) do
        aliases[#aliases + 1] = { name = name, v = v }
    end

    local results, total_pages = self:getPageResults(aliases, page, number_to_show)
    if not results or #results == 0 then return false end

    admin:send(_format(header, target, page, total_pages))

    for i = 1, #results do
        local r = results[i]
        admin:send(_gsub(_gsub(_gsub(_gsub(
			self.output, '$name', r.name),
			'$level', _tostring(r.v.level or '?')),
			'$date_joined',r.v.joined or '?'),
			'$last_activity', r.v.last_activity or '?')
		)
    end
    return true
end

function M:newAlias(parent, child, name)
    local records = self.aliases
    local date = self:getDate(true)

    records[parent][child] = records[parent][child] or {}

    if not records[parent][child][name] then
        records[parent][child][name] = { joined = date }
    end

    records[parent][child][name].level = self.level
    records[parent][child][name].last_activity = date
end

function M:newAdmin(parent, child, admin, password, args)
    local name = (args and args.name) or self.name
    local level = (args and args.level) or self.level
    local date = self:getDate()
    password = password and self:getSimpleHash(password) or nil

    local admin_table = self.admins[parent]
    admin_table[child] = {
        password = password,
        name = name,
        level = level,
        added_on = 'Added on ' .. date .. ' by ' .. admin.name .. ' (' .. admin.ip .. ')',
        id = self:setAdminID(admin_table)
    }
    self:updateAdmins()
end

function M:deleteAdmin(admin_table, child)
    admin_table[child] = nil
    self:updateAdmins()
end

function M:getIPFormat(IP)
    local index = self.cache_session_index
    if index == 1 then
        return IP
    elseif index == 2 then
        return _match(IP, '%d+%.%d+%.%d+%.%d+')
    end
end

function M:setLoginTimeout()
    return _time() + (self.login_timeout * 60) * 60
end

-- Rejoin tokens that stringSplit broke apart, e.g. `"the` and `Juan"` become `the Juan`.
local function mergeQuotedTokens(args, start)
    local out = {}
    local i = start or 1
    while i <= #args do
        local tok = args[i]
        if _sub(tok, 1, 1) == '"' and _sub(tok, -1) ~= '"' then
            local parts = { tok }
            local j = i + 1
            while j <= #args do
                parts[#parts + 1] = args[j]
                if _sub(args[j], -1) == '"' then break end
                j = j + 1
            end
            out[#out + 1] = _gsub(_gsub(_concat(parts, ' '), '^"', ''), '"$', '')
            i = j + 1
        else
            out[#out + 1] = _gsub(_gsub(tok, '^"', ''), '"$', '')
            i = i + 1
        end
    end
    return out
end

function M:adminSyntaxParser(args)
    local tokens = mergeQuotedTokens(args, 2)
    local parsed = {}
    local i = 1

    if tokens[i] and _tonumber(tokens[i]) then
        parsed.id = _tonumber(tokens[i])
        i = i + 1
    end

    while i <= #tokens do
        local key = self.flags[tokens[i]]
        if key and tokens[i + 1] then
            local v = tokens[i + 1]
            if key == 'level' then v = _tonumber(v) end
            parsed[key] = v
            i = i + 2
        else
            i = i + 1
        end
    end
    return parsed
end

-- ============================================================================
-- BAN SYSTEM
-- ============================================================================

local B = {}

B.parser = {
    ['-y'] = 'years',
    ['-mo'] = 'months',
    ['-d'] = 'days',
    ['-h'] = 'hours',
    ['-m'] = 'minutes',
    ['-s'] = 'seconds',
    ['-r'] = 'reason'
}

B.known_pirated_hashes = {
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
    ['3126fab3615a94119d5fe9eead1e88c1'] = true,
    ['2f02b641060da979e2b89abcfa1af3d6'] = true,
    ['ac73d9785215e196074d418d1cce825b'] = true,
    ['54f4d0236653a6da6429bfc79015f526'] = true
}

function B:banSyntaxParser(args)
    local tokens = mergeQuotedTokens(args, 2)
    local parsed = {}
    local i = 1

    -- Skip the leading player id if there is one.
    if tokens[i] and _tonumber(tokens[i]) then
        i = i + 1
    end

    while i <= #tokens do
        local key = self.parser[tokens[i]]
        if not key then
            i = i + 1
        elseif key == 'reason' then
            if not tokens[i + 1] then
                self:send('Missing value for flag: ' .. tokens[i])
                return false
            end
            local parts = { tokens[i + 1] }
            local j = i + 2
            while j <= #tokens and not self.parser[tokens[j]] do
                parts[#parts + 1] = tokens[j]
                j = j + 1
            end
            parsed.reason = _concat(parts, ' ')
            i = j
        else
            local value = tokens[i + 1]
            if not value then
                self:send('Missing value for flag: ' .. tokens[i])
                return false
            end
            local num = _tonumber(value)
            if not num then
                self:send('Invalid numeric value for flag ' .. tokens[i] .. ': ' .. value)
                return false
            end
            parsed[key] = num
            i = i + 2
        end
    end
    return parsed
end

function B:banSTDOUT(args)
    local id = args.id
    local pirated = args.pirated
    local admin_name = args.admin_name
    local offender_name = args.offender_name
    local reason = args.reason
    local expiration = args.expiration or { year = 0, month = 0, day = 0, hour = 0, min = 0, sec = 0 }

    local placeholders = {
        ['$id'] = id,
        ['$pirated'] = (pirated and 'Yes' or 'No'),
        ['$admin'] = admin_name,
        ['$offender'] = offender_name,
        ['$reason'] = reason,
        ['$years'] = expiration.year,
        ['$months'] = expiration.month,
        ['$days'] = expiration.day,
        ['$hours'] = expiration.hour,
        ['$minutes'] = expiration.min,
        ['$seconds'] = expiration.sec
    }

    local output = self.output
    for k, v in _pairs(placeholders) do
        output = _gsub(output, k, _tostring(v or ''))
    end
    return output
end

function B:newBan(args)
    return {
        added_on = self:getDate(),
        added_by = args.admin_name,
        offender = args.offender_name,
        ip = args.ip or nil,
        hash = args.hash or nil,
        reason = args.reason,
        time = args.time,
        id = self:setBanID(args.type)
    }
end

local function noTime(y, mo, d, h, m, s)
    return (y == 0 and mo == 0 and d == 0 and h == 0 and m == 0 and s == 0)
end

-- Round-trip through os.time so month/day overflow normalises correctly.
local function normalize_date(t)
    return _date(
        '*t',
        _time({
            year = t.year,
            month = t.month,
            day = t.day,
            hour = t.hour or 0,
            min = t.min or 0,
            sec = t.sec or 0
        })
    )
end

function B:generateExpiration(time)
    local y = time.years or 0
    local mo = time.months or 0
    local d = time.days or 0
    local h = time.hours or 0
    local m = time.minutes or 0
    local s = time.seconds or 0
    local default = self.default_ban_duration

    if noTime(y, mo, d, h, m, s) then
        y, mo, d, h, m, s = default.y, default.mo, default.d, default.h, default.m, default.s
    end

    if noTime(y, mo, d, h, m, s) then return nil end

    local now = _date('*t')
    now.year = now.year + y
    now.month = now.month + mo
    now.day = now.day + d
    now.hour = now.hour + h
    now.min = now.min + m
    now.sec = now.sec + s
    return normalize_date(now)
end

function B:setBanID(ban_table)
    local id = 0
    for _, entry in _pairs(ban_table) do
        if entry.id and entry.id > id then id = entry.id end
    end
    return id + 1
end

function B:getBanEntryByID(ban_table, id)
    for entry, v in _pairs(ban_table) do
        if v.id == id then return entry end
    end
    self:send('Ban ID not found.')
    return nil
end

function B:isMuted()
    local ip = self.ip
    local hash = self.hash
    local ip_muted = self.bans['mute']['ip'][ip]
    local hash_muted = self.bans['mute']['hash'][hash]
    return ip_muted or hash_muted
end

function B:setPirated(group, type, hash)
    local pirated = self.known_pirated_hashes
    local is_pirated = (hash and pirated[hash] and true or false) or nil
    if self.bans[group][type] then
        self.bans[group][type].pirated = is_pirated
    end
end

function B:hashBan(reason, time, admin)
    local hash_bans = self.bans['hash']
    local name, hash, ip = self.name, self.hash, self.ip
    hash_bans[hash] = self:newBan({
        admin_name = admin.name,
        offender_name = name,
        ip = ip,
        reason = reason,
        time = time,
        type = hash_bans
    })
    self:setPirated('hash', hash, hash)
    self:kick()
    self:updateBans()
end

function B:hashBanProceed(offender, parsed, admin)
    local reason = parsed.reason or 'No reason given.'
    local expiration = self:generateExpiration(parsed)

    offender:hashBan(reason, expiration, admin)
    local stdout = self:banSTDOUT({
        admin_name = admin.name,
        offender_name = offender.name,
        reason = reason,
        expiration = expiration
    })

    admin:send(stdout)
    self:log(stdout, self.logging.management)
end

function B:ipBan(reason, time, admin)
    local name, hash, ip = self.name, self.hash, self.ip
    local ip_bans = self.bans['ip']
    ip_bans[ip] = self:newBan({
        admin_name = admin.name,
        offender_name = name,
        hash = hash,
        reason = reason,
        time = time,
        type = ip_bans
    })
    self:setPirated('ip', ip, hash)
    self:kick()
    self:updateBans()
end

function B:nameBan(target)
    local name_to_ban = target
    local player = self.players[target]

    if _type(target) == 'number' then
        if not player then
            self:send('Player not found.')
            return
        end
        name_to_ban = player.name
        player:kick()
    elseif _type(target) == 'string' and #name_to_ban > 11 then
        self:send('Name too long. Max 11 characters.')
        return
    end

    local ip = self.ip
    local name = self.name
    local hash = self.hash
    local name_bans = self.bans['name']

    name_bans[name_to_ban] = {
        name = name_to_ban,
        added_by = name,
        added_on = self:getDate(),
        ip = ip,
        hash = hash,
        id = self:setBanID(name_bans)
    }

    self:send(_format('Added (%s) to the name-ban list.', name_to_ban))
    self:log(_format('%s name-banned (%s)', name, name_to_ban), self.logging.management)
    self:updateBans()
end

function B:mute(parent, child, reason, time, admin)
    local text_bans = self.bans['mute'][parent]
    text_bans[child] = self:newBan({
        admin_name = admin.name,
        offender_name = self.name,
        reason = reason,
        time = time,
        type = text_bans
    })
    self:updateBans()
end

function B:unban(args)
    local admin = args.admin
    local parent = args.parent
    local child = args.child
    local sub = args.sub

    local message = ''
    local entry = self.bans[parent][child]

    if sub and entry and entry[sub] then
        -- mute_ip / mute_hash entry.
        message = _format(self.output, entry[sub].offender or '?', sub)
        entry[sub] = nil
    else
        -- Direct ban entry. Fall back to the name field for name bans.
        local display = entry and (entry.offender or entry.name) or child
        message = _format(self.output, display, child)
        self.bans[parent][child] = nil
    end

    admin:send(message)
    self:updateBans()
end

local function isBanned(self, parent, child)
    if self.bans[parent][child] then
        self:kick()
        return true
    end
    return false
end

function B:rejectPlayer()
    if self.id == 0 then return false end

    local name = self.name
    local hash = self.hash
    local ip = self.ip
    local log = self.logging.management

    if isBanned(self, 'hash', hash) then
        self:log(_format('%s tried to join, but is hash-banned.', name), log)
        return true
    elseif isBanned(self, 'ip', ip) then
        self:log(_format('%s tried to join, but is ip-banned.', name), log)
        return true
    elseif isBanned(self, 'name', name) then
        self:log(_format('%s tried to join, but is name-banned.', name), log)
        return true
    elseif self:isMuted() then
        self:log(_format('%s joined and is muted.', name), log)
        return false
    end
    return false
end

for k, v in _pairs(B) do
    if _type(v) == 'function' then
        M[k] = v
    end
end
M.parser = B.parser
M.known_pirated_hashes = B.known_pirated_hashes

-- ============================================================================
-- FILE I/O
-- ============================================================================

local IO = {}

local function readFile(file)
    local f = _open(file, 'r')
    if f then
        local contents = f:read('*all')
        f:close()
        return contents or ''
    end
    return ''
end

local function writeFile(file, contents)
    if contents == nil then contents = '' end
    local f = _open(file, 'w')
    if f then
        f:write(contents)
        f:close()
    end
end

function IO:loadBans()
    local file = self.data_dir .. self.files[3]
    local contents = readFile(file)
    if contents ~= '' then
        self.bans = deserializeBans(contents)
    else
        self.bans = emptyBans()
    end
end

function IO:loadAliases()
    local file = self.data_dir .. self.files[5]
    local contents = readFile(file)
    if contents ~= '' then
        self.aliases = deserializeAliases(contents)
    else
        self.aliases = emptyAliases()
    end
end

function IO:setDefaultCommands()
    local file = self.data_dir .. self.files[2]
    local contents = readFile(file)
    local commands

    if contents ~= '' then
        commands = deserializeCommands(contents)
    end

    -- If file missing OR parsed to an empty table, seed from defaults.
    local needs_seed = true
    if commands then
        for _ in _pairs(commands) do
            needs_seed = false
            break
        end
    end

    if needs_seed then
        commands = {}
        for level_str, defs in _pairs(self.default_commands) do
            local lvl = _tonumber(level_str)
            if lvl then
                commands[lvl] = {}
                for name, on in _pairs(defs) do
                    commands[lvl][name] = on
                end
            end
        end
        writeFile(file, serializeCommands(commands))
    end

    -- Level 1 must always exist.
    if not commands[1] then commands[1] = {} end

    self.commands = commands
end

function IO:setAdmins()
    local file = self.data_dir .. self.files[1]
    local contents = readFile(file)

    if contents ~= '' then
        self.admins = deserializeAdmins(contents)
    else
        self.admins = emptyAdmins()
        writeFile(file, serializeAdmins(self.admins))
    end
end

function IO:updateAdmins()
    writeFile(self.data_dir .. self.files[1], serializeAdmins(self.admins))
end

function IO:updateCommands()
    writeFile(self.data_dir .. self.files[2], serializeCommands(self.commands))
end

function IO:updateBans()
    writeFile(self.data_dir .. self.files[3], serializeBans(self.bans))
end

function IO:updateAliases()
    if not self.players then return end

    local date = self:getDate(true)
    for i, v in _pairs(self.players) do
        if i ~= 0 then
            local ip = v.ip
            local name = v.name
            local hash = v.hash
            local level = v.level

            local ip_entry = self.aliases['IP_ALIASES'][ip] and self.aliases['IP_ALIASES'][ip][name]
            local hash_entry = self.aliases['HASH_ALIASES'][hash] and self.aliases['HASH_ALIASES'][hash][name]

            if ip_entry then
                ip_entry.level = level
                ip_entry.last_activity = date
            end
            if hash_entry then
                hash_entry.level = level
                hash_entry.last_activity = date
            end
        end
    end
    writeFile(self.data_dir .. self.files[5], serializeAliases(self.aliases))
end

function IO:log(entry, enabled)
    if enabled == false then return end
    local date = self:getDate(true)
    local file = self.data_dir .. self.files[4]
    local contents = readFile(file)
    local logs = (contents ~= '' and deserializeLogs(contents)) or {}
    logs[#logs + 1] = { date, entry }
    writeFile(file, serializeLogs(logs))
end

for k, v in _pairs(IO) do
    if _type(v) == 'function' then M[k] = v end
end

function M:registerLevelVariable()
    execute_command('var_add ' .. self.custom_level_var .. ' 4 0')
end

function M:unregisterLevelVariable()
    execute_command('var_del ' .. self.custom_level_var)
end

function M:setLevelVariable()
    execute_command('var_set ' .. self.custom_level_var .. ' ' .. (self.level or 1) .. ' ' .. self.id)
end

-- ============================================================================
-- COMMAND DEFINITIONS
-- ============================================================================

local commands = {}

local function def(name, desc, help, run_fn, extra)
    local cmd = { name = name, description = desc, help = help, run = run_fn }
    if extra then
        for k, v in _pairs(extra) do
            cmd[k] = v
        end
    end
    commands[_lower(name)] = cmd
end

def('login', 'Login as a password-admin.', 'Syntax: /$cmd <password>', function (self, id, args)
    local admin = self.players[id]
    if id == 0 then
        admin:send('Cannot execute this command from console.')
        return
    end
    if args[2] == 'help' then
        admin:send(self.description)
        return
    end

    local password = _concat(args, ' ', 2)
    if not password or password == '' then
        admin:send(self.help)
        return
    end
    if admin.level > 1 then
        admin:send('You are already logged in as ' .. admin.name .. ' (level ' .. admin.level .. ')')
        return
    end

    local stored_admin = self.admins.password_admins[admin.name]
    if stored_admin then
        local hashed_password = self:getSimpleHash(password)
        if stored_admin.password == hashed_password then
            admin.password_admin = true
            admin.level = stored_admin.level
            admin:setLevelVariable()
            self.login_session_cache[admin.socket] = self:setLoginTimeout()
            admin:send('Successfully logged in as ' .. admin.name .. ' (level ' .. admin.level .. ')')
            self:log(admin.name .. ' ('
				.. admin.ip .. ') logged in as '
				.. admin.name .. ' Level ('
				.. admin.level .. ')', self.logging.management)
        else
            admin:send('Incorrect username or password.')
        end
    else
        admin:send('Incorrect username or password.')
    end
end)

def('logout', 'Logout as a password-admin.', 'Syntax: /$cmd', function (self, id, args)
    local admin = self.players[id]
    if id == 0 then
        admin:send('Cannot execute this command from console.')
        return
    end
    if args[2] == 'help' then
        admin:send(self.description)
        return
    end
    if admin.level == 1 then
        admin:send('You are not logged in.')
        return
    end

    admin.level = 1
    admin.password_admin = nil
    admin:setLevelVariable()
    admin:send('Successfully logged out.')
    self:log(admin.name .. ' (' .. admin.ip .. ') logged out.', self.logging.management)
end)

def('my_level', 'Show your current admin level.', 'Syntax: /$cmd', function (self, id, args)
    local admin = self.players[id]
    if args[2] == 'help' then
        admin:send(self.description)
        return
    end
    admin:send('Your admin level is (' .. admin.level .. ').')
end)

def('admins_online', 'List all online admins.', 'Syntax: /$cmd', function (self, id, args)
    local admin = self.players[id]
    if args[2] == 'help' then
        admin:send(self.description)
        return
    end
    local found = {}
    for i, v in _pairs(self.players) do
        if i ~= 0 and v.level > 1 then
            found[#found + 1] = _format('[%d] %s (Level %d)', i, v.name, v.level)
        end
    end
    if #found == 0 then
        admin:send('No admins are currently online.')
        return
    end
    admin:send('Online admins:')
    for _, line in _ipairs(found) do
        admin:send(line)
    end
end)

def('admin_chat', 'Chat privately with other admins.', 'Syntax: /$cmd <1/0 (on/off)>',
	function (self, id, args)
		local admin = self.players[id]
		local toggle = _tonumber(args[2])
		local enabled = (toggle == 1)
		local allow, str = admin:checkLevel()

		if id == 0 then
			admin:send('You cannot execute this command from console.')
		elseif admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
				return
			elseif toggle == nil or (toggle ~= 0 and toggle ~= 1) then
				admin:send(self.help)
				return
			elseif not allow then
				admin:send('Insufficient Permission.')
				admin:send(str)
				return
			else
				admin:send('Admin Chat: ' .. (enabled and 'Enabled' or 'Disabled'))
			end
			admin.a_chat = enabled
		end
	end, { output = '[A-CHAT] $name: $message' }
)

def('command_spy', 'Toggle command spy on or off (spy on player commands).', 'Syntax: /$cmd <1/0 (on/off)>',
	function (self, id, args)
		local admin = self.players[id]
		local toggle = _tonumber(args[2])
		local enabled = (toggle == 1)
		local allow, str = admin:checkLevel()

		if id == 0 then
			admin:send('You cannot execute this command from console.')
		elseif admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
				return
			elseif toggle == nil or (toggle ~= 0 and toggle ~= 1) then
				admin:send(self.help)
				return
			elseif not allow then
				admin:send('Insufficient Permission.')
				admin:send(str)
				return
			else
				admin:send('Command Spy: ' .. (enabled and 'Enabled' or 'Disabled'))
			end
			admin.spy = enabled
		end
	end, { output = '[SPY] $name: $message' }
)

def('confirm', 'Confirm the deletion of an admin level.', 'Syntax: /$cmd', function (self, id, args)
    local admin = self.players[id]
    if admin:hasPermission(self.permission_level, args[1]) then
        if args[2] == 'help' then
            admin:send(self.description)
        elseif not admin.confirm then
            admin:send('You have nothing to confirm.')
        else
            local confirmation = admin.confirm
            if confirmation.level then
                local level = confirmation.level
                self.commands[level] = nil
                admin:send('Level (' .. level .. ') has been deleted.')
                self:updateCommands()
                self:log(admin.name .. ' ('
					.. admin.ip .. ') deleted level '
					.. level .. ' from ('
					.. self.files[2] .. ')', self.logging.management)
            end
            admin.confirm = nil
        end
    end
end)

def('change_password', 'Change your own password.', 'Syntax: /$cmd <"old password"> <"new password">', function (self, id, args)
    local admin = self.players[id]

    if admin:hasPermission(self.permission_level, args[1]) then
        if args[2] == 'help' then
            admin:send(self.description)
        elseif not args[2] then
            admin:send(self.help)
        else
            local tokens = mergeQuotedTokens(args, 2)
            local old_password = tokens[1]
            local new_password = tokens[2]
            if not old_password or old_password == '' then
                admin:send('You must specify the old password')
                return
            elseif not new_password or new_password == '' then
                admin:send('You must specify the new password')
                return
            end

            local min, max = self.password_length_limit[1], self.password_length_limit[2]
            if #new_password < min or #new_password > max then
                admin:send('Password must be ' .. min .. ' to ' .. max .. ' characters')
                return
            end

            local username = admin.name
            local admin_table = self.admins.password_admins[username]
            if admin_table then
                old_password = self:getSimpleHash(old_password)
                local new_password_hash = self:getSimpleHash(new_password)
                if old_password == new_password_hash then
                    admin:send('New password cannot be the same as the old password.')
                    return
                end
                admin_table.password = new_password_hash
                admin_table.date = 'Changed on ' .. self:getDate() .. ' by ' .. admin.name .. ' (' .. admin.ip .. ')'
                self:updateAdmins()
                admin:send('Password changed successfully.')
                self:log(
                    admin.name .. ' (' .. admin.ip .. ') changed ' .. username .. '\'s password.',
                    self.logging.management
                )
            else
                admin:send('Username (' .. username .. ') is not a registered admin name.')
            end
        end
    end
end)

def(
    'ip_mute', 'Flags: -y -mo -d -h -m -s -r "example reason"',
    'Syntax: /$cmd <player> <flags> | Type ($cmd help) for more information.',
    function (self, id, args)
        local offender = _tonumber(args[2])
        local admin = self.players[id]

        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not offender then
                admin:send(self.help)
            elseif not player_present(offender) then
                admin:send('Player #' .. offender .. ' is not online.')
            else
                local parsed = admin:banSyntaxParser(args)
                if parsed then
                    offender = self.players[offender]
                    local name = offender.name
                    local child = offender.ip
                    local reason = parsed.reason or 'No reason given.'
                    local expiration = self:generateExpiration(parsed)

                    offender:mute('ip', child, reason, expiration, admin)
                    local stdout = self:banSTDOUT({
                        admin_name = admin.name,
                        offender_name = name,
                        reason = reason,
                        expiration = expiration
                    })
                    admin:send(stdout)
                    self:log(stdout, self.logging.management)
                else
                    admin:send(self.help)
                end
            end
        end
    end,
	{
		output = '$admin IP-muted $offender until [$years/$months/$days - $hours:$minutes:$seconds] for reason: $reason'
    }
)

def(
    'ip_mutes', 'List all text-ban mutes by IP.', 'Syntax: /$cmd <page>',
    function (self, id, args)
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
                return
            end
            local page = _tonumber(args[2]) or 1
            local ip_mutes = self.bans['mute']['ip']
            local results = self:showBanList(ip_mutes, page, 5, admin)
            if not results then admin:send('There are no text-bans by IP.') end
            self:log(admin.name .. ' viewed the text-ban list by IP.', self.logging.management)
        end
    end,
    {
        header = '[Text-Bans (IP)] (Page: %s/%s)',
        output = '[$id] $offender [$years/$months/$days-$hours:$minutes:$seconds] [Pirated: $pirated]'
    }
)

def('ip_unmute', 'Unmute a player by IP. Use /ip_mutes to get the mute ID.', 'Syntax: /$cmd <ban id>',
	function (self, id, args)
		local admin = self.players[id]
		local ban_id = _tonumber(args[2])
		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			elseif not ban_id then
				admin:send(self.help)
			else
				local ip_mutes = self.bans['mute']['ip']
				local entry = admin:getBanEntryByID(ip_mutes, ban_id)
				if entry then
					self:unban({ admin = admin, parent = 'mute', child = 'ip', sub = entry })
				end
			end
		end
	end, { output = '(%s) (%s) unmuted.' }
)

def(
    'hash_mute', 'Flags: -y -mo -d -h -m -s -r "example reason"',
    'Syntax: /$cmd <player> <flags> | Type ($cmd help) for more information.',
    function (self, id, args)
        local offender = _tonumber(args[2])
        local admin = self.players[id]

        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not offender then
                admin:send(self.help)
            elseif not player_present(offender) then
                admin:send('Player #' .. offender .. ' is not online.')
            else
                local parsed = admin:banSyntaxParser(args)
                if parsed then
                    offender = self.players[offender]
                    local name = offender.name
                    local child = offender.hash
                    local reason = parsed.reason or 'No reason given.'
                    local expiration = self:generateExpiration(parsed)

                    offender:mute('hash', child, reason, expiration, admin)
                    local stdout = self:banSTDOUT({
                        admin_name = admin.name,
                        offender_name = name,
                        reason = reason,
                        expiration = expiration
                    })
                    admin:send(stdout)
                    self:log(stdout, self.logging.management)
                else
                    admin:send(self.help)
                end
            end
        end
    end,
    {
        output = '$admin hash-muted $offender until [$years/$months/$days - $hours:$minutes:$seconds] for reason: $reason'
    }
)

def(
    'hash_mutes', 'List all text-ban mutes by hash.', 'Syntax: /$cmd <page>',
    function (self, id, args)
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
                return
            end
            local page = _tonumber(args[2]) or 1
            local hash_mutes = self.bans['mute']['hash']
            local results = self:showBanList(hash_mutes, page, 5, admin)
            if not results then admin:send('There are no text-bans by Hash.') end
            self:log(admin.name .. ' viewed the text-ban list by hash.', self.logging.management)
        end
    end,
    {
        header = '[Text-Bans (hash)] (Page: %s/%s)',
        output = '[$id] $offender [$years/$months/$days-$hours:$minutes:$seconds] [Pirated: $pirated]'
    }
)

def('hash_unmute', 'Unmute a player by hash. Use /hash_mutes to get the mute ID.', 'Syntax: /$cmd <ban id>',
	function (self, id, args)
		local admin = self.players[id]
		local ban_id = _tonumber(args[2])
		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			elseif not ban_id then
				admin:send(self.help)
			else
				local hash_mutes = self.bans['mute']['hash']
				local entry = admin:getBanEntryByID(hash_mutes, ban_id)
				if entry then
					self:unban({ admin = admin, parent = 'mute', child = 'hash', sub = entry })
				end
			end
		end
	end, { output = '(%s) (%s) unmuted.' }
)

def('alias_ip', 'View a player\'s aliases by IP.', 'Syntax: /$cmd <player/ip> <page>',
	function (self, id, args)
		local admin = self.players[id]
		if admin:hasPermission(self.permission_level, args[1]) then
			local target = args[2]
			local page = _tonumber(args[3]) or 1
			local ip_pattern = '^%d+%.%d+%.%d+%.%d+$'

			if target == 'help' then
				admin:send(self.description)
				return
			elseif not target then
				admin:send(self.help)
				return
			end

			if _tonumber(target) then
				target = _tonumber(target)
				if not player_present(target) then
					admin:send('Player #' .. target .. ' is not online.')
					return
				end
				target = self.players[target].ip
			elseif not _match(target, ip_pattern) then
				admin:send('Invalid IP address or player ID.')
				return
			end

			if page < 1 then
				admin:send('Invalid page number. Must be 1 or higher.')
				return
			end

			local found = self:showAliases({
				target = target,
				page = page,
				admin = admin,
				header = self.header,
				type = 'IP_ALIASES',
				number_to_show = 10
			})
			if not found then
				admin:send('No aliases found for [' .. target .. '] on page ' .. page .. '.')
				return
			end
			self:log(admin.name .. ' viewed the IP alias list for [' .. target .. ']', self.logging.management)
		end
	end,
	{
		header = 'Aliases for [%s]: Page %d/%d',
		output = '$name  |  Level: [$level]'
	}
)

def('alias_hash', 'View a player\'s aliases by hash.', 'Syntax: /$cmd <player/ip> <page>',
	function (self, id, args)
		local admin = self.players[id]
		if admin:hasPermission(self.permission_level, args[1]) then
			local target = args[2]
			local page = _tonumber(args[3]) or 1
			local hash_pattern = '^' .. ('%x'):rep(32) .. '$'

			if target == 'help' then
				admin:send(self.description)
				return
			elseif not target then
				admin:send(self.help)
				return
			end

			if _tonumber(target) then
				target = _tonumber(target)
				if not player_present(target) then
					admin:send('Player #' .. target .. ' is not online.')
					return
				end
				target = self.players[target].hash
			elseif not _match(target, hash_pattern) then
				admin:send('Invalid hash or player ID.')
				return
			end

			if page < 1 then
				admin:send('Invalid page number. Must be 1 or higher.')
				return
			end

			local found = self:showAliases({
				target = target,
				page = page,
				admin = admin,
				header = self.header,
				type = 'HASH_ALIASES',
				number_to_show = 10
			})
			if not found then
				admin:send('No aliases found for [' .. target .. '] on page ' .. page .. '.')
				return
			elseif self.known_pirated_hashes[target] then
				admin:send('This CD-KEY hash is pirated.')
			end
			self:log(admin.name .. ' viewed the hash-alias list for [' .. target .. ']', self.logging.management)
		end
	end,
	{
		header = 'Aliases for [%s]: Page %d/%d',
		output = '$name  |  Level: [$level]'
	}
)

def(
    'ip_ban', 'Flags: -y -mo -d -h -m -s -r "example reason"',
    'Syntax: /$cmd <player> <flags> | Type ($cmd help) for more information.',
    function (self, id, args)
        local offender = _tonumber(args[2])
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not offender then
                admin:send(self.help)
            elseif not player_present(offender) then
                admin:send('Player #' .. offender .. ' is not online.')
            else
                local parsed = admin:banSyntaxParser(args)
                if parsed then
                    offender = self.players[offender]
                    local reason = parsed.reason or 'No reason given.'
                    local name = offender.name
                    local expiration = self:generateExpiration(parsed)
                    offender:ipBan(reason, expiration, admin)
                    local stdout = self:banSTDOUT({
                        admin_name = admin.name,
                        offender_name = name,
                        reason = reason,
                        expiration = expiration
                    })
                    admin:send(stdout)
                    self:log(stdout, self.logging.management)
                else
                    admin:send(self.help)
                end
            end
        end
    end,
    {
        output = '$admin ip-banned $offender until [$years/$months/$days - $hours:$minutes:$seconds] for reason: $reason'
    }
)

def(
    'ip_bans', 'List all IP-bans.', 'Syntax: /$cmd <page>',
    function (self, id, args)
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
                return
            end
            local page = _tonumber(args[2]) or 1
            local ip_bans = self.bans['ip']
            local results = self:showBanList(ip_bans, page, 5, admin)
            if not results then admin:send('There are no ip-bans.') end
            self:log(admin.name .. ' viewed the ip-ban list.', self.logging.management)
        end
    end,
    {
        header = '[IP-Bans] (Page: %s/%s)',
        output = '[$id] $offender [$years/$months/$days-$hours:$minutes:$seconds] [Pirated: $pirated]'
    }
)

def('ip_unban', 'Unban a player\'s IP. Use /ip_bans to get the ban ID.', 'Syntax: /$cmd <ban id>',
	function (self, id, args)
		local admin = self.players[id]
		local ban_id = _tonumber(args[2])
		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			elseif not ban_id then
				admin:send(self.help)
			else
				local ip_bans = self.bans['ip']
				local entry = admin:getBanEntryByID(ip_bans, ban_id)
				if entry then self:unban({ admin = admin, parent = 'ip', child = entry }) end
			end
		end
	end, { output = '(%s) (%s) unbanned.' }
)

def(
	'hash_admin_add',
	'Add a new hash-admin.',
	'Syntax: /$cmd <ID / -u "username"> <-l level> <-h hash>',
	function (self, id, args)
		local admin = self.players[id]
		local admins = self.admins

		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			else
				local pattern = '^[a-f0-9]+$'
				local parsed = self:adminSyntaxParser(args)
				local target
				local player_id = parsed.id
				local hash = parsed.hash
				local username = parsed.username
				local level = parsed.level

				if player_id then
					if not player_present(player_id) then
						admin:send('Player #' .. player_id .. ' is not present.')
						return
					end
					target = self.players[player_id]
					username = target.name
					hash = target.hash
				end

				if not username or not hash or not level then
					admin:send(self.help)
					return
				elseif #username > 11 then
					admin:send('Username must be 11 characters or less.')
					return
				elseif #hash ~= 32 then
					admin:send('Hash must be 32 characters long.')
					return
				elseif not _match(hash, pattern) then
					admin:send('Hash must be a valid MD5 hash.')
					return
				elseif not self.commands[level] then
					admin:send('Invalid level. Must be between 1 and ' .. #self.commands)
					return
				end

				local admin_table = admins.hash_admins[hash]
				if not admin_table then
					if target then
						target.level = level
						target:setLevelVariable()
						target:newAdmin('hash_admins', hash, admin)
					else
						self:newAdmin('hash_admins', hash, admin, _, { level = level, name = username })
					end
					admin:send('Added ' .. username .. ' to the hash-admin list. Level (' .. level .. ').')
					self:log(admin.name .. ' ('
						.. admin.ip .. ') added ('
						.. username .. ') to the hash-admin list. Level ('
						.. level .. ')', self.logging.management)
				else
					admin:send(username .. ' is already a hash-admin (level ' .. admin_table.level .. ')')
				end
			end
		end
	end
)

def(
    'hash_admin_delete',
    'Delete a hash-admin. Use /hash_admins to get the admin ID.',
    'Syntax: /$cmd <admin id>',
    function (self, id, args)
        local admin_id = _tonumber(args[2])
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not admin_id then
                admin:send(self.help)
            else
                local admins = self.admins['hash_admins']
                local entry = admin:getAdminByID(admins, admin_id)
                if entry then
                    self:deleteAdmin(admins, entry.type)
                    admin:send('Removed (' .. entry.type
						.. ') (' .. (entry.name or '?')
						.. ') from the hash-admin list.')
                    self:log(admin.name .. ' ('
						.. admin.ip .. ') removed ('
						.. entry.type .. ') ('
						.. (entry.name or '?') .. ') from the hash-admin list.', self.logging.management)
                end
            end
        end
    end
)

def('hash_admins', 'List all hash-admins.', 'Syntax: /$cmd <page>',
	function (self, id, args)
		local admin = self.players[id]
		if not admin:hasPermission(self.permission_level, args[1]) then return end
		if args[2] == 'help' then
			admin:send(self.description)
			return
		end
		local page = _tonumber(args[2]) or 1
		self.header = '[Hash-Admins] (Page: %s/%s)'
		local results = self:showAdminList('hash_admins', page, 5, admin)
		if not results then
			admin:send('There are no hash-admins.')
			return
		end
		self:log(admin.name .. ' viewed the hash-admin list.', self.logging.management)
	end, { output = '[%s] %s | Level: [%s]' }
)

def(
	'ip_admin_add',
	'Add a new IP-admin.',
	'Syntax: /$cmd <ID / -u "username"> <-l level> <-ip IP>',
	function (self, id, args)
		local admin = self.players[id]
		local admins = self.admins

		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			else
				local pattern = '(%d+%.%d+%.%d+%.%d+)'
				local parsed = self:adminSyntaxParser(args)
				local target
				local player_id = parsed.id
				local ip = parsed.ip
				local username = parsed.username
				local level = parsed.level

				if player_id then
					if not player_present(player_id) then
						admin:send('Player #' .. player_id .. ' is not present.')
						return
					end
					target = self.players[player_id]
					username = target.name
					ip = target.ip
				end

				if not username or not ip or not level then
					admin:send(self.help)
					return
				elseif #username > 11 then
					admin:send('Username must be 11 characters or less.')
					return
				elseif not _match(ip, pattern) then
					admin:send('IP address not valid.')
					return
				elseif not self.commands[level] then
					admin:send('Invalid level. Must be between 1 and ' .. #self.commands)
					return
				end

				local admin_table = admins.ip_admins[ip]
				if not admin_table then
					if target then
						target.level = level
						target:setLevelVariable()
						target:newAdmin('ip_admins', ip, admin)
					else
						self:newAdmin('ip_admins', ip, admin, _, { level = level, name = username })
					end
					admin:send('Added ' .. username .. ' to the IP-admin list. Level (' .. level .. ').')
					self:log(admin.name .. ' ('
						.. admin.ip .. ') added ('
						.. username .. ') to the IP-admin list. Level ('
						.. level .. ')', self.logging.management)
				else
					admin:send(username .. ' is already an IP-admin (level ' .. admin_table.level .. ')')
				end
			end
		end
	end
)

def(
    'ip_admin_delete',
    'Delete an IP-admin. Use /ip_admins to get the admin ID.',
    'Syntax: /$cmd <admin id>',
    function (self, id, args)
        local admin_id = _tonumber(args[2])
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not admin_id then
                admin:send(self.help)
            else
                local admins = self.admins['ip_admins']
                local entry = admin:getAdminByID(admins, admin_id)
                if entry then
                    self:deleteAdmin(admins, entry.type)
                    admin:send('Removed (' .. entry.type .. ') (' .. (entry.name or '?') .. ') from the IP-admin list.')
                    self:log(admin.name .. ' ('
						.. admin.ip .. ') removed ('
						.. entry.type .. ') ('
						.. (entry.name or '?') .. ') from the IP-admin list.', self.logging.management)
                end
            end
        end
    end
)

def('ip_admins', 'List all IP-admins.', 'Syntax: /$cmd <page>', function (self, id, args)
    local admin = self.players[id]
    if not admin:hasPermission(self.permission_level, args[1]) then return end
    if args[2] == 'help' then
        admin:send(self.description)
        return
    end
    local page = _tonumber(args[2]) or 1
    self.header = '[IP-Admins] (Page: %s/%s)'
    local results = self:showAdminList('ip_admins', page, 5, admin)
    if not results then
        admin:send('There are no ip-admins.')
        return
    end
    self:log(admin.name .. ' viewed the ip-admin list.', self.logging.management)
end, { output = '[%s] %s | Level: [%s]' }
)

def(
    'hash_ban', 'Flags: -y -mo -d -h -m -s -r "example reason"',
    'Syntax: /$cmd <player> <flags> | Type ($cmd help) for more information.',
    function (self, id, args)
        local offender = _tonumber(args[2])
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not offender then
                admin:send(self.help)
            elseif not player_present(offender) then
                admin:send('Player #' .. offender .. ' is not online.')
            else
                local parsed = admin:banSyntaxParser(args)
                if parsed then
                    offender = self.players[offender]
                    local hash = offender.hash
                    if self.known_pirated_hashes[hash] then
                        admin:send('[WARNING] ' .. offender.name .. ' is using a pirated copy of Halo.')
                        admin:send(
                            'Pirated hashes cannot be banned, as doing so would affect all players sharing that hash.'
                        )
                        return
                    end
                    self:hashBanProceed(offender, parsed, admin)
                else
                    admin:send(self.help)
                end
            end
        end
    end,
    {
        output = '$admin hash-banned $offender until [$years/$months/$days - $hours:$minutes:$seconds] for reason: $reason'
    }
)

def(
    'hash_bans', 'List all hash-bans.', 'Syntax: /$cmd <page>',
    function (self, id, args)
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
                return
            end
            local page = _tonumber(args[2]) or 1
            local hash_bans = self.bans['hash']
            local results = self:showBanList(hash_bans, page, 5, admin)
            if not results then admin:send('There are no hash-bans.') end
            self:log(admin.name .. ' viewed the hash-ban list.', self.logging.management)
        end
    end,
    {
        header = '[Hash-Bans] (Page: %s/%s)',
        output = '[$id] $offender [$years/$months/$days-$hours:$minutes:$seconds] [Pirated: $pirated]'
    }
)

def(
	'hash_unban',
	'Unban a player\'s hash. Use /hash_bans to get the ban ID.',
	'Syntax: /$cmd <ban id>',
	function (self, id, args)
		local admin = self.players[id]
		local ban_id = _tonumber(args[2])
		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			elseif not ban_id then
				admin:send(self.help)
			else
				local hash_bans = self.bans['hash']
				local entry = admin:getBanEntryByID(hash_bans, ban_id)
				if entry then
					self:unban({ admin = admin, parent = 'hash', child = entry })
				end
			end
		end
	end, { output = '(%s) (%s) unbanned.' }
)

def(
    'name_ban',
    'Block an unwanted name.',
    'Syntax: /$cmd <id> or /$cmd <name> | Type /$cmd help for more information.',
    function (self, id, args)
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            local target = args[2]
            if target == 'help' then
                admin:send(self.description)
                return
            end
            if not target then
                admin:send(self.help)
                return
            end
            local player_id = _tonumber(target)
            if player_id and not player_present(player_id) then
                admin:send('Player #' .. player_id .. ' is not online.')
                return
            end
            admin:nameBan(target)
            admin:send('Name ban successfully applied for: ' .. target)
        end
    end
)

def('name_bans', 'List all name-bans.', 'Syntax: /$cmd <page>',
	function (self, id, args)
		local admin = self.players[id]
		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
				return
			end
			local page = _tonumber(args[2]) or 1
			local results = self:showNameBans(page, 5, admin)
			if not results then admin:send('There are no name-bans.') end
			self:log(admin.name .. ' viewed the name-ban list.', self.logging.management)
		end
	end,
	{
		header = '[Name-Bans] (Page: %s/%s)',
		output = '[%s] %s'
	}
)

def('name_unban', 'Unban a name. Use /name_bans to view all name-bans.', 'Syntax: /$cmd <ban id>',
	function (self, id, args)
		local admin = self.players[id]
		local ban_id = _tonumber(args[2])
		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			elseif not ban_id then
				admin:send(self.help)
			else
				local name_bans = self.bans['name']
				local entry = admin:getBanEntryByID(name_bans, ban_id)
				if entry then
					self:unban({ admin = admin, parent = 'name', child = entry })
				end
			end
		end
	end, { output = 'Name (%s) has been unbanned.' }
)

def(
    'pw_admin_add',
    'Add a new username & password admin.',
    'Syntax: /$cmd <ID / -u "username"> <-l level> <-p "password">',
    function (self, id, args)
        local admins = self.admins
        local admin = self.players[id]
        local min, max = self.password_length_limit[1], self.password_length_limit[2]

        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            else
                local parsed = self:adminSyntaxParser(args)
                local target
                local player_id = parsed.id
                local username = parsed.username
                local level = parsed.level
                local password = parsed.password

                if player_id then
                    if not player_present(player_id) then
                        admin:send('Player #' .. player_id .. ' is not present.')
                        return
                    end
                    target = self.players[player_id]
                    username = target.name
                end

                if not username or not password or not level then
                    admin:send(self.help)
                    return
                elseif #username > 11 then
                    admin:send('Username must be 11 characters or less.')
                    return
                elseif not self.commands[level] then
                    admin:send('Invalid level. Must be between 1 and ' .. #self.commands)
                    return
                elseif #password < min or #password > max then
                    admin:send('Password must be ' .. min .. ' to ' .. max .. ' characters')
                    return
                end

                local admin_table = admins.password_admins[username]
                if not admin_table then
                    if target then
                        target.level = level
                        target:setLevelVariable()
                        target:newAdmin('password_admins', username, admin, password)
                        self.login_session_cache[target.socket] = self:setLoginTimeout()
                    else
                        self:newAdmin('password_admins', username, admin, password, { level = level, name = username })
                    end
                    admin:send('Added ' .. username .. ' to the password-admin list. Level (' .. level .. ').')
                    self:log(admin.name .. ' ('
						.. admin.ip .. ') added ('
						.. username .. ') to the password-admin list. Level ('
						.. level .. ')', self.logging.management)
                else
                    admin:send(username .. ' is already a password-admin (level ' .. admin_table.level .. ')')
                end
            end
        end
    end
)

def(
    'pw_admin_delete',
    'Delete a password-admin. Use /pw_admins to get the admin ID.',
    'Syntax: /$cmd <admin id>',
    function (self, id, args)
        local admin_id = _tonumber(args[2])
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not admin_id then
                admin:send(self.help)
            else
                local admins = self.admins['password_admins']
                local entry = admin:getAdminByID(admins, admin_id)
                if entry then
                    self:deleteAdmin(admins, entry.type)
                    admin:send('Removed username (' .. entry.type .. ') from the password-admin list.')
                    self:log(admin.name .. ' ('
						.. admin.ip .. ') removed username ('
						.. entry.type .. ') from the password-admin list.', self.logging.management)
                end
            end
        end
    end
)

def('pw_admins', 'List all username & password admins.', 'Syntax: /$cmd <page>',
	function (self, id, args)
		local admin = self.players[id]
		if not admin:hasPermission(self.permission_level, args[1]) then return end
		if args[2] == 'help' then
			admin:send(self.description)
			return
		end
		local page = _tonumber(args[2]) or 1
		self.header = '[Password-Admins] (Page: %s/%s)'
		local results = self:showAdminList('password_admins', page, 5, admin)
		if not results then
			admin:send('There are no password-admins.')
			return
		end
		self:log(admin.name .. ' viewed the password-admin list.', self.logging.management)
	end, { output = '[%s] %s | Level: [%s]' }
)

def(
	'change_admin_password',
	'Change another player\'s password.',
	'Syntax: /$cmd <id> <"new password">',
	function (self, id, args)
		local target = _tonumber(args[2])
		local admin = self.players[id]
		local admins = self.admins
		local tokens = mergeQuotedTokens(args, 3)
		local new_password = tokens[1]

		if admin:hasPermission(self.permission_level, args[1]) then
			if args[2] == 'help' then
				admin:send(self.description)
			elseif not target then
				admin:send(self.help)
			elseif not player_present(target) then
				admin:send('Player #' .. target .. ' is not present.')
			elseif not new_password or new_password == '' then
				admin:send('You must specify a password.')
			else
				local min, max = self.password_length_limit[1], self.password_length_limit[2]
				if #new_password < min or #new_password > max then
					admin:send('Password must be ' .. min .. ' to ' .. max .. ' characters')
					return
				end

				target = self.players[target]
				local username = target.name
				local admin_table = admins.password_admins[username]
				if admin_table then
					local old_password = admin_table.password
					local new_password_hash = self:getSimpleHash(new_password)
					if old_password == new_password_hash then
						admin:send('New password cannot be the same as the old password.')
						return
					end
					admin_table.password = new_password_hash
					admin_table.date = 'Changed on ' .. self:getDate() .. ' by ' .. admin.name .. ' (' .. admin.ip .. ')'
					self:updateAdmins()
					admin:send('Changed ' .. username .. '\'s password.')
					self:log(
						admin.name .. ' (' .. admin.ip .. ') changed ' .. username .. '\'s password.',
						self.logging.management
					)
				else
					admin:send('Username (' .. username .. ') is not a registered admin name.')
				end
			end
		end
	end
)

def(
    'change_level',
    'Changes a player\'s admin level.',
    'Syntax: /$cmd <player> <level> <type (hash/ip/password)>',
    function (self, id, args)
        local target = _tonumber(args[2])
        local level = _tonumber(args[3])
        local type_ = args[4]
        local admin = self.players[id]

        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not target or not level then
                admin:send(self.help)
            elseif not self.commands[level] then
                admin:send('Admin level (' .. level .. ') does not exist.')
            elseif not player_present(target) then
                admin:send('Player #' .. target .. ' is not present.')
            elseif level == 1 then
                admin:send('You cannot change a player\'s admin level to 1.')
            elseif target == id then
                admin:send('You cannot change your own admin level.')
            else
                target = self.players[target]
                local name = target.name
                local hash = target.hash
                local admins = self.admins
                local hash_admins = admins.hash_admins
                local ip_admins = admins.ip_admins
                local password_admins = admins.password_admins

                if target.level == 1 then
                    admin:send(name .. ' is either not an admin or isn\'t logged in.')
                    return
                elseif type_ == 'hash' and not hash_admins[hash] then
                    admin:send(name .. ' is not a hash-admin.')
                    return
                elseif type_ == 'ip' and not ip_admins[target.ip] then
                    admin:send(name .. ' is not an ip-admin.')
                    return
                elseif type_ == 'password' and not target.password_admin then
                    admin:send(name .. ' either not an admin or isn\'t logged in.')
                    return
                elseif type_ == 'hash' then
                    hash_admins[hash].level = level
                    hash_admins[hash].date = 'Changed on ' .. self:getDate()
						.. ' by ' .. admin.name
						.. ' (' .. admin.ip
						.. ')'
                elseif type_ == 'ip' then
                    ip_admins[target.ip].level = level
                    ip_admins[target.ip].date = 'Changed on ' .. self:getDate()
						.. ' by ' .. admin.name
						.. ' (' .. admin.ip
						.. ')'
                elseif type_ == 'password' then
                    password_admins[name].level = level
                else
                    admin:send('Invalid type argument. Valid types: hash, ip, password')
                    return
                end

                target.level = level
                target:setLevelVariable()
                self:updateAdmins()
                admin:send('Changed ' .. name .. '\'s admin level to ' .. level .. ' (' .. type_ .. ')')
                self:log(admin.name .. ' ('
					.. admin.ip .. ') changed '
					.. name .. '\'s admin level to '
					.. level .. ' ('
					.. type_ .. ')', self.logging.management)
            end
        end
    end
)

def('level_add', 'Add a new admin level.', 'Syntax: /$cmd <level>', function (self, id, args)
    local level = _tonumber(args[2])
    local admin = self.players[id]
    if admin:hasPermission(self.permission_level, args[1]) then
        if args[2] == 'help' then
            admin:send(self.description)
        elseif not level then
            admin:send(self.help)
        elseif self.commands[level] then
            admin:send('Level ' .. level .. ' already exists.')
        else
            self.commands[level] = {}
            self:updateCommands()
            admin:send('Level ' .. level .. ' added.')
            self:log(
                admin.name .. ' (' .. admin.ip .. ') added level ' .. level .. ' to (' .. self.files[2] .. ')',
                self.logging.management
            )
        end
    end
end)

def(
    'level_delete',
    'Delete an admin level (requires confirmation).',
    'Syntax: /$cmd <level>',
    function (self, id, args)
        local level = _tonumber(args[2])
        local admin = self.players[id]
        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not level then
                admin:send(self.help)
            elseif level == 1 then
                admin:send('You cannot delete level 1.')
            elseif not self.commands[level] then
                admin:send('Level ' .. level .. ' does not exist.')
            else
                admin:send('Are you sure you want to delete level ' .. level .. '?')
                admin:send('Type /confirm to confirm.')
                admin.confirm = { timeout = _time() + self.confirmation_timeout, level = level }
            end
        end
    end
)

def('disable_command', 'Disable a command.', 'Syntax: /$cmd <command>', function (self, id, args)
    local target_command = args[2]
    local admin = self.players[id]
    if admin:hasPermission(self.permission_level, args[1]) then
        if not target_command then
            admin:send(self.help)
        elseif target_command == 'help' then
            admin:send(self.description)
        else
            local level, enabled = self:findCommand(target_command)
            if level == nil then
                admin:send('Command (' .. target_command .. ') does not exist.')
            elseif not enabled then
                admin:send('Command (' .. target_command .. ') is already disabled.')
            else
                self.commands[level][target_command] = false
                self:updateCommands()
                admin:send('Command (' .. target_command .. ') has been disabled.')
                self:log(
                    admin.name .. '(' .. admin.ip .. ') disabled command (' .. target_command .. ')',
                    self.logging.management
                )
            end
        end
    end
end)

def('enable_command', 'Enable a command.', 'Syntax: /$cmd <command>', function (self, id, args)
    local target_command = args[2]
    local admin = self.players[id]
    if admin:hasPermission(self.permission_level, args[1]) then
        if not target_command then
            admin:send(self.help)
        elseif target_command == 'help' then
            admin:send(self.description)
        else
            local level, enabled = self:findCommand(target_command)
            if level == nil then
                admin:send('Command (' .. target_command .. ') does not exist.')
            elseif enabled then
                admin:send('Command (' .. target_command .. ') is already enabled.')
            else
                self.commands[level][target_command] = true
                self:updateCommands()
                admin:send('Command (' .. target_command .. ') has been enabled.')
                self:log(
                    admin.name .. '(' .. admin.ip .. ') enabled command (' .. target_command .. ')',
                    self.logging.management
                )
            end
        end
    end
end)

def(
    'set_command',
    'Add or set a new/existing command to a new level.',
    'Syntax: /$cmd <command> <level> (opt 3rd arg: "true" to enable, "false" to disable)',
    function (self, id, args)
        local target_command = (args[2] and _lower(args[2]))
        local level = _tonumber(args[3])
        local enable = args[4]
        local admin = self.players[id]

        if admin:hasPermission(self.permission_level, args[1]) then
            if args[2] == 'help' then
                admin:send(self.description)
            elseif not target_command then
                admin:send(self.help)
            elseif not level then
                admin:send(self.help)
            elseif not self.commands[level] then
                admin:send('Admin level (' .. level .. ') does not exist.')
            else
                local existing_level = self:findCommand(target_command)
                if existing_level then
                    self.commands[existing_level][target_command] = nil
                end
                enable = (enable and _lower(enable) == 'true') or false
                self.commands[level][target_command] = enable
                self:updateCommands()
                admin:send('Command (' .. target_command
					.. ') has been set to level (' .. level
					.. '). Enabled: ' .. _tostring(enable))
                self:log(admin.name .. ' ('
					.. admin.ip .. ') set command ('
					.. target_command .. ') to level ('
					.. level .. '). Enabled: '
					.. _tostring(enable), self.logging.management)
            end
        end
    end
)

def('reload', 'Reload all admin databases.', 'Syntax: /$cmd', function (self, id, args)
    local admin = self.players[id]
    if admin:hasPermission(self.permission_level, args[1]) then
        if args[2] == 'help' then
            admin:send(self.description)
            return
        end
        self:loadBans()
        self:loadAliases()
        self:setAdmins()
        self:setDefaultCommands()
        admin:send('Databases reloaded.')
        self:log(admin.name .. ' (' .. admin.ip .. ') reloaded the databases.', self.logging.management)
    end
end)

-- ============================================================================
-- EVENTS
-- ============================================================================

local event = {}

event.overrides = { 'login', 'change_password' }

local function getHighest(a, b)
    return (a > b and a or b)
end

local function isChatCommand(s)
    local c = _sub(s, 1, 1)
    return c == '/' or c == '\\'
end

function event:setLevel()
    local id = self.id
    local ip = self.ip
    local socket = self.socket
    local hash = self.hash
    local username = self.name

    local cache = self.login_session_cache
    local admins = self.admins
    local hash_admins = admins.hash_admins
    local ip_admins = admins.ip_admins
    local password_admins = admins.password_admins

    if hash_admins[hash] and ip_admins[ip] then
        self.level = getHighest(hash_admins[hash].level, ip_admins[ip].level)
    elseif hash_admins[hash] then
        self.level = hash_admins[hash].level
    elseif ip_admins[ip] then
        self.level = ip_admins[ip].level
    elseif password_admins[username] and cache[socket] then
        self.level = password_admins[username].level
    else
        self.level = 1
    end

    self:setLevelVariable()
    execute_command('adminadd ' .. id .. ' 4')
end

function event:newPlayer(o)
    _setmetatable(o, { __index = AdminManager })
    if o:rejectPlayer() then
        return o
    elseif o.id ~= 0 then
        o:setLevel()
        o:newAlias('IP_ALIASES', o.ip, o.name)
        o:newAlias('HASH_ALIASES', o.hash, o.name)
    end
    return o
end

for k, v in _pairs(event) do
    if _type(v) == 'function' then M[k] = v end
end
M.overrides = event.overrides
_setmetatable(AdminManager, { __index = M })

function OnJoin(id)
    if not AdminManager.players then return end
    local ip = get_var(id, '$ip')
    local player = AdminManager:newPlayer({
        socket = AdminManager:getIPFormat(ip),
        ip     = _match(ip, '%d+%.%d+%.%d+%.%d+'),
        id     = id,
        name   = get_var(id, '$name'),
        hash   = get_var(id, '$hash')
    })
    AdminManager.players[id] = player
    player:vipMessages()
end

function OnQuit(id)
    if AdminManager.players then
        AdminManager.players[id] = nil
    end
end

function OnGameStart()
    if get_var(0, '$gt') == 'n/a' then return end

    AdminManager.login_session_cache = AdminManager.login_session_cache or {}
    AdminManager.players = {
        [0] = AdminManager:newPlayer({
            id    = 0,
            level = AdminManager.console_default_level,
            name  = '_CONSOLE_',
            hash  = 'N/A',
            ip    = 'localhost'
        })
    }
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

-- Walk one ban group and drop any entries whose time has passed.
-- Returns true if anything was removed.
local function expireBanGroup(group_name, tbl, now)
    local updated = false
    for key, entry in _pairs(tbl) do
        local t = entry.time
        if t and (t.year or 0) > 0 then
            local when = _time({
                year = t.year,
                month = t.month,
                day = t.day,
                hour = t.hour or 0,
                min = t.min or 0,
                sec = t.sec or 0
            })
            if now >= when then
                updated = true
                tbl[key] = nil
                cprint('Ban expired: ' .. key .. ' (' .. (entry.offender or '?') .. ') ' .. group_name, 12)
            end
        end
    end
    return updated
end

function OnTick()
    if not AdminManager.players then return end

    local now = _time()
    local bans = AdminManager.bans
    local update_bans = false

    if expireBanGroup('ip', bans.ip, now) then update_bans = true end
    if expireBanGroup('hash', bans.hash, now) then update_bans = true end
    if expireBanGroup('mute_ip', bans.mute.ip, now) then update_bans = true end
    if expireBanGroup('mute_hash', bans.mute.hash, now) then update_bans = true end
    if update_bans then AdminManager:updateBans() end

    -- Confirmation prompts expire after the configured timeout.
    for _, v in _pairs(AdminManager.players) do
        if v.confirm and now > v.confirm.timeout then
            v.confirm = nil
            v:send('Action timed out.')
        end
    end

    -- Password admin sessions expire after login_timeout hours.
    for socket, expiration in _pairs(AdminManager.login_session_cache) do
        if now > expiration then
            AdminManager.login_session_cache[socket] = nil
            for _, player in _pairs(AdminManager.players) do
                if player.id ~= 0 and player.socket == socket then
                    player.level = 1
                    player.password_admin = false
                    player:setLevelVariable()
                    player:send('Your login session has expired.')
                end
            end
        end
    end
end

function OnUnload()
    AdminManager:unregisterLevelVariable()
end

function OnChat(id, message)
    local player = AdminManager.players and AdminManager.players[id]
    if not player then return true end

    if isChatCommand(message) then
        local args = AdminManager:stringSplit(message)
        local commandName = _lower(_sub(args[1], 2))
        for _, override in _ipairs(AdminManager.overrides) do
            if commandName == override then
                local command = AdminManager.management[override]
                command:run(id, args)
                return false
            end
        end
        return true
    end

    -- Regular chat is blocked for muted players.
    if player:isMuted() then return false end

    if player.a_chat then
        player:adminChat(message)
        return false
    end
    return true
end

function OnCommand(id, command)
    local args = AdminManager:stringSplit(command)
    local target_command = args[1] and _lower(args[1]) or nil
    local admin = AdminManager.players and AdminManager.players[id]
    if not admin or not target_command then return end

    local cmd = AdminManager.management[target_command]

    local server_management = (cmd ~= nil) and id == 0
    local player_management = (cmd ~= nil) and cmd.enabled
    local player_management_disabled = (id > 0 and cmd ~= nil and not cmd.enabled)

    if server_management then
        cmd:run(id, args)
        return false
    elseif player_management then
        admin:commandSpy(target_command)
        cmd:run(id, args)
        return false
    elseif player_management_disabled then
        admin:send('Command (' .. target_command .. ') is disabled.')
        AdminManager:log(
            admin.name .. ' is attempting to execute (' .. target_command .. ') but it is disabled.',
            AdminManager.logging.default
        )
        return false
    end

    -- Default (SAPP) commands.
    local current_level = admin.level
    local required_level, enabled = AdminManager:findCommand(target_command)

    if required_level == nil then
        admin:send('Command (' .. target_command .. ') does not exist.')
        AdminManager:log(
            admin.name .. ' is attempting to execute (' .. target_command .. ') but it does not exist.',
            AdminManager.logging.default
        )
        return false
    elseif not enabled and id ~= 0 then
        admin:send('Command (' .. target_command .. ') is disabled.')
        AdminManager:log(
            admin.name .. ' is attempting to execute (' .. target_command .. ') but it is disabled.',
            AdminManager.logging.default
        )
        return false
    elseif current_level < required_level then
        admin:send('Insufficient Permission.')
        admin:send('You must be level (' .. required_level .. ') or higher.')
        AdminManager:log(admin.name .. ' is attempting to execute ('
                .. target_command .. ') but is not a high enough level (current level: '
                .. admin.level .. ') (Required level: '
                .. required_level .. ')', AdminManager.logging.default)
        return false
    end

    AdminManager:log('Command: (' .. target_command
            .. ') was executed by: ' .. admin.name
            .. ' (' .. id
            .. ') (' .. admin.ip
            .. ')', AdminManager.logging.default)
    admin:commandSpy(target_command)
    return true
end

function OnGameEnd()
    AdminManager:updateAliases()
end

-- ============================================================================
-- LOAD
-- ============================================================================

function AdminManager:load()
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_GAME_START'], 'OnGameStart')
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_CHAT'], 'OnChat')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_END'], 'OnGameEnd')

    local dir = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    self.data_dir = dir .. '\\sapp\\'

    local t = {}
    for level, v in _pairs(self.management_commands) do
        for cmd_name, enabled in _pairs(v) do
            local cmd = commands[_lower(cmd_name)]
            if cmd then
                local registered = {}
                for k, val in _pairs(cmd) do
                    registered[k] = val
                end
                registered.enabled = enabled
                registered.permission_level = _tonumber(level)
                registered.help = _gsub(cmd.help, '%$cmd', cmd_name)
                registered.description = _gsub(cmd.description, '%$cmd', cmd_name)
                _setmetatable(registered, { __index = self })
                t[_lower(cmd_name)] = registered
            end
        end
    end

    self.management = t
    self:registerLevelVariable()
    self:loadBans()
    self:loadAliases()
    self:setDefaultCommands()
    self:setAdmins()

    OnGameStart()
end

function OnScriptLoad()
    AdminManager:load()
end

function OnScriptUnload()
    OnUnload()
end
