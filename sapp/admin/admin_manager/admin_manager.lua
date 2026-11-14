--[[
==============================================================================================
SCRIPT NAME:    admin_manager.lua
DESCRIPTION:    A drop-in replacement for SAPP's built-in admin system.

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

                FILE LAYOUT:
                ------------------------------------------------------------------------------
                admin_manager.lua               this file (entry point, loaded by SAPP).
                                                Always goes in `<instance>\sapp\`.

                admin_manager\                  Modules, loaded with loadfile. Goes next to
                                                this file, or in the server root folder for a
                                                multi-instance setup (see MODULE_LOCATION).
                    config.lua                  Settings: edit this one.
                    manager.lua                 Event handling and command dispatch.
                    database.lua                Admins, bans, aliases (in memory + files).
                    permissions.lua             commands.txt: levels and command access.
                    serializer.lua              Plain text file formats.
                    player.lua, console.lua     Player objects (Console extends Player).
                    commands\                   One file per command group and a few small
                                                helpers (class, util, storage, logger, data).

                Databases (plain text, auto-created in the instance's sapp folder):
                    admins.txt                  (manual editing OK, run /reload afterwards)
                    commands.txt                (manual editing OK, run /reload afterwards)
                    bans.txt                    (do not edit, use commands)
                    aliases.txt                 (do not edit, use commands)
                    logs.txt                    (append-only admin activity log)

                File format:
                    - Fields are separated by a single semicolon (;).
                    - Lists inside a field (commands.txt) are separated by commas (,).
                    - Literal semicolons, backslashes and newlines inside a field are
                      escaped with a backslash: \; \\ \n \r
                    - One record per line.

                Commands and permissions (defaults):
                -----------------------------------------------------------------------
                | Command                | Description                        | Level |
                -----------------------------------------------------------------------
                | login                  | Login with a password              |   1   |
                | logout                 | Logout of the server               |   1   |
                | my_level               | Show your admin level              |   1   |
                | admins_online          | List online admins                 |   1   |
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
                | reload                 | Reload the admin databases         |   6   |
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
                    - /hash_ban 1                                 (permanent)
                    - /ip_ban 1 -h 1 -m 30 -r "caught cheating"
                    - /ip_ban 1                                   (permanent)
                    - /name_ban 1 -r "explicit name"
                    - /name_ban penis
                    - /ip_mute 1 -m 10 -r "spamming"
                    - /hash_mute 1 -d 5 -r "constant swearing"

                Pirated hashes:
                Shared CD-KEY hashes are detected automatically and cannot be
                banned, as doing so would affect all players sharing that hash.

                Default levels:
                -----------------------------------------------------------------------
                1: Public       2: Moderator   3: Admin   4: Senior Admin
                5: Head Admin   6: Owner

                Add custom levels in commands.txt or with level_add / level_delete.
                There is no limit on the number of levels. Just keep at least one
                level with the "1" key. A command set to enabled is usable by its
                level and above. A disabled command only works from the console.

                By default nobody can ban/mute/modify someone of equal or higher level,
                or hand out a level above their own (see config.lua). The console is
                exempt from both rules.

                WARNING:
                For this system to work, all players are given SAPP level 4.
                In the rare event this script crashes, all players would have
                unrestricted access to SAPP's commands. No known crashes currently,
                just something worth noting.

                INSTALLATION:
                
                1. Put `admin_manager.lua` into `<instance>\sapp\`.
                2. Put the `admin_manager` folder in the server root (beside
                haloded.exe / haloceded.exe).

                CONFIGURATION:
                Edit `admin_manager\config.lua`.

Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

-- Where the module folder lives. This has to be set here rather than in config.lua,
-- because config.lua is itself one of the modules being located.
--   'instance'  <instance>\sapp\admin_manager\         (default, single or multi-server)
--   'root'      <server root>\admin_manager\           (multi-instance: one copy shared by every instance)
---@type string
local MODULE_LOCATION = 'root'

-- Name of the module folder.
local MODULE_FOLDER = 'admin_manager'

-- Path separator. Windows and Wine report '\'; this only differs when testing elsewhere.
local SEPARATOR = package and package.config and package.config:sub(1, 1) or '\\'

---@diagnostic disable-next-line: access-invisible
-- Lua 5.1 provides setfenv; Lua 5.2+ does not. Aliased to a nullable local so the
-- compatibility guard below is explicit (and visible to the type checker).
---@type fun(f: function, env: table)?
local lua51_setfenv = setfenv

---@diagnostic disable-next-line: access-invisible
-- Modules are loaded with loadfile, which gives them the global environment rather than
-- this script's. SAPP scripts have their own environment, so it is passed on explicitly.
local script_env = getfenv and getfenv(1) or _G

---@type Manager | nil
local manager

--- Resolves the string pointer at sig_scan(signature) + offset, falling back to a
--- hardcoded PC/CE address when the signature misses or points outside Halo's data.
---@param signature  string
---@param offset     number
---@param pc_address number
---@param ce_address number
---@return string | nil value
local function readSignedString(signature, offset, pc_address, ce_address)
    local hit = sig_scan(signature)
    local pointer = hit ~= 0 and read_dword(hit + offset) or 0
    if pointer < 0x400000 or pointer > 0x800000 then
        pointer = halo_type == 'PC' and pc_address or ce_address
    end
    local value = read_string(pointer)
    return value ~= '' and value or nil
end

--- Instance folder (the -path argument).
---@return string | nil path Without a trailing separator.
local function instanceDirectory()
    local path = readSignedString('68??????008D54245468', 0x1, 0x635610, 0x5B9630)
    return path and (path:gsub('[\\/]+$', ''))
end

--- Server root: the folder that contains haloded.exe / haloceded.exe.
---@return string | nil path With a trailing separator.
local function baseDirectory()
    local exe_path = readSignedString('0000BE??????005657C605', 0x3, 0x62C390, 0x5B0670)
    return exe_path and exe_path:match('^(.*[\\/])')
end

--- Folder holding the module files, according to `MODULE_LOCATION`.
---@param instance_directory string Without a trailing separator.
---@return string | nil path          With a trailing separator.
---@return string | nil error_message
local function moduleDirectory(instance_directory)
    if MODULE_LOCATION == 'root' then
        local base = baseDirectory()
        if not base then return nil, 'could not determine the server root folder' end
        return base .. MODULE_FOLDER .. SEPARATOR
    elseif MODULE_LOCATION == 'instance' then
        return instance_directory .. SEPARATOR .. 'sapp' .. SEPARATOR .. MODULE_FOLDER .. SEPARATOR
    end
    return nil, 'MODULE_LOCATION must be \'instance\' or \'root\' (got ' .. tostring(MODULE_LOCATION) .. ')'
end

--- Returns an `import(name)` function. 'commands.auth' loads `<root>commands\auth.lua`.
--- Each module is a chunk that receives `import` as `...` and returns its table/class.
---@param root string Module folder with trailing separator.
---@return function import
local function createImporter(root)
    local cache = {}

    local function import(name)
        local module = cache[name]
        if module ~= nil then return module end

        local path = root .. (name:gsub('%.', SEPARATOR)) .. '.lua'
        local chunk, err = loadfile(path)
        if not chunk then
            error('cannot load module "' .. name .. '": ' .. tostring(err), 2)
        end

        ---@diagnostic disable-next-line: access-invisible
        if lua51_setfenv then lua51_setfenv(chunk, script_env) end

        module = chunk(import)
        if module == nil then error('module "' .. name .. '" returned nothing', 2) end

        cache[name] = module
        return module
    end

    return import
end

function OnScriptLoad()
    if not loadfile then
        cprint('[AdminManager] loadfile is unavailable in this environment.', 12)
        return
    end

    local instance_directory = instanceDirectory()
    if not instance_directory then
        cprint('[AdminManager] Could not determine the instance folder.', 12)
        return
    end

    local module_directory, problem = moduleDirectory(instance_directory)
    if not module_directory then
        cprint('[AdminManager] ' .. problem, 12)
        return
    end

    local sapp_directory = instance_directory .. SEPARATOR .. 'sapp' .. SEPARATOR -- databases
    local import = createImporter(module_directory)

    local ok, result = pcall(function ()
        local instance = import('manager'):new(import, import('config'), sapp_directory)
        instance:load()
        return instance
    end)

    if not ok then
        cprint('[AdminManager] Failed to start: ' .. tostring(result), 12)
        return
    end
    ---@cast result Manager
    manager = result

    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnLeave')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_CHAT'], 'OnChat')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
end

function OnScriptUnload()
    if manager then manager:onUnload() end
end

---@param player_id number
function OnJoin(player_id)
    if manager then manager:onJoin(player_id) end
end

---@param player_id number
function OnLeave(player_id)
    if manager then manager:onLeave(player_id) end
end

function OnStart()
    if manager then manager:onStart() end
end

function OnEnd()
    if manager then manager:onEnd() end
end

function OnTick()
    if manager then manager:onTick() end
end

---@param player_id number
---@param message   string
---@return boolean | nil allow Return false to block the message.
function OnChat(player_id, message)
    if manager then return manager:onChat(player_id, message) end
end

---@param executor_id number
---@param command     string
---@return boolean | nil allow Return false to block the command.
function OnCommand(executor_id, command)
    if manager then return manager:onCommand(executor_id, command) end
end

function OnError(error_message)
    -- todo: implement this
end