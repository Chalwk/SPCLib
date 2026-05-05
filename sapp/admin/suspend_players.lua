--[[
=====================================================================================
SCRIPT NAME:      suspend_players.lua
DESCRIPTION:      Admin tool to freeze players in place, remove weapons, and mute chat.
                  Persists across sessions when configured.

FEATURES:
                  - Freezes player movement completely
                  - Removes all weapons and prevents new pickups
                  - Optional chat muting functionality
                  - Configurable persistence across sessions
                  - Customizable admin messages
                  - Supports targeting individuals or all players

CONFIGURATION:
                  command = "suspend"       -- Admin command to use
                  permission = 1            -- Required admin level
                  mute = true               -- Whether to block chat messages
                  keep_suspended = true     -- Persist suspensions across sessions
                  default_running_speed = 1 -- Speed after unsuspending

USAGE:
                  /suspend [playerID|*/all] [on|off]
                  Examples:
                  /suspend 3 on      - Suspend player 3
                  /suspend all off   - Unsuspend all players

Copyright (c) 2019 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local mod = {}
function mod:Init()
    -- ============= Configuration Starts ============= --

    -- Custom Command:
    -- Syntax: /suspend [id | */all] [on/off | 1/0 | true/false]
    mod.command = "suspend"

    -- Minimum permission needed to execute the custom command:
    mod.permission = 1

    mod.messages = {

        -- Message sent to (executor) - (example output: Chalwk was suspended | Chalwk was unsuspended):
        "%target_name% was %state%",

        -- Message sent to target player (valid Variables: %executor_name%):
        "You have been %state% by an admin",

        -- If you try to suspend/unsuspended a player who is already suspended or unsuspended, you will see this message:
        "%target_name% is already %state%",

        -- Message sent to admins when a suspended player joins the server (requires mod.keep_suspended) to be true
        "%target_name% joined Suspended",

        -- Message sent to suspended players when they text-chat (requires mod.mute) to be true
        "You cannot talk or use chat commands!",
    }

    -- If true, suspended players will not be able to send chat messages.
    mod.mute = true

    -- Should players remain suspended when they quit?
    mod.keep_suspended = true

    -- Running speed players return to when unsuspended:
    mod.default_running_speed = 1
    -- ============= Configuration Ends ============= --

    -- # Do Not Touch # --
    mod.players, mod.ip_table = {}, {}
end


-- Variables for String Library:
local sub, gsub = string.sub, string.gsub
local lower, upper, match = string.lower, string.upper, string.match

-- Game Variables:
local game_over

function OnScriptLoad()

    -- Register needed event callbacks:
    register_callback(cb["EVENT_CHAT"], "OnPlayerChat")
    register_callback(cb["EVENT_GAME_END"], "OnGameEnd")
    register_callback(cb["EVENT_JOIN"], "OnPlayerConnect")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    register_callback(cb["EVENT_COMMAND"], "OnServerCommand")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerDisconnect")
    register_callback(cb['EVENT_WEAPON_PICKUP'], "OnWeaponPickup")

    if (get_var(0, "$gt") ~= "n/a") then
        game_over = false
        mod:Init()
        for i = 1, 16 do
            if player_present(i) then
                mod.ip_table[i] = get_var(i, '$ip')
            end
        end
    end
end

function OnScriptUnload()
    --
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        game_over = false
        mod:Init()
    end
end

function OnGameEnd()
    game_over = true
end

function OnPlayerConnect(p)
    mod.ip_table[p] = get_var(p, '$ip')

    local ip = mod:GetIP(p)
    mod[ip] = mod[ip] or nil

    local suspended = (mod[ip] == true)
    if (mod.keep_suspended) and (suspended) then
        mod:Respond(p, mod.messages[2])
        for i = 1, 16 do
            if player_present(i) then
                if mod:isAdmin(i) then
                    mod:Respond(p, gsub(mod.messages[4], "%%target_name%%"))
                    mod:Suspend(p)
                end
            end
        end
    end
end

function OnPlayerDisconnect(p)
    local ip = mod:GetIP(p)

    local suspended = (mod[ip] == true)
    if (not mod.keep_suspended) or (not suspended) then
        mod[ip], mod.ip_table[p] = nil, nil
    end
end

function OnServerCommand(PlayerIndex, Command, Environment, Password)
    local command, args = mod:StringSplit(Command)
    local executor = tonumber(PlayerIndex)

    if (command == nil) then
        return
    end
    command = lower(command) or upper(command)

    if (command == mod.command) then
        if mod:checkAccess(executor) then
            if not mod:isGameOver(executor) then
                if (args[1] ~= nil) then

                    local params = mod:ValidateCommand(executor, args)
                    if (params ~= nil) and (not params.target_all) and (not params.is_error) then
                        local Target = tonumber(args[1]) or tonumber(executor)
                        if mod:isOnline(Target, executor) then
                            mod:ExecuteCore(params)
                        end
                    end
                else
                    mod:Respond(executor, "Invalid Syntax: Usage: /" .. mod.command .. " [id | */all] on|off", 4 + 8)
                end
            end
        end
        return false
    end
end

function OnPlayerChat(PlayerIndex, Message, type)
    if (type ~= 6) then
        local ip = mod:GetIP(PlayerIndex)
        local suspended = (mod[ip] == true)
        if (mod.mute) and (suspended) then
            mod:Respond(PlayerIndex, mod.messages[5], 4 + 8)
            return false
        end
    end
end

function mod:ExecuteCore(params)
    local params = params or nil
    if (params ~= nil) then

        -- Target Parameters:
        local tid, tip, tn = params.tid, params.tip, params.tn

        -- Executor Parameters:
        local eid, eip, en = params.eid, params.eip, params.en

        -- 
        local is_console = mod:isConsole(eid)
        if is_console then
            en = "SERVER"
        end

        local is_self = (eid == tid)
        local admin_level = tonumber(get_var(eid, '$lvl'))
        local state = mod:ActivationState(eid, params.state)

        if (state) then
            if (not is_self) then
                local valid_state
                mod[tip] = mod[tip] or nil

                local already_suspended = (mod[tip] == true)
                local already_set

                if (state == 1) then
                    state, valid_state = "suspended", true
                    if (mod[tip] == nil) then
                        mod[tip] = true
                    else
                        already_set = true
                    end
                elseif (state == 0) then
                    state, valid_state = "unsuspended", true
                    if (mod[tip] == already_suspended) then
                        mod[tip] = nil
                    else
                        already_set = true
                    end
                end

                if (valid_state) then
                    local messages = mod.messages
                    local Feedback = function(Message)
                        local words = {
                            ["%%state%%"] = state,
                            ["%%executor_name%%"] = en,
                            ["%%target_name%%"] = tn,
                        }
                        for k, v in pairs(words) do
                            Message = gsub(Message, k, v)
                        end
                        return Message
                    end

                    if (not already_set) then
                        mod:Respond(eid, Feedback(messages[1]), 2 + 8)
                        mod:Respond(tid, Feedback(messages[2]), 2 + 8)
                        mod:Suspend(tid, state)
                    else
                        mod:Respond(eid, Feedback(messages[3]), 4 + 8)
                    end
                end
            else
                mod:Respond(tid, "You cannot Suspend yourself", 4 + 8)
            end
        end
    end
end

function mod:Suspend(target, state)
    if (state == "suspended") then
        local player_object = get_dynamic_player(target)
        if (player_object ~= 0) then
            execute_command("s " .. target .. " 0")
            execute_command("wdel " .. target)
        end
    elseif (state == "unsuspended") then
        execute_command("s " .. target .. " " .. mod.default_running_speed)
        local player = get_player(target)
        local OldValue = read_word(player + 0xD4)
        write_word(player + 0xD4, 0xFFFF)
        kill(target)
        write_word(player + 0xD4, OldValue)
    end
end

function OnWeaponPickup(PlayerIndex, WeaponIndex, Type)
    local ip = mod:GetIP(PlayerIndex)
    mod[ip] = mod[ip] or nil

    local suspended = (mod[ip] == true)
    if (suspended) then
        execute_command("wdel " .. PlayerIndex)
    end
end

function mod:ValidateCommand(executor, args)
    local params = { }

    local function getplayers(arg)
        local players = { }

        if (arg == nil) or (arg == 'me') then
            table.insert(players, executor)
        elseif (arg:match('%d+')) then
            table.insert(players, tonumber(arg))
        elseif (arg == '*' or arg == 'all') then
            params.target_all = true
            for i = 1, 16 do
                if player_present(i) then
                    table.insert(players, i)
                end
            end
        elseif (arg == 'rand' or arg == 'random') then
            local temp = { }
            for i = 1, 16 do
                if player_present(i) then
                    temp[#temp + 1] = i
                end
            end
            table.insert(players, temp[math.random(#temp)])
        else
            mod:Respond(executor, "Invalid Player ID: Usage: /" .. mod.command .. " [number: 1-16 | */all | me] on|off", 4 + 8)
            params.is_error = true
            return false
        end

        if players[1] then
            return players
        end
        return false
    end

    local pl = getplayers(args[1])
    if (pl) then
        for i = 1, #pl do

            if (pl[i] == nil) then
                break
            end

            params.state = args[2]
            params.eid, params.en, params.eip = executor, get_var(executor, '$name'), mod:GetIP(executor)
            params.tid, params.tn, params.tip = tonumber(pl[i]), get_var(pl[i], '$name'), mod:GetIP(pl[i])

            if (params.target_all) then
                mod:ExecuteCore(params)
            end
        end
    end
    return params
end

function mod:isOnline(target, executor)
    if (target > 0 and target < 17) then
        if player_present(target) then
            return true
        else
            mod:Respond(executor, "Command Failed. Player not online!", 4 + 8)
            return false
        end
    else
        mod:Respond(executor, "Invalid Player ID. Please enter a number between 1-16", 4 + 8)
    end
end

function mod:checkAccess(p)
    local access
    if not mod:isConsole(p) then
        if mod:isAdmin(p) then
            access = true
        else
            mod:Respond(p, "Command Failed. Insufficient permission!", 4 + 8)
            access = false
        end
    else
        access = true
    end
    return access
end

function mod:ActivationState(e, s)
    if (s == "on") or (s == "1") or (s == "true") then
        return 1
    elseif (s == "off") or (s == "0") or (s == "false") then
        return 0
    else
        mod:Respond(e, "Invalid Syntax: Usage: /" .. mod.command .. " [id | */all] on|off", 4 + 8)
        return false
    end
end

function mod:isConsole(e)
    if (e) then
        if (e ~= -1 and e >= 1 and e < 16) then
            return false
        else
            return true
        end
    end
end

function mod:isGameOver(p)
    if (game_over) then
        mod:Respond(p, "Please wait until the next game has started.", 4 + 8)
        return true
    end
end

function mod:GetIP(p)

    if (halo_type == 'PC') then
        ip_address = mod.ip_table[p]
    else
        ip_address = get_var(p, '$ip')
    end
    if (ip_address ~= nil) then
        return ip_address:match('(%d+.%d+.%d+.%d+)')
    else
        error(debug.traceback())
    end
end

function mod:isAdmin(p)
    if (tonumber(get_var(p, "$lvl"))) >= mod.permission then
        return true
    end
end

function mod:Respond(p, msg, color)
    local color = color or 4 + 8
    if not mod:isConsole(p) then
        rprint(p, msg)
    else
        cprint(msg, color)
    end
end

function mod:StringSplit(str, bool)
    local subs = {}
    local sub = ""
    local ignore_quote, inquote, endquote
    for i = 1, string.len(str) do
        local bool
        local char = string.sub(str, i, i)
        if char == " " then
            if (inquote and endquote) or (not inquote and not endquote) then
                bool = true
            end
        elseif char == "\\" then
            ignore_quote = true
        elseif char == "\"" then
            if not ignore_quote then
                if not inquote then
                    inquote = true
                else
                    endquote = true
                end
            end
        end

        if char ~= "\\" then
            ignore_quote = false
        end

        if bool then
            if inquote and endquote then
                sub = string.sub(sub, 2, string.len(sub) - 1)
            end

            if sub ~= "" then
                table.insert(subs, sub)
            end
            sub = ""
            inquote = false
            endquote = false
        else
            sub = sub .. char
        end

        if i == string.len(str) then
            if string.sub(sub, 1, 1) == "\"" and string.sub(sub, string.len(sub), string.len(sub)) == "\"" then
                sub = string.sub(sub, 2, string.len(sub) - 1)
            end
            table.insert(subs, sub)
        end
    end

    local cmd, args = subs[1], subs
    table.remove(args, 1)

    return cmd, args
end

-- For a future update:
return mod
