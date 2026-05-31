--[[
===============================================================================
SCRIPT NAME:      liberty_vehicle_spawner.lua
DESCRIPTION:      On-demand vehicle spawning system with:
                  - Chat command activation
                  - Automatic player entry
                  - Custom map support

CONFIGURATION:
                HELP_COMMAND:           Command to list available vehicles
                COOLDOWN_PERIOD:        Cooldown time (seconds) between vehicle spawns per player
                DESPAWN_DELAY_SECONDS:  Time (in seconds) before a spawned vehicle despawns
                DEFAULT_TAGS: Base vehicle definitions
                    Format: ["keyword"] = "tag_path"
                        - keyword: What players type in chat to spawn the vehicle
                        - tag_path: The internal path to the vehicle tag name
                CUSTOM_TAGS: Map-specific vehicle definitions that extend DEFAULT_TAGS
                    Format: ["map_name"] = {["keyword"] = "tag_path", ...}
                        - map_name: The name of the map (not case sensitive)
                        - keyword: What players type in chat to spawn the vehicle
                        - tag_path: The internal path to the vehicle tag name
                    BEHAVIOR:
                        - For maps listed here: DEFAULT_TAGS and CUSTOM_TAGS are merged
                        - Stock vehicles take precedence over custom vehicles with same keyword
                        - If keyword conflicts occur, custom vehicles are automatically renamed (hog -> hog2, etc.)
                        - For maps not listed: Only DEFAULT_TAGS are available

LAST UPDATED:     31 May 2026

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG START ----------------------------------------------------------------
local HELP_COMMAND = "vlist"
local DESPAWN_DELAY_SECONDS = 7
local COOLDOWN_PERIOD = 7
-- CONFIG START ----------------------------------------------------------------

local DEFAULT_TAGS = { ["hog"] = "vehicles\\warthog\\mp_warthog", ["rhog"] = "vehicles\\rwarthog\\rwarthog" }

local CUSTOM_TAGS = {
    ["[h3]_sandtrap"] = {
        ["hog"] = "halo3\\vehicles\\warthog\\mp_warthog",
        ["hog2"] = "halo3\\vehicles\\mongoose\\mongoose"
    },
    ["bc_raceway_final_mp"] = {
        ["hog"] = "levels\\test\\racetrack\\custom_hogs\\mp_warthog_green",   -- green
        ["hog2"] = "levels\\test\\racetrack\\custom_hogs\\mp_warthog_blue",   -- blue
        ["hog3"] = "levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi1", -- red and pink
        ["hog4"] = "levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi2", -- green and red
        ["hog5"] = "levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi3"  -- blue, red, green, pink
    },
    ["cityscape-adrenaline"] = {
        ["hog2"] = "vehicles\\civvi\\civvi",
        ["hog"] = "vehicles\\g_warthog\\g_warthog",
        ["rhog"] = "vehicles\\rwarthog\\boogerhawg"
    },
    ["hypothermia_race"] = {
        ["hog"] = "vehicles\\g_warthog\\g_warthog"
    },
    ["mongoose_point"] = {
        ["hog"] = "vehicles\\m257_multvp\\m257_multvp",
        ["hog2"] = "vehicles\\m257_multvp\\m257_multvp2"
    },
    ["mystic_mod"] = {
        ["hog"] = "vehicles\\puma\\puma_lt",
        ["rhog"] = "vehicles\\puma\\rpuma_lt"
    },
    ["tsce_multiplayerv1"] = {
        ["hog"] = "cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_mp\\warthog_mp",
        ["rhog"] = "cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_rocket\\warthog_rocket"
    },
    ["hornets_nest"] = {
        ["hog"] = "halo3\\vehicles\\warthog\\mp_warthog",
        ["rhog"] = "halo3\\vehicles\\warthog\\rwarthog"
    },
    ["liberty_hornets_nest"] = {
        ["quad"] = "altis\\vehicles\\mongoose\\mongoose"
    },
    ["grove_final"] = {
        ["hog"] = "vehicles\\warthog\\art_cwarthog",
        ["rhog"] = "vehicles\\rwarthog\\art_rwarthog_shiny"
    },
    ["liberty_nightglow"] = {
        ["quad"] = "altis\\vehicles\\mongoose\\mongoose"
    },
    ["liberty_blockfort_race"] = {
        ["hog"] = "bourrin\\halo reach\\vehicles\\warthog\\h2 mp_warthog",
        ["rhog"] = "bourrin\\halo reach\\vehicles\\warthog\\rocket warthog",
        ["quad"] = "altis\\vehicles\\mongoose\\mongoose"
    },
    ["liberty_blockfort_quad"] = {
        ["hog1"] = "altis\\vehicles\\mongoose\\mongoose",
        ["hog2"] = "altis\\vehicles\\mortargoose\\mortargoose",
        ["hog3"] = "altis\\vehicles\\mongoose\\elara",
        ["hog4"] = "altis\\vehicles\\mongoose\\empire",
        ["hog5"] = "altis\\vehicles\\mongoose\\icarus",
        ["hog6"] = "altis\\vehicles\\mortargoose\\mortargoose_no_target"
    },
    ["liberty_race_me_now"] = {
        ["hog1"] = "altis\\vehicles\\mongoose\\mongoose",
        ["hog2"] = "altis\\vehicles\\mortargoose\\mortargoose_no_target",
        ["hog3"] = "altis\\vehicles\\mongoose\\elara",
        ["hog4"] = "altis\\vehicles\\mongoose\\empire",
        ["hog5"] = "altis\\vehicles\\mongoose\\icarus"
    },
    ["yoyorast_island"] = {
        ["hog"] = "vehicles\\mongoose\\mongoose"
    }
}
-- CONFIG ENDS ----------------------------------------------------------------

api_version = "1.12.0.0"

local map_name
local height_offset = 0.3
local game_over
local active_vehicles, vehicle_meta_cache, player_cooldowns = {}, {}, {}

local os_time = os.time
local math_floor = math.floor
local os_clock, pairs = os.clock, pairs
local table_insert, table_sort = table.insert, table.sort
local table_concat = table.concat

local rprint, get_var = rprint, get_var
local read_dword, read_vector3d = read_dword, read_vector3d
local lookup_tag, enter_vehicle = lookup_tag, enter_vehicle
local player_present, player_alive = player_present, player_alive
local spawn_object, destroy_object = spawn_object, destroy_object
local get_dynamic_player, get_object_memory = get_dynamic_player, get_object_memory

local sapp_events = {
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_CHAT']] = 'OnChat',
    [cb['EVENT_SPAWN']] = 'OnSpawn',
    [cb['EVENT_GAME_END']] = 'OnEnd',
    [cb['EVENT_COMMAND']] = 'OnCommand'
}

local function fmtMsg(str, ...)
    return select('#', ...) > 0 and str:format(...) or str
end

local function register_callbacks(enable)
    for event, callback in pairs(sapp_events) do
        if enable then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function getVehicle(id)
    if not player_present(id) or not player_alive(id) then return nil end

    local player_obj = get_dynamic_player(id)
    if player_obj == 0 then return nil end

    local vehicle_id = read_dword(player_obj + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    local object_id = get_object_memory(vehicle_id)
    if object_id == 0 then return nil end

    return object_id
end

local function isOccupied(vehicle_object)
    if vehicle_object == 0 then return false end
    for i = 1, 16 do
        if getVehicle(i) == vehicle_object then return true end
    end
    return false
end

local function atan2(y, x)
    return math.atan(y / x) + ((x < 0) and math.pi or 0)
end

local function getPos(id)
    if not player_alive(id) then
        rprint(id, "Must be alive to spawn vehicle!")
        return nil
    end

    if getVehicle(id) then
        rprint(id, "Already in vehicle!")
        return nil
    end

    local player_dyn = get_dynamic_player(id)
    if player_dyn == 0 then return nil end

    local x, y, z = read_vector3d(player_dyn + 0x5C)

    local cam_x = read_float(player_dyn + 0x230)
    local cam_y = read_float(player_dyn + 0x234)
    local yaw = atan2(cam_y, cam_x)

    return x, y, z, yaw
end

local function canSpawnVehicle(id)
    local now = os_time()
    local player_cooldown = player_cooldowns[id]

    if player_cooldown and now < player_cooldown then
        local remaining = math_floor(player_cooldown - now)
        rprint(id, fmtMsg("Wait %ds to spawn another vehicle.", remaining))
        return false
    end

    return true
end

local function showKeyWords(id)
    rprint(id, "== VEHICLE SUMMON PHRASES ==")
    rprint(id, vehicle_meta_cache[map_name].hud)
end

local function mapNamesToLower()
    local custom_tags_lower = {}
    for map, vehicles in pairs(CUSTOM_TAGS) do
        custom_tags_lower[map:lower()] = vehicles
    end
    return custom_tags_lower
end

local function addVehicle(merged_config, hud_strings, keyword, tag_path)
    local meta_id = getTag("vehi", tag_path)
    if meta_id then
        merged_config[keyword] = meta_id
        table_insert(hud_strings, keyword)
        return true
    end
    return false
end

local function buildVehicleConfig(map_name_lower)
    local merged_config = {}
    local hud_strings = {}

    local valid_defaults = {}
    for keyword, tag_path in pairs(DEFAULT_TAGS) do
        if addVehicle(merged_config, hud_strings, keyword, tag_path) then
            valid_defaults[keyword] = true
        end
    end

    local custom_vehicles = CUSTOM_TAGS[map_name_lower]
    if custom_vehicles then
        for keyword, tag_path in pairs(custom_vehicles) do
            if valid_defaults[keyword] then
                local base_keyword = keyword
                local counter = 2
                while merged_config[base_keyword .. counter] do
                    counter = counter + 1
                end
                local new_keyword = base_keyword .. counter
                addVehicle(merged_config, hud_strings, new_keyword, tag_path)
            else
                addVehicle(merged_config, hud_strings, keyword, tag_path)
            end
        end
    end

    table_sort(hud_strings)

    return {
        vehicles = merged_config,
        hud = table_concat(hud_strings, ", ")
    }
end

function OnScriptLoad()
    timer(1000, "DespawnVehicles")

    CUSTOM_TAGS = mapNamesToLower()
    register_callback(cb["EVENT_GAME_START"], "OnStart")

    OnStart() -- in case script is loaded mid-game
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    map_name = get_var(0, "$map"):lower()
    active_vehicles = {}

    if not vehicle_meta_cache[map_name] then
        local config = buildVehicleConfig(map_name)
        if next(config.vehicles) == nil then
            vehicle_meta_cache[map_name] = nil
            register_callbacks(false)
            return
        end
        vehicle_meta_cache[map_name] = config
    end

    register_callbacks(true)
    game_over = false

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnEnd()
    game_over = true
    player_cooldowns = {}
end

function OnChat(id, message)
    local input = message:lower():gsub("^%s*(.-)%s*$", "%1")
    if game_over or input == "hud" then return end

    local map_config = vehicle_meta_cache[map_name].vehicles
    for keyword, meta_id in pairs(map_config) do
        if input == keyword then
            if not canSpawnVehicle(id) then return false end

            local x, y, z, yaw = getPos(id)
            if not x then return false end

            local object_id = spawn_object('', '', x, y, z + height_offset, yaw, meta_id)
            if object_id == 0 then
                rprint(id, "Failed to spawn vehicle.")
                return false
            end

            player_cooldowns[id] = os_time() + COOLDOWN_PERIOD
            active_vehicles[object_id] = { object = object_id, despawn_time = nil }
            enter_vehicle(object_id, id, 0)
            return false
        end
    end

    return true
end

function OnCommand(id, cmd)
    if cmd == HELP_COMMAND then
        showKeyWords(id)
        return false
    end
end

function DespawnVehicles()
    if not game_over then
        local now = os_clock()
        for object_id, data in pairs(active_vehicles) do
            local object = get_object_memory(object_id)

            if object == 0 then
                active_vehicles[object_id] = nil
            elseif not isOccupied(object) then
                if not data.despawn_time then
                    data.despawn_time = now + DESPAWN_DELAY_SECONDS
                elseif now >= data.despawn_time then
                    destroy_object(object_id)
                    active_vehicles[object_id] = nil
                end
            elseif data.despawn_time then
                data.despawn_time = nil
            end
        end
    end
    return true
end

function OnJoin(id)
    player_cooldowns[id] = nil
end

function OnSpawn(id)
    if game_over then return end
    showKeyWords(id)
end

function OnScriptUnload()
    for object_id, _ in pairs(active_vehicles) do
        destroy_object(object_id)
    end
    active_vehicles, vehicle_meta_cache = {}, {}
end
