--[[
=====================================================================================
SCRIPT NAME:      discord.lua
DESCRIPTION:      Logs Halo server events and exports them
                  to a text file for external processing by a Discord bot.

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local PIRATED_HASHES = {
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
}

api_version = '1.12.0.0'

-- Standard Lua functions
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local io_open = io.open
local table_insert = table.insert
local concat = table.concat
local char = string.char
local os_time = os.time

-- SAPP API functions
local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local register_callback = register_callback
local read_byte = read_byte
local read_dword = read_dword
local sig_scan = sig_scan
local lookup_tag = lookup_tag
local get_dynamic_player = get_dynamic_player

-- Game/server state
local players
local server_name
local map
local mode
local gametype
local gametype_base
local score_limit
local ffa
local first_blood
local falling_tag
local distance_tag

-- Constants
local COMMAND_TYPE = { [0] = "RCON", [1] = "CONSOLE", [2] = "CHAT", [3] = "UNKNOWN" }
local CHAT_TYPE = { [0] = "GLOBAL", [1] = "TEAM", [2] = "VEHICLE", [3] = "UNKNOWN" }
local GAMETYPE_MAP = { ctf = 1, race = 2, slayer = 4 }
local CALLBACKS = {
    [cb['EVENT_CHAT']] = 'OnChat',
    [cb['EVENT_COMMAND']] = 'OnCommand',
    [cb['EVENT_DIE']] = 'OnDeath',
    [cb['EVENT_SCORE']] = 'OnScore',
    [cb['EVENT_DAMAGE_APPLICATION']] = 'OnDamage',
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_GAME_END']] = 'OnEnd',
    [cb['EVENT_GAME_START']] = 'OnStart',
    [cb['EVENT_SNAP']] = 'OnSnap',
    [cb['EVENT_SPAWN']] = 'OnSpawn',
    [cb['EVENT_LOGIN']] = 'OnLogin',
    [cb['EVENT_MAP_RESET']] = "OnReset",
    [cb['EVENT_TEAM_SWITCH']] = 'OnSwitch'
}

local log_path

local function escapeValue(value)
    if value == nil then return "" end
    local str = tostring(value)
    str = str:gsub("|", "\\|")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    return str
end

local function formatEvent(event_type, data_table, subtype)
    local parts = { event_type }

    if subtype then
        table_insert(parts, "subtype=" .. escapeValue(subtype))
    end

    for key, value in pairs(data_table) do
        table_insert(parts, key .. "=" .. escapeValue(value))
    end

    table_insert(parts, "timestamp=" .. os_time())

    return concat(parts, "|")
end

local function clearLog()
    local file = io_open(log_path, "w")
    if file then file:close() end
end

local function appendEvent(event_string)
    local file = io_open(log_path, "a")
    if file then
        file:write(event_string .. "\n")
        file:close()
        return true
    end
    return false
end

local function WriteEvent(event_type, data, subtype, attempt)
    attempt = attempt or 1
    local event_string = formatEvent(event_type, data, subtype)

    local success = appendEvent(event_string)

    if not success and attempt < 3 then
        timer(100, "RetryWriteEvent", event_type, data, subtype, attempt + 1)
    end

    return success
end

function RetryWriteEvent(event_type, data, subtype, attempt)
    attempt = tonumber(attempt) or 1
    WriteEvent(event_type, data, subtype, attempt)
end

local function readWideString(address, length)
    local bytes = {}
    for i = 1, length do
        local byte = read_byte(address + (i - 1) * 2)
        if byte == 0 then break end
        bytes[#bytes + 1] = char(byte)
    end
    return concat(bytes)
end

local function getServerName()
    local network_struct = read_dword(sig_scan("F3ABA1????????BA????????C740??????????E8????????668B0D") + 3)
    return readWideString(network_struct + 0x8, 0x42)
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function newPlayer(id)
    return {
        id = id,
        last_damage = 0,
        switched = false,
        ip = get_var(id, '$ip'),
        name = get_var(id, '$name'),
        team = get_var(id, '$team'),
        hash = get_var(id, '$hash'),
        level = function() return tonumber(get_var(id, '$lvl')) end
    }
end

local function getPlayerData(player, isQuit)
    local total = tonumber(get_var(0, '$pn'))
    return {
        total = isQuit and total - 1 or total,
        name = player.name,
        ip = player.ip,
        hash = player.hash,
        id = player.id,
        lvl = player.level(),
        ping = get_var(player.id, "$ping"),
        pirated = PIRATED_HASHES[player.hash] and 'YES' or 'NO'
    }
end

local function inVehicle(id)
    local dyn_player = get_dynamic_player(id)
    return dyn_player ~= 0 and read_dword(dyn_player + 0x11C) ~= 0xFFFFFFFF
end

function OnStart(notifyFlag)
    gametype = get_var(0, "$gt")
    if gametype == 'n/a' then return end

    if not server_name then
        server_name = getServerName()
        log_path = "./discord_events/" .. server_name .. ".txt"
        clearLog()
    end

    players, first_blood = {}, true
    ffa = get_var(0, '$ffa') == '1'
    mode, map = get_var(0, "$mode"), get_var(0, "$map")
    falling_tag, distance_tag = getTag('jpt!', 'globals\\falling'), getTag('jpt!', 'globals\\distance')
    score_limit = read_byte(gametype_base + 0x58)

    if not notifyFlag or notifyFlag == 0 then
        WriteEvent("event_start", {
            map = map,
            mode = mode,
            gametype = gametype,
            ffa = ffa and "true" or "false"
        })
    end

    for i = 1, 16 do
        if player_present(i) then OnJoin(i, notifyFlag) end
    end
end

function OnEnd()
    WriteEvent("event_end", {
        map = map,
        mode = mode,
        gametype = gametype,
        ffa = ffa and "true" or "false"
    })
end

function OnJoin(id, notifyFlag)
    players[id] = newPlayer(id)
    if not notifyFlag then
        WriteEvent("event_join", getPlayerData(players[id]))
    end
end

function OnQuit(id)
    local player = players[id]
    if player then
        WriteEvent("event_leave", getPlayerData(player, true))
        players[id] = nil
    end
end

function OnSpawn(id)
    local player = players[id]
    if player then
        player.last_damage, player.switched = 0, nil
        WriteEvent("event_spawn", { name = player.name, team = player.team })
    end
end

function OnSwitch(id)
    local player = players[id]
    if player then
        player.team, player.switched = get_var(id, '$team'), true
        WriteEvent("event_team_switch", { name = player.name, team = player.team })
    end
end

function OnReset()
    WriteEvent("event_map_reset", {
        map = map,
        mode = mode,
        gt = gametype,
        ffa = ffa and "FFA" or "Team Play"
    })
end

function OnLogin(id)
    local player = players[id]
    if player then
        WriteEvent("event_login", { name = player.name, lvl = player.level() })
    end
end

function OnSnap(id)
    local player = players[id]
    if player then WriteEvent("event_snap", { name = player.name }) end
end

function OnCommand(id, command, env)
    local player = players[id]
    if player then
        WriteEvent("event_command", {
            lvl = player.level(),
            name = player.name,
            id = tostring(id),
            type = COMMAND_TYPE[env],
            cmd = command
        })
    end
    return true
end

function OnChat(id, msg, env)
    local player = players[id]
    if player and msg:sub(1, 1) ~= "/" and msg:sub(1, 1) ~= "\\" and msg:sub(1, 1) ~= "@" then
        WriteEvent("event_chat", {
            type = CHAT_TYPE[env],
            name = player.name,
            id = id,
            msg = msg
        })
    end
end

function OnScore(id)
    local player = players[id]
    if not player then return end

    local event_type = GAMETYPE_MAP[gametype] or (gametype == "race" and (ffa and 3 or 2))
    if not event_type then return end

    WriteEvent("event_score", {
        totalTeamLaps = player.team == "red" and get_var(0, "$redscore") or get_var(0, "$bluescore"),
        score = get_var(id, "$score"),
        name = player.name,
        team = player.team or "FFA",
        redScore = get_var(0, "$redscore"),
        blueScore = get_var(0, "$bluescore"),
        scorelimit = score_limit
    }, event_type)
end

function OnDamage(victim, _, metaId)
    local player = players[tonumber(victim)]
    if player then player.last_damage = metaId end
end

function OnDeath(victim, killer)
    victim, killer = tonumber(victim), tonumber(killer)
    local victim_data, killer_data = players[victim], players[killer]
    if not victim_data then return end

    local event_type = 10
    if killer == -1 and not victim_data.switched then
        event_type = (victim_data.last_damage == falling_tag or victim_data.last_damage == distance_tag) and 8 or 9
    elseif killer == 0 then
        event_type = 7
    elseif killer > 0 then
        if killer == victim then
            event_type = 5
        elseif not ffa and killer_data and victim_data.team == killer_data.team then
            event_type = 6
        elseif first_blood then
            first_blood = false; event_type = 1
        elseif not player_alive(killer) then
            event_type = 2
        elseif inVehicle(victim) then
            event_type = 3
        else
            event_type = 4
        end
    end

    WriteEvent("event_death", {
        killerName = killer_data and killer_data.name or "",
        victimName = victim_data.name
    }, event_type)
end

function OnScriptLoad()
    gametype_base = read_dword(sig_scan("B9360000008BF3BF78545F00") + 0x8)
    for event, handler in pairs(CALLBACKS) do
        register_callback(event, handler)
    end

    OnStart(1)
end

function OnScriptUnload() end
