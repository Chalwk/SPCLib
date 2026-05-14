--[[
=====================================================================================
SCRIPT NAME:      self_destruction.lua
DESCRIPTION:      Allows players to self-destruct using the flashlight key,
                  with configurable cooldown period and explosion effects.

FEATURES:
                 - Flashlight-key activated self-destruction
                 - Configurable cooldown timer between uses
                 - Customizable explosion projectile and count
                 - Optional cooldown reset on spawn
                 - Ready notification system

CONFIGURATION:
                 - cooldown: Time between detonations (seconds)
                 - explosion_effect: Projectile tag for explosion
                 - projectile_count: Number of spawned projectiles
                 - reset_on_spawn: Reset cooldown when respawning
                 - on_ready: Custom ready notification message

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- [ config ] --
-- Time (in seconds) between player detonations:
local cooldown = 60

-- Projectile tag used to simulate explosion:
local explosion_effect = "weapons\\rocket launcher\\rocket"

-- # of projectiles spawned:
local projectile_count = 5

-- Reset cooldown on spawn?
local reset_on_spawn = true

-- Message sent to player when self-destruction is ready:
local on_ready = "Self-Destruction ready! Use flashlight key to detonate."

api_version = "1.12.0.0"
------------------------

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    OnGameStart()
end

local players = { }
local time_scale = 1 / 30

local function InitPlayer(Ply, Reset)
    if (not Reset) then
        players[Ply] = { 0, 0, false }
        return
    end
    players[Ply] = nil
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        players = { }
        for i = 1, 16 do
            if player_present(i) then
                InitPlayer(i, false)
            end
        end
    end
end

function OnJoin(Ply)
    InitPlayer(Ply, false)
end

function OnQuit(Ply)
    InitPlayer(Ply, true)
end

function OnSpawn(Ply)
    if (reset_on_spawn) then
        InitPlayer(Ply, false)
    end
end

local function GetPos(Ply)
    local DyN = get_dynamic_player(Ply)
    if (DyN ~= 0) then
        local VehicleID = read_dword(DyN + 0x11C)
        if (VehicleID == 0xFFFFFFFF) then
            return DyN, read_vector3d(DyN + 0x5c)
        end
    end
    return nil
end

local function GetTag(Type, Name)
    local Tag = lookup_tag(Type, Name)
    return Tag ~= 0 and read_dword(Tag + 0xC) or nil
end

function OnTick()
    for i, v in pairs(players) do

        local DyN, x, y, z = GetPos(i)
        if (DyN and x) then

            -- check if player pressed flashlight key:
            local flashlight = read_bit(DyN + 0x208, 4)
            local case = (v[2] ~= flashlight and flashlight == 1 and v[1] == 0)
            if (case) then

                local tag = GetTag("proj", explosion_effect)
                if (tag) then

                    -- init cooldown timer:
                    v[3] = true
                    --

                    -- spawn projectile:
                    for _ = 1, projectile_count do
                        local explosion = spawn_projectile(tag, i, x, y, z + 0.3)
                        local object = get_object_memory(explosion)
                        if (explosion and object ~= 0) then
                            write_float(object + 0x68, 0)
                            write_float(object + 0x6C, 0)
                            write_float(object + 0x70, -10)
                        end
                    end
                    --

                end
            end
            v[2] = flashlight
        end

        -- cooldown timer:
        if (v[3]) then
            v[1] = v[1] + time_scale
            if (v[1] >= cooldown) then
                v[1], v[3] = 0, false
                rprint(i, on_ready)
            end
        end
    end
end

function OnScriptUnload()
    -- N/A
end