--[[
===============================================================================
SCRIPT NAME:      get_server_name.lua
DESCRIPTION:      Retrieves and displays the server name with:
                  - Simple API for accessing server name
                  - Welcome message functionality
                  - Wide string handling

FEATURES:
                  - Gets the actual server name (not map name)
                  - Can be used for welcome messages
                  - Lightweight implementation

USAGE:            Call GetServerName() to retrieve the server name string

Copyright (c) 2016-2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = '1.12.0.0'

local network_struct, server_name
local concat, char = table.concat, string.char

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    network_struct = read_dword(sig_scan('F3ABA1????????BA????????C740??????????E8????????668B0D') + 3)
    OnStart()
end

local function read_wide_string(address, length)
    local count = 0
    local byte_table = {}
    for i = 1, length do
        if read_byte(address + count) ~= 0 then
            byte_table[i] = char(read_byte(address + count))
        end
        count = count + 2
    end
    return concat(byte_table)
end

local function GetServerName()
    return read_wide_string(network_struct + 0x8, 0x42)
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then
        server_name = GetServerName()
    end
end

--
-- USE CASE EXAMPLE:
--
function OnJoin(Ply)
    say(Ply, 'Welcome to ' .. server_name)
end

function OnScriptUnload()
    -- N/A
end
