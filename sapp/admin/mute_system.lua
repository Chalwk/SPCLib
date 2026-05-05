--[[
=====================================================================================
SCRIPT NAME:      mute_system.lua
DESCRIPTION:      Advanced player mute management system with anti-spam protection.

FEATURES:
                  - Comprehensive mute functionality:
                    * Timed mutes with duration display
                    * Manual and automatic spam-based muting
                    * Whitelist system for protected players
                  - Anti-spam system with configurable thresholds
                  - Command whitelisting for muted players
                  - Persistent mute storage through game sessions
                  - Admin commands:
                    * /mute <pid> <time>
                    * /unmute <pid>
                    * /mutes (view active mutes)

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:   http://regex.info/blog/lua/json
                  - Page Browsing Lib: https://github.com/Chalwk/SPCLib/blob/master/misc/libraries/page_browsing_lib.lua

USAGE:
                  - Configure settings in the MuteSystem table
                  - Use admin commands to manage mutes
                  - System automatically handles spam detection

Copyright (c) 2020 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local MuteSystem = {

    -- Mute System Configuration --

    dir = "mutes.json",
    prefix = "[Mute System]",

    default_mute_time = 525600,

    -- MUTE SYSTEM COMMANDS:
    -- {command, permission level}:
    commands = {

        -- Command to mute a player.
        -- Syntax: /mute <pid> <opt time>
        [1] = { "mute", 1 },

        -- Command to un-mute a player.
        -- Syntax: /un-mute <pid>
        [2] = { "unmute", 1 },

        -- Command to show a list of all muted players:
        -- Syntax: /mutelist <-online/-offline>
        -- This command will display the mute-list table for players currently online by default.
        -- You can request to view mutes for offline players by invoking -offline parameter.
        [3] = { "mutes", 1 }
    },

    -- If true, muted players will only be able to execute the commands in this list:
    block_commands = true,
    command_whitelist = {
        "whatsnext",
        "usage",
        "unstfu",
        "stats",
        "stfu",
        "sv_stats",
        "report",
        "info",
        "lead",
        "list",
        "login",
        "clead",
        "about"
    },

    messages = {
        whitelisted = "%name% is immune and cannot be muted",
        mute = {
            spam = {
                "%name% was spam-muted by SERVER for:",
                "%time%"
            },
            manual = {
                "%name% was muted by %admin% for:",
                "%time%"
            }
        },

        unmute = "%name% was un-muted by %admin%",

        mute_list = {
            no_mutes = "There are no active mutes",
            header = "------ [ MUTE LIST ] ------",
            content = "[%mute_index%] %name% %ip%",
        },

        mute_reminder = {
            "- YOU ARE MUTED -",
            "Time Remaining:",
            "%s"
        }
    },

    anti_spam = {
        -- Enable or disable Anti Spam:
        enabled = true,
        -- Amount of messages sent in a row that will trigger a warning;
        warnThreshold = 4,
        -- Amount of messages sent in a row that will trigger punishment:
        punishThreshold = 5,
        -- Amount of time (in seconds) in which messages are considered spam:
        maxInterval = 3.5,
        -- Valid Punishments: "muted" or "kicked"
        punishment = "muted",
        -- Mute time (in minutes) Set to nil to mute permanently:
        mute_time = 10,
        -- Message that will be sent in chat upon warning player:
        warnMessage = 'Please stop spamming or you will be %punishment%',
        -- Message that will be sent in chat upon kicking player:
        kickReason = 'spamming'
    },

    whitelist = {
        enabled = false,

        -- Group whitelisting:
        [-1] = false, -- PUBLIC
        [1] = true, -- ADMIN LEVEL 1
        [2] = true, -- ADMIN LEVEL 2
        [3] = true, -- ADMIN LEVEL 3
        [4] = true, -- ADMIN LEVEL 4

        -- Prevent players with specific IP Addresses from being muted:
        specific_user_check = true,
        players = {
            "127.0.0.1:2309",
        }
    },

    --
    -- Advanced users only:
    --
    --

    -- The array index for each client will either be "IP", or "IP:PORT".
    -- Set to 1 for ip-only indexing.
    ClientIndexType = 2,

    -- Mute System Configuration Ends --
}

api_version = "1.12.0.0"
local floor = math.floor
local time_scale = 1 / 30
local script_version = 1.2
local json = (loadfile "json.lua")()
local PageBrowser = (loadfile "page_browsing_lib.lua")()
local gsub, sub = string.gsub, string.sub
local gmatch, format, lower = string.gmatch, string.format, string.lower

function OnScriptLoad()
    register_callback(cb["EVENT_TICK"], "OnTick")
    register_callback(cb["EVENT_CHAT"], "OnPlayerChat")
    register_callback(cb["EVENT_GAME_END"], "OnGameEnd")
    register_callback(cb["EVENT_JOIN"], "OnPlayerConnect")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerDisconnect")
    register_callback(cb["EVENT_COMMAND"], "OnServerCommand")
    MuteSystem:CheckFile()
end

function OnScriptUnload()
    -- N/A
end

function OnGameStart()
    MuteSystem:CheckFile()
end

function OnGameEnd()
    MuteSystem:UpdateForAll()
end

function MuteSystem:OnTick()
    for IP, v in pairs(self.players) do
        if (v.time) then
            v.time = v.time - time_scale
            if (v.time < 1) then
                self:UnMute(0, v.mute_index)
            end
        elseif (self.anti_spam) and (v.spam and v.spam.count >= 1) then
            v.spam.timer = v.spam.timer + time_scale
            if (v.spam.timer < self.anti_spam.maxInterval) then
                if (v.spam.count >= self.anti_spam.warnThreshold) and (v.spam.count < self.anti_spam.punishThreshold) then
                    self:CLS(v.id)
                    self:Respond(v.id, gsub(self.anti_spam.warnMessage, "%%punishment%%", self.anti_spam.punishment), 12)
                elseif (v.spam.count >= self.anti_spam.punishThreshold) then
                    if (self.anti_spam.punishment == "kicked") then
                        self:CLS(v.id)
                        execute_command("k " .. v.id .. ' "' .. gsub(self.anti_spam.kickReason, "%%name%%", v.name) .. '"')
                    elseif (self.anti_spam.punishment == "muted") then
                        self:CLS(v.id)
                        self:Mute(0, IP, self.anti_spam.mute_time * 60)
                    end
                end
            elseif (v.spam.timer >= self.anti_spam.maxInterval) then
                v.spam.count, v.spam.timer = 0, 0
            end
        end
    end
end

function MuteSystem:InitPlayer(Ply, Reset)
    local IP = self:GetIP(Ply)
    if (not Reset) then
        self.players[IP] = self.players[IP] or { }
        self.players[IP].spam = { count = 0, timer = 0 }
        self.players[IP].id = Ply
        self.players[IP].name = get_var(Ply, "$name")
        self:IsMuted(Ply)
    else
        self:UpdateDatabase(IP, false, true)
    end
end

function MuteSystem:OnPlayerConnect(Ply)
    self:InitPlayer(Ply, false)
end

function OnPlayerDisconnect(Ply)
    MuteSystem:InitPlayer(Ply, true)
end

local function CMDSplit(CMD)
    local Args = { }
    for Params in gmatch(CMD, "([^%s]+)") do
        Args[#Args+1] = lower(Params)
    end
    return Args
end

function MuteSystem:OnServerCommand(Executor, Command)
    local Args = CMDSplit(Command)
    if (Args ~= nil) then

        for k, v in pairs(self.commands) do
            if (Args[1] == v[1]) then
                local lvl = tonumber(get_var(Executor, "$lvl"))
                if (lvl >= v[2] or Executor == 0) then
                    local mutes = self:GetMutes()
                    if (mutes ~= nil) then
                        if (k == 1) then

                            local pl = self:GetPlayers(Executor, Args)
                            if (pl) then

                                local Time = Args[3]
                                if (Time ~= nil) then
                                    if (Time:match("^%d+$") and tonumber(Time) > 0) then
                                        Time = tonumber(Time:match("^%d+$")) * 60
                                    else
                                        self:Respond(Executor, "- Invalid Time Parameter -")
                                    end
                                else
                                    Time = self.default_mute_time * 60
                                end

                                for i = 1, #pl do
                                    local TargetID = tonumber(pl[i])
                                    local IP = self:GetIP(TargetID)
                                    if (TargetID == Executor) then
                                        self:Respond(Executor, "You cannot mute yourself!")
                                    end
                                    self:Mute(Executor, IP, Time)
                                end
                            end
                        elseif (k == 2) then
                            local mute_index = (Args[2] ~= nil and Args[2]:match("^%d+$"))
                            if (mute_index) then
                                self:UnMute(Executor, mute_index)
                            else
                                self:Respond(Executor, "Invalid Mute Index")
                            end
                        elseif (k == 3) then
                            self:MuteList(Executor, Args)
                        end
                    end
                else
                    self:Respond(Executor, "Insufficient Permission")
                end
                return false
            end
        end

        if (self.block_commands and Executor > 0) then
            local muted = self:IsMuted(Executor)
            if (muted) then
                for _, cmd in pairs(self.command_whitelist) do
                    if (Args[1] == cmd) then
                        return true
                    end
                end
            end
            return muted
        end
    end
end

function MuteSystem:IsMuted(Ply)
    local IP = self:GetIP(Ply)
    local time = self.players[IP].time
    if (time ~= nil) then
        local s = self.messages.mute_reminder
        for i = 1, #s do
            self:Respond(Ply, format(s[i], self:SecondsToClock(time)))
        end
        return false, IP
    end
    return true, IP
end

local function isCommand(Msg)
    if (sub(Msg, 1, 1) == "/" or sub(Msg, 1, 1) == "\\") then
        return true
    end
    return false
end

function MuteSystem:OnPlayerChat(Ply, Msg, Type)
    if (Type ~= 6) and (not isCommand(Msg)) then
        local allow_chat, IP = self:IsMuted(Ply)
        if (allow_chat) then
            self.players[IP].spam.count = self.players[IP].spam.count + 1
        end
        return allow_chat
    end
end

function MuteSystem:Mute(Executor, TIP, Time)
    local name = self.players[TIP].name
    local TargetID = self.players[TIP].id
    if (not self:WhiteListed(Executor, TargetID, name, TIP)) then
        self.players[TIP].time = Time
        local admin = get_var(Executor, "$name")
        if (Executor == 0 or Executor == nil) then
            admin = "SERVER"
        end
        local str = self.messages.mute
        if (Executor) then
            str = str.manual
        else
            str = str.spam
        end
        for j = 1, #str do
            local msg = gsub(gsub(gsub(str[j],
                    "%%name%%", name),
                    "%%admin%%", admin),
                    "%%time%%", self:SecondsToClock(Time))
            self:Respond(_, msg, 10)
        end
        self:UpdateDatabase(TIP, false, true)
    end
end

function MuteSystem:UnMute(Executor, MuteIndex)
    for IP, v in pairs(self.players) do
        if (v.mute_index == tonumber(MuteIndex)) then
            if (v.time) then
                local s = self.messages.unmute
                local admin = get_var(Executor, "$name")
                if (Executor == 0) then
                    admin = "SERVER"
                end
                local msg = gsub(gsub(s, "%%name%%", v.name), "%%admin%%", admin)
                self:UpdateDatabase(IP, true, false)
                return self:Respond(_, msg, 10)
            elseif (Executor) then
                return self:Respond(Executor, v.name .. " is not muted!", 10)
            end
        end
    end
    return self:Respond(Executor, "Mute Index not found!", 10)
end

function MuteSystem:MuteList(Executor, Args)

    local Page = (Args[2] ~= nil and Args[2]:match("^%d+$") or 1)

    local pl = { }
    local count = 0

    local s = self.messages.mute_list
    self:Respond(Executor, s.header)

    for IP, v in pairs(self.players) do
        if (v.time) then
            count = count + 1
            pl[count] = gsub(gsub(gsub(s.content, "%%name%%", v.name), "%%ip%%", IP), "%%mute_index%%", v.mute_index)
        end
    end

    if (count == 0) then
        self:Respond(Executor, "There are no active mutes!", 10)
    else
        PageBrowser:ShowResults(Executor, tonumber(Page), 10, 1, 2, pl)
    end
end

function MuteSystem:UpdateMuteIndex()
    local index = 0
    for _, v in pairs(self.players) do
        if (v.time) then
            index = index + 1
            v.mute_index = index
        else
            v.mute_index = nil
        end
    end
end

function MuteSystem:UpdateDatabase(IP, UnMute, CleanArray)
    if (self.players[IP].time) then
        local mutes = self:GetMutes()
        if (mutes) then

            if (CleanArray) then
                self.players[IP].id = nil
                self.players[IP].spam = nil
            end

            local file = assert(io.open(self.dir, "w"))
            if (file) then
                if (UnMute) then
                    mutes[IP] = nil
                    self.players[IP].time = nil
                else
                    mutes[IP] = self.players[IP]
                end
                self:UpdateMuteIndex()
                file:write(json:encode_pretty(mutes))
                io.close(file)
            end
        end
    end
end

function MuteSystem:UpdateForAll()
    for i = 1, 16 do
        if player_present(i) then
            self:UpdateDatabase(self:GetIP(i), false, true)
        end
    end
end

function MuteSystem:GetPlayers(Executor, Args)
    local pl = { }
    if (Args[2] == "me" or Args[2] == nil) then
        if (Executor ~= 0) then
            table.insert(pl, Executor)
        else
            self:Respond(Executor, "Cannot execute from terminal", 10)
        end
    elseif (Args[2] ~= nil) and (Args[2]:match("^%d+$")) then
        if player_present(Args[2]) then
            table.insert(pl, Args[2])
        else
            self:Respond(Executor, "Player #" .. Args[2] .. " is not online", 10)
        end
    elseif (Args[2] == "all" or Args[2] == "*") then
        for i = 1, 16 do
            if player_present(i) then
                table.insert(pl, i)
            end
        end
        if (#pl == 0) then
            self:Respond(Executor, "There are no players online!", 10)
        end
    else
        self:Respond(Executor, "Invalid Command Syntax. Please try again!", 10)
    end
    return pl
end

function MuteSystem:WhiteListed(Executor, Ply, Name, IP)
    if (self.whitelist.enabled) then
        local lvl = tonumber(get_var(Ply, '$lvl'))
        local group_whitelisted = self.whitelist[lvl]
        if (group_whitelisted) then
            return true, self:Respond(Executor, gsub(self.messages.whitelisted, "%%name%%", Name), 12)
        elseif (self.whitelist.specific_user_check) then
            for _, ip in pairs(self.whitelist.players) do
                if (IP == ip) then
                    return true
                end
            end
        end
    end
    return false
end

function MuteSystem:GetMutes()
    local mutes
    local file = io.open(self.dir, "r")
    if (file) then
        local data = file:read("*all")
        mutes = json:decode(data)
        file:close()
    end
    return mutes
end

function MuteSystem:CheckFile()

    self.players = { }

    if (self.anti_spam.enabled) then
        execute_command_sequence("antispam 0")
    end

    if (get_var(0, "$gt") ~= "n/a") then

        local content = ""
        local file = io.open(self.dir, "r")
        if (file) then
            content = file:read("*all")
            io.close(file)
        end

        local mutes = json:decode(content)
        if (not mutes) then
            file = assert(io.open(self.dir, "w"))
            if (file) then
                file:write(json:encode_pretty({}))
                io.close(file)
            end
            return
        end

        for ip, _ in pairs(mutes) do
            self.players[ip] = mutes[ip] or nil
        end

        for i = 1, 16 do
            if player_present(i) then
                self:InitPlayer(i, false)
            end
        end
    end
end

function MuteSystem:SecondsToClock(seconds)
    if (seconds) then
        local years = floor(seconds / (60 * 60 * 24 * 365))
        seconds = seconds % (60 * 60 * 24 * 365)
        local weeks = floor(seconds / (60 * 60 * 24 * 7))
        seconds = seconds % (60 * 60 * 24 * 7)
        local days = floor(seconds / (60 * 60 * 24))
        seconds = seconds % (60 * 60 * 24)
        local hours = floor(seconds / (60 * 60))
        seconds = seconds % (60 * 60)
        local minutes = floor(seconds / 60)
        seconds = seconds % 60

        if (years >= 1) then
            return format("%d Years %d Weeks %d Days %d Hours %d Minutes %d Seconds", years, weeks, days, hours, minutes, seconds)
        elseif (weeks >= 1) then
            return format("%d Weeks %d Days %d Hours %d Minutes %d Seconds", weeks, days, hours, minutes, seconds)
        elseif (days >= 1) then
            return format("%d Days %d Hours %d Minutes %d Seconds", days, hours, minutes, seconds)
        elseif (hours >= 1) then
            return format("%d Hours %d Minutes %d Seconds", hours, minutes, seconds)
        elseif (minutes >= 1) then
            return format("%d Minutes %d Seconds", minutes, seconds)
        elseif (seconds >= 1) then
            return format("%d Seconds", seconds)
        else
            return "- time expired -"
        end
    end
end

function MuteSystem:GetIP(Ply)
    local IP = get_var(Ply, "$ip")
    if (self.ClientIndexType == 1) then
        IP = IP:match("%d+.%d+.%d+.%d+")
    end
    return IP
end

function MuteSystem:Respond(Ply, Message, Color)
    Color = Color or 10
    if (Ply == 0) then
        cprint(Message, Color)
    elseif (Ply) then
        rprint(Ply, Message)
    else
        cprint(Message, Color)
        for i = 1, 16 do
            if player_present(i) then
                rprint(i, Message)
            end
        end
    end
end

function MuteSystem:CLS(Ply, Count)
    Count = Count or 25
    for _ = 1, Count do
        rprint(Ply, " ")
    end
end

function OnServerCommand(P, C)
    return MuteSystem:OnServerCommand(P, C)
end
function OnPlayerConnect(P)
    return MuteSystem:OnPlayerConnect(P)
end
function OnTick()
    return MuteSystem:OnTick()
end
function OnPlayerChat(P, M, T)
    return MuteSystem:OnPlayerChat(P, M, T)
end

function WriteLog(str)
    local file = io.open("Mute System.log", "a+")
    if (file) then
        file:write(str .. "\n")
        file:close()
    end
end

-- In the event of an error, the script will trigger these two functions: OnError(), report()
function report(StackTrace, Error)

    cprint(StackTrace, 12)

    cprint("--------------------------------------------------------", 12)
    cprint("Please report this error on github:", 11)
    cprint("https://github.com/Chalwk/SPCLib/issues", 12)
    cprint("Script Version: " .. script_version, 11)
    cprint("--------------------------------------------------------", 12)

    WriteLog(os.date("[%H:%M:%S - %d/%m/%Y]"))
    WriteLog("Please report this error on github:")
    WriteLog("https://github.com/Chalwk/SPCLib/issues")
    WriteLog("Script Version: " .. tostring(script_version))
    WriteLog(Error)
    WriteLog(StackTrace)
    WriteLog("\n")
end

-- This function will return a string with a traceback of the stack call...
-- ...and call function 'report' after 50 milliseconds.
function OnError(Error)
    local StackTrace = debug.traceback()
    timer(50, "report", StackTrace, Error)
end

return MuteSystem