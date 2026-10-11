--[[
=====================================================================================
SCRIPT NAME:      vpn_blocker.lua
DESCRIPTION:      Automatically screens connecting players against IPQualityScore
                  and removes players whose IP is positively identified as a VPN,
                  Tor node or proxy.

HOW IT DECIDES (see "policy" in the config):
                  1. DEFINITIVE   active_tor / active_vpn are set by IPQS
                                  -> blocked on their own.
                  2. SUSPECTED    tor / vpn / proxy flags
                                  -> blocked ONLY when corroborated by at least one
                                     independent signal (data-centre range, high fraud
                                     score, recent abuse, ...).
                  3. NEVER        A fraud score, bot flag or abuse history on its own
                                  never blocks anybody. Verified crawlers, security
                                  scanners and trusted networks are never blocked on
                                  suspicion alone.
                  If a lookup fails for ANY reason the player is allowed (fail-open).

FEATURES:
                  - Non-blocking lookups through sapp_http.dll (never stalls the server)
                  - Built-in JSON parser (no external library to download)
                  - API key sent in the IPQS-KEY header (never appears in a URL)
                  - Retries with exponential backoff on timeouts / 429 / 5xx
                  - Rate limiting, request queue and in-flight de-duplication per IP
                  - Result cache (in memory + optional file) to save API credits
                  - IP / CIDR exclusion list; private/reserved addresses are skipped
                  - Handles slot reuse: a verdict only applies to the player it was for
                  - Automatic pause when the API key is invalid or credits run out
                  - Admin command /ipqs <ip|player#> for on-demand lookups

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - SAPP HTTP Client:       https://github.com/Chalwk/SAPP-HTTP
                  - IPQualityScore API Key: https://www.ipqualityscore.com/

LAST UPDATED:     12 Oct 2026

Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local ffi = require('ffi')
local bit = require('bit')

local config = {

    -------------------
    -- config starts --
    -------------------

    -- IPQualityScore API key (https://www.ipqualityscore.com/):
    api_key = 'PASTE_API_KEY_HERE',

    -- Action taken against a blocked player:
    --   'k' = kick   (k <id> [reason])
    --   'b' = IP ban (ipban <id> [time] [reason])
    -- NOTE: 'b' deliberately uses SAPP's IP ban, not the hash ban ('b' command).
    -- Hash bans hit innocent players on shared/cracked CD keys and do nothing
    -- against someone who simply reconnects through the same VPN.
    action = 'k',

    -- IP ban length in minutes (only used when action = 'b'). Whole number >= 1.
    -- Keep this short: VPN/proxy addresses are shared and get reassigned.
    ban_time = 10,

    -- Reason passed to the kick / ban command:
    reason = 'VPN/Proxy/Tor detected',

    -- Message sent privately to the player before they are removed:
    player_feedback = "We've detected that you're using a VPN, proxy or Tor - these are not allowed here.",

    -- Console message. Placeholders (in order): player name, action taken, IP, why.
    console_feedback = '%s was %s for using a VPN, proxy or Tor (IP: %s | %s)',

    -- Print one summary line per lookup (IP, fraud score, flags, decision)?
    -- Blocks and errors are always printed.
    log_verbose = true,

    ----------------------------------------------------------------------------
    -- DETECTION POLICY
    ----------------------------------------------------------------------------
    policy = {

        -- Which kinds of anonymisation to enforce:
        block_tor   = true,
        block_vpn   = true,
        block_proxy = true, -- plain proxies (SOCKS / elite / anonymous, residential proxy networks)

        -- A SUSPECTED flag (tor / vpn / proxy) must be backed by this many
        -- independent corroborating signals before the player is removed.
        -- 1 = recommended. 0 = block on any suspected flag (more false positives).
        -- Definitive flags (active_tor / active_vpn) ignore this setting.
        corroboration_needed = 1,

        -- Signal: IPQS fraud score at or above this value corroborates.
        -- IPQS bands: 75 = suspicious, 85 = high risk, 90 = recommended block.
        -- Set to 0 to disable this signal.
        min_fraud_score = 85,

        -- Signal: the IP sits in a hosting / data-centre range.
        data_center_corroborates = true,

        -- Signal: any of these response flags being true corroborates.
        corroborators = { 'recent_abuse', 'frequent_abuser', 'high_risk_attacks', 'bot_status' },

        -- If ANY of these flags is true, a merely SUSPECTED anonymiser is let through.
        -- (A definitive active_tor / active_vpn result still blocks.)
        never_block = { 'is_crawler', 'security_scanner', 'trusted_network' }
    },

    -- IPs / CIDR ranges that are never checked (e.g. admins who use a VPN):
    exclusion_list = {
        -- '198.51.100.0/24',
    },

    -- Skip private / loopback / link-local / CGNAT / reserved addresses.
    -- They cannot be looked up and would only waste credits.
    skip_non_public = true,

    ----------------------------------------------------------------------------
    -- IPQS REQUEST PARAMETERS (ADVANCED USERS ONLY)
    -- https://www.ipqualityscore.com/documentation/proxy-detection-api/overview
    ----------------------------------------------------------------------------
    parameters = {
        -- 0 is IPQS's recommended starting point. 1 is stricter; 2+ is "VERY
        -- strict" and produces false positives on legitimate residential IPs.
        strictness = 0,

        -- Recommended by IPQS to avoid false positives on universities, hotels,
        -- and corporate networks:
        allow_public_access_points = true,

        -- true LOWERS detection rates and fraud scores. Leave false unless you
        -- are seeing false positives:
        lighter_penalties = false,

        -- true skips slower forensic checks. Leave false:
        fast = false,

        -- Only sent when set to true/false. Leave nil for a normal lookup:
        mobile = nil
    },

    ----------------------------------------------------------------------------
    -- REQUEST TRANSPORT
    ----------------------------------------------------------------------------
    request = {
        api_url       = 'https://ipqualityscore.com/api/json/ip',
        method        = 'POST',     -- 'POST' (recommended) or 'GET'
        key_in_header = true        -- true = IPQS-KEY header.
                                    -- false (GET only) = key in URL path.
    },

    ----------------------------------------------------------------------------
    -- NETWORK BEHAVIOUR
    ----------------------------------------------------------------------------
    network = {
        poll_interval_ms = 100,      -- how often pending requests are serviced
        max_rps          = 5,        -- max new requests started per second (0 = unlimited)
        retries          = 3,        -- extra attempts on timeouts / 429 / 5xx / bad JSON
        backoff          = 1.0,      -- seconds; doubles on each retry (plus a little jitter)
        max_backoff      = 15.0,     -- hard cap on any single wait
        max_pending      = 64,       -- queued + active lookups; beyond this, players are allowed
        fatal_pause      = 600       -- seconds to stop looking up after an invalid key / no credits
    },

    ----------------------------------------------------------------------------
    -- CACHE (each uncached lookup costs an IPQS credit)
    ----------------------------------------------------------------------------
    cache = {
        enabled   = true,
        ttl_hours = 6,
        -- Persisted between restarts. Relative paths resolve against the server's
        -- working directory. Set to nil/false for a memory-only cache.
        file          = 'vpn_blocker_cache.txt',
        max_entries   = 5000,
        save_interval = 300 -- seconds between background saves (also saved on unload)
    },

    ----------------------------------------------------------------------------
    -- ADMIN COMMAND
    -- On-demand lookups: /<name> <ip|player#>
    -- (e.g. /ipqs 45.83.117.206 or /ipqs 3).
    ----------------------------------------------------------------------------
    command = {
        name     = 'ipqs',  -- command name, without the leading slash
        cooldown = 10,      -- minimum seconds between uses
        level    = 4        -- minimum admin level required to use this command
    },

    ----------------------------------------------------------------------------
    -- DEBUGGING (development only - leave disabled on a live server)
    -- Every time the script loads, each IP below is sent to IPQS as a fresh lookup
    -- (the cache is bypassed, and nothing is cached) and a detailed report is
    -- printed: raw response, which flags fired, and the exact decision the policy
    -- would make. Nobody is ever kicked or banned because of a test lookup.
    ----------------------------------------------------------------------------
    debug = {
        enabled       = false,
        test_ips      = { '8.8.8.8' },
        dump_response = true -- also print every field IPQS returned
    }

    -----------------
    -- config ends --
    -----------------
}

--------------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------------

local clock, time = os.clock, os.time
local P, N, C, R, D = config.policy, config.network, config.cache, config.request, config.debug

local PLACEHOLDER_KEYS = { [''] = true, ['PASTE_API_KEY_HERE'] = true, ['REDACTED'] = true }
local PARAM_ORDER = { 'strictness', 'allow_public_access_points', 'lighter_penalties', 'fast', 'mobile' }

local FATAL_MARKERS = {
    'insufficient credits', 'invalid api key', 'invalid or unauthorized', 'unauthorized', 'access denied',
    'account disabled'
}
local RETRY_MARKERS = {
    'rate limit', 'too many requests', 'temporarily unavailable', 'try again', 'timeout', 'service unavailable',
    'internal server error', 'bad gateway', 'gateway timeout'
}

local CDEF = [[
    typedef struct sapp_http_header {
        const char *name;
        const char *value;
    } sapp_http_header;

    typedef struct sapp_http_response {
        int curl_code;
        long http_status;
        size_t body_size;
        char *body;
        char *content_type;
        char *error_message;
    } sapp_http_response;

    typedef struct sapp_http_request sapp_http_request;

    int sapp_http_global_init(void);
    void sapp_http_global_cleanup(void);
    sapp_http_request* sapp_http_create_get(const char *url,
                                            const sapp_http_header *headers,
                                            size_t header_count);
    sapp_http_request* sapp_http_create_post(const char *url,
                                             const char *content_type,
                                             const char *body,
                                             size_t body_size,
                                             const sapp_http_header *headers,
                                             size_t header_count);
    int sapp_http_process(void);
    int sapp_http_request_is_done(sapp_http_request *req);
    int sapp_http_request_get_response(sapp_http_request *req,
                                       sapp_http_response *out);
    void sapp_http_request_free(sapp_http_request *req);
    void sapp_http_free_response(sapp_http_response *response);
    const char *sapp_http_version(void);
]]

local http
local http_ready = false

local players = {}  -- [player id] = record for the player currently in that slot
local inflight = {} -- [ip] = job (queued, active, or waiting to retry)
local queue = {}    -- jobs waiting to be started
local active = 0    -- jobs with a live HTTP request
local next_slot = 0 -- rate limiter: earliest clock() at which another request may start
local paused_until = 0
local paused_noted = false
local cache = {}
local cache_dirty = false
local last_save = 0
local last_proc_err = 0
local ttl = 0

local cmd_cooldown = {}

local EXCLUDED = {}
local NON_PUBLIC = {}

local function log(msg, color)
    cprint('[VPN Blocker] ' .. msg, color or 11)
end
local function vlog(msg, color)
    if config.log_verbose then log(msg, color or 8) end
end

--------------------------------------------------------------------------------
-- IPv4 helpers
--------------------------------------------------------------------------------

-- Accepts "a.b.c.d" or "a.b.c.d:port". Returns numeric value and canonical string.
local function parse_ipv4(s)
    if type(s) ~= 'string' then return nil end
    local a, b, c, d = s:match('^%s*(%d+)%.(%d+)%.(%d+)%.(%d+)')
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not (a and b and c and d) then return nil end
    if a > 255 or b > 255 or c > 255 or d > 255 then return nil end
    return a * 16777216 + b * 65536 + c * 256 + d, string.format('%d.%d.%d.%d', a, b, c, d)
end

-- "a.b.c.d" or "a.b.c.d/n" -> { base, mask }
local function parse_cidr(s)
    s = tostring(s)
    local addr, len = s:match('^%s*([%d%.]+)%s*/%s*(%d+)%s*$')
    local n = 32
    if addr then
        n = tonumber(len)
    else
        addr = s:match('^%s*([%d%.]+)%s*$')
    end
    if not addr or n > 32 then return nil end
    local v = parse_ipv4(addr)
    if not v then return nil end
    local mask = (n == 0) and 0 or bit.lshift(0xFFFFFFFF, 32 - n)
    return { base = bit.band(v, mask), mask = mask }
end

local function in_nets(v, nets)
    for i = 1, #nets do
        if bit.band(v, nets[i].mask) == nets[i].base then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Misc helpers
--------------------------------------------------------------------------------

local function urlencode(s)
    return (tostring(s):gsub('[^%w%-_%.~]', function (ch)
        return string.format('%%%02X', ch:byte())
    end))
end

local function has_marker(msg, list)
    msg = tostring(msg):lower()
    for i = 1, #list do
        if msg:find(list[i], 1, true) then return true end
    end
    return false
end

local function yn(v)
    if v == true then
        return 'Y'
    elseif v == false then
        return 'N'
    end
    return '?'
end

local function normalise_ctype(v)
    return (tostring(v or ''):gsub('[^%a]', ''):lower())
end

---------------------------------------------------------------------------------
-- JSON decoder (strict RFC 8259; objects/arrays/strings/numbers/true/false/null)
---------------------------------------------------------------------------------

local JSON_MAX_DEPTH = 32

local JSON_ESCAPES = {
    [34] = '"',
    [92] = '\\',
    [47] = '/',
    [98] = '\b',
    [102] = '\f',
    [110] = '\n',
    [114] = '\r',
    [116] = '\t'
}

local function codepoint_to_utf8(cp)
    local floor, char = math.floor, string.char
    if cp < 0x80 then
        return char(cp)
    elseif cp < 0x800 then
        return char(0xC0 + floor(cp / 64), 0x80 + cp % 64)
    elseif cp < 0x10000 then
        return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    return char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end

-- Returns the decoded value. Raises an error (string) on malformed input, so call it
-- through pcall. JSON null becomes nil.
local function json_decode(text)
    local find, sub, byte, match = string.find, string.sub, string.byte, string.match
    local len = #text
    local pos = 1

    local function fail(msg, at)
        error(string.format('JSON error: %s at position %d', msg, at or pos), 0)
    end

    local function skip_ws()
        pos = find(text, '[^ \t\r\n]', pos) or (len + 1)
    end

    local function parse_string()
        pos = pos + 1 -- opening quote
        local parts, n = {}, 0
        while true do
            local s = find(text, '["\\\1-\31]', pos)
            if not s then fail('unterminated string', pos) end
            if s > pos then
                n = n + 1
                parts[n] = sub(text, pos, s - 1)
            end

            local c = byte(text, s)
            if c == 34 then
                pos = s + 1
                return table.concat(parts)
            elseif c == 92 then
                local e = byte(text, s + 1)
                n = n + 1
                if e == 117 then -- \uXXXX
                    local hex = match(text, '^%x%x%x%x', s + 2)
                    if not hex then fail('bad \\u escape', s) end
                    local cp = tonumber(hex, 16)
                    local nextpos = s + 6
                    if cp >= 0xD800 and cp <= 0xDBFF then
                        local lo = match(text, '^\\u(%x%x%x%x)', nextpos)
                        lo = lo and tonumber(lo, 16)
                        if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                            cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00)
                            nextpos = nextpos + 6
                        else
                            cp = 0xFFFD
                        end
                    elseif cp >= 0xDC00 and cp <= 0xDFFF then
                        cp = 0xFFFD
                    end
                    parts[n] = codepoint_to_utf8(cp)
                    pos = nextpos
                else
                    local r = e and JSON_ESCAPES[e]
                    if not r then fail('bad escape', s) end
                    parts[n] = r
                    pos = s + 2
                end
            else
                fail('control character in string', s)
            end
        end
    end

    local function parse_number()
        local s, e = find(text, '^-?%d+', pos)
        if not s then fail('invalid value') end
        local int = sub(text, s, e)
        if match(int, '^-?0%d') then fail('leading zero in number') end
        local _, e2 = find(text, '^%.%d+', e + 1)
        if e2 then e = e2 end
        local _, e3 = find(text, '^[eE][+-]?%d+', e + 1)
        if e3 then e = e3 end
        local num = tonumber(sub(text, pos, e))
        if not num then fail('invalid number') end
        pos = e + 1
        return num
    end

    local parse_value

    local function parse_object(depth)
        pos = pos + 1
        local obj = {}
        skip_ws()
        if byte(text, pos) == 125 then
            pos = pos + 1
            return obj
        end
        while true do
            skip_ws()
            if byte(text, pos) ~= 34 then fail('expected string key') end
            local key = parse_string()
            skip_ws()
            if byte(text, pos) ~= 58 then fail("expected ':'") end
            pos = pos + 1
            obj[key] = parse_value(depth + 1)
            skip_ws()
            local c = byte(text, pos)
            if c == 44 then
                pos = pos + 1
            elseif c == 125 then
                pos = pos + 1
                return obj
            else
                fail("expected ',' or '}'")
            end
        end
    end

    local function parse_array(depth)
        pos = pos + 1
        local arr, n = {}, 0
        skip_ws()
        if byte(text, pos) == 93 then
            pos = pos + 1
            return arr
        end
        while true do
            n = n + 1
            arr[n] = parse_value(depth + 1)
            skip_ws()
            local c = byte(text, pos)
            if c == 44 then
                pos = pos + 1
            elseif c == 93 then
                pos = pos + 1
                return arr
            else
                fail("expected ',' or ']'")
            end
        end
    end

    function parse_value(depth)
        if depth > JSON_MAX_DEPTH then fail('nesting too deep') end
        skip_ws()
        local c = byte(text, pos)
        if c == 123 then return parse_object(depth) end
        if c == 91 then return parse_array(depth) end
        if c == 34 then return parse_string() end
        if c == 45 or (c and c >= 48 and c <= 57) then return parse_number() end
        if sub(text, pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        end
        if sub(text, pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        end
        if sub(text, pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        end
        fail(c and 'unexpected character' or 'unexpected end of input')
    end

    if sub(text, 1, 3) == '\239\187\191' then pos = 4 end -- UTF-8 BOM
    local value = parse_value(0)
    skip_ws()
    if pos <= len then fail('trailing characters') end
    return value
end

--------------------------------------------------------------------------------
-- Verdict engine
--------------------------------------------------------------------------------

-- Turns an IPQS response into { block, tier, why, fraud }.
local function evaluate(data)
    local fraud = tonumber(data.fraud_score)

    -- DEFINITIVE: IPQS reports a currently active anonymiser.
    local definitive = {}
    if P.block_tor and data.active_tor == true then definitive[#definitive + 1] = 'active_tor' end
    if P.block_vpn and data.active_vpn == true then definitive[#definitive + 1] = 'active_vpn' end

    if #definitive > 0 then
        return { block = true, tier = 'definitive', why = table.concat(definitive, '+'), fraud = fraud }
    end

    -- SUSPECTED: IPQS documents vpn/tor as implying proxy=true, so a plain proxy
    -- only counts when no VPN/Tor flag is present (prevents double counting, and
    -- stops block_vpn = false from being bypassed through the implied proxy flag).
    local suspected = {}
    if P.block_tor and data.tor == true then suspected[#suspected + 1] = 'tor' end
    if P.block_vpn and data.vpn == true then suspected[#suspected + 1] = 'vpn' end
    local vpn_or_tor = data.vpn == true or data.active_vpn == true or data.tor == true or data.active_tor == true
    if P.block_proxy and data.proxy == true and not vpn_or_tor then suspected[#suspected + 1] = 'proxy' end

    if #suspected == 0 then
        return { block = false, tier = 'none', why = 'no anonymiser flags', fraud = fraud }
    end

    local sus = table.concat(suspected, '+')

    for _, key in ipairs(P.never_block) do
        if data[key] == true then
            return { block = false, tier = 'vetoed', why = sus .. ' ignored (' .. key .. ')', fraud = fraud }
        end
    end

    local support = {}
    if P.min_fraud_score and P.min_fraud_score > 0 and fraud and fraud >= P.min_fraud_score then
        support[#support + 1] = 'fraud_score=' .. fraud
    end
    if P.data_center_corroborates and normalise_ctype(data.connection_type) == 'datacenter' then
        support[#support + 1] = 'data_center'
    end
    for _, key in ipairs(P.corroborators) do
        if data[key] == true then support[#support + 1] = key end
    end

    if #support >= P.corroboration_needed then
        local why = sus
        if #support > 0 then why = why .. ' + ' .. table.concat(support, ', ') end
        return { block = true, tier = 'suspected', why = why, fraud = fraud }
    end

    return { block = false, tier = 'uncorroborated', why = sus .. ' but uncorroborated', fraud = fraud }
end

--------------------------------------------------------------------------------
-- Cache
--------------------------------------------------------------------------------

local function cache_usable()
    return C.enabled and C.file and io and io.open
end

local function cache_get(ip)
    if not C.enabled then return nil end
    local e = cache[ip]
    if not e then return nil end
    if time() - e.ts > ttl then
        cache[ip] = nil
        cache_dirty = true
        return nil
    end
    return e
end

local function cache_put(ip, entry)
    if not C.enabled then return end
    cache[ip] = entry
    cache_dirty = true
end

local function cache_load()
    if not cache_usable() then return end
    local f = io.open(C.file, 'r') or io.open(C.file .. '.tmp', 'r')
    if not f then return end
    local now_t, loaded = time(), 0
    for line in f:lines() do
        local ip, ts, blk, fraud, tier, why = line:match('^([%d%.]+)|(%d+)|([01])|(%-?%d+)|([^|]*)|(.*)$')
        ts = tonumber(ts)
        if ip and ts and now_t - ts <= ttl then
            fraud = tonumber(fraud)
            cache[ip] = {
                ts = ts,
                block = (blk == '1'),
                tier = tier,
                why = why,
                fraud = (fraud and fraud >= 0) and fraud or nil
            }
            loaded = loaded + 1
        end
    end
    f:close()
    if loaded > 0 then log(string.format('Loaded %d cached result(s).', loaded), 8) end
end

local function cache_save(force)
    if not cache_usable() then return end
    if not cache_dirty and not force then return end

    local t, list = time(), {}
    for ip, e in pairs(cache) do
        if t - e.ts > ttl then
            cache[ip] = nil
        else
            list[#list + 1] = { ip = ip, e = e }
        end
    end

    table.sort(list, function (a, b) return a.e.ts > b.e.ts end)
    for i = #list, C.max_entries + 1, -1 do
        cache[list[i].ip] = nil
        list[i] = nil
    end

    local tmp = C.file .. '.tmp'
    local f = io.open(tmp, 'w')
    if not f then
        log('Could not write cache file: ' .. tostring(C.file), 14)
        return
    end
    for _, item in ipairs(list) do
        local e = item.e
        f:write(
            string.format(
                '%s|%d|%d|%d|%s|%s\n', item.ip, e.ts, e.block and 1 or 0, e.fraud and math.floor(e.fraud) or -1,
                tostring(e.tier):gsub('[|\r\n]', '/'), (tostring(e.why):gsub('[|\r\n]', '/'))
            )
        )
    end
    f:close()

    if os.remove and os.rename then
        os.remove(C.file)
        os.rename(tmp, C.file)
    end
    cache_dirty = false
end

--------------------------------------------------------------------------------
-- Enforcement
--------------------------------------------------------------------------------

local function take_action(rec, entry)
    local id = rec.id

    say(id, config.player_feedback)

    local state
    if config.action == 'b' then
        execute_command('ipban ' .. id .. ' ' .. config.ban_time .. ' "' .. config.reason .. '"')
        state = 'IP-banned for ' .. config.ban_time .. ' min'
    else
        execute_command('k ' .. id .. ' "' .. config.reason .. '"')
        state = 'kicked'
    end

    local ok, msg = pcall(string.format, config.console_feedback, rec.name, state, rec.ip, entry.why)
    if not ok then msg = string.format('%s was %s (IP: %s | %s)', rec.name, state, rec.ip, entry.why) end
    log(msg, 12)
end

-- Only act on a player who is fully joined, still in the same slot, and still on the
-- same IP the verdict was issued for.
local function enforce(rec)
    local entry = rec.verdict
    if not entry or not entry.block or rec.enforced then return end
    if players[rec.id] ~= rec or not player_present(rec.id) then return end

    local _, current = parse_ipv4(get_var(rec.id, '$ip'))
    if current ~= rec.ip then return end

    rec.enforced = true
    take_action(rec, entry)
end

local function apply_verdict(rec, entry)
    if players[rec.id] ~= rec then return end -- player left, or slot was reused
    rec.verdict = entry
    if rec.joined then enforce(rec) end
end

--------------------------------------------------------------------------------
-- Request building
--------------------------------------------------------------------------------

local function build_request(ip)
    local qs = {}
    for _, key in ipairs(PARAM_ORDER) do
        local v = config.parameters[key]
        if v ~= nil then qs[#qs + 1] = key .. '=' .. urlencode(tostring(v)) end
    end

    local use_header = (R.method == 'POST') or R.key_in_header

    local hdrs = ffi.new('sapp_http_header[2]')
    hdrs[0].name = 'Accept'
    hdrs[0].value = 'application/json'
    local n = 1
    if use_header then
        hdrs[1].name = 'IPQS-KEY'
        hdrs[1].value = config.api_key
        n = 2
    end

    if R.method == 'POST' then
        qs[#qs + 1] = 'ip=' .. urlencode(ip)
        local body = table.concat(qs, '&')
        return http.sapp_http_create_post(R.api_url, 'application/x-www-form-urlencoded', body, #body, hdrs, n)
    end

    local base = (R.api_url:gsub('/+$', ''))
    local url
    if use_header then
        qs[#qs + 1] = 'ip=' .. urlencode(ip)
        url = base .. '?' .. table.concat(qs, '&')
    else
        url = base .. '/' .. urlencode(config.api_key) .. '/' .. urlencode(ip) .. '?' .. table.concat(qs, '&')
    end
    return http.sapp_http_create_get(url, hdrs, n)
end

--------------------------------------------------------------------------------
-- Job lifecycle
--------------------------------------------------------------------------------

local function settle(job, entry)
    inflight[job.key] = nil
    for _, rec in ipairs(job.waiters) do
        apply_verdict(rec, entry)
    end
end

-- Fail-open: nobody is removed because of a failed lookup.
local function abandon(job, why)
    inflight[job.key] = nil
    if job.debug then
        log(
            '[DEBUG] Test lookup for ' .. job.ip .. ' FAILED after ' .. job.attempt .. ' attempt(s): ' .. tostring(why),
            12
        )
        return
    end
    if job.report_to and player_present(job.report_to) then
        say(job.report_to, 'Lookup failed: ' .. job.ip)
    end
    log('Lookup failed for ' .. job.ip .. ' (' .. tostring(why) .. ') - player allowed.', 14)
end

local function retry_or_abandon(job, why)
    if job.attempt <= N.retries then
        local delay = math.min(N.max_backoff, N.backoff * (2 ^ (job.attempt - 1))) + math.random() * 0.5
        job.not_before = clock() + delay
        queue[#queue + 1] = job
        vlog(
            string.format(
                'Lookup for %s failed (%s); retry %d/%d in %.1fs', job.ip, tostring(why), job.attempt, N.retries, delay
            ), 14
        )
    else
        abandon(job, why)
    end
end

local function go_fatal(why)
    paused_until = clock() + N.fatal_pause
    paused_noted = true
    log('API error: ' .. tostring(why), 12)
    log(
        string.format(
            'Lookups paused for %d seconds. Players are NOT being checked. Fix your API key/credits.', N.fatal_pause
        ), 12
    )
    for i = 1, #queue do
        inflight[queue[i].key] = nil
    end
    queue = {}
end

-- Returns: data, errmsg, retryable, fatal
local function classify(rc, curl_code, curl_err, status, body)
    if rc ~= 0 then return nil, 'could not read response (code ' .. tostring(rc) .. ')', true, false end
    if curl_code ~= 0 then return nil, curl_err or ('curl error ' .. curl_code), true, false end

    local data
    if body ~= '' then
        local ok, decoded = pcall(json_decode, body)
        if ok and type(decoded) == 'table' then data = decoded end
    end

    if data and data.success == false then
        local msg = tostring(data.message or 'unknown API error')
        local fatal = has_marker(msg, FATAL_MARKERS)
        local retryable = (not fatal) and has_marker(msg, RETRY_MARKERS)
        return nil, msg, retryable, fatal
    end

    if status == 401 or status == 403 then return nil, 'HTTP ' .. status, false, true end
    if status == 408 or status == 425 or status == 429 or status >= 500 then
        return nil, 'HTTP ' .. status, true, false
    end
    if status < 200 or status >= 300 then return nil, 'HTTP ' .. status, false, false end
    if not data then return nil, 'invalid JSON in response', true, false end

    return data
end

local function summary_line(ip, data, entry)
    return string.format(
        '%s fraud=%s vpn=%s active_vpn=%s tor=%s active_tor=%s proxy=%s conn=%s -> %s (%s)', ip,
        tostring(data.fraud_score), yn(data.vpn), yn(data.active_vpn), yn(data.tor), yn(data.active_tor), yn(data.proxy),
        tostring(data.connection_type or '?'), entry.block and 'BLOCK' or 'allow', entry.why
    )
end

local function log_lookup(ip, data, entry)
    vlog(summary_line(ip, data, entry), entry.block and 12 or 8)
end

-- Compact, sorted rendering of a decoded JSON value for the debug dump.
local function dump_value(v, depth)
    local t = type(v)
    if t == 'string' then return '"' .. v .. '"' end
    if t ~= 'table' then return tostring(v) end
    if depth > 2 then return '{...}' end
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function (a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        local item = dump_value(v[k], depth + 1)
        parts[#parts + 1] = (type(k) == 'number') and item or (tostring(k) .. '=' .. item)
    end
    return '{' .. table.concat(parts, ', ') .. '}'
end

local function report_debug(job, data, entry)
    local function d(msg, color)
        log('[DEBUG] ' .. msg, color or 11)
    end

    local num = parse_ipv4(job.ip)
    local scope = 'yes'
    if in_nets(num, EXCLUDED) then
        scope = 'NO - matched exclusion_list'
    elseif in_nets(num, NON_PUBLIC) then
        scope = config.skip_non_public and 'NO - private/reserved range (skip_non_public)'
            or 'yes (skip_non_public is off)'
    end

    local action = (config.action == 'b') and ('ipban for ' .. config.ban_time .. ' min') or 'kick'

    d('===== Test lookup: ' .. job.ip .. ' =====')
    d('Real players on this IP would be checked: ' .. scope)
    d(
        string.format(
            'Request: %s, %d attempt(s), %.0f ms total', R.method, job.attempt, (clock() - (job.t0 or clock())) * 1000
        )
    )
    d(summary_line(job.ip, data, entry))
    d(
        string.format('Decision: %s [%s] %s', entry.block and 'BLOCK' or 'ALLOW', entry.tier, entry.why),
        entry.block and 12 or 10
    )
    d('Action a real player would receive: ' .. (entry.block and action or 'none'))

    if D.dump_response then
        local keys = {}
        for k in pairs(data) do
            keys[#keys + 1] = k
        end
        table.sort(keys)
        d('Response fields:', 8)
        for _, k in ipairs(keys) do
            local line = '  ' .. k .. ' = ' .. dump_value(data[k], 0)
            if #line > 300 then line = line:sub(1, 297) .. '...' end
            d(line, 8)
        end
    end
    d('===== End test lookup =====')
end

local function report_admin(job, data, entry)
    local id = job.report_to
    if not id or not player_present(id) then return end

    local tag = job.report_name and (tostring(job.report_name):sub(1, 12) .. ' ') or ''
    say(
        id,
        string.format(
            '%s%s [%s] f=%s vpn=%s tor=%s proxy=%s', tag, job.ip, entry.block and 'BLOCK' or 'OK',
            tostring(data.fraud_score or '?'), yn(data.vpn), yn(data.tor), yn(data.proxy)
        )
    )
end

-- Queues a fresh lookup that never touches the cache and never affects a player.
local function queue_debug_lookup(ip)
    local key = 'debug:' .. ip
    if inflight[key] then return end
    local job = { ip = ip, key = key, debug = true, waiters = {}, attempt = 0, not_before = 0 }
    inflight[key] = job
    queue[#queue + 1] = job
end

local function finish(job)
    local req = job.req
    job.req = nil
    active = active - 1

    local resp = ffi.new('sapp_http_response')
    local rc = http.sapp_http_request_get_response(req, resp)

    local status, curl_code, curl_err, body = 0, 0, nil, ''
    if rc == 0 then
        status = tonumber(resp.http_status)
        curl_code = tonumber(resp.curl_code)
        local size = tonumber(resp.body_size)
        if resp.body ~= nil and size > 0 then body = ffi.string(resp.body, size) end
        if resp.error_message ~= nil then curl_err = ffi.string(resp.error_message) end
    end

    http.sapp_http_free_response(resp)
    http.sapp_http_request_free(req)

    local data, err, retryable, fatal = classify(rc, curl_code, curl_err, status, body)

    if data then
        local entry = evaluate(data)
        if job.debug then
            inflight[job.key] = nil
            report_debug(job, data, entry)
        else
            entry.ts = time()
            cache_put(job.ip, entry)
            log_lookup(job.ip, data, entry)
            settle(job, entry)
            if job.report_to then report_admin(job, data, entry) end
        end
    elseif fatal then
        inflight[job.key] = nil
        go_fatal(err)
    elseif retryable then
        retry_or_abandon(job, err)
    else
        abandon(job, err)
    end
end

local function start_jobs(t)
    if t < paused_until then return end
    local interval = (N.max_rps and N.max_rps > 0) and (1 / N.max_rps) or 0
    local i = 1
    while i <= #queue do
        local job = queue[i]
        if job.not_before <= t and t >= next_slot then
            table.remove(queue, i)
            next_slot = math.max(t, next_slot) + interval
            job.attempt = job.attempt + 1
            job.t0 = job.t0 or t
            local req = build_request(job.ip)
            if req == nil then
                retry_or_abandon(job, 'could not create request')
            else
                job.req = req
                active = active + 1
            end
        else
            i = i + 1
        end
    end
end

local function poll()
    if not http_ready then return end
    local t = clock()

    if paused_noted and t >= paused_until then
        paused_noted = false
        log('Lookups resumed.', 10)
    end

    start_jobs(t)

    if active > 0 then
        local rc = http.sapp_http_process()
        if rc < 0 and t - last_proc_err > 5 then
            last_proc_err = t
            log('sapp_http_process returned error ' .. rc, 12)
        end

        local done = {}
        for _, job in pairs(inflight) do
            if job.req ~= nil and http.sapp_http_request_is_done(job.req) == 1 then
                done[#done + 1] = job
            end
        end
        for _, job in ipairs(done) do
            local ok, err = pcall(finish, job)
            if not ok then
                -- Never leave a job stuck in `inflight`: later joins from this IP would wait on it forever.
                inflight[job.key] = nil
                log('Internal error while processing ' .. job.ip .. ': ' .. tostring(err) .. ' - player allowed.', 12)
            end
        end
    end

    if cache_dirty and time() - last_save >= C.save_interval then
        cache_save()
        last_save = time()
    end
end

function VPNBlockerPoll()
    if not http_ready then return false end
    local ok, err = pcall(poll)
    if not ok then log('Internal error: ' .. tostring(err), 12) end
    return true
end

--------------------------------------------------------------------------------
-- Player tracking
--------------------------------------------------------------------------------

local function submit(rec)
    local ip = rec.ip

    local hit = cache_get(ip)
    if hit then
        vlog(string.format('%s cache hit -> %s (%s)', ip, hit.block and 'BLOCK' or 'allow', hit.why))
        apply_verdict(rec, hit)
        return
    end

    local job = inflight[ip]
    if job then
        job.waiters[#job.waiters + 1] = rec
        return
    end

    if not http_ready or clock() < paused_until then return end
    if #queue + active >= N.max_pending then
        log('Lookup queue full; ' .. ip .. ' was not checked.', 14)
        return
    end

    job = { ip = ip, key = ip, waiters = { rec }, attempt = 0, not_before = 0 }
    inflight[ip] = job
    queue[#queue + 1] = job
end

local function track(id, joined)
    local num, ip = parse_ipv4(get_var(id, '$ip'))
    if not num then return end
    if in_nets(num, EXCLUDED) then return end
    if config.skip_non_public and in_nets(num, NON_PUBLIC) then return end

    local rec = { id = id, ip = ip, name = get_var(id, '$name') or '?', joined = joined }
    players[id] = rec
    submit(rec)
end

function OnPreJoin(id)
    track(tonumber(id), false)
end

function OnJoin(id)
    id = tonumber(id)
    local rec = players[id]
    if rec then
        rec.joined = true
        rec.name = get_var(id, '$name') or rec.name
        enforce(rec)
    else
        track(id, true) -- script loaded mid-join, or PreJoin was missed for some stupid reason
    end
end

function OnLeave(id)
    id = tonumber(id)
    players[id] = nil
    cmd_cooldown[id] = nil
end

--------------------------------------------------------------------------------
-- Admin command: /<config.command.name> <ip|player#>
--------------------------------------------------------------------------------

local function is_admin(id)
    local lvl = tonumber(get_var(id, '$lvl'))
    return id == 0 or lvl >= config.command.level
end

-- Manual lookup for an admin. Reuses an in-flight player lookup for the same IP
-- (no extra credit); otherwise queues a fresh one that bypasses the cache.
local function queue_admin_lookup(admin_id, ip, name)
    local job = inflight[ip]
    if job and not job.debug then
        job.report_to = admin_id
        job.report_name = name
        return
    end

    if not http_ready or clock() < paused_until then
        say(admin_id, 'Lookups are paused.')
        return
    end
    if #queue + active >= N.max_pending then
        say(admin_id, 'Lookup queue full.')
        return
    end

    job = { ip = ip, key = ip, waiters = {}, attempt = 0, not_before = 0, report_to = admin_id, report_name = name }
    inflight[ip] = job
    queue[#queue + 1] = job
end

local function respond(id)
    if id == 0 then return cprint end
    return function (msg)
        rprint(id, msg)
    end
end

function OnCommand(id, command, environment, password)
    id = tonumber(id)
    if not id then return end

    local raw = tostring(command or ''):gsub('^/+', '')
    local cmd, rest = raw:match('^(%S+)%s*(.*)$')
    cmd = (cmd or ''):lower()

    if cmd ~= config.command.name then return end
    local args = rest or ''

    local now = clock()

    if id ~= 0 then
        if not is_admin(id) then
            say(id, 'Admins only.')
            return false
        end

        local last = cmd_cooldown[id]
        if last and (now - last) < config.command.cooldown then
            say(id, string.format('Cooldown: %ds', math.ceil(config.command.cooldown - (now - last))))
            return false
        end
    end

    local tell = respond(id)
    local arg = args:match('^%s*(%S+)')
    if not arg then
        tell('Usage: /' .. config.command.name .. ' <ip|player#>')
        return false
    end

    local target_ip, target_name
    local pnum = tonumber(arg)

    if pnum and pnum > 0 and player_present(pnum) then
        target_ip = select(2, parse_ipv4(get_var(pnum, '$ip')))
        target_name = get_var(pnum, '$name')
    else
        target_ip = select(2, parse_ipv4(arg))
    end

    if pnum and (pnum <= 0 or not player_present(pnum)) then
        tell('Player #' .. pnum .. ' not online')
        return false
    end

    if not target_ip then
        tell('Invalid IP or player.')
        return false
    end

    cmd_cooldown[id] = now
    tell('Checking ' .. target_ip .. '...')
    queue_admin_lookup(id, target_ip, target_name)
    return false
end

--------------------------------------------------------------------------------
-- Startup / shutdown
--------------------------------------------------------------------------------

local function validate_config()
    config.action = (config.action == 'b') and 'b' or 'k'

    config.ban_time = math.floor(tonumber(config.ban_time) or 10)
    if config.ban_time < 1 then config.ban_time = 10 end

    config.reason = (tostring(config.reason):gsub('["\r\n]', "'"))

    config.command = config.command or {}
    config.command.name = tostring(config.command.name or 'ipqs'):gsub('^/+', ''):lower()
    if config.command.name == '' then config.command.name = 'ipqs' end
    config.command.cooldown = math.max(0, tonumber(config.command.cooldown) or 10)

    R.method = tostring(R.method):upper()
    if R.method ~= 'GET' then R.method = 'POST' end

    N.max_rps = tonumber(N.max_rps) or 5
    N.retries = math.max(0, math.floor(tonumber(N.retries) or 3))
    N.backoff = math.max(0, tonumber(N.backoff) or 1)
    N.max_backoff = math.max(N.backoff, tonumber(N.max_backoff) or 15)
    N.max_pending = math.max(1, math.floor(tonumber(N.max_pending) or 64))
    N.fatal_pause = math.max(1, tonumber(N.fatal_pause) or 600)
    N.poll_interval_ms = math.max(20, math.floor(tonumber(N.poll_interval_ms) or 100))

    C.ttl_hours = tonumber(C.ttl_hours) or 6
    C.max_entries = math.max(1, math.floor(tonumber(C.max_entries) or 5000))
    C.save_interval = math.max(10, tonumber(C.save_interval) or 300)
    ttl = C.ttl_hours * 3600

    P.corroboration_needed = math.max(0, math.floor(tonumber(P.corroboration_needed) or 1))
    P.corroborators = P.corroborators or {}
    P.never_block = P.never_block or {}

    if (tonumber(config.parameters.strictness) or 0) >= 2 then
        log("Warning: strictness 2+ is 'VERY strict' per IPQS and can flag legitimate players.", 14)
    end
    if P.corroboration_needed == 0 then
        log('Warning: corroboration_needed = 0 - any suspected flag will remove a player.', 14)
    end
end

function OnScriptLoad()
    config.api_key = (tostring(config.api_key):gsub('^%s+', ''):gsub('%s+$', ''))
    if PLACEHOLDER_KEYS[config.api_key:upper()] then
        log('No API key configured. Set config.api_key - the script is inactive.', 12)
        return
    end

    validate_config()

    -- HTTP DLL
    pcall(ffi.cdef, CDEF)
    local loaded, dll = pcall(ffi.load, 'sapp_http')
    if not loaded then
        log('Could not load sapp_http.dll (place it next to sapp.dll). Script is inactive.', 12)
        return
    end
    http = dll

    local rc = http.sapp_http_global_init()
    if rc ~= 0 then
        log('sapp_http_global_init failed with code ' .. tostring(rc) .. '. Script is inactive.', 12)
        return
    end
    http_ready = true

    -- Exclusions and reserved ranges
    for _, entry in ipairs(config.exclusion_list) do
        local net = parse_cidr(entry)
        if net then
            EXCLUDED[#EXCLUDED + 1] = net
        else
            log('Ignoring bad exclusion_list entry: ' .. tostring(entry), 14)
        end
    end
    for _, c in ipairs({
        '0.0.0.0/8',
        '10.0.0.0/8',
        '100.64.0.0/10',
        '127.0.0.0/8',
        '169.254.0.0/16',
        '172.16.0.0/12',
        '192.0.0.0/24',
        '192.0.2.0/24',
        '192.168.0.0/16',
        '198.18.0.0/15',
        '198.51.100.0/24',
        '203.0.113.0/24',
        '224.0.0.0/3'
    }) do
        NON_PUBLIC[#NON_PUBLIC + 1] = parse_cidr(c)
    end

    cache_load()
    last_save = time()

    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnLeave')
    register_callback(cb['EVENT_PREJOIN'], 'OnPreJoin')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    timer(N.poll_interval_ms, 'VPNBlockerPoll')

    -- Debug: test lookups (see config.debug)
    if D.enabled then
        log('DEBUG MODE ON - running test lookups. Disable config.debug.enabled for production.', 14)
        for _, test_ip in ipairs(D.test_ips or {}) do
            local _, canonical = parse_ipv4(tostring(test_ip))
            if canonical then
                queue_debug_lookup(canonical)
            else
                log('[DEBUG] Ignoring invalid test IP: ' .. tostring(test_ip), 14)
            end
        end
    end

    -- Screen anyone already connected (script loaded mid-game).
    for i = 1, 16 do
        if player_present(i) then track(i, true) end
    end

    log('Active. libcurl ' .. ffi.string(http.sapp_http_version()), 10)
end

function OnScriptUnload()
    if http_ready then
        for _, job in pairs(inflight) do
            if job.req ~= nil then
                http.sapp_http_request_free(job.req)
                job.req = nil
            end
        end
        cache_save(true)
        http.sapp_http_global_cleanup()
        http_ready = false
    end
    players, inflight, queue, active = {}, {}, {}, 0
    cmd_cooldown = {}
end