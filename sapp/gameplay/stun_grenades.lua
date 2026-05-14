--[[
=====================================================================================
SCRIPT NAME:      stun_grenades.lua
DESCRIPTION:      Converts standard grenades into tactical stun devices that
                  temporarily reduce movement speed of affected players.

FEATURES:
                 - Three distinct stun effects based on grenade type:
                   * Frag explosion: 5 second stun
                   * Plasma explosion: 5 second stun
                   * Plasma sticky: 10 second stun
                 - Configurable stun durations and speed reduction
                 - Automatic speed restoration after stun expires
                 - Preserves original grenade damage effects
                 - Works in all game modes

CONFIGURATION:
                 - Edit the 'tags' table to:
                   * Add new stun effects
                   * Modify existing stun durations
                   * Adjust speed reduction percentage
                 - Format: {'tag_name', duration_seconds, speed_percent}

NOTES:
                 - Speed reduction defaults to 0.5% (crawling speed)
                 - Stun effects persist through death
                 - Works with both PvP and PvE scenarios
                 - No special permissions required

LAST UPDATED:     20/8/2025

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts --
local tags = {
    --
    -- format:
    -- {tag name, stun time, stun percent}
    --
    { 'weapons\\frag grenade\\explosion',   5,  0.5 },
    { 'weapons\\plasma grenade\\explosion', 5,  0.5 },
    { 'weapons\\plasma grenade\\attached',  10, 0.5 }
}
-- config ends --

api_version = '1.12.0.0'

local stuns = {}
local players = {}
local time = os.time

-- Register needed event callbacks:
function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")
    OnStart()
end

-- Return meta id of a tag address using its class and name:
local function get_tag(Class, Name)
    local tag = lookup_tag(Class, Name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function tags_to_id()
    local t = {}

    for i = 1, #tags do
        local v = tags[i]
        local name = v[1]
        local tag = get_tag('jpt!', name)

        if tag then
            local stun_time = v[2]
            local stun_percent = v[3]
            t[tag] = { stun_time, stun_percent }
        end
    end

    return t
end

-- Called when the game starts:
function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    players = {}
    stuns = tags_to_id()
end

-- Called every tick (1/30th second)
function OnTick()
    for i, player in pairs(players) do
        if (i) and player_alive(i) then
            if (player.start() < player.finish) then
                execute_command('s ' .. i .. ' ' .. player.stun_percent)
            else
                execute_command('s ' .. i .. ' 1')
                players[i] = nil
            end
        elseif (i) and (not player_alive(i)) then
            players[i] = nil
        end
    end
end

-- Called when a player receives damage:
function OnDamage(victim, killer, meta_id)
    victim = tonumber(victim)
    killer = tonumber(killer)

    if not stuns[meta_id] or killer == 0 or killer == victim then return true end

    local stun_time = stuns[meta_id][1]
    local stun_percent = stuns[meta_id][2]

    players[victim] = {
        start = time,
        finish = time() + stun_time,
        stun_percent = stun_percent,
    }
end

function OnScriptUnload()
    -- N/A
end
