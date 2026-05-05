--[[
=====================================================================================
SCRIPT NAME:      roll_the_dice.lua
DESCRIPTION:      Random effect generator with "/rtd" command. Players get one of:
                  - Random vehicle entry
                  - Random weapon assignment
                  - Inventory deletion
                  - Temporary invulnerability
                  - High-velocity launch

FEATURES:
                  - Five distinct random effects
                  - Configurable vehicle and weapon pools
                  - Permission system for command access
                  - Customizable messages for each effect
                  - Insta-shield duration control

CONFIGURATION:
                  - Enable/disable individual features
                  - Set insta-shield duration
                  - Adjust launch height
                  - Customize vehicle and weapon tables

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"
local RTD = {

    -- Custom command used to roll-the-dice!
    command = "rtd",

    -- Minimum permission level required to execute /base_command
    permission = -1,


    features = {

        [1] = { -- Random Vehicle Entry
            enabled = true,
            msg = "Entering %vehicle_name%"
        },

        [2] = { -- Random Weapon Assignment
            enabled = true,
            msg = "You have received %weapon_name%"
        },

        [3] = { -- Delete Inventory
            enabled = true,
            msg = "Your weapons have gone poof!",
            delete_flag_and_oddball = false,
        },

        [4] = { -- Insta-Shield
            enabled = true,
            msg = "INSTA-SHIELD!",
            --
            -- time (in seconds) insta-shield lasts:
            interval = 30
        },

        [5] = { -- Launch Player into the air
            enabled = true,

            -- How many world-units should we launch the player into the air?
            -- 1 w/unit = 10 feet or ~3.048 meters
            height = 25,
            msg = "Weeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        }

    },

    -- This table is used for RANDOM VEHICLE ENTRY feature:
    -- Players have a chance of entering one of these vehicles.
    vehicles = {
        { "vehicles\\ghost\\ghost_mp", "Ghost" },
        { "vehicles\\rwarthog\\rwarthog", "Rocket Hog" },
        { "vehicles\\warthog\\mp_warthog", "Chain Gun Hog" },
        { "vehicles\\banshee\\banshee_mp", "banshee" },
        { "vehicles\\scorpion\\scorpion_mp", "Tank" },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret" },
    },

    -- This table is used for RANDOM WEAPON ASSIGNMENT feature:
    -- Players have a chance of being given a random weapon.
    weapons = {
        { "weapons\\pistol\\pistol", "a Pistol" },
        { "weapons\\sniper rifle\\sniper rifle", "a Sniper" },
        { "weapons\\plasma_cannon\\plasma_cannon", "a Plasma Cannon" },
        { "weapons\\rocket launcher\\rocket launcher", "a Rocket Launcher" },
        { "weapons\\plasma pistol\\plasma pistol", "a Plasma Pistol" },
        { "weapons\\plasma rifle\\plasma rifle", "a Plasma Rifle" },
        { "weapons\\assault rifle\\assault rifle", "an Assault Rifle" },
        { "weapons\\flamethrower\\flamethrower", "a Flame Thrower" },
        { "weapons\\needler\\mp_needler", "a Needler" },
        { "weapons\\shotgun\\shotgun", "a Shotgun" },
    }
    --
}

-- string library variables --
local gsub = string.gsub
--

-- counts --
local time_scale = 1 / 30

function OnScriptLoad()
    register_callback(cb["EVENT_TICK"], "OnTick")
    register_callback(cb["EVENT_JOIN"], "OnPlayerJoin")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerQuit")
    register_callback(cb["EVENT_SPAWN"], "OnPlayerSpawn")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    register_callback(cb["EVENT_COMMAND"], "OnServerCommand")
    OnGameStart()
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        RTD.players = { }
        for i = 1, 16 do
            if player_present(i) then
                RTD:InitPlayer(i, false)
            end
        end
    end
end

local function GetXYZ(DyN)
    local pos = { }

    local VehicleID = read_dword(DyN + 0x11C)
    local VehicleObject = get_object_memory(VehicleID)

    pos.dyn = DyN

    if (VehicleID == 0xFFFFFFFF) then
        pos.invehicle = false
        pos.x, pos.y, pos.z = read_vector3d(DyN + 0x5c)
    elseif (VehicleObject ~= 0) then
        pos.invehicle = true
        pos.obj = VehicleObject
        pos.x, pos.y, pos.z = read_vector3d(VehicleObject + 0x5c)
    end
    return pos
end

local function Respond(Ply, Msg, Color)
    Color = Color or 12
    return (Ply == 0 and cprint(Msg, Color)) or rprint(Ply, Msg)
end

local function InstaShield(DyN)
    local shield = read_float(DyN + 0xE4)
    if (shield < 1) then
        write_word(DyN + 0x104, 0)
    end
end

function RTD:OnTick()
    for i, v in pairs(self.players) do

        local DyN = get_dynamic_player(i)
        if (DyN ~= 0 and player_alive(i)) then

            if (v.assign) then

                local pos = GetXYZ(DyN)
                if (pos and not pos.invehicle) then
                    v.assign = false

                    local index = math.random(1, #self.weapons)
                    local n = self.weapons[index]

                    local tag = n[1]
                    local weapon_name = n[2]

                    assign_weapon(spawn_object("weap", tag, pos.x, pos.y, pos.z), i)
                    local str = gsub(self.features[2].msg, "%%weapon_name%%", weapon_name)
                    Respond(i, str)
                end
            end

            if (v.insta_shield) then
                InstaShield(DyN)
                v.shield_timer = v.shield_timer + time_scale
                if (v.shield_timer >= self.features[4].interval) then
                    v.shield_timer = 0
                    v.insta_shield = false
                end
            end
        end
    end
end

local function HasPermission(Ply)

    local lvl = tonumber(get_var(Ply, "$lvl"))
    if (lvl >= RTD.permission and Ply ~= 0) then
        return true
    end

    if (Ply > 0) then
        Respond(Ply, "You do not have permission to execute that command", 12)
    else
        Respond(Ply, "You cannot execute this command from console!", 12)
    end

    return
end

local function CMDSplit(CMD)
    local Args = { }
    for Params in CMD:gmatch("([^%s]+)") do
        Args[#Args + 1] = Params:lower()
    end
    return Args
end

-- Command handler for /command (see config)
function RTD:OnServerCommand(Ply, CMD, _, _)
    local Args = CMDSplit(CMD)
    local case = (Args and Args[1])
    if (case and Args[1] == self.command) then

        if player_alive(Ply) then
            if HasPermission(Ply) then
                RTD:RollTheRice(Ply)
            end
        else
            Respond(Ply, "You're dead. Try again when you respawn")
        end

        --

        return false
    end
end

local function DeleteWeapons(Ply, Tab)
    local deleted

    local DyN = get_dynamic_player(Ply)
    if (DyN ~= 0) then
        for i = 0, 3 do
            local WeaponID = read_dword(DyN + 0x2F8 + 0x4 * i)
            if (WeaponID ~= 0xFFFFFFFF) then
                local Weapon = get_object_memory(WeaponID)
                if (Weapon ~= 0) then

                    local tag_address = read_word(Weapon)
                    local tag_data = read_dword(read_dword(0x40440000) + tag_address * 0x20 + 0x14)

                    local has_flag = (read_bit(tag_data + 0x308, 3) == 1)
                    if (not has_flag or RTD.features[3].delete_flag_and_oddball) then
                        destroy_object(WeaponID)
                        deleted = true
                    end
                end
            end
        end
    end

    if (deleted) then
        Respond(Ply, Tab.msg)
    else
        Respond(Ply, "Such boss. Much avoid!")
    end
end

local function Launch(Pos, Height)
    if (Pos) then
        local obj = (Pos.obj ~= 0 and Pos.obj or Pos.dyn)
        if (Pos.obj) then
            write_float(Pos.obj + 0x94, 0.75)
        end
        write_vector3d((obj) + 0x5C, Pos.x, Pos.y, (obj and Pos.z + Height))
    end
end

function RTD:RollTheRice(Ply)

    math.randomseed(os.clock())
    math.random();
    math.random();
    math.random();

    local n = math.random(1, #self.features)

    local feature = self.features[n]
    if (feature.enabled) then

        local DyN = get_dynamic_player(Ply)
        if (DyN ~= 0) then

            local pos = GetXYZ(DyN)

            -- enter player into random vehicle:
            if (n == 1) then

                if (pos and not pos.invehicle) then

                    local t = self.vehicles[math.random(1, #self.vehicles)]
                    local offset = 0.2
                    local tag, vehicle_name = t[1], t[2]
                    local vehicle = spawn_object("vehi", tag, pos.x, pos.y, pos.z + offset)
                    enter_vehicle(vehicle, Ply, 0)

                    Respond(Ply, gsub(feature.msg, "%%vehicle_name%%", vehicle_name))
                    return
                end
                --



                -- assign player a random weapon:
            elseif (n == 2) then
                self.players[Ply].assign = true
                return
                --



                -- delete player inventory (excluding flag/oddball):
            elseif (n == 3) then
                DeleteWeapons(Ply, feature)
                return
                --



                -- insta-shield
            elseif (n == 4) then

                Respond(Ply, feature.msg)
                self.players[Ply].insta_shield = true
                return
                --



                -- Launch player into the air:
            elseif (n == 5) then
                Respond(Ply, feature.msg)
                Launch(pos, feature.height)
                return
            end
        end
    end

    return Respond(Ply, "Aww, tough luck. Nada!")
end

function RTD:InitPlayer(Ply, Reset)

    if (not Reset) then
        self.players[Ply] = { assign = false, insta_shield = false, shield_timer = 0 }
        return
    end

    self.players[Ply] = nil
end

function OnPlayerJoin(Ply)
    RTD:InitPlayer(Ply, false)
end

function OnPlayerSpawn(Ply)
    RTD.players[Ply].shield_timer = 0
    RTD.players[Ply].insta_shield = false
end

function OnPlayerQuit(Ply)
    RTD:InitPlayer(Ply, true)
end

function OnScriptUnload()
    -- N/A
end

function OnServerCommand(P, C, _, _)
    return RTD:OnServerCommand(P, C, _, _)
end

function OnTick()
    return RTD:OnTick()
end

-- For a future update:
return RTD