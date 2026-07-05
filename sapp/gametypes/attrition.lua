--[[
=====================================================================================
SCRIPT NAME:      attrition.lua
DESCRIPTION:      Implements Halo Infinite-style Attrition mode with team revival
                  mechanics and limited respawns.

KEY FEATURES:
                 - Limited lives pool per team
                 - Team-based revival system:
                   * Crouch-to-revive mechanics
                   * Progress-based revival timer
                   * Visual feedback for both reviver and revivee
                 - Orb markers for downed players
                 - Tactical respawn positioning
                 - Team-specific revival restrictions

CONFIGURATION OPTIONS:
                 - Adjustable revival time
                 - Customizable revival range
                 - Orb height offset
                 - Admin message prefix
                 - Orb object customization

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts
local Attrition = {

    -- Time (in seconds) it takes to revive a player:
    --
    revival_time = 5,

    -- A player must be within this distance (in world units) to revive a team mate:
    --
    range = 0.5,

    -- Orb object height offset (height above ground):
    --
    orb_height_offset = 1,

    -- A message relay function temporarily disables the 'msg_prefix',
    -- and will restore it to this when done:
    --
    prefix = '**ADMIN**',

    -- The object tag class & name that represents the 'orb'.
    orb_object = { 'weap', 'weapons\\ball\\ball' }
}

-----------------
-- config ends --
-----------------

api_version = '1.12.0.0'

local orb_object
local players = {}
local time = os.time

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_MAP_RESET, 'OnStart')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_TEAM_SWITCH, 'OnSwitch')
    OnStart()
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then
        players = {}

        local class, name = Attrition.orb_object[1], Attrition.orb_object[2]
        orb_object = getTag(class, name)

        execute_command('disable_object ' .. '"' .. name .. '" 0')

        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function Attrition:newTimer()
    return { start = time, finish = time() + self.revival_time }
end

function Attrition:newPos(x, y, z)
    return { x = x, y = y, z = z }
end

local sqrt = math.sqrt
local function getDistance(x1, y1, z1, x2, y2, z2)
    return sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2)
end

local function getPosition(id)
    local x, y, z
    local dyn = get_dynamic_player(id)
    if (dyn == 0) then
        return nil
    end

    local vehicle = read_dword(dyn + 0x11C)
    local object = get_object_memory(vehicle)
    if (vehicle == 0xFFFFFFFF) then
        x, y, z = read_vector3d(dyn + 0x5C)
    elseif (object ~= 0) then
        x, y, z = read_vector3d(object + 0x5C)
    end

    return x, y, z, dyn
end

function Attrition:spawnOrb()
    local id = self.id
    local h = self.orb_height_offset
    local x, y, z = getPosition(id)
    if (not x) then
        return -- something went wrong
    end

    -- Create the orb:
    local orb = spawn_object('', '', x, y, z + h, 0, orb_object)
    local object = get_object_memory(orb)
    if (object == 0) then
        return -- something went wrong
    end

    self.pos = self:newPos(x, y, z)

    -- It's necessary to get separate coordinates for the orb
    -- because its position vectors are updated every tick (bouncing animation).
    self.orb[orb] = self:newPos(x, y, z)
    self.orb[orb].team = self.team

    rprint(id, 'Waiting to be revived...')
end

function Attrition:newPlayer(o)
    setmetatable(o, { __index = self })
    self.__index = self

    -- default properties:
    o.orb = {}
    o.revived = false

    return o
end

local function deductDeath(id)
    local deaths = tonumber(get_var(id, '$deaths'))
    execute_command('deaths ' .. id .. ' ' .. deaths - 1)
end
local function cls(id)
    for _ = 1, 25 do
        rprint(id, ' ')
    end
end

local function sayAll(message)
    execute_command('msg_prefix ""')
    say_all(message)
    execute_command('msg_prefix "' .. Attrition.prefix .. '"')
end

local function privateSay(id, message)
    rprint(id, message)
end

local function progressBar(start, finish, revival_time)
    local bar = ''
    local time_remaining = finish - start()

    for i = 1, time_remaining do
        if (i > (time_remaining / finish) * revival_time) then
            bar = bar .. '=='
        end
    end

    return bar
end

function Attrition:revive(victim, orb)
    local start = self.timer.start
    local finish = self.timer.finish

    local vic_id = victim.id

    if (start() >= finish) then
        self.timer = nil -- reset revive timer for team mate

        sayAll(self.name .. ' revived ' .. victim.name .. '!')

        -- Resets the players respawn time (causes instant respawn):
        write_dword(get_player(vic_id) + 0x2C, -1 * 33)

        destroy_object(orb) -- destroy orb

        victim.orb = {}       -- reset orbs for downed player
        victim.revived = true -- set revived flag for downed player

        deductDeath(vic_id) -- deduct death from downed player (since they were revived)
        return
    end

    local bar = progressBar(start, finish, self.revival_time)

    cls(self.id)
    privateSay(self.id, '|cReviving ' .. victim.name)
    privateSay(self.id, '|c[' .. bar .. ']')
    --
    --
    cls(vic_id)
    privateSay(vic_id, '|cYou are being revived by ' .. self.name)
    privateSay(vic_id, '|c[' .. bar .. ']')
end

local function updateVectors(object, x, y, z)
    -- update orb x,y,z map coordinates:
    write_float(object + 0x5C, x)
    write_float(object + 0x60, y)
    write_float(object + 0x64, z)

    -- update orb velocities:
    write_float(object + 0x68, 0) -- x vel
    write_float(object + 0x6C, 0) -- y vel
    write_float(object + 0x70, 0) -- z vel

    -- update orb yaw, pitch, roll
    write_float(object + 0x90, 0) -- yaw
    write_float(object + 0x8C, 0) -- pitch
    write_float(object + 0x94, 0) -- roll
end

function Attrition:onTick()
    for i, victim in pairs(players) do
        if (not player_alive(i)) then
            -- Setting this to 0.1*33 will prevent the player from respawning:
            write_dword(get_player(i) + 0x2C, 0.1 * 33)

            for orb_id, orb in pairs(victim.orb) do
                local object = get_object_memory(orb_id)
                if (object ~= 0) then
                    orb.team = victim.team -- get the team of the downed player that this orb belongs to

                    local h = self.orb_height_offset
                    updateVectors(object, orb.x, orb.y, orb.z + h)

                    for j, teammate in pairs(players) do
                        if (i ~= j and player_alive(j)) then
                            local px, py, pz, dyn = getPosition(j)
                            if (not px) then
                                goto next
                            end

                            local crouching = read_bit(dyn + 0x208, 0)
                            local distance = getDistance(px, py, pz, orb.x, orb.y, orb.z)

                            if (teammate.team == orb.team) then
                                if (distance <= self.range and crouching == 1) then
                                    if (not teammate.timer) then
                                        teammate.timer = teammate:newTimer()
                                    else
                                        teammate:revive(victim, orb_id, orb)
                                    end
                                else
                                    teammate.timer = nil
                                end
                            elseif (teammate.team ~= orb.team) then
                                if (distance <= self.range and crouching == 1) then
                                    cls(j)
                                    privateSay(j, 'You cannot revive this player.')
                                end
                            end

                            :: next ::
                        end
                    end
                end
            end
        end
    end
end

function OnJoin(id)
    players[id] = Attrition:newPlayer({
        id = id,
        team = get_var(id, '$team'),
        name = get_var(id, '$name')
    })
end

function OnQuit(id)
    for object, _ in pairs(players[id].orb) do
        destroy_object(object)
    end

    players[id] = nil
end

function OnDeath(victim, killer)
    victim = tonumber(victim)
    killer = tonumber(killer)

    local k = players[killer]
    local v = players[victim]

    if (killer > 0 and killer ~= victim and k and v) then
        v:spawnOrb()
    end
end

local function teleport(t)
    write_vector3d(unpack(t))
end

function OnSpawn(id)
    local player = players[id]
    local dyn = get_dynamic_player(id)
    if (player.revived and dyn ~= 0) then
        teleport({ dyn + 0x5C, player.pos.x, player.pos.y, player.pos.z })
        player.revived = false
    end
end

function OnSwitch(id)
    players[id].team = get_var(id, '$team')
end

function OnTick()
    Attrition:onTick()
end

function OnScriptUnload() end
