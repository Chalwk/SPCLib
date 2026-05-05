--[[
================================================================================
SCRIPT NAME:    item_spawner.lua
DESCRIPTION:    Item spawning system for weapons, vehicles, and equipment
                  - Spawn weapons, vehicles, equipment, bipeds, and projectiles
                  - Enter vehicles with seat selection
                  - Object caching and cleanup system
                  - Paginated item listing

COMMANDS:
/clean [type]                  - Destroy cached objects of given type
/enter <alias> [seat] [amount] - Enter vehicle with seat selection
/give <alias> [amount]         - Give weapon/equipment
/itemlist [page]               - List available items
/spawn <alias> [amount]        - Spawn object at position

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
================================================================================
]] --

-- CONFIGURATION START ---------------------------------------------------------

local ADMIN_LEVEL = 4
local ITEM_QUANTITY = 1
local MAX_OBJECTS = 200
local DISTANCE_FROM_PLAYER = 2.5
local MAX_RESULTS_PER_PAGE = 25
local MAX_ITEMS_PER_ROW = 4
local DESTROY_ON_QUIT = true
local COMMANDS = {
    clean = true,
    enter = true,
    give = true,
    itemlist = true,
    spawn = true
}

local ITEMS = {
    bipd = {
        { "characters\\cyborg_mp\\cyborg_mp", "Cyborg", { "cyborg" } }
    },

    eqip = {
        { "powerups\\full-spectrum vision",          "Vision Spectrum Cube", { "vscube" } },
        { "powerups\\health pack",                   "Health Pack",          { "health", "hp" } },
        { "powerups\\active camouflage",             "Camouflage",           { "camo", "camouflage" } },
        { "powerups\\over shield",                   "Over Shield",          { "overshield", "os", "sh" } },
        { "weapons\\frag grenade\\frag grenade",     "Frag Grenade",         { "frag", "grenade", "fraggrenade" } },
        { "weapons\\plasma grenade\\plasma grenade", "Plasma Grenade",       { "plasma", "plasmagrenade" } }
    },

    vehi = {
        { "vehicles\\ghost\\ghost_mp",               "Ghost",   { "ghost" },                 1 },
        { "vehicles\\rwarthog\\rwarthog",            "R-Hog",   { "rhog" },                  3 },
        { "vehicles\\banshee\\banshee_mp",           "Banshee", { "banshee", "banshee_mp" }, 1 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret",  { "turret" },                1 },
        { "vehicles\\warthog\\mp_warthog",           "Warthog", { "hog", "warthog" },        3 },
        { "vehicles\\scorpion\\scorpion_mp",         "Tank",    { "tank", "scorpion" },      5 }
    },

    weap = {
        { "weapons\\gravity rifle\\gravity rifle",     "Gravity Gun",     { "gravitygun" } },
        { "weapons\\flag\\flag",                       "Flag",            { "flag" } },
        { "weapons\\ball\\ball",                       "Skull",           { "skull" } },
        { "weapons\\pistol\\pistol",                   "Pistol",          { "pistol" } },
        { "weapons\\shotgun\\shotgun",                 "Shotgun",         { "shotgun" } },
        { "weapons\\needler\\mp_needler",              "Needler",         { "needler" } },
        { "weapons\\plasma rifle\\plasma rifle",       "Plasma Rifle",    { "prifle", "plasmarifle" } },
        { "weapons\\flamethrower\\flamethrower",       "Flamethrower",    { "flame", "flamethrower" } },
        { "weapons\\plasma_cannon\\plasma_cannon",     "Plasma Cannon",   { "pcannon", "plasmacannon" } },
        { "weapons\\plasma pistol\\plasma pistol",     "Plasma Pistol",   { "ppistol", "plasmapistol" } },
        { "weapons\\assault rifle\\assault rifle",     "Assault Rifle",   { "arifle", "assaultrifle" } },
        { "weapons\\sniper rifle\\sniper rifle",       "Sniper Rifle",    { "sniper", "sniperrifle" } },
        { "weapons\\rocket launcher\\rocket launcher", "Rocket Launcher", { "rocketl", "rocketlauncher" } }
    },

    proj = {
        { "weapons\\flamethrower\\flame",           "Flames",                    { "flames", "flameproj" } },
        { "weapons\\needler\\mp_needle",            "Needler Needle",            { "needle", "needlerproj" } },
        { "weapons\\rocket launcher\\rocket",       "Rocket",                    { "rocket", "rocketproj" } },
        { "weapons\\pistol\\bullet",                "Pistol Bullet",             { "pistolbullet", "pistolproj" } },
        { "weapons\\plasma pistol\\bolt",           "Plasma Pistol Bolt",        { "ppistolproj" } },
        { "weapons\\sniper rifle\\sniper bullet",   "Sniper Bullet",             { "sniperproj" } },
        { "weapons\\plasma rifle\\bolt",            "Plasma Rifle Bolt",         { "plasmariflebolt" } },
        { "weapons\\assault rifle\\bullet",         "Assault Rifle Bullet",      { "ariflebullet" } },
        { "weapons\\plasma rifle\\charged bolt",    "Plasma Rifle Charged Bolt", { "priflecharged" } },
        { "weapons\\shotgun\\pellet",               "Shotgun Pellet",            { "shotgunproj" } },
        { "weapons\\plasma_cannon\\plasma_cannon",  "Plasma Cannon Shot",        { "fuelrodproj" } },
        { "vehicles\\warthog\\bullet",              "Warthog Bullet",            { "warthogbullet", "warthogproj" } },
        { "vehicles\\scorpion\\bullet",             "Tank Bullet",               { "tankbullet", "tankbulletproj" } },
        { "vehicles\\c gun turret\\mp gun turret",  "Turret Bolt",               { "turretbolt", "turretproj" } },
        { "vehicles\\ghost\\ghost bolt",            "Ghost Bolt",                { "ghostbolt", "ghostproj" } },
        { "vehicles\\scorpion\\tank shell",         "Tank Shell",                { "tankshell", "tankshellproj" } },
        { "vehicles\\banshee\\mp_banshee fuel rod", "Banshee Fuel Rod",          { "bansheerod" } },
        { "vehicles\\banshee\\banshee bolt",        "Banshee Bolt",              { "sheebolt" } }
    }
}
-- CONFIGURATION END -----------------------------------------------------------

api_version = '1.12.0.0'

local get_var, player_present, player_alive = get_var, player_present, player_alive
local rprint, cprint = rprint, cprint
local get_dynamic_player, get_object_memory = get_dynamic_player, get_object_memory
local lookup_tag, read_dword, spawn_object = lookup_tag, read_dword, spawn_object
local assign_weapon, destroy_object, enter_vehicle = assign_weapon, destroy_object, enter_vehicle
local read_float, read_vector3d = read_float, read_vector3d
local powerup_interact = powerup_interact

local pairs = pairs
local t_remove, t_concat, t_sort = table.remove, table.concat, table.sort
local tonumber = tonumber

local atan, ceil, max, min, pi = math.atan, math.ceil, math.max, math.min, math.pi
local find, lower = string.find, string.lower

local players = {}
local catalog = { items = {}, aliases = {} }

local OBJECT_TYPES = {
    vehi = { name = "vehi", display = "Vehicles" },
    weap = { name = "weap", display = "Weapons" },
    eqip = { name = "eqip", display = "Equipment" },
    bipd = { name = "bipd", display = "Bipeds" },
    proj = { name = "proj", display = "Projectiles" },
    all = { name = "all", display = "Everything" }
}

local SEAT_MAP = { ["-"] = 0, ["*"] = 1, ["^"] = 2 }
local ITEM_FLAGS = {
    vehi = { is_vehicle = true },
    weap = { is_weapon = true },
    eqip = { is_equipment = true }
}

local function respond(id)
    return id == 0 and cprint or function(msg) rprint(id, msg) end
end

local function atan2(y, x)
    return atan(y / x) + (x < 0 and pi or 0)
end

local function create_player(id)
    local player = {
        id = id,
        name = get_var(id, '$name'),
        cached_objects = {},
        object_count = 0
    }
    players[id] = player
    return player
end

local function destroy_oldest_object(player)
    local objects = player.cached_objects
    if objects[1] then
        destroy_object(t_remove(objects, 1))
        player.object_count = player.object_count - 1
        return true
    end
end

local function cache_object(player, object_id)
    if player.object_count >= MAX_OBJECTS then
        destroy_oldest_object(player)
    end
    local objects = player.cached_objects
    objects[#objects + 1] = object_id
    player.object_count = player.object_count + 1
    return true
end

local function clean_objects(player)
    local objects = player.cached_objects
    local cleaned = #objects
    for i = 1, cleaned do
        destroy_object(objects[i])
    end
    player.cached_objects = {}
    player.object_count = 0
    return cleaned
end

local function get_tag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function initialize_catalog()
    local items, aliases = catalog.items, catalog.aliases
    for tag_class, entries in pairs(ITEMS) do
        local flags = ITEM_FLAGS[tag_class] or false
        for i = 1, #entries do
            local data = entries[i]
            local tag_path, display_name, item_aliases, seats = data[1], data[2], data[3], data[4]
            local tag_id = get_tag(tag_class, tag_path)

            if tag_id then
                local item = {
                    tag_id = tag_id,
                    display_name = display_name,
                    aliases = item_aliases or {},
                    seats = seats or 1,
                    is_vehicle = flags and flags.is_vehicle or false,
                    is_weapon = flags and flags.is_weapon or false,
                    is_equipment = flags and flags.is_equipment or false
                }

                items[#items + 1] = item
                aliases[#aliases + 1] = { name = lower(display_name), item = item }
                if item_aliases then
                    for j = 1, #item_aliases do
                        aliases[#aliases + 1] = { name = lower(item_aliases[j]), item = item }
                    end
                end
            else
                cprint("Warning: Could not find tag " .. tag_class .. ", " .. tag_path, 12)
            end
        end
    end

    cprint("ItemSpawner: Loaded " .. #items .. " items with " .. #aliases .. " aliases", 6)
end

local function find_item(search_term)
    search_term = lower(search_term)
    for i = 1, #catalog.aliases do
        local alias = catalog.aliases[i]
        if alias.name == search_term then
            return alias.item
        end
    end

    -- Partial match
    for i = 1, #catalog.aliases do
        local alias = catalog.aliases[i]
        if find(alias.name, search_term, 1, true) then
            return alias.item
        end
    end
end

local function hasPermission(id)
    return id == 0 or (tonumber(get_var(id, '$lvl')) or 0) >= ADMIN_LEVEL
end

local function parse_seat_option(seat_str, max_seats)
    local seat = SEAT_MAP[seat_str]
    if seat then
        return seat < max_seats and seat or 0
    end

    seat = tonumber(seat_str)
    return seat and seat >= 0 and seat < max_seats and seat or 0
end

local function getCam(dyn)
    return read_float(dyn + 0x230), read_float(dyn + 0x234), read_float(dyn + 0x238)
end

local function get_position(id)
    local dyn = get_dynamic_player(id)
    if dyn == 0 then return end

    local vehicle_id = read_dword(dyn + 0x11C)
    local object = vehicle_id == 0xFFFFFFFF and dyn or get_object_memory(vehicle_id)
    if object == 0 then return end

    local x, y, z = read_vector3d(object + 0x5C)
    local cam_x, cam_y, cam_z = getCam(dyn)
    local d = DISTANCE_FROM_PLAYER

    return x + d * cam_x, y + d * cam_y, z + d * cam_z, atan2(cam_y, cam_x)
end

local function spawn_item(id, item, options)
    local player = players[id]
    if not player then return {} end

    local spawned, quantity = {}, options.amount or ITEM_QUANTITY
    local enter, seat = options.enter, options.seat

    for _ = 1, quantity do
        local x, y, z, yaw = get_position(id)
        if not x then break end

        local object_id = spawn_object('', '', x, y, z, yaw, item.tag_id)
        if object_id then
            cache_object(player, object_id)
            spawned[#spawned + 1] = object_id

            if item.is_vehicle and enter then
                enter_vehicle(object_id, id, parse_seat_option(seat, item.seats))
            elseif item.is_weapon then
                assign_weapon(object_id, id)
            elseif item.is_equipment then
                local dyn = get_dynamic_player(id)
                if dyn ~= 0 and read_dword(dyn + 0x11C) == 0xFFFFFFFF then
                    powerup_interact(object_id, id)
                end
            end
        end
    end

    return spawned
end

local function remove_player(id)
    local player = players[id]
    if player and DESTROY_ON_QUIT then
        clean_objects(player)
    end
    players[id] = nil
end

local function parse_options(args, start_index)
    local options = { amount = ITEM_QUANTITY }
    for i = start_index, #args do
        local arg = args[i]
        local num = tonumber(arg)
        if num then
            options.amount = num
        elseif SEAT_MAP[arg] ~= nil then
            options.seat = arg
        end
    end
    return options
end

local function handle_clean_command(id, args, tell)
    local type_str = args[2] or 'all'
    if not OBJECT_TYPES[type_str] then
        return tell('Invalid object type. Use: vehi, weap, eqip, bipd, proj, or all')
    end
    tell('Cleaned ' .. clean_objects(players[id]) .. ' objects')
end

local function handle_enter_command(id, args, tell)
    local vehicle_name = args[2]
    if not vehicle_name then
        return tell('Usage: /enter <vehicle> [seat] [amount]')
    end

    local vehicle_item = find_item(vehicle_name)
    if not vehicle_item or not vehicle_item.is_vehicle then
        return tell('Vehicle not found: ' .. vehicle_name)
    end

    if not player_alive(id) then
        return tell('You must be alive to enter a vehicle')
    end

    local options = parse_options(args, 3)
    options.enter = true
    tell('Entered ' .. #spawn_item(id, vehicle_item, options) .. ' ' .. vehicle_item.display_name .. '(s)')
end

local function handle_give_command(id, args, tell)
    local item_name = args[2]
    if not item_name then
        return tell('Usage: /give <item> [amount]')
    end

    local item = find_item(item_name)
    if not item then
        return tell('Item not found: ' .. item_name)
    end
    if not item.is_weapon and not item.is_equipment then
        return tell('Cannot give ' .. item.display_name .. '. Use /spawn instead.')
    end

    tell('Gave ' .. #spawn_item(id, item, parse_options(args, 3)) .. ' ' .. item.display_name .. '(s)')
end

local function format_items_page(items, page, total_pages)
    local result, row = {}, {}
    local start_index = (page - 1) * MAX_RESULTS_PER_PAGE + 1
    local end_index = min(start_index + MAX_RESULTS_PER_PAGE - 1, #items)

    result[1] = 'Page ' .. page .. '/' .. total_pages .. ' - Showing ' .. (end_index - start_index + 1) .. ' items'

    local n = 1
    for i = start_index, end_index do
        local item = items[i]
        row[#row + 1] = item.is_vehicle and (item.display_name .. ' (' .. item.seats .. ' seats)') or item.display_name
        if #row == MAX_ITEMS_PER_ROW then
            n = n + 1
            result[n] = t_concat(row, ', ')
            row = {}
        end
    end

    if row[1] then
        result[#result + 1] = t_concat(row, ', ')
    end

    return result
end

local function sort(items)
    t_sort(items, function(a, b) return a.display_name < b.display_name end)
    return items
end

local function handle_itemlist_command(_, args, tell)
    local items = catalog.items
    if not items[1] then
        return tell('No items found')
    end

    sort(items)

    local total_pages = ceil(#items / MAX_RESULTS_PER_PAGE)
    local page = max(1, min(tonumber(args[2]) or 1, total_pages))

    tell('=== Available Items (' .. #items .. ' items) ===')
    local lines = format_items_page(items, page, total_pages)
    for i = 1, #lines do
        tell(lines[i])
    end

    if total_pages > 1 and page < total_pages then
        tell("Use '/itemlist " .. (page + 1) .. "' for next page")
    end
end

local function handle_spawn_command(id, args, tell)
    local item_name = args[2]
    if not item_name then
        return tell('Usage: /spawn <item> [amount]')
    end

    local item = find_item(item_name)
    if not item then
        return tell('Item not found: ' .. item_name)
    end

    if not players[id] then
        return tell('Player data not initialized')
    end

    tell('Spawned ' .. #spawn_item(id, item, parse_options(args, 3)) .. ' ' .. item.display_name .. '(s)')
end

local function parse_command_args(command)
    local args, n = {}, 0
    for arg in command:gmatch('%S+') do
        n = n + 1
        args[n] = arg
    end
    return args
end

local handlers = {
    clean = handle_clean_command,
    enter = handle_enter_command,
    give = handle_give_command,
    itemlist = handle_itemlist_command,
    spawn = handle_spawn_command
}

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart() -- in case script is loaded mid-game
end

function OnCommand(id, Command)
    local args = parse_command_args(Command)
    local cmd = args[1] and lower(args[1])
    if not cmd or not COMMANDS[cmd] then return true end

    local tell = respond(id)
    if not hasPermission(id) then
        tell('Insufficient permissions')
        return false
    end

    if cmd ~= 'itemlist' and cmd ~= 'clean' and not player_alive(id) then
        tell('You need to be alive to use this command')
        return false
    end

    handlers[cmd](id, args, tell)
    return false
end

function OnJoin(id) create_player(id) end

function OnQuit(id) remove_player(id) end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    catalog.items, catalog.aliases = {}, {}
    initialize_catalog()

    for i = 1, 16 do
        if player_present(i) then
            create_player(i)
        end
    end
end

function OnScriptUnload()
    for i = 1, 16 do
        if player_present(i) then
            remove_player(i)
        end
    end
end
