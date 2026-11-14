--[[
===============================================================================
SCRIPT NAME:    get_server_name.lua
DESCRIPTION:    Reads the current server name from the network struct and
                welcomes joining players with it.

USAGE:          getServerName() - safe to call from any callback
                                  or via: lua_call get_server_name getServerName

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
================================================================================
]]

api_version = "1.12.0.0"

local NETWORK_STRUCT_SIG = "F3ABA1????????BA????????C740??????????E8????????668B0D"
local NETWORK_STRUCT_OFFSET = 3

local NAME_OFFSET = 0x8
local NAME_MAX_CHARS = 0x42

local network_struct
local concat, char = table.concat, string.char

local function safeScan(sig, offset)
    local hit = sig_scan(sig)
    if hit == 0 then return nil end

    local ptr = read_dword(hit + offset)
    if not ptr or ptr < 0x400000 or ptr > 0x800000 then return nil end

    return ptr
end

local function readWideString(address, max_chars)
    local chars = {}
    for i = 0, (max_chars - 1) * 2, 2 do
        local lo = read_byte(address + i)
        if lo == 0 then break end
        ---@diagnostic disable-next-line: param-type-mismatch
        chars[#chars + 1] = char(lo)
    end
    return concat(chars)
end

local function getServerName()
    if not network_struct then return "" end
    return readWideString(network_struct + NAME_OFFSET, NAME_MAX_CHARS)
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, "OnJoin")

    network_struct = safeScan(NETWORK_STRUCT_SIG, NETWORK_STRUCT_OFFSET)
    if not network_struct then
        cprint("[get_server_name] ERROR: network_struct not found", 12)
    end
end

function OnJoin(player_id)
    if not player_id or not player_present(player_id) then return end

    local name = getServerName()
    if name ~= "" then
        say(player_id, "Welcome to " .. name)
    end
end

function OnScriptUnload()
    network_struct = nil
end
