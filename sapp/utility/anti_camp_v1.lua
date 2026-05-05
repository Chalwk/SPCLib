--[[
=====================================================================================
SCRIPT NAME:      anti_camp_v1.lua
DESCRIPTION:      Camping prevention system with:
                  - Configurable per-map zones
                  - Dynamic radius & duration tracking
                  - Progressive warnings & punishment
                  - Cooldown-protected enforcement
                  - Automatic reset on spawn/disconnect

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start --------------------------------------------
local COOLDOWN = 10 -- Cooldown period in seconds

-- Customizable messages:
local MESSAGES = {
    LOADED = "[Anti-Camp] Loaded %d zones for %s",      -- Console message when zones are loaded
    NONE = "[Anti-Camp] No zones configured for %s",    -- Console message when no zones
    WARNING = "WARNING: Move or be killed in %ds!",     -- Player warning message
    PUNISH = "No camping allowed!",                     -- Punishment message
}

-- Camping zones {x, y, z, radius, max_time}
local MAPS = {
    ["bloodgulch"] = {
        {98.80, -156.30, 1.70, 5.0, 120},  -- RED base
        {36.87, -82.33, 1.70, 5.0, 120},   -- BLUE base
    }
    -- Add configurations for other maps using the same structure
}
-- Config End ----------------------------------------------

api_version = "1.12.0.0"

local map
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
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function punishPlayer(player)
    execute_command('kill ' .. player)
    rprint(player, MESSAGES.PUNISH)
    return os.time()
end

function OnScriptLoad()
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnSpawn(id)
    players[id] = nil -- Reset data on spawn
end

function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        map = get_var(0, '$map')
        local zones = MAPS[map]

        if zones and #zones > 0 then
            cprint(string.format(MESSAGES.LOADED, #zones, map), 12)
            register_callback(cb['EVENT_TICK'], 'OnTick')
        else
            unregister_callback(cb['EVENT_TICK'])
            cprint(string.format(MESSAGES.NONE, map), 12)
        end
    end
end

function OnTick()
    local current_time = os.time()
    local zones = MAPS[map]

    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if not inVehicle(dyn) then
                local x, y, z = getXYZ(dyn)
                local data = players[i] or {}

                -- Check cooldown status
                if data.last_punishment and (current_time - data.last_punishment) < COOLDOWN then
                    goto continue
                end

                -- Check all camping zones
                local in_zone = false
                for index, zone in ipairs(zones) do
                    local dist = getDistance(x, y, z, zone[1], zone[2], zone[3])
                    if dist <= zone[4] then
                        in_zone = true

                        -- Initialize zone timer if new zone
                        if data.zone ~= index then
                            data.zone = index
                            data.entry_time = current_time
                            data.warned = false
                        end

                        -- Check camping duration
                        local elapsed = current_time - data.entry_time
                        local max_time = zone[5]

                        -- Warn at 50% of max time
                        if not data.warned and elapsed >= max_time/2 then
                            local time_left = max_time - elapsed
                            rprint(i, string.format(MESSAGES.WARNING, floor(time_left)))
                            data.warned = true
                        end

                        -- Kill if exceeded max time
                        if elapsed >= max_time then
                            data.last_punishment = punishPlayer(i)
                            data.zone = nil
                            break
                        end
                    end
                end

                -- Reset if not in any zone
                if not in_zone and data.zone then
                    data.zone = nil
                    data.entry_time = nil
                end

                players[i] = data
            end
        end
        ::continue::
    end
end

function OnQuit(id)
    players[id] = nil
end

function OnScriptUnload()
    -- Cleanup
end