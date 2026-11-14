--[[
==============================================================================
SCRIPT NAME:    script_manager.lua
DESCRIPTION:    Dynamic script loader that automatically loads/unloads
                Lua scripts based on the current map and game mode.

CONFIGURATION:  maps[map_name][mode_key] = { 'script1', 'script2' }

Copyright (c) 2024-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
==============================================================================
]]

api_version = '1.12.0.0'

-- CONFIG START --
local maps = {
    ['bloodgulch'] = {
        ['slayer'] = { 'notify_me', 'another_script' }
    },
    ['deathisland'] = {
        ['ctf']       = { 'dynamic_scorelimit' },
        ['Team Race'] = { 'track_master' }
    }
}
-- CONFIG ENDS --

local maps_lc = {}
local loaded = {}

local function normalizeConfig()
    for map_name, modes in pairs(maps) do
        local map_key = map_name:lower()
        local entry = maps_lc[map_key] or {}
        maps_lc[map_key] = entry

        for mode_name, scripts in pairs(modes) do
            entry[mode_name:lower()] = scripts
        end
    end
end

local function loadScript(name)
    if loaded[name] then return end

    execute_command(string.format('lua_load "%s"', name))
    loaded[name] = true
    cprint('[Script Manager] Loading: ' .. name, 11)
end

local function unloadScript(name)
    if not loaded[name] then return end

    execute_command(string.format('lua_unload "%s"', name))
    loaded[name] = nil
    cprint('[Script Manager] Unloading: ' .. name, 11)
end

local function unloadAll()
    local names = {}
    for name in pairs(loaded) do
        names[#names + 1] = name
    end
    for i = 1, #names do
        unloadScript(names[i])
    end
end

local function processMapMode(map, mode)
    local wanted = maps_lc[map] and maps_lc[map][mode] or {}
    local wanted_set = {}
    for i = 1, #wanted do
        wanted_set[wanted[i]] = true
    end

    local to_unload = {}
    for name in pairs(loaded) do
        if not wanted_set[name] then
            to_unload[#to_unload + 1] = name
        end
    end
    for i = 1, #to_unload do
        unloadScript(to_unload[i])
    end

    for i = 1, #wanted do
        if not loaded[wanted[i]] then
            loadScript(wanted[i])
        end
    end
end

function OnScriptLoad()
    normalizeConfig()

    register_callback(cb.EVENT_GAME_START, 'OnStart')

    OnStart() -- in case script is loaded mid-game
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    local map = get_var(0, '$map')
    local mode = get_var(0, '$mode')
    if not map or not mode then return end

    processMapMode(map:lower(), mode:lower())
end

function OnScriptUnload()
    unloadAll()
end
