--[[
=============================================================================================================
SCRIPT NAME:      anti_aimbot.lua
DESCRIPTION:      Advanced anti-cheat system designed to detect and prevent aim assistance cheating.

                  KEY FEATURES:
                  - Multi-Layered Detection: Combines angle threshold monitoring, velocity analysis, and
                    predictive trajectory calculations to identify unnatural aiming patterns
                  - Dynamic Threshold Adjustment: Automatically adapts sensitivity based on player accuracy
                    and movement patterns to minimize false positives
                  - Weapon-Specific Profiling: Differentiates detection parameters for various weapons based
                    on their inherent accuracy and gameplay characteristics
                  - Environmental Awareness: Accounts for visibility conditions and physical obstructions
                    to validate suspected aim locks
                  - Camouflage Detection: Detects when a target is using active camouflage and applies a
                    scoring modifier - hitting invisible players is a strong indicator of cheating
                  - Pattern Recognition: Detects robotic firing patterns and consistent interval timing
                    indicative of automated assistance
                  - Automatically executes configured moderation commands upon
                    confirmation of cheating

                  USAGE:
                  1. Configure detection parameters in the CONFIG table according to your server's needs
                  2. Adjust weapon-specific modifiers to match your server's gameplay balance
                  3. Set enforcement commands (default: "k" for kick) and reason messages
                  4. The system operates automatically once loaded - no player-side configuration needed
                  5. Monitor server logs for detection events and adjust thresholds if needed

                  RECOMMENDED SETTINGS:
                  - Lower ANGLE_THRESHOLD_DEGREES (1.5-2.0) for competitive servers
                  - Increase MAX_SCORE (3500-5000) for more lenient enforcement
                  - Adjust WEAPON_MODIFIERS based on your server's weapon prevalence
                  - Enable DYNAMIC_THRESHOLD for adaptive detection in varied gameplay situations

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=============================================================================================================
]]

-- CONFIGURATION --------------------------------------------------------------

api_version = "1.12.0.0"

local AUTO_AIM = {
    ANGLE_THRESHOLD_DEGREES = 2.5,     -- Base angle threshold (degrees)
    MIN_ANGLE_THRESHOLD_DEGREES = 0.2, -- Minimum angle threshold fallback
    MAX_SCORE = 3000,                  -- Enforcement threshold
    DYNAMIC_THRESHOLD = {              -- Dynamic threshold adjustment
        ENABLED = true,
        BASE_MULTIPLIER = 1.0,         -- Base multiplier for threshold
        ACCURACY_WEIGHT = 0.5,         -- How much accuracy affects threshold (0-1)
        MIN_MULTIPLIER = 0.8,          -- Minimum threshold multiplier
        MAX_MULTIPLIER = 1.2           -- Maximum threshold multiplier
    }
}

local SNAP_DETECTION = {
    BASELINE_DEGREES = 6.0,        -- Significant snap angle (degrees)
    MOVING_THRESHOLD_DEGREES = 0.4 -- Subtle snap threshold while moving (degrees)
}

local PLAYER = {
    TRACE_DISTANCE = 250,   -- Raycast length for hit validation
    PROJECTILE_SPEED = 30.0 -- Assumed projectile speed for trajectory prediction (m/s)
}

local ENFORCEMENT = {
    COMMAND = "k",              -- Command executed on detection (e.g. "k", "b")
    REASON = "Aimbot detection" -- Reason message for enforcement command
}

local DECAY = {
    POINTS_PER_SECOND = 0.25, -- Aim score reduced per second
    INTERVAL_SECONDS = 0.25   -- Update granularity (seconds)
}

local VELOCITY_ADJUSTED = {
    ENABLED = true,        -- Enable velocity adjustment
    SPEED_THRESHOLD = 1.5, -- Minimum speed (m/s) to trigger adjustment
    ANGLE_MODIFIER = 0.8   -- Multiplier for angle threshold during movement
}

local WEAPON_MODIFIERS = {
    ["weapons\\pistol\\pistol"]                   = 1.15, -- High accuracy, fast TTK
    ["weapons\\sniper rifle\\sniper rifle"]       = 0.65, -- Extreme precision required, slower ROF
    ['weapons\\rocket launcher\\rocket launcher'] = 0.75, -- Splash damage, slow projectile
    ['weapons\\flamethrower\\flamethrower']       = 0.50, -- Short range, easy to keep aim on target
    ['weapons\\needler\\mp_needler']              = 0.90, -- Homing projectiles but delayed kill
    ['weapons\\shotgun\\shotgun']                 = 1.40, -- Forgiving spread, high CQC lethality
    ['weapons\\plasma pistol\\plasma pistol']     = 1.10, -- Charged shot aim assist + normal fire
    ['weapons\\plasma rifle\\plasma rifle']       = 1.00, -- Sustained fire, moderate tracking
    ['weapons\\assault rifle\\assault rifle']     = 1.20, -- Bullet spray but easy tracking
    ['weapons\\plasma_cannon\\plasma_cannon']     = 0.85, -- Slow projectile, splash
    DEFAULT                                       = 1.0   -- Default multiplier
}

local ENERGY_WEAPONS = {
    ['weapons\\plasma pistol\\plasma pistol'] = true,
    ['weapons\\plasma rifle\\plasma rifle'] = true,
    ['weapons\\plasma_cannon\\plasma_cannon'] = true
}

local PATTERN_DETECTION = {
    ENABLED = true,        -- Enable pattern recognition
    MAX_STD_DEV = 0.05,    -- Max allowed interval deviation
    SCORE_BOOST = 150,     -- Score added when pattern detected
    MAX_PATTERN_LENGTH = 5 -- Number of recent locks to consider
}

local ENVIRONMENTAL = {
    ENABLED = true,           -- Enable environmental awareness
    OBSCURED_MULTIPLIER = 0.3 -- Multiplier for score when target is obscured
}

local CAMO = {
    ENABLED = true,        -- Enable camouflage detection
    SCORE_MULTIPLIER = 2.0 -- Multiplier applied to score when target is camouflaged
}
-- END CONFIG ---------------------------------------------------------------

local players = {}        -- Per-player state (indexed 1..16)
local camera_vectors = {} -- Last-camera vector per player
local weapon_cache = {}   -- Weapon name cache for performance

local time = os.clock
local fmt = string.format

local sqrt = math.sqrt
local acos = math.acos
local max = math.max
local abs = math.abs
local pi = math.pi
local floor = math.floor

local ipairs = ipairs
local insert = table.insert
local remove = table.remove

local read_vector3d = read_vector3d
local get_object_memory = get_object_memory
local get_dynamic_player = get_dynamic_player
local get_var, get_player = get_var, get_player
local player_present, player_alive = player_present, player_alive
local read_float, read_string, read_dword, read_word = read_float, read_string, read_dword, read_word

local function clamp(v, lo, hi) return (v < lo) and lo or ((v > hi) and hi or v) end

local function vectorLength(x, y, z) return sqrt(x * x + y * y + z * z) end

local function normalize(x, y, z)
    local len = vectorLength(x, y, z)
    if len <= 0 then return 0, 0, 0 end
    return x / len, y / len, z / len
end

local function getCamera(dyn)
    if dyn == 0 then return 0, 0, 0 end
    local cam_x = read_float(dyn + 0x230)
    local cam_y = read_float(dyn + 0x234)
    local cam_z = read_float(dyn + 0x238)
    if cam_x ~= cam_x or cam_y ~= cam_y or cam_z ~= cam_z then return 0, 0, 0 end
    return cam_x, cam_y, cam_z
end

local function getVelocity(dyn)
    local vel_x = read_float(dyn + 0x68)
    local vel_y = read_float(dyn + 0x6C)
    local vel_z = read_float(dyn + 0x70)
    return vel_x, vel_y, vel_z
end

local function getPlayerPosition(dyn)
    local crouch = read_float(dyn + 0x50C)
    local vehicle_id = read_dword(dyn + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    end

    local z_off = (crouch == 0) and 0.65 or 0.35 * crouch
    return x, y, z + z_off
end

local function dotProduct(ax, ay, az, bx, by, bz) return ax * bx + ay * by + az * bz end

-- Calculate angular change between frames (degrees)
local function calculateOrientationChange(id, dyn_ptr)
    if dyn_ptr == 0 then return 0 end
    local cx, cy, cz = getCamera(dyn_ptr)

    -- Normalize the current camera vector
    cx, cy, cz = normalize(cx, cy, cz)

    local prev = camera_vectors[id]
    camera_vectors[id] = { cx, cy, cz }

    if not prev then return 0 end

    local d = dotProduct(prev[1], prev[2], prev[3], cx, cy, cz)
    d = clamp(d, -1, 1)

    -- Handle floating-point precision that might cause acos domain errors
    if abs(d - 1) < 1e-10 then return 0 end

    local angle_rad = acos(d)
    return (angle_rad * 180) / pi
end

-- Calculate mean and standard deviation
local function computeStats(t)
    local sum = 0
    for i = 1, #t do sum = sum + t[i] end
    local mean = sum / #t

    local variance = 0
    for i = 1, #t do
        variance = variance + (t[i] - mean) ^ 2
    end
    return mean, sqrt(variance / #t)
end

-- Get weapon name with caching
local function getWeaponName(id)
    if weapon_cache[id] then return weapon_cache[id] end

    local dyn = get_dynamic_player(id)
    if dyn == 0 then return end

    local weapon = read_dword(dyn + 0x118)
    local object = get_object_memory(weapon)
    if object == 0 then return end

    local name = read_string(read_dword(read_word(object) * 32 + 0x40440038))
    weapon_cache[id] = name
    return name
end

-- Check if target is visible (not behind wall)
local function isVisible(shooter_id, target_id)
    local shooter_dyn = get_dynamic_player(shooter_id)
    local target_dyn = get_dynamic_player(target_id)
    if shooter_dyn == 0 or target_dyn == 0 then return false end

    local sx, sy, sz = getPlayerPosition(shooter_dyn)
    local tx, ty, tz = getPlayerPosition(target_dyn)

    local shooter_unit = read_dword(get_player(shooter_id) + 0x34)
    local hit, _, _, _, _ = intersect(sx, sy, sz, tx, ty, tz, shooter_unit)
    return not hit
end

-- Check if a player is currently camouflaged (active invisibility)
local function isPlayerCamouflaged(id)
    local player_obj = get_player(id)
    if player_obj == 0 then return false end
    return read_word(player_obj + 0x68) > 0
end

-- Returns horizontal speed of a player (m/s)
local function getHorizontalSpeed(dyn)
    local vx, vy, _ = getVelocity(dyn)
    return sqrt(vx * vx + vy * vy)
end

-- Check whether current aim vector is aligned with direction to target
local function checkAimAtTarget(shooter_dyn, shooter_id, target_id)
    if shooter_dyn == 0 then return nil end
    local target_dyn = get_dynamic_player(target_id)
    if target_dyn == 0 then return nil end

    -- Get shooter state for dynamic threshold
    local state = players[shooter_id]
    local threshold = state.dynamic_threshold or AUTO_AIM.ANGLE_THRESHOLD_DEGREES

    -- Apply velocity adjustment to threshold
    if VELOCITY_ADJUSTED.ENABLED then
        local speed = getHorizontalSpeed(shooter_dyn)
        if speed > VELOCITY_ADJUSTED.SPEED_THRESHOLD then
            threshold = threshold * VELOCITY_ADJUSTED.ANGLE_MODIFIER
        end
    end

    -- Shooter eye position
    local sx, sy, sz = getPlayerPosition(shooter_dyn)
    if not sx then return nil end

    -- Target position (center mass)
    local tx, ty, tz = getPlayerPosition(target_dyn)

    -- Get target velocity for prediction
    local vx, vy, vz = getVelocity(target_dyn)
    local dx, dy, dz = tx - sx, ty - sy, tz - sz
    local dist = vectorLength(dx, dy, dz)

    -- Predict future position
    local time_to_target = dist / PLAYER.PROJECTILE_SPEED
    local predicted_x = tx + vx * time_to_target
    local predicted_y = ty + vy * time_to_target
    local predicted_z = tz + vz * time_to_target

    -- Recalculate direction with prediction
    dx, dy, dz = predicted_x - sx, predicted_y - sy, predicted_z - sz
    dist = vectorLength(dx, dy, dz)
    if dist < 0.001 then return nil end

    local dir_x, dir_y, dir_z = normalize(dx, dy, dz)
    local aim_x, aim_y, aim_z = getCamera(shooter_dyn)
    aim_x, aim_y, aim_z = normalize(aim_x, aim_y, aim_z)

    -- Compute angle between vectors (degrees)
    local dp = dotProduct(aim_x, aim_y, aim_z, dir_x, dir_y, dir_z)
    dp = clamp(dp, -1, 1)
    local angle_deg = acos(dp) * 180 / pi

    -- Apply weapon-specific modifier
    local weapon = getWeaponName(shooter_id)
    local modifier = WEAPON_MODIFIERS[weapon] or WEAPON_MODIFIERS.DEFAULT
    threshold = threshold * modifier

    if angle_deg <= threshold then
        return {
            distance = dist,
            direction = { dir_x, dir_y, dir_z },
            angle = angle_deg
        }
    end

    return nil
end

-- Validate whether the aim ray would hit a player object
local function validateRaycastHit(shooter_dyn, shooter_id, direction)
    if shooter_dyn == 0 then return false end
    local sx, sy, sz = getPlayerPosition(shooter_dyn)
    if not sx then return false end

    local dir_x, dir_y, dir_z = unpack(direction)
    local ex = sx + dir_x * PLAYER.TRACE_DISTANCE
    local ey = sy + dir_y * PLAYER.TRACE_DISTANCE
    local ez = sz + dir_z * PLAYER.TRACE_DISTANCE

    local shooter_unit = read_dword(get_player(shooter_id) + 0x34)
    local hit, _, _, _, hit_object = intersect(sx, sy, sz, ex, ey, ez, shooter_unit)

    if not hit or hit_object == 0 then return false end

    -- Check if hit_object is another player
    for pid = 1, 16 do
        if pid ~= shooter_id and player_alive(pid) then
            local pdyn = get_dynamic_player(pid)
            if pdyn ~= 0 and get_object_memory(hit_object) == pdyn then return true end
        end
    end

    return false
end

-- Score evaluation for an aim event
local function evaluateAim(shooter_id, shooter_dyn, snap_angle_deg, distance, direction, target_id)
    local state = players[shooter_id]
    if not state then return false end

    -- Base score uses lock_count and distance
    local base_score = (state.lock_count * distance) * 0.0015
    local hit_detected = validateRaycastHit(shooter_dyn, shooter_id, direction)
    local final_score = base_score
    local is_moving = getHorizontalSpeed(shooter_dyn) > 0.1

    -- Environmental awareness check
    local obscured = false
    if ENVIRONMENTAL.ENABLED then
        obscured = not isVisible(shooter_id, target_id)
        if obscured then
            final_score = final_score * ENVIRONMENTAL.OBSCURED_MULTIPLIER
        end
    end

    -- Camouflage detection check
    if CAMO.ENABLED then
        local target_camo = isPlayerCamouflaged(target_id)
        if target_camo then
            final_score = final_score * CAMO.SCORE_MULTIPLIER
        end
    end

    -- Scoring logic
    if snap_angle_deg > SNAP_DETECTION.BASELINE_DEGREES then
        state.lock_count = state.lock_count + 1
        final_score = final_score + (hit_detected and snap_angle_deg * 5 or snap_angle_deg * 15)
    elseif is_moving and snap_angle_deg > 0 and snap_angle_deg < SNAP_DETECTION.MOVING_THRESHOLD_DEGREES then
        state.lock_count = state.lock_count + 1
        final_score = final_score + (hit_detected and 4 or 10)
    else
        return false
    end

    state.aim_score = state.aim_score + final_score

    -- Pattern recognition
    if PATTERN_DETECTION.ENABLED then
        insert(state.lock_pattern, time())
        if #state.lock_pattern > PATTERN_DETECTION.MAX_PATTERN_LENGTH then
            remove(state.lock_pattern, 1)
        end

        if #state.lock_pattern >= 3 then
            local intervals = {}
            for i = 2, #state.lock_pattern do
                insert(intervals, state.lock_pattern[i] - state.lock_pattern[i - 1])
            end

            local mean, std_dev = computeStats(intervals)
            if std_dev < PATTERN_DETECTION.MAX_STD_DEV then
                state.aim_score = state.aim_score + PATTERN_DETECTION.SCORE_BOOST
            end
        end
    end

    return true
end

-- Check if a shot (ammo decrement) would hit an enemy
local function checkShotHit(pid, dyn, team)
    for target = 1, 16 do
        if target ~= pid and player_present(target) and player_alive(target) and get_var(target, "$team") ~= team then
            local aim_data = checkAimAtTarget(dyn, pid, target)
            if aim_data and validateRaycastHit(dyn, pid, aim_data.direction) then
                return true
            end
        end
    end
    return false
end

-- Update accuracy tracking (ammo-based shots and hits), now supports energy weapons correctly
local function updateAccuracy(pid, dyn, team)
    local state = players[pid]
    if not state then return end

    -- Read current weapon and determine if it's an energy weapon
    local weapon_obj = read_dword(dyn + 0x118)
    if weapon_obj == 0xFFFFFFFF then
        state.last_weapon_obj = nil
        state.last_ammo_value = nil
        return
    end

    local weapon_mem = get_object_memory(weapon_obj)
    if weapon_mem == 0 then
        state.last_weapon_obj = nil
        state.last_ammo_value = nil
        return
    end

    local weapon_name = getWeaponName(pid)
    local is_energy = weapon_name and ENERGY_WEAPONS[weapon_name]

    -- Read the relevant ammo proxy
    local ammo_value
    if is_energy then
        local battery = read_float(weapon_mem + 0x240)
        if not battery then
            state.last_weapon_obj = nil
            state.last_ammo_value = nil
            return
        end
        -- Number of shots fired from a full charge (assuming 1% battery per shot)
        ammo_value = 100 - floor(battery * 100)
    else
        ammo_value = read_word(weapon_mem + 0x2B8) -- primary rounds left (magazine)
        if not ammo_value then
            state.last_weapon_obj = nil
            state.last_ammo_value = nil
            return
        end
    end

    -- Handle weapon switch: reset tracking
    if weapon_obj ~= state.last_weapon_obj then
        state.last_ammo_value = ammo_value
        state.last_weapon_obj = weapon_obj
        return
    end

    -- Initialise last ammo value on first read
    if state.last_ammo_value == nil then
        state.last_ammo_value = ammo_value
        return
    end

    -- Detect shots
    local shots_this_tick = 0
    if is_energy then
        -- For energy weapons: an increase in shots fired indicates ammo was consumed
        if ammo_value > state.last_ammo_value then
            shots_this_tick = ammo_value - state.last_ammo_value
        end
    else
        -- For ballistic weapons: a decrease in magazine count indicates shots were fired
        if ammo_value < state.last_ammo_value then
            shots_this_tick = state.last_ammo_value - ammo_value
        end
    end

    if shots_this_tick > 0 then
        state.shots_fired = state.shots_fired + shots_this_tick
        for _ = 1, shots_this_tick do
            if checkShotHit(pid, dyn, team) then
                state.shots_hit = state.shots_hit + 1
            end
        end
    end

    -- Remember the new ammo proxy value (reloads/pickups/overheat recovery are ignored)
    state.last_ammo_value = ammo_value
end

-- Update dynamic threshold based on accuracy
local function updateDynamicThreshold(pid)
    if not AUTO_AIM.DYNAMIC_THRESHOLD.ENABLED then return end

    local state = players[pid]
    if not state then return end

    -- Calculate actual accuracy (hits / shots) if shots have been fired; fallback 0.5 (50%)
    local accuracy = 0.5
    if state.shots_fired > 0 then
        accuracy = state.shots_hit / state.shots_fired
        accuracy = clamp(accuracy, 0, 1)
    end

    -- Update accuracy history
    insert(state.accuracy_history, accuracy)
    if #state.accuracy_history > 10 then
        remove(state.accuracy_history, 1)
    end

    -- Calculate weighted average accuracy
    local avg_accuracy = 0
    for _, acc in ipairs(state.accuracy_history) do
        avg_accuracy = avg_accuracy + acc
    end
    avg_accuracy = avg_accuracy / #state.accuracy_history

    -- Adjust threshold based on accuracy
    local multiplier = AUTO_AIM.DYNAMIC_THRESHOLD.BASE_MULTIPLIER +
        AUTO_AIM.DYNAMIC_THRESHOLD.ACCURACY_WEIGHT * (avg_accuracy - 0.5) * 2
    multiplier = clamp(multiplier,
        AUTO_AIM.DYNAMIC_THRESHOLD.MIN_MULTIPLIER,
        AUTO_AIM.DYNAMIC_THRESHOLD.MAX_MULTIPLIER)

    state.dynamic_threshold = AUTO_AIM.ANGLE_THRESHOLD_DEGREES * multiplier
end

local function validatePlayers(target, pid, team)
    return target ~= pid and player_present(target) and player_alive(target) and get_var(target, "$team") ~= team
end

-- Process a single player's aim checks / decay / enforcement
local function processPlayerAim(pid)
    local state = players[pid]

    -- Update dynamic threshold
    updateDynamicThreshold(pid)

    -- Time-based decay
    local now = time()
    local elapsed = now - (state.last_decay_time or now)
    if elapsed >= DECAY.INTERVAL_SECONDS and state.aim_score > 0 then
        local decay_amount = elapsed * DECAY.POINTS_PER_SECOND
        state.aim_score = max(0, state.aim_score - decay_amount)
        state.last_decay_time = now
    end

    local dyn = get_dynamic_player(pid)
    if dyn == 0 then
        camera_vectors[pid] = nil
        return
    end

    local team = get_var(pid, "$team")

    -- Update accuracy tracking (shots fired & hits)
    updateAccuracy(pid, dyn, team)

    local orientation_change = calculateOrientationChange(pid, dyn)
    local scoring_occurred = false

    -- Iterate targets and evaluate
    for target = 1, 16 do
        if validatePlayers(target, pid, team) then
            local aim_data = checkAimAtTarget(dyn, pid, target)
            if aim_data then
                scoring_occurred = evaluateAim(
                    pid,
                    dyn,
                    orientation_change,
                    aim_data.distance,
                    aim_data.direction,
                    target)
                break -- One primary evaluation per tick
            end
        end
    end

    if not scoring_occurred then
        state.lock_count = max(0, state.lock_count - 0.5)
    end

    -- Enforcement
    if state.aim_score > AUTO_AIM.MAX_SCORE then
        execute_command(fmt("%s %d \"%s\"", ENFORCEMENT.COMMAND, pid, ENFORCEMENT.REASON))
        state.aim_score = 0
        state.lock_count = 0
        state.lock_pattern = {}
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], "OnTick")
    register_callback(cb['EVENT_JOIN'], "OnJoin")
    register_callback(cb['EVENT_DIE'], "OnDeath")
    register_callback(cb['EVENT_LEAVE'], "OnQuit")
    register_callback(cb['EVENT_GAME_END'], "OnEnd")
    register_callback(cb['EVENT_GAME_START'], "OnStart")
    OnStart() -- in case the script is loaded mid-game
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    for i = 1, 16 do
        OnJoin(i)
        camera_vectors[i] = nil
    end
    weapon_cache = {}
end

function OnEnd()
    for i = 1, 16 do
        players[i] = nil
        camera_vectors[i] = nil
    end
    weapon_cache = {}
end

function OnJoin(id)
    players[id] = {
        aim_score = 0,
        lock_count = 0,
        last_decay_time = time(),
        lock_pattern = {},
        dynamic_threshold = AUTO_AIM.ANGLE_THRESHOLD_DEGREES,
        accuracy_history = { 0.5 }, -- Start with 50% accuracy
        shots_fired = 0,            -- total shots fired this life
        shots_hit = 0,              -- total hits landed this life
        last_ammo_value = nil,      -- last read ammo proxy (word or shots from battery)
        last_weapon_obj = nil       -- last weapon object to detect switches
    }
    camera_vectors[id] = nil
    weapon_cache[id] = nil
end

function OnDeath(id)
    if players[id] then
        players[id].lock_count = 0
        players[id].aim_score = 0
        players[id].last_decay_time = time()
        players[id].shots_fired = 0
        players[id].shots_hit = 0
        players[id].last_ammo_value = nil
        players[id].last_weapon_obj = nil
    end
    camera_vectors[id] = nil
end

function OnQuit(id)
    players[id] = nil
    camera_vectors[id] = nil
    weapon_cache[id] = nil
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            processPlayerAim(i)
        end
    end
end

function OnScriptUnload() end
