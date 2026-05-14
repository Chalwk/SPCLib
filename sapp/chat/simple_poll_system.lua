--[[
=====================================================================================
SCRIPT NAME:      simple_poll_system.lua
DESCRIPTION:      Admin-controlled in-game polling system for map votes or rule changes.

FEATURES:
                  - Create polls with custom questions and options
                  - Players vote using numbered options
                  - Automatic results calculation
                  - Admin-only poll cancellation
                  - Configurable duration and permissions

USAGE:
                  Admin commands:
                  /poll "Question?" option1 option2 option3
                  /cancel (stops current poll)

                  Player commands:
                  /vote [number] (e.g., /vote 1 = option1)

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration starts
local config = {
    poll_command = "poll",
    vote_command = "vote",
    cancel_command = "cancel",
    poll_duration = 30, -- in seconds
    required_level = 1; -- Required admin level to start a poll
}
-- Configuration ends

-- Poll object using metatables and inheritance
local Poll = {}
Poll.__index = Poll

function Poll:new(question, options)
    local self = setmetatable({}, Poll)
    self.question = question
    self.options = options
    self.votes = {}  -- Store votes by playerId
    self.start_time = os.time()
    self.end_time = self.start_time + config.poll_duration
    return self
end

function Poll:add_vote(playerId, vote)
    if self.votes[playerId] == nil then
        self.votes[playerId] = vote
    else
        -- Player already voted, so return false
        return false
    end
    return true
end

function Poll:has_ended()
    return os.time() >= self.end_time
end

function Poll:get_results()
    local results = {}
    for _, option in ipairs(self.options) do
        results[option] = 0
    end
    for _, vote in pairs(self.votes) do
        results[vote] = results[vote] + 1
    end
    return results
end

-- Global variable for the active poll
local current_poll
local last_poll_time = 0

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_TICK, "OnTick")  -- Adding the tick event
    OnStart() -- Ensure the script initializes on game start
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then
        -- Reset poll data at the start of a new game
        current_poll = nil
        last_poll_time = 0
    end
end

local function isAdmin(playerId)
    local level = tonumber(get_var(playerId, '$lvl')) or 0
    if playerId == 0 or level >= config.required_level then
        return true
    end
    rprint(playerId, "You do not have permission to use this command.")
    return false
end

local function broadcast(message)
    for i = 1, 16 do
        if player_present(i) then
            rprint(i, message)
        end
    end
end

function OnCommand(playerId, Command)
    local args = string.split(Command)

    -- Handle the /poll command (admin only)
    if args[1] == config.poll_command then
        if isAdmin(playerId) then
            -- only the server admin can start polls
            if current_poll ~= nil and not current_poll:has_ended() then
                rprint(playerId, "A poll is already ongoing!")
                return false
            end

            -- Extract the question (everything in quotes)
            local question = ""
            local options_start_idx

            -- Look for the question enclosed in quotes
            for i = 2, #args do
                local part = args[i]
                if part:sub(1, 1) == "\"" then
                    -- Start of the question
                    question = part:sub(2) -- Remove the opening quote
                    for j = i + 1, #args do
                        local next_part = args[j]
                        if next_part:sub(-1) == "\"" then
                            -- End of the question
                            question = question .. " " .. next_part:sub(1, -2)
                            options_start_idx = j + 1  -- The options start after the end quote
                            break
                        else
                            -- Continue adding to the question
                            question = question .. " " .. next_part
                        end
                    end
                    break
                end
            end

            -- Check if the question was properly extracted
            if question == "" then
                rprint(playerId, "Error: You must provide a question in quotes!")
                return false
            end

            -- Get the options after the question
            local options = {}
            if options_start_idx then
                for i = options_start_idx, #args do
                    table.insert(options, args[i])
                end
            end

            -- Check if there are enough options
            if #options < 2 then
                rprint(playerId, "You need at least two options for a poll!")
                return false
            end

            -- Create and start the poll
            current_poll = Poll:new(question, options)
            broadcast(string.format("Poll started: %s", question))
            broadcast("Options: ")
            for i, option in ipairs(options) do
                broadcast(string.format("%d: %s", i, option))
            end
        end
        return false
    elseif args[1] == config.cancel_command then
        if isAdmin(playerId) then
            if current_poll ~= nil then
                broadcast("The poll has been canceled.")
                current_poll = nil  -- Reset the poll
            else
                rprint(playerId, "No poll is currently running to cancel.")
            end
        end
        return false
    elseif args[1] == config.vote_command then
        -- Handle the /vote command (player votes)
        if current_poll ~= nil and not current_poll:has_ended() then
            local vote = tonumber(args[2])  -- Convert the second argument to a number

            -- Check if the vote is a valid number and within the valid range
            if vote and vote >= 1 and vote <= #current_poll.options then
                if current_poll:add_vote(playerId, current_poll.options[vote]) then
                    rprint(playerId, string.format("You voted for option %d: %s", vote, current_poll.options[vote]))
                else
                    rprint(playerId, "You have already voted!")
                end
            else
                rprint(playerId, "Invalid vote option! Please vote with a valid option number.")
            end
        else
            rprint(playerId, "No poll is currently running.")
        end
        return false
    end
end

function string.split(str)
    local t = {}
    for word in str:gmatch("%S+") do
        t[#t + 1] = word
    end
    return t
end

local function notifyAdmin(result)
    for i = 1, 16 do
        if player_present(i) and isAdmin(i) then
            rprint(i, result)
        end
    end
end

-- Handle the event tick to check the poll's state
function OnTick()
    if current_poll and current_poll:has_ended() then
        -- Poll has ended, display results
        local results = current_poll:get_results()
        local result_message = "Poll ended! Results: "
        for option, count in pairs(results) do
            result_message = result_message .. string.format("%s: %d votes, ", option, count)
        end
        notifyAdmin(result_message)  -- Notify all admins of the poll results
        current_poll = nil  -- Reset poll after it ends
    end
end

function OnScriptUnload()
    -- N/A
end