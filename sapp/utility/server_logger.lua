--[[
=====================================================================================
SCRIPT NAME:      server_logger.lua
DESCRIPTION:      Advanced server logging system that replaces SAPP's default logs.
                  Tracks player activity, game events, and admin commands with
                  customizable verbosity.

LAST UPDATED:     23/9/2025

Copyright (c) 2024-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration starts here -----------------------------------------------------------------------

local LOG_FILE = '\sapp\server_log.txt'
local TIMESTAMP_FORMAT = '!%a %d %b %Y %H:%M:%S'
local EVENTS = {
    OnStart = { enable = true, log = "[START] New game on $map - $mode" },
    OnEnd = { enable = true, log = "[END] Game ended" },
    OnJoin = { enable = true, log = "[JOIN] $name ($id) | IP: $ip | Hash: $hash | Pirated: $pirated | Players: $total/16" },
    OnQuit = { enable = true, log = "[QUIT] $name ($id) | IP: $ip | Hash: $hash | Pirated: $pirated | Players: $total/16" },
    OnSpawn = { enable = false, log = "[SPAWN] $name spawned" },
    OnSwitch = { enable = false, log = "[SWITCH] $name switched to $team" },
    OnWarp = { enable = false, log = "[WARP] $name warped" },
    OnReset = { enable = true, log = "[RESET] Map reset: $map / $mode" },
    OnLogin = { enable = false, log = "[LOGIN] $name logged in" },
    OnSnap = { enable = true, log = "[SNAP] $name snapped" },
    OnCommand = { enable = true, log = "[$type CMD] $name ($id): $cmd" },
    OnChat = { enable = true, log = "[$type MSG] $name ($id): $msg" },

    OnScore = {
        [1] = { enable = false, log = "[SCORE] $name captured for $team | Red: $redScore Blue: $blueScore | Limit: $scorelimit" },
        [2] = { enable = false, log = "[SCORE] $name lap for $team | Lap: $lap_time | Team Laps: $totalTeamLaps | Limit: $scorelimit" },
        [3] = { enable = false, log = "[SCORE] $name lap done | Lap: $lap_time | Laps: $score/$scorelimit" },
        [4] = { enable = false, log = "[SCORE] $name scored for $team | Red: $redScore Blue: $blueScore | Limit: $scorelimit" },
        [5] = { enable = false, log = "[SCORE] $name scored | Score: $score/$scorelimit" }
    },

    OnDeath = {
        [1] = { enable = false, log = "[DEATH] $killerName drew first blood on $victimName" },
        [2] = { enable = false, log = "[DEATH] $victimName was killed from the grave by $killerName" },
        [3] = { enable = false, log = "[DEATH] $victimName was run over by $killerName" },
        [4] = { enable = false, log = "[DEATH] $victimName was killed by $killerName" },
        [5] = { enable = false, log = "[DEATH] $victimName committed suicide" },
        [6] = { enable = false, log = "[DEATH] $victimName was betrayed by $killerName" },
        [7] = { enable = false, log = "[DEATH] $victimName was squashed by a vehicle" },
        [8] = { enable = false, log = "[DEATH] $victimName fell to their death" },
        [9] = { enable = false, log = "[DEATH] $victimName was killed by the server" },
        [10] = { enable = false, log = "[DEATH] $victimName died" }
    }
}

-- Known CD-key hashes from pirated/cracked Halo copies.
-- Used to flag players with "$pirated = YES".
local KNOWN_PIRATED_HASHES = {
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

-- Configuration ends here -----------------------------------------------------------------------

local log_directory, log_file

local players = {}
local tick_rate = 1 / 30
local score_limit, gametype_base, gametype, mode, map
local ffa, falling, distance, first_blood

local command_type = {
    [0] = "RCON",
    [1] = "CONSOLE",
    [2] = "CHAT",
    [3] = "UNKNOWN",
}

local chat_type = {
    [0] = "GLOBAL",
    [1] = "TEAM",
    [2] = "VEHICLE",
    [3] = "UNKNOWN",
}

-- Gametype -> score event type mapping
local score_event = {
    ctf = function() return 1 end,
    race = function() return ffa and 3 or 2 end,
    slayer = function() return ffa and 5 or 4 end
}

local io_open = io.open
local os_date = os.date
local tonumber = tonumber
local string_format = string.format
local math_huge, math_floor = math.huge, math.floor
local read_byte, read_word, read_dword = read_byte, read_word, read_dword
local get_var, player_present, player_alive = get_var, player_present, player_alive
local get_player, get_dynamic_player = get_player, get_dynamic_player

local function openLog()
    if not log_file then
        local f, err = io_open(log_directory, 'a')
        if not f then
            print("Error opening log file: " .. err)
            return false
        end
        log_file = f
    end
    return true
end

local function writeToFile(content)
    if not openLog() then return false end
    log_file:write(content, '\n')
    log_file:flush()
    return true
end

local function formatLog(msg, args)
    return (msg:gsub("($[%w_]+)", args))
end

local function getEvent(name, event_type)
    local event = EVENTS[name]
    return event_type and event[event_type] or event
end

local function log(event_name, args)
    local event = getEvent(event_name, args and args.event_type)
    if not event or not event.enable then return end

    local formatted = formatLog(event.log, args)
    local timestamp = os_date(TIMESTAMP_FORMAT)
    local log_entry = string_format('[%s] %s', timestamp, formatted)
    writeToFile(log_entry)
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function getTeamPlay()
    return ffa and "FFA" or "Team Play"
end

local function getscorelimit()
    return read_byte(gametype_base + 0x58)
end

local function isPirated(hash)
    return KNOWN_PIRATED_HASHES[hash] and 'YES' or 'NO'
end

local function getPlayerData(player, quit)
    local total = tonumber(get_var(0, '$pn'))
    total = (quit and total - 1) or total

    return {
        ["$total"] = total,
        ["$name"] = player.name,
        ["$ip"] = player.ip,
        ["$hash"] = player.hash,
        ["$id"] = player.id,
        ["$lvl"] = player.level(),
        ["$ping"] = get_var(player.id, "$ping"),
        ["$pirated"] = isPirated(player.hash)
    }
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
        level = function()
            return tonumber(get_var(id, '$lvl'))
        end
    }
end

local function formatTime(lap_time)
    if gametype ~= "race" then return nil end
    if lap_time == 0 or lap_time == math_huge then return "00:00.000" end

    local total_ms = math_floor(lap_time * 1000 + 0.5)
    local minutes = math_floor(total_ms / 60000)
    total_ms = total_ms - minutes * 60000
    local seconds = math_floor(total_ms / 1000)
    local millis = total_ms - seconds * 1000

    return string_format("%02d:%02d.%03d", minutes, seconds, millis)
end

local function roundToHundredths(num)
    return math_floor(num * 100 + 0.5) / 100
end

local function getLapTicks(address)
    return address ~= 0 and read_word(address) or 0
end

local function isCommand(str)
    local c = str:sub(1, 1)
    return c == "/" or c == "\\"
end

local function inVehicle(id)
    local dyn = get_dynamic_player(id)
    return dyn ~= 0 and read_dword(dyn + 0x11C) ~= 0xFFFFFFFF
end

function OnStart(notifyFlag)
    gametype = get_var(0, "$gt")
    if gametype == 'n/a' then return end

    players = {}
    first_blood = true
    ffa = get_var(0, '$ffa') == '1'
    mode = get_var(0, "$mode")
    map = get_var(0, "$map")
    falling = getTag('jpt!', 'globals\\falling')
    distance = getTag('jpt!', 'globals\\distance')
    score_limit = getscorelimit()

    if not notifyFlag or notifyFlag == 0 then
        log("OnStart", {
            ["$map"] = map,
            ["$mode"] = mode,
            ["$gt"] = gametype,
            ["$ffa"] = getTeamPlay()
        })
    end

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i, notifyFlag)
        end
    end
end

function OnEnd()
    log("OnEnd", {
        ["$map"] = map,
        ["$mode"] = mode,
        ["$gt"] = gametype,
        ["$ffa"] = getTeamPlay()
    })
end

function OnJoin(id, notifyFlag)
    players[id] = newPlayer(id)

    if not notifyFlag or notifyFlag == 0 then
        log("OnJoin", getPlayerData(players[id]))
    end
end

function OnQuit(id)
    local player = players[id]
    if not player then return end

    log("OnQuit", getPlayerData(player, true))
    players[id] = nil
end

function OnSpawn(id)
    local player = players[id]
    if not player then return end

    player.last_damage = 0
    player.switched = nil
    log("OnSpawn", { ["$name"] = player.name })
end

function OnSwitch(id)
    local player = players[id]
    if not player then return end

    player.team = get_var(id, '$team')
    player.switched = true
    log("OnSwitch", { ["$name"] = player.name, ["$team"] = player.team })
end

function OnWarp(id)
    local player = players[id]
    if not player then return end

    log("OnWarp", { ["$name"] = player.name })
end

function OnReset()
    log("OnReset", {
        ["$map"] = map,
        ["$mode"] = mode,
        ["$gt"] = gametype,
        ["$ffa"] = getTeamPlay()
    })
end

function OnLogin(id)
    local player = players[id]
    if not player then return end

    log("OnLogin", { ["$name"] = player.name })
end

function OnSnap(id)
    local player = players[id]
    if not player then return end

    log("OnSnap", { ["$name"] = player.name })
end

function OnCommand(id, command, environment)
    local player = players[id]
    if not player then return true end

    log("OnCommand", {
        ["$lvl"] = player.level(),
        ["$name"] = player.name,
        ["$id"] = tostring(id),
        ["$type"] = command_type[environment],
        ["$cmd"] = command
    })
end

function OnChat(id, message, environment)
    local player = players[id]

    if player and not isCommand(message) then
        log("OnChat", {
            ["$type"] = chat_type[environment],
            ["$name"] = player.name,
            ["$id"] = id,
            ["$msg"] = message
        })
    end
end

function OnScore(id)
    local player = players[id]
    if not player then return end

    local red_score = get_var(0, "$redscore")
    local blue_score = get_var(0, "$bluescore")
    local lap_time = 0
    if gametype == "race" then
        lap_time = roundToHundredths(getLapTicks(get_player(id) + 0xC4) * tick_rate)
    end

    log("OnScore", {
        event_type = score_event[gametype](),
        ["$lap_time"] = formatTime(lap_time),
        ["$totalTeamLaps"] = player.team == "red" and red_score or blue_score,
        ["$score"] = get_var(id, "$score"),
        ["$name"] = player.name,
        ["$team"] = player.team or "FFA",
        ["$redScore"] = red_score,
        ["$blueScore"] = blue_score,
        ["$scorelimit"] = score_limit
    })
end

function OnDamage(victimIndex, _, metaId)
    local victim = players[tonumber(victimIndex)]
    if victim then victim.last_damage = metaId end
end

function OnDeath(victimIndex, killerIndex)
    local victim = tonumber(victimIndex)
    local victim_data = players[victim]
    if not victim_data then return end

    local killer = tonumber(killerIndex)
    local killer_data = killer and players[killer]

    local event_type = 10

    if killer == -1 and not victim_data.switched then
        event_type = (victim_data.last_damage == falling or victim_data.last_damage == distance) and 8 or 9
    elseif killer == 0 then
        event_type = 7
    elseif killer and killer > 0 then
        if killer == victim then
            event_type = 5
        elseif not ffa and killer_data and victim_data.team == killer_data.team then
            event_type = 6
        elseif first_blood then
            first_blood, event_type = false, 1
        elseif not player_alive(killer) then
            event_type = 2
        elseif inVehicle(victim) then
            event_type = 3
        else
            event_type = 4
        end
    end

    log("OnDeath", {
        event_type = event_type,
        ["$killerName"] = killer_data and killer_data.name or "",
        ["$victimName"] = victim_data.name
    })
end

function OnScriptLoad()
    gametype_base = read_dword(sig_scan("B9360000008BF3BF78545F00") + 0x8)

    local directory = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    log_directory = directory .. LOG_FILE

    register_callback(cb.EVENT_CHAT, 'OnChat')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_SCORE, 'OnScore')
    register_callback(cb.EVENT_DAMAGE_APPLICATION, 'OnDamage')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_SNAP, 'OnSnap')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_LOGIN, 'OnLogin')
    register_callback(cb.EVENT_MAP_RESET, "OnReset")
    register_callback(cb.EVENT_TEAM_SWITCH, 'OnSwitch')

    OnStart(1) -- in case script is loaded mid-game
end

function OnScriptUnload()
    if log_file then
        log_file:close()
        log_file = nil
    end
end
