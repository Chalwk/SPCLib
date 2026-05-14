--[[
=====================================================================================
SCRIPT NAME:      custom_teleports.lua
DESCRIPTION:      Creates configurable instant teleport zones that transport players
                  between defined locations when entering activation areas.

FEATURES:
                  - Map-specific teleport configuration
                  - Adjustable activation radius
                  - Optional crouch activation requirement
                  - Cooldown system to prevent abuse
                  - Vehicle usage protection

USAGE:
                  1. Add teleport entries for each supported map in CFG table
                  2. Format: {srcX, srcY, srcZ, radius, destX, destY, destZ, zOffset}
                  3. Set CROUCH_ACTIVATED true for crouch-only activation

EXAMPLE CONFIG:
                  ["bloodgulch"] = {
                      {98.80, -156.30, 1.70, 0.5, 72.58, -126.33, 1.18, 0}, -- Red base health pack to rocket launcher mid-map
                      {36.87, -82.33, 1.70, 0.5, 72.58, -126.33, 1.18, 0}    -- Blue base health pack to rocket launcher mid-map
                  }

LAST UPDATED:     August 19, 2025

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-----------------
-- CONFIG STARTS
-----------------

local CROUCH_ACTIVATED = false  -- Set to true for crouch-only activation
local COOLDOWN = 0              -- Cooldown in seconds (0 = disabled)

local CFG = {
    ["bloodgulch"] = {
		{ 48.046, -153.087, 21.181, 0.5, 23.112, -59.428, 16.352, 0 },
		{ 43.258, -45.365, 20.901, 0.5, 82.068, -68.505, 18.101, 0 },
		{ 82.459, -73.877, 15.729, 0.5, 67.970, -86.299, 23.393, 0 },
		{ 77.756, -89.082, 22.434, 0.5, 92.456, -111.263, 14.945, 0 },
		{ 101.136, -117.054, 14.962, 0.5, 105.877, -117.677, 15.323, 0 },
		{ 116.826, -120.564, 15.109, 0.5, 124.988, -135.579, 13.575, 0 },
		{ 131.785, -169.872, 15.951, 0.5, 127.812, -184.557, 16.420, 0 },
		{ 120.665, -188.766, 13.752, 0.5, 109.956, -188.522, 14.437, 0 },
		{ 97.476, -188.912, 15.718, 0.5, 53.653, -157.885, 21.753, 0 },
		{ 56.664, -164.837, 22.795, 0.5, 96.744, -186.242, 14.131, 0 },
		{ 111.995, -188.984, 14.651, 0.5, 122.376, -187.829, 13.938, 0 },
		{ 129.211, -183.764, 17.222, 0.5, 130.083, -170.598, 14.916, 0 },
		{ 128.141, -136.294, 14.547, 0.5, 112.550, -127.203, 1.905, 0 },
		{ 118.263, -120.761, 17.192, 0.5, 39.968, -139.983, 2.518, 0 },
		{ 102.131, -117.216, 14.871, 0.5, 100.467, -116.833, 14.929, 0 },
		{ 90.741, -109.854, 14.751, 0.5, 74.335, -89.752, 23.676, 0 },
		{ 68.909, -82.116, 22.843, 0.5, 82.065, -68.507, 18.152, 0 },
		{ 78.907, -64.793, 19.836, 0.5, 33.687, -50.148, 19.162, 0 },
		{ 21.916, -61.007, 16.189, 0.5, 50.409, -155.826, 21.830, 0 },
		{ 14.852, -99.241, 8.995, 0.5, 50.409, -155.826, 21.830, 0 },
		{ 98.559, -158.558, -0.253, 0.5, 63.338, -169.305, 3.702, 0 },
		{ 98.541, -160.190, -0.255, 0.5, 119.995, -183.364, 6.667, 0 },
		{ 92.538, -160.213, -0.215, 0.5, 112.550, -127.203, 1.905, 0 },
		{ 92.550, -158.581, -0.256, 0.5, 46.934, -151.024, 4.496, 0 },
		{ 98.935, -157.626, 0.425, 0.5, 96.431, -121.027, 3.757, 0 },
		{ 74.304, -77.590, 6.552, 0.5, 76.001, -77.936, 11.425, 0 },
		{ 94.351, -97.615, 5.184, 0.5, 92.792, -93.604, 9.501, 0 },
		{ 84.848, -127.267, 0.563, 0.5, 74.335, -89.752, 23.676, 0 },
		{ 63.693, -177.303, 5.606, 0.5, 19.030, -103.428, 19.150, 0 },
		{ 70.535, -62.097, 5.392, 0.5, 122.491, -123.891, 15.646, 0 },
		{ 89.473, -115.480, 17.013, 0.5, 108.005, -109.328, 1.924, 0 },
		{ 120.605, -185.611, 7.626, 0.5, 95.746, -114.248, 16.032, 0 },
		{ 43.125, -78.434, -0.273, 0.5, 15.720, -102.766, 13.465, 0 },
		{ 43.112, -80.069, -0.278, 0.5, 68.123, -92.847, 2.167, 0 },
		{ 37.105, -80.069, -0.255, 0.5, 108.005, -109.328, 1.924, 0 },
		{ 37.080, -78.426, -0.238, 0.5, 79.924, -64.560, 4.669, 0 },
		{ 38.559, -79.209, 0.769, 0.5, 69.833, -88.165, 5.660, 0 },
		{ 43.456, -77.197, 0.633, 0.5, 29.528, -52.746, 3.100, 0 },
    },
    -- add more maps here
}

---------------
-- CONFIG ENDS
---------------

api_version = "1.12.0.0"

local map_cfg
local last_teleport = {}

local rprint = rprint
local os_time = os.time
local read_float = read_float
local read_dword = read_dword
local player_alive = player_alive
local read_vector3d = read_vector3d
local write_vector3d = write_vector3d
local player_present = player_present
local get_dynamic_player = get_dynamic_player

function OnScriptLoad()
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

local function precompute_teleports(cfg)
    for _, t in ipairs(cfg) do
        local cx, cy, cz = t[1], t[2], t[3]
        local radius = t[4] or 0.0

        t.cx, t.cy, t.cz = cx, cy, cz
        t.radius = radius
        t.radius_sq = radius * radius

        t.destX, t.destY, t.destZ = t[5], t[6], t[7]
        t.zOff = t[8] or 0

        -- Axis-aligned bounding box for a cheap early reject
        t.minX, t.maxX = cx - radius, cx + radius
        t.minY, t.maxY = cy - radius, cy + radius
        t.minZ, t.maxZ = cz - radius, cz + radius
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    local map = get_var(0, '$map')
    local cfg = CFG[map]

    if cfg then

        local tmp = {}
        for i, entry in ipairs(cfg) do tmp[i] = { unpack(entry) } end

        precompute_teleports(tmp)
        map_cfg = tmp

        register_callback(cb.EVENT_TICK, 'OnTick')
    else
        unregister_callback(cb.EVENT_TICK)
    end
end

function OnTick()
    for i = 1, 16 do
        if not player_present(i) or not player_alive(i) then goto continue end

        local dyn = get_dynamic_player(i)
        if dyn == 0 then goto continue end

        -- vehicle check
        if read_dword(dyn + 0x11C) == 0xFFFFFFF then goto continue end

        local position = dyn + 0x5C
        local x, y, z = read_vector3d(position)

        if CROUCH_ACTIVATED then
            local crouch_state = read_float(dyn + 0x50C)
            if crouch_state ~= 1 then goto continue end
            z = z + 0.35
        end

        -- cooldown check
        local last = last_teleport[i]
        if last and os_time() < last + COOLDOWN then goto continue end

        -- iterate teleporters:
        for _, t in ipairs(map_cfg) do

            if x >= t.minX and x <= t.maxX
            and y >= t.minY and y <= t.maxY
            and z >= t.minZ and z <= t.maxZ then

                local dx = x - t.cx
                local dy = y - t.cy
                local dz = z - t.cz
                local distSq = dx * dx + dy * dy + dz * dz

                if distSq <= t.radius_sq then
                    local zOff = (CROUCH_ACTIVATED and 0) or t.zOff

                    write_vector3d(position, t.destX, t.destY, t.destZ + zOff)
                    rprint(i, 'WOOSH!')
                    last_teleport[i] = os_time()
                    break
                end
            end
        end

        ::continue::
    end
end

function OnQuit(id)
    last_teleport[id] = nil
end

function OnScriptUnload() end