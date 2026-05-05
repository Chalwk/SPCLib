--[[
=====================================================================================
SCRIPT NAME:      set_respawn_time.lua
DESCRIPTION:      Configurable respawn timer system with per-map/per-gametype settings
                  and real-time adjustments via admin commands.

FEATURES:
                  - Map/gametype specific respawn times
                  - Global and per-player time settings
                  - Silent command execution option
                  - Default fallback time for unlisted maps

COMMANDS:
                  /setrespawn <time>          - Set global respawn time (seconds)
                  /setrespawn <pid> <time>   - Set time for specific player
                  /setrespawn all <time>      - Set time for all players
                  Add "-s" flag for silent execution

CONFIGURATION:
                  - command:        Admin command name
                  - permission_level: Required admin level
                  - default_respawn_time: Fallback time (seconds)
                  - maps:           Per-map gametype settings table
                    Format: ["mapname"] = {ctf, slayer_ffa, slayer_team, koth_ffa, koth_team, ...}

EXAMPLE MAP CONFIG:
                  ["bloodgulch"] = {
                      3.0, -- CTF
                      1,   -- Slayer (FFA)
                      3.0, -- Slayer (Team)
                      3.0, -- KOTH (FFA)
                      3.0  -- KOTH (Team)
                  }

Copyright (c) 2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration Starts --
local SRT = {

    -- Custom command used to manually change global/player respawn time
    command = "setrespawn",

    -- Minimum level required to execute "command"
    permission_level = 1,

    -- The "-s" parameter is optional.
    -- If you specify the "-s" flag, your command will be executed silently.
    -- This means the target player will not receive the "[Command Executor name]
    -- set your respawn time to X seconds" message.
    silent_flag = "-s",

    -- If map is not listed below, it will use this global default respawn time (in seconds):
    default_respawn_time = 3,

    maps = {
        --	CTF | SLAYER | TEAM-S | KOTH | TEAM-KOTH | ODDBALL | TEAM-ODDBALL | RACE | TEAM-RACE
        ["beavercreek"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["bloodgulch"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["boardingaction"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["carousel"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["dangercanyon"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["deathisland"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["chillout"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["gephyrophobia"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["icefields"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["infinity"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["sidewinder"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["timberland"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["hangemhigh"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["ratrace"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["damnation"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["putput"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["prisoner"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["wizard"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
        ["longest"] = { 3.0, 1, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0 },
    },

    -- A message relay function temporarily removes the server prefix
    -- and will restore it to this when the relay is finished
    serverPrefix = "**SAPP**",
}
-- Configuration Ends --

api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb['EVENT_DIE'], "OnPlayerDeath")
    register_callback(cb['EVENT_JOIN'], "OnPlayerJoin")
    register_callback(cb['EVENT_LEAVE'], "OnPlayerQuit")
    register_callback(cb['EVENT_GAME_START'], "OnNewGame")
    register_callback(cb['EVENT_COMMAND'], "OnServerCommand")
    OnNewGame()
end

function OnNewGame()
    if (get_var(0, "$gt") ~= "n/a") then
        SRT.players = { }
        SRT.team_play = (get_var(0, "$ffa") == "0") or false
        SRT.global_respawn_time = SRT:GetRespawnTime()
        for i = 1, 16 do
            if player_present(i) then
                SRT:InitPlayer(i, false)
            end
        end
    end
end

function SRT:InitPlayer(Ply, Reset)
    if (not Reset) then
        self.players[Ply] = {
            name = get_var(Ply, "$name"),
            time = self.global_respawn_time
        }
        return
    end
    self.players[Ply] = nil
end

function OnPlayerJoin(Ply)
    SRT:InitPlayer(Ply, false)
end
function OnPlayerQuit(Ply)
    SRT:InitPlayer(Ply, true)
end

function OnPlayerDeath(Ply)
    local player = get_player(Ply)
    if (player ~= 0) then
        write_dword(player + 0x2C, SRT.players[Ply].time * 33)
    end
end

function SRT:GetRespawnTime()

    local map = get_var(0, "$map")
    if (self.maps[map]) then

        for k, v in pairs(self.maps) do
            if (k == map) then
                local gt = get_var(0, "$gt")
                if (gt == "ctf") then
                    return v[1]
                elseif (gt == "slayer") then
                    if (not self.team_play) then
                        return v[2]
                    else
                        return v[3]
                    end
                elseif (gt == "koth") then
                    if (not self.team_play) then
                        return v[4]
                    else
                        return v[5]
                    end
                elseif (gt == "oddball") then
                    if (not self.team_play) then
                        return v[6]
                    else
                        return v[7]
                    end
                elseif (gt == "race") then
                    if (not self.team_play) then
                        return v[8]
                    else
                        return v[9]
                    end
                end
            end
        end
    end
    return self.default_respawn_time
end

local function Plural(n)
    return (n > 1 and "s") or ""
end

local function Respond(Ply, Msg, Clear)

    if (Ply == 0) then
        cprint(Msg)
        return
    end

    if (Clear) then
        for _ = 1, 25 do
            rprint(Ply, " ")
        end
    end
    rprint(Ply, Msg)
end

local function CMDSplit(CMD)
    local Args = { }
    for Params in CMD:gmatch("([^%s]+)") do
        Args[#Args + 1] = Params:lower()
    end
    return Args
end

function SRT:OnCommand(Ply, CMD, _, _)
    local Args = CMDSplit(CMD)
    local case = (Args and Args[1])
    if (case and Args[1] == self.command) then

        local lvl = tonumber(get_var(Ply, "$lvl"))
        if (lvl >= self.permission_level or Ply == 0) then
            if (Args[2]) then
                local time = tonumber(Args[2]:match("%d+"))
                if (Args[3] == nil) then
                    Respond(Ply, "Global respawn time set to " .. time .. " second" .. Plural(time))
                    for i = 1, 16 do
                        if player_present(i) then
                            self.players[i].time = time
                            OnPlayerDeath(i)
                        end
                    end
                elseif (Args[3]:match("%d+")) then
                    local pl = GetPlayers(Ply, Args)
                    if (#pl > 0) then
                        time = tonumber(Args[3]:match("%d+"))
                        for i = 1, #pl do
                            local TID = tonumber(pl[i])
                            self.players[TID].time = time
                            local name = self.players[TID].name
                            OnPlayerDeath(TID)
                            Respond(Ply, "Respawn time for " .. name .. " set to " .. time .. " second" .. Plural(time))
                        end
                    end
                else
                    Respond(Ply, "Invalid Time! Please try again.")
                end
            else
                Respond(Ply, "Invalid Command Argument.")
                Respond(Ply, "Usage: /" .. self.command .. " <time> or " .. self.command .. " <pid> <time> <-s>")
            end
        else
            Respond(Ply, "You do not have permission to execute that command")
        end
        return false
    end
end

function GetPlayers(Ply, Args)

    local players = { }
    local TID = Args[2]

    if (TID == nil or TID == "me") then
        table.insert(players, Ply)
    elseif (TID == "all" or TID == "*") then
        for i = 1, 16 do
            if player_present(i) then
                table.insert(players, i)
            end
        end
    elseif (TID:match("%d+") and tonumber(TID:match("%d+")) > 0) then
        if player_present(TID) then
            table.insert(players, TID)
        else
            Respond(Ply, "Player #" .. TID .. " is not online!")
        end
    else
        Respond(Ply, "Invalid Target ID Parameter")
        Respond(Ply, 'Usage: "me", "all", "*" or [pid between 1-16]')
    end

    return players
end

function OnServerCommand(P, C)
    return SRT:OnCommand(P, C)
end

function OnScriptUnload()
    --
end
