--[[
=====================================================================================
SCRIPT NAME:      spawn_from_sky.lua
DESCRIPTION:      Makes players spawn high above the ground (35 world units) when joining,
                  creating a dramatic falling spawn effect.

FEATURES:
                 - Configurable spawn heights per map
                 - Team-specific spawn locations (Red/Blue)
                 - Automatic un-godding when players land
                 - Supports all standard Halo CE maps
                 - Lightweight and efficient implementation

CONFIGURATION:
                 - Edit the 'maps' table to:
                   * Add new maps
                   * Adjust spawn coordinates
                   * Modify spawn heights (35 = default)
                 - First array position = Red team
                 - Second array position = Blue team

NOTES:
                 - 1 world unit ≈ 10 feet (3.048 meters)
                 - Players are temporarily godded to prevent fall damage
                 - Works automatically with no player input needed

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

-- config begins --
local maps = {
    ['bloodgulch'] = {
        { 95.687797546387, -159.44900512695, -0.10000000149012, 35 },
        { 40.240600585938, -79.123199462891, -0.10000000149012, 35 },
    },
    ['beavercreek'] = {
        { 29.055599212646, 13.732000350952, -0.10000000149012, 35 },
        { -0.86037802696228, 13.764800071716, -0.0099999997764826, 35 },
    },
    ['boardingaction'] = {
        { 1.723109960556, 0.4781160056591, 0.60000002384186, 35 },
        { 18.204000473022, -0.53684097528458, 0.60000002384186, 35 },
    },
    ['carousel'] = {
        { 5.6063799858093, -13.548299789429, -3.2000000476837, 35 },
        { -5.7499198913574, 13.886699676514, -3.2000000476837, 35 },
    },
    ['chillout'] = {
        { 7.4876899719238, -4.49059009552, 2.5, 35 },
        { -7.5086002349854, 9.750340461731, 0.10000000149012, 35 },
    },
    ['dangercanyon'] = {
        { -12.104507446289, -3.4351840019226, -2.2419033050537, 35 },
        { 12.007399559021, -3.4513700008392, -2.2418999671936, 35 },
    },
    ['deathisland'] = {
        { -26.576030731201, -6.9761986732483, 9.6631727218628, 35 },
        { 29.843469619751, 15.971487045288, 8.2952880859375, 35 },
    },
    ['gephyrophobia'] = {
        { 26.884338378906, -144.71551513672, -16.049139022827, 35 },
        { 26.727857589722, 0.16621616482735, -16.048349380493, 35 },
    },
    ['icefields'] = {
        { 24.85000038147, -22.110000610352, 2.1110000610352, 35 },
        { -77.860000610352, 86.550003051758, 2.1110000610352, 35 },
    },
    ['infinity'] = {
        { 0.67973816394806, -164.56719970703, 15.039022445679, 35 },
        { -1.8581243753433, 47.779975891113, 11.791272163391, 35 },
    },
    ['sidewinder'] = {
        { -32.038200378418, -42.066699981689, -3.7000000476837, 35 },
        { 30.351499557495, -46.108001708984, -3.7000000476837, 35 },
    },
    ['timberland'] = {
        { 17.322099685669, -52.365001678467, -17.751399993896, 35 },
        { -16.329900741577, 52.360000610352, -17.741399765015, 35 },
    },
    ['hangemhigh'] = {
        { 13.047902107239, 9.0331249237061, -3.3619771003723, 35 },
        { 32.655700683594, -16.497299194336, -1.7000000476837, 35 },
    },
    ['ratrace'] = {
        { -4.2277698516846, -0.85564690828323, -0.40000000596046, 35 },
        { 18.613000869751, -22.652599334717, -3.4000000953674, 35 },
    },
    ['damnation'] = {
        { 9.6933002471924, -13.340399742126, 6.8000001907349, 35 },
        { -12.17884349823, 14.982703208923, -0.20000000298023, 35 },
    },
    ['putput'] = {
        { -18.89049911499, -20.186100006104, 1.1000000238419, 35 },
        { 34.865299224854, -28.194700241089, 0.10000000149012, 35 },
    },
    ['prisoner'] = {
        { -9.3684597015381, -4.9481601715088, 5.6999998092651, 35 },
        { 9.3676500320435, 5.1193399429321, 5.6999998092651, 35 },
    },
    ['wizard'] = {
        { -9.2459697723389, 9.3335800170898, -2.5999999046326, 35 },
        { 9.1828498840332, -9.1805400848389, -2.5999999046326, 35 },
    },
    ['longest'] = {
        { -12.791899681091, -21.6422996521, -0.40000000596046, 35 },
        { 11.034700393677, -7.5875601768494, -0.40000000596046, 35 },
    }
}
-- config ends --

local coords = {}
local players = { }

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then

        local map = get_var(0, '$map')
        if (maps[map]) then
            coords = maps[map]
            register_callback(cb['EVENT_TICK'], 'OnTick')
            register_callback(cb['EVENT_JOIN'], 'OnJoin')
            register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
            register_callback(cb['EVENT_PRESPAWN'], 'OnPreSpawn')
        else
            register_callback(cb['EVENT_JOIN'])
            register_callback(cb['EVENT_TICK'])
            register_callback(cb['EVENT_SPAWN'])
            register_callback(cb['EVENT_PRESPAWN'])
        end
    end
end

function OnTick()
    for i, enabled in pairs(players) do
        local dyn = get_dynamic_player(i)
        if (enabled and player_alive(i) and dyn ~= 0) then
            local state = read_byte(dyn + 0x2A3) -- un-god player when they hit the ground
            if (state == 21 or state == 22) then
                execute_command('ungod ' .. i)
                write_word(dyn + 0x104, 0)
                players[i] = nil
            end
        end
    end
end

function OnJoin(playerId)
    players[playerId] = true
end

function OnSpawn(playerId)
    if (players[playerId]) then
        execute_command('god ' .. playerId)
    end
end

function OnPreSpawn(playerId)
    if (not players[playerId]) then
        return
    end

    local dyn = get_dynamic_player(playerId)
    if (dyn == 0) then
        return
    end

    local team = get_var(playerId, '$team')
    local x, y, z, h = unpack(coords[team == 'red' and 1 or 2])
    write_vector3d(dyn + 0x5C, x, y, z + h)
end