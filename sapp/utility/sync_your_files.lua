--[[
=====================================================================================
SCRIPT NAME:      sync_your_files.lua
DESCRIPTION:      Synchronizes any file type with a remote server while maintaining
                  local backups for offline reliability.

FEATURES:
                  - Universal file synchronization (supports any file extension)
                  - Automatic backup system when offline
                  - Configurable sync options
                  - Data verification via keyword matching
                  - Connection status notifications

CONFIGURATION:
                  url = 'www.example.com/files/'  - Remote server directory
                  filename = 'test.txt'           - File to synchronize
                  keyword = 'your_keyword'        - Verification string
                  BackupMethod = true             - Enable local backups
                  DisplayConsoleOutput = true     - Show status messages

USAGE:
                  /sync files  - Initiate file synchronization

BACKUP SYSTEM:
                  Edit backup_table contents to match your desired backup file data

REQUIREMENTS:
                  - SAPP HTTP Client:       https://opencarnage.net/index.php?/topic/5998-sapp-http-client/

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb['EVENT_COMMAND'], "OnServerCommand")
    SyncFiles()
    backup_table = {}
end

function OnScriptUnload() end

-- Configuration --
--===>>>===>>>===>>>===>>>===>>>===>>>===>>>===>>>===>>>===
-- Change this url accordingly. 
url = 'www.example.com/files/'
-- Do not reference a direct url path to your file
-->> Bad: www.example.com/files/myfilename.txt/
-->> Good: www.example.com/files/
--===<<<===<<<===<<<===<<<===<<<===<<<===<<<===<<<===<<<===

-- File name
ext = '.txt'
filename = 'test' .. ext
-- File extension
-- SAPP file directory
sapp_dir = "sapp\\" .. filename .. ""

-- For security and to help varify that your file exists or isn't empty on the remote server, the script will search for a 'keyword' in the remote file.
-- If found, the script will proceed to sync with that file. 
-- Otherwise it will initialize the backup solution and insert the data from the "backup_table" instead.
-- Enter that keyword here...

keyword = "your_keyword"

settings = {
    ["Sync_Files"] = true,
    --  Toggle on|off syncing backup method.
    ["BackupMethod"] = true,
    -- Toggle on|off script message output
    ["DisplayFileOutput"] = false,
    ["DisplayConsoleOutput"] = true
}

-- Backup Solution. 
local backup_table = {
    "The contents of this table should be identical to the contents of the remote file.",
    "If the remote file is empty or unavailable, the script will initialize the backup solution.",
    "The backup function will read the data from this backup_table and write it to your local file.",
    "--<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>--",
    "--<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>--",
    "--<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>--",
    "--<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>--",
    "--<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>-- Example Text --<<>><<>>--" -- Don't put a comma on the last line.
}
-- Configuration Ends --

function OnServerCommand(PlayerIndex, Command)
    local isadmin
    if (tonumber(get_var(PlayerIndex, "$lvl"))) >= 1 then
        isadmin = true
    else
        isadmin = false
    end
    local notify
    local t = tokenizestring(Command)
    count = #t
    -- Syntax: /sync files
    if t[1] == "sync" then
        if isadmin then
            if t[2] == "files" then
                -- Call [function] SyncFiles()
                SyncFiles(Message, PlayerIndex)
                if not settings["Sync_Files"] then
                    notify = false
                else
                    notify = true
                end
            else
                notify = false
                -- Command invalid.
                respond("Invalid Syntax: /sync files", PlayerIndex)
            end
        else
            notify = false
            -- Player is not an admin - deny access.
            respond("You do not have permission to execute /" .. Command, PlayerIndex)
        end
        if notify then
            send_all(PlayerIndex)
        end
        return false
    end
end

--- >>> ------
-- Credits to skylace for this function
function send_all(PlayerIndex)
    for i = 1, 16 do
        if player_present(i) then
            if i ~= PlayerIndex then
                --              Notify all players of temporary lag while the server syncs the files.
                rprint(i, "[Server Process] - Temporary Lag Warning!")
            end
        end
    end
end
--- <<< ------

function SyncFiles(Message, PlayerIndex)
    file_url = GetPage(tostring(url) .. filename)
    response = nil
    if settings["Sync_Files"] then
        -- invalid url (unavailable) or remote server is offline
        if file_url == nil then
            respond('Script Error:', PlayerIndex)
            respond(url .. filename .. ' does not exist or the remote server is offline.', PlayerIndex)
            if settings["BackupMethod"] then
                BackupSolution(Message, PlayerIndex)
            else
                respond('Script Error: [BackupMethod] disabled - Unable to sync ' .. filename, PlayerIndex)
            end
            -- file does not exist or remote server is offline - go to backup solution.
            response = false
        else
            -- file exists on remote server, varify data.
            response = true
            if string.match(file_url, keyword) == nil then
                respond('Script Error: Failed to read from ' .. filename .. ' on remote server.', PlayerIndex)
                if settings["BackupMethod"] then
                    BackupSolution(Message, PlayerIndex)
                else
                    respond('Script Error: [BackupMethod] disabled - Unable to sync ' .. filename, PlayerIndex)
                end
                --  file is empty on remote server, or unable to varify data, go to backup solution.
                response = false
            end
            -- file found on remote server, data varified, initiate sync.
            if response then
                --- >>> ------
                -- Read data from remote file and write to sapp\\<filename>.<ext>
                local file = io.open(sapp_dir, "w")
                local line = tokenizestring(file_url, "\n")
                respond('Syncing Files...', PlayerIndex)
                for i = 1, #line do
                    file:write(line[i])
                    if settings["DisplayFileOutput"] then
                        respond(line[i], PlayerIndex)
                    end
                end
                file:close()
                --- <<< ------
                respond(filename .. ' successfully synced with remote server|n', PlayerIndex)
            end
        end
    else
        respond('Script Error: [Sync_Files] setting disabled - Please enable it first.', PlayerIndex)
    end
    return response
end

function BackupSolution(Message, PlayerIndex)
    respond('Going to backup solution...', PlayerIndex)
    --- >>> ------ 
    -- Read data from backup_table and write to sapp\\<filename>.<ext>
    local file = io.open(sapp_dir, "w")
    for i = 1, #backup_table do
        file:write(backup_table[i], "\n")
        if settings["DisplayFileOutput"] then
            respond(backup_table[i], PlayerIndex)
        end
    end
    file:close()
    respond(filename .. ' successfully synced.', PlayerIndex)
end

function respond(Message, PlayerIndex)
    if Message then
        if Message == "" then
            return
        elseif type(Message) == "table" then
            Message = Message[1]
        end
        PlayerIndex = tonumber(PlayerIndex)
        if tonumber(PlayerIndex) and PlayerIndex ~= nil and PlayerIndex ~= -1 and PlayerIndex >= 0 and PlayerIndex < 16 then
            if settings["DisplayConsoleOutput"] then
                cprint(Message, 10)
            end
            rprint(PlayerIndex, Message)
            note = string.format('[SyncFilesUtility] -->> ' .. get_var(PlayerIndex, "$name") .. ': ' .. Message)
            execute_command("log_note \"" .. note .. "\"")
        else
            if settings["DisplayConsoleOutput"] then
                cprint(Message, 10)
            end
            v1note = string.format('[SyncFilesUtility]: ' .. Message)
            execute_command("log_note \"" .. v1note .. "\"")
        end
    end
end

-- Found this neat little function here:
-- http://stackoverflow.com/questions/1426954/split-string-in-lua
function tokenizestring(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {};
    i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function OnError(Message)
    print(debug.traceback())
end

-- 002's Code
ffi = require("ffi")
ffi.cdef [[
    typedef void http_response;
    http_response *http_get(const char *url, bool async);
    void http_destroy_response(http_response *);
    void http_wait_async(const http_response *);
    bool http_response_is_null(const http_response *);
    bool http_response_received(const http_response *);
    const char *http_read_response(const http_response *);
    uint32_t http_response_length(const http_response *);
]]
http_client = ffi.load("lua_http_client")

function GetPage(URL)
    local response = http_client.http_get(URL, false)
    local returning = nil
    if http_client.http_response_is_null(response) ~= true then
        local response_text_ptr = http_client.http_read_response(response)
        returning = ffi.string(response_text_ptr)
    end
    http_client.http_destroy_response(response)
    return returning
end