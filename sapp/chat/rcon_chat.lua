--[[
=====================================================================================
SCRIPT NAME:      rcon_chat.lua
DESCRIPTION:      Redirects in-game chat messages to RCON with customizable formatting.
                  Supports global, team, and vehicle chat modes.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local chat = {

    --
    -- RCON output format:
    --

    -- Global:
    [0] = '$name [$id]: $msg',

    -- Team:
    [1] = '[$name] [$id]: $msg',

    -- Vehicle:
    [2] = '[$name] [$id]: $msg',

    -- Messages containing these keywords will not trigger chat formatting:
    --
    ignore_list = {
        'rtv',
        'skip'
    }
}

api_version = '1.12.0.0'

local ffa
local players = {}

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, 'OnChat')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_TEAM_SWITCH, 'OnTeamSwitch')
    OnStart()
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then
        ffa = (get_var(0, '$ffa') == '1')
        players = {}

        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function OnJoin(Ply)
    players[Ply] = { team = get_var(Ply, '$team'), name = get_var(Ply, '$name') }
end

function OnQuit(Ply)
    players[Ply] = nil
end

function OnTeamSwitch(Ply)
    local p = players[Ply]
    p.team = get_var(Ply, '$team')
end

local function IsCommand(s)
    return (s:sub(1, 1) == '/' or s:sub(1, 1) == '\\')
end

local function Ignore(s)
    for i = 1, #chat.ignore_list do
        local word = chat.ignore_list[i]
        if (s:sub(1, word:len()) == word) then
            return true
        end
    end
    return false
end

local function FormatMsg(Ply, Content, Type)
    local new_message = chat[Type]

    local player = players[Ply]
    new_message = new_message:gsub('$name', player.name):gsub('$id', Ply):gsub('$msg', Content)

    return new_message
end

local function Global(str)
    for i, _ in pairs(players) do
        rprint(i, str)
    end
end

local function Team(sender, str)
    for i, v in pairs(players) do
        if (v.team == sender.team) then
            rprint(i, str)
        end
    end
end

local function GetVehicle(Ply)
    local dyn = get_dynamic_player(Ply)
    if (dyn ~= 0 and player_alive(Ply)) then
        local vehicle = read_dword(dyn + 0x11C)
        local object = get_object_memory(vehicle)
        return (vehicle ~= 0xFFFFFFFF and object ~= 0 and object)
    end
    return false
end

local function Vehicle(Ply, str)
    local senderVehicle = GetVehicle(Ply)
    if (not senderVehicle) then
        rprint(Ply, 'You are not in a vehicle')
        return false
    end

    for i, _ in pairs(players) do
        local playerVehicle = GetVehicle(i)
        if (playerVehicle == senderVehicle) then
            rprint(i, str)
        end
    end
end

function OnChat(Ply, Msg, Type)
    if (not IsCommand(Msg) and not Ignore(Msg)) then
        Msg = FormatMsg(Ply, Msg, Type)

        if (ffa) then
            Global(Msg)
            return false
        end

        -- Global:
        if (Type == 0) then
            Global(Msg)

            -- Team:
        elseif (Type == 1) then
            Team(players[Ply], Msg)

            -- Vehicle:
        elseif (Type == 2) then
            Vehicle(Ply, Msg)
        end

        return false
    end
end

function OnScriptUnload()
    -- N/A
end
