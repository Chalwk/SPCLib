--[[
=====================================================================================
SCRIPT NAME:    server_info.lua
DESCRIPTION:    Server state API for SAPP. Read almost everything about a running
                server through one dashboard-shaped Lua table with server/game info,
                slot-keyed player state, and map objects.

USAGE:
    1. Require this module from OnScriptLoad(). Its signatures and pointers are
       resolved once while the module is loaded.
       local info
       function OnScriptLoad() info = require("server_info") end

    2. function OnStart() info.onGameStart() end
        Call this from EVENT_GAME_START. It clears the tag name cache so names are
        re-read for the new map.

    3. Call info.getSnapshot() from a timer or callback for the current data.
        Snapshot shape:
        { api = { game, players = { ["1"] = player },
          map_objects = { vehicles = {...} } }, errors = {...} }

    Player entries include name, team { code, name }, color { code, name },
    dynamic_player_id, static_player_id, halo_index, health, shield, speed,
    position, yaw/pitch, stats, four weapon slots, and grenade counts. Unavailable
    fields are JSON null. Game combines server identity with gametype settings.

COPYRIGHT (c) 2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
            https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

local json = require("json")

local ipairs, pairs, pcall = ipairs, pairs, pcall
local tonumber, tostring, type = tonumber, tostring, type
local fmt, t_concat = string.format, table.concat
local m_asin, m_atan = math.asin, math.atan
local m_floor, m_max, m_min, m_sqrt = math.floor, math.max, math.min, math.sqrt
local m_pi = math.pi

local cprint, get_dynamic_player, get_object_memory = cprint, get_dynamic_player, get_object_memory
local get_player, get_var, player_alive, player_present = get_player, get_var, player_alive, player_present
local read_byte, read_dword, read_float = read_byte, read_dword, read_float
local read_string, read_vector3d, read_word = read_string, read_vector3d, read_word
local sig_scan, to_real_index = sig_scan, to_real_index

local M = { SERVER = {}, GAME = {}, PLAYERS = {}, VEHICLES = {}, json = json }
local SERVER, GAME, PLAYERS, VEHICLES = M.SERVER, M.GAME, M.PLAYERS, M.VEHICLES

local TAG_TABLE = 0x40440000 -- same for PC and CE
local NO_OBJECT = 0xFFFFFFFF
local TICKS_PER_SECOND = 30
local WU_PER_TICK_TO_KMH = TICKS_PER_SECOND * 3.048 * 3.6
local OBJECT_TYPE_VEHICLE = 1

local OBJECT_HEADER_SIG = "8B0D????????8B513425FFFF00008D"
local GAMETYPE_BASE_SIG = "B9360000008BF3BF????????"
local TIMELIMIT_SIG = "8B0D????????83C8FF85C97E17"
local SERVER_PORT_SIG = "668B0D??????000BF2C605"
local PROFILE_PATH_SIG = "68??????008D54245468"

local WEAPON_SETS = {
    [0] = "normal",
    [1] = "pistols",
    [4] = "sniper",
    [6] = "rockets",
    [7] = "shotguns",
    [12] = "heavy"
}
local ODDBALL_VARIANTS = { [0] = "normal", [1] = "reverse tag", [2] = "juggernaut" }
local COLOR_NAMES = {
    [0] = "white",
    "black",
    "red",
    "blue",
    "gray",
    "yellow",
    "green",
    "pink",
    "purple",
    "cyan",
    "cobalt",
    "orange",
    "teal",
    "sage",
    "brown",
    "tan",
    "maroon",
    "salmon"
}

---@class ServerInfoMapObjects
---@field vehicles table[]

---@class ServerInfoApi
---@field game        table<string, any>
---@field players     table<string, table<string, any>>
---@field map_objects ServerInfoMapObjects

---@class ServerInfoSnapshot
---@field api    ServerInfoApi
---@field errors table[]

---@type number
local gametype_base, timelimit_address, port_address, object_header_slot
---@type number | nil
local tick_counter_address, map_reset_tick_address
---@type string | nil
local sapp_directory
---@type table<number, string>
local tag_names = {} -- tag index -> full tag path, cleared on game start

local function isInt(n, min, max)
    return type(n) == "number" and n % 1 == 0 and n >= min and (max == nil or n <= max)
end

local function num(value)
    return tonumber(value) or 0
end

local function round(value, decimals)
    local factor = 10 ^ (decimals or 0)
    return m_floor(value * factor + 0.5) / factor
end

local function atan2(y, x)
    if x > 0 then return m_atan(y / x) end
    if x < 0 then return m_atan(y / x) + (y >= 0 and m_pi or -m_pi) end
    if y > 0 then return m_pi / 2 end
    if y < 0 then return -m_pi / 2 end
    return 0
end

---@return number address
local function resolveAddress(signature, offset, pc_fallback, ce_fallback)
    local hit = sig_scan(signature)
    if hit and hit ~= 0 then return read_dword(hit + offset) end
    return halo_type == "PC" and pc_fallback or ce_fallback
end

---@return number | nil address
local function resolveTickCounterAddress()
    local hit = sig_scan("8B2D????????807D0000C644240600")
    if not hit or hit == 0 then return nil end

    local pointer_address = read_dword(hit + 2)
    if not pointer_address or pointer_address == 0 then return nil end

    local pointer = read_dword(pointer_address)
    if not pointer or pointer == 0 then return nil end

    return pointer + 0xC
end

---@return number | nil address
local function resolveMapResetTickAddress()
    local hit = sig_scan("8B510C6A018915????????E8????????83C404")
    if not hit or hit == 0 then return nil end

    local address = read_dword(hit + 7)
    return address ~= 0 and address or nil
end

---@return number address
local function resolveObjectHeaderSlot()
    local hit = sig_scan(OBJECT_HEADER_SIG)
    if hit and hit ~= 0 then return read_dword(hit + 2) end
    return halo_type == "PC" and 0x744C18 or 0x6C69F0
end

---@return string | nil path
local function resolveSappDirectory()
    local hit = sig_scan(PROFILE_PATH_SIG)
    if not hit or hit == 0 then return nil end

    local path_address = read_dword(hit + 1)
    if not path_address or path_address == 0 then return nil end

    local config_path = read_string(path_address)
    if not config_path or config_path == "" then return nil end
    config_path = config_path:gsub("%s+$", ""):gsub("[\\/]+$", "")
    return config_path .. "\\sapp\\"
end

gametype_base = resolveAddress(GAMETYPE_BASE_SIG, 8, 0x671320, 0x5F5478)
timelimit_address = resolveAddress(TIMELIMIT_SIG, 2, 0x626630, 0x5AA5B0)
port_address = resolveAddress(SERVER_PORT_SIG, 3, 0x625230, 0x5A91A0)
tick_counter_address = resolveTickCounterAddress()
map_reset_tick_address = resolveMapResetTickAddress()
object_header_slot = resolveObjectHeaderSlot()
sapp_directory = resolveSappDirectory()
M.getConfigPath = function () return sapp_directory end

-- Match SAPP's game countdown: the map reset tick is the elapsed-time origin.
local function getElapsedTicks()
    if tick_counter_address and map_reset_tick_address then
        local elapsed = read_dword(tick_counter_address) - read_dword(map_reset_tick_address)
        if elapsed < 0 then elapsed = elapsed + 0x100000000 end
        return elapsed
    end

    -- Keep elapsed time available if a build does not match either signature.
    return num(get_var(0, "$ticks")) -- just in case
end

---@param object number Object memory address.
---@return string | nil tag_path
local function getTagPath(object)
    local tag_index = read_word(object)
    local cached = tag_names[tag_index]
    if cached ~= nil then return cached end

    local tag_array = read_dword(TAG_TABLE)
    if not tag_array or tag_array == 0 then return nil end

    local name_ptr = read_dword(tag_array + tag_index * 0x20 + 0x10)
    if not name_ptr or name_ptr == 0 then return nil end

    local path = read_string(name_ptr)
    tag_names[tag_index] = path
    return path
end

-- shortName("weapons\\assault rifle\\assault rifle") -> "assault rifle"
local function shortName(tag_path)
    if not tag_path then return "unknown" end
    return tag_path:match(".*\\([^\\]+)$") or tag_path
end

-- Seat 0 is always the driver. Warthog style vehicles seat a passenger at 1 and a
-- gunner at 2. Anything else (tank passengers, for example) is a passenger.
local function seatName(seat, tag_path)
    if seat == 0 then return "driver" end
    if seat == 2 and tag_path and tag_path:find("hog", 1, true) then return "gunner" end
    return "passenger"
end

---@return number | nil header
local function getObjectTable()
    if not object_header_slot or object_header_slot == 0 then return nil end
    local header = read_dword(object_header_slot)
    if not header or header == 0 then return nil end
    return header
end

--- Calls fn(object_id, object_address) for every live object.
local function forEachObject(fn)
    local header = getObjectTable()
    if not header then return end

    local count = read_word(header + 0x2E)
    local first = read_dword(header + 0x34)
    if not count or count > 4096 or not first or first == 0 then return end

    for i = 0, count - 1 do
        local object_id = read_word(first + i * 0xC) * 0x10000 + i
        local object = get_object_memory(object_id)
        if object ~= 0 then fn(object_id, object) end
    end
end

--- Maps vehicle object id -> list of occupants, built from each player's own vehicle id.
local function mapOccupants()
    local map = {}
    for p = 1, 16 do
        if player_present(p) and player_alive(p) then
            local dyn = get_dynamic_player(p)
            if dyn ~= 0 then
                local vehicle_id = read_dword(dyn--[[@cast -?]] + 0x11C)
                if vehicle_id ~= NO_OBJECT then
                    local vehicle = get_object_memory(vehicle_id)
                    local seat = read_word(dyn--[[@cast -?]] + 0x2F0)
                    local list = map[vehicle_id] or {}
                    list[#list + 1] = {
                        player_id = p,
                        name = get_var(p, "$name"),
                        seat = seat,
                        seat_name = seatName(seat, vehicle ~= 0 and getTagPath(vehicle) or nil)
                    }
                    map[vehicle_id] = list
                end
            end
        end
    end
    return map
end

function M.onGameStart()
    tag_names = {}
end

-- SERVER:

---@return table info { name, map, port, player_count }
function SERVER.getInfo()
    local port_ptr = port_address
    return {
        name = get_var(0, "$svname"),
        map = get_var(0, "$map"),
        port = port_ptr and port_ptr ~= 0 and read_word(port_ptr) or nil,
        player_count = num(get_var(0, "$pn"))
    }
end

-- GAME:

--- Gametype settings, time and scores. Returns nil when no game is running.
---@return table | nil info
function GAME.getInfo()
    local gametype = get_var(0, "$gt")
    if gametype == "n/a" then return nil end

    ---@type number
    local base = gametype_base
    local limit_ptr = timelimit_address

    -- The limit is in ticks. Zero, or a negative value read back unsigned, means no limit.
    local limit_ticks = limit_ptr and limit_ptr ~= 0 and read_dword(limit_ptr) or 0
    if limit_ticks > 0x7FFFFFFF then limit_ticks = 0 end

    local elapsed_ticks = getElapsedTicks()
    local elapsed = elapsed_ticks / TICKS_PER_SECOND
    local limit = limit_ticks / TICKS_PER_SECOND

    local info = {
        gametype = gametype,
        variant = get_var(0, "$mode"),
        ffa = get_var(0, "$ffa") == "1",
        running = get_var(0, "$running") == "1",
        elapsed_seconds = round(elapsed, 1),
        time_limit_seconds = limit,
        scores = { red = num(get_var(0, "$redscore")), blue = num(get_var(0, "$bluescore")) }
    }

    if base ~= 0 then
        local settings = {
            team_play = read_byte(base + 0x34) == 1,
            rules_flags = read_dword(base + 0x38),
            indicator_mode = read_byte(base + 0x3C),
            respawn_growth_seconds = read_dword(base + 0x44) / TICKS_PER_SECOND,
            respawn_seconds = read_dword(base + 0x48) / TICKS_PER_SECOND,
            suicide_penalty_seconds = read_dword(base + 0x4C) / TICKS_PER_SECOND,
            lives = read_byte(base + 0x50), -- 0 = unlimited
            max_health = round(read_float(base + 0x54), 2),
            score_limit = read_byte(base + 0x58),
            weapon_set = WEAPON_SETS[read_byte(base + 0x5C)] or "unknown",
            vehicle_respawn_seconds = read_dword(base + 0x68) / TICKS_PER_SECOND,
            friendly_fire = read_byte(base + 0x6C) == 1,
            friendly_fire_penalty_seconds = read_dword(base + 0x70) / TICKS_PER_SECOND,
            auto_team_balance = read_byte(base + 0x74) == 1
        }
        if gametype == "oddball" then
            settings.oddball_variant = ODDBALL_VARIANTS[read_byte(base + 0x8C)] or "unknown"
        elseif gametype == "king" then
            settings.moving_hill = read_byte(base + 0x9C) == 1
        end
        info.settings = settings
    end

    return info
end

-- PLAYERS:

local WEAPON_FIELDS = { "primary_weapon", "secondary_weapon", "tertiary_weapon", "quaternary_weapon" }

local function readWeapons(dyn)
    local weapons = {}
    for _, field in ipairs(WEAPON_FIELDS) do
        weapons[field] = json.null
    end

    for slot = 0, 3 do
        local weapon_id = read_dword(dyn + 0x2F8 + slot * 4)
        if weapon_id ~= NO_OBJECT then
            local weapon = get_object_memory(weapon_id)
            if weapon ~= 0 then
                weapons[WEAPON_FIELDS[slot + 1]] = {
                    tag = getTagPath(weapon) or "unknown",
                    object_id = weapon_id,
                    ammo_clip = read_word(weapon + 0x2B8),
                    ammo_reserve = read_word(weapon + 0x2B6)
                }
            end
        end
    end
    return weapons
end

---@param p number
---@return table | nil player
local function buildPlayer(p)
    local static = get_player(p)
    if not static or static == 0 then return nil end

    local color_code = read_byte(static + 0x60)
    local team_name = get_var(p, "$team")
    local team_code = team_name == "red" and 0 or team_name == "blue" and 1 or nil
    local team = team_code ~= nil and { code = team_code, name = team_name } or json.null
    local alive = player_alive(p)
    local dyn = alive and get_dynamic_player(p) or 0
    if not dyn or dyn == 0 then alive = false end

    ---@type table<string, any>
    local info = {
        name = get_var(p, "$name"),
        team = team,
        color = { code = color_code, name = COLOR_NAMES[color_code] or "unknown" },
        dynamic_player_id = alive and dyn or json.null,
        static_player_id = static,
        halo_index = to_real_index(p),
        health = json.null,
        shield = json.null,
        speed_kmh = json.null,
        x = json.null,
        y = json.null,
        z = json.null,
        yaw = json.null,
        pitch = json.null,
        is_alive = alive,
        kills = num(get_var(p, "$kills")),
        deaths = num(get_var(p, "$deaths")),
        assists = num(get_var(p, "$assists")),
        score = num(get_var(p, "$score")),
        primary_weapon = json.null,
        secondary_weapon = json.null,
        tertiary_weapon = json.null,
        quaternary_weapon = json.null,
        grenades = { frag = json.null, plasma = json.null }
    }

    if not alive then return info end

    info.health = round(read_float(dyn--[[@cast -?]] + 0xE0), 3)
    info.shield = round(read_float(dyn--[[@cast -?]] + 0xE4), 3)
    info.grenades = { frag = read_byte(dyn--[[@cast -?]] + 0x31E), plasma = read_byte(dyn--[[@cast -?]] + 0x31F) }
    local weapons = readWeapons(dyn)
    for _, field in ipairs(WEAPON_FIELDS) do
        info[field] = weapons[field]
    end

    local object = dyn
    local vehicle_id = read_dword(dyn--[[@cast -?]] + 0x11C)
    if vehicle_id ~= NO_OBJECT then
        local vehicle = get_object_memory(vehicle_id)
        if vehicle ~= 0 then object = vehicle end
    end

    info.x, info.y, info.z = read_vector3d(object--[[@cast -?]] + 0x5C)
    local vx, vy, vz = read_vector3d(object--[[@cast -?]] + 0x68)
    info.speed_kmh = round(m_sqrt(vx * vx + vy * vy + vz * vz) * WU_PER_TICK_TO_KMH, 1)

    local fx, fy, fz = read_vector3d(object--[[@cast -?]] + 0x74)
    info.yaw = round(atan2(fy, fx), 3)
    info.pitch = round(m_asin(m_max(-1, m_min(1, fz))), 3)
    return info
end

---@param player_id number
---@return table | nil player
function PLAYERS.getPlayer(player_id)
    if not isInt(player_id, 1, 16) or not player_present(player_id) then return nil end
    return buildPlayer(player_id)
end

--- Every connected player
---@return table<number, table> players
function PLAYERS.getAll()
    local players = {}
    for p = 1, 16 do
        if player_present(p) then
            local player = buildPlayer(p)
            if player then players[tostring(p)] = player end
        end
    end
    return players
end

--- First connected player whose name contains `partial` (case-insensitive).
---@param partial string
---@return table | nil player
function PLAYERS.findByName(partial)
    if type(partial) ~= "string" or partial == "" then return nil end
    partial = partial:lower()
    for p = 1, 16 do
        if player_present(p) and get_var(p, "$name"):lower():find(partial, 1, true) then
            return buildPlayer(p)
        end
    end
    return nil
end

-- VEHICLES:

local function describeVehicle(object_id, object, occupants)
    local path = getTagPath(object)
    local x, y, z = read_vector3d(object + 0x5C)
    local vx, vy, vz = read_vector3d(object + 0x68)
    local list = occupants[object_id] or {}
    return {
        object_id = object_id,
        name = shortName(path),
        tag = path,
        x = x,
        y = y,
        z = z,
        speed_kmh = round(m_sqrt(vx * vx + vy * vy + vz * vz) * WU_PER_TICK_TO_KMH, 1),
        health = round(read_float(object + 0xE0), 3),
        occupied = #list > 0,
        occupants = list
    }
end

--- Every vehicle object currently in the game.
---@return table[] vehicles
function VEHICLES.getAll()
    local vehicles = {}
    if get_var(0, "$gt") == "n/a" then return vehicles end

    local occupants = mapOccupants()
    forEachObject(function (object_id, object)
        if read_byte(object + 0xB4) == OBJECT_TYPE_VEHICLE then
            vehicles[#vehicles + 1] = describeVehicle(object_id, object, occupants)
        end
    end)
    return vehicles
end

--- Only the vehicles that have at least one player in them.
---@return table[] vehicles
function VEHICLES.getOccupied()
    local occupied = {}
    for _, vehicle in ipairs(VEHICLES.getAll()) do
        if vehicle.occupied then occupied[#occupied + 1] = vehicle end
    end
    return occupied
end

--- The vehicle a player is currently in, or nil.
---@param player_id number
---@return table | nil vehicle
function VEHICLES.getByPlayer(player_id)
    for _, vehicle in ipairs(VEHICLES.getOccupied()) do
        for _, occupant in ipairs(vehicle.occupants) do
            if occupant.player_id == player_id then return vehicle end
        end
    end
    return nil
end

-- SNAPSHOT:

---@param errors   table
---@param endpoint string
---@param callback function
---@return any result
local function capture(errors, endpoint, callback)
    local ok, result = pcall(callback)
    if not ok then
        errors[#errors + 1] = { endpoint = endpoint, message = tostring(result) }
        return json.null
    end
    return result == nil and json.null or result
end

--- Returns the dashboard schema: combined game/server info, slot keyed players, and map objects.
---@return ServerInfoSnapshot snapshot
function M.getSnapshot()
    ---@type table[]
    local errors = json.array()
    ---@type ServerInfoApi
    local api = json.object()
    ---@type table<string, any>
    api.game = json.object()

    local server = capture(errors, "SERVER.getInfo", SERVER.getInfo)
    if type(server) == "table" then
        for key, value in pairs(server) do
            api.game[key] = value
        end
    end

    local game = capture(errors, "GAME.getInfo", GAME.getInfo)
    if type(game) == "table" then
        for key, value in pairs(game) do
            api.game[key] = value
        end
    end

    ---@type table<string, table<string, any>>
    api.players = json.object()
    for player_id = 1, 16 do
        local player = capture(errors, "PLAYERS.getPlayer(" .. player_id .. ")", function ()
            return PLAYERS.getPlayer(player_id)
        end)
        if player ~= json.null then api.players[tostring(player_id)] = player end
    end

    local vehicles = capture(errors, "VEHICLES.getAll", VEHICLES.getAll)
    if vehicles == json.null then
        vehicles = json.array()
    else
        json.array(vehicles)
    end
    api.map_objects = json.object({ vehicles = vehicles })

    ---@type ServerInfoSnapshot
    local snapshot = { api = api, errors = errors }
    json.object(snapshot)
    return snapshot
end

-- JSON:

--- Encodes JSON values through the json.lua library.
---@param value any
---@param opts? table Encoder options accepted by json.encode.
---@return string json
function M.toJson(value, opts)
    local encoded, err = json.encode(value, opts)
    if not encoded then error(err or "JSON encoding failed", 2) end
    return encoded
end

-- DUMP:

local function clock(seconds)
    seconds = m_floor(seconds or 0)
    return fmt("%02d:%02d", m_floor(seconds / 60), seconds % 60)
end

--- Prints a readable summary of the snapshot to the console.
function M.dump()
    ---@type ServerInfoSnapshot
    local snap = M.getSnapshot()
    ---@type ServerInfoApi
    local api = snap.api
    local g = api.game

    cprint(fmt("== %s | %s | %s players ==", g.name, g.map, g.player_count), 11)
    if not g.gametype then
        cprint("No game running.", 14)
        return
    end

    local remaining = g.time_limit_seconds > 0 and m_max(0, g.time_limit_seconds - g.elapsed_seconds) or nil
    local timing = remaining and (clock(remaining) .. " left") or "no time limit"
    cprint(
        fmt(
            "%s (%s) | %s elapsed, %s | red %s - blue %s", g.variant, g.gametype, clock(g.elapsed_seconds), timing,
            g.scores.red, g.scores.blue
        ), 10
    )

    for player_id, p in pairs(api.players) do
        cprint(
            fmt(
                "[%s] %s | %s | K %d D %d A %d", player_id, p.name, p.is_alive and "alive" or "dead", p.kills, p.deaths,
                p.assists
            ), 15
        )
    end

    for _, v in ipairs(api.map_objects.vehicles) do
        local names = {}
        for _, o in ipairs(v.occupants) do
            names[#names + 1] = o.name .. " (" .. o.seat_name .. ")"
        end
        cprint(fmt("vehicle %s | %s", v.name, #names > 0 and t_concat(names, ", ") or "empty"), 14)
    end
end

return M
