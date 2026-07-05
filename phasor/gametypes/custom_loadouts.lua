--[[
===============================================================================
SCRIPT NAME:      custom_loadouts.lua
DESCRIPTION:      Custom weapon loadout system with multiple pre-configured
                  weapon sets, automatic application on spawn, player selection,
                  admin override capabilities, custom ammo, grenade counts, a
                  selection menu, and persistent player preferences.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
===============================================================================
]]

-- CONFIG START ------------------

local show_loadouts_on_death = true
local default_loadout = 1

-- Command Syntax: /loadout <opt id>/list
local commands = { base = "loadout", list = "list" }

local weapon_tags = {
    [1] = "weapons\\pistol\\pistol",
    [2] = "weapons\\sniper rifle\\sniper rifle",
    [3] = "weapons\\plasma_cannon\\plasma_cannon",
    [4] = "weapons\\rocket launcher\\rocket launcher",
    [5] = "weapons\\plasma pistol\\plasma pistol",
    [6] = "weapons\\plasma rifle\\plasma rifle",
    [7] = "weapons\\assault rifle\\assault rifle",
    [8] = "weapons\\flamethrower\\flamethrower",
    [9] = "weapons\\needler\\mp_needler",
    [10] = "weapons\\shotgun\\shotgun"
}

local loadouts = {
    {
        id = 1,
        name = "Default",
        frags = 1,
        plasmas = 3,
        weapons = {
            [7] = { label = 'ARifle', clip = 60, ammo = 120 },
            [1] = { label = 'Pistol', clip = 12, ammo = 48 }
        }
    },
    {
        id = 2,
        name = "LoneWolf",
        frags = 0,
        plasmas = 0,
        weapons = {
            [2] = { label = 'Sniper', clip = 4, ammo = 8 }
        }
    },
    {
        id = 3,
        name = "ShottySnipes",
        frags = 0,
        plasmas = 0,
        weapons = {
            [10] = { label = 'Shotgun', clip = 12, ammo = 24 },
            [2] = { label = 'Sniper', clip = 4, ammo = 8 }
        }
    },
    {
        id = 4,
        name = "HeavyOrdnance",
        frags = 2,
        plasmas = 0,
        weapons = {
            [4] = { label = 'RLauncher', clip = 2, ammo = 4 },
            [3] = { label = 'PCannon', clip = 100, ammo = 200 },
            [5] = { label = 'PPistol', clip = 12, ammo = 48 }
        }
    }
}

-- CONFIG ENDS -------------------

api_version = '1.12.0.0'

local str_lower = string.lower
local str_match = string.match
local str_gmatch = string.gmatch
local tbl_concat = table.concat
local tbl_sort = table.sort

local weapon_datums = {}
local players = {}
local loadouts_by_id = {}
local player_data = {}

local function cache_weapon_datums()
    for _, tag_name in pairs(weapon_tags) do
        weapon_datums[tag_name] = gettagid('weap', tag_name)
    end
end

local function build_loadout_indexes()
    loadouts_by_id = {}

    for i = 1, #loadouts do
        local loadout = loadouts[i]
        loadouts_by_id[loadout.id] = loadout

        local labels = {}
        for weap_idx, weapon in pairs(loadout.weapons) do
            local tag_string = weapon_tags[weap_idx]
            if tag_string then
                labels[#labels + 1] = weapon.label or tag_string
            end
        end
        tbl_sort(labels)
        loadout._weapon_text = tbl_concat(labels, ", ")
    end

    default_loadout_id = loadouts_by_id[default_loadout] and default_loadout or (loadouts[1] and loadouts[1].id or 1)
end

local function delete_weapons(player_object)
    for i = 0, 3 do
        local weapon_id = readdword(player_object + 0x2F8 + i * 4)
        local weapon_object = getobject(weapon_id)
        if weapon_object then destroyobject(weapon_id) end
    end
end

local function spawn_weapon(id, tag_string, attributes, slot)
    local tag_datum = weapon_datums[tag_string]
    if not tag_datum then return end

    local weapon = createobject(tag_datum, 0, 0, false, 0, 0, 0)
    if weapon == 0 then return end

    local weapon_mem = getobject(weapon)
    if weapon_mem == 0 then return end

    writeword(weapon_mem + 0x2B6, attributes.ammo or 0)
    writeword(weapon_mem + 0x2B8, attributes.clip or 0)

    if slot <= 2 then
        assignweapon(id, weapon)
    else
        registertimer(250, "DelayedAssignWeapon", { id = id, weapon = weapon })
    end
end

function DelayedAssignWeapon(_, _, data)
    if not data then return false end

    local player_id = data.id
    local weapon = data.weapon

    if not getplayer(player_id) then return false end
    if not weapon or weapon == 0 then return false end

    local obj = getobject(weapon)
    if not obj then return false end

    assignweapon(player_id, weapon)
    return false
end

local function get_player_loadout_id(id)
    return players[id] or default_loadout_id
end

function ApplyLoadout(_, _, player_id)
    if not getplayer(player_id) then return end

    local player_object_id = getplayerobjectid(player_id)
    if not player_object_id or player_object_id == 0 then return end

    local player_object = getobject(player_object_id)
    if not player_object then return end

    local loadout = loadouts_by_id[get_player_loadout_id(player_id)] or loadouts_by_id[default_loadout_id]
    if not loadout then return false end

    delete_weapons(player_object)

    local slot = 0
    for weap_idx, attributes in pairs(loadout.weapons) do
        local tag_string = weapon_tags[weap_idx]
        if tag_string then
            slot = slot + 1
            spawn_weapon(player_id, tag_string, attributes, slot)
        end
    end

    return false
end

local function show_current_loadout(id)
    local loadout_id = get_player_loadout_id(id)
    local loadout = loadouts_by_id[loadout_id] or loadouts_by_id[default_loadout_id]
    if not loadout then
        privatesay(id, "No loadout configured.")
        return
    end

    privatesay(id, "Current Loadout: #" .. loadout_id .. " - " .. loadout.name)
end

local function show_available_loadouts(id)
    privatesay(id, "Available Loadouts:")

    for i = 1, #loadouts do
        local loadout = loadouts[i]
        privatesay(id, "[" .. loadout.id .. "]: " .. loadout.name)
        privatesay(id, "Weaps: " .. (loadout._weapon_text or ""))
        privatesay(id, "Grenades: " .. (loadout.frags or 0) .. "/" .. (loadout.plasmas or 0))
        privatesay(id, " ")
    end

    privatesay(id, "Use /" .. commands.base .. " [number] to select")
end

local function process_loadout_command(id, selected_id)
    local loadout = loadouts_by_id[selected_id]
    if not loadout then return false end

    players[id] = selected_id
    player_data[id] = selected_id
    privatesay(id, "Loadout #" .. selected_id .. " (" .. loadout.name .. ") selected.")
    privatesay(id, "Will apply on respawn.")
    return true
end

local function strip_prefix(msg)
    if not msg then return "" end
    return msg:gsub("^[\\/]+", "")
end

local function parse_cmd(s)
    local args = {}
    for w in str_gmatch(s, '([^%s]+)') do
        args[#args + 1] = str_lower(w)
    end
    return args
end

function OnServerChat(id, _, message)
    message = strip_prefix(message)
    local args = parse_cmd(message)

    if args[1] ~= commands.base then return true end
    if #args == 1 then
        show_current_loadout(id)
        return false
    end

    local sub = args[2]
    if sub == commands.list then
        show_available_loadouts(id)
    elseif sub and str_match(sub, '^%d+$') then
        local selected_id = tonumber(sub)
        if not process_loadout_command(id, selected_id) then
            privatesay(id, "Unknown Loadout ID. Use /" .. commands.base .. " " .. commands.list .. " to see options.")
        end
    else
        privatesay(id, "Unknown command. Use /" .. commands.base .. " " .. commands.list .. " to see options.")
    end

    return false
end

function OnScriptLoad()
    build_loadout_indexes()
    cache_weapon_datums()
    for i = 0, 15 do
        if getplayer(i) then OnPlayerJoin(i) end
    end
end

function OnNewGame()
    cache_weapon_datums()
end

function OnPlayerJoin(id)
    players[id] = player_data[id] or default_loadout_id
end

function OnPlayerLeave(id)
    players[id] = nil
end

function OnPlayerSpawn(id)
    registertimer(50, "ApplyLoadout", id)
end

function OnPlayerKill(_, victim)
    if show_loadouts_on_death then
        show_available_loadouts(victim)
    end
end

function GetRequiredVersion()
    return 200
end

function OnScriptUnload() end
