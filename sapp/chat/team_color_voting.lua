--[[
=====================================================================================
SCRIPT NAME:      team_color_voting.lua
DESCRIPTION:      Allows players to vote for team colors to be used in the next game.

FEATURES:
                  - Vote from predefined color sets
                  - Automatic color application next game
                  - Vote tally and result announcements
                  - Default color fallback
                  - Permission-based command access

COMMANDS:
                  /votelist        - Show available color sets
                  /votecolor <id>  - Vote for a specific color set

CONFIGURATION:
                  vote_command = "votecolor"     - Main voting command
                  vote_list_command = "votelist" - List command
                  permission_level = -1          - Required access level (-1 = all)
                  default_color_set = 10         - Default color set ID

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local mod, color_table = {}
function mod:LoadSettings()
    -- Configuration [starts] ---------------------------------------------------------------------------
    mod.settings = {

        -- Default color set: (see color table below)
        default_color_set = 10, -- set two (yellow, purple)

        -- CMD 1 Syntax: /votecolor <set id>
        vote_command = "votecolor",

        -- CMD 2 Syntax: /votelist
        vote_list_command = "votelist",

        -- Permission level needed to execute "/vote_command" (all players by default)
        permission_level = -1, -- negative 1 (-1) = all players | 1 to 4 = admins

        server_prefix = "** SAPP ** ",

        -- All custom output messages:
        messages = {
            on_vote = "You voted for SetID [%id%] (%R% - VS - %B%)", -- e.g: "You voted for Teal"
            broadcast_vote = "[Color Voting] %name% voted for SetID [%id%] (%R% - VS - %B%)",
            on_game_over = {
                [1] = {
                    " ",
                    "--- [Team Color Voting] ---",
                    "Color Set #%id% won with %votes% vote(s).",
                    "Red Team will be %red_color% and Blue Team will be %blue_color%",
                    " "
                },
                [2] = "No one voted to change their team color. Colors will remain the same."
            },

            on_quit = "%name%'s vote for Color Set ID #%id% has been excluded from the tally",
            invalid_syntax = "Incorrect Vote Option. Usage: /%cmd% <set id>",
            vote_list_hud = "[%id%] %R% - VS - %B%",
            vote_list_hud_header = "Vote Command Syntax: /%cmd% <set id>",
            game_over_error = "You can only vote during an active game!",
            already_voted = "You have already voted! (You voted for %R% - vs - %B%)",
            insufficient_permission = "You do not have permission to execute that command!"
        },

        --[[
            There are 10 sets of choices to vote for (you can add more sets)

            Color Name			Color ID
            white        		0
            black 				1
            red 				2
            blue 				3
            gray 				4
            yellow 				5
            green 				6
            pink 				7
            purple 				8
            cyan 				9
            cobalt 				10
            orange 				11
            teal 				12
            sage 				13
            brown 				14
            tan 				15
            maroon 				16
            salmon 				17
        ]]

        choices = {

            [1] = { -- set 1
                red = { "white", 0 }, -- COLOR NAME, COLOR ID
                blue = { "black", 1 }
            },

            [2] = { -- set 2
                red = { "red", 2 },
                blue = { "blue", 3 }
            },

            [3] = { -- set 3
                red = { "gray", 4 },
                blue = { "yellow", 5 }
            },

            [4] = { -- set 4
                red = { "green", 6 },
                blue = { "pink", 7 }
            },

            [5] = { -- set 5
                red = { "purple", 8 },
                blue = { "cyan", 9 }
            },

            [6] = { -- set 6
                red = { "cobalt", 10 },
                blue = { "orange", 11 }
            },

            [7] = { -- set 7
                red = { "teal", 12 },
                blue = { "sage", 13 }
            },

            [8] = { -- set 8
                red = { "brown", 14 },
                blue = { "tan", 15 }
            },

            [9] = { -- set 9
                red = { "maroon", 16 },
                blue = { "salmon", 17 }
            },

            -- CUSTOM SETS EXAMPLE:
            [10] = { -- set 10
                red = { "yellow", 5 },
                blue = { "purple", 8 }
            },

            -- repeat the structure to add more set entries
        }
    }
    -- Configuration [ends] ---------------------------------------------------------------------------

    -- Do Not Touch --
    local t = mod.settings
    color_table = color_table or t.choices[t.default_color_set]
    for i = 1, #t.choices do
        t.choices[i].setid, t.choices[i].votes = i, 0
    end
end

api_version = "1.12.0.0"
local gsub, lower, upper = string.gsub, string.lower, string.upper
local players, ls = {}
local game_over

function OnScriptLoad()

    -- Register needed event callbacks:
    register_callback(cb["EVENT_GAME_END"], "OnGameEnd")
    register_callback(cb["EVENT_JOIN"], "OnPlayerConnect")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    register_callback(cb["EVENT_COMMAND"], "OnServerCommand")
    register_callback(cb["EVENT_TEAM_SWITCH"], "OnTeamSwitch")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerDisconnect")

    if (get_var(0, "$gt") ~= "n/a") then
        mod:LoadSettings()
        for i = 1, 16 do
            if player_present(i) then
                mod:InitPlayer(i, false)
            end
        end
    end

    mod:LSS(true)
end

function OnScriptUnload()
    mod:LSS(false)
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        game_over = false
        mod:LoadSettings()
    end
end

function OnGameEnd()
    game_over = true
    local results = mod:CalculateVotes()
    local t = mod.settings.messages
    if (results ~= nil) then

        -- Set the new color table to be used next game:
        color_table = results

        local R = results.red[1]
        local B = results.blue[1]
        local m1 = t.on_game_over[1]
        for i = 1, #m1 do
            local msg = gsub(gsub(gsub(gsub(m1[i],
                    "%%red_color%%", R),
                    "%%blue_color%%", B),
                    "%%id%%", results.setid),
                    "%%votes%%", results.votes)
            mod:broadcast(nil, msg, true, "chat")
        end
    else
        mod:broadcast(nil, t.on_game_over[2], true, "chat")
    end
end

function OnPlayerConnect(PlayerIndex)
    mod:InitPlayer(PlayerIndex, false)
    mod:SetColor(PlayerIndex)
end

function OnTeamSwitch(PlayerIndex)
    mod:SetColor(PlayerIndex)
end

function OnPlayerDisconnect(PlayerIndex)
    mod:InitPlayer(PlayerIndex, true)
end

function mod:InitPlayer(PlayerIndex, Reset)
    local name = get_var(PlayerIndex, "$name")

    if (Reset) then

        local t = mod.settings
        local SetID = players[PlayerIndex].setid

        if (SetID ~= 0) then
            t.choices[SetID].votes = t.choices[SetID].votes - 1

            if (t.choices[SetID].votes < 0) then
                t.choices[SetID].votes = 0
            end

            local msg = gsub(gsub(t.messages.on_quit, "%%name%%", name), "%%id%%", SetID)
            mod:broadcast(nil, msg, true, "chat")
        end

        players[PlayerIndex] = {}

    else
        players[PlayerIndex] = {
            name = name,
            voted = false,
            voted_for = "",
            setid = 0
        }
    end
end

function OnServerCommand(PlayerIndex, Command, Environment, Password)
    if (PlayerIndex ~= 0) then
        local command, args = mod:CMDSplit(Command)
        local executor = tonumber(PlayerIndex)

        if (command == nil) then
            return
        end
        command = lower(command) or upper(command)

        local t = mod.settings
        local has_permission = function()
            local access = (tonumber(get_var(executor, "$lvl")) >= t.permission_level)
            if (not access) then
                return mod:broadcast(executor, t.messages.insufficient_permission, false, "rcon")
            end
            return true
        end

        if (command == t.vote_command) then
            if (not game_over) then
                mod:cls(executor, 25)
                if has_permission() then
                    if (not players[executor].voted) then

                        local vote = args[1]
                        local team, valid = get_var(executor, "$team")

                        for SetID, Choice in pairs(t.choices) do
                            if (tonumber(vote) == SetID) then

                                -- Increment vote count by 1 for this color set:
                                Choice.votes = Choice.votes + 1

                                players[executor].setid = tonumber(vote)
                                players[executor].voted, players[executor].voted_for = true, gsub(gsub(gsub(t.messages.already_voted,
                                        "%%id%%", SetID),
                                        "%%R%%", Choice.red[1]),
                                        "%%B%%", Choice.blue[1])

                                valid = true

                                local msg = gsub(gsub(gsub(t.messages.on_vote,
                                        "%%id%%", SetID),
                                        "%%R%%", Choice.red[1]),
                                        "%%B%%", Choice.blue[1])
                                mod:broadcast(executor, msg, false, "rcon")

                                local broadcast = gsub(gsub(gsub(gsub(t.messages.broadcast_vote,
                                        "%%name%%", players[executor].name),
                                        "%%id%%", vote),
                                        "%%R%%", Choice.red[1]),
                                        "%%B%%", Choice.blue[1])

                                for i = 1, 16 do
                                    if player_present(i) and (i ~= executor) then
                                        if (get_var(i, "$team") == get_var(executor, "$team")) then
                                            mod:broadcast(i, broadcast, false, "Chat")
                                        end
                                    end
                                end
                            end
                        end

                        if (not valid) then
                            local error = gsub(t.messages.invalid_syntax, "%%cmd%%", t.vote_command)
                            mod:broadcast(executor, error, false, "rcon")
                        end
                    else
                        mod:broadcast(executor, players[executor].voted_for, false, "rcon")
                    end
                end
            else
                mod:broadcast(executor, t.messages.game_over_error, false, "rcon")
            end

            return false
        elseif (command == t.vote_list_command) then
            if has_permission() then
                mod:cls(executor, 25)

                -- header (contents):
                for i = 1, #t.choices do
                    local msg = gsub(gsub(gsub(t.messages.vote_list_hud,
                            "%%id%%", i),
                            "%%R%%", t.choices[i].red[1]),
                            "%%B%%", t.choices[i].blue[1])
                    mod:broadcast(executor, msg, false, "rcon")
                end

                -- footer:
                local msg = gsub(t.messages.vote_list_hud_header, "%%cmd%%", t.vote_command)
                mod:broadcast(executor, msg, false, "rcon")
            end
            return false
        end
    end
end

function mod:CalculateVotes()
    local Choices = mod.settings.choices

    local highest_vote, tab = 0
    for i = 1, #Choices do
        if (highest_vote < Choices[i].votes) then
            tab = Choices[i]
        end
    end

    return tab
end

function mod:SetColor(PlayerIndex)
    local player = get_player(PlayerIndex)
    if (player ~= 0) then
        local team = get_var(PlayerIndex, "$team")
        if (team == "red") then
            write_byte(player + 0x60, tonumber(color_table.red[2]))
        elseif (team == "blue") then
            write_byte(player + 0x60, tonumber(color_table.blue[2]))
        end
    end
end

function mod:broadcast(PlayerIndex, Message, SendToAll, Enviro)

    local responseFunc = say
    if (Enviro == "rcon") then
        responseFunc = rprint
    end

    execute_command("msg_prefix \"\"")
    if (not SendToAll) then
        responseFunc(PlayerIndex, Message)
    else
        for i = 1, 16 do
            if player_present(i) then
                responseFunc(i, Message)
            end
        end
    end
    execute_command("msg_prefix \" " .. mod.settings.server_prefix .. "\"")
end

function mod:cls(PlayerIndex, count)
    count = count or 25
    for _ = 1, count do
        rprint(PlayerIndex, " ")
    end
end

function mod:CMDSplit(CMD)
    local subs = {}
    local sub = ""
    local ignore_quote, inquote, endquote
    for i = 1, string.len(CMD) do
        local bool
        local char = string.sub(CMD, i, i)
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

        if i == string.len(CMD) then
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

function mod:LSS(state)
    if (state) then
        ls = sig_scan("741F8B482085C9750C")
        if (ls == 0) then
            ls = sig_scan("EB1F8B482085C9750C")
        end
        safe_write(true)
        write_char(ls, 235)
        safe_write(false)
    else
        if (ls == 0) then
            return
        end
        safe_write(true)
        write_char(ls, 116)
        safe_write(false)
    end
end
--------------------------------------------

return mod
