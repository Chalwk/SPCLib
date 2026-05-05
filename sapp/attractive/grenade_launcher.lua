--[[
=====================================================================================
SCRIPT NAME:      grenade_launcher.lua
DESCRIPTION:      Converts weapons into grenade launchers
                  - Toggle with: /gl [on/off] (permission level -1)
                  - Works with all standard weapons and vehicle weapons
                  - Configurable projectile behavior and velocity
                  - Automatic map-specific grenade types
                  - Optional auto-disable on player death

                  Supported weapons include:
                  - Pistol, Plasma Pistol, Shotgun
                  - Plasma Rifle, Assault Rifle
                  - Warthog, Ghost, Banshee weapons

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG STARTS -------------------------------------------------------------

local GL = {

    -- General settings
    server_prefix = "**GL**",
    command = "gl",
    permission = -1,
    disable_on_death = false,

    -- Projectile behaviour:
    projectile = {
        spawn_distance = 1.0, -- Distance in world units in front of the player where the projectile spawns
        velocity_x = 0.6,     -- Horizontal speed multiplier
        velocity_y = 0.6,     -- Forward speed multiplier
        velocity_z = 0.6      -- Vertical speed multiplier
    },

    -- Map settings [map name] = { grenade tag, explosion tag }
    ["bloodgulch"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["deathisland"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["icefields"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["infinity"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["sidewinder"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["timberland"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["dangercanyon"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["beavercreek"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["boardingaction"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["carousel"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["chillout"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["damnation"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["gephyrophobia"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["hangemhigh"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["longest"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["prisoner"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["putput"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["ratrace"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },
    ["wizard"] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\explosion" },

    -- Weapon that can be turned into grenade launcher
    weapons = {
        ["weapons\\pistol\\bullet"] = true,
        ["weapons\\plasma pistol\\bolt"] = true,
        ["weapons\\shotgun\\pellet"] = true,
        ["weapons\\plasma rifle\\bolt"] = true,
        ["weapons\\assault rifle\\bullet"] = true,
        ["vehicles\\warthog\\bullet"] = true,
        ["vehicles\\ghost\\ghost bolt"] = true,
        ["vehicles\\banshee\\banshee bolt"] = true,
    }
}
-- CONFIG ENDS ---------------------------------------------------------------

api_version = '1.12.0.0'

local players = {}
local sin = math.sin
local frag_grenade_tag
local frag_grenade_explosion_tag
local active_map = nil

GL.active = false
GL.weapon_tags = {}

local function get_tag(type, name)
    local tag = lookup_tag(type, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

local function get_player_xyz(player)
    local dyn = get_dynamic_player(player)
    if dyn == 0 then return nil end

    local vehicle = read_dword(dyn + 0x11C)
    local x, y, z, distance

    if vehicle == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn + 0x5C)
        distance = 0.5
    else
        local vehi_object = get_object_memory(vehicle)
        if vehi_object ~= 0 then
            x, y, z = read_vector3d(vehi_object + 0x5C)
            distance = 2
        else
            return nil
        end
    end

    -- Adjust for crouching
    local crouching = read_float(dyn + 0x50C)
    z = z + (crouching == 0 and 0.65 or 0.35 * crouching)

    return x, y, z, distance
end

local function launch_grenade(player)
    local dyn = get_dynamic_player(player)
    if dyn == 0 then return end

    local x, y, z, base_distance = get_player_xyz(player)
    if not x then return end

    local xAim = sin(read_float(dyn + 0x230))
    local yAim = sin(read_float(dyn + 0x234))
    local zAim = sin(read_float(dyn + 0x238))

    local distance = base_distance + GL.projectile.spawn_distance
    local spawn_x = x + (distance * xAim)
    local spawn_y = y + (distance * yAim)
    local spawn_z = z + (distance * zAim)

    local grenade = spawn_projectile(frag_grenade_tag, player, spawn_x, spawn_y, spawn_z)
    if grenade ~= nil then
        local obj = get_object_memory(grenade)
        if obj ~= 0 then
            write_float(obj + 0x68, GL.projectile.velocity_x * xAim)
            write_float(obj + 0x6C, GL.projectile.velocity_y * yAim)
            write_float(obj + 0x70, GL.projectile.velocity_z * zAim)
        end
    end
end

local function toggle_mode(player, state)
    if state == nil then
        rprint(player, "Grenade Launcher is " .. (players[player].enabled and "enabled" or "disabled"))
        return
    end

    players[player].enabled = state
    rprint(player, "Grenade Launcher " .. (state and "enabled" or "disabled"))
end

local function process_command(player, args)
    local level = tonumber(get_var(player, "$lvl"))
    if level < GL.permission then
        rprint(player, "Insufficient permissions")
        return
    end

    local state
    if args[2] == "on" or args[2] == "1" then
        state = true
    elseif args[2] == "off" or args[2] == "0" then
        state = false
    end

    toggle_mode(player, state)
end

function OnScriptLoad()
    register_callback(cb["EVENT_JOIN"], "OnJoin")
    register_callback(cb["EVENT_LEAVE"], "OnQuit")
    register_callback(cb["EVENT_SPAWN"], "OnSpawn")
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    register_callback(cb["EVENT_GAME_START"], "OnStart")
    register_callback(cb["EVENT_OBJECT_SPAWN"], "OnObjectSpawn")
    OnStart()
end

function OnStart()
    GL.active = false
    if get_var(0, "$gt") == "n/a" then return end

    active_map = get_var(0, "$map")
    if not GL[active_map] then return end

    -- Precompute weapon tags
    GL.weapon_tags = {}
    for tag_path, enabled in pairs(GL.weapons) do
        if enabled then
            local tag_id = get_tag("proj", tag_path)
            if tag_id then
                GL.weapon_tags[tag_id] = true
            end
        end
    end

    frag_grenade_tag = get_tag("proj", GL[active_map][1])
    if not frag_grenade_tag then return end

    frag_grenade_explosion_tag = get_tag("jpt!", GL[active_map][2])
    if not frag_grenade_explosion_tag then return end

    players = {}
    GL.active = true

    for i = 1, 16 do
        if player_present(i) then
            players[i] = {
                enabled = false,
                name = get_var(i, "$name"),
                meta_id = 0
            }
        end
    end
end

function OnObjectSpawn(player, object_id)
    if not GL.active then return true end
    if player == 0 then return true end
    if not player_alive(player) then return true end

    local player_data = players[player]
    if not player_data or not player_data.enabled then return true end

    if GL.weapon_tags[object_id] then
        launch_grenade(player)
        return false
    end

    return true
end

function OnSpawn(player)
    if players[player] then
        players[player].meta_id = 0
        if GL.disable_on_death then
            players[player].enabled = false
            rprint(player, "Grenade Launcher disabled (on death)")
        end
    end
end

function OnCommand(player, command)
    local args = {}
    for arg in command:gmatch("%S+") do
        args[#args + 1] = arg:lower()
    end

    if player > 0 and #args > 0 and args[1] == GL.command then
        process_command(player, args)
        return false
    end
    return true
end

function OnJoin(player)
    players[player] = {
        enabled = false,
        name = get_var(player, "$name"),
        meta_id = 0
    }
end

function OnQuit(player)
    players[player] = nil
end