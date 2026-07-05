--[[
=====================================================================================
SCRIPT NAME:      on_teleport.lua
DESCRIPTION:      Teleportation detection system for player movement monitoring

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local max_distance = 10
local players = {}

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function OnJoin(playerId)
    players[playerId] = {
        name = get_var(playerId, '$name'),
        old_pos = { 0, 0, 0 },
        new_pos = { 0, 0, 0 },
        get_old = true
    }
end

function OnQuit(playerId)
    players[playerId] = nil
end

function OnSpawn(playerId)
    if players[playerId] then
        players[playerId].get_old = true
    end
end

local function GetPlayerPosition(dynamicPlayer)
    local x, y, z
    local vehicle = read_dword(dynamicPlayer + 0x11C)
    local object = get_object_memory(vehicle)

    if vehicle == 0xFFFFFFFF then
        x, y, z = read_vector3d(dynamicPlayer + 0x5C)
    elseif object ~= 0 then
        x, y, z = read_vector3d(object + 0x5C)
    end

    return x, y, z
end

local function CalculateDistance(old_pos, new_pos)
    local dx = old_pos[1] - new_pos[1]
    local dy = old_pos[2] - new_pos[2]
    local dz = old_pos[3] - new_pos[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function OnTeleport(player)
    print(player.name .. ' teleported')
    -- Add additional logic here
end

function OnTick()
    for i, player in pairs(players) do
        local dynamicPlayer = get_dynamic_player(i)
        if dynamicPlayer ~= 0 and player_alive(i) then
            if player.get_old then
                player.old_pos = { GetPlayerPosition(dynamicPlayer) }
                player.get_old = false
            else
                player.new_pos = { GetPlayerPosition(dynamicPlayer) }
                local distance = CalculateDistance(player.old_pos, player.new_pos)
                if distance > max_distance then
                    OnTeleport(player)
                end
                player.old_pos = player.new_pos
                player.get_old = true
            end
        end
    end
end

function OnScriptUnload()
    -- N/A
end
