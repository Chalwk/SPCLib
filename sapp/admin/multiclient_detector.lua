--[[
=====================================================================================
SCRIPT NAME:      multiclient_detector.lua
DESCRIPTION:      Advanced detection system for identifying players using multiple clients.

FEATURES:
                  - Probability-based scoring (0-100%) with risk categories:
                    * Low (0-40%)
                    * Moderate (41-60%)
                    * High (61-80%)
                    * Very High (81-100%)
                  - Detection methods:
                    * Known pirated client hashes
                    * Network port analysis
                    * Client behavior patterns
                  - Admin command (/mc) to check players
                  - Automatic high-risk player notifications

USAGE:
                  - System runs automatically on player join
                  - Admins can manually check players with /mc [playerID]
                  - Configure known hashes and port ranges in config

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

Copyright (c) 2024 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Define the Multiclient module
local Multiclient = {
    file = 'multiclients.json',                                                  -- File name for storing the multiclient data in JSON format.
    common_ports = { { 2300, 2400 } },                                           -- List of common port ranges that may indicate multi-client usage.
    min_range = 2401,                                                            -- Minimum port number to consider for custom clients (inclusive).
    max_range = 65535,                                                           -- Maximum port number to consider for custom clients (inclusive).
    command = 'mc',                                                              -- Command to trigger multi-client checks in-game.
    output_message = '$name - MultiClient Probability: $probability% ($reason)', -- Template message format for outputting player multi-client probability and reason.
    permission_level = 4,                                                        -- Required permission level to use the multi-client command (higher means fewer users can access).
    -- Table of known hashes associated with pirated clients.
    known_pirated_hashes = {
        -- (your known hashes here)
    },

    thresholds = { -- Thresholds for defining the probability levels.
        low = 40,      -- Probability percentage for low risk of multi-client usage.
        moderate = 60, -- Probability percentage for moderate risk of multi-client usage.
        high = 80,     -- Probability percentage for high risk of multi-client usage.
        very_high = 90 -- Probability percentage for very high risk of multi-client usage.
    },

    admin_id = 1                                                                 -- Example admin ID for sending notifications; adjust as needed.
}

local players = {}
local open = io.open
local json = loadfile('./json.lua')()

api_version = '1.12.0.0'

-- Load the database from the specified file
function Multiclient:LoadDB()
    local content = ''
    local file = open(self.file, 'r')
    if file then
        content = file:read('*all')
        file:close()
    end
    local data = json:decode(content) or {}
    return data
end

-- Update the database by writing to the specified file
function Multiclient:Update()
    local file = open(self.file, 'w')
    if file then
        file:write(json:encode_pretty(self.db))
        file:close()
    end
end

-- Create a new player entry in the database
function Multiclient:NewPlayer(playerData)
    setmetatable(playerData, self)
    self.__index = self
    playerData.probability = 0
    self.db[playerData.ip] = self.db[playerData.ip] or { hash = playerData.hash, port = playerData.port }
    self.db[playerData.ip].name = playerData.name
    self:Update()
    playerData:SetProbability()
    return playerData
end

-- Set the probability score for the player
function Multiclient:SetProbability()
    if not self.known_pirated_hashes[self.hash] then
        self.probability = self.probability + 1
        local db = self.db[self.ip]
        if db.port ~= self.port then
            self.probability = self.probability + 1
        end
        if db.hash ~= self.hash then
            self.probability = self.probability + 1
        end
        local isCommonPort = false
        for _, v in ipairs(self.common_ports) do
            local min, max = v[1], v[2]
            local port = tonumber(self.port)
            if port >= min and port <= max then
                isCommonPort = true
                break
            end
        end
        if not isCommonPort then
            self.probability = self.probability + 1
            if self.port:len() > 4 then
                self.probability = self.probability + 1
            elseif tonumber(self.port) >= self.min_range and tonumber(self.port) <= self.max_range then
                self.probability = self.probability + 1
            end
        end
    end
    self.probability = (self.probability / 5) * 100
end

-- Called when the script is loaded
function OnScriptLoad()
    local dir = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    Multiclient.dir = dir .. '\\sapp\\' .. Multiclient.file
    Multiclient.db = Multiclient:LoadDB()

    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')

    OnStart()
end

-- Utility function to split a string into a table of words
function string.split(str)
    local t = {}
    for arg in str:gmatch('([^%s]+)') do
        t[#t + 1] = arg
    end
    return t
end

-- Initialize players on game start
function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        players = {}
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

-- Update database on game end
function OnEnd()
    Multiclient:Update()
end

-- Handle player join event
function OnJoin(playerId)
    local ip = get_var(playerId, '$ip')
    local port = ip:match(':(.*)')
    players[playerId] = Multiclient:NewPlayer({
        pid = playerId,
        port = port,
        name = get_var(playerId, '$name'),
        hash = get_var(playerId, '$hash'),
        ip = ip:match('%d+.%d+.%d+.%d+')
    })
end

-- Handle player leave event
function OnQuit(playerId)
    if players[playerId] then
        players[playerId] = nil
    end
end

-- Function to get the reason for the probability score
local function getProbabilityReason(probability)
    if probability < Multiclient.thresholds.low then
        return "Low probability of using a MultiClient."
    elseif probability < Multiclient.thresholds.moderate then
        return "Moderate probability of using a MultiClient."
    elseif probability < Multiclient.thresholds.high then
        return "High probability of using a MultiClient."
    else
        return "Very high probability of using a MultiClient."
    end
end

local function respond(playerId, message)
    if playerId == 0 then
        cprint(message)
    else
        rprint(playerId, message)
    end
end

-- Handle command event
function OnCommand(playerId, cmd)
    local args = string.split(cmd)

    if args[1] ~= Multiclient.command then
        return true
    end

    local targetId = args[2] and tonumber(args[2]) or playerId

    if targetId and player_present(targetId) then
        local targetPlayer = players[targetId]

        if targetPlayer then
            local reason = getProbabilityReason(targetPlayer.probability)
            local message = Multiclient
                .output_message
                :gsub('$name', targetPlayer.name)
                :gsub('$probability', string.format("%.2f", targetPlayer.probability))
                :gsub('$reason', reason)
            respond(playerId, message)

            -- Notify admin if high probability
            if targetPlayer.probability > Multiclient.thresholds.high then
                respond(
                    Multiclient.admin_id,
                    targetPlayer.name .. " has been flagged as a likely multi-client user with "
                        .. string.format("%.2f", targetPlayer.probability) .. "% chance."
                )
            end
        else
            respond(playerId, 'Player not found.')
            return false
        end
    else
        respond(playerId, 'Invalid player ID or player not present.')
        return false
    end

    return false
end
