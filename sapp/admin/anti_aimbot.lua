--[[
=============================================================================================================
SCRIPT NAME:    anti_aimbot.lua
DESCRIPTION:    Anti-aimbot detection. Every tick it checks whether each living player's camera is lined up
                with an enemy and scores the suspicious cases. When a player's score passes CFG.AUTO_AIM.MAX_SCORE,
                the configured command runs (kick by default).

                WHAT GETS SCORED:
                - Snaps: a big camera jump in a single tick that ends on an enemy.
                - Tracking: tiny camera movement while the player is moving and the crosshair sits on an enemy.
                - Pattern: new locks that arrive at suspiciously even intervals.
                - Visibility: points are scaled down when there is a wall between shooter and target.
                - Camo: points are scaled up when the target is camouflaged, since landing hits on an invisible
                  player is a strong sign.

                WHAT SHAPES THE AIM CONE:
                - Weapon: each weapon has its own modifier (see CFG.WEAPON_MODIFIERS).
                - Speed: the cone shrinks while the shooter is moving.
                - Accuracy: the cone grows or shrinks with the shooter's hit rate this life.

                COMPATIBILITY:
                - This script currently only supports stock weapons and will not work on custom maps with
                  custom weapon tags unless you add those custom weapon tags to CFG.WEAPON_MODIFIERS and
                  CFG.ENERGY_WEAPONS.

                USAGE:
                1. Tune the CFG table below for your server.
                2. Set CFG.ENFORCEMENT.COMMAND, CFG.ENFORCEMENT.IPBAN_TIME_MINUTES, and
                   CFG.MESSAGES.PLAYER_KICK_REASON.
                3. Load it. A line is printed to the server console every time it enforces.

                TUNING NOTES:
                - This is a heuristic, so start with a high CFG.AUTO_AIM.MAX_SCORE and watch the console before
                  trusting it with bans.
                - Raise CFG.AUTO_AIM.MAX_SCORE to be more lenient. Lower CFG.AUTO_AIM.ANGLE_THRESHOLD_DEGREES
                  to narrow the cone.
                - The CFG.SCORING table controls how fast each kind of event adds up.
                - The tracking branch is off by default (CFG.SNAP_DETECTION.TRACKING_ENABLED). Steady aim
                  during a strafing duel looks a lot like tracking, so only turn it on after testing.

LAST UPDATED:   14 Nov 2026

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=============================================================================================================
]]

api_version = "1.12.0.0"

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- Every tunable lives inside CFG. The ---@class block immediately below is the
-- single source of truth for CFG's shape; editing values never requires
-- touching the annotations. Adding a new field means adding exactly one
-- ---@field line here, then one key/value pair in the CFG literal.

---@class DynamicThresholdConfig
---@field ENABLED         boolean Enable accuracy-based cone adjustment.
---@field BASE_MULTIPLIER number  Cone multiplier at 50% accuracy.
---@field ACCURACY_WEIGHT number  How strongly accuracy moves the multiplier (0-1).
---@field MIN_MULTIPLIER  number  Lowest cone multiplier.
---@field MAX_MULTIPLIER  number  Highest cone multiplier.

---@class AutoAimConfig
---@field ANGLE_THRESHOLD_DEGREES     number                 Base aim cone around an enemy (degrees).
---@field MIN_ANGLE_THRESHOLD_DEGREES number                 Floor for the cone after all modifiers (degrees).
---@field MAX_SCORE                   number                 Score that triggers enforcement.
---@field DYNAMIC_THRESHOLD           DynamicThresholdConfig

---@class SnapDetectionConfig
---@field BASELINE_DEGREES         number  Camera change in one tick that counts as a snap (degrees).
---@field TRACKING_ENABLED         boolean Also score subtle camera movement while moving.
---@field MOVING_THRESHOLD_DEGREES number  Upper limit for a subtle camera change while moving (degrees).
---@field MOVING_SPEED             number  Minimum speed that counts as moving (m/s).

---@class ScoringConfig
---@field SNAP_ON_TARGET       number Points per degree of snap when the aim ray hits the target.
---@field SNAP_OFF_TARGET      number Points per degree of snap when the aim ray misses the target.
---@field TRACK_ON_TARGET      number Flat points for subtle tracking when the aim ray hits the target.
---@field TRACK_OFF_TARGET     number Flat points for subtle tracking when the aim ray misses the target.
---@field LOCK_DISTANCE_WEIGHT number Extra points per (lock count * distance in world units).

---@class PlayerConfig
---@field TRACE_DISTANCE   number Aim ray length (world units).
---@field PROJECTILE_SPEED number Assumed projectile speed when leading a moving target (m/s).
---@field MAX_LEAD_SECONDS number Cap on how far ahead of a moving target we aim (seconds).

---@class EnforcementConfig
---@field COMMAND            string Command run on enforcement ("k" or "ipban").
---@field IPBAN_TIME_MINUTES number Ban duration for ipban (minutes); 0 = indefinite.

---@class MessagesConfig
---@field ADMIN_ALERT        string Server-console format string for the enforcement alert.
---@field PLAYER_KICK_REASON string Reason shown to the kicked/banned player.

---@class DecayConfig
---@field POINTS_PER_SECOND number Aim score removed per second.
---@field INTERVAL_SECONDS  number How often decay is applied (seconds).

---@class VelocityAdjustedConfig
---@field ENABLED         boolean Shrink the cone while the shooter is moving.
---@field SPEED_THRESHOLD number  Minimum shooter speed to apply it (m/s).
---@field ANGLE_MODIFIER  number  Cone multiplier while moving.

---@class AccuracyConfig
---@field DEFAULT      number Accuracy assumed before any shots are fired.
---@field HISTORY_SIZE number Number of recent accuracy samples to average.
---@field HEAT_EPSILON number Minimum heat rise that counts as an energy weapon shot.

---@class PatternDetectionConfig
---@field ENABLED            boolean Look for evenly spaced new locks.
---@field MAX_STD_DEV        number  Max spread of the intervals to count as a pattern (seconds).
---@field SCORE_BOOST        number  Points added when a pattern is found.
---@field MAX_PATTERN_LENGTH number  Number of recent new locks to keep.
---@field MIN_LOCKS          number  New locks needed before checking for a pattern.

---@class EnvironmentalConfig
---@field ENABLED             boolean Scale the score when a wall is between shooter and target.
---@field OBSCURED_MULTIPLIER number  Score multiplier when the target is behind geometry.

---@class CamoConfig
---@field ENABLED          boolean Scale the score when the target is camouflaged.
---@field SCORE_MULTIPLIER number  Score multiplier when the target is camouflaged.

---@class AntiAimbotConfig
---@field AUTO_AIM          AutoAimConfig
---@field SNAP_DETECTION    SnapDetectionConfig
---@field SCORING           ScoringConfig
---@field PLAYER            PlayerConfig
---@field ENFORCEMENT       EnforcementConfig
---@field MESSAGES          MessagesConfig
---@field DECAY             DecayConfig
---@field VELOCITY_ADJUSTED VelocityAdjustedConfig
---@field ACCURACY          AccuracyConfig
---@field WEAPON_MODIFIERS  table<string, number>  Weapon tag path -> cone multiplier. "DEFAULT" is the fallback.
---@field ENERGY_WEAPONS    table<string, boolean> Weapon tag path -> true if the weapon runs on heat instead of a magazine.
---@field PATTERN_DETECTION PatternDetectionConfig
---@field ENVIRONMENTAL     EnvironmentalConfig
---@field CAMO              CamoConfig

---@type AntiAimbotConfig
local CFG = {
    AUTO_AIM = {
        ANGLE_THRESHOLD_DEGREES = 2.5,     -- Base aim cone around an enemy (degrees)
        MIN_ANGLE_THRESHOLD_DEGREES = 0.2, -- Floor for the cone after all modifiers (degrees)
        MAX_SCORE = 3000,                  -- Score that triggers enforcement
        DYNAMIC_THRESHOLD = {
            ENABLED = true,
            BASE_MULTIPLIER = 1.0, -- Cone multiplier at 50% accuracy
            ACCURACY_WEIGHT = 0.5, -- How strongly accuracy moves the multiplier (0-1)
            MIN_MULTIPLIER = 0.8,  -- Lowest cone multiplier
            MAX_MULTIPLIER = 1.2   -- Highest cone multiplier
        }
    },

    SNAP_DETECTION = {
        BASELINE_DEGREES = 6.0,         -- Camera change in one tick that counts as a snap (degrees)
        TRACKING_ENABLED = false,       -- Also score subtle camera movement while moving (see tuning notes)
        MOVING_THRESHOLD_DEGREES = 0.4, -- Upper limit for a subtle camera change while moving (degrees)
        MOVING_SPEED = 0.1              -- Minimum speed that counts as moving (m/s)
    },

    SCORING = {
        SNAP_ON_TARGET = 15,          -- Points per degree of snap when the aim ray hits the target
        SNAP_OFF_TARGET = 5,          -- Points per degree of snap when the aim ray misses the target
        TRACK_ON_TARGET = 4,          -- Flat points for subtle tracking when the aim ray hits the target
        TRACK_OFF_TARGET = 10,        -- Flat points for subtle tracking when the aim ray misses the target
        LOCK_DISTANCE_WEIGHT = 0.0015 -- Extra points per (lock count * distance in world units)
    },

    PLAYER = {
        TRACE_DISTANCE = 250,    -- Aim ray length (world units)
        PROJECTILE_SPEED = 30.0, -- Assumed projectile speed when leading a moving target (m/s)
        MAX_LEAD_SECONDS = 0.3   -- Cap on how far ahead of a moving target we aim (seconds)
    },

    ENFORCEMENT = {
        COMMAND = "k",          -- "k" or "ipban"
        IPBAN_TIME_MINUTES = 60 -- 0 means an indefinite IP ban
    },

    MESSAGES = {
        ADMIN_ALERT = "[anti_aimbot] %s (id %d) reached score %.0f, running '%s'",
        PLAYER_KICK_REASON = "Aimbot detection"
    },

    DECAY = {
        POINTS_PER_SECOND = 0.25, -- Aim score removed per second
        INTERVAL_SECONDS = 0.25   -- How often decay is applied (seconds)
    },

    VELOCITY_ADJUSTED = {
        ENABLED = true,        -- Shrink the cone while the shooter is moving
        SPEED_THRESHOLD = 1.5, -- Minimum shooter speed to apply it (m/s)
        ANGLE_MODIFIER = 0.8   -- Cone multiplier while moving
    },

    ACCURACY = {
        DEFAULT = 0.5,        -- Accuracy assumed before any shots are fired
        HISTORY_SIZE = 10,    -- Number of recent accuracy samples to average
        HEAT_EPSILON = 0.0001 -- Minimum heat rise that counts as an energy weapon shot (TODO: vary per weapon)
    },

    WEAPON_MODIFIERS = {
        ["weapons\\pistol\\pistol"] = 1.15,                   -- Accurate and kills fast
        ["weapons\\sniper rifle\\sniper rifle"] = 0.65,       -- Needs precision, slow fire rate
        ["weapons\\rocket launcher\\rocket launcher"] = 0.75, -- Splash damage, slow projectile
        ["weapons\\flamethrower\\flamethrower"] = 0.50,       -- Short range, easy to stay on target
        ["weapons\\needler\\mp_needler"] = 0.90,              -- Homing needles, kills are delayed
        ["weapons\\shotgun\\shotgun"] = 1.40,                 -- Wide spread, deadly up close
        ["weapons\\plasma pistol\\plasma pistol"] = 1.10,     -- Charged shot plus normal fire
        ["weapons\\plasma rifle\\plasma rifle"] = 1.00,       -- Sustained fire, moderate tracking
        ["weapons\\assault rifle\\assault rifle"] = 1.20,     -- Spray, but easy to track with
        ["weapons\\plasma_cannon\\plasma_cannon"] = 0.85,     -- Slow projectile, splash
        DEFAULT = 1.0                                         -- Any weapon not listed above
    },

    -- Weapons that run on heat instead of a magazine
    ENERGY_WEAPONS = {
        ["weapons\\plasma pistol\\plasma pistol"] = true,
        ["weapons\\plasma rifle\\plasma rifle"] = true,
        ["weapons\\plasma_cannon\\plasma_cannon"] = true
    },

    PATTERN_DETECTION = {
        ENABLED = true,         -- Look for evenly spaced new locks
        MAX_STD_DEV = 0.05,     -- Max spread of the intervals to count as a pattern (seconds)
        SCORE_BOOST = 150,      -- Points added when a pattern is found
        MAX_PATTERN_LENGTH = 5, -- Number of recent new locks to keep
        MIN_LOCKS = 3           -- New locks needed before checking for a pattern
    },

    ENVIRONMENTAL = {
        ENABLED = true,           -- Scale the score when a wall is between shooter and target
        OBSCURED_MULTIPLIER = 0.3 -- Score multiplier when the target is behind geometry
    },

    CAMO = {
        ENABLED = true,        -- Scale the score when the target is camouflaged
        SCORE_MULTIPLIER = 2.0 -- Score multiplier when the target is camouflaged
    }
}

-- END CONFIG ---------------------------------------------------------------

---@class PlayerAimState
---@field aim_score         number       Aim score for the current life.
---@field lock_count        number       Running lock count (decays when no scoring).
---@field last_decay_time   number       Timestamp (seconds) when decay was last applied.
---@field lock_pattern      number[]     Timestamps (seconds) of recent new locks.
---@field was_scoring       boolean      True if the previous tick scored (for new-lock detection).
---@field dynamic_threshold number       Current aim cone half angle (degrees).
---@field accuracy_history  number[]     Recent per-volley accuracy samples.
---@field shots_fired       number       Shots fired this life.
---@field shots_hit         number       Shots that landed on an enemy this life.
---@field last_fire_value   number | nil Last magazine count, or heat for energy weapons.
---@field last_weapon_id    number | nil Last held weapon object ID (for switch detection).

local BASE_TAG_TABLE = 0x40440000 -- Same on PC and CE
local TICKS_PER_SECOND = 30
local METERS_PER_WU = 3.048
local NO_OBJECT = 0xFFFFFFFF

---@type table<number, PlayerAimState | nil>
local players = {}

---@type table<number, number[] | nil> Last camera vector per player {cx, cy, cz}.
local camera_vectors = {}

---@type table<number, string | nil> Weapon tag names, keyed by tag index.
local weapon_cache = {}

---@type table<number, string | false | nil> Team of each living player this tick, false if absent or dead.
local tick_teams = {}

local tick_count = 0 -- Ticks since the script loaded
local is_ffa = false -- True when the running game has no teams

local fmt = string.format

local sqrt = math.sqrt
local acos = math.acos
local deg = math.deg
local max = math.max
local min = math.min
local abs = math.abs

local insert = table.insert
local remove = table.remove

local read_vector3d = read_vector3d
local get_object_memory = get_object_memory

---@type fun(player_id: number): number
local get_dynamic_player = get_dynamic_player

---@type fun(player_id: number): number
local get_player = get_player

local get_var = get_var
local player_present, player_alive = player_present, player_alive
local read_float, read_string, read_dword, read_word = read_float, read_string, read_dword, read_word
local intersect, execute_command, cprint = intersect, execute_command, cprint

---@param value number Value to clamp.
---@param low   number Lower bound.
---@param high  number Upper bound.
---@return number clamped Value limited to the range low-high.
local function clamp(value, low, high)
    return (value < low) and low or ((value > high) and high or value)
end

---@param x number Vector X component.
---@param y number Vector Y component.
---@param z number Vector Z component.
---@return number length Vector length.
local function vectorLength(x, y, z)
    return sqrt(x * x + y * y + z * z)
end

---@param x number Vector X component.
---@param y number Vector Y component.
---@param z number Vector Z component.
---@return boolean is_zero True if every component is zero.
local function isZeroVector(x, y, z)
    return x == 0 and y == 0 and z == 0
end

-- Returns 0, 0, 0 for a zero-length vector.
---@param x number Vector X component.
---@param y number Vector Y component.
---@param z number Vector Z component.
---@return number x, number y, number z Normalized X, Y, and Z components.
local function normalize(x, y, z)
    local length = vectorLength(x, y, z)
    if length <= 0 then return 0, 0, 0 end
    return x / length, y / length, z / length
end

---@param ax number First vector X component.
---@param ay number First vector Y component.
---@param az number First vector Z component.
---@param bx number Second vector X component.
---@param by number Second vector Y component.
---@param bz number Second vector Z component.
---@return number dot Dot product of the two vectors.
local function dotProduct(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end

-- Game time in seconds. Counting ticks keeps decay and timing tied to the server tick rate.
---@return number seconds Seconds since the script loaded.
local function now()
    return tick_count / TICKS_PER_SECOND
end

---@param dyn_player number Dynamic player address.
---@return number | nil object Vehicle address if seated, biped address if on foot, nil if vehicle invalid.
local function getBaseObject(dyn_player)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id == NO_OBJECT then return dyn_player end

    local vehicle_object = get_object_memory(vehicle_id)
    return vehicle_object ~= 0 and vehicle_object or nil
end

---@param dyn_player number Dynamic player address.
---@return number cx, number cy, number cz Aim vector X, Y, Z. 0 if invalid.
local function getCamera(dyn_player)
    if dyn_player == 0 then return 0, 0, 0 end

    local cx = read_float(dyn_player + 0x230)
    local cy = read_float(dyn_player + 0x234)
    local cz = read_float(dyn_player + 0x238)
    if cx ~= cx or cy ~= cy or cz ~= cz then return 0, 0, 0 end

    return cx, cy, cz
end

-- Velocity is in world units per tick.
---@param dyn_player number Dynamic player address.
---@return number vx, number vy, number vz Velocity X, Y, and Z.
local function getVelocity(dyn_player)
    local object = getBaseObject(dyn_player)
    if not object then return 0, 0, 0 end
    local vx, vy, vz = read_vector3d(object + 0x68)

    return vx, vy, vz
end

-- Eye level position, using the vehicle position when seated.
---@param dyn_player number Dynamic player address.
---@return number | nil x, number | nil y, number | nil z Player X, Y, and eye-level Z coordinates, or nil if the vehicle is invalid.
local function getPlayerPosition(dyn_player)
    local object = getBaseObject(dyn_player)
    if not object then return nil, nil, nil end

    local crouch = read_float(dyn_player + 0x50C) -- 0 = standing, 1 = fully crouched
    local x, y, z = read_vector3d(object + 0x5C)
    return x, y, z + 0.65 - (0.3 * crouch)
end

-- Velocity is stored per tick, so scale it up to meters per second.
---@param dyn_player number Dynamic player address.
---@return number speed Horizontal speed in m/s.
local function getHorizontalSpeed(dyn_player)
    local vx, vy = getVelocity(dyn_player)
    return sqrt(vx * vx + vy * vy) * TICKS_PER_SECOND * METERS_PER_WU
end

---@param dyn_player number Dynamic player address.
---@return number | nil weapon_object, number | nil weapon_id Held weapon address and object ID, or nil if unarmed.
local function getWeaponObject(dyn_player)
    local weapon_id = read_dword(dyn_player + 0x118)
    if weapon_id == NO_OBJECT then return nil end

    local weapon_object = get_object_memory(weapon_id)
    if weapon_object == 0 then return nil end

    return weapon_object, weapon_id
end

-- Tag names are cached by tag index, so a weapon swap never leaves a stale name behind.
---@param weapon_object number Weapon object address.
---@return string name Weapon tag path, or "" if the tag has no name pointer.
local function getWeaponName(weapon_object)
    local tag_index = read_word(weapon_object)

    local name = weapon_cache[tag_index]
    if name then return name end

    local tag_address = read_dword(BASE_TAG_TABLE) + tag_index * 0x20
    local name_pointer = read_dword(tag_address + 0x10)

    name = name_pointer ~= 0 and read_string(name_pointer) or ""
    weapon_cache[tag_index] = name
    return name
end

-- This is the object a ray hits for this player: the vehicle when seated, the biped otherwise.
---@param player_id number Player index.
---@return number | nil object_id Object ID a ray would hit, or nil if the player is dead.
local function getCollisionObjectId(player_id)
    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return nil end

    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id ~= NO_OBJECT then return vehicle_id end

    local static_player = get_player(player_id)
    if static_player == 0 then return nil end

    return read_dword(static_player + 0x34)
end

---@param player_id number Player index.
---@return boolean camouflaged True if the player has active camo.
local function isPlayerCamouflaged(player_id)
    local static_player = get_player(player_id)
    if static_player == 0 then return false end

    return read_word(static_player + 0x68) > 0
end

---@param shooter_id number Shooter player index.
---@param target_id  number Target player index.
---@return boolean enemy True if the target is alive and counts as an enemy of the shooter.
local function isEnemy(shooter_id, target_id)
    local target_team = tick_teams[target_id]
    if not target_team or target_id == shooter_id then return false end

    return is_ffa or target_team ~= tick_teams[shooter_id]
end

---@param values number[] Samples to measure.
---@return number mean, number std_dev Average and population standard deviation of the samples.
local function computeStats(values)
    local sum = 0
    for i = 1, #values do
        ---@diagnostic disable-next-line: assign-type-mismatch
        sum = sum + values[i]
    end
    local mean = sum / #values

    local variance = 0
    for i = 1, #values do
        ---@diagnostic disable-next-line: assign-type-mismatch
        variance = variance + (values[i] - mean) ^ 2
    end
    return mean, sqrt(variance / #values)
end

---@return PlayerAimState state Fresh per-player state.
local function newState()
    return {
        aim_score = 0,
        lock_count = 0,
        last_decay_time = now(),
        lock_pattern = {},     -- Times of recent new locks
        was_scoring = false,   -- True if the previous tick scored, used to spot new locks
        dynamic_threshold = CFG.AUTO_AIM.ANGLE_THRESHOLD_DEGREES,
        accuracy_history = { CFG.ACCURACY.DEFAULT },
        shots_fired = 0,       -- Shots fired this life
        shots_hit = 0,         -- Shots that landed on an enemy this life
        last_fire_value = nil, -- Last magazine count, or heat for energy weapons
        last_weapon_id = nil   -- Last held weapon, used to spot weapon switches
    }
end

-- Accuracy history and the dynamic threshold carry over between lives.
---@param state PlayerAimState Per-player state to reset.
local function resetLife(state)
    state.aim_score = 0
    state.lock_count = 0
    state.last_decay_time = now()
    state.lock_pattern = {}
    state.was_scoring = false
    state.shots_fired = 0
    state.shots_hit = 0
    state.last_fire_value = nil
    state.last_weapon_id = nil
end

---@param state PlayerAimState Per-player state.
local function clearFireTracking(state)
    state.last_fire_value = nil
    state.last_weapon_id = nil
end

-- Angle between this tick's camera vector and last tick's (degrees).
---@param shooter_id  number Shooter player index.
---@param shooter_dyn number Shooter dynamic player address.
---@return number angle Camera change in degrees, 0 on the first tick or if the camera is invalid.
local function calculateOrientationChange(shooter_id, shooter_dyn)
    local cx, cy, cz = normalize(getCamera(shooter_dyn))

    -- A bad read would look like a 90 degree snap next tick, so drop the baseline.
    if isZeroVector(cx, cy, cz) then
        camera_vectors[shooter_id] = nil
        return 0
    end

    local previous = camera_vectors[shooter_id]
    if not previous then
        camera_vectors[shooter_id] = { cx, cy, cz }
        return 0
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local dot = clamp(dotProduct(previous[1], previous[2], previous[3], cx, cy, cz), -1, 1)
    previous[1], previous[2], previous[3] = cx, cy, cz

    -- Identical vectors can land a hair under 1 from rounding, treat that as no movement.
    if abs(dot - 1) < 1e-10 then return 0 end

    return deg(acos(dot))
end

-- Checks the line from the shooter's eye to the target's eye for geometry in the way.
---@param shooter_id number Shooter player index.
---@param target_id  number Target player index.
---@return boolean visible True if nothing but the target is on that line.
local function isVisible(shooter_id, target_id)
    local shooter_dyn = get_dynamic_player(shooter_id)
    local target_dyn = get_dynamic_player(target_id)
    if shooter_dyn == 0 or target_dyn == 0 then return false end

    local sx, sy, sz = getPlayerPosition(shooter_dyn)
    local tx, ty, tz = getPlayerPosition(target_dyn)
    if not sx or not sy or not sz or not tx or not ty or not tz then return false end

    local hit, _, _, _, hit_object_id = intersect(
        sx, sy, sz, tx - sx, ty - sy, tz - sz, getCollisionObjectId(shooter_id)
    )
    return not hit or hit_object_id == getCollisionObjectId(target_id)
end

-- Fires a ray along the shooter's actual camera vector.
---@param shooter_id  number Shooter player index.
---@param shooter_dyn number Shooter dynamic player address.
---@return number | nil object_id Object ID the ray hit, or nil if it hit nothing or only map geometry.
local function castAimRay(shooter_id, shooter_dyn)
    local sx, sy, sz = getPlayerPosition(shooter_dyn)
    if not sx or not sy or not sz then return nil end

    local aim_x, aim_y, aim_z = normalize(getCamera(shooter_dyn))
    if isZeroVector(aim_x, aim_y, aim_z) then return nil end

    local trace = CFG.PLAYER.TRACE_DISTANCE
    local hit, _, _, _, hit_object_id = intersect(
        sx, sy, sz, aim_x * trace, aim_y * trace, aim_z * trace, getCollisionObjectId(shooter_id)
    )

    if not hit or hit_object_id == NO_OBJECT then return nil end
    return hit_object_id
end

---@param shooter_id  number Shooter player index.
---@param shooter_dyn number Shooter dynamic player address.
---@param target_id   number Target player index.
---@return boolean hit True if the shooter's aim ray lands on the target.
local function validateRaycastHit(shooter_id, shooter_dyn, target_id)
    local hit_object_id = castAimRay(shooter_id, shooter_dyn)
    return hit_object_id ~= nil and hit_object_id == getCollisionObjectId(target_id)
end

-- One ray covers every enemy, so the shot count does not add raycasts.
---@param shooter_id  number Shooter player index.
---@param shooter_dyn number Shooter dynamic player address.
---@return boolean hit True if the aim ray lands on any enemy.
local function checkShotHit(shooter_id, shooter_dyn)
    local hit_object_id = castAimRay(shooter_id, shooter_dyn)
    if not hit_object_id then return false end

    for target_id = 1, 16 do
        if isEnemy(shooter_id, target_id) and getCollisionObjectId(target_id) == hit_object_id then
            return true
        end
    end
    return false
end

-- Only runs when a shot was fired, so the history tracks shots and not ticks.
---@param shooter_id number Shooter player index.
local function updateDynamicThreshold(shooter_id)
    local config = CFG.AUTO_AIM.DYNAMIC_THRESHOLD
    if not config.ENABLED then return end

    local state = players[shooter_id]
    ---@cast state PlayerAimState

    local accuracy = CFG.ACCURACY.DEFAULT
    if state.shots_fired > 0 then
        accuracy = clamp(state.shots_hit / state.shots_fired, 0, 1)
    end
    insert(state.accuracy_history, accuracy)
    if #state.accuracy_history > CFG.ACCURACY.HISTORY_SIZE then
        remove(state.accuracy_history, 1)
    end

    local sum = 0
    for i = 1, #state.accuracy_history do
        ---@diagnostic disable-next-line: assign-type-mismatch
        sum = sum + state.accuracy_history[i]
    end
    local average_accuracy = sum / #state.accuracy_history

    -- Better accuracy widens the cone, so accurate players get scored more easily.
    local multiplier = config.BASE_MULTIPLIER + config.ACCURACY_WEIGHT * (average_accuracy - 0.5) * 2
    multiplier = clamp(multiplier, config.MIN_MULTIPLIER, config.MAX_MULTIPLIER)

    state.dynamic_threshold = CFG.AUTO_AIM.ANGLE_THRESHOLD_DEGREES * multiplier
end

-- Counts shots from the magazine, or from heat for energy weapons, and checks each volley for a hit.
---@param shooter_id  number Shooter player index.
---@param shooter_dyn number Shooter dynamic player address.
local function updateAccuracy(shooter_id, shooter_dyn)
    local state = players[shooter_id]
    ---@cast state PlayerAimState

    local weapon_object, weapon_id = getWeaponObject(shooter_dyn)
    if not weapon_object then
        clearFireTracking(state)
        return
    end

    local is_energy = CFG.ENERGY_WEAPONS[getWeaponName(weapon_object)]
    local fire_value = is_energy and read_float(weapon_object + 0x240) or read_word(weapon_object + 0x2B8)

    -- First read, or the weapon changed: just remember where we are.
    if weapon_id ~= state.last_weapon_id or state.last_fire_value == nil then
        state.last_weapon_id = weapon_id
        state.last_fire_value = fire_value
        return
    end

    local shots = 0
    if is_energy then
        -- Heat goes up when the weapon fires and drifts down when idle.
        shots = fire_value > state.last_fire_value + CFG.ACCURACY.HEAT_EPSILON and 1 or 0
    else
        ---@diagnostic disable-next-line: assign-type-mismatch
        -- Reloads and pickups raise the magazine count, so only drops count as shots.
        shots = max(0, state.last_fire_value - fire_value)
    end

    if shots > 0 then
        state.shots_fired = state.shots_fired + shots
        if checkShotHit(shooter_id, shooter_dyn) then
            state.shots_hit = state.shots_hit + shots
        end
        updateDynamicThreshold(shooter_id)
    end

    state.last_fire_value = fire_value
end

-- Cone size for this tick: dynamic threshold, then speed, then weapon, then the floor.
---@param shooter_id  number Shooter player index.
---@param shooter_dyn number Shooter dynamic player address.
---@return number threshold Aim cone half angle in degrees.
local function getAimThreshold(shooter_id, shooter_dyn)
    local state = players[shooter_id]
    ---@cast state PlayerAimState
    local threshold = state.dynamic_threshold

    if CFG.VELOCITY_ADJUSTED.ENABLED and getHorizontalSpeed(shooter_dyn) > CFG.VELOCITY_ADJUSTED.SPEED_THRESHOLD then
        threshold = threshold * CFG.VELOCITY_ADJUSTED.ANGLE_MODIFIER
    end

    local weapon_object = getWeaponObject(shooter_dyn)
    local weapon_name = weapon_object and getWeaponName(weapon_object)
    threshold = threshold * (weapon_name and CFG.WEAPON_MODIFIERS[weapon_name] or CFG.WEAPON_MODIFIERS.DEFAULT)

    return max(threshold, CFG.AUTO_AIM.MIN_ANGLE_THRESHOLD_DEGREES)
end

-- Checks whether the camera is inside the aim cone around where the target will be.
---@param shooter_dyn number Shooter dynamic player address.
---@param target_id   number Target player index.
---@param threshold   number Aim cone half angle in degrees.
---@return number | nil distance Distance to the predicted target (world units), nil if outside the cone.
local function checkAimAtTarget(shooter_dyn, target_id, threshold)
    local target_dyn = get_dynamic_player(target_id)
    if target_dyn == 0 then return nil end

    local sx, sy, sz = getPlayerPosition(shooter_dyn)
    local tx, ty, tz = getPlayerPosition(target_dyn)
    if not sx or not sy or not sz or not tx or not ty or not tz then return nil end

    -- Lead the target. Distance is in world units and the projectile speed is in m/s.
    local vx, vy, vz = getVelocity(target_dyn)
    local distance = vectorLength(tx - sx, ty - sy, tz - sz)
    local lead_seconds = min(distance * METERS_PER_WU / CFG.PLAYER.PROJECTILE_SPEED, CFG.PLAYER.MAX_LEAD_SECONDS)
    local lead_ticks = lead_seconds * TICKS_PER_SECOND

    local dx = tx + vx * lead_ticks - sx
    local dy = ty + vy * lead_ticks - sy
    local dz = tz + vz * lead_ticks - sz
    local predicted_distance = vectorLength(dx, dy, dz)
    if predicted_distance < 0.001 then return nil end

    local dir_x, dir_y, dir_z = normalize(dx, dy, dz)
    local aim_x, aim_y, aim_z = normalize(getCamera(shooter_dyn))

    local dot = clamp(dotProduct(aim_x, aim_y, aim_z, dir_x, dir_y, dir_z), -1, 1)
    if deg(acos(dot)) > threshold then return nil end

    return predicted_distance
end

-- Looks for new locks that arrive at suspiciously even intervals.
---@param state PlayerAimState Per-player state.
local function checkPattern(state)
    local pattern = state.lock_pattern

    insert(pattern, now())
    if #pattern > CFG.PATTERN_DETECTION.MAX_PATTERN_LENGTH then
        remove(pattern, 1)
    end

    if #pattern < CFG.PATTERN_DETECTION.MIN_LOCKS then return end

    local intervals = {}
    for i = 2, #pattern do
        ---@diagnostic disable-next-line: need-check-nil
        insert(intervals, pattern[i] - pattern[i - 1])
    end

    local _, std_dev = computeStats(intervals)
    if std_dev < CFG.PATTERN_DETECTION.MAX_STD_DEV then
        state.aim_score = state.aim_score + CFG.PATTERN_DETECTION.SCORE_BOOST
        state.lock_pattern = {} -- Start over so one pattern is only counted once
    end
end

-- Scores one aim event. Returns true if something was scored.
---@param shooter_id     number Shooter player index.
---@param shooter_dyn    number Shooter dynamic player address.
---@param target_id      number Target player index.
---@param snap_angle_deg number Camera change this tick (degrees).
---@param distance       number Distance to the target (world units).
---@return boolean scored True if the event added to the shooter's score.
local function evaluateAim(shooter_id, shooter_dyn, target_id, snap_angle_deg, distance)
    local state = players[shooter_id]
    ---@cast state PlayerAimState

    local is_snap = snap_angle_deg > CFG.SNAP_DETECTION.BASELINE_DEGREES
    local is_tracking = CFG.SNAP_DETECTION.TRACKING_ENABLED and snap_angle_deg > 0
        and snap_angle_deg < CFG.SNAP_DETECTION.MOVING_THRESHOLD_DEGREES
        and getHorizontalSpeed(shooter_dyn) > CFG.SNAP_DETECTION.MOVING_SPEED

    if not is_snap and not is_tracking then return false end

    local hit_detected = validateRaycastHit(shooter_id, shooter_dyn, target_id)

    local points
    if is_snap then
        points = snap_angle_deg * (hit_detected and CFG.SCORING.SNAP_ON_TARGET or CFG.SCORING.SNAP_OFF_TARGET)
    else
        points = hit_detected and CFG.SCORING.TRACK_ON_TARGET or CFG.SCORING.TRACK_OFF_TARGET
    end

    -- A new lock is the first scoring tick after a gap, so a sustained lock is only one event.
    local is_new_lock = not state.was_scoring

    -- Lock count is read before this event is added to it.
    local final_score = points + state.lock_count * distance * CFG.SCORING.LOCK_DISTANCE_WEIGHT
    state.lock_count = state.lock_count + 1

    if CFG.ENVIRONMENTAL.ENABLED and not isVisible(shooter_id, target_id) then
        final_score = final_score * CFG.ENVIRONMENTAL.OBSCURED_MULTIPLIER
    end

    if CFG.CAMO.ENABLED and isPlayerCamouflaged(target_id) then
        final_score = final_score * CFG.CAMO.SCORE_MULTIPLIER
    end

    state.aim_score = state.aim_score + final_score

    if CFG.PATTERN_DETECTION.ENABLED and is_new_lock then
        checkPattern(state)
    end

    return true
end

---@param shooter_id number Shooter player index.
local function enforce(shooter_id)
    local state = players[shooter_id]
    if not state then return end

    cprint(
		fmt(
            CFG.MESSAGES.ADMIN_ALERT,
			get_var(shooter_id, "$name"),
			shooter_id,
			state.aim_score,
			CFG.ENFORCEMENT.COMMAND
		), 12
    )
    local command
    if CFG.ENFORCEMENT.COMMAND == "ipban" then
        command = fmt('%s %d %d "%s"',
			CFG.ENFORCEMENT.COMMAND,
			shooter_id,
			CFG.ENFORCEMENT.IPBAN_TIME_MINUTES,
			CFG.MESSAGES.PLAYER_KICK_REASON
        )
    else
        command = fmt('%s %d "%s"',
			CFG.ENFORCEMENT.COMMAND,
			shooter_id,
			CFG.MESSAGES.PLAYER_KICK_REASON
		)
    end
    execute_command(command)

    resetLife(state)
end

-- Runs the decay, accuracy tracking, aim checks and enforcement for one living player.
---@param shooter_id number Shooter player index.
local function processPlayerAim(shooter_id)
    -- State is cleared at game end, and players are still alive for a moment after it.
    local state = players[shooter_id]
    if not state then return end

    local shooter_dyn = get_dynamic_player(shooter_id)
    if shooter_dyn == 0 then
        camera_vectors[shooter_id] = nil
        return
    end

    -- Decay. The timer always advances so unused time is never banked.
    local current_time = now()
    local elapsed = current_time - state.last_decay_time
    if elapsed >= CFG.DECAY.INTERVAL_SECONDS then
        state.last_decay_time = current_time
        state.aim_score = max(0, state.aim_score - elapsed * CFG.DECAY.POINTS_PER_SECOND)
    end

    updateAccuracy(shooter_id, shooter_dyn)

    local orientation_change = calculateOrientationChange(shooter_id, shooter_dyn)
    local threshold = getAimThreshold(shooter_id, shooter_dyn)
    local scoring_occurred = false

    for target_id = 1, 16 do
        if isEnemy(shooter_id, target_id) then
            local distance = checkAimAtTarget(shooter_dyn, target_id, threshold)
            if distance then
                scoring_occurred = evaluateAim(shooter_id, shooter_dyn, target_id, orientation_change, distance)
                break
            end
        end
    end

    if not scoring_occurred then
        state.lock_count = max(0, state.lock_count - 0.5)
    end
    state.was_scoring = scoring_occurred

    if state.aim_score > CFG.AUTO_AIM.MAX_SCORE then
        enforce(shooter_id)
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_DIE, "OnDie")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart() -- in case the script was loaded mid-game
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    is_ffa = get_var(0, "$ffa") == "1"
    weapon_cache = {}

    for i = 1, 16 do
        players[i] = player_present(i) and newState() or nil
        camera_vectors[i] = nil
    end
end

function OnEnd()
    for i = 1, 16 do
        players[i] = nil
        camera_vectors[i] = nil
    end
    weapon_cache = {}
end

---@param player_id number Player index.
function OnJoin(player_id)
    players[player_id] = newState()
    camera_vectors[player_id] = nil
end

---@param player_id number Player index.
function OnDie(player_id)
    local state = players[player_id]
    if state then resetLife(state) end

    camera_vectors[player_id] = nil
end

---@param player_id number Player index.
function OnLeave(player_id)
    players[player_id] = nil
    camera_vectors[player_id] = nil
end

function OnTick()
    tick_count = tick_count + 1 -- More reliable than os.clock() for decay and timing, since it is tied to the server tick rate.

    -- One pass up front so team lookups are not repeated for every shooter and target pair.
    for i = 1, 16 do
        tick_teams[i] = player_present(i) and player_alive(i) and get_var(i, "$team")
    end

    for i = 1, 16 do
        if tick_teams[i] then
            processPlayerAim(i)
        end
    end
end

function OnScriptUnload() end
