--[[
=====================================================================================
SCRIPT NAME:    netgame_flags.lua
DESCRIPTION:    Netgame objective API for SAPP: CTF flags, KOTH hills, Oddball and
                Race checkpoints. Spawn data is read from the scenario tag, so it is
                available on any gametype. Live state is read from the game's own
                globals and is only meaningful while the matching gametype runs.

USAGE:
    1. local netgame = require("netgame_flags")

    2. function OnStart() netgame.onGameStart() end
        Call this from EVENT_GAME_START. It reloads the scenario data and captures the
        starting KOTH hill (needed by KOTH.resetHill).

    3. Spawn and checkpoint data (getSpawn, getHill(index), getRaceCheckpoints, the oddball
        spawns) is read from the scenario and works on any gametype. Live state (getFlag,
        the live oddballs, the current hill, race progress) only exists while the matching
        gametype is running; outside it, getters return nil and resets return false.
        Resets that move an object are applied a moment later if a player was carrying it.

    - netgame.CTF.getFlag(team)
    - netgame.CTF.getSpawn(team)
    - netgame.CTF.resetFlag([team])
        team is 0 (red) or 1 (blue). getFlag returns a table: x, y, z, object_id, carried,
        carrier, carrier_name, at_spawn. getSpawn returns the flag's starting x, y, z.
        resetFlag forces any carrier to drop the flag, then returns it to its base.
        With no team, both flags are reset.

    - netgame.ODDBALL.getOddball([index])
    - netgame.ODDBALL.reset([index])
        A map can have several oddballs, numbered from 1. getOddball(index) returns that
        live ball (x, y, z, object_id, carried, carrier, carrier_name, spawn). With no
        index it returns { live = {...}, spawns = {...} }. reset forces the carrier to
        drop the ball and returns it to its starting location. With no index, all balls.

    - netgame.RACE.getRaceCheckpoints()
    - netgame.RACE.resetCheckpoint([player_id])
        getRaceCheckpoints returns every checkpoint (x, y, z, facing) in running order.
        resetCheckpoint clears a player's checkpoint progress, or every connected
        player's if no id is given. Race only.

    - netgame.KOTH.getHill([index])
    - netgame.KOTH.resetHill()
        getHill(index) returns the x, y, z of that scenario hill entry (numbered from 1).
        With no index it returns { current, spawns, markers }: the live hill centre, every
        hill entry, and the live hill markers (current and markers are King only).
        resetHill moves the hill back to where it was at game start. It runs
        asynchronously (about a second), so check KOTH.getResetStatus() for the result.

COPYRIGHT (c) 2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
            https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

local M = {
    -- Scenario netgame entry types this library uses.
    TYPE = {
        CTF_FLAG = 0,
        ODDBALL = 2,
        RACE_TRACK = 3,
        VEHICLE_RESPAWN = 5, -- also the value used to mark an entry disabled
        HILL = 8
    },
    CTF = {},
    KOTH = {},
    ODDBALL = {},
    RACE = {}
}
local CTF, KOTH, ODDBALL, RACE = M.CTF, M.KOTH, M.ODDBALL, M.RACE

local TAG_TABLE = 0x40440000 -- same for PC and CE
local SCNR_CLASS = 0x73636E72 -- "scnr"
local WEAP_CLASS = 0x77656170 -- "weap"
local NETGAME_FLAGS = 0x378 -- reflexive in scenario tag data
local ENTRY_SIZE = 0x94
local MEM_MIN, MEM_MAX = 0x40440000, 0x42000000
local NO_OBJECT = 0xFFFFFFFF

local OBJECTIVE_TYPE_OFFSET, OBJECTIVE_FLAG_OFFSET, OBJECTIVE_FLAG_BIT = 0x2, 0x308, 3
local ODDBALL_OBJECTIVE_TYPE = 4

local OBJECT_HEADER_SIG = "8B0D????????8B513425FFFF00008D"
local CTF_GLOBALS_SIG = "8B3C85????????3BF9741FE8????????8B8E2C0200008B4610"
local KOTH_GLOBALS_SIG = "BF??????00F3ABB96B000000"
local RACE_GLOBALS_SIG = "BF??????00F3ABB952000000"
local GAMETYPE_BASE_SIG = "B9360000008BF3BF????????"

local entries = {} -- parsed scenario netgame entries
local loaded_map   -- map the entries were parsed for
local initial_hill -- hill definition captured at game start
local hill_reset_job
local ctf_globals, koth_globals, race_globals, gametype_base
local oddball_tag_id -- tag meta id of the oddball weapon

local function isInt(n, min, max)
    return type(n) == "number" and n % 1 == 0 and n >= min and (max == nil or n <= max)
end

local function isNum(...)
    for i = 1, select("#", ...) do
        if type((select(i, ...))) ~= "number" then return false end
    end
    return true
end

local function resolveGlobals(signature, offset, pc_fallback, ce_fallback)
    local hit = sig_scan(signature)
    if hit ~= 0 then return read_dword(hit + offset) end
    return halo_type == "PC" and pc_fallback or ce_fallback
end

local function getCtfGlobals()
    ctf_globals = ctf_globals or resolveGlobals(CTF_GLOBALS_SIG, 3, 0x639B78, 0x5BDB98)
    return ctf_globals
end

local function getKothGlobals()
    koth_globals = koth_globals or resolveGlobals(KOTH_GLOBALS_SIG, 1, 0x639BB0, 0x5BDBD0)
    return koth_globals
end

local function getRaceGlobals()
    race_globals = race_globals or resolveGlobals(RACE_GLOBALS_SIG, 1, 0x639F80, 0x5BDFA0)
    return race_globals
end

local function getGametypeBase()
    gametype_base = gametype_base or resolveGlobals(GAMETYPE_BASE_SIG, 8, 0x671320, 0x5F5478)
    return gametype_base
end

-- Not cached: read the header pointer each time so a map change cannot leave it stale.
---@return number | nil header
local function getObjectTable()
    local hit = sig_scan(OBJECT_HEADER_SIG)
    local slot = hit ~= 0 and read_dword(hit + 2) or (halo_type == "PC" and 0x744C18 or 0x6C69F0)
    local header = read_dword(slot)
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

--- Finds the player holding an objective weapon (flag or oddball).
--- A carried objective is in the carrier's weapon slots and its parent is their biped.
---@return number | nil player_id, string | nil name, number | nil dyn
local function findCarrier(object, object_id)
    local parent_id = read_dword(object + 0xC4)
    for p = 1, 16 do
        if player_present(p) and player_alive(p) then
            local player, dyn = get_player(p), get_dynamic_player(p)
            if player ~= 0 and dyn ~= 0 then
                local holding = parent_id ~= NO_OBJECT and read_dword(player--[[@cast -?]] + 0x34) == parent_id
                if not holding then
                    for slot = 0, 3 do
                        if read_dword(dyn--[[@cast -?]] + 0x2F8 + slot * 4) == object_id then
                            holding = true
                            break
                        end
                    end
                end
                if holding then return p, get_var(p, "$name"), dyn end
            end
        end
    end
    return nil
end

--- Describes an objective object: position (carrier's if carried), id and carrier.
local function describeObject(object_id, object)
    local x, y, z = read_vector3d(object + 0x5C)
    local carrier, carrier_name, dyn = findCarrier(object, object_id)
    if dyn then x, y, z = read_vector3d(dyn + 0x5C) end
    return {
        object_id = object_id,
        x = x,
        y = y,
        z = z,
        carried = carrier ~= nil,
        carrier = carrier,
        carrier_name = carrier_name
    }
end

-- Timer callbacks must be global. They return false so the timer does not repeat.
function NetgameFlagsMoveObject(object_id, x, y, z)
    local object = get_object_memory(object_id)
    if object ~= 0 then
        write_vector3d(object + 0x5C, x, y, z)
        write_vector3d(object + 0x68, 0, 0, 0) -- clear velocity so it does not drift away
    end
    return false
end

--- Moves an objective weapon. If it is carried, the carrier drops it first and the
--- move is applied after the drop has been processed.
---@return boolean ok
local function moveObjective(info, x, y, z)
    if info.carried and info.carrier then
        drop_weapon(info.carrier)
        timer(100, "NetgameFlagsMoveObject", info.object_id, x, y, z)
        return true
    end
    NetgameFlagsMoveObject(info.object_id, x, y, z)
    return true
end

local function getScenarioData()
    local tag_array = read_dword(TAG_TABLE)
    local tag_count = read_dword(TAG_TABLE + 0xC)
    for i = 0, tag_count - 1 do
        local tag = tag_array + 0x20 * i
        if read_dword(tag) == SCNR_CLASS then return read_dword(tag + 0x14) end
    end
    return nil
end

---@return number | nil count, number | nil data
local function getReflexive()
    local scnr = getScenarioData()
    if not scnr or scnr == 0 then return nil end

    local count = read_dword(scnr + NETGAME_FLAGS)
    local data = read_dword(scnr + NETGAME_FLAGS + 4)
    if not count or count > 1024 or not data then return nil end
    if count > 0 and (data < MEM_MIN or data > MEM_MAX) then return nil end
    return count, data
end

--- Rescans the scenario. Called automatically when the map changes.
---@return boolean ok False if the reflexive is invalid (protected map, bad offset).
function M.load()
    entries = {}
    local count, data = getReflexive()
    if not count then return false end

    local per_type = {}
    for i = 0, count - 1 do
        local e = data--[[@cast -?]] + i * ENTRY_SIZE
        local flag_type = read_word(e + 0x10)
        per_type[flag_type] = (per_type[flag_type] or 0) + 1
        local x, y, z = read_vector3d(e)
        entries[#entries + 1] = {
            index = per_type[flag_type], -- 1-based within its type
            x = x,
            y = y,
            z = z,
            facing = read_float(e + 0x0C),
            type = flag_type,
            team = read_word(e + 0x12)
        }
    end
    loaded_map = get_var(0, "$map")
    return true
end

local function ensureLoaded()
    if loaded_map ~= get_var(0, "$map") then M.load() end
end

--- All scenario entries of a type, optionally filtered by team.
---@param flag_type number       One of M.TYPE
---@param team      number | nil
---@return table[] list Items: { index, x, y, z, facing, type, team }
function M.getEntries(flag_type, team)
    ensureLoaded()
    local out = {}
    for _, e in ipairs(entries) do
        if e.type == flag_type and (team == nil or e.team == team) then out[#out + 1] = e end
    end
    return out
end

--- Writes a new position into a scenario entry (changes the running map until reload).
local function setSpawn(flag_type, index, team, x, y, z)
    if not isNum(x, y, z) then return false end
    local count, data = getReflexive()
    if not count then return false end

    local match = 0
    for i = 0, count - 1 do
        local address = data--[[@cast -?]] + i * ENTRY_SIZE
        if read_word(address + 0x10) == flag_type and (team == nil or read_word(address + 0x12) == team) then
            match = match + 1
            if match == index then
                if not write_vector3d(address, x, y, z) then return false end
                return M.load()
            end
        end
    end
    return false
end

--- Call from EVENT_GAME_START. Reloads scenario data and captures the starting KOTH hill.
---@return boolean ok
function M.onGameStart()
    initial_hill = nil
    hill_reset_job = nil
    local ok = M.load()
    -- KOTH globals can still hold the previous round's hill during EVENT_GAME_START.
    timer(300, "NetgameFlagsCaptureInitialHill")
    return ok
end

--- Starting position of a team's flag.
---@param team number 0 = red, 1 = blue
---@return number | nil x, number | nil y, number | nil z
function CTF.getSpawn(team)
    if team ~= 0 and team ~= 1 then return nil end
    local e = M.getEntries(M.TYPE.CTF_FLAG, team)[1]
    if not e then return nil end
    return e.x, e.y, e.z
end

--- Moves a team's starting flag position (running map only).
---@return boolean ok
function CTF.setSpawn(team, x, y, z)
    if team ~= 0 and team ~= 1 then return false end
    return setSpawn(M.TYPE.CTF_FLAG, 1, team, x, y, z)
end

--- Live state of a team's flag. Only available during a CTF game.
--- If carried, x/y/z are the carrier's position.
---@param team number 0 = red, 1 = blue
---@return table | nil flag { team, object_id, x, y, z, carried, carrier, carrier_name, at_spawn }
function CTF.getFlag(team)
    if (team ~= 0 and team ~= 1) or get_var(0, "$gt") ~= "ctf" then return nil end

    local globals = getCtfGlobals()
    for slot = 0, 1 do
        local spawn_address = read_dword(globals--[[@cast -?]] + slot * 4)
        local object_id = read_dword(globals--[[@cast -?]] + 0x8 + slot * 4)

        -- Match on the spawn entry's team field so assault/slot swaps do not matter.
        if spawn_address ~= 0 and object_id ~= NO_OBJECT and read_word(spawn_address + 0x12) == team then
            local object = get_object_memory(object_id)
            if object ~= 0 then
                local flag = describeObject(object_id, object)
                local sx, sy, sz = read_vector3d(spawn_address)
                flag.team = team
                flag.spawn = { x = sx, y = sy, z = sz }
                flag.at_spawn = not flag.carried and math.abs(flag.x - sx) < 0.5
                    and math.abs(flag.y - sy) < 0.5 and math.abs(flag.z - sz) < 0.5
                return flag
            end
        end
    end
    return nil
end

--- Respawns a flag at its starting base. A carrier is forced to drop it first.
---@param team number | nil 0 = red, 1 = blue, nil = both
---@return boolean ok
---@return number count Flags reset
function CTF.resetFlag(team)
    if team ~= nil and team ~= 0 and team ~= 1 then return false, 0 end
    if get_var(0, "$gt") ~= "ctf" then return false, 0 end

    local count = 0
    for t = 0, 1 do
        if team == nil or team == t then
            local flag, x, y, z = CTF.getFlag(t), CTF.getSpawn(t)
            if flag and x then
                moveObjective(flag, x, y, z)
                write_byte(getCtfGlobals()--[[@cast -?]] + 0x1C + t, 0)
                count = count + 1
            end
        end
    end
    return count > 0, count
end

local function readHillMarkers()
    local globals = getKothGlobals()
    local count = read_dword(globals--[[@cast -?]] + 0x90)
    if not count or count < 1 or count > 12 then return {} end

    local markers = {}
    for i = 0, count - 1 do
        local x, y, z = read_vector3d(globals--[[@cast -?]] + 0x94 + i * 0x0C)
        markers[#markers + 1] = {
            index = i + 1,
            x = x,
            y = y,
            z = z,
            bounds_x = read_float(globals--[[@cast -?]] + 0x124 + i * 0x08),
            bounds_y = read_float(globals--[[@cast -?]] + 0x128 + i * 0x08)
        }
    end
    return markers
end

---@return table | nil definition { x, y, z, count, points }
local function readHillDefinition()
    if get_var(0, "$gt") ~= "king" then return nil end
    local markers = readHillMarkers()
    if #markers == 0 then return nil end
    local x, y, z = read_vector3d(getKothGlobals()--[[@cast -?]] + 0x184)
    return { x = x, y = y, z = z, count = #markers, points = markers }
end

function NetgameFlagsCaptureInitialHill()
    initial_hill = readHillDefinition()
    return false
end

local function near(a, b)
    return math.abs(a - b) < 0.02
end

local function hillsMatch(a, b)
    if not a or not b or a.count ~= b.count then return false end
    if not (near(a.x, b.x) and near(a.y, b.y) and near(a.z, b.z)) then return false end
    for i = 1, a.count do
        local p, q = a.points[i], b.points[i]
        if not (near(p.x, q.x) and near(p.y, q.y)
            and near(p.z, q.z) and near(p.bounds_x, q.bounds_x)
            and near(p.bounds_y, q.bounds_y)) then
            return false
        end
    end
    return true
end

--- Scenario hill entry `index` (1-based) as x, y, z; with no index, a table of everything:
--- { current = {x,y,z}|nil, spawns = { {index,x,y,z,facing,team} }, markers = { {index,x,y,z} } }.
--- `current` and `markers` are live and only present during King.
---@param index number | nil
---@return number | table | nil
function KOTH.getHill(index)
    local spawns = M.getEntries(M.TYPE.HILL)
    if index ~= nil then
        local e = isInt(index, 1) and spawns[index]
        if not e then return nil end
        ---@diagnostic disable-next-line: redundant-return-value
        return e.x, e.y, e.z
    end

    local result = { spawns = spawns, markers = {} }
    if get_var(0, "$gt") == "king" then
        local x, y, z = read_vector3d(getKothGlobals()--[[@cast -?]] + 0x184)
        result.current = { x = x, y = y, z = z }
        result.markers = readHillMarkers()
    end
    return result
end

--- Moves the active hill centre in memory (King only).
---@return boolean ok
function KOTH.setHill(x, y, z)
    if get_var(0, "$gt") ~= "king" or not isNum(x, y, z) then return false end
    local address = getKothGlobals()--[[@cast -?]] + 0x184
    if not write_vector3d(address, x, y, z) then return false end
    local ax, ay, az = read_vector3d(address)
    return near(ax, x) and near(ay, y) and near(az, z)
end

local function close(a, b)
    return math.abs(a - b) < 0.05
end

--- Scenario hill groups (entries sharing a `team` value form one hill) and how many of
--- the start hill's markers each group contains.
---@return table[] groups { team, count, matches } sorted by team
function KOTH.getGroups()
    local by_team = {}
    for _, e in ipairs(M.getEntries(M.TYPE.HILL)) do
        by_team[e.team] = by_team[e.team] or { team = e.team, count = 0, matches = 0, list = {} }
        local g = by_team[e.team]
        g.count = g.count + 1
        g.list[#g.list + 1] = e
    end

    local groups = {}
    for _, g in pairs(by_team) do
        ---@diagnostic disable-next-line: unnecessary-if
        if initial_hill then
            for _, m in ipairs(initial_hill.points) do
                for _, e in ipairs(g.list) do
                    if close(e.x, m.x) and close(e.y, m.y) and close(e.z, m.z) then
                        g.matches = g.matches + 1
                        break
                    end
                end
            end
        end
        g.list = nil
        groups[#groups + 1] = g
    end
    table.sort(groups, function (a, b) return a.team < b.team end)
    return groups
end

-- Ends a reset job: always re-enables the hill entries and restores the gametype flag.
local function finishHillReset(status, reason)
    local job = hill_reset_job
    if not job then return end
    for _, d in ipairs(job.disabled) do
        write_word(d.address + 0x10, d.type)
    end
    job.disabled = {}
    if job.restore_moving then write_byte(job.base + 0x9C, 0) end
    job.status, job.reason = status, reason
end

-- Global timer callback. Returns true to keep polling, false to stop.
function NetgameFlagsHillResetStep()
    local job = hill_reset_job
    if not job or job.status ~= "running" then return false end

    if get_var(0, "$gt") ~= "king" then
        finishHillReset("failed", "game ended")
        return false
    end
    if hillsMatch(readHillDefinition(), initial_hill) then
        finishHillReset("complete")
        return false
    end

    job.polls = job.polls + 1
    if job.polls >= 50 then -- 5 seconds
        finishHillReset("failed", "the engine did not move the hill to the start group")
        return false
    end
    return true
end

--- Moves the hill back to where it was at game start.
---
--- The live hill is rebuilt by the engine from the scenario hill entries every time it
--- moves, so writing the live globals does not stick. Instead this temporarily disables
--- every hill group except the start group, asks the engine to move the hill (so it has
--- only one place to go), then restores the entries. Asynchronous, finishing within a
--- second or so: poll KOTH.getResetStatus().
--- This was a pain to figure out. Enjoy.
---@return boolean ok True if the reset finished or was started.
function KOTH.resetHill()
    ---@diagnostic disable-next-line: unnecessary-if
    if hill_reset_job and hill_reset_job.status == "running" then return false end
    hill_reset_job = { status = "failed", reason = "not in a King game", disabled = {} }
    local job = hill_reset_job

    if get_var(0, "$gt") ~= "king" then return false end
    if not initial_hill then
        job.reason = "no start hill captured (call onGameStart at game start)"
        return false
    end
    if hillsMatch(readHillDefinition(), initial_hill) then
        job.status, job.reason = "complete", nil
        return true
    end

    local best
    for _, g in ipairs(KOTH.getGroups()) do
        if g.matches > 0 and (not best or g.matches > best.matches) then best = g end
    end
    if not best then
        job.reason = "no scenario hill group matches the start hill markers"
        return false
    end

    local count, data = getReflexive()
    if not count then
        job.reason = "invalid netgame flags reflexive"
        return false
    end

    for i = 0, count - 1 do
        local address = data--[[@cast -?]] + i * ENTRY_SIZE
        if read_word(address + 0x10) == M.TYPE.HILL and read_word(address + 0x12) ~= best.team then
            job.disabled[#job.disabled + 1] = { address = address, type = M.TYPE.HILL }
            write_word(address + 0x10, M.TYPE.VEHICLE_RESPAWN)
        end
    end

    -- A static (non-moving) King game needs moving-hill enabled while we move it.
    local base = getGametypeBase()
    ---@diagnostic disable-next-line: unnecessary-if
    if base and base ~= 0 and read_byte(base + 0x9C) == 0 then
        write_byte(base + 0x9C, 1)
        job.base, job.restore_moving = base, true
    end

    job.status, job.reason, job.polls = "running", nil, 0
    write_dword(getKothGlobals()--[[@cast -?]] + 0x1A8, 1) -- move timer: move on the next tick
    timer(100, "NetgameFlagsHillResetStep")
    return true
end

---@return string status       idle | running | complete | failed
---@return string | nil reason Why the last reset failed
function KOTH.getResetStatus()
    if not hill_reset_job then return "idle" end
    return hill_reset_job.status, hill_reset_job.reason
end

--- The hill definition captured at game start (x, y, z, marker count).
function KOTH.getStartHill()
    if not initial_hill then return nil end
    return initial_hill.x, initial_hill.y, initial_hill.z, initial_hill.count
end

--- Players the game currently registers as inside the hill.
---@return table[] players { player_id, name }
function KOTH.getPlayers()
    local players = {}
    if get_var(0, "$gt") ~= "king" then return players end
    local globals = getKothGlobals()
    for p = 1, 16 do
        if player_present(p) and read_byte(globals--[[@cast -?]] + to_real_index(p) + 0x80) == 1 then
            players[#players + 1] = { player_id = p, name = get_var(p, "$name") }
        end
    end
    return players
end

local function getOddballTagId()
    ---@diagnostic disable-next-line: unnecessary-if
    if oddball_tag_id then return oddball_tag_id end

    local tag_array = read_dword(TAG_TABLE)
    local tag_count = read_dword(TAG_TABLE + 0xC)
    if not tag_array or tag_array == 0 or not tag_count or tag_count > 65536 then return nil end

    for i = 0, tag_count - 1 do
        local tag = tag_array + i * 0x20
        if read_dword(tag) == WEAP_CLASS then
            local data = read_dword(tag + 0x14)
            if data ~= 0 and read_bit(data + OBJECTIVE_FLAG_OFFSET, OBJECTIVE_FLAG_BIT) == 1
                and read_byte(data + OBJECTIVE_TYPE_OFFSET) == ODDBALL_OBJECTIVE_TYPE then
                oddball_tag_id = read_dword(tag + 0xC)
                return oddball_tag_id
            end
        end
    end
    return nil
end

local function liveOddballs()
    local out = {}
    if get_var(0, "$gt") ~= "oddball" then return out end
    local tag_id = getOddballTagId()
    if not tag_id then return out end

    forEachObject(function (object_id, object)
        if read_dword(object) == tag_id then
            local ball = describeObject(object_id, object)
            ball.index = #out + 1
            out[#out + 1] = ball
        end
    end)
    return out
end

--- Live oddball `index` (1-based), or with no index a table { live = {...}, spawns = {...} }.
--- Live entries: { index, object_id, x, y, z, carried, carrier, carrier_name, spawn }.
--- Spawns are the configured oddball starting locations and work on any gametype.
--- A map can have several oddballs. The nth oddball is paired with the nth spawn.
---@param index number | nil
---@return table | nil
function ODDBALL.getOddball(index)
    local spawns = M.getEntries(M.TYPE.ODDBALL)
    local live = liveOddballs()
    for i, ball in ipairs(live) do
        ball.spawn = spawns[i]
    end

    if index == nil then return { live = live, spawns = spawns } end
    if not isInt(index, 1) then return nil end
    return live[index]
end

--- Moves a configured oddball spawn (running map only).
---@return boolean ok
function ODDBALL.setSpawn(index, x, y, z)
    if not isInt(index, 1) then return false end
    return setSpawn(M.TYPE.ODDBALL, index, nil, x, y, z)
end

--- Respawns oddball(s) at their starting location. A carrier is forced to drop it first.
---@param index number | nil 1-based oddball, or nil for all
---@return boolean ok
---@return number count Oddballs reset
function ODDBALL.reset(index)
    if index ~= nil and not isInt(index, 1) then return false, 0 end
    if get_var(0, "$gt") ~= "oddball" then return false, 0 end

    local spawns = M.getEntries(M.TYPE.ODDBALL)
    local count = 0
    for i, ball in ipairs(liveOddballs()) do
        local spawn = spawns[i]
        if (index == nil or index == i) and spawn then
            moveObjective(ball, spawn.x, spawn.y, spawn.z)
            count = count + 1
        end
    end
    return count > 0, count
end

local function countBits(mask)
    local n = 0
    while mask > 0 do
        if mask % 2 == 1 then n = n + 1 end
        mask = math.floor(mask / 2)
    end
    return n
end

--- All race checkpoint locations in running order.
---@return table[] checkpoints { index, order, x, y, z, facing }
function RACE.getRaceCheckpoints()
    local list = {}
    for _, e in ipairs(M.getEntries(M.TYPE.RACE_TRACK)) do
        list[#list + 1] = { index = e.index, order = e.team, x = e.x, y = e.y, z = e.z, facing = e.facing }
    end
    table.sort(list, function (a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    return list
end

--- Checkpoints a lap requires, per the game's checkpoint mask. Race only.
---@return number | nil count
function RACE.getCheckpointCount()
    if get_var(0, "$gt") ~= "race" then return nil end
    ---@diagnostic disable-next-line: param-type-mismatch
    return countBits(read_dword(getRaceGlobals()))
end

--- A player's progress. Race only.
---@param player_id number
---@return number | nil reached, number | nil total, number | nil mask
function RACE.getProgress(player_id)
    if get_var(0, "$gt") ~= "race" or not isInt(player_id, 1, 16) then return nil end
    local globals = getRaceGlobals()
    local mask = read_dword(globals--[[@cast -?]] + 0x44 + to_real_index(player_id) * 4)
    ---@diagnostic disable-next-line: param-type-mismatch
    return countBits(mask), countBits(read_dword(globals)), mask
end

--- Clears checkpoint progress for one player, or every connected player.
---@param player_id number | nil
---@return boolean ok
---@return number count Players reset
function RACE.resetCheckpoint(player_id)
    if get_var(0, "$gt") ~= "race" then return false, 0 end
    if player_id ~= nil and not isInt(player_id, 1, 16) then return false, 0 end

    local globals = getRaceGlobals()
    local count = 0
    for p = 1, 16 do
        if (player_id == nil and player_present(p)) or p == player_id then
            if not write_dword(globals--[[@cast -?]] + 0x44 + to_real_index(p) * 4, 0) then return false, count end
            count = count + 1
        end
    end
    return count > 0, count
end

return M
