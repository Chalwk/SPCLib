--[[
=====================================================================================
SCRIPT NAME:      low_ammo_warning.lua
DESCRIPTION:      A simple script that displays a warning message when your weapon's
                  ammo is running low.

                  Command: /ammo_warn - Toggle low ammo display

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true        -- enable the script
local COMMAND = "ammo_warn" -- command to toggle the script
local AMMO_THRESHOLD = 5    -- ammo count below which warning triggers
local WARNING_INTERVAL = 30 -- ticks between warning repetitions
local FLASH_DURATION = 5    -- how long the warning message flashes on screen (in ticks)
-- END CONFIG --

local timer, flash_timer, warning_active = 0, 0, false

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

function OnTick()
    local player = get_dynamic_player()
    if not player then return end

    local weapon = get_object(read_dword(player + 0x118))
    if not weapon then return end

    local ammo = read_word(weapon + 0x2B6) -- current ammo
    local low = ammo <= AMMO_THRESHOLD

    if low ~= warning_active then
        warning_active = low
        if not low then flash_timer = 0 end
    end

    if warning_active then
        timer = timer + 1
        if timer >= WARNING_INTERVAL then
            timer = 0
            flash_timer = FLASH_DURATION
        end
        if flash_timer > 0 then
            for _ = 1, 10 do
                hud_message(" ")
            end
            hud_message("LOW AMMO!")
            flash_timer = flash_timer - 1
        end
    end
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED -- set to the opposite of current state
        console_out("Low Ammo Warning " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end
