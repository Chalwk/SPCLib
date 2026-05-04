--[[
=====================================================================================
SCRIPT NAME:      nade_launcher.lua
DESCRIPTION:      Converts non‑grenade projectiles into high‑velocity frag grenades.
                  Players can toggle the effect with the /nade command.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/HALO-SCRIPT-PROJECTS/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ----------------------------------------------------------
local COMMAND = "nade"       -- Command to toggle the launcher
local VELOCITY = 0.5         -- Speed multiplier for the spawned grenade
local DISTANCE = 0.4         -- How far in front of the player nades spawn
local DEFAULT_ENABLED = true -- New players start with the launcher on
-- CONFIG END ------------------------------------------------------------

local proj_tag_id
local player_enabled = {}
local math_sin = math.sin

local function get_player_pos(player_object)
    local x = readfloat(player_object, 0x5C)
    local y = readfloat(player_object, 0x60)
    local z = readfloat(player_object, 0x64)

    local crouch = readfloat(player_object + 0x50C)
    local z_off = (crouch == 0) and 0.65 or 0.35 * crouch

    return x, y, z + z_off
end

local function get_player_aim(player_object)
    local x_aim = readfloat(player_object, 0x230)
    local y_aim = readfloat(player_object, 0x234)
    local z_aim = readfloat(player_object, 0x238)

    return x_aim, y_aim, z_aim
end

local function replace_with_nade(parent_object_id)
    local player_object = getobject(parent_object_id)
    if not player_object then return false end

    local player_id = objectidtoplayer(parent_object_id)
    if not player_id or not getplayer(player_id) then return false end

    local x_aim, y_aim, z_aim = get_player_aim(player_object)
    local px, py, pz = get_player_pos(player_object)

    local ox = px + DISTANCE * math_sin(x_aim)
    local oy = py + DISTANCE * math_sin(y_aim)
    local oz = pz + DISTANCE * math_sin(z_aim)

    local nade_id = createobject(proj_tag_id, 0, 0, false, ox, oy, oz)
    local nade_obj = getobject(nade_id)
    if nade_obj then
        writefloat(nade_obj, 0x68, VELOCITY * math_sin(x_aim))
        writefloat(nade_obj, 0x6C, VELOCITY * math_sin(y_aim))
        writefloat(nade_obj, 0x70, VELOCITY * math_sin(z_aim))
    end
end

function OnObjectCreationAttempt(map_id, parent_id, player)
    if not player_enabled[player] then return end

    local name, obj_type = gettaginfo(map_id)
    if obj_type ~= "proj" then return end
    if name:find("nade") then return end

    replace_with_nade(parent_id)
    return false
end

function OnServerChat(id, _, message)
    message = message:gsub("^[\\/]+", "")
    local command = message:lower()
    if command ~= COMMAND then return end

    local current = player_enabled[id]
    if current == nil then current = DEFAULT_ENABLED end
    player_enabled[id] = not current

    local status = player_enabled[id] and "ON" or "OFF"
    privatesay(id, "Nade Launcher: " .. status)
    return false
end

function OnScriptLoad()
    for i = 0, 15 do
        if getplayer(i) then player_enabled[i] = DEFAULT_ENABLED end
    end
end

function OnNewGame()
    proj_tag_id = gettagid("proj", "weapons\\frag grenade\\frag grenade")
end

function OnPlayerJoin(id)
    player_enabled[id] = DEFAULT_ENABLED
end

function OnPlayerLeave(id)
    player_enabled[id] = nil
end

function GetRequiredVersion() return 200 end

function OnScriptUnload() end
