--[[
=====================================================================================
SCRIPT NAME:      proximity_chat.lua
DESCRIPTION:      Implements proximity-based voice chat with configurable range.
                  - Per-map range customization
                  - Adjustable range via admin command
                  - Configurable chat behavior for dead players
                  - Custom chat message formatting

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- configuration starts  --
-- Custom command used to change the chat range:
local command = "chatrange"

-- Minimum permission level required to execute /command (see above).
local permission_level = 1

-- 1 world unit = 10 feet or ~3.048 meters.
-- If the map is not listed below, the script will use this range:
local default_range = 8

-- Set the default range on a per-map basis:
local maps = {
    ["beavercreek"] = 8,
    ["bloodgulch"] = 8,
    ["boardingaction"] = 8,
    ["carousel"] = 8,
    ["chillout"] = 8,
    ["damnation"] = 8,
    ["dangercanyon"] = 8,
    ["deathisland"] = 8,
    ["gephyrophobia"] = 8,
    ["hangemhigh"] = 8,
    ["icefields"] = 8,
    ["infinity"] = 8,
    ["longest"] = 8,
    ["prisoner"] = 8,
    ["putput"] = 8,
    ["ratrace"] = 8,
    ["sidewinder"] = 8,
    ["timberland"] = 8,
    ["wizard"] = 8,

    -- repeat the structure to add more entries:
}


-- Allow dead players to talk?
-- Note: Players who are dead have infinite range.
local talk_while_dead = true

-- Talk to dead players?
-- Note: Players who are dead have infinite range.
local talk_to_dead_players = true

-- Chat Output Format:
local on_chat = {

    -- Global:
    [0] = "%name%: %message%",

    -- Team:
    [1] = "[%name%]: %message%",

    -- Vehicle:
    [2] = "[%name%]: %message%",
}

-- A message relay function temporarily removes the server prefix
-- and will restore it to this when the relay is finished
local server_prefix = "**SAPP**"

-- configuration ends --

api_version = "1.12.0.0"

local team_play
local current_range
local sqrt = math.sqrt
local gsub = string.gsub
local gmatch, lower = string.gmatch, string.lower

function OnScriptLoad()
    register_callback(cb["EVENT_CHAT"], "OnPlayerChat")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    register_callback(cb["EVENT_COMMAND"], "OnServerCommand")
    OnGameStart()
end

local function Respond(Ply, Str, Color)
    Color = Color or 12
    if (Ply == 0) then
        cprint(Str, Color)
    else
        say(Ply, Str)
    end
end

local function TeamPlay()
    if (get_var(0, "$ffa") == "0") then
        return true
    end
    return false
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        team_play = TeamPlay()

        local map = get_var(0, "$map")
        current_range = maps[map] or default_range
    end
end

local function GetXYZ(Ply)
    local pos = { }
    local DyN = get_dynamic_player(Ply)
    if (DyN ~= 0) then
        local VehicleID = read_dword(DyN + 0x11C)
        local VehicleObject = get_object_memory(VehicleID)
        if (VehicleID == 0xFFFFFFFF) then
            pos.invehicle = false
            pos.x, pos.y, pos.z = read_vector3d(DyN + 0x5c)
        elseif (VehicleObject ~= 0) then
            pos.invehicle = true
            pos.x, pos.y, pos.z = read_vector3d(VehicleObject + 0x5c)
        end
    end
    return pos
end

local function GetPlayers(Talker, Type)

    local pl = { }
    local TalkerTeam = get_var(Talker, "$team")

    -- Team Chat -> Team Play [0]
    local case1 = (Type == 1 and team_play)

    -- Vehicle Chat -> Team Play [1]
    local case2 = (Type == 2 and team_play)

    for i = 1, 16 do
        if player_present(i) and (i ~= Talker) then
            local pos = GetXYZ(i)
            if (case1 or case2) then

                if (case2 and not pos.invehicle) then
                    goto next
                end

                local team = get_var(i, "$team")
                if (team == TalkerTeam) then
                    pl[i] = { pos = pos }
                end
            else
                pl[i] = { pos = pos }
            end
            :: next ::
        end
    end

    return pl
end

local function WithinRange(pX, pY, pZ, X, Y, Z)
    return (sqrt((pX - X) ^ 2 + (pY - Y) ^ 2 + (pZ - Z) ^ 2) <= current_range)
end

local function FormatMsg(Talker, Msg, Type)

    local name = get_var(Talker, "$name")
    Msg = gsub(gsub(on_chat[Type], "%%name%%", name), "%%message%%", Msg)

    return Msg
end

local function SendRangedText(Ply, Msg)
    execute_command("msg_prefix \"\"")
    say(Ply, Msg)
    execute_command("msg_prefix \" " .. server_prefix .. "\"")
end

local function isCommand(m)
    return (m:sub(1, 1) == "/" or m:sub(1, 1) == "\\")
end

function OnPlayerChat(Ply, Msg, Type)

    if (not isCommand(Msg)) then

        -- Get talker position (returns false if dead)
        local TalkerPos = GetXYZ(Ply)
        if (TalkerPos) then

            -- Get all player positions (excluding talker)
            local players = GetPlayers(Ply, Type)
            if (players) then

                -- Send talker their own message:
                SendRangedText(Ply, FormatMsg(Ply, Msg, Type))

                local px, py, pz = TalkerPos.x, TalkerPos.y, TalkerPos.z

                -- Loop through all available players:
                for i, v in pairs(players) do
                    if (v.pos) then

                        -- Check player is within range of talker & send them the message:
                        local x, y, z = v.pos.x, v.pos.y, v.pos.z
                        if WithinRange(px, py, pz, x, y, z) then
                            SendRangedText(i, FormatMsg(Ply, Msg, Type))
                        end
                        --

                    elseif (talk_to_dead_players) then
                        goto next
                    end
                end
                :: next ::
            else
                Respond(Ply, "[Message Blocked] No one within " .. current_range .. " world units!")
            end
        elseif (talk_while_dead) then
            return true
        end
        return false
    end
end

local function CMDSplit(CMD)
    local Args = { }
    for Params in gmatch(CMD, "([^%s]+)") do
        Args[#Args + 1] = lower(Params)
    end
    return Args
end

function OnServerCommand(Ply, CMD)
    local Args = CMDSplit(CMD)

    if (Args) and (Args[1] == command) then
        local lvl = tonumber(get_var(Ply, "$lvl"))
        if (lvl >= permission_level or Ply == 0) then
            if (Args[2]) then

                local range = tonumber(Args[2]:match("%d+"))

                if (range and range > 1) then
                    current_range = Args[2]
                    Respond(Ply, "New Chat Range: " .. Args[2], 10)
                elseif (range and range <= 1) then
                    Respond(Ply, "Please enter a range greater than 1", 12)
                else
                    Respond(Ply, "Invalid syntax. Usage: /" .. command ..  " [range (number)]",12)
                end
            else
                Respond(Ply, "Current Range: " .. current_range .. " | Default Range: " .. default_range, 10)
            end
        else
            Respond(Ply, "You do not have permission to execute this command.")
        end
        return false
    end
end