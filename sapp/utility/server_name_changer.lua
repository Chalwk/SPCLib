--[[
=====================================================================================
SCRIPT NAME:      server_name_changer.lua
DESCRIPTION:      Cycles through server names at regular intervals for dynamic branding.

Copyright (c) 2021-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- config starts --
-- The script will pick a new server name every 15 seconds:
local INTERVAL = 15
local SERVER_NAMES = {
    "My Cool Server",
    "A server!",
    " ",          -- blank
    "Ya mom!",
    "CoronaVirus" -- repeat the structure to add more entries.
}
-- config ends --

local network_struct
function OnScriptLoad()
    network_struct = read_dword(sig_scan("F3ABA1????????BA????????C740??????????E8????????668B0D") + 3)
    if not network_struct then
        print("[server_name_changer] ERROR: network_struct not found")
        return
    end
    timer(INTERVAL, "ChangeServerName")
end

local function write_widestring(address, str, len)
    for i = 0, len - 1 do
        write_word(address + i * 2, 0)
    end
    for i = 1, #str do
        write_byte(address + (i - 1) * 2, string.byte(str, i))
    end
end

local index = 1
function ChangeServerName()
    write_widestring(network_struct + 0x8, SERVER_NAMES[index], 0x42)
    index = index + 1
    if index > #SERVER_NAMES then index = 1 end
    return true
end
