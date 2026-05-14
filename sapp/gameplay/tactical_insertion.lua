--[[
=====================================================================================
SCRIPT NAME:      tactical_insertion.lua
DESCRIPTION:      Allows players to set custom spawn points using a command.
                  Players get limited uses per game.

COMMANDS:
                  /ti - Set your tactical insertion (spawn point)
                  (Automatically shows remaining uses on spawn)

CONFIGURATION:
                  command = 'ti'         - Command to set spawn point
                  uses_per_game = 5      - Uses allowed per player per game

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts
local command = 'ti'
local uses_per_game = 5

-- Messages
local messages = {
    no_uses_left = 'You have no more uses left for this game.',
    tac_insert_set = 'Tac-Insert set to: %s',
    uses_left = 'You have %s uses left for this game.',
    need_alive = 'You need to be alive to use this command.',
    will_spawn_at_tac = 'You will spawn at your Tac-Insert point.',
    spawn_uses_left = 'You have %s tac-insert uses left for this game.',
    set_command_help = 'Use /%s to set your next spawn point.'
}
-- config ends

api_version = '1.12.0.0'

local players = {}
local format = string.format

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_PRESPAWN, 'OnPreSpawn')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    players = {}
    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

local function getIP(id)
    return get_var(id, '$ip')
end

function OnJoin(id)
    players[getIP(id)] = {
        teleport = false,
        uses = uses_per_game,
        x = 0,
        y = 0,
        z = 0
    }
end

function OnQuit(id)
    players[getIP(id)] = nil
end

local function GetXYZ(id)
    local x, y, z

    local dyn = get_dynamic_player(id)
    if dyn == 0 then return nil end

    local vehicle = read_dword(dyn + 0x11C)
    local object = get_object_memory(vehicle)
    if vehicle == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn + 0x5C)
    else
        x, y, z = read_vector3d(object + 0x5c)
    end

    return x, y, z
end

function OnPreSpawn(id)
    local dyn = get_dynamic_player(id)
    if dyn == 0 then return end

    local p = players[getIP(id)]
    if p and p.teleport then
        p.teleport = false
        local x, y, z = p.x, p.y, p.z
        local z_off = 0.1
        write_vector3d(dyn + 0x5C, x, y, z + z_off)
    end
end

function OnCommand(id, CMD)
    if id > 0 and CMD:sub(1, command:len()):lower() == command then
        if player_alive(id) then
            local p = players[getIP(id)]
            if p.uses <= 0 then
                rprint(id, messages.no_uses_left)
                return false
            end

            p.uses = p.uses - 1

            local x, y, z = GetXYZ(id)
            p.teleport = true
            p.x = x
            p.y = y
            p.z = z

            rprint(id, format(messages.tac_insert_set, format('%.2f, %.2f, %.2f', x, y, z)))
            rprint(id, format(messages.uses_left, p.uses))
        else
            rprint(id, messages.need_alive)
        end

        return false
    end
end

function OnDeath(id)
    local p = players[getIP(id)]
    if p and p.teleport then
        rprint(id, messages.will_spawn_at_tac)
    end
end

function OnSpawn(id)
    local p = players[getIP(id)]
    rprint(id, format(messages.spawn_uses_left, p.uses))
    rprint(id, format(messages.set_command_help, command))
end

function OnScriptUnload() end