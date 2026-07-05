--[[
=====================================================================================
SCRIPT NAME:      hunter_prey.lua
DESCRIPTION:      Intense free-for-all flag survival mode where players compete
                  to hold the flag for the longest cumulative time.

KEY FEATURES:
                 - Central flag spawn with strategic positioning
                 - Timed flag holding mechanics
                 - Automatic flag respawn system
                 - Real-time score tracking
                 - End-game winner announcements
                 - Multi-map support with predefined flag locations

CONFIGURATION OPTIONS:
                 - Adjustable score limit
                 - Customizable flag respawn delay
                 - Map-specific flag coordinates
                 - Server message prefix
                 - Free-for-all enforcement

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local HunterPrey = {

    -- Score limit for the game
    scorelimit = 300,

    -- Respawn time for the flag in seconds
    respawn_time = 10,

    -- Prefix for server messages
    prefix = '**SAPP**',

    -- Map settings with coordinates for flag placement
    map_settings = {
        ["bloodgulch"] = { 65.749, -120.409, 0.118 },
        ["deathisland"] = { -30.282, 31.312, 16.601 },
        ["icefields"] = { -26.032, 32.365, 9.007 },
        ["infinity"] = { 9.631, -64.030, 7.776 },
        ["sidewinder"] = { 2.051, 55.220, -2.801 },
        ["timberland"] = { 1.250, -1.487, -21.264 },
        ["dangercanyon"] = { -0.477, 55.331, 0.239 },
        ["beavercreek"] = { 14.015, 14.238, -0.911 },
        ["boardingaction"] = { 4.374, -12.832, 7.220 },
        ["carousel"] = { 0.033, 0.003, -0.856 },
        ["chillout"] = { 1.392, 4.700, 3.108 },
        ["damnation"] = { -2.002, -4.301, 3.399 },
        ["gephyrophobia"] = { 63.513, -74.088, -1.062 },
        ["hangemhigh"] = { 21.020, -4.632, -4.229 },
        ["longest"] = { -0.84, -14.54, 2.41 },
        ["prisoner"] = { 0.902, 0.088, 1.392 },
        ["putput"] = { -2.350, -21.121, 0.902 },
        ["ratrace"] = { 8.662, -11.159, 0.221 },
        ["wizard"] = { -5.035, -5.064, -2.750 }
    }
}

local FLAG_BIT_INDEX = 3
local timer = {}
local players = {}
local announce_respawn
local clock = os.clock
local format = string.format

api_version = '1.12.0.0'

function timer:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function timer:start()
    self.start_time = clock()
    self.paused_time = 0
    self.paused = false
end

function timer:stop()
    self.start_time = nil
    self.paused_time = 0
    self.paused = false
end

function timer:pause()
    if not self.paused then
        self.paused_time = clock()
        self.paused = true
    end
end

function timer:resume()
    if self.paused then
        self.start_time = self.start_time + (clock() - self.paused_time)
        self.paused_time = 0
        self.paused = false
    end
end

function timer:get()
    if self.start_time then
        if self.paused then
            return self.paused_time - self.start_time
        else
            return clock() - self.start_time
        end
    end
    return 0
end

local function GetTag(Class, Name)
    local tag = lookup_tag(Class, Name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

local function GetDist(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2)
end

local function Say(playerId, message)
    local prefix = HunterPrey.prefix
    if not playerId then
        execute_command('msg_prefix ""')
        say_all(message)
        execute_command('msg_prefix "' .. prefix .. '"')
    else
        for _ = 1, 25 do
            rprint(playerId, ' ')
        end
        rprint(playerId, '|c' .. message)
    end
end

local function FormatTime(time)
    return format('%.3f', time)
end

local function FlagHeld()
    for i, v in pairs(players) do
        local dyn = get_dynamic_player(i)
        if dyn ~= 0 and player_alive(i) and v.has_flag then
            return true
        end
    end
    return false
end

local function RegisterSAPPEvents(f)
    for event, callback in pairs({
        ['EVENT_DIE'] = 'OnDeath',
        ['EVENT_TICK'] = 'OnTick',
        ['EVENT_JOIN'] = 'OnJoin',
        ['EVENT_LEAVE'] = 'OnQuit',
        ['EVENT_GAME_END'] = 'OnEnd'
    }) do
        f(cb[event], callback)
    end
end

function HunterPrey:NewPlayer(player)
    setmetatable(player, { __index = self })
    self.__index = self
    return player
end

function HunterPrey:SpawnFlag()
    local x, y, z = self.fx, self.fy, self.fz
    local flag = spawn_object('', '', x, y, z, 0, self.meta)
    self.flag_object = get_object_memory(flag)
end

function HunterPrey:RespawnFlag()
    if not FlagHeld() then
        local flag = self.flag_object
        local fx, fy, fz = read_vector3d(flag + 0x5C)
        local x, y, z = self.fx, self.fy, self.fz
        local dist = GetDist(fx, fy, fz, x, y, z)

        if dist > 1 and not self.respawn_timer then
            announce_respawn = true
            self.respawn_timer = timer:new()
            self.respawn_timer:start()
        elseif dist > 1 and self.respawn_timer then
            local time = self.respawn_timer:get()
            time = math.floor(time)

            if time == self.respawn_time / 2 and announce_respawn then
                announce_respawn = false
                Say(nil, 'Flag will respawn in ' .. self.respawn_time - time .. ' seconds.')
            elseif time >= self.respawn_time then
                self.respawn_timer = nil
                write_vector3d(self.flag_object + 0x5C, x, y, z)
                Say(nil, 'Flag has respawned.')
            end
        end
    end
end

function HunterPrey:CheckForFlag(dyn)
    for i = 0, 3 do
        local weapon = read_dword(dyn + 0x2F8 + 0x4 * i)
        local object = get_object_memory(weapon)
        if weapon ~= 0xFFFFFFFF and object ~= 0 then
            local tag_address = read_word(object)
            local tag_data = read_dword(read_dword(0x40440000) + tag_address * 0x20 + 0x14)
            if read_bit(tag_data + 0x308, FLAG_BIT_INDEX) == 1 then
                if not self.timer.start_time then
                    self.timer:start()
                elseif self.timer.paused then
                    self.timer:resume()
                end

                self.total_time = self.timer:get()
                local time = FormatTime(self.total_time)

                self.has_flag = true
                self.respawn_timer = nil

                for j, _ in pairs(players) do
                    Say(j, self.name .. ' has the flag (' .. time .. ' seconds).')
                end
                execute_command('score ' .. self.id .. ' ' .. math.floor(time))
                return
            end
        end
    end

    self.timer:pause()
    self.has_flag = nil
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    local game_type = get_var(0, '$gt')
    local ffa = get_var(0, '$ffa') == '1'
    if game_type ~= 'n/a' and ffa then
        announce_respawn = false

        local hp = HunterPrey
        local map = get_var(0, '$map')
        local meta = GetTag('weap', 'weapons\\flag\\flag')

        if hp.map_settings[map] and meta then
            hp.meta = meta
            hp.fx, hp.fy, hp.fz = unpack(hp.map_settings[map])
            hp.fz = hp.fz + 0.5
            hp:SpawnFlag()
            RegisterSAPPEvents(register_callback)
            execute_command('scorelimit ' .. hp.scorelimit)
            return
        end
    end
    RegisterSAPPEvents(unregister_callback)
end

function OnTick()
    for i, v in pairs(players) do
        local dyn = get_dynamic_player(i)
        if player_alive(i) and dyn ~= 0 then
            v:CheckForFlag(dyn)
        end
    end
    HunterPrey:RespawnFlag()
end

function OnJoin(playerId)
    players[playerId] = HunterPrey:NewPlayer({
        id = playerId,
        total_time = 0,
        timer = timer:new(),
        name = get_var(playerId, '$name')
    })
end

function OnDeath(playerId)
    local player = players[playerId]
    player.timer:pause()
    player.has_flag = nil
end

function OnQuit(playerId)
    players[playerId] = nil
end

function OnEnd()
    local winners = {}

    for _, v in pairs(players) do
        if v.total_time > 0 then
            table.insert(winners, v)
        end
    end

    table.sort(winners, function (a, b)
        return a.total_time > b.total_time
    end)

    if #winners == 0 then
        Say(nil, 'The game ended in a tie.')
        goto next
    end

    for i = 1, 3 do
        local player = winners[i]
        if player then
            local name = player.name
            local time = FormatTime(player.total_time)
            local place = i == 1 and '1st (Winner)' or i == 2 and '2nd' or '3rd'
            Say(nil, place .. ' place: ' .. name .. ' | ' .. time .. ' seconds.')
        end
    end

    :: next ::

    players = {}
end

function OnScriptUnload() end
