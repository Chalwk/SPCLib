--[[
===============================================================================
SCRIPT NAME:      admin_add_me.lua
DESCRIPTION:      Grants admin privileges via "/admin me" command
                  - Sets level 4 admin by default (configurable)
                  - Only works for pre-approved players, IPs, or hashes
                  - Blocks known pirated game copies

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

-- Config Start -------------------------------------------------------------

local SECRET_COMMAND = "some_secret_command"

local DEFAULT_ADMIN_LEVEL = 4

-- Approved users (names, IPs, or hashes):
local APPROVED_USERS = {
    "PlayerName",
    "d4aa2371dc89589a9ebfc9dda6c4b3ca",
    "127.0.0.1"
}

-- Known pirated hashes:
local PIRATED_HASHES = {
    ["388e89e69b4cc08b3441f25959f74103"] = true,
    ["81f9c914b3402c2702a12dc1405247ee"] = true,
    ["c939c09426f69c4843ff75ae704bf426"] = true,
    ["13dbf72b3c21c5235c47e405dd6e092d"] = true,
    ["29a29f3659a221351ed3d6f8355b2200"] = true,
    ["d72b3f33bfb7266a8d0f13b37c62fddb"] = true,
    ["76b9b8db9ae6b6cacdd59770a18fc1d5"] = true,
    ["55d368354b5021e7dd5d3d1525a4ab82"] = true,
    ["d41d8cd98f00b204e9800998ecf8427e"] = true,
    ["c702226e783ea7e091c0bb44c2d0ec64"] = true,
    ["f443106bd82fd6f3c22ba2df7c5e4094"] = true,
    ["10440b462f6cbc3160c6280c2734f184"] = true,
    ["3d5cd27b3fa487b040043273fa00f51b"] = true,
    ["b661a51d4ccf44f5da2869b0055563cb"] = true,
    ["740da6bafb23c2fbdc5140b5d320edb1"] = true,
    ["7503dad2a08026fc4b6cfb32a940cfe0"] = true,
    ["4486253cba68da6786359e7ff2c7b467"] = true,
    ["f1d7c0018e1648d7d48f257dc35e9660"] = true,
    ["40da66d41e9c79172a84eef745739521"] = true,
    ["2863ab7e0e7371f9a6b3f0440c06c560"] = true,
    ["34146dc35d583f2b34693a83469fac2a"] = true,
    ["b315d022891afedf2e6bc7e5aaf2d357"] = true,
    ["63bf3d5a51b292cd0702135f6f566bd1"] = true,
    ["6891d0a75336a75f9d03bb5e51a53095"] = true,
    ["325a53c37324e4adb484d7a9c6741314"] = true,
    ["0e3c41078d06f7f502e4bb5bd886772a"] = true,
    ["fc65cda372eeb75fc1a2e7d19e91a86f"] = true,
    ["f35309a653ae6243dab90c203fa50000"] = true,
    ["50bbef5ebf4e0393016d129a545bd09d"] = true,
    ["a77ee0be91bd38a0635b65991bc4b686"] = true,
    ["3126fab3615a94119d5fe9eead1e88c1"] = true
}
-- Config End ------------------------------------------------------------

local approved_lookup = {}

local function addIPAdmin(playerId, lvl, ip)
    rprint(playerId, "You're now level " .. lvl .. " admin (IP-based).")
    execute_command('adminadd ' .. playerId .. ' ' .. lvl .. ' ' .. ip)
end

local function addHashAdmin(playerId, lvl)
    rprint(playerId, "You're now level " .. lvl .. " admin (Hash-based).")
    execute_command('adminadd ' .. playerId .. ' ' .. lvl)
end

local function isApproved(value)
    return approved_lookup[value]
end

local function tryGrantAdmin(playerId)
    local hash = get_var(playerId, "$hash")
    local name = get_var(playerId, "$name")
    local ip = get_var(playerId, "$ip"):match("%d+%.%d+%.%d+%.%d+")
    local lvl = tonumber(get_var(playerId, "$lvl"))

    if lvl >= DEFAULT_ADMIN_LEVEL then
        rprint(playerId, "You're already an admin (level " .. lvl .. ").")
        return
    end

    if PIRATED_HASHES[hash] then
        rprint(playerId, "Access denied: pirated game copy detected.")
        return
    end

    if isApproved(name) or isApproved(ip) then
        addIPAdmin(playerId, DEFAULT_ADMIN_LEVEL, ip)
    elseif isApproved(hash) then
        addHashAdmin(playerId, DEFAULT_ADMIN_LEVEL)
    else
        say(playerId, "Unknown Command: " .. SECRET_COMMAND) -- fake the unknown command to prevent detection
    end
end

function OnScriptLoad()
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    for _, v in ipairs(APPROVED_USERS) do
        approved_lookup[v] = true
    end
end

function OnCommand(playerId, command)
    if playerId == 0 then return true end

    if command == SECRET_COMMAND then
        tryGrantAdmin(playerId)
        return false
    end
    return true
end

function OnScriptUnload() end