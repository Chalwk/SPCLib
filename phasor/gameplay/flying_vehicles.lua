--[[
=====================================================================================
SCRIPT NAME:      flying_vehicles.lua
DESCRIPTION:      Enables flying capability for ground vehicles
                  - Toggle with: fly [on/off]
                  - Configurable per vehicle type
                  - Auto-reset when server empties (configurable)

                  Default enabled vehicles:
                  - Rocket Warthog
                  - Warthog

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--- config starts
local base_command = "fly"
local no_players_reset = true
local vehicles = {
    ["vehicles\\ghost\\ghost_mp"] = false,
    ["vehicles\\rwarthog\\rwarthog"] = true,
    ["vehicles\\warthog\\mp_warthog"] = true,
    ["vehicles\\banshee\\banshee_mp"] = false,
    ["vehicles\\scorpion\\scorpion_mp"] = false,
    ["vehicles\\c gun turret\\c gun turret_mp"] = false
}
--- config ends

function GetRequiredVersion()
    return 200
end

function OnScriptLoad(processId, game, persistent) end

local rollback = nil
local tag_address, tag_count

local function get_player_count()
    local count = 0
    for i = 0, 15 do
        if getplayer(i) then count = count + 1 end
    end
    return count
end

local function read_string(address)
    local str = ""
    local i = 0
    while true do
        local byte = readbyte(address + i)
        if byte == 0 then break end
        str = str .. string.char(byte)
        i = i + 1
    end
    return str
end

local function parse_args(cmd)
    local args = {}
    for str in cmd:gmatch("([^%s]+)") do
        table.insert(args, str:lower())
    end
    return args
end

local function toggle_fly(state)
    if state == "enabled" then
        for i = 0, tag_count - 1 do
            local offset = tag_address + 0x20 * i
            if readdword(offset) == 1986357353 then
                local tag_name = read_string(readdword(offset + 0x10))
                for tag, enabled in pairs(vehicles) do
                    if tag_name == tag and enabled then
                        local data = readdword(offset + 0x14)
                        local value = readword(data + 0x2F4)
                        if value == 0 or value == 1 or value == 2 or value == 4 then
                            rollback = rollback or {}
                            table.insert(rollback, { data + 0x2F4, readword(data + 0x2F4) })
                            writeword(data + 0x2F4, 0x3)
                        end
                    end
                end
            end
        end
    elseif rollback then
        for _, v in pairs(rollback) do
            writeword(v[1], v[2])
        end
        rollback = nil
    end
end

function OnCommand(player, command)
    local args = parse_args(command)
    if args and args[1] == base_command then
        local toggled = rollback or false
        local state = args[2]

        if not state then
            state = toggled and "activated" or "not activated"
            privatesay(player, "Flying Vehicles " .. state)
        elseif state == "on" or state == "1" or state == "true" then
            state = "enabled"
        elseif state == "off" or state == "0" or state == "false" then
            state = "disabled"
        else
            state = nil
        end

        if (toggled and state == "enabled") or (not toggled and state == "disabled") then
            privatesay(player, "Flying Vehicles already " .. state)
        elseif state then
            toggle_fly(state)
            say("Flying Vehicles " .. state)
        else
            privatesay(player, "Invalid Command Argument.")
            privatesay(player, 'Usage: "on", "1", "true", "off", "0" or "false"')
        end
        return false
    end
end

function OnGameStart()
    tag_address = 0x40440000
    tag_count = readdword(0x4044000C)
    toggle_fly()
end

function OnPlayerLeave(player)
    local playerCount = get_player_count()
    if playerCount - 1 <= 0 and rollback then
        toggle_fly()
    end
end
