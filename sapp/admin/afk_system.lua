--[[
=====================================================================================
SCRIPT NAME:      afk_system.lua
DESCRIPTION:      Automated AFK management system.
                  - Detects inactivity via movement, camera/aim, and various inputs.
                  - Configurable AFK timeout, warnings, and grace periods.
                  - Supports manual/auto AFK toggling.
                  - Admin immunity configurable per level.
                  - Sends progressive warnings and custom kick messages.

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- ========================= CONFIGURATION ====================================--

local AFK_ACTIVATE_MSG = "$name is now AFK."
local AFK_DEACTIVATE_MSG = "$name is no longer AFK."
local WARNING_MESSAGE = "Warning: You will be kicked in $time_until_kick seconds for being AFK."
local KICK_REASON = "for being AFK!"

local MAX_AFK_TIME = 5      -- Maximum allowed AFK time (seconds)
local GRACE_PERIOD = 60     -- Grace period before kicking (seconds)
local WARNING_INTERVAL = 30 -- Warning frequency (seconds)

local AIM_THRESHOLD = 0.05           -- Camera aim detection sensitivity (increased to ignore tiny shakes)
local AFK_PERMISSION = -1            -- Minimum admin level required (-1 = public, 1-4 = admin levels)
local AFK_COMMAND = "afk"            -- Command to toggle AFK status
local AFK_STATUS_COMMAND = "afklist" -- Command to list AFK players
local AFK_KICK_IMMUNITY = { -- Admin levels with kick immunity (true = immunity, false = no immunity)
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true
}

local MONITOR_INPUT = { -- Inputs to monitor for activity (true = enabled, false = disabled)
    shooting = true,       -- firing weapon
    movement = true,       -- forward/back/left/right / grenade throw
    weapon_switch = true,  -- switching weapons
    grenade_switch = true, -- switching to grenades
    reload = true,         -- reloading
    zoom = true,           -- zooming
    action = true          -- melee / flashlight / action / crouch / jump
}

-- Enable/disable position tracking
local USE_POSITION_CHECK = true

-- Minimum distance units to consider as intentional movement
-- 0.5 = very sensitive, 1.5 = only large moves
local POSITION_THRESHOLD = 0.75

-- CONFIG ENDS ---------------------------------------------------------------

api_version = "1.12.0.0"

local abs, floor, time, pairs = math.abs, math.floor, os.time, pairs
local sqrt = math.sqrt

local read_float = read_float
local read_byte = read_byte
local read_word = read_word
local read_dword = read_dword
local read_vector3d = read_vector3d
local get_dynamic_player = get_dynamic_player
local player_alive = player_alive
local player_present = player_present
local get_object_memory = get_object_memory
local get_player = get_player
local execute_command = execute_command
local get_var, say_all, rprint = get_var, say_all, rprint

local players = {}
local TOTAL_ALLOWED = MAX_AFK_TIME + GRACE_PERIOD
local INPUT_DEFS = {
    shooting = { read_float, 0x490 },
    movement = { read_byte, 0x2A3 },
    weapon_switch = { read_byte, 0x47C },
    grenade_switch = { read_byte, 0x47E },
    reload = { read_byte, 0x2A4 },
    zoom = { read_word, 0x480 },
    action = { read_word, 0x208 }
}

local function get_position(dyn)
    local crouch = read_float(dyn + 0x50C)
    local vehicle_id = read_dword(dyn + 0x11C)
    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn + 0x5C)
    else
        local object = get_object_memory(vehicle_id)
        if object ~= 0 then
            x, y, z = read_vector3d(object + 0x5C)
        end
    end

    local z_off = z and (crouch == 0 and 0.65 or 0.35 * crouch) or 0

    return { x = x, y = y, z = z_off }
end

local function distance(pos1, pos2)
    if not pos1 or not pos2 then return 0 end
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return sqrt(dx * dx + dy * dy + dz * dz)
end

local function has_immunity(id)
    return AFK_KICK_IMMUNITY[tonumber(get_var(id, "$lvl"))]
end

local function has_perm(id)
    return tonumber(get_var(id, "$lvl")) >= AFK_PERMISSION
end

local function is_command(msg)
    local c = msg:sub(1, 1)
    return c == '/' or c == '\\'
end

local function broadcast(player, message, public)
    local msg = message:gsub("$name", player.name or "Player")
    if public then
        say_all(msg)
    else
        rprint(player.id, msg)
    end
end

local function init_input_states(player, dyn)
    local inputs = player.inputStates
    for i = 1, #inputs do
        local entry = inputs[i]
        entry[3] = entry[1](dyn + entry[2])
    end
    player.inputStatesInitialized = true
end

local function is_moving_key_pressed(dyn)
    local move_flags = read_byte(dyn + 0x2A3)
    return move_flags ~= 0
end

local function enter_afk(player)
    player.afk = true
    execute_command('kill ' .. player.id)
    broadcast(player, AFK_ACTIVATE_MSG, true)
end

local function exit_afk(player)
    player.afk = nil

    ---@diagnostic disable-next-line: need-check-nil
    -- Subtract 1 death HERE and not in toggle_afk, otherwise, if the player
    -- has exactly 0 deaths before they go AFK, it will cause them to respawn (due to the -1)
    local deaths = tonumber(get_var(player.id, "$deaths")) - 1
    execute_command('deaths ' .. player.id .. ' ' .. deaths)

    broadcast(player, AFK_DEACTIVATE_MSG, true)
end

local function toggle_afk(player)
    if player.afk then
        exit_afk(player)
    else
        enter_afk(player)
    end
end

local function update_camera(player, cameraPosition, current_time)
    player.lastActive = current_time
    local prev = player.previousCamera
    prev[1], prev[2], prev[3] = cameraPosition[1], cameraPosition[2], cameraPosition[3]
end

local function has_camera_moved(player, currentCamera)
    local prev = player.previousCamera
    return abs(currentCamera[1] - prev[1]) > AIM_THRESHOLD or abs(currentCamera[2] - prev[2]) > AIM_THRESHOLD
        or abs(currentCamera[3] - prev[3]) > AIM_THRESHOLD
end

local function get_input_states()
    local inputStates = {}
    for name, enabled in pairs(MONITOR_INPUT) do
        ---@diagnostic disable-next-line: unnecessary-if
        if enabled and INPUT_DEFS[name] then
            local def = INPUT_DEFS[name]
            ---@diagnostic disable-next-line: undefined-field
            inputStates[#inputStates + 1] = { def[1], def[2], nil }
        end
    end
    return inputStates
end

local function process_inputs(player, dyn, current_time)
    if player.afk then return end

    if not player.inputStatesInitialized then
        init_input_states(player, dyn)
        if not player.inputStatesInitialized then return end
    end

    local inputs = player.inputStates
    for i = 1, #inputs do
        local entry = inputs[i]
        local currentValue = entry[1](dyn + entry[2])
        if currentValue ~= entry[3] then
            player.lastActive = current_time
            entry[3] = currentValue
        end
    end
end

local function terminate(player)
    execute_command("k " .. player.id .. '"' .. KICK_REASON .. '"')
    players[player.id] = nil
end

local function check_afk_status(player, current_time)
    if not player.afk then
        ---@diagnostic disable-next-line: unnecessary-if
        if not has_immunity(player.id) then
            local inactive_duration = current_time - player.lastActive
            if inactive_duration >= TOTAL_ALLOWED then
                ---@diagnostic disable-next-line: call-non-callable
                terminate(player)
                return true
            elseif inactive_duration >= MAX_AFK_TIME then
                if current_time - player.lastWarning >= WARNING_INTERVAL then
                    local timeLeft = TOTAL_ALLOWED - inactive_duration
                    ---@diagnostic disable-next-line: undefined-field, call-non-callable
                    local msg = WARNING_MESSAGE:gsub("$time_until_kick", floor(timeLeft))
                    ---@diagnostic disable-next-line: call-non-callable
                    broadcast(player, msg, false)
                    player.lastWarning = current_time
                end
            end
        end
        return false
    end

    if not player_alive(player.id) then return false end

    local inactive_duration = current_time - player.lastActive
    if inactive_duration >= MAX_AFK_TIME then
        ---@diagnostic disable-next-line: unnecessary-if
        if not has_immunity(player.id) then
            ---@diagnostic disable-next-line: call-non-callable
            enter_afk(player)
            return true
        end
    end

    return false
end

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnChat")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    players = {}
    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnTick()
    local current_time = time()

    for i, player in pairs(players) do
        local dyn = get_dynamic_player(i)
        if dyn ~= 0 then
            process_inputs(player, dyn, current_time)

            ---@diagnostic disable-next-line: unnecessary-if
            if USE_POSITION_CHECK then
                local currentPos = get_position(dyn)
                if player.lastPosition then
                    local dist = distance(currentPos, player.lastPosition)
                    if dist > POSITION_THRESHOLD and is_moving_key_pressed(dyn) then
                        player.lastActive = current_time
                    end
                end
                player.lastPosition = currentPos
            end

            local cam = player.currentCamera
            cam[1] = read_float(dyn + 0x230)
            cam[2] = read_float(dyn + 0x234)
            cam[3] = read_float(dyn + 0x238)

            if has_camera_moved(player, cam) and is_moving_key_pressed(dyn) then
                update_camera(player, cam, current_time)
            end

            check_afk_status(player, current_time)
        elseif player.afk then
            write_dword(get_player(i) + 0x2C, 0.1 * 33) -- keep player dead (afk)
        end
    end
end

function OnJoin(id)
    players[id] = {
        id = id,
        name = get_var(id, "$name"),
        lastActive = time(),
        lastWarning = 0,
        previousCamera = { 0, 0, 0 },
        currentCamera = { 0, 0, 0 },
        afk = false,
        inputStatesInitialized = false,
        inputStates = get_input_states(),
        lastPosition = nil
    }
end

function OnQuit(id)
    players[id] = nil
end

function OnCommand(id, command)
    local player = players[id]
    if not player then return end

    local cmd = command:lower()
    if cmd == AFK_COMMAND then
        if has_perm(id) then
            toggle_afk(player)
        else
            rprint(id, "You don't have permission to use this command.")
        end
        return false
    end

    if player.afk then return false end
    player.lastActive = time()

    if cmd == AFK_STATUS_COMMAND then
        if has_perm(id) then
            local afkList = {}
            for _, p in pairs(players) do
                if p.afk then
                    afkList[#afkList + 1] = p.name
                end
            end
            local msg = (#afkList > 0) and ("AFK players: " .. table.concat(afkList, ", ")) or "No players are AFK"
            rprint(id, msg)
        else
            rprint(id, "You don't have permission to use this command.")
        end
        return false
    end

    return true
end

function OnChat(id, msg)
    local player = players[id]
    if not player then return true end

    if is_command(msg) then return true end
    if player.afk then return false end

    player.lastActive = time()
    return true
end
