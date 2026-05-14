--[[
=====================================================================================
SCRIPT NAME:      flying_vehicles.lua
DESCRIPTION:      Enables flying capability for ground vehicles
                  - Toggle with: !fly [on/off]
                  - Configurable per vehicle type
                  - Permission level protection
                  - Auto-reset when server empties (configurable)

                  Default enabled vehicles:
                  - Rocket Warthog
                  - Warthog

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration
local FlyingVehicles = {
    -- Custom command to toggle fly mode on/off
    base_command = "fly",
    permission = 1,  -- Minimum permission required to toggle fly mode
    no_players_reset = true,  -- Should Flying Vehicles be reset when no players are online?

    vehicles = {
        -- Set to false to disable flying for specific vehicles:
        ["vehicles\\ghost\\ghost_mp"] = false,
        ["vehicles\\rwarthog\\rwarthog"] = true,
        ["vehicles\\warthog\\mp_warthog"] = true,
        ["vehicles\\banshee\\banshee_mp"] = false,
        ["vehicles\\scorpion\\scorpion_mp"] = false,
        ["vehicles\\c gun turret\\c gun turret_mp"] = false
    }
}

-- Internal Variables
local tag_address, tag_count

-- Event Handlers
function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_LEAVE, "OnPlayerQuit")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    OnGameStart()
end

function OnScriptUnload()
    FlyingVehicles:Toggle()
end

function OnGameStart()
    if get_var(0, "$gt") ~= "n/a" then
        tag_address = read_dword(0x40440000)
        tag_count = read_dword(0x4044000C)
        FlyingVehicles:Toggle()
    end
end

function FlyingVehicles:Quit()
    local playerCount = tonumber(get_var(0, "$pn"))
    if playerCount - 1 <= 0 and self.rollback then
        self:Toggle()
    end
end

local function SplitCommand(command)
    local args = {}
    for str in command:gmatch("([^%s]+)") do
        table.insert(args, str:lower())
    end
    return args
end

function FlyingVehicles:OnCommand(playerId, command, _, _)
    local args = SplitCommand(command)
    if args and args[1] == self.base_command then
        local playerLevel = tonumber(get_var(playerId, "$lvl"))

        if playerLevel >= self.permission then
            local toggled = self.rollback or false
            local state = args[2]

            if not state then
                state = toggled and "activated" or "not activated"
                rprint(playerId, "Flying Vehicles " .. state)
            elseif state == "on" or state == "1" or state == "true" then
                state = "enabled"
            elseif state == "off" or state == "0" or state == "false" then
                state = "disabled"
            else
                state = nil
            end

            if (toggled and state == "enabled") or (not toggled and state == "disabled") then
                rprint(playerId, "Flying Vehicles already " .. state)
            elseif state then
                self:Toggle(state)
                say_all("Flying Vehicles " .. state)
            else
                rprint(playerId, "Invalid Command Argument.")
                rprint(playerId, 'Usage: "on", "1", "true", "off", "0" or "false"')
            end
        else
            rprint(playerId, "You do not have permission to execute that command.")
        end
        return false
    end
end

function FlyingVehicles:Toggle(state)
    if state == "enabled" then
        for i = 0, tag_count - 1 do
            local offset = tag_address + 0x20 * i
            if read_dword(offset) == 1986357353 then
                local tag_name = read_string(read_dword(offset + 0x10))
                for tag, enabled in pairs(self.vehicles) do
                    if tag_name == tag and enabled then
                        local data = read_dword(offset + 0x14)
                        local value = read_word(data + 0x2F4)
                        if value == 0 or value == 1 or value == 2 or value == 4 then
                            self.rollback = self.rollback or {}
                            table.insert(self.rollback, { data + 0x2F4, read_word(data + 0x2F4) })
                            write_word(data + 0x2F4, 0x3)  -- Enable flying
                        end
                    end
                end
            end
        end
    elseif self.rollback then
        for _, v in pairs(self.rollback) do
            write_word(v[1], v[2])  -- Restore original values
        end
        self.rollback = nil
    end
end

function OnCommand(playerId, command)
    return FlyingVehicles:OnCommand(playerId, command)
end

function OnPlayerQuit()
    FlyingVehicles:Quit()
end
