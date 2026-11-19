--[[
=====================================================================================
SCRIPT NAME:	health_audit.lua
DESCRIPTION:    Logging only.

                Records ping, health/shield and damage events for every player
                so you can compare suspected players against the rest of the lobby.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
			https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG

local LOG_FILE = "health_audit.log" -- written to <cg>\sapp\ (falls back to the working dir)
local CHECK_ALL_PLAYERS = true      -- true: track everyone (WATCH is ignored); false: track only players matching WATCH
local WATCH = {}                    -- only used when CHECK_ALL_PLAYERS is false. Lowercase name substrings, e.g. { "ian", "atom" }
local POST_DAMAGE_DELAY = 100       -- ms to wait before reading health/shield after a hit
local HEALTH_EPSILON = 0.0005       -- ignore float noise when checking for health increases
local BASE_TAG_TABLE = 0x40440000   -- same on PC and CE

-- CONFIG ENDS

local log_handle
local event_counter = 0
local stats, pending = {}, {}
local ignored = {}


local string_format = string.format
local date = os.date
local io_open = io.open
local tostring = tostring
local tonumber = tonumber
local math_min = math.min
local math_abs = math.abs
local pairs = pairs
local ipairs = ipairs

local read_dword = read_dword
local read_string = read_string
local read_float = read_float
local read_bit = read_bit
local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local get_dynamic_player = get_dynamic_player
local cprint = cprint
local timer = timer

local function stamp()
    return date("%Y-%m-%d %H:%M:%S")
end

local function writeLog(line)
    if not log_handle then return end
    log_handle:write(stamp() .. " | " .. line .. "\n")
    log_handle:flush()
end

local function resolveLogDir()
    local hit = sig_scan("68??????008D54245468")
    local ptr = hit ~= 0 and read_dword(hit + 0x1) or nil
    if not ptr or ptr < 0x400000 or ptr > 0x800000 then
        ptr = halo_type == "PC" and 0x635610 or 0x5B9630
    end

    local dir = read_string(ptr)
    if not dir or dir == "" then return nil end
    if dir:sub(-1) ~= "\\" then dir = dir .. "\\" end
    return dir .. "sapp\\"
end

local function isWatched(name)
    name = name:lower()
    for _, w in ipairs(WATCH) do
        if name:find(w, 1, true) then return true end
    end
    return false
end

local function tagName(tag_id)
    local fallback = tostring(tag_id)
    local tag_array = read_dword(BASE_TAG_TABLE)
    if tag_array == 0 then return fallback end

    local entry = tag_array + (tag_id % 0x10000) * 0x20
    local name_ptr = read_dword(entry + 0x10)
    if name_ptr == 0 then return fallback end

    return read_string(name_ptr) or fallback
end

local function pingOf(id)
    return tonumber(get_var(id, "$ping")) or 0
end

local function inVehicle(dyn)
    return read_dword(dyn + 0x11C) ~= 0xFFFFFFFF
end

local function newStats(name, watched)
    return {
        name = name,
        watched = watched,
        ping_sum = 0,
        ping_n = 0,
        ping_min = nil,
        ping_max = 0,
        last_ping = nil,
        jitter_sum = 0,
        hits = 0,
        dmg = 0,
        deaths = 0,
        life_hits = 0,
        life_dmg = 0,
        hits_at_death = 0,
        dmg_at_death = 0,
        last_hp = nil,
        last_invuln = false
    }
end

local function ensureStats(id)
    id = tonumber(id)
    if not id then return nil end
    if stats[id] then return stats[id] end
    if ignored[id] then return nil end

    local name = get_var(id, "$name")
    local watched = false

    ---@diagnostic disable-next-line: unnecessary-if
    if not CHECK_ALL_PLAYERS then
        watched = isWatched(name)
        if not watched then
            ignored[id] = true
            return nil
        end
    end

    stats[id] = newStats(name, watched)
    return stats[id]
end

local function tag(s)
    return s.watched and "*" or " "
end

local function summarize(id)
    local s = stats[id]
    if not s then return end

    local avg_ping = s.ping_n > 0 and s.ping_sum / s.ping_n or 0
    local avg_jitter = s.ping_n > 1 and s.jitter_sum / (s.ping_n - 1) or 0
    local hits_per_death = s.deaths > 0 and s.hits_at_death / s.deaths or 0
    local dmg_per_death = s.deaths > 0 and s.dmg_at_death / s.deaths or 0

    writeLog(
        string_format(
            "SUMMARY%s%s | ping avg=%.0f min=%s max=%d jitter=%.1f | hits_taken=%d dmg_taken=%.1f | deaths=%d hits/death=%.2f dmg/death=%.1f",
            tag(s), s.name, avg_ping, tostring(s.ping_min or 0), s.ping_max, avg_jitter, s.hits, s.dmg, s.deaths,
            hits_per_death, dmg_per_death
        )
    )
end

function OnScriptLoad()
    local dir = resolveLogDir()
    if dir then log_handle = io_open(dir .. LOG_FILE, "a") end
    if not log_handle then log_handle = io_open(LOG_FILE, "a") end
    if not log_handle then cprint("health_audit: could not open log file", 12) end

    ---@diagnostic disable-next-line: unnecessary-if
    if not CHECK_ALL_PLAYERS and #WATCH == 0 then
        cprint("health_audit: CHECK_ALL_PLAYERS is false but WATCH is empty, so no one will be tracked", 14)
    end

    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_ALIVE, "OnAlive")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_DIE, "OnDie")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_GAME_END, "OnEnd")

    OnStart() -- in case the script was loaded mid-game
end

function OnScriptUnload()
    for id in pairs(stats) do
        summarize(id)
    end
    ---@diagnostic disable-next-line: unnecessary-if
    if log_handle then
        log_handle:close()
        log_handle = nil
    end
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    stats, pending, ignored = {}, {}, {}
    writeLog(string_format("GAME_START | map=%s mode=%s", get_var(0, "$map"), get_var(0, "$mode")))
    for i = 1, 16 do
        if player_present(i) then ensureStats(i) end
    end
end

function OnEnd()
    writeLog("GAME_END | per-player summary follows")
    for id in pairs(stats) do
        summarize(id)
    end
end

function OnJoin(id)
    id = tonumber(id)
    if not id then return end

    ignored[id] = nil
    local s = ensureStats(id)
    if not s then return end

    writeLog(string_format("JOIN%s%s | ping=%d", tag(s), s.name, pingOf(id)))
end

function OnLeave(id)
    id = tonumber(id)
    if not id then return end

    summarize(id)
    stats[id] = nil
    ignored[id] = nil
end

function OnSpawn(id)
    local s = ensureStats(id)
    if not s then return end

    s.last_hp = nil
    s.last_invuln = false
    s.life_hits = 0
    s.life_dmg = 0
end

function OnAlive(id)
    local s = ensureStats(id)
    if not s then return end

    local ping = pingOf(id)

    s.ping_sum = s.ping_sum + ping
    s.ping_n = s.ping_n + 1
    s.ping_min = s.ping_min and math_min(s.ping_min, ping) or ping
    if ping > s.ping_max then s.ping_max = ping end
    if s.last_ping then s.jitter_sum = s.jitter_sum + math_abs(ping - s.last_ping) end
    s.last_ping = ping
end

function OnTick()
    for i = 1, 16 do
        local s = player_present(i) and ensureStats(i)
        if s and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if dyn ~= 0 then
                local hp = read_float(dyn--[[@cast -?]] + 0xE0)
                local sh = read_float(dyn--[[@cast -?]] + 0xE4)

                if s.last_hp then
                    if hp > s.last_hp + HEALTH_EPSILON then
                        writeLog(
                            string_format(
                                "HP_INCREASE%s%s | %.3f -> %.3f sh=%.3f ping=%d (health pack?)", tag(s), s.name,
                                s.last_hp, hp, sh, pingOf(i)
                            )
                        )
                    end
                    if hp > 1.0001 then
                        writeLog(string_format("HP_OVER_MAX%s%s | hp=%.3f", tag(s), s.name, hp))
                    end
                end
                s.last_hp = hp

                local invuln = read_bit(dyn--[[@cast -?]] + 0x106, 11) == 1
                if invuln ~= s.last_invuln then
                    writeLog(
                        string_format(
                            "INVULN_%s%s%s | hp=%.3f sh=%.3f", invuln and "ON" or "OFF", tag(s), s.name, hp, sh
                        )
                    )
                    s.last_invuln = invuln
                end
            end
        end
    end
end

function OnDamageApplication(victim_id, causer_id, damage_tag_id, damage, collision_material, backtap)
    victim_id = tonumber(victim_id)
    causer_id = tonumber(causer_id)
    if not victim_id or not player_present(victim_id) then return end

    local dyn = get_dynamic_player(victim_id)
    if dyn == 0 then return end

    local s = ensureStats(victim_id)
    if not s then return end

    local pre_hp = read_float(dyn--[[@cast -?]] + 0xE0)
    local pre_sh = read_float(dyn--[[@cast -?]] + 0xE4)
    local dmg = tonumber(damage) or 0

    s.hits = s.hits + 1
    s.dmg = s.dmg + dmg
    s.life_hits = s.life_hits + 1
    s.life_dmg = s.life_dmg + dmg

    local causer = "world"
    if causer_id and causer_id > 0 and player_present(causer_id) then
        causer = get_var(causer_id, "$name")
    end

    event_counter = event_counter + 1
    pending[event_counter] = { pre_hp = pre_hp, pre_sh = pre_sh }

    writeLog(
        string_format(
            "HIT%s%s <- %s | dmg=%.2f type=%s mat=%s backtap=%s | pre hp=%.3f sh=%.3f | vehicle=%s ping=%d | life_hits=%d",
            tag(s), s.name, causer, dmg, tagName(damage_tag_id), tostring(collision_material), tostring(backtap), pre_hp,
            pre_sh, tostring(inVehicle(dyn)), pingOf(victim_id), s.life_hits
        )
    )

    timer(POST_DAMAGE_DELAY, "LogPostDamage", event_counter, victim_id)
end

function LogPostDamage(event_id, victim_id)
    event_id = tonumber(event_id)
    victim_id = tonumber(victim_id)
    if not event_id or not victim_id then return end

    local pre = pending[event_id]
    pending[event_id] = nil
    if not pre or not player_present(victim_id) or not player_alive(victim_id) then return end

    local dyn = get_dynamic_player(victim_id)
    if dyn == 0 then return end

    local s = ensureStats(victim_id)
    if not s then return end

    local hp = read_float(dyn--[[@cast -?]] + 0xE0)
    local sh = read_float(dyn--[[@cast -?]] + 0xE4)

    writeLog(
        string_format(
            "  AFTER%s%s | hp %.3f -> %.3f (%+.3f) | sh %.3f -> %.3f (%+.3f)", tag(s), s.name, pre.pre_hp, hp,
            hp - pre.pre_hp, pre.pre_sh, sh, sh - pre.pre_sh
        )
    )
end

function OnDie(victim_id, killer_id)
    victim_id = tonumber(victim_id)
    if not victim_id or not stats[victim_id] then return end

    local s = stats[victim_id]
    s.deaths = s.deaths + 1
    s.hits_at_death = s.hits_at_death + s.life_hits
    s.dmg_at_death = s.dmg_at_death + s.life_dmg

    local killer_num = tonumber(killer_id)
    local killer = "unknown"
    if killer_num == -1 then
        killer = "world/fall"
    elseif killer_num == 0 then
        killer = "non-player"
    elseif killer_num and player_present(killer_num) then
        killer = get_var(killer_num, "$name")
    end

    writeLog(
        string_format(
            "DEATH%s%s | hits_this_life=%d dmg_this_life=%.1f ping=%d killer=%s", tag(s), s.name, s.life_hits,
            s.life_dmg, pingOf(victim_id), killer
        )
    )
end
