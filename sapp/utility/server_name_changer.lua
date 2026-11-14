--[[
=====================================================================================
SCRIPT NAME:      server_name_changer.lua
DESCRIPTION:      Cycles through server names at a fixed interval for dynamic
                  branding.

Copyright (c) 2021-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Config starts --
-- Pick a new server name every N seconds (must be positive):
local INTERVAL_SECONDS = 15

-- Names cycled in order. Keep each entry shorter than NAME_MAX_CHARS (66):
local SERVER_NAMES = {
    "My Cool Server",
    "A server!",
    " ",          -- blank
    "Ya mom!",
    "CoronaVirus" -- add more entries here
}
-- Config ends --

local NETWORK_STRUCT_SIG = "F3ABA1????????BA????????C740??????????E8????????668B0D"
local NETWORK_STRUCT_OFFSET = 3

local NAME_OFFSET = 0x8
local NAME_MAX_CHARS = 0x42

local network_struct
local name_index = 1

local function safeScan(sig, offset)
    local hit = sig_scan(sig)
    if hit == 0 then return nil end

    local ptr = read_dword(hit + offset)
    if not ptr or ptr < 0x400000 or ptr > 0x800000 then return nil end

    return ptr
end

local function writeWideString(address, str, max_chars)
    local length = #str
    if length > max_chars then length = max_chars end

    -- Clear the buffer (also zeroes the trailing null terminator):
    for i = 0, max_chars - 1 do
        write_word(address + i * 2, 0)
    end

    -- Write the low byte of each ASCII character; high byte remains 0:
    for i = 1, length do
        write_byte(address + (i - 1) * 2, str:byte(i))
    end
end

function OnScriptLoad()
    network_struct = safeScan(NETWORK_STRUCT_SIG, NETWORK_STRUCT_OFFSET)
    if not network_struct then
        cprint("[server_name_changer] ERROR: network_struct not found", 12)
        return
    end

    timer(INTERVAL_SECONDS * 1000, "ChangeServerName")
end

function ChangeServerName()
    if not network_struct then return false end

    writeWideString(network_struct + NAME_OFFSET, SERVER_NAMES[name_index], NAME_MAX_CHARS)

    name_index = name_index + 1
    if name_index > #SERVER_NAMES then name_index = 1 end

    return true -- repeat indefinitely
end

function OnScriptUnload()
    network_struct = nil
end
