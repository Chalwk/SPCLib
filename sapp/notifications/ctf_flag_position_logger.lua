--[[
=====================================================================================
SCRIPT NAME:      ctf_flag_position_logger.lua
DESCRIPTION:      Logs precise coordinates of Capture The Flag (CTF) flag spawn points
                  at the start of each game. Ideal for map data collection or custom
                  CTF scripting.

OUTPUT EXAMPLE:
  {x, y, z},
  {x, y, z}


COPYRIGHT (c) 2025 Jericho Crosby (Chalwk)
LICENSE: MIT License
         https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local ctf_globals
local sig = "8B3C85????????3BF9741FE8????????8B8E2C0200008B4610"

function OnScriptLoad()
    local address = sig_scan(sig)
    if address == 0 then
        cprint("[CTF Logger] Failed to locate memory signature.", 12)
        return
    end

    -- The pointer is 3 bytes ahead of the signature start
    ctf_globals = read_dword(address + 3)

    register_callback(cb["EVENT_GAME_START"], "OnStart")
end

function OnStart()
    if not ctf_globals or ctf_globals == 0 then
        cprint("[CTF Logger] CTF globals pointer not initialized.", 12)
        return
    end

    local red_ptr = read_dword(ctf_globals)
    local blue_ptr = read_dword(ctf_globals + 4)

    if red_ptr == 0 or blue_ptr == 0 then
        cprint("[CTF Logger] Unable to read flag pointers.", 12)
        return
    end

    local rx, ry, rz = read_vector3d(red_ptr)
    local bx, by, bz = read_vector3d(blue_ptr)

    cprint(string.format("{%.4f, %.4f, %.4f},", rx, ry, rz))
    cprint(string.format("{%.4f, %.4f, %.4f}", bx, by, bz))
end

function OnScriptUnload() end
