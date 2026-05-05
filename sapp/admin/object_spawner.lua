--[[
=====================================================================================
SCRIPT NAME:      object_spawner.lua
DESCRIPTION:      Map-specific object spawning system with precise positioning control.

FEATURES:
                  - Per-map object configuration
                  - Exact coordinate placement (X,Y,Z)
                  - Rotation control (in radians)
                  - Supports all tag types (weapons, vehicles, scenery, etc.)
                  - Automatic spawning on game start

USAGE:
                  1. Add entries to the objects table using format:
                     { "tag_type", "tag_path", x, y, z, rotation }
                  2. Multiple objects can be spawned per map
                  3. Rotation values must be in radians

Copyright (c) 2021-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local objects = {

    -- Objects will be spawned on a per-map basis.

    ["bloodgulch"] = {
        --
        -- Format as follows: tag type, tag name, x, y, z, rotation
        -- Make sure object rotation coordinates are in radians not degrees.
        --
        -- This weapon will spawn on top of Red Base by the ramp
        { "weap", "weapons\\sniper rifle\\sniper rifle", 90.899, -159.633, 1.704, 1.587 },
    },

    -- Repeat the structure to add more entries:
    ["example map"] = {
        { "tag type", "tag name", 0, 0, 0, 0 },
        { "tag type", "tag name", 0, 0, 0, 0 },
        { "tag type", "tag name", 0, 0, 0, 0 },
        { "tag type", "tag name", 0, 0, 0, 0 },
    },
}

function OnScriptLoad()
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
end

function OnGameStart()
    local map = get_var(0, "$map")
    if get_var(0, "$gt") ~= "n/a" and objects[map] then
        for _, v in pairs(objects[map]) do
            spawn_object(v[1], v[2], v[3], v[4], v[5], v[6])
        end
    end
end
