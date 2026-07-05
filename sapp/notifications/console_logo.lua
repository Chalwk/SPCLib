--[[
===============================================================================
SCRIPT NAME:      console_logo.lua
DESCRIPTION:      Displays custom ASCII art in server console with:
                  - Automatic timestamp and server name insertion
                  - Color-coded text support
                  - Multi-line formatting

CONFIGURATION:    Edit the logo table to:
                  - Add/remove ASCII art lines
                  - Set text colors (0-255)
                  - Use $time_stamp and $server_name variables
                  - Adjust timestamp format

CREATION TIP:     Generate ASCII art at:
                  https://patorjk.com/software/taag/
                  (Use 'KBAN' font for best results)

Copyright (c) 2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- config starts --

-- See this page for instructions on tweaking the time stamp format:
-- https://www.lua.org/pil/22.1.html
local time_stamp_format = "$A, $d $B $Y - $X"

local logo = {

    -- format: {"text", text color code}
    -- See SAPP documentation for color codes:
    -- http://halo.isimaginary.com/SAPP$20Documentation$20Revision$202.5.pdf

    -- Make sure logo text is encapsulated in "quotes".

    -- Custom Variables: "$time_stamp" & "$server_name"
    -- Use anywhere to output their values

    { "================================================================================", 10 },
    { "$time_stamp", 6 },
    { "" },
    { "     '||'  '||'     |     '||'       ..|''||           ..|'''.| '||''''|  ", 12 },
    { "      ||    ||     |||     ||       .|'    ||        .|'     '   ||  .    ", 12 },
    { "      ||''''||    |  ||    ||       ||      ||       ||          ||''|    ", 12 },
    { "      ||    ||   .''''|.   ||       '|.     ||       '|.      .  ||       ", 12 },
    { "     .||.  .||. .|.  .||. .||.....|  ''|...|'         ''|....'  .||.....| ", 12 },
    { "               ->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-", 7 },
    { "                             $server_name", 10 },
    { "               ->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-<->-", 7 },
    { "" },
    { "================================================================================", 10 }
}

-- config ends --

local network_struct

api_version = "1.12.0.0"

function OnScriptLoad()
    network_struct = read_dword(sig_scan("F3ABA1????????BA????????C740??????????E8????????668B0D") + 3)
    timer(50, "PrintLogo")
end

local function read_widestring(address, length)
    local count = 0
    local byte_table = {}
    for i = 1, length do
        if (read_byte(address + count) ~= 0) then
            byte_table[i] = string.char(read_byte(address + count))
        end
        count = count + 2
    end
    return table.concat(byte_table)
end

function PrintLogo()
    local game_type = get_var(0, "$gt")
    if game_type ~= "n/a" then
        local time_stamp = os.date(time_stamp_format)
        local server_name = read_widestring(network_struct + 0x8, 0x42)
        for _, v in pairs(logo) do
            local text = v[1]
            local color = v[2] or 0
            local art = text:gsub("$time_stamp", time_stamp):gsub("$server_name", server_name)

            cprint(art, color)
        end
    end
end

function OnScriptUnload()
    -- N/A
end
