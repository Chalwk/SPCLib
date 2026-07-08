--[[
==============================================================================
SCRIPT NAME:    script_manager.lua
DESCRIPTION:    Dynamic script loader that automatically loads/unloads scripts
                based on current map and game mode.

CONFIGURATION:
                maps:  Nested table defining script associations:
                maps[map_name][gamemode] = { 'script1', 'script2' }

Copyright (c) 2024-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
==============================================================================
]]

api_version = '1.12.0.0'

-- CONFIG START --

local maps = {
    ['bloodgulch'] = {
        ['LNZ-DAC'] = { 'notify_me', 'another_script' }
    },
    ['deathisland'] = {
        ['ctf'] = { 'dynamic_scorelimit' },
        ['team_race'] = { 'track_master' }
    }
}
-- CONFIG ENDS --

local loaded = {}

local function load_script(name)
    if loaded[name] then return end
    local ok, err = pcall(function ()
        execute_command('lua_load "' .. name .. '"')
        loaded[name] = true
        cprint('[Script Manager] Loaded: ' .. name)
    end)
    if not ok then
        cprint('[Script Manager] ERROR loading ' .. name .. ': ' .. tostring(err))
        loaded[name] = nil
    end
end

local function unload_script(name)
    if not loaded[name] then return end
    local ok, err = pcall(function ()
        execute_command('lua_unload "' .. name .. '"')
        loaded[name] = nil
        cprint('[Script Manager] Unloaded: ' .. name)
    end)
    if not ok then
        cprint('[Script Manager] ERROR unloading ' .. name .. ': ' .. tostring(err))
    end
end

local function unload_all()
    local names = {}
    for name in pairs(loaded) do
        table.insert(names, name)
    end
    for _, name in ipairs(names) do
        unload_script(name)
    end
end

local function process_map_mode(map, mode)
    local new_scripts = maps[map] and maps[map][mode] or {}
    local new_set = {}
    for _, name in ipairs(new_scripts) do
        new_set[name] = true
    end

    local to_unload = {}
    for name in pairs(loaded) do
        if not new_set[name] then
            table.insert(to_unload, name)
        end
    end
    for _, name in ipairs(to_unload) do
        unload_script(name)
    end

    for _, name in ipairs(new_scripts) do
        if not loaded[name] then
            load_script(name)
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnGameStart')
    register_callback(cb.EVENT_GAME_END, 'OnGameEnd')
    OnGameStart() -- Just incase (this) script is loaded mid-game
end

function OnGameStart()
    local gt = get_var(0, '$gt')
    if gt == 'n/a' then return end
    local map = get_var(0, '$map'):lower()
    local mode = get_var(0, '$mode'):lower()
    process_map_mode(map, mode)
end

function OnGameEnd()
    unload_all()
end

function OnScriptUnload()
    unload_all()
end
