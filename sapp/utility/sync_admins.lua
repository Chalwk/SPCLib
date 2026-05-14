--[[
=====================================================================================
SCRIPT NAME:      sync_admins.lua
DESCRIPTION:      Synchronizes admin and user files with a remote server while
                  maintaining local backups for offline reliability.

FEATURES:
                  - Automatic remote-to-local file synchronization
                  - Fallback to local backups when offline
                  - Configurable sync options (admins/users/both)
                  - Connection status notifications
                  - Data validation for security
                  - Temporary lag warnings during sync

CONFIGURATION:
                  url = 'http://example.com/files/'  -- Remote server path
                  Sync_Admins = true                -- Enable admin file sync
                  Sync_Users = true                 -- Enable user file sync
                  BackupMethod = true               -- Enable local backups
                  DisplayConsoleOutput = true        -- Show sync status messages

USAGE:
                  /sync admins   - Sync only admin file
                  /sync users    - Sync only user file
                  /sync all      - Sync both files

REQUIREMENTS:
                  - SAPP HTTP Client:       https://opencarnage.net/index.php?/topic/5998-sapp-http-client/

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration
local url = 'http://example.com/files/'
local admins_file = 'sapp\\admins.txt'
local users_file = 'sapp\\users.txt'

local settings = {
    Sync_Admins = true,
    Sync_Users = true,
    BackupMethod = true,
    DisplayFileOutput = false,
    DisplayConsoleOutput = true
}

-- Backup Data
local admin_table = {
    "PlayerName1:f443106bd82fd6f3c22ba2df7c5e4094:4",
    "PlayerName2:c702226e783ea7e091c0bb44c2d0ec64:1",
    "PlayerName3:d72b3f33bfb7266a8d0f13b37c62fddb:2",
    "PlayerName4:55d368354b5021e7dd5d3d1525a4ab82:1",
    "PlayerName5:3d5cd27b3fa487b040043273fa00f51b:3",
    "PlayerName6:b661a51d4ccf44f5da2869b0055563cb:3"
}

local users_table = {
    "PlayerName1:0:f443106bd82fd6f3c22ba2df7c5e4094:4:",
    "PlayerName2:1:c702226e783ea7e091c0bb44c2d0ec64:1:",
    "PlayerName3:2:d72b3f33bfb7266a8d0f13b37c62fddb:2:",
    "PlayerName4:3:55d368354b5021e7dd5d3d1525a4ab82:1:",
    "PlayerName5:4:3d5cd27b3fa487b040043273fa00f51b:3:",
    "PlayerName6:5:b661a51d4ccf44f5da2869b0055563cb:3:"
}

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
end

function OnScriptUnload()
end

local function stringSplit(s)
    local args = {}
    for arg in s:gmatch('([^%s]+)') do
        args[#args + 1] = arg:lower()
    end
    return args
end

local function notifyLagToPlayers(PlayerIndex)
    for i = 1, 16 do
        if player_present(i) and i ~= PlayerIndex then
            rprint(i, "[Server Process] - Temporary Lag Warning!")
        end
    end
end

local function validateData(data)
    return string.match(data, "(:)(%d+%w+)(:)[0-4]") ~= nil
end

local function respond(Message, PlayerIndex)
    if Message and Message ~= "" then
        if settings.DisplayConsoleOutput then
            cprint(Message, 10)
        end

        if PlayerIndex and player_present(PlayerIndex) then
            rprint(PlayerIndex, Message)
            execute_command("log_note \"" .. string.format('[SyncAdminsUtility] -->> %s: %s', get_var(PlayerIndex, "$name"), Message) .. "\"")
        else
            execute_command("log_note \"" .. '[SyncAdminsUtility]: ' .. Message .. "\"")
        end
    end
end

local function handleBackup(backupFunction, PlayerIndex)
    if settings.BackupMethod then
        backupFunction(PlayerIndex)
    else
        respond('Backup method is disabled - Unable to sync.', PlayerIndex)
    end
end

local function writeToFile(filename, data, PlayerIndex)
    local file = io.open(filename, "w")
    if file then
        file:write(data)
        file:close()
        respond('Data written to ' .. filename, PlayerIndex)
    else
        respond('Error writing to ' .. filename, PlayerIndex)
    end
end

local function BackupSolutionAdmins(PlayerIndex)
    writeToFile(admins_file, table.concat(admin_table, "\n"), PlayerIndex)
    respond('admins.txt successfully restored from backup.', PlayerIndex)
end

local function BackupSolutionUsers(PlayerIndex)
    writeToFile(users_file, table.concat(users_table, "\n"), PlayerIndex)
    respond('users.txt successfully restored from backup.', PlayerIndex)
end

local function SyncAdmins(PlayerIndex)
    notifyLagToPlayers(PlayerIndex)
    local response = GetPage(url .. "admins.txt")

    if response then
        if validateData(response) then
            writeToFile(admins_file, response, PlayerIndex)
            respond('admins.txt successfully synced.', PlayerIndex)
        else
            handleBackup(BackupSolutionAdmins, PlayerIndex)
        end
    else
        handleBackup(BackupSolutionAdmins, PlayerIndex)
    end
end

local function SyncUsers(PlayerIndex)
    notifyLagToPlayers(PlayerIndex)
    local response = GetPage(url .. "users.txt")

    if response then
        if validateData(response) then
            writeToFile(users_file, response, PlayerIndex)
            respond('users.txt successfully synced.', PlayerIndex)
        else
            handleBackup(BackupSolutionUsers, PlayerIndex)
        end
    else
        handleBackup(BackupSolutionUsers, PlayerIndex)
    end
end

local function handleSyncCommand(PlayerIndex, commandArgs)
    local isAdmin = tonumber(get_var(PlayerIndex, "$lvl")) >= 0

    if not isAdmin then
        respond("You do not have permission to execute /" .. table.concat(commandArgs, " "), PlayerIndex)
        return
    end

    if commandArgs[2] == "admins" and settings.Sync_Admins then
        SyncAdmins(PlayerIndex)
    elseif commandArgs[2] == "users" and settings.Sync_Users then
        SyncUsers(PlayerIndex)
    elseif commandArgs[2] == "all" then
        if settings.Sync_Admins then SyncAdmins(PlayerIndex) end
        if settings.Sync_Users then SyncUsers(PlayerIndex) end
    else
        respond("Invalid Syntax: /sync admins | users | all", PlayerIndex)
    end
end

function OnServerCommand(PlayerIndex, Command)
    local commandArgs = stringSplit(Command)
    local command = string.lower(commandArgs[1])

    if command == "sync" then
        handleSyncCommand(PlayerIndex, commandArgs)
        return false
    end
end

local ffi = require("ffi")
ffi.cdef [[
    typedef void http_response;
    http_response *http_get(const char *url, bool async);
    void http_destroy_response(http_response *);
    bool http_response_is_null(const http_response *);
    const char *http_read_response(const http_response *);
]]
local http_client = ffi.load("lua_http_client")

function GetPage(URL)
    local response = http_client.http_get(URL, false)
    if not http_client.http_response_is_null(response) then
        local response_text_ptr = http_client.http_read_response(response)
        local returning = ffi.string(response_text_ptr)
        http_client.http_destroy_response(response)
        return returning
    end
    http_client.http_destroy_response(response)
    return nil
end
