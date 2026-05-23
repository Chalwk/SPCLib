--[[
=====================================================================================
SCRIPT NAME:      play_time.lua
DESCRIPTION:      Comprehensive player session tracking and statistics system

FEATURES:
                  - Tracks total connection time and join counts
                  - Detailed time breakdown (years/weeks/days/hours/minutes/seconds)
                  - Multiple query options:
                    * Individual players (/playtime <ID>)
                    * All players (/playtime all)
                    * Self-check (/playtime me)
                  - Persistent JSON data storage
                  - Automatic tracking on join/leave

CONFIGURATION:
                  command:          Primary command trigger (default: "playtime")
                  permission:       Minimum admin level required (default: 1)
                  output:           Customizable response templates
                  ClientIndexType:  Player identification method (1=IP:PORT, 2=IP, 3=Hash)

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

USAGE EXAMPLES:
                  /playtime         (shows your own stats)
                  /playtime 3       (shows stats for player ID 3)
                  /playtime all     (shows stats for all players)

Copyright (c) 2020-2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local TimePlayed = {
    -- Custom command used to check playtime & join count:
    --
    command = "playtime",
    -- Minimum permission lvl required to execute "/playtime"
    --
    permission = 1,
    -- During what events should the PlayTime.json database be updated?
    --
    update_file_database = {
        ["event_join"] = true,
        ["event_leave"] = true,
        ["event_game_end"] = true
    },
    -- Custom messages seen when checking playtime:
    --
    output = {
        -- Your playtime:
        --
        {
            "-------- [ Your Playtime ] --------",
            "Years: %Y%, Weeks: %W%, Days: %D%",
            "Hours: %H%, Minutes: %M%, Seconds: %S%",
            " ", -- line break
            "You have joined %joins% time%s%"
        },
        -- Someone else's playtime:
        --
        {
            "-------- [ %name%'s Playtime ] --------",
            "Years: %Y%, Weeks: %W%, Days: %D%",
            "Hours: %H%, Minutes: %M%, Seconds: %S%",
            " ", -- line break
            "%name% has joined %joins% time%s%"
        }
    },
    -- ADVANCED USERS ONLY:
    --
    --
    -- A JSON database containing player stats.
    -- This file will be located in the server's root directory.
    --
    dir = "PlayTime.json",
    -- Client data is saved as a json array.
    -- The array index for each client will either be "IP", or "IP:PORT" or the players Hash.
    -- Set to 1 for IP:PORT indexing.
    -- Set to 2 for IP-only indexing.
    -- Set to 3 for hash-only indexing (not recommended at all).
    --
    ClientIndexType = 1
}

-- Preload JSON Interpreter Library:
--
local json = (loadfile "json.lua")()

function OnScriptLoad()
    -- register needed event callbacks:
    --

    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_JOIN, "OnPlayerConnect")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
    register_callback(cb.EVENT_LEAVE, "OnPlayerDisconnect")
    --

    TimePlayed:CheckFile(true)
end

function OnScriptUnload()
    TimePlayed:UpdateJSON()
end

function OnGameStart()
    TimePlayed:CheckFile()
end

function OnGameEnd()
    TimePlayed:UpdateJSON("event_game_end")
end

function TimePlayed:UpdateJSON(TYPE)
    -- saves local database (self.database) to self.dir:
    --
    if (self.update_file_database[TYPE]) then
        local db = self:GetLocalDB()
        if (db) then
            local file = assert(io.open(self.dir, "w"))
            if (file) then
                file:write(json:encode_pretty(db))
                file:close()
            end
        end
    end
end

function OnPlayerConnect(Ply)
    TimePlayed:AddNewPlayer(Ply, false)
end

function OnPlayerDisconnect(Ply)
    TimePlayed:UpdateJSON("event_leave")
    TimePlayed.players[Ply ~= nil and Ply] = nil
end

function TimePlayed:AddNewPlayer(Ply, ManualLoad)
    local index = self:GetClientIndex(Ply)
    local name = get_var(Ply, "$name")

    local db = self.database
    if (db[index] == nil) then
        db[index] = {
            time = 0,  -- set initial play time to zero
            joins = 0, -- set initial joins to zero
            name = name
        }
    end

    self.database = db

    self.players[Ply] = {}
    self.players[Ply] = db[index]
    self.players[Ply].name = name -- update name
    self.players[Ply].joins = db[index].joins + 1 -- match joins on file (+1)
    self.players[Ply].time = db[index].time -- match time on file (last known time)

    self.play_time[Ply] = os.time()

    -- false when called from OnPlayerConnect()
    if (not ManualLoad) then
        self:UpdateJSON("event_join")
    end
end

function TimePlayed:GetLocalDB()
    local db = self.database
    if (db) then
        for i = 1, 16 do
            -- update self.database:
            --
            if (player_present(i) and self.players[i]) then
                local time = os.time() - self.play_time[i]
                self.players[i].time = self.players[i].time + time

                db[self:GetClientIndex(i)] = self.players[i]
            end
        end
    end

    return db -- return self.database
end

-- Converts seconds to time format:
--
local function secondsToTime(seconds)
    local years = math.floor(seconds / (60 * 60 * 24 * 365))
    seconds = seconds % (60 * 60 * 24 * 365)
    local weeks = math.floor(seconds / (60 * 60 * 24 * 7))
    seconds = seconds % (60 * 60 * 24 * 7)
    local days = math.floor(seconds / (60 * 60 * 24))
    seconds = seconds % (60 * 60 * 24)
    local hours = math.floor(seconds / (60 * 60))
    seconds = seconds % (60 * 60)
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    return years, weeks, days, hours, minutes, seconds
end

local function FormatMessage(y, w, d, h, m, s, n, j)
    return {
        ["%%Y%%"] = y,     -- years
        ["%%W%%"] = w,     -- weeks
        ["%%D%%"] = d,     -- days
        ["%%H%%"] = h,     -- hours
        ["%%M%%"] = m,     -- minutes
        ["%%S%%"] = s,     -- seconds
        ["%%name%%"] = n,  -- name
        ["%%joins%%"] = j, -- joins
        -- determine pluralize word (join):
        ["%%s%%"] = function ()
            return (j > 1 and "s") or ""
        end
    }
end

function TimePlayed:OnCommand(Ply, CMD)
    local Args = {}
    for Params in CMD:gmatch("([^%s]+)") do
        Args[#Args + 1] = Params:lower()
    end

    if (#Args > 0) then
        local lvl = tonumber(get_var(Ply, "$lvl"))

        if (Args[1] == self.command) then
            if (lvl >= self.permission or Ply == 0) then
                local pl = self:GetPlayers(Ply, Args)
                if pl then
                    for i = 1, #pl do
                        local TID = tonumber(pl[i])
                        local name = self.players[TID].name
                        local joins = self.players[TID].joins

                        local session_time = self.play_time[TID]
                        local time_on_file = self.players[TID].time
                        local time = (os.time() + time_on_file) - session_time

                        local y, w, d, h, m, s = secondsToTime(time)
                        local str_format = FormatMessage(y, w, d, h, m, s, name, joins)

                        local output_list = (Ply == TID and self.output[1] or self.output[2])

                        for _, str in pairs(output_list) do
                            local formatted = str

                            for k, v in pairs(str_format) do
                                formatted = formatted:gsub(k, v)
                            end

                            self:Respond(Ply, formatted)
                        end
                    end
                end
            else
                self:Respond(Ply, "You do not have permission to execute this command!")
            end

            return false
        end
    end
end

function TimePlayed:Respond(Ply, Msg)
    if (Ply == 0) then
        cprint(Msg)
    else
        rprint(Ply, Msg)
    end
end

function TimePlayed:GetClientIndex(Ply)
    local ip = get_var(Ply, "$ip")

    -- ip:port
    --
    if (self.ClientIndexType == 1) then
        ip = ip or self.players[Ply].ip

        -- ip only
        --
    elseif (self.ClientIndexType == 2) then
        ip = ip:match("%d+.%d+.%d+.%d+")

        -- hash
        --
    elseif (self.ClientIndexType == 3) then
        return get_var(Ply, "$hash")
    end

    return ip
end

function TimePlayed:GetPlayers(Ply, Args)
    local pl = {}
    if (Args[2] == "me" or Args[2] == nil) then
        if (Ply ~= 0) then
            table.insert(pl, Ply)
        else
            self:Respond(Ply, "Please enter a valid player id (#1-16)")
        end
    elseif (Args[2] ~= nil and Args[2]:match("^%d+$")) then
        if player_present(Args[2]) then
            table.insert(pl, Args[2])
        else
            self:Respond(Ply, "Player #" .. Args[2] .. " is not online")
        end
    elseif (Args[2] == "all" or Args[2] == "*") then
        for i = 1, 16 do
            if player_present(i) then
                table.insert(pl, i)
            end
        end
        if (#pl == 0) then
            self:Respond(Ply, "There are no players online!")
        end
    else
        self:Respond(Ply, "Invalid Command Syntax. Please try again!")
    end
    return pl
end

function TimePlayed:CheckFile(ScriptLoad)
    if (ScriptLoad) then
        self.database = nil
    end

    self.players, self.play_time = {}, {}
    self.game_started = false

    if (get_var(0, "$gt") ~= "n/a") then
        self.game_started = true

        if (self.database == nil) then
            -- Check if self.dir exists (create if not):
            --
            local content = ""
            local file = io.open(self.dir, "r")
            if (file) then
                content = file:read("*all")
                file:close()
            end

            -- Load an existing database or create a new one:
            --
            local db = json:decode(content)
            if (not db) then
                file = assert(io.open(self.dir, "w"))
                if (file) then
                    db = {}
                    file:write(json:encode_pretty(db))
                    file:close()
                end
            end

            self.database = db

            for i = 1, 16 do
                if player_present(i) then
                    self:AddNewPlayer(i, true)
                end
            end
        end
    end
end

function OnServerCommand(P, C)
    return TimePlayed:OnCommand(P, C)
end
