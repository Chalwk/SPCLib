--[[
===============================================================================
SCRIPT NAME:      custom_colors.lua
DESCRIPTION:      Customizes player colors with:
                  - Team-based colors (Red/Yellow, Blue/Blue by default)
                  - Random FFA colors from 18 options
                  - Automatic color assignment on join/team switch

CONFIGURATION:    Edit the colors table to:
                  - Set team colors (red/blue values 0-17)
                  - Customize FFA color pool (values 0-17)
                  - Add/remove FFA color options

COLOR REFERENCE:  0=white, 1=black, 2=red, 3=blue, 4=gray, 5=yellow
                  6=green, 7=pink, 8=purple, 9=cyan, 10=cobalt
                  11=orange, 12=teal, 13=sage, 14=brown, 15=tan
                  16=maroon, 17=salmon

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- config starts --
local colors = {

    team = {
        red = 5, -- yellow
        blue = 3 -- blue
    },

    ffa = {
        0,  -- white
        1,  -- black
        2,  -- red
        3,  -- blue
        4,  -- gray
        5,  -- yellow
        6,  -- green
        7,  -- pink
        8,  -- purple
        9,  -- cyan
        10, -- cobalt
        11, -- orange
        12, -- teal
        13, -- sage
        14, -- brown
        15, -- tan
        16, -- maroon
        17  -- salmon
    }
}
-- config ends --

local ffa, sig
api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")

    sig = sig_scan("741F8B482085C9750C")
    if (sig == 0) then
        sig = sig_scan("EB1F8B482085C9750C")
    end

    OnStart()
end

local function WriteSig(state)
    if (state) then
        safe_write(true)
        write_char(sig, 235)
        safe_write(false)
    elseif (sig == 0 or sig == nil) then
        return
    else
        safe_write(true)
        write_char(sig, 116)
        safe_write(false)
    end
end

function OnStart()
    ffa = nil
    WriteSig(false)

    if (get_var(0, "$gt") ~= "n/a") then
        WriteSig(true)
        ffa = get_var(0, "$ffa")

        register_callback(cb.EVENT_JOIN, "SetColor")
        register_callback(cb.EVENT_TEAM_SWITCH, "SetColor")
    end
end

local function GetColor(Ply)
    if (ffa == "1") then
        return colors.ffa[rand(1, #colors.ffa + 1)]
    else
        return colors.team[get_var(Ply, "$team")]
    end
end

function SetColor(Ply)
    local player = get_player(Ply)
    if (player ~= 0) then
        safe_write(true)
        write_byte(player + 0x60, GetColor(Ply))
        safe_write(false)
    end
end

function OnScriptUnload()
    WriteSig(false)
end
