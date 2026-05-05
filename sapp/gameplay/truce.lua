--[[
=====================================================================================
SCRIPT NAME:      truce.lua
DESCRIPTION:      Enables players to establish temporary truces preventing mutual
                  damage, with request/accept system and admin controls.


CONFIGURATION:
                  privilege_level = -1              - Minimum admin level for commands (-1 = all players)
                  save_on_newgame = true            - Persist truces across map changes
                  base_command = "truce"            - Main command prefix
                  accept_command = "accept"         - Accept truce command
                  deny_command = "deny"             - Deny truce command
                  untruce_command = "untruce"       - End truce command
                  trucelist_command = "trucelist"   - List active truces

FEATURES:
                  - Request/accept/deny system for truces
                  - Prevents damage between truced players
                  - Persistence across map changes (configurable)
                  - Admin-level controls
                  - List active/pending truces
                  - Team-based restrictions
                  - Customizable messages

COMMANDS:
                  /truce [player]   - Request truce
                  /accept [player]  - Accept truce request
                  /deny [player]    - Deny truce request
                  /untruce [player] - End existing truce
                  /trucelist        - View active/pending truces

MESSAGE TEMPLATES:
                  Supports variables: %target_name%, %executor_name%, %executor_id%

TODO: rewrite this garbage

Copyright (c) 2016-2019 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"
-- configuration [starts] -->

-- Minimum privilege level required to execute /truce command. Set to -1 (negative one) for all players
local privilege_level = -1

local base_command = "truce"
local accept_command = "accept"
local deny_command = "deny"
local untruce_command = "untruce"
local trucelist_command = "trucelist"

-- If enabled, truce data will be saved when the map cycles.
local save_on_newgame = true

-- # Message Configuration:
local on_request = {
    { ["msgToExecutor"] = { "Request sent to %target_name%" } },
    { ["msgToTarget"] = {
        "%executor_name% is requesting a truce with you.",
        "To accept, type /accept %executor_id%",
        "To deny this request, type /deny %executor_id%"
    } },
}

local on_accept = {
    { ["msgToExecutor"] = { "You are now in a truce with %target_name%" } },
    { ["msgToTarget"] = { "[request accepted] You are now in a truce with %executor_name%" } },
}

local on_deny = {
    { ["msgToExecutor"] = { "You denied %target_name%'s truce request" } },
    { ["msgToTarget"] = { "%executor_name% denied your truce request" } },
}

-- configuration [ends] <--

local truce, ip_table, requests, members, tracker, pending = { }, { }, { }, { }, { }, { }
local lower, gsub = string.lower, string.gsub

function OnScriptLoad()
    register_callback(cb['EVENT_COMMAND'], "OnServerCommand")
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], "OnDamageApplication")
    register_callback(cb['EVENT_LEAVE'], "OnPlayerDisconnect")
    register_callback(cb['EVENT_JOIN'], "OnPlayerConnect")
    register_callback(cb['EVENT_GAME_END'], "OnGameEnd")
end

local function clearData()
    if not (save_on_newgame) then
        for i = 1, 16 do
            if player_present(i) then
                local ip = get_var(i, "$ip")
                requests[ip] = 0
                if (tracker[ip] ~= nil) then
                    for key, _ in pairs(tracker[ip]) do
                        tracker[ip][key] = nil
                    end
                end
            end
        end
        if (next(members) ~= nil) then
            for i = 1, #members do
                members[i] = nil
            end
        end
        if (next(pending) ~= nil) then
            for i = 1, #pending do
                pending[i] = nil
            end
        end
    end
end

function OnScriptUnload()
    clearData()
end

function OnGameEnd()
    clearData()
end

function OnPlayerConnect(PlayerIndex)
    local hash = get_var(PlayerIndex, "$hash")
    if not ip_table[hash] then
        ip_table[hash] = {}
        table.insert(ip_table[hash], { ["ip"] = get_var(PlayerIndex, "$ip") })
    end
end

function OnPlayerDisconnect(PlayerIndex)
    local name = get_var(PlayerIndex, "$name")
    local ip = getIP(PlayerIndex, "ip"):match("(%d+.%d+.%d+.%d+:%d+)")

    requests[ip] = 0

    if (next(members) ~= nil) and (tracker[ip] ~= nil) then

        local function removeTracker(a, b)
            for key, _ in pairs(tracker[a]) do
                if tracker[a][key] == b then
                    tracker[a][key] = nil
                end
            end
            for key, _ in pairs(tracker[b]) do
                if tracker[b][key] == a then
                    tracker[b][key] = nil
                end
            end
        end

        for key, _ in ipairs(members) do
            local eid = tonumber(members[key]["eid"])
            local eip = members[key]["eip"]

            local tid = tonumber(members[key]["tid"])
            local tip = members[key]["tip"]

            if (ip == tip) then
                rprint(eid, "Your truce with " .. name .. " has ended.")
                removeTracker(eip, tip)
                members[key] = nil
            elseif (ip == eip) then
                rprint(tid, "Your truce with " .. name .. " has ended.")
                removeTracker(tip, eip)
                members[key] = nil
            end
        end
    end

    if (next(pending) ~= nil) then
        for key, _ in ipairs(pending) do

            local eid = tonumber(pending[key]["eid"])
            local eip = pending[key]["eip"]

            local tid = tonumber(pending[key]["tid"])
            local tip = pending[key]["tip"]

            if (ip == tip) then
                rprint(eid, "Your truce request with " .. name .. " expired")
                pending[key] = nil
            elseif (ip == eip) then
                rprint(tid, "Your truce request with " .. name .. " expired")
                pending[key] = nil
            end

        end
    end
end

local function checkAccess(e)
    if (e ~= -1 and e >= 1 and e < 16) then
        if (tonumber(get_var(e, "$lvl"))) >= privilege_level then
            return true
        else
            rprint(e, "Command failed. Insufficient Permission.")
            return false
        end
    else
        cprint("You cannot execute this command from the console.", 4 + 8)
        return false
    end
end

local function isOnline(t, e)
    if (t) then
        if (t > 0 and t < 17) then
            if player_present(t) then
                return true
            else
                rprint(e, "Command failed. Player not online.")
                return false
            end
        else
            rprint(e, "Invalid player id. Please enter a number between 1-16")
        end
    end
end

local function cmdself(t, e)
    if (t) then
        if tonumber(t) == tonumber(e) then
            rprint(e, "You cannot execute this command on yourself.")
            return true
        end
    end
end

local function hasRequest(params, e, id)
    local params = params or {}
    local ip = params.eip or nil
    if requests[ip] ~= nil then
        if tonumber(requests[ip]) > 0 then
            return tonumber(requests[ip])
        else
            rprint(e, "You do not have any pending truce requests to " .. id)
        end
    else
        rprint(e, "You do not have any pending truce requests to " .. id)
    end
end

local function sameTeam(t, e)
    if not getTeamPlay() then
        return false
    elseif get_var(e, "$team") == get_var(t, "$team") then
        rprint(e, "You cannot initiate a truce with someone on the same team!")
        return true
    end
end

function truce:isPending(params)
    local params = params or {}

    local executor_id = params.eid or nil
    local executor_ip = params.eip or nil

    local target_name = params.tn or nil
    local target_ip = params.tip or nil

    for key, _ in ipairs(pending) do

        local eip = pending[key]["eip"]
        local tip = pending[key]["tip"]

        if (executor_ip == eip) and (target_ip == tip) then
            rprint(executor_id, "You have already sent " .. target_name .. " a request!")
            return true
        elseif (executor_ip == tip) and (target_ip == eip) then
            rprint(executor_id, target_name .. " has already sent you a request!")
            return true
        else
            return false
        end
    end
end

function truce:inTruce(params, bool, isrequest)
    local found, intruce
    local params = params or {}

    local executor_id = params.eid or nil
    local executor_ip = params.eip or nil

    local target_ip = params.tip or nil
    local target_name = params.tn or nil

    if tracker[executor_ip] ~= nil then
        intruce = true
        for i = 1, #tracker[executor_ip] do
            if (tracker[executor_ip][i] == target_ip) then
                if not (bool) then
                    rprint(executor_id, "You are already in a truce with " .. target_name)
                end
                found = true
                return true
            end
        end
    end
    if not (found) and not (isrequest) then
        if (intruce) then
            rprint(executor_id, "You are not in a truce with " .. target_name)
        else
            rprint(executor_id, "You are not in a truce with anybody")
        end
        return false
    end
end

function OnServerCommand(PlayerIndex, Command, Environment, Password)

    local command, args = cmdsplit(Command)
    local executor = tonumber(PlayerIndex)
    local TargetID = tonumber(args[1])

    local players = {}

    local function set_info(param)
        players.en = get_var(executor, "$name")
        players.eid = tonumber(get_var(executor, "$n"))
        players.eip = getIP(executor, "ip"):match("(%d+.%d+.%d+.%d+:%d+)")

        if (param) then
            if args[1]:match("%d+") and not args[1]:match('[A-Za-z]') then
                if player_present(TargetID) then
                    players.tn = get_var(TargetID, "$name")
                    players.tid = tonumber(get_var(TargetID, "$n"))
                    players.tip = getIP(TargetID, "ip"):match("(%d+.%d+.%d+.%d+:%d+)")
                end
            else
                rprint(executor, "Invalid command parameter.")
                return false
            end
        end
    end

    if (command == lower(base_command)) then
        if (checkAccess(executor)) then
            if (args[1] ~= nil and args[3] == nil) then
                set_info(true)
                if isOnline(TargetID, executor) then
                    if not cmdself(TargetID, executor) then
                        if not sameTeam(TargetID, executor) then
                            if not truce:isPending(players) then
                                if not truce:inTruce(players, false, true) then
                                    truce:sendrequest(players)
                                end
                            end
                        end
                    end
                end
            else
                rprint(executor, "Invalid syntax. Usage: /" .. base_command .. " [player id]")
            end
        end
        return false
    elseif (command == lower(accept_command)) then
        if (checkAccess(executor)) then
            if args[1] ~= nil then
                set_info(true)
                if hasRequest(players, executor, "accept") then
                    if isOnline(TargetID, executor) then
                        if not cmdself(TargetID, executor) then
                            truce:enable(players)
                        end
                    end
                end
            else
                rprint(executor, "Invalid syntax. Usage: /" .. accept_command .. " [player id]")
            end
        end
        return false
    elseif (command == lower(deny_command)) then
        if (checkAccess(executor)) then
            if args[1] ~= nil then
                set_info(true)
                if hasRequest(players, executor, "deny") then
                    if isOnline(TargetID, executor) then
                        if not cmdself(TargetID, executor) then
                            truce:deny(players)
                        end
                    end
                end
            else
                rprint(executor, "Invalid syntax. Usage: /" .. deny_command .. " [player id]")
            end
        end
        return false
    elseif (command == lower(untruce_command)) then
        if (checkAccess(executor)) then
            if args[1] ~= nil then
                set_info(true)
                if isOnline(TargetID, executor) then
                    if not cmdself(TargetID, executor) then
                        if truce:inTruce(players, true, false) then
                            truce:disable(players)
                        end
                    end
                end
            else
                rprint(executor, "Invalid syntax. Usage: /" .. untruce_command .. " [player id]")
            end
        end
        return false
    elseif (command == lower(trucelist_command)) then
        if (checkAccess(executor)) then
            if args[1] == nil then
                set_info(false)
                truce:list(players)
            else
                rprint(executor, "Invalid syntax. Usage: /" .. trucelist_command)
            end
        end
        return false
    end
    players = nil
end

function truce:sendrequest(params)
    local params = params or {}

    local executor_name = params.en or nil
    local executor_id = params.eid or nil
    local executor_ip = params.eip or nil

    local target_name = params.tn or nil
    local target_id = params.tid or nil
    local target_ip = params.tip or nil

    table.insert(pending, { ["en"] = executor_name, ["eid"] = executor_id, ["eip"] = executor_ip, ["tn"] = target_name, ["tid"] = target_id, ["tip"] = target_ip })

    for k, _ in ipairs(on_request) do
        local msgToExecutor, msgToTarget = on_request[k]["msgToExecutor"], on_request[k]["msgToTarget"]
        if (msgToExecutor ~= nil) then
            for i = 1, #msgToExecutor do
                local StringFormat = gsub(msgToExecutor[i], "%%target_name%%", target_name)
                rprint(executor_id, StringFormat)
            end
        end
        if (msgToTarget ~= nil) then
            for i = 1, #msgToTarget do
                local StringFormat = (gsub(gsub(msgToTarget[i], "%%executor_name%%", executor_name), "%%executor_id%%", executor_id))
                rprint(target_id, StringFormat)
            end
        end
    end

    if requests[target_ip] == nil then
        requests[target_ip] = 0
    end
    requests[target_ip] = requests[target_ip] + 1
end

function truce:enable(params)
    local params = params or {}

    local executor_name = params.en or nil
    local executor_id = params.eid or nil
    local executor_ip = params.eip or nil

    local target_name = params.tn or nil
    local target_id = params.tid or nil
    local target_ip = params.tip or nil

    table.insert(members, { ["en"] = executor_name, ["eid"] = executor_id, ["eip"] = executor_ip, ["tn"] = target_name, ["tid"] = target_id, ["tip"] = target_ip })
    tracker[executor_ip] = tracker[executor_ip] or {}
    tracker[executor_ip][#tracker[executor_ip] + 1] = target_ip

    tracker[target_ip] = tracker[target_ip] or {}
    tracker[target_ip][#tracker[target_ip] + 1] = executor_ip

    for k, _ in ipairs(on_accept) do
        local msgToExecutor, msgToTarget = on_accept[k]["msgToExecutor"], on_accept[k]["msgToTarget"]
        if (msgToExecutor ~= nil) then
            for i = 1, #msgToExecutor do
                local StringFormat = gsub(msgToExecutor[i], "%%target_name%%", target_name)
                rprint(executor_id, StringFormat)
            end
        end
        if (msgToTarget ~= nil) then
            for i = 1, #msgToTarget do
                local StringFormat = gsub(msgToTarget[i], "%%executor_name%%", executor_name)
                rprint(target_id, StringFormat)
            end
        end
    end

    for key, _ in ipairs(pending) do
        local eip = pending[key]["eip"]
        local en = pending[key]["en"]

        local tip = pending[key]["tip"]
        local tn = pending[key]["tn"]

        if (executor_ip == eip) and (target_name == tn) then
            pending[key] = nil
            break
        elseif (executor_ip == tip) and (target_name == en) then
            pending[key] = nil
            break
        end
    end

    requests[executor_ip] = requests[executor_ip] - 1
end

function truce:disable(params)
    local params = params or {}

    local executor_name = params.en or nil
    local executor_id = params.eid or nil
    local executor_ip = params.eip or nil

    local target_name = params.tn or nil
    local target_ip = params.tip or nil

    if (next(members) ~= nil) and (tracker[executor_ip] ~= nil) then
        for key, _ in ipairs(members) do

            local tn = members[key]["tn"]
            local tid = tonumber(members[key]["tid"])
            local tip = members[key]["tip"]

            local en = members[key]["en"]
            local eid = tonumber(members[key]["eid"])
            local eip = members[key]["eip"]

            if (executor_ip == eip) and (target_name == tn) then
                rprint(executor_id, "Your truce with " .. tn .. " has ended.")
                rprint(tid, "Your truce with " .. executor_name .. " has ended.")
                members[key] = nil
                break
            elseif (executor_ip == tip) and (target_name == en) then
                rprint(executor_id, "Your truce with " .. en .. " has ended.")
                rprint(eid, "Your truce with " .. executor_name .. " has ended.")
                members[key] = nil
                break
            end
        end
        for key, _ in pairs(tracker[executor_ip]) do
            if tracker[executor_ip][key] == target_ip then
                tracker[executor_ip][key] = nil
                break
            end
        end
        for key, _ in pairs(tracker[target_ip]) do
            if tracker[target_ip][key] == executor_ip then
                tracker[target_ip][key] = nil
                break
            end
        end
    end
end

function truce:deny(params)
    local params = params or {}

    local executor_name = params.en or nil
    local executor_id = params.eid or nil

    local target_name = params.tn or nil
    local target_id = params.tid or nil
    local target_ip = params.tip or nil

    for key, _ in ipairs(pending) do
        local eip = pending[key]["eip"]
        local tip = pending[key]["tip"]
        local tn = pending[key]["tn"]
        if (target_ip == eip) and (target_name == en) then
            pending[key] = nil
            break
        elseif (target_ip == tip) and (target_name == tn) then
            pending[key] = nil
            break
        end
    end

    for k, _ in ipairs(on_deny) do
        local msgToExecutor, msgToTarget = on_deny[k]["msgToExecutor"], on_deny[k]["msgToTarget"]
        if (msgToExecutor ~= nil) then
            for i = 1, #msgToExecutor do
                local StringFormat = gsub(msgToExecutor[i], "%%target_name%%", target_name)
                rprint(executor_id, StringFormat)
            end
        end
        if (msgToTarget ~= nil) then
            for i = 1, #msgToTarget do
                local StringFormat = gsub(msgToTarget[i], "%%executor_name%%", executor_name)
                rprint(target_id, StringFormat)
            end
        end
    end
end

function truce:list(params)
    local params = params or {}

    local executor_id = params.eid or nil
    local executor_ip = params.eip or nil

    local mem_en_name, mem_tn_name, mem_en_index, mem_tn_index

    if (next(members) ~= nil) then
        for key, _ in ipairs(members) do

            local en = members[key]["en"]
            local eid = tonumber(members[key]["eid"])
            local eip = members[key]["eip"]

            local tn = members[key]["tn"]
            local tid = tonumber(members[key]["tid"])
            local tip = members[key]["tip"]

            if tracker[executor_ip] ~= nil then
                for i = 1, 16 do
                    if player_present(i) then
                        if eip == get_var(i, "$ip") then
                            mem_en_name = get_var(i, "$name")
                            mem_en_index = tonumber(i)
                        elseif tip == get_var(i, "$ip") then
                            mem_tn_name = get_var(i, "$name")
                            mem_tn_index = tonumber(i)
                        end
                    end
                end
                if executor_ip == eip then
                    if not mem_tn_name then
                        mem_tn_name = tn
                        mem_tn_index = tid
                    end
                    rprint(executor_id, "[you] -> [" .. mem_tn_index .. "] " .. mem_tn_name .. " (truced)")
                elseif executor_ip == tip then
                    if not mem_en_name then
                        mem_en_name = en
                        mem_en_index = eid
                    end
                    rprint(executor_id, "[you] -> [" .. mem_en_index .. "] " .. mem_en_name .. " (truced)")
                end
            else
                rprint(executor_id, "You are not truced with anybody")
            end
        end
    else
        rprint(executor_id, "No active truces")
    end

    local pen_en_name, pen_tn_name, pen_en_index, pen_tn_index

    if (next(pending) ~= nil) then
        for key, _ in ipairs(pending) do

            local tn = pending[key]["tn"]
            local tid = tonumber(pending[key]["tid"])
            local tip = pending[key]["tip"]

            local en = pending[key]["en"]
            local eid = tonumber(pending[key]["eid"])
            local eip = pending[key]["eip"]

            for i = 1, 16 do
                if player_present(i) then
                    if eip == get_var(i, "$ip") then
                        pen_en_name = get_var(i, "$name")
                        pen_en_index = tonumber(i)
                    elseif tip == get_var(i, "$ip") then
                        pen_tn_name = get_var(i, "$name")
                        pen_tn_index = tonumber(i)
                    end
                end
            end
            if executor_ip == eip then
                if not pen_tn_name then
                    pen_tn_name = tn
                    pen_tn_index = tid
                end
                rprint(executor_id, "[you] -> [" .. pen_tn_index .. "] " .. pen_tn_name .. " (pending request)")
            elseif executor_ip == tip then
                if not pen_en_name then
                    pen_en_name = en
                    pen_en_index = eid
                end
                rprint(executor_id, "[you] -> [" .. pen_en_index .. "] " .. pen_en_name .. " (pending request)")
            end
        end
    else
        rprint(executor_id, "No pending requests")
    end
end

function OnDamageApplication(PlayerIndex, CauserIndex, MetaID, Damage, HitString, Backtap)
    if (tonumber(CauserIndex) > 0 and PlayerIndex ~= CauserIndex) then
        if tracker[get_var(CauserIndex, "$ip")] ~= nil then
            for i = 1, #tracker[get_var(CauserIndex, "$ip")] do
                if (tracker[get_var(CauserIndex, "$ip")][i] == get_var(PlayerIndex, "$ip")) then
                    return false
                end
            end
        end
    end
end

function getTeamPlay()
    if get_var(0, "$ffa") == "0" then
        return true
    else
        return false
    end
end

function getIP(PlayerIndex, id)
    if player_present(PlayerIndex) then
        local hash = get_var(PlayerIndex, "$hash")
        if ip_table[hash] ~= nil or ip_table[hash] ~= {} then
            for key, _ in ipairs(ip_table[hash]) do
                return ip_table[hash][key][id]
            end
        end
    end
end

function cmdsplit(str)
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

    local cmd = subs[1]
    local args = subs
    table.remove(args, 1)

    return cmd, args
end
