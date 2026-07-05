--[[
===============================================================================
SCRIPT NAME:      freeze_players.lua
DESCRIPTION:      Player freezing system with:
                  - Freeze/unfreeze commands
                  - Weapon management options
                  - Customizable notifications
                  - Admin permission controls

FEATURES:
                  - Movement restriction
                  - Weapon removal/restoration
                  - God mode toggle
                  - Chat restrictions
                  - Multi-target support

CONFIGURATION:    Adjust these settings:
                  - freeze_command: Freeze command name
                  - unfreeze_command: Unfreeze command name
                  - permission_level: Required admin level
                  - messages: Custom notification texts
                  - god_mode: Toggle invulnerability
                  - take_weapons: Toggle weapon removal

Copyright (c) 2020 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config [Starts] ----------------------------------------------------------------

-- Syntax: /freeze_command [player id]
local freeze_command = "freeze"

-- Syntax: /unfreeze_command [player id]
local unfreeze_command = "unfreeze"

-- If true, you can freeze yourself if you have permission (see setting "permission_level").
local freeze_self = true

-- If true, all players (including target) will be notified that the target was frozen.
-- Doesn't require setting "tell_victim" to be false.
local tell_all = false

-- If true, the victim will be notified that they were frozen (requires setting "tell_all" to be false!)
local tell_victim = true

-- If true, the victim will be put into god mode.
local god_mode = true

-- TAKE|RESTORE player weapons on freeze\unfreeze
local take_weapons = true
local restore_weapons = true

-- If false, frozen players will not be able to chat!
local chat = false

-- Minimum permission level required to execute /freeze_command or /unfreeze_command
local permission_level = 1

local messages = {
    [1] = {
        "You were %state% by %executor_name%",
        "You %state% %target_name%",
        "%target_name% was %state% by %executor_name%"
    },
    [2] = "%target_name% is already frozen!",
    [3] = "%target_name% is already unfrozen!",
    [4] = "Invalid Player ID. Usage: /%cmd% [number: 1-16] | */all | me",
    [5] = "You do not have permission to execute this command!",
    [6] = "You cannot %state% yourself!",
    [7] = "Your message was not sent. You are frozen!"
}
-- Config [Ends] ----------------------------------------------------------------

api_version = "1.12.0.0"

local players = {}
local gsub, lower, upper, gmatch = string.gsub, string.lower, string.upper, string.gmatch

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnPlayerChat")
    register_callback(cb.EVENT_SPAWN, "OnPlayerSpawn")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
    register_callback(cb.EVENT_LEAVE, "OnPlayerDisconnect")

    if get_var(0, "$gt") ~= "n/a" then
        players = {}
        for i = 1, 16 do
            if player_present(i) then
                InitPlayer(i, false)
            end
        end
    end
end

function OnGameStart()
    if get_var(0, "$gt") ~= "n/a" then
        players = {}
    end
end

function OnPlayerSpawn(PlayerIndex)
    InitPlayer(PlayerIndex, false)
end

function OnPlayerDisconnect(PlayerIndex)
    InitPlayer(PlayerIndex, true)
end

function InitPlayer(PlayerIndex, Reset)
    players[PlayerIndex] = players[PlayerIndex] or {}

    if (Reset) then
        players[PlayerIndex] = {}
    elseif (not players[PlayerIndex].frozen) then
        players[PlayerIndex] = { speed = 0, frozen = false, inventory = {} }
    elseif (players[PlayerIndex].frozen) then
        DelInventory(PlayerIndex)
    end
end

function OnScriptUnload()
end

function OnServerCommand(Executor, Command, _, _)
    local Args = CmdSplit(Command)
    if (Args == nil) then
        return
    else
        Args[1] = (lower(Args[1]) or upper(Args[1]))
        if (Args[1] == freeze_command) then
            if HasAccess(Executor) then
                ValidateCMD(Executor, Args, 1)
            end
            return false
        elseif (Args[1] == unfreeze_command) then
            if HasAccess(Executor) then
                ValidateCMD(Executor, Args, 2)
            end
            return false
        end
    end
end

function OnPlayerChat(PlayerIndex, Message, Type)
    if (Type ~= 6) then
        local PreventChat = (players[PlayerIndex].frozen) and (not chat)
        if (PreventChat) then
            rprint(PlayerIndex, messages[7])
            return false
        end
    end
end

function ValidateCMD(Executor, Args, Type)
    local pl = GetPlayers(Executor, Args)
    if (#pl > 0) then
        for i = 1, #pl do
            local TargetID = pl[i]
            local DynamicPlayer = get_dynamic_player(TargetID)
            if (DynamicPlayer ~= 0) then
                if Proceed(Executor, TargetID, Type) then
                    local Check = CheckPlayer(TargetID, Type)
                    if Check then
                        local player = get_player(TargetID)
                        if (Type == 1) and (player) then
                            players[TargetID].frozen = true
                            players[TargetID].speed = read_float(player + 0x6c)

                            safe_write(true)
                            write_float(player + 0x6c, 0)
                            if (god_mode) then
                                write_float(DynamicPlayer + 0xE0, 99999999)
                                write_float(DynamicPlayer + 0xE4, 99999999)
                            end
                            safe_write(false)
                            Send(Executor, messages[1], TargetID, Type)

                            if (take_weapons) then
                                TakeWeapons(TargetID, DynamicPlayer)
                            end
                        elseif (Type == 2) and (player) then
                            players[TargetID].frozen = false
                            safe_write(true)
                            write_float(player + 0x6c, players[TargetID].speed)

                            if (god_mode) then
                                write_float(DynamicPlayer + 0xE0, 1)
                                write_float(DynamicPlayer + 0xE4, 1)
                            end

                            safe_write(false)
                            Send(Executor, messages[1], TargetID, Type)

                            if (take_weapons and restore_weapons) then
                                RestoreWeapons(TargetID, DynamicPlayer)
                            end
                        end
                    else
                        rprint(Executor, Check)
                    end
                end
            end
        end
    end
end

function Proceed(Executor, TargetID, Type)
    local state = ""
    if (Type == 1) then
        state = "freeze"
    elseif (Type == 2) then
        state = "unfreeze"
    end

    local case = (freeze_self == false and Executor == TargetID)
    if (case) then
        return rprint(Executor, gsub(messages[6], "%%state%%", state))
    end

    return true
end

function CheckPlayer(TargetID, Type)
    if (Type == 1 and players[TargetID].frozen) then
        return gsub(messages[3], "%%target_name%%", get_var(TargetID, "$name"))
    elseif (Type == 2 and not players[TargetID].frozen) then
        return gsub(messages[4], "%%target_name%%", get_var(TargetID, "$name"))
    end
    return true
end

function GetPlayers(Executor, Args)
    local pl = {}
    if (Args[2] == nil or Args[2] == "me") then
        table.insert(pl, Executor)
    elseif (Args[2]:match("%d+") and player_present(Args[2])) then
        table.insert(pl, Args[2])
    elseif (Args[2] == "all" or Args[2] == "*") then
        for i = 1, 16 do
            table.insert(pl, i)
        end
    else
        rprint(Executor, gsub(messages[4], "%%cmd%%", Args[1]))
    end
    return pl
end

function Send(Executor, Message, TargetID, Type)
    local state = {}
    local t_name = get_var(TargetID, "$name")
    local e_name = get_var(Executor, "$name")

    if (Type == 1) then
        state[1], state[2] = "frozen", "froze"
    elseif (Type == 2) then
        state[1], state[2] = "unfrozen", "unfroze"
    end

    local to_executor = gsub(gsub(Message[2], "%%target_name%%", t_name), "%%state%%", state[2])
    rprint(Executor, to_executor)

    if (tell_all) then
        for i = 1, 16 do
            if player_present(i) then
                if (i ~= Executor) then
                    local msg = gsub(
                        gsub(gsub(Message[3], "%%target_name%%", t_name), "%%executor_name%%", e_name), "%%state%%",
                        state[1]
                    )
                    rprint(TargetID, msg)
                end
            end
        end
    elseif (tell_victim and Executor ~= TargetID) then
        local msg = gsub(gsub(Message[1], "%%executor_name%%", e_name), "%%state%%", state[1])
        rprint(TargetID, msg)
    end
end

function CmdSplit(Cmd)
    local t, i = {}, 1
    for Args in gmatch(Cmd, "([^%s]+)") do
        t[i] = Args
        i = i + 1
    end
    return t
end

function HasAccess(Executor)
    local lvl = tonumber(get_var(Executor, "$lvl"))
    if (lvl >= permission_level) then
        return true
    else
        rprint(Executor, messages[5])
    end
end

local function saveInventory(playerId, type)
    local dynamic_player = get_dynamic_player(playerId)
    if not player_alive(playerId) or dynamic_player == 0 then
        return
    end
    for i = 0, 3 do
        local equipment = get_object_memory(read_dword(dynamic_player + 0x2F8 + i * 4))
        if (equipment ~= 0) then
            players[playerId][type].inventory[i + 1] = {
                ["id"] = read_dword(equipment),
                ["ammo"] = read_word(equipment + 0x2B6),
                ["clip"] = read_word(equipment + 0x2B8),
                ["ammo2"] = read_word(equipment + 0x2C6),
                ["clip2"] = read_word(equipment + 0x2C8),
                ["age"] = read_float(equipment + 0x240),
                ['frags'] = read_byte(dynamic_player + 0x31E),
                ['plasmas'] = read_byte(dynamic_player + 0x31F)
            }
        end
    end
end

local function loadInventory(playerId, type)
    local dynamic_player = get_dynamic_player(playerId)
    if not player_alive(playerId) or dynamic_player == 0 then
        return
    end
    local inventory = players[playerId][type].inventory
    for i = 0, 3 do
        local equipment = get_object_memory(read_dword(dynamic_player + 0x2F8 + i * 4))
        if (equipment ~= 0) then
            write_dword(equipment, inventory[i + 1].id)
            write_word(equipment + 0x2B6, inventory[i + 1].ammo)
            write_word(equipment + 0x2B8, inventory[i + 1].clip)
            write_word(equipment + 0x2C6, inventory[i + 1].ammo2)
            write_word(equipment + 0x2C8, inventory[i + 1].clip2)
            write_float(equipment + 0x240, inventory[i + 1].age)
        end
    end
    write_byte(dynamic_player + 0x31E, inventory.frags)
    write_byte(dynamic_player + 0x31F, inventory.plasmas)
end

function TakeWeapons(TargetID, DynamicPlayer)
    for i = 0, 3 do
        local equipment = get_object_memory(read_dword(DynamicPlayer + 0x2F8 + i * 4))
        if (equipment ~= 0) then
            players[TargetID].inventory[i + 1] = {
                ["id"] = read_dword(equipment),
                ["ammo"] = read_word(equipment + 0x2B6),
                ["clip"] = read_word(equipment + 0x2B8),
                ["ammo2"] = read_word(equipment + 0x2C6),
                ["clip2"] = read_word(equipment + 0x2C8),
                ["age"] = read_float(equipment + 0x240)
            }
        end
    end

    local frags = read_byte(DynamicPlayer + 0x31E)
    local plasmas = read_byte(DynamicPlayer + 0x31F)

    players[TargetID].inventory.frag_grenades = frags
    players[TargetID].inventory.plasma_grenades = plasmas

    DelInventory(TargetID)
end

function RestoreWeapons(TargetID, DynamicPlayer)
    local x, y, z = read_vector3d(DynamicPlayer + 0x5C)
    local inventory = players[TargetID].inventory

    for _, eqip in pairs(inventory) do
        if (type(eqip) == "table") then
            local Weapon = spawn_object("null", "null", x, y, z + 0.3, 90, eqip.id)
            local weapon_object = get_object_memory(Weapon)
            write_word(weapon_object + 0x2B6, eqip.ammo)
            write_word(weapon_object + 0x2B8, eqip.clip)
            write_word(weapon_object + 0x2C6, eqip.ammo2)
            write_word(weapon_object + 0x2C8, eqip.clip2)
            write_float(weapon_object + 0x240, eqip.age)
            sync_ammo(Weapon)
            assign_weapon(Weapon, TargetID)
        end
    end

    write_byte(DynamicPlayer + 0x31E, inventory.frag_grenades)
    write_byte(DynamicPlayer + 0x31F, inventory.plasma_grenades)

    players[TargetID].inventory = {}
end

function DelInventory(TargetID)
    local DynamicPlayer = get_dynamic_player(TargetID)

    write_word(DynamicPlayer + 0x31E, 0)
    write_word(DynamicPlayer + 0x31F, 0)

    local WeaponID = read_dword(DynamicPlayer + 0x118)
    if (WeaponID ~= 0) then
        for j = 0, 3 do
            local WeapObject = read_dword(DynamicPlayer + 0x2F8 + j * 4)
            destroy_object(WeapObject)
        end
    end
end
