--[[
=====================================================================================
SCRIPT NAME:      melee_attack.lua
DESCRIPTION:      Brutal melee-only combat mode

Copyright (c) 2023-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--- CONFIG start ---------------------
local SCORELIMIT = 50
local RESPAWN_TIME = 0
--- CONFIG end -----------------------

api_version = '1.12.0.0'

-- Precomputed values
local oddballs = {}
local oddball_meta_id
local respawn_ticks = RESPAWN_TIME * 33

local BASE_TAG_TABLE = 0x40440000
local TAG_ENTRY_SIZE, TAG_DATA_OFFSET, BIT_CHECK_OFFSET, BIT_INDEX = 0x20, 0x14, 0x308, 3

local sapp_events = {
    [cb['EVENT_DIE']] = 'OnDeath',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_SPAWN']] = 'OnSpawn',
    [cb['EVENT_WEAPON_DROP']] = 'OnWeaponDrop',
}

local function registerCallbacks(enable)
    for event, callback in pairs(sapp_events) do
        if enable then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function setMapObjects()
    local tag_array = read_dword(BASE_TAG_TABLE)
    local tag_count = read_dword(BASE_TAG_TABLE + 0xC)

    local oddball_id
    for i = 0, tag_count - 1 do
        local tag = tag_array + TAG_ENTRY_SIZE * i
        local class = read_dword(tag)
        if class == 0x77656170 or class == 0x76656869 or class == 1701931376 then
            local tag_data = read_dword(tag + TAG_DATA_OFFSET)
            local name_ptr = read_dword(tag + 0x10)
            local tag_name = (name_ptr ~= 0) and read_string(name_ptr) or "<no-name>"
            if tag_data ~= 0 then
                if read_bit(tag_data + BIT_CHECK_OFFSET, BIT_INDEX) == 1 then
                    local item_type = read_byte(tag_data + 2)
                    if item_type == 4 and not oddball_id then
                        oddball_id = read_dword(tag + 0xC)
                        goto continue
                    end
                end
                ::continue::
                execute_command("disable_object '" .. tag_name .. "'")
            end
        end
    end

    return oddball_id
end

local function delete_weap(id)
    if oddballs[id] then
        destroy_object(oddballs[id])
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    oddballs = {}

    execute_command('scorelimit ' .. SCORELIMIT)
    oddball_meta_id = setMapObjects()

    if not oddball_meta_id then
        registerCallbacks(false)
        error('Failed to find oddball meta ID')
    end

    for i = 1, 16 do
        if player_present(i) then
            OnSpawn(i)
        end
    end

    registerCallbacks(true)
end

function OnQuit(id)
    delete_weap(id)
    oddballs[id] = nil
end

function OnSpawn(id)
    if not oddballs[id] then
        oddballs[id] = spawn_object('', '', 0, 0, -9999, 0, oddball_meta_id)
    end

    execute_command('wdel ' .. id)
    assign_weapon(oddballs[id], id)
end

function OnWeaponDrop(id)
    local weap = oddballs[id]
    if weap then assign_weapon(weap, id) end
end

function OnDeath(victim, killer)
    if tonumber(killer) > 0 then
        local player = get_player(tonumber(victim))
        if player ~= 0 then
            write_dword(player + 0x2C, respawn_ticks)
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_WEAPON_DROP, 'OnWeaponDrop')

    OnStart()
end

function OnScriptUnload() end
