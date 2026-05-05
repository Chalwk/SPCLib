--[[
=====================================================================================
SCRIPT NAME:      weighted_weapons.lua
DESCRIPTION:      Realistic weapon weight system that affects player movement speed
                  with optional stamina mechanics for enhanced tactical gameplay.

KEY FEATURES:
                 - Weapon-specific weight values affecting mobility
                 - Dual calculation modes (active weapon vs all carried weapons)
                 - Comprehensive stamina system:
                   * Dynamic depletion during movement
                   * Gradual regeneration while resting
                   * Visual stamina bar display
                   * Exhaustion penalties
                 - Configurable weight values for all weapons
                 - Real-time speed adjustments

CONFIGURATION OPTIONS:
                 - Toggle between active/all weapon weight modes
                 - Adjustable stamina parameters:
                   * Depletion/regeneration rates
                   * Maximum stamina capacity
                   * Exhaustion penalties
                 - Customizable visual display:
                   * Stamina bar length
                   * Refresh rate
                 - Weapon-specific weight tuning

LAST UPADTED:     August, 2025

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration Settings --
local CONFIG = {
    default_speed = 1.0,
    combined_weight = true,   -- False: Active weapon only, True: All carried weapons
    stamina_enabled = true,   -- Toggle stamina system
    max_stamina = 100,        -- Maximum stamina value
    stamina_depletion = 0.5,  -- Stamina loss per tick when moving
    stamina_regen = 0.5,      -- Stamina gain per tick when resting
    exhaustion_penalty = 0.2, -- Speed reduction when exhausted
    bar_length = 20,          -- Visual length of stamina bar

    -- Weapon weight definitions (tag path: weight ratio)
    weights = {
        ['weapons\\flag\\flag'] = 0.056,
        ['weapons\\ball\\ball'] = 0.056,
        ['weapons\\pistol\\pistol'] = 0.072,
        ['weapons\\plasma pistol\\plasma pistol'] = 0.072,
        ['weapons\\needler\\mp_needler'] = 0.084,
        ['weapons\\plasma rifle\\plasma rifle'] = 0.084,
        ['weapons\\shotgun\\shotgun'] = 0.094,
        ['weapons\\assault rifle\\assault rifle'] = 0.122,
        ['weapons\\flamethrower\\flamethrower'] = 0.140,
        ['weapons\\sniper rifle\\sniper rifle'] = 0.146,
        ['weapons\\plasma_cannon\\plasma_cannon'] = 0.190,
        ['weapons\\rocket launcher\\rocket launcher'] = 0.200
    }
}

-- CONFIG ENDS -----------------------------------------------

api_version = '1.12.0.0'

local floor, min, max = math.floor, math.min, math.max

local weapon_tags = {} -- weapon tag ID: weight
local players = {} -- PlayerID: {stamina, last_bar}

local function get_tag_id(class, name)
    local tag = lookup_tag(class, name)
    return (tag ~= 0) and read_dword(tag + 0xC) or nil
end

local function update_weapon_tags()
    weapon_tags = {}
    for path, weight in pairs(CONFIG.weights) do
        local tag_id = get_tag_id('weap', path)
        if tag_id then
            weapon_tags[tag_id] = weight
        end
    end
end

function InitPlayer(player)
    players[player] = {
        stamina = CONFIG.max_stamina,
        last_bar = "" -- Last displayed stamina bar
    }
end

local function get_weapon_weight(weapon_id)
    if weapon_id == 0xFFFFFFFF then return 0 end
    local obj = get_object_memory(weapon_id)
    return obj ~= 0 and weapon_tags[read_dword(obj)] or 0
end

local function get_player_speed(player)
    local dyn = get_dynamic_player(player)
    if dyn == 0 or not player_alive(player) then
        return CONFIG.default_speed
    end

    local total_weight = 0
    local data = players[player]

    -- Calculate weight burden
    if CONFIG.combined_weight then
        for slot = 0, 3 do
            total_weight = total_weight + get_weapon_weight(read_dword(dyn + 0x2F8 + slot * 4))
        end
    else
        total_weight = get_weapon_weight(read_dword(dyn + 0x118))
    end

    -- Apply stamina penalty if exhausted
    local speed = CONFIG.default_speed - total_weight
    if CONFIG.stamina_enabled and data.stamina <= 0 then
        speed = speed - CONFIG.exhaustion_penalty
    end

    return max(speed, 0.1) -- Ensure minimum speed
end

local function update_stamina_display(player)
    local data = players[player]
    if not data then return end

    local percent = (data.stamina / CONFIG.max_stamina) * 100
    local filled = floor(CONFIG.bar_length * (percent / 100))
    local empty = CONFIG.bar_length - filled

    local bar = "|" .. string.rep("=", filled) .. string.rep(" ", empty) .. "|"
    local display = "Stamina: " .. bar .. " " .. floor(percent) .. "%"

    -- Only update if display changed
    if display ~= data.last_bar then
        for _ = 1, 25 do rprint(player, " ") end -- Clear previous display
        rprint(player, display)
        data.last_bar = display
    end
end

-- Callbacks --
function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'InitPlayer')
    register_callback(cb['EVENT_SPAWN'], 'InitPlayer')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()

    if get_var(0, '$gt') == 'n/a' then return end

    update_weapon_tags()
    players = {}
    for i = 1, 16 do
        if player_present(i) then
            InitPlayer(i)
        end
    end
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) then
            local data = players[i]
            if not data then goto next end

            if player_alive(i) then
                -- Apply movement effects
                local speed = get_player_speed(i)
                execute_command('s ' .. i .. ' ' .. speed)

                -- Update stamina system
                if CONFIG.stamina_enabled then
                    data.stamina = data.stamina - CONFIG.stamina_depletion
                    update_stamina_display(i)
                end
            end

            -- Regenerate stamina (alive or dead)
            if CONFIG.stamina_enabled then
                data.stamina = min(CONFIG.max_stamina, data.stamina + CONFIG.stamina_regen)
            end
            ::next::
        end
    end
end

function OnScriptUnload() end