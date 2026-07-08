--[[
===============================================================================
SCRIPT NAME:      block_replace_objects.lua
DESCRIPTION:      Controls object spawning with:
                  - Ability to block specific objects
                  - Option to replace objects with alternatives
                  - Per-gametype configuration

FEATURES:
                  - Works with all object types (weapons, vehicles, etc.)
                  - Simple tag-based configuration
                  - Runtime adjustments without server restart
                  - Error handling and validation
                  - Caching for better performance

CONFIGURATION:    Edit the tags table to:
                  - Block objects: {tag_type, "tag/path"}
                  - Replace objects: {src_type, "src/path", dest_type, "dest/path"}
                  - Organize by gametype

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

-- CONFIG
local TAGS_CONFIG = {
    -- Replace Format: {tag_type, "tag/path", replacement_type, "replacement/path"}
    -- Block Format: {tag_type, "tag/path"}

    -- Example configurations for different gametypes
    ["ctf"] = {
        -- Block frag grenades in CTF
        { "eqip", "weapons\\frag grenade\\frag grenade" },

        -- Replace assault rifle with pistol in CTF
        { "weap", "weapons\\assault rifle\\assault rifle", "weap", "weapons\\pistol\\pistol" }
    },

    ["slayer"] = {
        -- Example for slayer mode
        { "weap", "weapons\\sniper rifle\\sniper rifle", "weap", "weapons\\rocket launcher\\rocket launcher" }
    }

    -- Add more gametypes as needed
}

-- CONFIG ENDS --

-- Internal state
local block_table = {}
local replace_table = {}

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function processConfig(config)
    for _, entry in ipairs(config) do
        local entry_type = #entry
        local src_tag_id, dest_tag_id

        if entry_type == 2 then
            -- Block entry: {tag_type, "tag/path"}
            src_tag_id = getTag(entry[1], entry[2])
            if src_tag_id then
                block_table[src_tag_id] = true
            end
        elseif entry_type == 4 then
            -- Replace entry: {src_type, "src/path", dest_type, "dest/path"}
            src_tag_id = getTag(entry[1], entry[2])
            dest_tag_id = getTag(entry[3], entry[4])

            if src_tag_id and dest_tag_id then
                replace_table[src_tag_id] = dest_tag_id
            end
        else
            -- Invalid entry format
            cprint("Invalid configuration entry format. Expected 2 or 4 elements, got " .. entry_type, 4)
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == 'n/a' then return end

    local gametype = get_var(0, "$mode")

    block_table = {}
    replace_table = {}

    local config = TAGS_CONFIG[gametype]
    ---@diagnostic disable-next-line: unnecessary-if
    if config then
        processConfig(config)
        register_callback(cb.EVENT_OBJECT_SPAWN, "OnObjectSpawn")
        return
    end

    unregister_callback(cb.EVENT_OBJECT_SPAWN)
end

function OnObjectSpawn(_, object_id)
    if block_table[object_id] then return false end
    local replacement_id = replace_table[object_id]
    ---@diagnostic disable-next-line: unnecessary-if
    if replacement_id then return true, replacement_id end
    return true
end

function OnScriptUnload() end
