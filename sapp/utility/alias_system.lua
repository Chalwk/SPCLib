--[[
===============================================================================
SCRIPT NAME:      alias_system.lua
DESCRIPTION:      Advanced player alias tracking and lookup system.
                  - Tracks player aliases by IP address and hash.
                  - Provides commands to look up player aliases using various methods.
                  - Detects and marks players using known pirated game copies.
                  - Automatic database maintenance with stale record cleanup.
                  - Configurable permission levels and command cooldowns.
                  - Fuzzy search for names with partial matching.

COMMAND SYNTAX:
    /alias hash <player_id> [page]      - Lookup aliases for a player using their hash.
    /alias ip <player_id> [page]        - Lookup aliases for a player using their IP.
    /alias hash_lookup <hash> [page]    - Directly lookup aliases by hash (manual input).
    /alias ip_lookup <ip> [page]        - Directly lookup aliases by IP (manual input).
    /alias search <partial_name> [page] - Fuzzy search for names containing text.
    /alias help                         - Show command usage help.

REQUIREMENTS:   Install to the same directory as sapp.dll
                 - Lua JSON Parser: http://regex.info/blog/lua/json

LAST UPDATED:     5/10/2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG start --------------------------------------------
local CONFIG = {
    -- Permission level required to use the alias lookup commands
    REQUIRED_PERMISSION_LEVEL = 4,

    -- Enable/disable specific commands
    -- hash:        Look up aliases by player ID (uses their hash)
    -- ip:          Look up aliases by player ID (uses their IP)
    -- hash_lookup: Direct hash lookup (manual hash input)
    -- ip_lookup:   Direct IP lookup (manual IP input)
    -- search:      Fuzzy search for names containing text
    COMMANDS = {
        ["hash"] = true,
        ["ip"] = true,
        ["hash_lookup"] = true,
        ["ip_lookup"] = true,
        ["search"] = true
    },

    -- Command cooldown in seconds
    COOLDOWN = 3,

    -- Database update settings
    UPDATE = {
        on_join = false, -- Save database when players join (can cause lag on busy servers)
        on_end = true,   -- Save database at game end (recommended)
        stale = true     -- Enable stale record cleanup (automatic maintenance)
    },

    -- Enable automatic deletion of old records
    -- Prevents database from growing indefinitely
    DELETE_STALE_RECORDS = true,

    -- Number of days before a record is considered stale and gets deleted
    -- Records older than this will be automatically removed
    STALE_PERIOD = 30,

    -- Maximum number of names to display per page in results
    MAX_RESULTS = 25,

    -- Maximum number of names to display per line in the output
    -- Helps prevent console spam with long lists
    MAX_NAMES_PER_ROW = 5,

    -- Fuzzy search settings
    FUZZY_SEARCH = {
        case_sensitive = false, -- Set to true for case-sensitive searches
        min_search_length = 2,  -- Minimum characters required for search
        max_results = 100       -- Maximum results to return (prevents lag)
    },

    -- Filtering settings
    FILTERING = {
        -----------------------------------------------------------------------
        -- IP FILTERING
        -----------------------------------------------------------------------
        -- These IP patterns are ignored (not tracked or stored in the database).
        -- Useful for filtering out local, shared, or temporary IPs (like LANs or localhost).
        --
        -- Pattern syntax:
        --     *  matches any number of characters (wildcard)
        --     ?  matches a single character
        --
        -- Examples:
        --     "192.168.*"   ignores all 192.168.x.x addresses (typical LAN)
        --     "10.*"        ignores all 10.x.x.x addresses (private network)
        --     "127.0.0.1"   ignores localhost
        --
        -- You can add more patterns if needed.
        -- For example, to ignore a VPN subnet: "172.16.*"
        ignore_ips = {
            "192.168.*",
            "10.*",
            "127.0.0.1"
        },

        -----------------------------------------------------------------------
        -- NAME FILTERING
        -----------------------------------------------------------------------
        -- These name patterns are ignored and will not be stored or shown
        -- in alias lookup results.
        --
        -- Use this to skip generic, temporary, or automated names such as
        -- default client names, bot accounts, or placeholder names.
        --
        -- Pattern syntax:
        --     *  matches any sequence of characters
        --     ?  matches a single character
        --
        -- Examples:
        --     "Player"     ignores exact name "Player"
        --     "sapp*"      ignores any name beginning with "sapp" (e.g., sapp_bot)
        --     "halo*"      ignores any name beginning with "halo"
        --
        -- You can add your own patterns here to exclude clan tags,
        -- temporary accounts, or system bots, such as:
        --     "[LNZ]*", "*test*", or "Guest?"
        ignore_names = {
            "Player",
            "sapp*",
            "halo*"
        }
    },

    -- Known pirated game hashes - players using these will be marked as [PIRATED]
    -- These are MD5 hashes of game executables from unauthorized copies
    -- Add new hashes as you encounter them (format: lowercase, no spaces)
    KNOWN_PIRATED_HASHES = {
        [' 388e89e69b4cc08b3441f25959f74103'] = true,
        [' 81f9c914b3402c2702a12dc1405247ee'] = true,
        [' c939c09426f69c4843ff75ae704bf426'] = true,
        [' 13dbf72b3c21c5235c47e405dd6e092d'] = true,
        [' 29a29f3659a221351ed3d6f8355b2200'] = true,
        [' d72b3f33bfb7266a8d0f13b37c62fddb'] = true,
        [' 76b9b8db9ae6b6cacdd59770a18fc1d5'] = true,
        [' 55d368354b5021e7dd5d3d1525a4ab82'] = true,
        [' d41d8cd98f00b204e9800998ecf8427e'] = true,
        [' c702226e783ea7e091c0bb44c2d0ec64'] = true,
        [' f443106bd82fd6f3c22ba2df7c5e4094'] = true,
        [' 10440b462f6cbc3160c6280c2734f184'] = true,
        [' 3d5cd27b3fa487b040043273fa00f51b'] = true,
        [' b661a51d4ccf44f5da2869b0055563cb'] = true,
        [' 740da6bafb23c2fbdc5140b5d320edb1'] = true,
        [' 7503dad2a08026fc4b6cfb32a940cfe0'] = true,
        [' 4486253cba68da6786359e7ff2c7b467'] = true,
        [' f1d7c0018e1648d7d48f257dc35e9660'] = true,
        [' 40da66d41e9c79172a84eef745739521'] = true,
        [' 2863ab7e0e7371f9a6b3f0440c06c560'] = true,
        [' 34146dc35d583f2b34693a83469fac2a'] = true,
        [' b315d022891afedf2e6bc7e5aaf2d357'] = true,
        [' 63bf3d5a51b292cd0702135f6f566bd1'] = true,
        [' 6891d0a75336a75f9d03bb5e51a53095'] = true,
        [' 325a53c37324e4adb484d7a9c6741314'] = true,
        [' 0e3c41078d06f7f502e4bb5bd886772a'] = true,
        [' fc65cda372eeb75fc1a2e7d19e91a86f'] = true,
        [' f35309a653ae6243dab90c203fa50000'] = true,
        [' 50bbef5ebf4e0393016d129a545bd09d'] = true,
        [' a77ee0be91bd38a0635b65991bc4b686'] = true,
        [' 3126fab3615a94119d5fe9eead1e88c1'] = true,
        [' 2f02b641060da979e2b89abcfa1af3d6'] = true,
        [' ac73d9785215e196074d418d1cce825b'] = true,
        [' 54f4d0236653a6da6429bfc79015f526'] = true
    }
}
-- CONFIG end ----------------------------------------------

api_version = '1.12.0.0'

local db_directory, json
local aliases_db = {}
local DEFAULT_DB = { ip_records = {}, hash_records = {} }
local command_cooldowns = {}

local get_var = get_var
local rprint = rprint

local pcall = pcall
local pairs, ipairs = pairs, ipairs
local os_time = os.time
local io_open = io.open
local string_lower, string_find = string.lower, string.find
local table_insert, table_concat, table_sort = table.insert, table.concat, table.sort

local function getConfigPath()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
end

local function send(id, msg)
    if id == 0 or id == nil then return cprint(msg) end
    rprint(id, msg)
end

local function matchesPattern(value, pattern)
    -- Convert wildcard pattern to Lua pattern
    local lua_pattern = pattern:gsub("%*", ".*"):gsub("%?", ".")
    return value:match(lua_pattern) ~= nil
end

local function shouldIgnoreIP(ip)
    for _, pattern in ipairs(CONFIG.FILTERING.ignore_ips) do
        if matchesPattern(ip, pattern) then
            return true
        end
    end
    return false
end

local function shouldIgnoreName(name)
    for _, pattern in ipairs(CONFIG.FILTERING.ignore_names) do
        if matchesPattern(name, pattern) then
            return true
        end
    end
    return false
end

local function applyFilters(record_type, identifier, name)
    if record_type == "ip" and shouldIgnoreIP(identifier) then
        return true -- Skip this IP
    end

    if name and shouldIgnoreName(name) then
        return true -- Skip this name
    end

    return false -- Don't skip
end

local function parseAndValidateArgs(args, expected_type, command_name)
    local target = args[3]
    local page = tonumber(args[4])

    if not target then
        return nil, nil, "Usage: /alias " .. command_name .. " [" .. expected_type .. "] [optional page]"
    end

    return target, page
end

local function validatePlayerAndGetData(target_id)
    target_id = tonumber(target_id)
    if not target_id or not player_present(target_id) then
        return nil, "Invalid or offline player ID"
    end
    return target_id
end

local function getRecordData(record_type, identifier)
    if record_type == "hash" then
        return aliases_db.hash_records[identifier], identifier
    else
        return aliases_db.ip_records[identifier], identifier
    end
end

local function getPlayerData(target_id, record_type)
    if record_type == "hash" then
        return get_var(target_id, '$hash')
    else
        return get_var(target_id, '$ip'):match('%d+.%d+.%d+.%d+')
    end
end

local function validateHash(hash)
    hash = hash:gsub("%s+", ""):lower()
    if #hash ~= 32 then
        return nil, "Invalid hash format. Must be 32 characters."
    end
    return hash
end

local function validateIp(ip)
    if not ip:match('^%d+.%d+.%d+.%d+$') then
        return nil, "Invalid IP address format"
    end
    return ip
end

local function formatNamesList(names, max_per_row)
    local result = {}
    local current_row = {}
    local count = 0

    for name, _ in pairs(names) do
        table_insert(current_row, name)
        count = count + 1

        if #current_row >= max_per_row then
            table_insert(result, table_concat(current_row, ", "))
            current_row = {}
        end
    end

    if #current_row > 0 then
        table_insert(result, table_concat(current_row, ", "))
    end

    return result, count
end

local function showAliasesPage(id, record, target, record_type, page)
    if not record then
        send(id, "No records found for: " .. target)
        return
    end

    local all_names = {}
    for name, _ in pairs(record.names) do
        table_insert(all_names, name)
    end

    table_sort(all_names)

    local total_names = #all_names
    local max_results = CONFIG.MAX_RESULTS
    local max_per_row = CONFIG.MAX_NAMES_PER_ROW
    local total_pages = math.ceil(total_names / max_results)

    page = page or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_index = (page - 1) * max_results + 1
    local end_index = math.min(start_index + max_results - 1, total_names)

    local sliced_names_table = {}
    for i = start_index, end_index do
        sliced_names_table[all_names[i]] = true
    end

    local formatted_rows, names_count = formatNamesList(sliced_names_table, max_per_row)

    local header = "Page " ..
        page .. "/" .. total_pages .. ". Showing " .. names_count .. " names aliases for: " .. target
    if record_type == "hash" and CONFIG.KNOWN_PIRATED_HASHES[target] then
        header = header .. " [PIRATED]"
    end
    send(id, header)

    for _, row in ipairs(formatted_rows) do
        send(id, row)
    end

    if total_pages > 1 then
        send(id, "Use '" .. page + 1 .. "' as page parameter to see next page")
    end
end

local function handlePlayerBasedLookup(id, args, record_type, command_name)
    local target_id, page, error_msg = parseAndValidateArgs(args, "player_id", command_name)
    if error_msg then
        rprint(id, error_msg)
        return
    end

    target_id, error_msg = validatePlayerAndGetData(target_id)
    if error_msg then
        send(id, error_msg)
        return
    end

    local identifier = getPlayerData(target_id, record_type)
    local record = getRecordData(record_type, identifier)

    showAliasesPage(id, record, identifier, record_type, page)
end

local function handleDirectLookup(id, args, record_type, command_name)
    local target, page, error_msg = parseAndValidateArgs(args, record_type, command_name)
    if error_msg then
        send(id, error_msg)
        return
    end

    if record_type == "hash" then
        target, error_msg = validateHash(target)
    else
        target, error_msg = validateIp(target)
    end

    if error_msg then
        send(id, error_msg)
        return
    end

    local record = getRecordData(record_type, target)
    showAliasesPage(id, record, target, record_type, page)
end

local function handleFuzzySearch(id, args, command_name)
    local search_term, page, error_msg = parseAndValidateArgs(args, "partial_name", command_name)
    if error_msg then
        send(id, error_msg)
        return
    end

    -- Add safety check to ensure search_term is not nil
    if not search_term then
        send(id, "Search term cannot be empty")
        return
    end

    -- Validate minimum search length
    if #search_term < CONFIG.FUZZY_SEARCH.min_search_length then
        send(id, "Search term must be at least " .. CONFIG.FUZZY_SEARCH.min_search_length .. " characters long")
        return
    end

    -- Prepare search term (now we know search_term is not nil)
    if not CONFIG.FUZZY_SEARCH.case_sensitive then
        search_term = string_lower(search_term)
    end

    -- Collect all unique names from both IP and hash records
    local all_unique_names = {}
    local name_sources = {} -- Track which records contain each name

    -- Search through IP records
    for ip, record in pairs(aliases_db.ip_records) do
        -- Skip filtered IPs
        if not shouldIgnoreIP(ip) then
            for name, _ in pairs(record.names) do
                -- Skip filtered names
                if not shouldIgnoreName(name) then
                    local search_name = CONFIG.FUZZY_SEARCH.case_sensitive and name or string_lower(name)
                    if string_find(search_name, search_term, 1, true) then -- true for plain search (no patterns)
                        if not all_unique_names[name] then
                            all_unique_names[name] = true
                            name_sources[name] = { ips = {}, hashes = {} }
                        end
                        table_insert(name_sources[name].ips, ip)
                    end
                end
            end
        end
    end

    -- Search through hash records
    for hash, record in pairs(aliases_db.hash_records) do
        for name, _ in pairs(record.names) do
            -- Skip filtered names
            if not shouldIgnoreName(name) then
                local search_name = CONFIG.FUZZY_SEARCH.case_sensitive and name or string_lower(name)
                if string_find(search_name, search_term, 1, true) then
                    if not all_unique_names[name] then
                        all_unique_names[name] = true
                        name_sources[name] = { ips = {}, hashes = {} }
                    end
                    table_insert(name_sources[name].hashes, hash)
                end
            end
        end
    end

    -- Convert to sorted list
    local matched_names = {}
    for name, _ in pairs(all_unique_names) do
        table_insert(matched_names, name)
    end

    table_sort(matched_names)

    -- Apply maximum results limit
    local total_matches = #matched_names
    if total_matches > CONFIG.FUZZY_SEARCH.max_results then
        send(id,
            "Too many results (" ..
            total_matches .. "). Showing first " .. CONFIG.FUZZY_SEARCH.max_results .. " matches.")
        -- Truncate the results
        while #matched_names > CONFIG.FUZZY_SEARCH.max_results do
            table.remove(matched_names)
        end
        total_matches = CONFIG.FUZZY_SEARCH.max_results
    end

    -- Handle pagination
    local max_results = CONFIG.MAX_RESULTS
    local max_per_row = CONFIG.MAX_NAMES_PER_ROW
    local total_pages = math.ceil(total_matches / max_results)

    page = page or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_index = (page - 1) * max_results + 1
    local end_index = math.min(start_index + max_results - 1, total_matches)

    -- Display results
    if total_matches == 0 then
        send(id, "No names found containing: '" .. args[3] .. "'")
        return
    end

    local header = "Page " .. page .. "/" .. total_pages ..
        ". Found " .. total_matches .. " names containing '" .. args[3] .. "'"
    send(id, header)

    -- Display names in rows
    local current_row = {}
    local count = 0

    for i = start_index, end_index do
        local name = matched_names[i]
        table_insert(current_row, name)
        count = count + 1

        if #current_row >= max_per_row then
            send(id, table_concat(current_row, ", "))
            current_row = {}
        end
    end

    if #current_row > 0 then
        send(id, table_concat(current_row, ", "))
    end

    -- Show detailed information for the first few results on page 1
    if page == 1 and total_matches > 0 then
        send(id, "--- Detailed info for first few matches ---")

        local details_shown = 0
        local max_details = 3 -- Show details for first 3 matches

        for i = start_index, math.min(start_index + max_details - 1, end_index) do
            local name = matched_names[i]
            local sources = name_sources[name]

            if sources and (#sources.ips > 0 or #sources.hashes > 0) then
                send(id, "Name: " .. name)

                if #sources.ips > 0 then
                    send(id, "  Found in IP records: " .. #sources.ips .. " unique IPs")
                end

                if #sources.hashes > 0 then
                    local pirated_count = 0
                    for _, hash in ipairs(sources.hashes) do
                        if CONFIG.KNOWN_PIRATED_HASHES[hash] then
                            pirated_count = pirated_count + 1
                        end
                    end
                    send(id, "  Found in hash records: " .. #sources.hashes .. " unique hashes")
                    if pirated_count > 0 then
                        send(id, "  [PIRATED COPIES DETECTED: " .. pirated_count .. "]")
                    end
                end

                details_shown = details_shown + 1
                if details_shown >= max_details then
                    break
                end
            end
        end

        if total_matches > max_details then
            send(id, "... and " .. (total_matches - max_details) .. " more matches")
        end
    end

    if total_pages > 1 then
        send(id, "Use '/alias search \"" .. args[3] .. "\" " .. (page + 1) .. "' to see next page")
    end
end

local function showHelp(id)
    send(id, "=== Alias System Commands ===")
    send(id, "/alias hash <player_id> [page]      - Lookup aliases by player hash")
    send(id, "/alias ip <player_id> [page]        - Lookup aliases by player IP")
    send(id, "/alias hash_lookup <hash> [page]    - Direct hash lookup")
    send(id, "/alias ip_lookup <ip> [page]        - Direct IP lookup")
    send(id, "/alias search <partial_name> [page] - Fuzzy search for names")
    send(id, "/alias help                         - Show this help")
end

local function loadAliasesDB()
    local f = io_open(db_directory, 'r')
    if not f then
        aliases_db = DEFAULT_DB
        return true
    end

    local content = f:read('*a')
    f:close()

    if content and content ~= '' then
        local success, result = pcall(function()
            return json:decode(content)
        end)
        if success and result then
            aliases_db = {
                ip_records = result.ip_records or {},
                hash_records = result.hash_records or {}
            }
            return true
        else
            cprint("[alias_system] Error parsing aliases database: " .. tostring(result), 12)
            aliases_db = DEFAULT_DB
            return false
        end
    else
        aliases_db = DEFAULT_DB
        return true
    end
end

local function saveAliasesDB()
    local f, err = io_open(db_directory, 'w')
    if not f then
        cprint("[alias_system] Error opening aliases database for writing: " .. err, 12)
        return false
    end

    local success, json_str = pcall(function()
        return json:encode(aliases_db)
    end)

    if not success then
        cprint("[alias_system] Error encoding aliases database: " .. tostring(json_str), 12)
        f:close()
        return false
    end

    f:write(json_str)
    f:close()
    return true
end

local function parseArgs(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function hasPermission(id)
    if id == 0 then return true end
    local lvl = tonumber(get_var(id, '$lvl'))
    return lvl >= CONFIG.REQUIRED_PERMISSION_LEVEL
end

local function updatePlayerRecord(id)
    if not player_present(id) then return end

    local now = os_time()
    local name = get_var(id, '$name')
    local hash = get_var(id, '$hash')
    local ip = get_var(id, '$ip'):match('%d+.%d+.%d+.%d+')

    -- Apply filters - skip if IP or name should be ignored
    if applyFilters("ip", ip, name) then return end

    -- Update hash record
    if not aliases_db.hash_records[hash] then
        aliases_db.hash_records[hash] = { names = {}, last_seen = now }
    end

    aliases_db.hash_records[hash].names[name] = true
    aliases_db.hash_records[hash].last_seen = now

    -- Update IP record (only if IP is not filtered)
    if not shouldIgnoreIP(ip) then
        if not aliases_db.ip_records[ip] then
            aliases_db.ip_records[ip] = { names = {}, last_seen = now }
        end

        aliases_db.ip_records[ip].names[name] = true
        aliases_db.ip_records[ip].last_seen = now
    end
end

function OnScriptLoad()
    local success, result = pcall(function()
        return loadfile('json.lua')()
    end)

    if not success or not result then
        cprint("[alias_system] Failed to load json.lua. Make sure the file exists and is valid.", 12)
        return
    end
    json = result

    local directory = getConfigPath()
    db_directory = directory .. '\\sapp\\aliases.json'

    if not loadAliasesDB() then
        cprint("[alias_system] Warning: Could not load aliases database, starting with empty database", 12)
    end

    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    register_callback(cb['EVENT_GAME_START'], 'OnStart')

    OnStart(true)

    if CONFIG.DELETE_STALE_RECORDS then
        timer(1000, "CheckStaleRecords")
    end
end

local function isOnCooldown(id, command)
    local key = id .. "_" .. command
    local current_time = os_time()

    if command_cooldowns[key] then
        local time_since_last_use = current_time - command_cooldowns[key]
        if time_since_last_use < CONFIG.COOLDOWN then
            return true, CONFIG.COOLDOWN - time_since_last_use
        end
    end

    command_cooldowns[key] = current_time
    return false, 0
end

function OnCommand(id, command)
    local args = parseArgs(command)
    if #args == 0 then return end

    local cmd = args[1]:lower()

    if cmd == "alias" then
        if not hasPermission(id) then
            send(id, "You do not have permission to use this command")
            return false
        end

        if isOnCooldown(id, "alias") then return false end

        local subcommand = args[2] and args[2]:lower() or "help"

        if subcommand == "help" then
            showHelp(id)
        elseif subcommand == "hash" then
            if CONFIG.COMMANDS.hash then
                handlePlayerBasedLookup(id, args, "hash", "hash")
            else
                send(id, "Hash lookup command is disabled")
            end
        elseif subcommand == "ip" then
            if CONFIG.COMMANDS.ip then
                handlePlayerBasedLookup(id, args, "ip", "ip")
            else
                send(id, "IP lookup command is disabled")
            end
        elseif subcommand == "hash_lookup" then
            if CONFIG.COMMANDS.hash_lookup then
                handleDirectLookup(id, args, "hash", "hash_lookup")
            else
                send(id, "Direct hash lookup command is disabled")
            end
        elseif subcommand == "ip_lookup" then
            if CONFIG.COMMANDS.ip_lookup then
                handleDirectLookup(id, args, "ip", "ip_lookup")
            else
                send(id, "Direct IP lookup command is disabled")
            end
        elseif subcommand == "search" then
            if CONFIG.COMMANDS.search then
                handleFuzzySearch(id, args, "search")
            else
                send(id, "Search command is disabled")
            end
        else
            send(id, "Unknown subcommand: " .. subcommand)
            showHelp(id)
        end

        return false
    end
end

function OnStart(script_load)
    if get_var(0, '$gt') == 'n/a' then return end

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i, script_load)
        end
    end
end

function OnEnd()
    if CONFIG.UPDATE.on_end then
        saveAliasesDB()
    end
end

function OnJoin(id, script_load)
    updatePlayerRecord(id)
    if not script_load and CONFIG.UPDATE.on_join then
        saveAliasesDB()
    end
end

function CheckStaleRecords()
    local now = os_time()
    local stale_seconds = CONFIG.STALE_PERIOD * 24 * 60 * 60
    local deleted_count = 0

    for hash, record in pairs(aliases_db.hash_records) do
        if now - record.last_seen > stale_seconds then
            aliases_db.hash_records[hash] = nil
            deleted_count = deleted_count + 1
        end
    end

    for ip, record in pairs(aliases_db.ip_records) do
        if now - record.last_seen > stale_seconds then
            aliases_db.ip_records[ip] = nil
            deleted_count = deleted_count + 1
        end
    end

    if deleted_count > 0 then
        cprint("[alias_system] Deleted " .. deleted_count .. " stale alias records", 12)
        saveAliasesDB()
    end

    return true
end

function OnScriptUnload()
    saveAliasesDB()
end