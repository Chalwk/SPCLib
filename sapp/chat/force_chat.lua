--[[
=====================================================================================
SCRIPT NAME:      force_chat.lua
DESCRIPTION:      Forces a player to send a chat message
                  - Command: /fc <player#> <message>
                  - Output format: "PlayerName: message"
                  - Requires permission level 1
                  - Works with all players (including Chimera users)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Custom command used to force a player to say something:
local command = 'fc'

-- Minimum permission level required to use the command:
--
local permission_level = 1

-- Chat message format:
--
local format = '$name: $msg'

-- A message relay function temporarily removes the "msg_prefix" and will
-- restore it to this when finished:
--
local prefix = '**SAPP**'

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
end

local function hasPerm(id)
    local lvl = tonumber(get_var(id, '$lvl'))
    return (id == 0 and true or lvl >= permission_level)
end

local function stringSplit(s)
    local t = {}
    for arg in s:gmatch('([^%s]+)') do
        t[#t + 1] = arg:lower()
    end
    return t
end

local function Say(id, Msg)
    return (id == 0 and cprint(Msg) or rprint(id, Msg))
end

function OnCommand(id, CMD)
    local args = stringSplit(CMD)
    if (args) then

        local cmd = (args[1]:sub(1, command:len()) == command)
        if (cmd) then
            local victim = (args[2] and tonumber(args[2]:match('%d+')))

            if (not victim or not args[3]) then
                Say(id, 'Usage: /fc <player> <message>')
                return false
            elseif (cmd) then

                if (hasPerm(id)) then

                    if (victim and player_present(victim)) then

                        local message = table.concat(args, ' ', 3)
                        if (message and message ~= '') then
                            local name = get_var(victim, '$name')
                            execute_command('msg_prefix ""')
                            say_all(format:gsub('$name', name):gsub('$msg', message))
                            execute_command('msg_prefix "' .. prefix .. '"')
                        else
                            Say(id, 'Usage: /fc <player> <message>')
                        end
                    else
                        Say(id, 'Player #' .. victim .. ' is not online.')
                    end
                else
                    Say(id, 'Insufficient Permission')
                end
                return false
            end
        end
    end
end

function OnScriptUnload()
    -- N/A
end