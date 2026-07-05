--[[
===============================================================================
SCRIPT NAME:      block_duplicate_ips.lua
DESCRIPTION:      Prevents multiple connections from the same IP address with:
                  - Configurable actions (kick/ban)
                  - IP whitelist support
                  - Admin notifications

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- API version required for the script to run:
api_version = "1.12.0.0"

-- Configuration table:
local config = {

    -- Action to take: "kick" or "ban":
    action = "kick",

    -- Duration of ban (in minutes) if the action is "ban":
    banTime = 999,

    -- Reason to show for taking action (kick/ban):
    punishmentReason = "Duplicate IP",

    -- Should all players with the same IP be removed (true) or only the latest player (false)?
    removeAllPlayersWithSameIP = true,

    -- List of IPs to exclude from duplicate IP checking:
    excludedIPs = {
        "127.0.0.1",
        "192.168.0.100" -- Example IP
    },

    -- Enable/Disable logging actions taken against players:
    loggingEnabled = true,

    -- Notify all players when a player is kicked or banned:
    notifyAllPlayers = false,

    notifyAdmins = true,

    -- Only admins with this level or higher will be notified of actions taken:
    adminLevel = 1,

    -- Customize message colors (0-255):
    messageColor = 12 -- Default to red color for messages
}

-- Utility function to write logs to the console (if logging is enabled):
local function logAction(message)
    if config.loggingEnabled then
        cprint("[LOG] " .. message)
    end
end

-- Helper function to check if an IP is excluded from duplicate checks:
local function isExcluded(ip)
    for _, excludedIP in ipairs(config.excludedIPs) do
        -- Support wildcard match (e.g., 192.168.*.*)
        local escapedIP = excludedIP:gsub("%%", "%%%%"):gsub("%*", "%%d+")
        if ip:match("^" .. escapedIP .. "$") then
            return true
        end
    end
    return false
end

-- Function to notify admins of actions taken:
local function notifyAdmins(message)
    for i = 1, 16 do
        if player_present(i) and config.notifyAdmins then
            local level = tonumber(get_var(i, "$lvl"))
            if level >= config.adminLevel then
                rprint(i, message)
            end
        end
    end
end

-- Function to take action (kick/ban) against players:
local function takeAction(playerId, ip)
    local playerName = get_var(playerId, "$name")
    local reason = config.punishmentReason

    if config.action == "kick" then
        execute_command('k ' .. playerId .. ' "' .. reason .. '"')
        cprint(playerName .. " was kicked for " .. reason, config.messageColor)
        logAction("Player '" .. playerName .. "' with IP '" .. ip .. "' was kicked.")
    elseif config.action == "ban" then
        local banTime = config.banTime
        execute_command('b ' .. playerId .. ' ' .. banTime .. '"' .. reason .. '"')
        cprint(playerName .. " was banned for " .. banTime .. " minutes for " .. reason, config.messageColor)
        logAction("Player '" .. playerName .. "' with IP '" .. ip .. "' was banned for " .. banTime .. " minutes.")
    end

    -- Notify all players if configured:
    if config.notifyAllPlayers then
        say_all(playerName .. " was " .. config.action .. "ed for " .. reason)
    end

    -- Notify admins:
    notifyAdmins(playerName .. " was " .. config.action .. "ed for " .. reason .. " (IP: " .. ip .. ")")
end

-- Function to check for duplicate IPs among connected players:
local function checkForDuplicateIPs(playerIndex, joiningIP)
    local duplicatePlayers = {}

    -- Iterate over all connected players to find duplicates:
    for i = 1, 16 do
        if player_present(i) and i ~= playerIndex then
            local currentPlayerIP = get_var(i, "$ip"):match("(%d+.%d+.%d+.%d+)")
            if currentPlayerIP == joiningIP and not isExcluded(joiningIP) then
                table.insert(duplicatePlayers, i)
            end
        end
    end

    -- Take action if duplicates are found:
    if #duplicatePlayers > 0 then
        if not config.removeAllPlayersWithSameIP then
            takeAction(playerIndex, joiningIP)
        else
            -- Take action against all players with the same IP, including the joining player:
            table.insert(duplicatePlayers, playerIndex)
            for _, duplicatePlayerIndex in ipairs(duplicatePlayers) do
                takeAction(duplicatePlayerIndex, joiningIP)
            end
        end
    end
end

-- Function triggered before a player joins (checks for duplicate IPs):
function OnPreJoin(playerId)
    local joiningIP = get_var(playerId, "$ip"):match("(%d+.%d+.%d+.%d+)")
    checkForDuplicateIPs(playerId, joiningIP)
end

-- Script load and unload callbacks:
function OnScriptLoad()
    register_callback(cb.EVENT_PREJOIN, "OnPreJoin")
end

function OnScriptUnload()
    -- No specific actions required when the script unloads
end
