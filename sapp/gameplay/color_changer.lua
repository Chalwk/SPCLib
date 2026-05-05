--[[
=====================================================================================
SCRIPT NAME:      color_changer.lua
DESCRIPTION:      Allows players to change their armor color via command with
                  admin-level restrictions and 18 color options.

FEATURES:
                  - 18 customizable armor colors (0-17)
                  - Admin-level permission system
                  - Preserves player position during color change
                  - Works in all game modes
                  - Safe memory patching for color changes

COMMAND USAGE:
                  /setcolor [0-17] - Changes player armor color
                  Example: /setcolor 5 (yellow)

COLOR OPTIONS:
                  0:white  1:black  2:red     3:blue    4:gray
                  5:yellow 6:green  7:pink    8:purple  9:cyan
                  10:cobalt 11:orange 12:teal 13:sage   14:brown
                  15:tan   16:maroon 17:salmon

CONFIGURATION:
                  - Change required admin level (default: 1)
                  - Customize command name
                  - Add/remove color options as needed

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local ColourChanger = {
    level = 1, -- Admin level required to change color
    command = 'setcolor', -- Custom command
    colours = {
        [0] = 'white', [1] = 'black', [2] = 'red', [3] = 'blue', [4] = 'gray',
        [5] = 'yellow', [6] = 'green', [7] = 'pink', [8] = 'purple', [9] = 'cyan',
        [10] = 'cobalt', [11] = 'orange', [12] = 'teal', [13] = 'sage', [14] = 'brown',
        [15] = 'tan', [16] = 'maroon', [17] = 'salmon'
    }
}

local players = {}
local colours_address
api_version = '1.12.0.0'

local function Write(address, value)
    safe_write(true)
    write_char(address, value)
    safe_write(false)
end

local function patchColours(state)
    if state then
        colours_address = sig_scan('741F8B482085C9750C') or sig_scan('EB1F8B482085C9750C')
        if colours_address ~= 0 then
            Write(colours_address, 235)
        end
    elseif colours_address ~= 0 then
        Write(colours_address, 116)
    end
end

local function overrideTeamColours(state)
    if get_var(0, '$gt') ~= 'n/a' then
        players = {}
        patchColours(state)
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart(true)
end

function OnSpawn(id)
    local player = players[id]
    if player then
        local x, y, z = player.x, player.y, player.z
        local dynamic_player = get_dynamic_player(id)
        if dynamic_player ~= 0 then
            write_vector3d(dynamic_player + 0x5C, x, y, z)
            players[id] = nil
        end
    end
end

local function say(id, str)
    rprint(id, str)
end

local function getPos(id)
    local dynamic_player = get_dynamic_player(id)
    if dynamic_player == 0 or not player_alive(id) then
        return nil
    end

    local vehicle = read_dword(dynamic_player + 0x11C)
    local object = get_object_memory(vehicle)
    if vehicle ~= 0xFFFFFFFF then
        return read_vector3d(dynamic_player + 0x5c)
    elseif object ~= 0 then
        return read_vector3d(object + 0x5c)
    end
end

local function setColor(id, colour_id)

    local x, y, z = getPos(id)
    if not x then
        say(id, 'Unable to set color.')
        return
    end

    local colour_name = ColourChanger.colours[colour_id]
    players[id] = { color = colour_id, x = x, y = y, z = z }
    write_byte(get_player(id) + 0x60, colour_id)

    say(id, 'Setting colour to ' .. colour_name .. '.')
    destroy_object(read_dword(get_player(id) + 0x34))
end

local function hasPermission(id, level)
    return tonumber(get_var(id, '$lvl')) >= level
end

local function stringSplit(s)
    local t = {}
    for arg in s:gmatch('([^%s]+)') do
        table.insert(t, arg:lower())
    end
    return t
end

function OnCommand(id, command)
    if id == 0 then
        return true
    end

    local self = ColourChanger
    local args = stringSplit(command)
    if args[1]:sub(1, self.command:len()):lower() == self.command then
        if not hasPermission(id, self.level) then
            say(id, 'You do not have permission to execute this command.')
            return false
        end

        local color = tonumber(args[2])
        if not color or not self.colours[color] then
            say(id, 'Invalid color id. Please enter a number between 0-17.')
            return false
        end

        setColor(id, color)
        return false
    end
    return true
end

function OnStart(state)
    overrideTeamColours(state)
end

function OnScriptUnload()
    overrideTeamColours(false)
end