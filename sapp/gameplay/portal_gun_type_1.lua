--[[
=====================================================================================
SCRIPT NAME:      portal_gun_type_1.lua
DESCRIPTION:      Teleportation tool that works by aiming and shooting.
                  - Works while in vehicles
                  - No crouching required to teleport
                  - Admin-configurable permissions
                  - Persistent activation (optional)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- config starts --

local PortalGun = {

    -- Custom command used to toggle Portal Gun on/off:
    command = "portalgun",

    -- Minimum permission needed to execute the custom command:
    permission = 1,

    -- Minimum permission needed to toggle Portal Gun for other players:
    permission_others = 4,

    -- Fully customizable messages:
    messages = {

        -- Portal Gun output format:
        [1] = "$name [$id]: $message",

        -- This message is sent to (you) when you enable/disable for yourself.
        [2] = "Portal Gun $state!",

        -- This message is sent to (you) when you enable/disable for others.
        [3] = "Portal Gun $state for $target_name",

        -- This message is sent to (target player) when you enable/disable for them.
        [4] = "Your Portal Gun was $state by $admin_name",

        -- This message is sent to (you) when your Portal Gun is already enabled/disabled.
        [5] = "Your Portal Gun is already $state!",

        -- This message is sent to (target player) when their Portal Gun is already enabled/disabled.
        [6] = "$target_name's Portal Gun is already $state!",

        -- This message is sent when a player connects to the server (if previously activated).
        -- This requires the 'restore' setting to be TRUE.
        [7] = "Portal Gun is Enabled! (auto-restore)",

        -- This message is sent to (you) when there is a command syntax error.
        [8] = "Invalid Syntax: Usage: /$cmd on|off [me | id | */all]",

        -- If command Ply permission level is < permission_others, send this message:
        [9] = "You lack permission to execute this command on other players",
    },

    -- Should Portal Gun be restored for returning players? (if previously activated)
    restore = true,

    --
    -- Advanced users only:
    --

    -- The table index for each client will either be "IP", or "IP:PORT".
    -- Set to 1 for ip-only indexing.
    -- Set to 2 for ip & port indexing.
    ClientIndexType = 2
}
-- config ends --

function OnScriptLoad()

    register_callback(cb["EVENT_TICK"], "OnTick")
    register_callback(cb["EVENT_JOIN"], "OnJoin")
    register_callback(cb["EVENT_LEAVE"], "OnQuit")
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    register_callback(cb["EVENT_GAME_START"], "OnStart")

    OnStart()
end

function OnStart()
    if (get_var(0, "$gt") ~= "n/a") then
        PortalGun.players = { }
        for i = 1, 16 do
            if player_present(i) then
                PortalGun:InitPlayer(i)
            end
        end
    end
end

function OnScriptUnload()
    -- N/A
end

function OnJoin(Ply)
    PortalGun:InitPlayer(Ply)
end

function OnQuit(Ply)
    PortalGun:InitPlayer(Ply, true)
end

local function STRSplit(CMD)
    local Args = { }

    for Params in CMD:gsub('"', ""):gmatch("([^%s]+)") do
        Args[#Args + 1] = Params:lower()
    end

    return Args
end

local function Respond(Ply, Msg, Color)
    return (Ply == 0 and cprint(Msg, Color or 10) or rprint(Ply, Msg))
end

function PortalGun:IsAdmin(Ply, CMD)

    local lvl = tonumber(get_var(Ply, "$lvl"))
    if (lvl >= self.permission) or (Ply == 0) then
        return true, lvl
    end

    -- Return false if player is not admin:
    -- Send player Insufficient Permission message if callback came from OnCommand()
    return false, (CMD and Respond(Ply, "Insufficient Permission", 10))
end

function PortalGun:InitPlayer(Ply, Reset)

    if (self:IsAdmin(Ply)) then

        local ip = self:GetIP(Ply)
        if (not Reset) then

            self.players[ip] = self.players[ip] or nil

            -- Restore Portal Gun to the state before they quit:
            if (self.restore and self.players[ip]) then
                Respond(Ply, self.messages[7])
            end

            -- Disable Portal Gun:
        elseif (not self.restore or not self.players[ip]) then
            self.players[ip] = nil
        end
    end
end

local function GetXYZ(DyN)

    -- Get vehicle id:
    local vehicle = read_dword(DyN + 0x11C)
    local object = get_object_memory(vehicle)

    -- Get player coordinates:
    local x, y, z = read_vector3d(DyN + 0x5C)

    -- Return vehicle coordinates if they're in one:
    if (vehicle ~= 0xFFFFFFFF and object ~= 0) then
        x, y, z = read_vector3d(object + 0x5C)
        return x, y, z, object
    end

    return x, y, z, DyN
end

local function GetLocation(Ply, DyN)

    -- Get player x,y,z:
    local x, y, z, object_to_move = GetXYZ(DyN)

    -- Account for crouch height:
    local crouching = read_float(DyN + 0x50C)
    if (crouching == 0) then
        z = z + 0.65
    else
        z = z + (0.35 * crouching)
    end

    -- Get camera aim coordinates:
    local cx = read_float(DyN + 0x230) * 1000
    local cy = read_float(DyN + 0x234) * 1000
    local cz = read_float(DyN + 0x238) * 1000

    -- Test intersect and return location coordinates:
    local ignore_player = read_dword(get_player(Ply) + 0x34)
    local success, new_x, new_y, new_z, object = intersect(x, y, z, cx, cy, cz, ignore_player)
    if (success and object) then
        return new_x, new_y, new_z, object_to_move
    end
end

function OnTick()
    for _, v in pairs(PortalGun.players) do

        local DyN = get_dynamic_player(v.id)
        if (DyN ~= 0 and player_alive(v.id)) then

            local shooting = read_float(DyN + 0x490)
            if (shooting ~= v.shooting) then
                local x, y, z, object = GetLocation(v.id, DyN)
                if (x and object) then
                    local z_off = 0.3
                    write_vector3d(object + 0x5C, x, y, z + z_off)
                end
            end
            v.shooting = shooting
        end
    end
end

function PortalGun:OnCommand(Ply, CMD)

    local Args = STRSplit(CMD)
    if (#Args > 0 and Args[1] == self.command) then

        -- Admin [boolean], lvl [int]
        local Admin, lvl = self:IsAdmin(Ply, true)

        if (Admin) then
            if (Args[2] ~= nil) then
                local pl = self:GetPlayers(Ply, Args[3])
                if (pl) then
                    local params = { }
                    for i = 1, #pl do
                        local player = tonumber(pl[i])
                        if (player ~= Ply and lvl < self.permission_others and Ply ~= 0) then
                            Respond(Ply, self.messages[9], 10)
                        else
                            params.state = Args[2] -- on|off
                            params.eid, params.en = Ply, get_var(Ply, '$name')
                            params.tid, params.tn, params.tip = player, get_var(player, '$name'), self:GetIP(player)
                            self:Toggle(params)
                        end
                    end
                end
            else
                Respond(Ply, "Invalid Syntax. Usage: /" .. self.command .. " on|off [me | id | */all]", 10)
            end
        end
        return false
    end
    return true
end

function PortalGun:GetState(Ply, State)
    if (State == "on" or State == "1" or State == "true") then
        return 1
    elseif (State == "off" or State == "0" or State == "false") then
        return 0
    else
        return false, Respond(Ply, self.messages[8]:gsub("$cmd", self.command), 12)
    end
end

local function FormatTxt(MsgID, State, AdminName, TargetName)
    local Txt = PortalGun.messages[MsgID]
    local words = {
        ["$state"] = State,
        ["$admin_name"] = AdminName,
        ["$target_name"] = TargetName,
    }
    for k, v in pairs(words) do
        Txt = Txt:gsub(k, v)
    end
    return Txt
end

function PortalGun:Toggle(params)

    -- Target:
    local tid, tip, tn = params.tid, params.tip, params.tn

    -- Admin:
    local eid, en = params.eid, params.en
    if (eid == 0) then
        en = "SERVER"
    end

    local state = self:GetState(eid, params.state)
    if (state) then

        local already_set
        self.players[tip] = self.players[tip] or nil

        if (state == 1) then
            state = "enabled"
            if (self.players[tip] == nil) then
                self.players[tip] = { id = tid, shooting = 0 }
            else
                already_set = true
            end
        elseif (state == 0) then
            state = "disabled"
            if (self.players[tip] ~= nil) then
                self.players[tip] = nil
            else
                already_set = true
            end
        end

        -- Send "enable/disable" message:
        if (not already_set) then
            if (eid == tid) then
                Respond(eid, FormatTxt(2, state, en, tn), 10)
                return
            else
                Respond(eid, FormatTxt(3, state, en, tn), 10)
                Respond(tid, FormatTxt(4, state, en, tn), 10)
                return
            end
            -- Send "already set" message:
        else
            if (eid == tid) then
                Respond(eid, FormatTxt(5, state, en, tn), 12)
            else
                Respond(eid, FormatTxt(6, state, en, tn), 12)
            end
        end
    end
end

function PortalGun:GetPlayers(Ply, Arg)
    local pl = { }
    if (Arg == nil or Arg == "me") then
        if (Ply ~= 0) then
            table.insert(pl, Ply)
        else
            Respond(Ply, "Please enter a valid player id", 10)
        end
    elseif (Arg ~= nil and Arg:match("^%d+$")) then
        if player_present(Arg) then
            table.insert(pl, Arg)
        else
            Respond(Ply, "Player #" .. Arg .. " is not online", 10)
        end
    elseif (Arg == "all" or Arg == "*") then
        for i = 1, 16 do
            if player_present(i) then
                table.insert(pl, i)
            end
        end
        if (#pl == 0) then
            Respond(Ply, "There are no players online!", 10)
        end
    else
        Respond(Ply, "Invalid Command Syntax. Please try again!", 10)
    end
    return pl
end

function PortalGun:GetIP(Ply)
    local IP = get_var(Ply, "$ip")

    if (self.ClientIndexType == 1) then
        IP = IP:match("%d+.%d+.%d+.%d+")
    end

    return IP
end

function OnCommand(P, C)
    return PortalGun:OnCommand(P, C)
end

-- for a future update:
return PortalGun