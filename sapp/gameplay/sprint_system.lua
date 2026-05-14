--[[
=====================================================================================
SCRIPT NAME:      sprint_system.lua
DESCRIPTION:      Advanced stamina-based sprinting system with toggle controls,
                  exhaustion mechanics, and real-time HUD feedback.

FEATURES:
                 - Flashlight key toggles sprinting (press to start/stop)
                 - Dynamic stamina management with drain/regen rates
                 - Three sprint states: Ready, Active, Exhausted
                 - Speed modifiers for sprinting and exhaustion
                 - Text-based stamina HUD with visual bar
                 - Configurable thresholds and rates
                 - Automatic state transitions

CONFIGURATION:
                 - stamina_max:          Maximum stamina capacity (default: 100)
                 - sprint_speed:         Speed multiplier while sprinting (default: 1.5x)
                 - exhaust_speed:        Speed penalty when exhausted (default: 0.8x)
                 - drain_rate:           Stamina depletion rate per tick (default: 0.35)
                 - regen_rate:           Stamina recovery rate per tick (default: 0.2)
                 - exhaust_threshold:    Minimum stamina to begin sprinting (default: 25)
                 - hud_update_interval:  HUD refresh rate in ticks (default: 30)

USAGE:
1. Press flashlight key to start sprinting
2. Release to stop or continue until exhausted
3. Wait for stamina to recover after exhaustion

LAST UPDATED:     20/8/2025

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

---------------------------------
-- CONFIGURATION
---------------------------------

local stamina_max = 100           -- Maximum stamina value
local sprint_speed = 1.5          -- Speed multiplier while sprinting
local exhaust_speed = 0.8         -- Speed multiplier when exhausted (slower)
local drain_rate = 0.35           -- Stamina drained per tick while sprinting
local regen_rate = 0.2            -- Stamina regenerated per tick while not sprinting
local exhaust_threshold = 25      -- Minimum stamina required to start sprinting
local hud_update_interval = 30    -- Update HUD once every 30 ticks (~1 second at 30 TPS)

-- CONFIG ENDS

api_version = "1.12.0.0"

-- Cache global functions locally for speed
local rprint, say = rprint, say
local execute_command = execute_command
local player_present = player_present
local player_alive = player_alive
local read_bit = read_bit
local get_dynamic_player = get_dynamic_player
local math_floor = math.floor
local string_rep = string.rep
local string_format = string.format
local math_min = math.min

-- Player state tracking
local players = {}
local FLASHLIGHT_BIT_OFFSET = 0x208
local SPRINTING_STATE = {
    DISABLED = 0,
    ACTIVE = 1,
    EXHAUSTED = 2
}

local function set_speed(id, multiplier)
    execute_command("s " .. id .. " " .. multiplier)
end

local function clear_hud(id)
    for _ = 1, 25 do rprint(id, " ") end
end

local function update_hud(player_id, stamina, state)
    clear_hud(player_id) -- Clear previous messages

    local status_text = ""
    if state == SPRINTING_STATE.ACTIVE then
        status_text = "| SPRINTING |"
    elseif state == SPRINTING_STATE.EXHAUSTED then
        status_text = "| EXHAUSTED |"
    else
        status_text = "| READY |"
    end

    local segments = 20
    local filled = math_floor((stamina / stamina_max) * segments)
    local bar = string_rep("|", filled) .. string_rep(" ", segments - filled)

    local message = string_format("STAMINA: %s %d%% %s", bar, math_floor(stamina), status_text)
    rprint(player_id, message)
end

local function is_valid_player(i, player)
    return player and player_present(i) and player_alive(i)
end

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_LEAVE, 'OnLeave')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    players = {}
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnJoin(id)
    players[id] = {
        stamina = stamina_max,
        sprint_state = SPRINTING_STATE.DISABLED,
        last_flashlight = 0,
        last_hud_update = 0
    }
end

function OnLeave(id)
    players[id] = nil
end

function OnSpawn(id)
    if players[id] then
        players[id].stamina = stamina_max
        players[id].sprint_state = SPRINTING_STATE.DISABLED
        set_speed(id, 1.0)
    end
end

function OnTick()
    for i = 1, 16 do
        local player = players[i]
        if not is_valid_player(i, player) then goto continue end

        local dyn_player = get_dynamic_player(i)
        local flashlight_state = read_bit(dyn_player + FLASHLIGHT_BIT_OFFSET, 4)

        -- Detect flashlight toggle
        if flashlight_state ~= player.last_flashlight then
            player.last_flashlight = flashlight_state

            if flashlight_state == 1 then
                if player.sprint_state == SPRINTING_STATE.DISABLED and player.stamina > exhaust_threshold then
                    player.sprint_state = SPRINTING_STATE.ACTIVE
                elseif player.sprint_state == SPRINTING_STATE.ACTIVE then
                    player.sprint_state = SPRINTING_STATE.DISABLED
                elseif player.sprint_state == SPRINTING_STATE.EXHAUSTED then
                    update_hud(i, player.stamina, player.sprint_state)
                end
            end
        end

        -- State machine
        if player.sprint_state == SPRINTING_STATE.ACTIVE then
            player.stamina = player.stamina - drain_rate
            set_speed(i, sprint_speed)

            if player.stamina <= 0 then
                player.stamina = 0
                player.sprint_state = SPRINTING_STATE.EXHAUSTED
                set_speed(i, exhaust_speed)
                say(i, "You're exhausted! Recover stamina to sprint again")
            end
        elseif player.sprint_state == SPRINTING_STATE.EXHAUSTED then
            player.stamina = player.stamina + regen_rate
            set_speed(i, exhaust_speed)

            if player.stamina >= stamina_max then
                player.stamina = stamina_max
                player.sprint_state = SPRINTING_STATE.DISABLED
                set_speed(i, 1.0)
            end
        else
            player.stamina = math_min(stamina_max, player.stamina + regen_rate)
            set_speed(i, 1.0)
        end

        -- Show HUD only while sprinting and at intervals
        if player.sprint_state == SPRINTING_STATE.ACTIVE then
            player.last_hud_update = player.last_hud_update + 1
            if player.last_hud_update >= hud_update_interval then
                update_hud(i, player.stamina, player.sprint_state)
                player.last_hud_update = 0
            end
        end

        ::continue::
    end
end