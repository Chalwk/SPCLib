--[[
=====================================================================================
SCRIPT NAME:      reg_to_play.lua
DESCRIPTION:      Enforces mandatory player registration with timed kick system.

FEATURES:
                  - 10-second registration window (configurable)
                  - Persistent player data storage (IP/name)
                  - Automatic kick for unregistered players
                  - Password-protected registration (!register <password>)

CONFIGURATION:
                  kick_delay:       Registration time window (default: 10s)
                  command:          Registration trigger command (default: !register)
                  password:         Registration password (default: secret123)
                  permission_level: Minimum required permission level (default: -1)
                  filename:         Player database filename (default: players.txt)
                  save_on_register: Save mode (true = immediate, false = on game end)

USAGE:
                  Players must register using: !register <password>
                  Unregistered players are automatically kicked after grace period
                  Configure settings in the CONFIG table at script top.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration Settings --
local CONFIG = {
    kick_delay = 10,                -- Registration time window (seconds)
    command = "!register",          -- Registration trigger command
    password = "secret123",         -- Registration password
    permission_level = -1,          -- Minimum required permission level
    filename = "players.txt",       -- Player database filename
    save_on_register = false        -- Save mode (true = immediate, false = on game end)
}

api_version = "1.12.0.0"

local pending_players = {}
local registered_players = {}
local file_path

local function get_clean_ip(player_id)
    return get_var(player_id, "$ip"):match("(%d+%.%d+%.%d+%.%d+)")
end

local function has_permission(player_id)
    local level = tonumber(get_var(player_id, "$lvl"))
    return level and (level == 0 or level >= CONFIG.permission_level)
end

local function save_database()
    local file, err = io.open(file_path, "w")
    if not file then
        return cprint("ERROR: Failed to save database - " .. (err or "unknown error"))
    end

    for ip, name in pairs(registered_players) do
        file:write(ip .. "|" .. name .. "\n")
    end
    file:close()
end

local function load_database()
    registered_players = {}
    local file = io.open(file_path, "r")
    if not file then return end

    for line in file:lines() do
        local ip, name = line:match("^([^|]+)|(.+)$")
        if ip and name then
            registered_players[ip] = name
        end
    end
    file:close()
end

local function register_player(player_id)
    local ip = get_clean_ip(player_id)
    local name = get_var(player_id, "$name")

    registered_players[ip] = name
    pending_players[player_id] = nil

    say(player_id, "Registration successful! Welcome to the server.")

    if CONFIG.save_on_register then
        save_database()
    end
end

local function process_command(player_id, command)
    local args = {}
    for arg in command:gmatch("%S+") do
        args[#args+1] = arg
    end

    if #args < 2 or args[1]:lower() ~= CONFIG.command then
        return true
    end

    if not pending_players[player_id] then
        say(player_id, "You are already registered.")
        return false
    end

    if not has_permission(player_id) then
        say(player_id, "Insufficient permissions.")
        return false
    end

    if args[2] == CONFIG.password then
        register_player(player_id)
    else
        say(player_id, "Invalid password. Try again.")
    end

    return false
end

function OnScriptLoad()
	local path = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    file_path = path .. "\\sapp\\" .. CONFIG.filename

    register_callback(cb["EVENT_JOIN"], "OnPlayerJoin")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerLeave")
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    register_callback(cb["EVENT_TICK"], "OnTick")
    register_callback(cb["EVENT_GAME_START"], "OnStart")

    if not CONFIG.save_on_register then
        register_callback(cb["EVENT_GAME_END"], "OnEnd")
    end

    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    load_database()

    for i = 1, 16 do
        if player_present(i) then
            OnPlayerJoin(i)
        end
    end
end

function OnEnd()
    save_database()
end

function OnPlayerJoin(player_id)
    local ip = get_clean_ip(player_id)
    local name = get_var(player_id, "$name")

    if not registered_players[ip] or registered_players[ip] ~= name then
        pending_players[player_id] = {
            start = os.time(),
            finish = os.time() + CONFIG.kick_delay
        }
        say(player_id, "You have " .. CONFIG.kick_delay .. " seconds to register using: " ..
            CONFIG.command .. " " .. CONFIG.password)
    end
end

function OnPlayerLeave(player_id)
    pending_players[player_id] = nil
end

function OnTick()
    local current_time = os.time()
    for player_id, data in pairs(pending_players) do
        if current_time >= data.finish then
            execute_command('k ' .. player_id .. '"Registration timeout"')
        end
    end
end

function OnCommand(player_id, command)
    return process_command(player_id, command)
end

function OnScriptUnload()
    if not CONFIG.save_on_register then
        save_database()
    end
end