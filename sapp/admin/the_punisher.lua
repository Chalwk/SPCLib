--[[
=====================================================================================
SCRIPT NAME:      the_punisher.lua
DESCRIPTION:      Automated player punishment system for team betrayals and friendly fire.

FEATURES:
                  - Customizable punishment thresholds
                  - Progressive warning system
                  - Multiple punishment types (kill/kick/crash)
                  - Detailed offense tracking
                  - Configurable warning messages
                  - Respawn time adjustment
                  - Death penalty control

COMMANDS:         (Automatic - no player commands needed)

CONFIGURATION:
                  punish.betrayals = {    - Betrayal punishment settings:
                    actions = {
                      KILL = {use=true, warnings=5, respawn_time=10},
                      KICK = {use=false, warnings=5},
                      CRASH = {use=false, warnings=5}
                    }
                  }
                  punish.teamshooting = { - Teamshooting punishment settings
                    actions = {
                      KILL = {use=false, warnings=5},
                      KICK = {use=false, warnings=5},
                      CRASH = {use=true, warnings=5}
                    }
                  }
                  punish.duration = 5      - Message display duration
                  punish.message_alignment = "|l" - Message alignment

PUNISHMENT TYPES:
                  KILL  - Silently kills offender with configurable respawn
                  KICK  - Kicks offender from server
                  CRASH - Crashes offender's game client

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local punish = {}
local betray_warnings, teamshoot_warnings = { }, { }
local clear_console = { }
local globals = nil
local messages = { }
local gsub = string.gsub

function punish:Init()
    -- Configuration [starts] -----------------------------------------------------

    --===========================================================================--
    -- WARNING: ONLY ONE ACTION CAN BE ENABLED PER ACTION TABLE:
    -- I.e, 1 action for "punish.betrayals", 1 action for "punish.teamshooting".
    --===========================================================================--

    -- Message Alignment Setting: (Left = l, Right = r, Centre = c, Tab = t)
    punish.message_alignment = "|l"
    -- Messages will appear on screen for this many seconds:
    punish.duration = 5
    punish.server_prefix = "** SERVER ** "

    punish.betrayals = {
        actions = {
            ["KILL"] = { -- Player will be warned before being killed automatically.
                use = true, -- Set to false to disable 'kill action'
                warnings = 5, -- Player has this many warnings before action is taken:
                edit_respawn_time = true, -- If true, an offender's respawn time will be changed to "respawn_time":
                respawn_time = 10, -- Offenders will respawn after this many seconds (requires edit_respawn_time to be enabled)
                deduct_death = true, -- If true then players wont get a death penalty point:
                notify_console = true, -- If true, console will be notified when action is taken on an offender:
                -- Warning Message:
                message1 = "%offender_name%, do not betray or you will be punished! Warning: (%warnings_left%/%total_warnings%)",
                -- Action Message:
                message2 = '%offender_name%, was killed for betraying!',
            },
            ["KICK"] = {
                use = false,
                warnings = 5,
                notify_console = true,
                message1 = "%offender_name%, do not betray or you will be punished! Warning: (%warnings_left%/%total_warnings%)",
                message2 = '%offender_name% was kicked for betraying!',
            },
            ["CRASH"] = {
                use = false,
                warnings = 5,
                notify_console = true,
                message1 = "%offender_name%, do not betray or you will be punished! Warning: (%warnings_left%/%total_warnings%)",
                message2 = "%offender_name%'s game client was crashed (by server) for betraying!",
            },
        }
    }

    punish.teamshooting = {
        actions = {
            ["KILL"] = {
                use = false,
                warnings = 5,
                edit_respawn_time = true, respawn_time = 10, deduct_death = true,
                notify_console = true,
                message1 = "%offender_name%, do not Team-Shoot or you will be punished! Warning: (%warnings_left%/%total_warnings%)",
                message2 = '%offender_name%, was killed for Team Shooting!',
            },
            ["KICK"] = {
                use = false,
                warnings = 5,
                notify_console = true,
                message1 = "%offender_name%, do not Team-Shoot or you will be punished! Warning: (%warnings_left%/%total_warnings%)",
                message2 = '%offender_name% was kicked for Team Shooting!',
            },
            ["CRASH"] = {
                use = true,
                warnings = 5,
                notify_console = true,
                message1 = "%offender_name%, do not Team-Shoot or you will be punished! Warning: (%warnings_left%/%total_warnings%)",
                message2 = "%offender_name%'s game client was crashed (by server) for Team Shooting!",
            },
        }
    }
    -- Configuration [ends] -----------------------------------------------------
end

function OnScriptLoad()

    punish:Init()

    -- Register needed Event Callbacks:

    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")

    register_callback(cb.EVENT_BETRAY, "OnPlayerBetray")
    register_callback(cb.EVENT_DIE, "OnPlayerDeath")
    register_callback(cb.EVENT_JOIN, "OnPlayerConnect")
    register_callback(cb.EVENT_LEAVE, "OnPlayerDisconnect")

    if (get_var(0, "$gt") ~= "n/a") then
        punish:Reset()
    end

    local gp = sig_scan("8B3C85????????3BF9741FE8????????8B8E2C0200008B4610") + 3
    if (gp == 3) then
        return
    end
    globals = read_dword(gp)
end

function OnScriptUnload()
    -- Not Used
end

function OnGameStart()
    red_flag, blue_flag = read_dword(globals + 0x8), read_dword(globals + 0xC)
end

function punish:InitMsgTable(player)
    messages[player] = {
        ["betrayals"] = {
            msg = "",
            delta_time = 0,
        },
        ["teamshooting"] = {
            msg = "",
            delta_time = 0,
        },
    }
end

function punish:InitWarningTables(player)
    for k, v in pairs(punish) do
        if type(v) == "table" then
            for _, value in pairs(v.actions) do
                if (value.use and k == "betrayals") then
                    betray_warnings[player] = value.warnings
                elseif (value.use and k == "teamshooting") then
                    teamshoot_warnings[player] = value.warnings
                end
            end
        end
    end
end

function OnPlayerConnect(PlayerIndex)
    punish:InitMsgTable(PlayerIndex)
    punish:InitWarningTables(PlayerIndex)
    clear_console[PlayerIndex] = false
end

function OnPlayerDisconnect(PlayerIndex)
    -- Clear the array index for this player:
    betray_warnings[PlayerIndex] = nil
    teamshoot_warnings[PlayerIndex] = nil
    messages[PlayerIndex] = nil
    clear_console[PlayerIndex] = false
end

function OnPlayerDeath(PlayerIndex)
    clear_console[PlayerIndex] = false
end

function punish:warningsReached(params)
    local params = params or nil
    local player = params.player

    if (params ~= nil) then
        local current_warnings = params.warning_table
        if (current_warnings[player] < 1) then
            return true
        end
    end
    return false
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) then
            local table = messages[i]
            if (table ~= nil) and cls(i) then
                for k, v in pairs(table) do
                    if (v.msg ~= "") then
                        rprint(i, punish.message_alignment .. " " .. v.msg)
                        v.delta_time = v.delta_time + 0.03333333333333333
                        if (v.delta_time >= punish.duration) then
                            v.delta_time = 0
                            v.msg = ""
                        end
                    end
                end
            end
        end
    end
end

function OnPlayerBetray(PlayerIndex, VictimIndex)

    local victim = tonumber(VictimIndex)
    local killer = tonumber(PlayerIndex)

    local vTeam, kTeam = get_var(victim, "$team"), get_var(killer, "$team")

    if (killer > 0) and (killer ~= victim) and (kTeam == vTeam) then

        local betray = punish.betrayals.actions
        local p = { }
        p.player = killer
        p.table = betray
        p.warning_table = betray_warnings
        p.reason = "Betraying"

        for k, _ in pairs(betray) do
            if (betray[k].use) then
                p.type = k
                p.msg_type = "betrayals"
                punish:Execute(p)
            end
        end
    end
end

function OnDamageApplication(PlayerIndex, CauserIndex, MetaID, Damage, HitString, Backtap)

    local victim = tonumber(PlayerIndex)
    local causer = tonumber(CauserIndex)

    local vTeam, kTeam = get_var(victim, "$team"), get_var(causer, "$team")

    if (causer > 0) and (causer ~= victim) and (kTeam == vTeam) then

        local teamshooting = punish.teamshooting.actions
        local p = { }
        p.player = causer
        p.table = teamshooting
        p.warning_table = teamshoot_warnings
        p.reason = "Team Shooting"

        for k, _ in pairs(teamshooting) do
            if (teamshooting[k].use) then
                p.type = k
                p.msg_type = "teamshooting"
                punish:Execute(p)
            end
        end
    end
end

function punish:Execute(params)
    local params = params or nil
    if (params ~= nil) then

        local type = params.type
        local table = params.table
        local player = params.player
        local warning_table = params.warning_table
        local name = get_var(player, "$name")
        local msg_type = params.msg_type
        local warnings_left = warning_table[player]
        local total_warnings = table[type].warnings

        warning_table[player] = warning_table[player] - 1

        if not punish:warningsReached(params) then

            local msg = gsub(gsub(gsub(table[type].message1,
                    "%%offender_name%%", name),
                    "%%warnings_left%%", warnings_left),
                    "%%total_warnings%%", total_warnings)

            local MsgTable = messages[player]
            if (MsgTable ~= nil) then
                for k, v in pairs(MsgTable) do
                    if (k == msg_type) then
                        v.msg = msg
                        v.delta_time = 0
                    end
                end
            end

            clear_console[player] = true

        else


            local msg = gsub(gsub(gsub(table[type].message2,
                    "%%offender_name%%", name),
                    "%%warnings_left%%", warnings_left),
                    "%%total_warnings%%", total_warnings)

            execute_command("msg_prefix \"\"")
            say_all(msg)
            execute_command("msg_prefix \" " .. punish.server_prefix .. "\"")

            params.notify_console = table[type].notify_console or nil
            params.name = name

            warning_table[player] = table[type].warnings

            -- Execute the punishment:
            if (params.type == "KILL") then
                params.respawn_time = table[type].respawn_time or nil
                params.deduct_death = table[type].deduct_death or nil
                params.edit_respawn_time = table[type].edit_respawn_time or nil
                punish:KillSilently(params)
            elseif (params.type == "KICK") then
                punish:Kick(params)
            elseif (params.type == "CRASH") then
                if punish:Crash(params) then
                    if (params.notify_console) then
                        cprint("The Punisher: " .. name .. " was crashed for " .. params.reason, 12)
                    end
                else
                    cprint("The Punished: Unable to Crash player. Something went wrong!", 12)
                end
            end
        end
    end
end

function punish:Reset()

    -- Clear the array:
    betray_warnings = { }
    teamshoot_warnings = { }

    for i = 1, 16 do
        if player_present(i) then
            punish:InitWarningTables(i)
            punish:InitMsgTable(i)
        end
    end
end

function punish:Kick(params)
    local params = params or nil
    if (params ~= nil) then
        execute_command("k" .. " " .. params.player .. " " .. params.reason)
        if (params.notify_console) then
            cprint("The Punisher: " .. params.name .. " was crashed for " .. params.reason, 10)
        end
    end
end

function punish:KillSilently(params)
    local params = params or nil

    if (params ~= nil) then
        if ClearInventory(params) then
            local kma = sig_scan("8B42348A8C28D500000084C9") + 3
            local original = read_dword(kma)

            safe_write(true)
            write_dword(kma, 0x03EB01B1)
            safe_write(false)

            execute_command("kill " .. tonumber(params.player))
            safe_write(true)
            write_dword(kma, original)
            safe_write(false)

            if (params.edit_respawn_time) then
                write_dword(get_player(params.player) + 0x2C, tonumber(params.respawn_time) * 33)
            end

            -- Deduct one death:
            if (params.deduct_death) then
                local deaths = tonumber(get_var(params.player, "$deaths"))
                if (deaths > 1) then
                    execute_command("deaths " .. tonumber(params.player) .. " " .. deaths - 1)
                else
                    execute_command_sequence("w8 " .. params.respawn_time .. "; deaths " .. tonumber(params.player) .. " " .. deaths - 1)
                end
            end

            if (params.notify_console) then
                cprint("The Punisher: " .. params.name .. " was killed for " .. params.reason, 10)
            end
        end
    end
end

function punish:Crash(params)
    local params = params or nil

    if (params ~= nil) then
        local player_object = get_dynamic_player(params.player)
        if (player_object ~= 0) then
            local x, y, z = read_vector3d(player_object + 0x5C)
            local tag_name = GetRandomVehicleTag()
            if (tag_name) then
                local vehicleID = spawn_object("vehi", tag_name, x, y, z)
                local vehicleObject = get_object_memory(vehicleID)
                if (vehicleObject ~= 0) then
                    for j = 0, 20 do
                        enter_vehicle(vehicleID, params.player, j)
                        exit_vehicle(params.player)
                    end
                    destroy_object(vehicleID)
                    return true
                end
            end
        end
    end
    return false
end

function ClearInventory(params)
    local params = params or nil

    if (params ~= nil) then
        local player_object = get_dynamic_player(params.player)
        if (player_object ~= 0) then

            -- Set grenade count to zero:
            write_word(player_object + 0x31E, 0)
            write_word(player_object + 0x31F, 0)

            -- Loop through player inventory and delete each weapon object:
            local weaponID = read_dword(player_object + 0x118)
            if (weaponID ~= 0) then
                for j = 0, 3 do
                    local weapon = read_dword(player_object + 0x2F8 + 4 * j)
                    if (weapon ~= red_flag) and (weapon ~= blue_flag) then
                        destroy_object(weapon)
                    end
                end
                return true
            end
        end
    end
    return false
end

function GetRandomVehicleTag()
    local temp = { }
    local tag_address = read_dword(0x40440000)
    local tag_count = read_dword(0x4044000C)

    for i = 0, tag_count - 1 do
        local tag = tag_address + 0x20 * i
        local tag_name = read_string(read_dword(tag + 0x10))
        local tag_class = string.reverse(string.sub(read_string(tag), 1, 4))
        if (tag_class == "vehi") then
            temp[#temp + 1] = tag_name
        end
    end

    if (#temp > 0) then
        math.randomseed(os.time())
        math.random();
        math.random();
        math.random()
        return temp[math.random(#temp)]
    end
end

function cls(player)
    if clear_console[player] then
        if (player) then
            for _ = 1, 25 do
                rprint(player, " ")
            end
        end
        return true
    end
end
