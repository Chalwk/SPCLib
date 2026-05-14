--[[
=====================================================================================
SCRIPT NAME:      sabotage.lua
DESCRIPTION:      Team-based bomb defusal gameplay featuring:
                  - Bomb planting/defusing mechanics
                  - Configurable timers (plant/defuse/explosion)
                  - Automatic bomb respawn system
                  - Multi-map configuration support
                  - Team scoring integration

MECHANICS:
                  - Players must crouch at enemy base to plant/defuse
                  - Bomb automatically returns if inactive
                  - Explosion awards points to planting team

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local Sabotage = {

    -------------------------------
    -- CONFIGURATION STARTS HERE
    -------------------------------

    -- Time (in seconds) to activate the bomb:
    -- Default: 15
    --
    plant_time = 15,

    -- Time (in seconds) until the bomb explodes:
    -- Default: 30
    --
    explosion_delay = 120,

    -- Time (in seconds) to defuse the bomb:
    -- Default: 15
    --
    defuse_time = 15,

    -- Time (in seconds) until the bomb respawns (if it's dropped):
    --
    bomb_respawn_time = 30,

    -- A message relay function temporarily removes the server prefix,
    -- and will restore it to this when done:
    --
    prefix = '**ADMIN**',

    --------------------
    --  MAP SETTINGS  --
    --------------------

    ["bloodgulch"] = {

        -- Tag class & name of the object to represent the bomb:
        --
        bomb = { 'weap', 'weapons\\ball\\ball' },

        -- Tag class & name of the object to represent the bomb explosion effect:
        --
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },

        -- Bomb spawn coordinates (x,y,z):
        --
        spawn_location = { 65.749, -120.409, 0.118 },

        -- Base location coordinates:
        -- Format: { x, y, z, trigger radius }
        -- A player must be with the trigger radius to activate or defuse the bomb.
        --
        base_locations = {
            ['red'] = { 95.687797546387, -159.44900512695, -0.10000000149012, 0.5 },
            ['blue'] = { 40.240600585938, -79.123199462891, -0.10000000149012, 0.5 }
        }
    },

    ["deathisland"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -30.282, 31.312, 16.601 },
        base_locations = {
            ['red'] = { -26.576030731201, -6.9761986732483, 9.6631727218628, 0.5 },
            ['blue'] = { 29.843469619751, 15.971487045288, 8.2952880859375, 0.5 }
        }
    },

    ["icefields"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -26.032, 32.365, 9.007 },
        base_locations = {
            ['red'] = { 24.85000038147, -22.110000610352, 2.1110000610352, 0.5 },
            ['blue'] = { -77.860000610352, 86.550003051758, 2.1110000610352, 0.5 }
        }
    },

    ["infinity"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 9.631, -64.030, 7.776 },
        base_locations = {
            ['red'] = { 0.67973816394806, -164.56719970703, 15.039022445679, 0.5 },
            ['blue'] = { -1.8581243753433, 47.779975891113, 11.791272163391, 0.5 }
        }
    },

    ["sidewinder"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 2.051, 55.220, -2.801 },
        base_locations = {
            ['red'] = { -32.038200378418, -42.066699981689, -3.7000000476837, 0.5 },
            ['blue'] = { 30.351499557495, -46.108001708984, -3.7000000476837, 0.5 }
        }
    },

    ["timberland"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 1.250, -1.487, -21.264 },
        base_locations = {
            ['red'] = { 17.322099685669, -52.365001678467, -17.751399993896, 0.5 },
            ['blue'] = { -16.329900741577, 52.360000610352, -17.741399765015, 0.5 }
        }
    },

    ["dangercanyon"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -0.477, 55.331, 0.239 },
        base_locations = {
            ['red'] = { -12.104507446289, -3.4351840019226, -2.2419033050537, 0.5 },
            ['blue'] = { 12.007399559021, -3.4513700008392, -2.2418999671936, 0.5 }
        }
    },

    ["beavercreek"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 14.015, 14.238, -0.911 },
        base_locations = {
            ['red'] = { 29.055599212646, 13.732000350952, -0.10000000149012, 0.5 },
            ['blue'] = { -0.86037802696228, 13.764800071716, -0.0099999997764826, 0.5 }
        }
    },

    ["boardingaction"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 4.374, -12.832, 7.220 },
        base_locations = {
            ['red'] = { 1.723109960556, 0.4781160056591, 0.60000002384186, 0.5 },
            ['blue'] = { 18.204000473022, -0.53684097528458, 0.60000002384186, 0.5 }
        }
    },

    ["carousel"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 0.033, 0.003, -0.856 },
        base_locations = {
            ['red'] = { 5.6063799858093, -13.548299789429, -3.2000000476837, 0.5 },
            ['blue'] = { -5.7499198913574, 13.886699676514, -3.2000000476837, 0.5 }
        }
    },

    ["chillout"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 1.392, 4.700, 3.108 },
        base_locations = {
            ['red'] = { 7.4876899719238, -4.49059009552, 2.5, 0.5 },
            ['blue'] = { -7.5086002349854, 9.750340461731, 0.10000000149012, 0.5 }
        }
    },

    ["damnation"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -2.002, -4.301, 3.399 },
        base_locations = {
            ['red'] = { 9.6933002471924, -13.340399742126, 6.8000001907349, 0.5 },
            ['blue'] = { -12.17884349823, 14.982703208923, -0.20000000298023, 0.5 }
        }
    },

    ["gephyrophobia"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 63.513, -74.088, -1.062 },
        base_locations = {
            ['red'] = { 26.884338378906, -144.71551513672, -16.049139022827, 0.5 },
            ['blue'] = { 26.727857589722, 0.16621616482735, -16.048349380493, 0.5 }
        }
    },

    ["hangemhigh"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 21.020, -4.632, -4.229 },
        base_locations = {
            ['red'] = { 13.047902107239, 9.0331249237061, -3.3619771003723, 0.5 },
            ['blue'] = { 32.655700683594, -16.497299194336, -1.7000000476837, 0.5 }
        }
    },

    ["longest"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -0.84, -14.54, 2.41 },
        base_locations = {
            ['red'] = { -12.791899681091, -21.6422996521, -0.40000000596046, 0.5 },
            ['blue'] = { 11.034700393677, -7.5875601768494, -0.40000000596046, 0.5 }
        }
    },

    ["prisoner"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 0.902, 0.088, 1.392 },
        base_locations = {
            ['red'] = { -9.3684597015381, -4.9481601715088, 5.6999998092651, 0.5 },
            ['blue'] = { 9.3676500320435, 5.1193399429321, 5.6999998092651, 0.5 }
        }
    },

    ["putput"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -2.350, -21.121, 0.902 },
        base_locations = {
            ['red'] = { -18.89049911499, -20.186100006104, 1.1000000238419, 0.5 },
            ['blue'] = { 34.865299224854, -28.194700241089, 0.10000000149012, 0.5 }
        }
    },

    ["ratrace"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { 8.662, -11.159, 0.221 },
        base_locations = {
            ['red'] = { -4.2277698516846, -0.85564690828323, -0.40000000596046, 0.5 },
            ['blue'] = { 18.613000869751, -22.652599334717, -3.4000000953674, 0.5 }
        }
    },

    ["wizard"] = {
        bomb = { 'weap', 'weapons\\ball\\ball' },
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        spawn_location = { -5.035, -5.064, -2.750 },
        base_locations = {
            ['red'] = { -9.2459697723389, 9.3335800170898, -2.5999999046326, 0.5 },
            ['blue'] = { 9.1828498840332, -9.1805400848389, -2.5999999046326, 0.5 }
        }
    },
}

-------------------------------
-- CONFIGURATION ENDS HERE
-------------------------------

local map
local bomb
local bomb_planted
local explosion_timer
local announce_respawn

local players = { }
local time = os.time

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function Sabotage:newPlayer(o)

    setmetatable(o, { __index = self })
    self.__index = self

    return o
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

function Sabotage:bombHeld()
    for i, v in pairs(players) do
        local dyn = get_dynamic_player(i)
        return (dyn ~= 0 and player_alive(i) and v.has_bomb) or false
    end
    return false
end

function Sabotage:spawnBomb()

    local x = map.spawn_location[1]
    local y = map.spawn_location[2]
    local z = map.spawn_location[3]

    z = z + 0.5

    local meta_id = bomb.meta_id

    local object = spawn_object('', '', x, y, z, 0, meta_id)
    local object_mem = get_object_memory(object)
    if (object_mem ~= 0) then
        bomb.object = object
        bomb.object_mem = object_mem
    end
end

function Sabotage:newTimer(finish)
    return {
        start = time,
        finish = time() + finish
    }
end

local function say(Ply, Msg)
    local prefix = Sabotage.prefix
    if (not Ply) then
        execute_command('msg_prefix ""')
        say_all(Msg)
        execute_command('msg_prefix "' .. prefix .. '"')
        return
    end
    for _ = 1, 25 do rprint(Ply, ' ') end
    rprint(Ply, '|c' .. Msg)
end

local function progressBar(start, finish, plant_time)

    local bar = ''
    local time_remaining = finish - start()

    for i = 1, time_remaining do
        if (i > (time_remaining / finish) * plant_time) then
            bar = bar .. '='
        end
    end

    return bar
end

local function getOppositeTeam(team)
    return (team == 'red' and 'blue' or 'red')
end

function Sabotage:plantBomb(timer)

    local start = timer.start
    local finish = timer.finish

    if (start() >= finish) then

        -- prevent interaction with bomb:
        execute_command('disable_object ' .. '"' .. map.bomb[2] .. '" 0')

        -- Force player to drop bomb:
        drop_weapon(self.id)

        -- set the team bomb belongs to:
        bomb.team = getOppositeTeam(self.team)

        bomb_planted = true

        explosion_timer = self:newTimer(self.explosion_delay)

        say(_, 'Bomb has been planted!')
        return
    end

    local bar = progressBar(start, finish, self.plant_time)
    say(self.id, 'Planting the bomb [' .. bar .. ']')

    for i = 1, 16 do
        if (i ~= self.id) then
            say(i, self.name .. ' is planting the bomb!')
        end
    end
end

local function updateTeamScore(team)
    local score = (team == 'red' and get_var(0, '$redscore') or get_var(0, '$bluescore'))
    execute_command("team_score " .. team .. " " .. score + 100000)
end

function Sabotage:defuseBomb(timer)

    local start = timer.start
    local finish = timer.finish

    if (not bomb.defuser) then
        bomb.defuser = self.id
    end

    if (self.id ~= bomb.defuser) then
        say(self.id, players[bomb.defuser].name .. ' is already defusing the bomb!')
        return
    elseif (start() >= finish) then
        updateTeamScore(bomb.team)
        destroy_object(bomb.object)
        say(_, 'Bomb has been defused! ' .. bomb.team .. ' team won!')
        bomb, bomb_planted = nil, false
        return
    end

    local bar = progressBar(start, finish, self.plant_time)
    say(self.id, 'Defusing the bomb [' .. bar .. ']')
end

function OnStart()

    local game_type = (get_var(0, '$gt'))
    if (game_type ~= 'n/a') then

        local team_slayer = (get_var(0, '$ffa') == '0' and game_type == 'slayer')
        if (team_slayer) then

            bomb_planted, announce_respawn = false, false

            map = get_var(0, '$map')
            map = Sabotage[map]
            if (map) then

                execute_command('scorelimit 10000')
                execute_command('enable_object ' .. '"' .. map.bomb[2] .. '" 0')

                local bomb_meta = getTag(map.bomb[1], map.bomb[2])
                local bomb_effect_meta = getTag(map.explosion_effect[1], map.explosion_effect[2])

                bomb = {
                    meta_id = bomb_meta,
                    bomb_effect = bomb_effect_meta
                }

                players = { } -- reset the table (just in case)
                for i = 1, 16 do
                    if player_present(i) then
                        OnJoin(i)
                    end
                end

                register_callback(cb.EVENT_TICK, 'OnTick')
                register_callback(cb.EVENT_JOIN, 'OnJoin')
                register_callback(cb.EVENT_LEAVE, 'OnQuit')
                register_callback(cb.EVENT_DIE, 'SpawnDeath')
                register_callback(cb.EVENT_SPAWN, 'SpawnDeath')
                register_callback(cb.EVENT_TEAM_SWITCH, 'OnTeamSwitch')

                Sabotage:spawnBomb()
                return
            end

            unregister_callback(cb.EVENT_DIE)
            unregister_callback(cb.EVENT_TICK)
            unregister_callback(cb.EVENT_JOIN)
            unregister_callback(cb.EVENT_SPAWN)
            unregister_callback(cb.EVENT_LEAVE)
            unregister_callback(cb.EVENT_TEAM_SWITCH)
            error('Map not configured!')
        else
            error('This script only supports Team Slayer.')
        end
    end
end

local sqrt = math.sqrt
local function GetDist(x1, y1, z1, x2, y2, z2)
    local dist = ((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2)
    return sqrt(dist)
end

local function getXYZ(dyn)

    local x, y, z
    local vehicle = read_dword(dyn + 0x11C)
    local object = get_object_memory(vehicle)

    if (vehicle == 0xFFFFFFFF) then
        x, y, z = read_vector3d(dyn + 0x5C)
    elseif (object ~= 0) then
        x, y, z = read_vector3d(object + 0x5C)
    end

    return x, y, z
end

function Sabotage:hasBomb(dyn)
    for i = 0, 3 do
        local weapon = read_dword(dyn + 0x2F8 + 0x4 * i)
        local object = get_object_memory(weapon)
        if (weapon ~= 0xFFFFFFFF and object ~= 0) then
            local tag_address = read_word(object)
            local tag_data = read_dword(read_dword(0x40440000) + tag_address * 0x20 + 0x14)
            if (read_bit(tag_data + 0x308, 3) == 1) then
                self.has_bomb = true
                bomb.respawn_timer = nil
                return true
            end
        end
    end
    self.has_bomb = false -- just in case
    return false
end

function Sabotage:explode(x, y, z)
    local object = bomb.bomb_effect
    for _ = 1, 10 do
        local payload = spawn_projectile(object, 0, x, y, z)
        local projectile = get_object_memory(payload)
        if (payload and projectile ~= 0) then
            write_float(projectile + 0x68, 0)
            write_float(projectile + 0x6C, 0)
            write_float(projectile + 0x70, -9999)
        end
    end
end

local function UpdateVectors(object, x, y, z)

    -- update bomb x,y,z map coordinates:
    write_float(object + 0x5C, x)
    write_float(object + 0x60, y)
    write_float(object + 0x64, z)

    -- update bomb velocities:
    write_float(object + 0x68, 0) -- x vel
    write_float(object + 0x6C, 0) -- y vel
    write_float(object + 0x70, 0) -- z vel

    -- update bomb yaw, pitch, roll
    write_float(object + 0x90, 0) -- yaw
    write_float(object + 0x8C, 0) -- pitch
    write_float(object + 0x94, 0) -- roll
end

function Sabotage:respawnBomb()
    local bomb_held = self:bombHeld()
    if (bomb and not bomb_held and not bomb_planted) then

        local bx, by, bz = read_vector3d(bomb.object_mem + 0x5C)

        local x = map.spawn_location[1]
        local y = map.spawn_location[2]
        local z = map.spawn_location[3]

        local dist = GetDist(bx, by, bz, x, y, z)

        if (dist > 1 and not bomb.respawn_timer) then
            announce_respawn = true
            bomb.respawn_timer = self:newTimer(self.bomb_respawn_time)

        elseif (dist > 1 and bomb.respawn_timer) then

            local start = bomb.respawn_timer.start
            local finish = bomb.respawn_timer.finish

            local time_remaining = math.floor(finish - start())
            if (time_remaining == self.bomb_respawn_time / 2 and announce_respawn) then
                announce_respawn = false
                say(_, 'Bomb will respawn in ' .. finish - start() .. ' seconds.')
            elseif (time_remaining <= 0) then

                write_vector3d(bomb.object_mem + 0x5C, x, y, z + 0.3)
                -- 28/01/23
                write_bit(bomb.object_mem + 0x10, 5, 0)
                --

                bomb.respawn_timer = nil
                say(_, 'Bomb has respawned.')
            end
        end
    end
end

function Sabotage:onTick()

    if (bomb_planted) then

        local team = bomb.team
        local object = bomb.object_mem
        local loc = map.base_locations[team]
        local x, y, z = loc[1], loc[2], loc[3]
        UpdateVectors(object, x, y, z)

        local start = explosion_timer.start
        local finish = explosion_timer.finish

        if (start() >= finish) then

            team = getOppositeTeam(team)
            updateTeamScore(team)
            destroy_object(bomb.object)
            say(_, 'Bomb has exploded! ' .. team .. ' team won!')
            self:explode(x, y, z)

            bomb, bomb_planted = nil, false
            return
        else
            for i, _ in pairs(players) do
                say(i, 'Bomb will explode in ' .. (finish - start()) .. ' seconds!')
            end
        end
    end

    for i, v in pairs(players) do

        local dyn = get_dynamic_player(i)
        if (player_alive(i) and dyn ~= 0) then

            local has_bomb = v:hasBomb(dyn)
            if (has_bomb and not bomb_planted) then

                local px, py, pz = getXYZ(dyn)
                local team = getOppositeTeam(v.team)
                local loc = map.base_locations[team]

                local bx, by, bz = loc[1], loc[2], loc[3]
                local radius = loc[4]
                local dist = GetDist(px, py, pz, bx, by, bz)
                local crouching = read_bit(dyn + 0x208, 0)

                if (dist <= radius and crouching == 1) then
                    if (not v.timer) then
                        v.timer = v:newTimer(v.plant_time)
                    else
                        v:plantBomb(v.timer)
                    end
                else
                    v.timer = nil
                end
            elseif (bomb_planted and v.team == bomb.team) then

                local loc = map.base_locations[bomb.team]
                local bx, by, bz = loc[1], loc[2], loc[3]
                local radius = loc[4]
                local px, py, pz = getXYZ(dyn)
                local crouching = read_bit(dyn + 0x208, 0)
                local dist = GetDist(px, py, pz, bx, by, bz)

                if (dist <= radius and crouching == 1) then
                    if (not v.timer) then
                        v.timer = v:newTimer(self.defuse_time)
                    else
                        v:defuseBomb(v.timer)
                    end
                else
                    v.timer = nil
                    bomb.defuser = nil
                end
            end
        end
    end

    self:respawnBomb()
end

function OnJoin(Ply)
    players[Ply] = Sabotage:newPlayer({
        id = Ply,
        name = get_var(Ply, '$name'),
        team = get_var(Ply, '$team')
    })
end

function OnQuit(Ply)
    players[Ply] = nil
    if (#players ==0 and bomb) then
        bomb_planted = false
        bomb.respawn_timer = Sabotage:newTimer(0)
        execute_command('enable_object ' .. '"' .. map.bomb[2] .. '" 0')
    end
end

function OnTeamSwitch(Ply)
    players[Ply].team = get_var(Ply, '$team')
end

function OnTick()
    Sabotage:onTick()
end

function SpawnDeath(Ply)
    local player = players[Ply]
    player.timer = nil
    player.has_bomb = false
    if (bomb and bomb.defuser) then
        bomb.defuser = (Ply == bomb.defuser) and nil or bomb.defuser
    end
end

function OnScriptUnload()
    -- N/A
end