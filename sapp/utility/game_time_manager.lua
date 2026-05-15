--[[
===============================================================================
SCRIPT NAME:      game_time_manager.lua
DESCRIPTION:      Per-map game time manager.

                  Supports stock game types (CTF, Slayer, Oddball, KOTH, Race)
                  and custom gametypes, e.g. "Race_005" or "My Custom Mode".

                  Add custom modes by creating a new entry in TIMELIMIT.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG START ---------------------------------

api_version = "1.12.0.0"

local DEFAULT_TIMELIMIT = {
    beavercreek = 30,
    bloodgulch = 30,
    boardingaction = 30,
    carousel = 30,
    chillout = 30,
    damnation = 30,
    dangercanyon = 30,
    deathisland = 30,
    gephyrophobia = 30,
    hangemhigh = 30,
    icefields = 30,
    infinity = 30,
    longest = 30,
    prisoner = 30,
    putput = 30,
    ratrace = 30,
    sidewinder = 30,
    timberland = 30,
    wizard = 30
}

local TIMELIMIT = {
    ctf = DEFAULT_TIMELIMIT,
    slayer = DEFAULT_TIMELIMIT,
    oddball = DEFAULT_TIMELIMIT,
    koth = DEFAULT_TIMELIMIT,
    race = DEFAULT_TIMELIMIT
    -- Example custom mode (spaces allowed):
    -- ["My Custom Gametype"] = {
    --     beavercreek = 20,
    --     bloodgulch  = 15,
    -- },
}
-- CONFIG END ----------------------------------

local TICKS_PER_MINUTE = 30 * 60
local gameinfo_header, gametype_base, timelimit_address

local function normalize(value)
    return (value or ""):gsub("%s+", ""):lower()
end

local function get_limit(mode, map)
    local mode_limits = TIMELIMIT[normalize(mode)] or DEFAULT_TIMELIMIT
    return mode_limits[normalize(map)]
end

local function apply_timelimit()
    if get_var(0, "$gt") == "n/a" then return end

    local map = get_var(0, "$map")
    local mode = get_var(0, "$mode")
    local limit = get_limit(mode, map)

    if not limit then return end

    write_dword(timelimit_address, limit)

    local gameinfo = read_dword(gameinfo_header)
    local current_ticks = read_dword(gameinfo + 0xC)

    write_dword(gametype_base + 0x78, (limit * TICKS_PER_MINUTE) + current_ticks)
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")

    local base_sig = sig_scan("B9360000008BF3BF78545F00")
    local header_sig = sig_scan("A1????????8B480C894D00")

    if base_sig == 0 or header_sig == 0 then return end

    gametype_base = read_dword(base_sig + 0x8)
    gameinfo_header = read_dword(header_sig + 0x1)
    timelimit_address = (halo_type == "PC" and 0x626630) or 0x5AA5B0

    OnStart()
end

function OnStart()
    apply_timelimit()
end
