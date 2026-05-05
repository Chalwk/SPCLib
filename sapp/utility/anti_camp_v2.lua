--[[
=====================================================================================
SCRIPT NAME:      anti_camp_v2.lua
DESCRIPTION:      Universal camping prevention system with:
                  - Continuous global monitoring
                  - Radius-based movement detection
                  - Dynamic warning at 50% of max time
                  - Automatic punishment on threshold exceed
                  - Cooldown-protected enforcement
                  - Automatic reset on spawn/disconnect

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start ---------------------------------------------------
local COOLDOWN = 10       -- Cooldown period in seconds
local MAX_CAMP_TIME = 120 -- Maximum allowed camping time (in seconds)
local CAMP_RADIUS = 1.0   -- Radius (world units) within which movement is considered camping

-- Customizable messages:
local MESSAGES = {
    WARNING = "WARNING: Move or be killed in %ds!", -- Player warning message
    PUNISH = "No camping allowed!",                 -- Punishment message
}
-- Config End -------------------------------------------------

api_version = "1.12.0.0"

local players = {}
local floor = math.floor

local function getXYZ(dyn)
    return read_vector3d(dyn + 0x5C)
end

local function inVehicle(dyn)
    return read_dword(dyn + 0x11C) == 0xFFFFFFF
end

local function getDistance(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function punishPlayer(player)
    execute_command('kill ' .. player)
    rprint(player, MESSAGES.PUNISH)
    return os.time()
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
end

function OnJoin(id)
    players[id] = {
        last_punishment = nil,
        start_time = nil,
        last_x = nil,
        last_y = nil,
        last_z = nil,
        warned = false
    }
end

function OnSpawn(id)
    if players[id] then
        players[id].start_time = nil
        players[id].last_x = nil
        players[id].last_y = nil
        players[id].last_z = nil
        players[id].warned = false
    end
end

function OnTick()
    local current_time = os.time()

    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if dyn ~= 0 and not inVehicle(dyn) then
                local x, y, z = getXYZ(dyn)
                local data = players[i]

                -- Check cooldown status
                local in_cooldown = data.last_punishment and (current_time - data.last_punishment) < COOLDOWN

                if not data.start_time then
                    -- Start monitoring new position
                    data.start_time = current_time
                    data.last_x = x
                    data.last_y = y
                    data.last_z = z
                    data.warned = false
                else
                    -- Calculate distance from last recorded position
                    local dist = getDistance(x, y, z, data.last_x, data.last_y, data.last_z)

                    if dist <= CAMP_RADIUS and not in_cooldown then
                        -- Player hasn't moved enough
                        local elapsed = current_time - data.start_time

                        -- Warn at 50% of max time
                        if not data.warned and elapsed >= MAX_CAMP_TIME / 2 then
                            local time_left = MAX_CAMP_TIME - elapsed
                            rprint(i, string.format(MESSAGES.WARNING, floor(time_left)))
                            data.warned = true
                        end

                        -- Punish if exceeded max time
                        if elapsed >= MAX_CAMP_TIME then
                            data.last_punishment = punishPlayer(i)
                            -- Reset monitoring after punishment
                            data.start_time = nil
                        end
                    else
                        -- Player moved beyond radius - reset monitoring
                        data.start_time = current_time
                        data.last_x = x
                        data.last_y = y
                        data.last_z = z
                        data.warned = false
                    end
                end
            end
        end
    end
end

function OnQuit(id)
    players[id] = nil
end

function OnScriptUnload()
    -- Cleanup
end
