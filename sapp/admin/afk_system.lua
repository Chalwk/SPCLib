--[[
=====================================================================================
SCRIPT NAME:      afk_system.lua
DESCRIPTION:      Automated AFK management system.
                  - Detects inactivity via movement, camera/aim, and input
                  - Configurable AFK timeout, warnings, and grace periods
                  - Supports manual/auto AFK toggling
                  - Admin immunity configurable per level
                  - Sends progressive warnings and custom kick messages

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--========================= CONFIGURATION ====================================--

-- 1. AFK Timing Settings
local MAX_AFK_TIME = 240    -- Maximum allowed AFK time (seconds)
local GRACE_PERIOD = 60     -- Grace period before kicking (seconds)
local WARNING_INTERVAL = 30 -- Warning frequency (seconds)

-- 2. AFK Detection Settings
local AIM_THRESHOLD = 0.001 -- Camera aim detection sensitivity (adjust as needed)

-- 3. AFK Command & Permissions
local AFK_PERMISSION = 3             -- Minimum admin level required (-1 = public, 1-4 = admin levels)
local AFK_COMMAND = "afk"            -- Command to toggle AFK status
local AFK_STATUS_COMMAND = "afklist" -- Command to list AFK players
local AFK_KICK_IMMUNITY = {          -- Admin levels with kick immunity
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true
}

-- 4. AFK Messages
local AFK_ACTIVATE_MSG = "$name is now AFK."
local AFK_DEACTIVATE_MSG = "$name is no longer AFK."
local WARNING_MESSAGE = "Warning: You will be kicked in $time_until_kick seconds for being AFK."
local KICK_MESSAGE = "$name was kicked for being AFK!"

-- CONFIG ENDS ---------------------------------------------------------------

api_version = "1.12.0.0"

local TOTAL_ALLOWED = MAX_AFK_TIME + GRACE_PERIOD
local players = {}

local abs, floor, time, pairs = math.abs, math.floor, os.time, pairs

local read_float = read_float
local read_byte = read_byte
local read_word = read_word
local read_dword = read_dword
local read_vector3d = read_vector3d
local write_vector3d = write_vector3d
local get_dynamic_player = get_dynamic_player
local player_alive = player_alive
local player_present = player_present
local get_object_memory = get_object_memory
local get_player = get_player
local destroy_object = destroy_object
local execute_command = execute_command
local execute_command_sequence = execute_command_sequence

local get_var, say_all, rprint = get_var, say_all, rprint

local function get_position(dyn)
    local crouch = read_float(dyn + 0x50C)
    local vehicle_id = read_dword(dyn + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    end

    return {
        x = x,
        y = y,
        z = z + (crouch == 0 and 0.65 or 0.35 * crouch)
    }
end

local function teleport(id, pos)
    local dyn = get_dynamic_player(id)
    if dyn == 0 or not pos then return end
    write_vector3d(dyn + 0x5C, pos.x, pos.y, pos.z)
end

local function hasKickImmunity(id)
    return AFK_KICK_IMMUNITY[tonumber(get_var(id, "$lvl"))]
end

local function hasPermission(id)
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

local function initInputStates(player)
    local dyn = get_dynamic_player(player.id)
    if dyn == 0 then return end

    local inputs = player.inputStates
    for i = 1, #inputs do
        local entry = inputs[i]
        entry[3] = entry[1](dyn + entry[2])
    end
    player.inputStatesInitialized = true
end

local function enterAFK(player)
    if player.afk then return end

    if not player_alive(player.id) then
        rprint(player.id, "You cannot go AFK while dead. Please respawn first.")
        return
    end

    local pdata = get_player(player.id)
    if pdata == 0 then return end

    local player_object = read_dword(pdata + 0x34)
    if player_object ~= 0 then
        local dyn = get_dynamic_player(player.id)
        if dyn == 0 then return end

        player.savedPosition = get_position(dyn)
        destroy_object(player_object)

        player.afk = true
        broadcast(player, AFK_ACTIVATE_MSG, true)
    end
end

local function exitAFK(player)
    if not player.afk then return end

    player.afk = false
    teleport(player.id, player.savedPosition)

    execute_command_sequence('w8 2; ungod ' .. player.id .. '; sh ' .. player.id .. ' 0')
    broadcast(player, AFK_DEACTIVATE_MSG, true)
end

local function toggleAFK(player)
    if player.afk then
        exitAFK(player)
    else
        enterAFK(player)
    end
end

local function updateCamera(player, cameraPosition, current_time)
    if player.afk then return end
    player.lastActive = current_time
    local prev = player.previousCamera
    prev[1], prev[2], prev[3] = cameraPosition[1], cameraPosition[2], cameraPosition[3]
end

local function hasCameraMoved(player, currentCamera)
    local prev = player.previousCamera
    return abs(currentCamera[1] - prev[1]) > AIM_THRESHOLD
        or abs(currentCamera[2] - prev[2]) > AIM_THRESHOLD
        or abs(currentCamera[3] - prev[3]) > AIM_THRESHOLD
end

local function processInputs(player, dyn)
    if player.afk then return end

    if not player.inputStatesInitialized then
        initInputStates(player)
        if not player.inputStatesInitialized then return end
    end

    local inputs = player.inputStates
    for i = 1, #inputs do
        local entry = inputs[i]
        local currentValue = entry[1](dyn + entry[2])
        if currentValue ~= entry[3] then
            player.lastActive = time()
            entry[3] = currentValue
        end
    end
end

local function terminate(player)
    local kick_msg = KICK_MESSAGE:gsub("$name", player.name or "Player")
    execute_command("k " .. player.id)
    broadcast(player, kick_msg, true)
    players[player.id] = nil
end

local function checkAFKStatus(player, current_time)
    if player.afk then
        if not hasKickImmunity(player.id) then
            local inactive_duration = current_time - player.lastActive
            if inactive_duration >= TOTAL_ALLOWED then
                terminate(player)
                return true
            elseif inactive_duration >= MAX_AFK_TIME then
                if current_time - player.lastWarning >= WARNING_INTERVAL then
                    local timeLeft = TOTAL_ALLOWED - inactive_duration
                    local msg = WARNING_MESSAGE:gsub("$time_until_kick", floor(timeLeft))
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
        if not hasKickImmunity(player.id) then
            enterAFK(player)
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
    register_callback(cb.EVENT_PRESPAWN, "OnPreSpawn")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
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
        if not player then goto continue end

        local dyn = get_dynamic_player(i)
        if dyn ~= 0 then
            processInputs(player, dyn)

            local cam = player.currentCamera
            cam[1] = read_float(dyn + 0x230)
            cam[2] = read_float(dyn + 0x234)
            cam[3] = read_float(dyn + 0x238)

            if hasCameraMoved(player, cam) then
                updateCamera(player, cam, current_time)
            end
        end

        checkAFKStatus(player, current_time)

        ::continue::
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
        savedPosition = nil,
        inputStatesInitialized = false,
        inputStates = {
            { read_float, 0x490 }, -- shooting
            { read_byte,  0x2A3 }, -- forward/back/left/right/grenade throw
            { read_byte,  0x47C }, -- weapon switch
            { read_byte,  0x47E }, -- grenade switch
            { read_byte,  0x2A4 }, -- weapon reload
            { read_word,  0x480 }, -- zoom
            { read_word,  0x208 }  -- melee, flashlight, action, crouch, jump
        }
    }
end

function OnQuit(id)
    players[id] = nil
end

function OnPreSpawn(id)
    local player = players[id]
    if player and player.afk then
        teleport(id, { x = -999, y = -999, z = -999 })
    end
end

function OnSpawn(id)
    local player = players[id]
    if player and player.afk then
        execute_command_sequence('god ' .. id .. '; sh ' .. id .. ' 9999999')
    end
end

function OnCommand(id, command)
    local player = players[id]
    if not player then return true end

    local cmd = command:lower()

    if cmd == AFK_COMMAND then
        if hasPermission(id) then
            toggleAFK(player)
        else
            rprint(id, "You don't have permission to use this command.")
        end
        return false
    end

    if player.afk then return false end

    player.lastActive = time()

    if cmd == AFK_STATUS_COMMAND then
        if hasPermission(id) then
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
