--[[
=====================================================================================
SCRIPT NAME:      notify_me.lua
DESCRIPTION:      Advanced console notification system.
                  - Customizable timestamp formatting
                  - ASCII art logo display
                  - Support for all major server events
                  - Dynamic message templates with placeholder substitution
                  - Configurable output for each event type
                  - First blood detection
                  - Detailed death cause reporting

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/HALO-SCRIPT-PROJECTS/blob/master/LICENSE
=====================================================================================
]]

-- Configuration starts here -----------------------------------------------------------------------

--
-- Event message templates | Format: { "Message", notify? }
--

local EVENTS = {
    OnStart = { "[START] New game on $map - $mode $gt ($ffa) $scorelimit", true },
    OnEnd = { "[END] Game ended", true },
    OnJoin = { "[JOIN] $name ($id) | $ip | $hash | Pirated: $pirated | $total/16", true },
    OnQuit = { "[QUIT] $name ($id) | $ip | $hash | Pirated: $pirated | $total/16", true },
    OnSpawn = { "[SPAWN] $name spawned", false },
    OnSwitch = { "[SWITCH] $name switched to $team team", true },
    OnCommand = { "[CMD] $name ($id): $cmd", true },
    OnChat = { "[MSG] $name ($id): $msg", true },
    OnDeath = {
        [1] = { "$k_name drew first blood on $v_name", true },
        [2] = { "$v_name was killed from the grave by $k_name", true },
        [3] = { "$v_name was run over by $k_name", true },
        [4] = { "$v_name was killed by $k_name", true },
        [5] = { "$v_name committed suicide", true },
        [6] = { "$v_name was betrayed by $k_name", true },
        [7] = { "$v_name was squashed by a vehicle", true },
        [8] = { "$v_name fell to their death", true },
        [9] = { "$v_name was killed by the server", true },
        [10] = { "$v_name died", true } -- generic
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
    ['3126fab3615a94119d5fe9eead1e88c1'] = true,
}

-- Logo template | Format: { "Message" }
local LOGO = {
    true, -- set to false to disable logo
    {
        { "================================================================================" },
        { "$timeStamp" },
        { "" },
        { "     '||'  '||'     |     '||'       ..|''||           ..|'''.| '||''''|" },
        { "      ||    ||     |||     ||       .|'    ||        .|'     '   ||  ." },
        { "      ||''''||    |  ||    ||       ||      ||       ||          ||''|" },
        { "      ||    ||   .''''|.   ||       '|.     ||       '|.      .  ||" },
        { "     .||.  .||. .|.  .||. .||.....|  ''|...|'         ''|....'  .||.....|" },
        { "              ->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-" },
        { "                                     $serverName" },
        { "              ->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-" },
        { "" },
        { "================================================================================" }
    }
}

-- End of Configuration ----------------------------------------------------------

local players = {}
local first_blood = true
local ffa = false
local gametype = ""
local mode, map = "", ""
local score_limit = 0
local gametype_base

local os_date = os.date
local tostring, tonumber = tostring, tonumber

local function format(template, args)
    if not args then return template end

    return (template:gsub("%$([%w_]+)", function(key)
        local value = args[key] or args[key:lower()] or args[key:upper()]
        return value ~= nil and tostring(value) or "$" .. key
    end))
end

local fmt_log = format

function show_ASCII_art()
    if not LOGO[1] then return end

    local args = {
        timestamp = os_date('!%a %d %b %Y %H:%M:%S'),
        servername = getservername()
    }

    for _, line in ipairs(LOGO[2]) do
        hprintf(format(line[1], args))
    end
end

local function is_pirated(hash)
    return KNOWN_PIRATED_HASHES[hash] and "YES" or "NO"
end

local function is_alive(id)
    if not id then return false end
    return getplayerobjectid(id) ~= nil
end

local function get_team_play()
    return ffa and "FFA" or "Team"
end

local function is_command(str)
    return str:sub(1, 1) == "/" or str:sub(1, 1) == "\\"
end

local function get_scorelimit()
    return readbyte(gametype_base + 0x58)
end

local function log(event_name, args)
    local event = EVENTS[event_name]
    if not event then return end

    local data = args and args.event_type and event[args.event_type] or event
    if data and data[2] then
        hprintf(fmt_log(data[1], args))
    end
end

local function get_player_data(id, leaving)
    local p = players[id]
    if not p then return end

    return {
        total = #players - (leaving and 1 or 0),
        name = p.name,
        ip = p.ip,
        hash = p.hash,
        id = id,
        pirated = is_pirated(p.hash)
    }
end

local function parse_gametype()
    local type = readbyte(gametype_base + 0x30)
    return type == 0 and "none" or type == 1 and "ctf" or type == 2 and "slayer" or type == 3 and "oddball" or
        type == 4 and "king" or type == 5 and "race"
end

local function get_player(player)
    if not player then return nil end
    local id = resolveplayer(player)
    return id and players[id] or nil
end

function OnScriptLoad(_, game, _)
    gametype_base = (game == "PC" and 0x671340) or 0x5F5498
    show_ASCII_art()
end

function OnNewGame(map_name, unknown_var)
    first_blood = true
    players = {}
    ffa = (readbyte(gametype_base + 0x34) == 0) -- 0 = FFA, 1 = Team
    mode = readstring(gametype_base, 0x2C)
    gametype = parse_gametype()
    score_limit = get_scorelimit()
    map = map_name

    log("OnStart", {
        map = map,
        mode = mode,
        gt = gametype,
        ffa = get_team_play(),
        scorelimit = score_limit
    })

    -- Notify about players already present after game load
    for i = 0, 15 do
        if getplayer(i) then OnPlayerJoin(i) end
    end
end

function OnGameEnd()
    log("OnEnd", {
        map = map,
        mode = mode,
        gt = gametype,
        ffa = get_team_play()
    })
end

function OnPlayerJoin(player)
    local id = resolveplayer(player)
    local p = {
        id = id,
        ip = getip(player),
        name = getname(player),
        hash = gethash(player),
        switched = false
    }
    players[id] = p
    log("OnJoin", get_player_data(id))
end

function OnPlayerLeave(id)
    local player = get_player(id)
    if player then
        log("OnQuit", get_player_data(id, true))
        players[id] = nil
    end
end

function OnPlayerSpawn(id)
    local player = get_player(id)
    if player then
        log("OnSpawn", { name = player.name })
    end
end

local function parse_team(team)
    return (team == 0 and "Blue" or team == 1 and "Red") or "N/A"
end

function OnTeamChange(id, _, new_team, _)
    local player = get_player(id)
    if player then
        player.switched = true
        local team_name = parse_team(new_team)
        log("OnSwitch", { name = player.name, team = team_name })
    end
end

function OnPlayerKill(killer, victim, mode)
    -- Kill modes:
    -- 0 = server           1 = falling/team-change
    -- 2 = guardians        3 = vehicle
    -- 4 = player           5 = teammate
    -- 6 = suicide

    local victim_data = get_player(victim)
    if not victim_data then return end

    local event_type = 10 -- default: generic death
    local killer_data = get_player(killer)

    if mode == 0 then
        event_type = 9 -- server
    elseif mode == 1 then
        if victim_data.switched then return end
        event_type = 8    -- fall damage
    elseif mode == 2 then
        event_type = 10   -- guardians (generic)
    elseif mode == 3 then
        event_type = 7    -- squashed by vehicle
    elseif mode == 4 then -- pvp
        if first_blood then
            first_blood = false
            event_type = 1 -- first blood
        elseif not killer or not is_alive(killer) then
            event_type = 2 -- from the grave
        else
            event_type = 4 -- normal kill
        end
    elseif mode == 5 then
        event_type = 6 -- betrayal
    elseif mode == 6 then
        event_type = 5 -- suicide
    end

    log("OnDeath", {
        event_type = event_type,
        k_name = killer_data and killer_data.name or "",
        v_name = victim_data.name
    })
end

function OnServerCommand(id, command)
    if not id then return end
    local player = get_player(tonumber(id))
    if player then
        log("OnCommand", {
            name = player.name,
            id = id,
            cmd = command
        })
    end
end

function OnServerChat(id, _, message)
    local player = get_player(id)
    if player then
        local command = is_command(message)
        log(command and "OnCommand" or "OnChat", {
            name = player.name,
            id = id,
            cmd = message,
            msg = message
        })
        if command then return false end -- prevents command feedback
    end
end

function GetRequiredVersion() return 200 end
