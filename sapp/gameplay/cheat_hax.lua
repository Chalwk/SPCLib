-- CONFIG start -------------------------------------

local HAX_COMMAND = "hax"
local REQUIRED_LEVEL = 4
-- CONFIG end ---------------------------------------

api_version = '1.12.0.0'

local gametype
local slayer_globals, oddball_globals, gametype_base

local function parseArgs(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function hasPermission(id)
    return tonumber(get_var(id, '$lvl')) >= REQUIRED_LEVEL
end

local function setscore(playerId, score, static_player)
    if gametype == 'ctf' then
        write_short(static_player + 0xC8, score)
    elseif gametype == 'slayer' then
        write_int(slayer_globals + 0x40 + playerId * 4, score)
    elseif gametype == 'oddball' then
        local oddball_game = read_byte(gametype_base + 0x8C)
        if oddball_game == 0 or oddball_game == 1 then
            write_int(oddball_globals + 0x84 + playerId * 4, score * 30)
        else
            write_int(oddball_globals + 0x84 + playerId * 4, score)
        end
    elseif gametype == 'king' then
        write_short(static_player + 0xC4, score * 30)
    elseif gametype == 'race' then
        write_short(static_player + 0xC6, score)
    end
end

function OnScriptLoad()
    if halo_type == 'PC' then
        slayer_globals = 0x63A0E8
        oddball_globals = 0x639E58
        gametype_base = 0x671340
    elseif halo_type == 'CE' then
        slayer_globals = 0x5BE108
        oddball_globals = 0x5BDE78
        gametype_base = 0x5F5498
    end

    register_callback(cb['EVENT_COMMAND'], "OnCommand")
    register_callback(cb['EVENT_GAME_START'], "OnStart")
    OnStart()
end

function OnStart()
    gametype = tonumber(get_var(0, '$gt'))
end

function OnCommand(id, command)
    if id == 0 then return true end

    local args = parseArgs(command)
    if #args == 0 then return end

    if args[1]:lower() == HAX_COMMAND then
        if hasPermission(id) then
            local target_id = tonumber(args[2])
            if not target_id or not player_present(target_id) then
                rprint(id, 'Player #' .. target_id .. ' is not online.')
                return false
            end

            local static_player = get_player(target_id)
            if static_player == 0 or not player_alive(target_id) then
                rprint(id, 'Player #' .. target_id .. ' is alive.')
                return false
            end

            setscore(static_player, 9999)
            write_short(static_player + 0x9C, 9999)
            write_short(static_player + 0xA4, 9999)
            write_short(static_player + 0xAC, 9999)
            write_short(static_player + 0xAE, 9999)
            write_short(static_player + 0xB0, 9999)
            rprint(id, 'HAX applied to ' .. get_var(target_id, '$name') .. '.')
        end
        return false
    end
end

function OnScriptUnload() end
