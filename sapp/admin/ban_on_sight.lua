--[[
====================================================================================
SCRIPT NAME:      ban_on_sight.lua
DESCRIPTION:      Instant IP bans with a pirate-hash safety net.
                  /bos <id> drops the hammer, /bos <id> -h ignores the warning.
                  /unbos <index> removes a ban, 'cause everyone deserves a second chance.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START --
local MIN_ADMIN_LEVEL = 1      -- Minimum admin level required to use BOS commands.
local BASE_COMMAND = "bos"     -- Command to BOS someone.
local LIST_COMMAND = "boslist" -- Command to list banned players.
local UNBOS_COMMAND = "unbos"  -- Command to forgive a sinner.
local BAN_FILE = "bos.txt"     -- Ban list file.

-- Pirated CD key hashes that are shared by many cracked copies.
-- Banning one of these would nuke tons of innocent (well, slightly guilty) players.
local pirated_hashes = {
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
    ["3126fab3615a94119d5fe9eead1e88c1"] = true,
    ["2f02b641060da979e2b89abcfa1af3d6"] = true,
    ["ac73d9785215e196074d418d1cce825b"] = true,
    ["54f4d0236653a6da6429bfc79015f526"] = true
}
-- END CONFIG --

local ban_file = ""
local players = {}
local ban_entries = {}
local banned_ips = {}

local ipairs = ipairs
local tonumber = tonumber
local io_open = io.open
local table_sort, table_remove = table.sort, table.remove

local function isAdmin(id)
    return id == 0 or tonumber(get_var(id, "$lvl")) >= MIN_ADMIN_LEVEL
end

local function saveBans()
    local file = io_open(ban_file, "w")
    if file then
        for _, entry in ipairs(ban_entries) do
            file:write(entry.name .. "," .. entry.hash .. "," .. entry.ip .. "\n")
        end
        file:close()
    end
end

local function loadBans()
    local file = io_open(ban_file, "r")
    if not file then return end
    for line in file:lines() do
        local name, hash, ip = line:match("^([^,]+),([^,]+),([^,]+)$")
        if name and hash and ip then
            ban_entries[#ban_entries + 1] = { name = name, hash = hash, ip = ip }
            banned_ips[ip] = true
        end
    end
    file:close()
    table_sort(ban_entries, function(a, b) return a.name:lower() < b.name:lower() end)
end

local function parseArgs(input)
    local pieces = {}
    for word in input:gmatch("([^%s]+)") do pieces[#pieces + 1] = word end
    return pieces
end

local function getConfigPath()
    return read_string(read_dword(sig_scan("68??????008D54245468") + 0x1))
end

function OnScriptLoad()
    ban_file = getConfigPath() .. "\\sapp\\" .. BAN_FILE

    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_PREJOIN, "OnPreJoin")
    register_callback(cb.EVENT_COMMAND, "OnCommand")

    -- in case script is loaded mid-game
    if get_var(0, "$gt") ~= "n/a" then
        for i = 1, 16 do
            if player_present(i) then OnJoin(i) end
        end
    end

    loadBans()
end

function OnJoin(id)
    players[id] = {
        name = get_var(id, "$name"),
        hash = get_var(id, "$hash"),
        ip   = get_var(id, "$ip")
    }
end

function OnPreJoin(id)
    local ip = get_var(id, "$ip")
    if banned_ips[ip] then
        for i = 1, 16 do
            if player_present(i) and isAdmin(i) then
                rprint(i, "BoS: Rejecting banned connection from " .. ip)
            end
        end
        rprint(id, "You are permanently banned from this server")
        execute_command('k' .. id .. ' "[Auto Ban on Sight]"')
        return false
    end
end

local function checkPerms(id)
    if not isAdmin(id) then
        rprint(id, "Insufficient permissions")
        return false
    end
    return true
end

function OnCommand(id, command)
    local args = parseArgs(command)
    if #args == 0 then return end

    local cmd = args[1]:lower()
    local arg = args[2]
    local count = #args

    if cmd == BASE_COMMAND then
        if not checkPerms(id) then return false end
        if count < 2 or not arg then
            rprint(id, "Syntax: /bos [player_id] [-h]")
            return false
        end

        local target = tonumber(arg)
        if not target or target < 1 or target > 16 then
            rprint(id, "Invalid player ID (1-16)")
            return false
        end

        local data = players[target]
        if not data then
            rprint(id, "No player data for slot " .. target)
            return false
        end

        if banned_ips[data.ip] then
            rprint(id, data.name .. " is already banned, chill")
            return false
        end

        if pirated_hashes[data.hash] then
            local force = (args[3] and args[3]:lower() == "-h")
            if not force then
                rprint(id, "Warning: " .. data.name .. " is using a pirated hash!")
                rprint(id, "Banning this hash would affect many innocent (cracked) players.")
                rprint(id, "Use '/bos " .. target .. " -h' to force the ban if you really mean it.")
                return false
            end
            -- if we're here, admin added -h so we let it slide
        end

        ban_entries[#ban_entries + 1] = { name = data.name, hash = data.hash, ip = data.ip }
        banned_ips[data.ip] = true

        table_sort(ban_entries, function(a, b) return a.name:lower() < b.name:lower() end)
        saveBans()

        rprint(id, "Banned " .. data.name .. " (" .. data.ip .. ")")

        if player_present(target) then
            execute_command('k' .. target .. ' "[Ban on Sight]"')
        end
        return false
    elseif cmd == UNBOS_COMMAND then
        if not checkPerms(id) then return false end
        if count ~= 2 or not arg then
            rprint(id, "Syntax: /unbos [index]")
            rprint(id, "Use /boslist to see the indexes.")
            return false
        end

        local idx = tonumber(arg)
        if not idx or idx < 1 or idx > #ban_entries then
            rprint(id, "Invalid index. There are " .. #ban_entries .. " bans (1 to " .. #ban_entries .. ").")
            return false
        end

        local entry = ban_entries[idx]
        local ip = entry.ip

        table_remove(ban_entries, idx)
        banned_ips[ip] = nil
        saveBans()

        rprint(id, "Unbanned " .. entry.name .. " (" .. ip .. ")")
        return false
    elseif cmd == LIST_COMMAND then
        if not checkPerms(id) then return false end
        if #ban_entries == 0 then
            rprint(id, "No bans in BoS list - everyone's behaving!")
            return false
        end

        rprint(id, "BoS Wall of Shame (" .. #ban_entries .. " entries):")
        for i, entry in ipairs(ban_entries) do
            rprint(id, string.format("%d. %s | %s | %s", i, entry.name, entry.hash, entry.ip))
        end
        return false
    end
end

function OnScriptUnload() end