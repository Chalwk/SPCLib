--[[
=====================================================================================
SCRIPT NAME:      vehicle_tag_utility.lua
DESCRIPTION:      Records vehicle tag names to a file when players use the tag command

KEY FEATURES:
                 - Captures vehicle tag names while players are seated in vehicles
                 - Outputs data in format: [map_name] Tag: vehicle_tag_path
                 - Appends results to vehicle_tag_utility.txt for easy analysis
                 - Permission-based command access

USAGE:
                 While in a vehicle, use the command: "tag"
                 Results are saved to sapp/vehicle_tag_utility.txt

COMMAND:
                 tag - Records the current vehicle's tag name to file

PERMISSION:      Level 1+ required (prevents console usage)

LAST UPDATED:    23/8/2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:         MIT License
                 https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration
local CONFIG = {
    FILE_NAME = 'vehicle_tag_utility.txt',
    COMMAND = 'tag',
    OUTPUT_FORMAT = '[%s] Tag: %s',  -- map, tag
    PERMISSION_LEVEL = 1
}

-- Config end

api_version = '1.12.0.0'

local file_path, current_map

function OnScriptLoad()
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')

    local sig_address = sig_scan('68??????008D54245468') + 0x1
    local directory = read_string(read_dword(sig_address))
    file_path = directory .. '\\sapp\\' .. CONFIG.FILE_NAME
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    current_map = get_var(0, '$map')
end

local function has_permission(id)
    if id == 0 then
        cprint("Console cannot execute this command.", 12)
        return false
    end
    return tonumber(get_var(id, '$lvl')) >= CONFIG.PERMISSION_LEVEL
end

local function read_tag(vehicle_id)
    local vehicle_object = get_object_memory(vehicle_id)
    return read_string(read_dword(read_word(vehicle_object) * 32 + 0x40440038))
end

local function format_output(map, tag)
    return string.format(CONFIG.OUTPUT_FORMAT, map or "unknown", tag:gsub("\\", "\\\\"))
end

function OnCommand(id, cmd)
    cmd = cmd:lower()
    if cmd ~= CONFIG.COMMAND then return true end

    if not has_permission(id) then return false end

    local dyn_player = get_dynamic_player(id)
    if dyn_player == 0 then return false end

    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id == 0xFFFFFFFF then
        rprint(id, "You must be in a vehicle to use this command.")
        return false
    end

    local tag_name = read_tag(vehicle_id)
    local output = format_output(current_map, tag_name)

    local file = io.open(file_path, "a")
    if not file then
        rprint(id, "Error: Could not write to file.")
        return false
    end

    file:write(output .. "\n")
    file:close()

    rprint(id, "Vehicle tag successfully recorded.")
    rprint(id, "Tag: " .. output)
    return false
end

function OnScriptUnload() end