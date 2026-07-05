--[[
=====================================================================================
SCRIPT NAME:      breadcrumb_tracker.lua
DESCRIPTION:      Tracks player identity across name changes using IP (including /24
                  subnet), CD-key hash, and VPN detection. Logs suspicious
                  joins automatically. Admins can query crumbs with /crumbs <id>.

FEATURES:
                  - Records every player's name, IP, /24 subnet, and hash.
                  - On join, checks if the IP, subnet, or hash was used by a different
                    name; prints details to console and log file.
                  - Flags known pirated CD-key hashes.
                  - Optional VPN/proxy detection via IPQualityScore API (free tier).
                  - Admin command: /crumbs <player_id> [page]
                    Shows all known linked identities, paginated (15 per page).
                  - Automatic stale record cleanup.
                  - Composite risk score (0-100%) based on IP, subnet, hash & VPN.
                  - VPN IP cross-referencing: shows all names that used a flagged IP.
                  - Caching for IPQS lookups (24h TTL) to save quota.
                  - Optional user_agent param for better fraud scoring.
                  - Differentiates alerts for pirated hashes.

REQUIREMENTS:     Install in the same folder as sapp.dll.
                  - Lua JSON Parser:  http://regex.info/blog/lua/json
                  - SAPP HTTP Client: https://opencarnage.net/index.php?/topic/5998-sapp-http-client/
                  - IPQualityScore API key (free): https://www.ipqualityscore.com/
                                                   https://www.ipqualityscore.com/user/api-keys

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START --
local config = {

    -- Permission level needed to use the /crumbs command.
    required_level = 4,

    -- File names for database and event log.
    db_file = "breadcrumb_db.json",
    log_file = "breadcrumb_events.txt",

    -- List of IP patterns to ignore (wildcards * and ? supported).
    ignore_ips = {
        "192.168.*",
        "10.*"
        --"127.0.0.1"
    },

    -- Names to ignore
    ignore_names = { "Player", "sapp*", "halo*" },

    -- Known pirated CD-key hashes - players using these are flagged.
    -- Set to nil or false to disable.
    pirated_hashes = {
        ['388e89e69b4cc08b3441f25959f74103'] = true,
        ['81f9c914b3402c2702a12dc1405247ee'] = true,
        ['c939c09426f69c4843ff75ae704bf426'] = true,
        ['13dbf72b3c21c5235c47e405dd6e092d'] = true,
        ['29a29f3659a221351ed3d6f8355b2200'] = true,
        ['d72b3f33bfb7266a8d0f13b37c62fddb'] = true,
        ['76b9b8db9ae6b6cacdd59770a18fc1d5'] = true,
        ['55d368354b5021e7dd5d3d1525a4ab82'] = true,
        ['d41d8cd98f00b204e9800998ecf8427e'] = true,
        ['c702226e783ea7e091c0bb44c2d0ec64'] = true,
        ['f443106bd82fd6f3c22ba2df7c5e4094'] = true,
        ['10440b462f6cbc3160c6280c2734f184'] = true,
        ['3d5cd27b3fa487b040043273fa00f51b'] = true,
        ['b661a51d4ccf44f5da2869b0055563cb'] = true,
        ['740da6bafb23c2fbdc5140b5d320edb1'] = true,
        ['7503dad2a08026fc4b6cfb32a940cfe0'] = true,
        ['4486253cba68da6786359e7ff2c7b467'] = true,
        ['f1d7c0018e1648d7d48f257dc35e9660'] = true,
        ['40da66d41e9c79172a84eef745739521'] = true,
        ['2863ab7e0e7371f9a6b3f0440c06c560'] = true,
        ['34146dc35d583f2b34693a83469fac2a'] = true,
        ['b315d022891afedf2e6bc7e5aaf2d357'] = true,
        ['63bf3d5a51b292cd0702135f6f566bd1'] = true,
        ['6891d0a75336a75f9d03bb5e51a53095'] = true,
        ['325a53c37324e4adb484d7a9c6741314'] = true,
        ['0e3c41078d06f7f502e4bb5bd886772a'] = true,
        ['fc65cda372eeb75fc1a2e7d19e91a86f'] = true,
        ['f35309a653ae6243dab90c203fa50000'] = true,
        ['50bbef5ebf4e0393016d129a545bd09d'] = true,
        ['a77ee0be91bd38a0635b65991bc4b686'] = true,
        ['3126fab3615a94119d5fe9eead1e88c1'] = true,
        ['2f02b641060da979e2b89abcfa1af3d6'] = true,
        ['ac73d9785215e196074d418d1cce825b'] = true,
        ['54f4d0236653a6da6429bfc79015f526'] = true
    },

    -- VPN detection via IPQualityScore (set enabled = true and paste API key)
    -- Full documentation: https://www.ipqualityscore.com/documentation/proxy-detection-api/best-practices
    vpn_detection = {

        -- GLOBAL SWITCH
        -- true  -> query IPQS on every join (cache saves quota)
        -- false -> skip all VPN lookups
        enabled = true,

        -- AUTHENTICATION
        api_key = "PASTE_API_KEY_HERE",

        -- SCORING STRICTNESS (0-3)
        -- 0 = lowest strictness (default), expands tests as value increases.
        -- Levels 2+ carry a higher risk of false positives.
        -- It is recommended to start at 0 and increase only if necessary.
        strictness = 1,

        -- SPEED VS ACCURACY
        -- true  -> faster API response, slightly degraded accuracy.
        -- false -> normal processing time, highest accuracy.
        fast = false,

        -- PENALTY CALIBRATION
        -- true  -> lower fraud scores & proxy detection for mixed-quality IPs; reduces false positives.
        -- false -> default penalty weights.
        lighter_penalties = false,

        -- PUBLIC ACCESS POINTS
        -- true  -> exempt IPs from schools, hotels, businesses, and universities from certain checks.
        -- false -> treat all IPs equally.
        allow_public_access_points = true,

        -- MOBILE DEVICE SCORING
        -- true  -> force-score the IP as a mobile device (not needed if you pass a user_agent).
        -- false -> auto-detect.
        mobile = false,

        -- DETECTION THRESHOLDS
        -- Number of individual tests that must FAIL before the IP is considered "VPN/proxy".
        -- Increase to reduce false positives; decrease to catch more borderline cases.
        min_checks = 2,

        -- IPQS fraud score range: 0 (safe) - 100 (definite fraud).
        --   0-74  = low risk, normal ISP.
        --   75-84 = suspicious (often proxy/VPN/Tor, but not necessarily fraudulent) - flag, don't block.
        --   85-89 = high confidence of abusive/malicious behavior.
        --   90+   = very high confidence; strongly recommended to block.
        fraud_score_threshold = 85,

        -- INDIVIDUAL CHECK FLAGS
        -- Set to true to enable each detection category.

        -- IP is associated with a commercial VPN service
        check_vpn = true,
        -- IP is an active proxy (elite, anonymous, SOCKS, etc.)
        check_proxy = true,
        -- IP is a Tor exit node
        check_tor = true,
        -- IP belongs to a crawler.
        check_crawler = false,
        -- This setting is for premium accounts only; IP recently used by bots/non-human traffic.
        bot_status = false,
        -- Optional user-agent string to improve scoring accuracy.
        -- Leave empty to not send any.
        user_agent = "SAPP/10.2.1 (HaloPC/CE)",

        -- Cache TTL (seconds) for IPQS responses to avoid duplicate lookups.
        -- Default 24 hours
        cache_ttl = 86400
    },

    -- Weights for the composite risk score (0-100).
    risk_weights = {
        ip_match = 30,
        subnet_match = 10,
        hash_match = 5,
        vpn_flag = 20,
        pirated_hash = 5 -- extra weight if the hash is a known pirated one
    },

    -- Days before unused records are deleted.
    stale_days = 30,

    -- Entries per page for /crumbs
    page_size = 15
}
-- END CONFIG --

api_version = '1.12.0.0'

local io_open = io.open
local os_time, os_date = os.time, os.date
local pairs, ipairs = pairs, ipairs
local tonumber, tostring = tonumber, tostring
local table_insert, table_concat = table.insert, table.concat
local math_ceil, math_min, math_floor = math.ceil, math.min, math.floor
local fmt = string.format
local pcall = pcall

local get_var = get_var
local player_present = player_present
local register_callback = register_callback
local rprint = rprint
local cprint = cprint

local json = (loadfile 'json.lua')()

local db = {
    -- ip_records[ip] = { names = {name=true,...}, hashes = {hash=true,...}, last_seen = timestamp, vpn = bool?, vpn_details }
    -- subnet_records[/24] = { names = {name=true,...}, last_seen = timestamp }
    -- hash_records[hash] = { names = {name=true,...}, ips = {ip=true,...}, last_seen = timestamp, is_pirated = bool }
}
db.ip_records = {}
db.subnet_records = {}
db.hash_records = {}

-- Cache for IPQS results: vpn_cache[ip] = { timestamp = ..., data = ... }
local vpn_cache = {}

local ffi, client
if config.vpn_detection.enabled then
    ffi = require('ffi')
    ffi.cdef [[
        typedef void http_response;
        http_response *http_get(const char *url, bool async);
        void http_destroy_response(http_response *);
        void http_wait_async(const http_response *);
        bool http_response_is_null(const http_response *);
        bool http_response_received(const http_response *);
        const char *http_read_response(const http_response *);
    ]]
    client = ffi.load('lua_http_client')
end

-- Super duper simple URL encoder (just replaces spaces and a few common chars)
local function url_encode(str)
    if not str or str == '' then return '' end
    str = str:gsub(" ", "%%20")
    str = str:gsub(":", "%%3A")
    str = str:gsub("/", "%%2F")
    -- add more if needed, but this is enough for basic user agents
    return str
end

-- turn a simple * and ? wildcard into a Lua pattern, then anchor it
local function wildcard_match(str, pattern)
    pattern = pattern:gsub("%*", ".*"):gsub("%?", ".")
    return str:match("^" .. pattern .. "$") ~= nil
end

local function is_ignored_ip(ip)
    for _, p in ipairs(config.ignore_ips) do
        if wildcard_match(ip, p) then return true end
    end
    return false
end

local function is_ignored_name(name)
    for _, p in ipairs(config.ignore_names) do
        if wildcard_match(name, p) then return true end
    end
    return false
end

-- grab the first three octets so we can lump /24 neighbours together
local function get_subnet(ip)
    return ip:match("^(%d+%.%d+%.%d+)") or ip
end

local function save_db()
    local file = io_open(config.db_file, 'w')
    if file then
        file:write(json:encode_pretty(db))
        file:close()
    end
end

local function load_db()
    local file = io_open(config.db_file, 'r')
    if file then
        local content = file:read('*all')
        file:close()
        if content and content ~= '' then
            local ok, decoded = pcall(json.decode, json, content)
            if ok and decoded then
                db.ip_records = decoded.ip_records or {}
                db.subnet_records = decoded.subnet_records or {}
                db.hash_records = decoded.hash_records or {}
                return
            end
        end
    end
    db.ip_records = {}
    db.subnet_records = {}
    db.hash_records = {}
end

local function log_event(msg)
    local file = io_open(config.log_file, 'a')
    if file then
        file:write(os_date('[%Y-%m-%d %H:%M:%S] ') .. msg .. '\n')
        file:close()
    end
end

-- holds VPN lookups, keyed by player id as a string
local async_requests = {}

-- tally up the individual IPQS checks that failed, then compare to min_checks
local function vpn_should_block(data)
    local cfg = config.vpn_detection
    local failed = 0
    if cfg.check_vpn and data.vpn then failed = failed + 1 end
    if cfg.check_proxy and data.proxy then failed = failed + 1 end
    if cfg.check_tor and data.tor then failed = failed + 1 end
    if cfg.check_crawler and data.is_crawler then failed = failed + 1 end
    if cfg.bot_status and data.bot_status then failed = failed + 1 end
    if data.fraud_score and data.fraud_score >= cfg.fraud_score_threshold then failed = failed + 1 end
    return failed >= cfg.min_checks
end

-- Check the VPN cache first; return true if we used the cache and already handled everything (no HTTP needed)
local function check_vpn_cache(ip, player_id)
    local cached = vpn_cache[ip]
    if cached and (os_time() - cached.timestamp) < config.vpn_detection.cache_ttl then
        local data = cached.data
        local suspicious = vpn_should_block(data)
        -- update db with cached result
        if db.ip_records[ip] then
            db.ip_records[ip].vpn = suspicious
            db.ip_records[ip].vpn_details = data
            db.ip_records[ip].vpn_checked = os_time()
            save_db()
        end
        if suspicious then
            local name = get_var(player_id, '$name') or 'Unknown'
            cprint(
                fmt('[Breadcrumb] %s joined with VPN/proxy (IP: %s, fraud: %d)', name, ip, data.fraud_score or 0), 12
            )
            log_event(
                fmt(
                    'VPN_DETECTED player=%s ip=%s fraud=%d vpn=%s proxy=%s tor=%s', name, ip, data.fraud_score or 0,
                    tostring(data.vpn), tostring(data.proxy), tostring(data.tor)
                )
            )
        end
        return true
    end
    return false
end

-- fire off an async HTTP request and set up a repeating timer to poll for the result
local function vpn_check_async(player_id, ip)
    -- try the cache first
    if check_vpn_cache(ip, player_id) then return end

    local cfg = config.vpn_detection
    local url = 'https://www.ipqualityscore.com/api/json/ip/' .. cfg.api_key
        .. '/' .. ip
        .. '?strictness=' .. cfg.strictness
        .. '&allow_public_access_points=' .. tostring(cfg.allow_public_access_points)
        .. '&lighter_penalties=' .. tostring(cfg.lighter_penalties)
        .. '&fast=' .. tostring(cfg.fast)
        .. '&mobile=' .. tostring(cfg.mobile)
    if cfg.user_agent and cfg.user_agent ~= '' then
        url = url .. '&user_agent=' .. url_encode(cfg.user_agent)
    end
    local response = client.http_get(url, true)
    async_requests[tostring(player_id)] = { response, ip, player_id }
    timer(1000, 'ProcessVPNResponse', player_id)
end

-- called every second until the async response arrives; processes it when ready
function ProcessVPNResponse(id)
    id = tonumber(id)
    local key = tostring(id)
    local entry = async_requests[key]
    if not entry then return end
    local response, ip, pid = entry[1], entry[2], entry[3]

    if client.http_response_received(response) then
        if not client.http_response_is_null(response) then
            local result_str = ffi.string(client.http_read_response(response))
            local ok, data = pcall(json.decode, json, result_str)
            if ok and data then
                -- cache the response
                vpn_cache[ip] = { timestamp = os_time(), data = data }

                local suspicious = vpn_should_block(data)
                if db.ip_records[ip] then
                    db.ip_records[ip].vpn = suspicious
                    db.ip_records[ip].vpn_details = data
                    db.ip_records[ip].vpn_checked = os_time()
                    save_db()
                end
                if suspicious then
                    local name = get_var(pid, '$name') or 'Unknown'
                    cprint(
                        fmt(
                            '[Breadcrumb] %s joined with VPN/proxy (IP: %s, fraud: %d)', name, ip, data.fraud_score or 0
                        ), 12
                    )
                    log_event(
                        fmt(
                            'VPN_DETECTED player=%s ip=%s fraud=%d vpn=%s proxy=%s tor=%s', name, ip,
                            data.fraud_score or 0, tostring(data.vpn), tostring(data.proxy), tostring(data.tor)
                        )
                    )
                end
            end
        end
        client.http_destroy_response(response)
        async_requests[key] = nil
    else
        -- not done yet, keep polling
        timer(1000, 'ProcessVPNResponse', id)
    end
end

-- stash this player's info to cross-reference later
local function update_records(name, ip, hash)
    local now = os_time()
    if is_ignored_name(name) then return end

    -- IP (and its /24 subnet) only if we aren't ignoring that IP
    if not is_ignored_ip(ip) then
        if not db.ip_records[ip] then
            db.ip_records[ip] = { names = {}, hashes = {}, last_seen = now }
        end
        db.ip_records[ip].names[name] = true
        db.ip_records[ip].hashes[hash] = true
        db.ip_records[ip].last_seen = now

        -- /24 subnet catches everyone behind the same router, even if DHCP gave different local IPs.
        -- At least that's the idea.
        local subnet = get_subnet(ip)
        if not db.subnet_records[subnet] then
            db.subnet_records[subnet] = { names = {}, last_seen = now }
        end
        db.subnet_records[subnet].names[name] = true
        db.subnet_records[subnet].last_seen = now
    end

    -- Hash record always gets updated (pirate flag set when we first see it)
    if not db.hash_records[hash] then
        db.hash_records[hash] = { names = {}, ips = {}, last_seen = now }
    end
    db.hash_records[hash].names[name] = true
    db.hash_records[hash].ips[ip] = true
    db.hash_records[hash].last_seen = now
    if config.pirated_hashes[hash] then
        db.hash_records[hash].is_pirated = true
    end
end

-- Compute a simple risk score based on found aliases and VPN status.
-- Called after check_for_alias has identified links.
local function calculate_risk_score(name, ip, hash, alerts)
    local w = config.risk_weights
    local score = 0
    local max = 0

    -- Check which categories we have alerts for
    local has_ip, has_subnet, has_hash, has_vpn = false, false, false, false

    for _, alert in ipairs(alerts) do
        if alert:find('same IP') and not alert:find('subnet') then has_ip = true end
        if alert:find('subnet') then has_subnet = true end
        if alert:find('same hash') then has_hash = true end
    end

    -- VPN flag
    if ip and not is_ignored_ip(ip) and db.ip_records[ip] and db.ip_records[ip].vpn then
        has_vpn = true
    end

    -- Accumulate weighted score
    if has_ip then score = score + w.ip_match end
    if has_subnet then score = score + w.subnet_match end
    if has_hash then score = score + w.hash_match end
    if has_vpn then score = score + w.vpn_flag end
    -- Bonus for pirated hash if the alert includes it (hash alert + pirated)
    if has_hash and config.pirated_hashes[hash] then
        score = score + w.pirated_hash
    end

    max = w.ip_match + w.subnet_match + w.hash_match + w.vpn_flag + w.pirated_hash
    if max == 0 then return 0 end
    local percent = math_floor((score / max) * 100 + 0.5)
    return math_min(percent, 100)
end

-- see if this player has shown up before under a different name or on a nearby IP
local function check_for_alias(name, ip, hash, id)
    local alerts = {}

    if not is_ignored_ip(ip) and db.ip_records[ip] then
        for prev_name in pairs(db.ip_records[ip].names) do
            if prev_name ~= name then
                local extra = ''
                if db.ip_records[ip].vpn then extra = ' (VPN IP)' end
                table_insert(alerts, fmt('Seen as "%s" from same IP (%s)%s', prev_name, ip, extra))
            end
        end
    end

    -- Check /24 subnet (only if IP not ignored)
    local subnet = get_subnet(ip)
    if not is_ignored_ip(ip) and db.subnet_records[subnet] then
        for prev_name in pairs(db.subnet_records[subnet].names) do
            if prev_name ~= name then
                -- don't spam the same name twice if it was already reported as an exact IP match
                local already = false
                for _, a in ipairs(alerts) do
                    if a:find(prev_name, 1, true) and a:find('subnet') then
                        already = true
                        break
                    end
                end
                if not already then
                    table_insert(alerts, fmt('Seen as "%s" from same /24 subnet (%s.*)', prev_name, subnet))
                end
            end
        end
    end

    -- Check hash
    if db.hash_records[hash] then
        for prev_name in pairs(db.hash_records[hash].names) do
            if prev_name ~= name then
                local extra = ''
                if config.pirated_hashes[hash] then extra = ' [PIRATED shared hash]' end
                table_insert(alerts, fmt('Seen as "%s" with same hash (%s)%s', prev_name, hash, extra))
            end
        end
    end

    -- If VPN wasn't in the alerts already from IP match, add a note if more than one name used this VPN IP
    if ip and not is_ignored_ip(ip) and db.ip_records[ip] and db.ip_records[ip].vpn then
        local ip_record = db.ip_records[ip]
        local other_names = {}
        for n in pairs(ip_record.names) do
            if n ~= name then table_insert(other_names, n) end
        end
        if #other_names > 0 then
            -- but avoid duplicate if we already have an IP alert
            local already_alerted = false
            for _, a in ipairs(alerts) do
                if a:find('same IP') and not a:find('subnet') then
                    already_alerted = true
                    break
                end
            end
            if not already_alerted then
                local list = table_concat(other_names, ', ')
                table_insert(alerts, fmt('VPN IP also used by: %s', list))
            end
        end
    end

    if #alerts > 0 then
        local risk = calculate_risk_score(name, ip, hash, alerts)
        local msg = fmt(
            '[Breadcrumb] %s (ID %d) entered with IP %s, hash %s%s. Risk: %d%%. Aliases: %s', name, id, ip, hash,
            config.pirated_hashes[hash] and ' [PIRATED]' or '', risk, table_concat(alerts, '; ')
        )
        cprint(msg, 10)
        log_event(msg)
    end
end

-- admin command to dump everything we know about a given player
local function show_player_crumbs(admin_id, target_id, page)
    page = page or 1
    if page < 1 then page = 1 end

    local name = get_var(target_id, '$name')
    local hash = get_var(target_id, '$hash')
    local ip_raw = get_var(target_id, '$ip')
    local ip = ip_raw:match('%d+%.%d+%.%d+%.%d+')

    rprint(admin_id, '=== crumbs for Player ' .. target_id .. ' (' .. name .. ') ===')

    -- Collect unique names from all sources
    local alias_set = {}

    -- from exact IP
    if ip and not is_ignored_ip(ip) and db.ip_records[ip] then
        for n in pairs(db.ip_records[ip].names) do
            if n ~= name then alias_set[n] = true end
        end
    end

    -- from /24 subnet
    local subnet = ip and get_subnet(ip)
    if subnet and not is_ignored_ip(ip) and db.subnet_records[subnet] then
        for n in pairs(db.subnet_records[subnet].names) do
            if n ~= name then alias_set[n] = true end
        end
    end

    -- from hash
    if db.hash_records[hash] then
        for n in pairs(db.hash_records[hash].names) do
            if n ~= name then alias_set[n] = true end
        end
    end

    -- Convert set to sorted list
    local aliases = {}
    for n in pairs(alias_set) do
        table_insert(aliases, n)
    end
    table.sort(aliases)

    local total_aliases = #aliases
    if total_aliases == 0 then
        rprint(admin_id, 'No known aliases found.')
    else
        local page_size = config.page_size
        local total_pages = math_ceil(total_aliases / page_size)
        if page > total_pages then page = total_pages end

        local start_index = (page - 1) * page_size + 1
        local end_index = math_min(page * page_size, total_aliases)

        rprint(admin_id, fmt('Page %d of %d (%d total aliases)', page, total_pages, total_aliases))

        for i = start_index, end_index do
            rprint(admin_id, '  ' .. aliases[i])
        end
    end

    -- Show risk score for this player based on current data
    local temp_alerts = {}
    if ip and not is_ignored_ip(ip) and db.ip_records[ip] then
        for prev_name in pairs(db.ip_records[ip].names) do
            if prev_name ~= name then
                table_insert(temp_alerts, 'IP alias ' .. prev_name)
            end
        end
    end
    if subnet and not is_ignored_ip(ip) and db.subnet_records[subnet] then
        for prev_name in pairs(db.subnet_records[subnet].names) do
            if prev_name ~= name then
                table_insert(temp_alerts, 'subnet alias ' .. prev_name)
            end
        end
    end
    if db.hash_records[hash] then
        for prev_name in pairs(db.hash_records[hash].names) do
            if prev_name ~= name then
                table_insert(temp_alerts, 'hash alias ' .. prev_name)
            end
        end
    end
    local risk = calculate_risk_score(name, ip, hash, temp_alerts)
    rprint(admin_id, 'Composite risk score: ' .. risk .. '%')

    -- VPN / proxy info
    if ip and not is_ignored_ip(ip) and db.ip_records[ip] and db.ip_records[ip].vpn ~= nil then
        rprint(admin_id, 'VPN/proxy detected: ' .. (db.ip_records[ip].vpn and 'YES' or 'NO'))
    end

    -- Pirated hash warning
    if db.hash_records[hash] and db.hash_records[hash].is_pirated then
        rprint(admin_id, '  [WARNING: Known pirated hash]')
    end
end

local function parseArgs(input, delimiter)
    local result = {}
    for substring in input:gmatch("([^" .. delimiter .. "]+)") do
        result[#result + 1] = substring
    end
    return result
end

function OnCommand(id, cmd)
    local args = parseArgs(cmd, " ")
    if #args == 0 or args[1] ~= 'crumbs' then return true end

    local lvl = tonumber(get_var(id, '$lvl'))
    if id ~= 0 and lvl < config.required_level then
        rprint(id, 'You do not have permission to use this command.')
        return false
    end

    if not args[2] then
        rprint(id, 'Usage: /crumbs <player_id> [page]')
        return false
    end

    local target_id = tonumber(args[2])
    if not target_id or not player_present(target_id) then
        rprint(id, 'Invalid or offline player ID.')
        return false
    end

    local page = tonumber(args[3]) or 1
    show_player_crumbs(id, target_id, page)
    return false
end

function OnScriptLoad()
    load_db()
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    log_event('Breadcrumb Tracker loaded')

    timer(3600000, 'CleanStaleRecords') -- hourly cleanup
    -- if the script loaded while a game is in progress, catch any players already online
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnJoin(id)
    local name = get_var(id, '$name')
    local hash = get_var(id, '$hash')
    local ip_raw = get_var(id, '$ip')
    local ip = ip_raw:match('%d+%.%d+%.%d+%.%d+') or ip_raw

    if is_ignored_name(name) then return end
    if is_ignored_ip(ip) then ip = nil end -- don't track ignored IPs at all

    check_for_alias(name, ip, hash, id)
    update_records(name, ip, hash)
    save_db()

    -- kick off an async VPN check if enabled and API key looks valid
    if ip and config.vpn_detection.enabled and config.vpn_detection.api_key ~= 'PASTE_API_KEY_HERE' then
        vpn_check_async(id, ip)
    end
end

function CleanStaleRecords()
    local now = os_time()
    local limit = config.stale_days * 86400
    local deleted = 0

    for ip, rec in pairs(db.ip_records) do
        if now - rec.last_seen > limit then
            db.ip_records[ip] = nil
            deleted = deleted + 1
        end
    end
    for subnet, rec in pairs(db.subnet_records) do
        if now - rec.last_seen > limit then
            db.subnet_records[subnet] = nil
            deleted = deleted + 1
        end
    end
    for hash, rec in pairs(db.hash_records) do
        if now - rec.last_seen > limit then
            db.hash_records[hash] = nil
            deleted = deleted + 1
        end
    end

    -- also clean up vpn cache entries older than TTL
    local cache_ttl = config.vpn_detection.cache_ttl
    for ip, entry in pairs(vpn_cache) do
        if now - entry.timestamp > cache_ttl then
            vpn_cache[ip] = nil
        end
    end

    if deleted > 0 then
        save_db()
        cprint('[Breadcrumb] Cleared ' .. deleted .. ' stale records.', 8)
    end

    -- SAPP expects a truthy return to keep a repeating timer going
    return true
end

function OnScriptUnload()
    save_db()
end
