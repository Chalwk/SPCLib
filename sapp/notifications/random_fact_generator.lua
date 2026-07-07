--[[
=====================================================================================
SCRIPT NAME:      random_fact_generator.lua
DESCRIPTION:      Periodically announces random Chuck Norris facts

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - SAPP-HTTP Client: https://github.com/Chalwk/SAPP-HTTP

Copyright (c) 2022-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START --
local INTERVAL = 120 -- seconds between facts
local JOKE_API_URL = "https://api.chucknorris.io/jokes/random"
-- CONFIG ENDS --

local ffi = require("ffi")
local sapp_http = ffi.load("sapp_http")

ffi.cdef [[
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
    int sapp_http_process(void);
    int sapp_http_request_is_done(sapp_http_request *req);
    int sapp_http_request_get_response(sapp_http_request *req,
                                       sapp_http_response *out);
    void sapp_http_request_free(sapp_http_request *req);
    void sapp_http_free_response(sapp_http_response *response);
]]

local game_running = false
local request_handle = nil -- current async request, or nil
local http_initialized = false

local function unescape_json_string(s)
    local result = s:gsub("\\\"", "\"")
        :gsub("\\\\", "\\")
        :gsub("\\/", "/")
        :gsub("\\b", "\b")
        :gsub("\\f", "\f")
        :gsub("\\n", "\n")
        :gsub("\\r", "\r")
        :gsub("\\t", "\t")
    return result
end

local function extract_joke_value(json_string)
    -- Look for "value":" (including the colon and opening quote)
    local start_pos = string.find(json_string, '"value":"', 1, true)
    if not start_pos then return nil, "missing 'value' key" end

    local i = start_pos + 8 -- position after the opening quote
    local len = #json_string
    local result_chars = {}

    while i <= len do
        local c = json_string:sub(i, i)
        if c == '\\' then
            -- Escape sequence: skip backslash, then take the next char literally
            result_chars[#result_chars + 1] = json_string:sub(i + 1, i + 1)
            i = i + 2
        elseif c == '"' then
            -- Found the closing quote
            i = i + 1
            break
        else
            result_chars[#result_chars + 1] = c
            i = i + 1
        end
    end

    if i == len + 1 and json_string:sub(-1) ~= '"' then return nil, "unterminated string" end

    local raw = table.concat(result_chars)
    return unescape_json_string(raw)
end

function ProcessHTTP()
    -- Process any pending network I/O
    sapp_http.sapp_http_process()

    -- If no request in flight, just keep the timer alive
    if not request_handle then return true end

    -- Check if the request is finished
    local done = sapp_http.sapp_http_request_is_done(request_handle)
    if done == 1 then
        -- Retrieve the response
        local response = ffi.new("sapp_http_response")
        local status = sapp_http.sapp_http_request_get_response(request_handle, response)

        if status == 0 then
            ---@diagnostic disable-next-line: undefined-field
            local body_str = ffi.string(response.body, response.body_size)

            -- Extract the joke value
            local joke, err = extract_joke_value(body_str)
            if joke then
                -- Only announce if a game is still running
                if game_running then
                    say_all("Chuck Norris Fact: " .. joke)
                end
            else
                print("[random_fact] Failed to parse joke: " .. (err or "unknown error"))
            end

            -- Free the response memory (the body pointer is owned by the response)
            sapp_http.sapp_http_free_response(response)
        else
            -- get_response failed (e.g., request not done or invalid)
            print("[random_fact] Error retrieving response: " .. tostring(status))
        end

        -- Clean up the request object
        sapp_http.sapp_http_request_free(request_handle)
        request_handle = nil
    end

    return true
end

function FetchJoke()
    if not game_running then return false end
    ---@diagnostic disable-next-line: unnecessary-if
    if request_handle then return true end

    local req = sapp_http.sapp_http_create_get(JOKE_API_URL, nil, 0)
    if req == nil then
        print("[random_fact] Failed to create HTTP request")
        return true
    end

    request_handle = req
    return true
end

function OnScriptLoad()
    if not http_initialized then
        local rc = sapp_http.sapp_http_global_init()
        if rc ~= 0 then
            print("[random_fact] HTTP global init failed with code " .. tostring(rc))
            return
        end
        http_initialized = true
    end

    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")

    timer(100, "ProcessHTTP")
    OnGameStart() -- in case the script is loaded mid-game
end

function OnGameStart()
    game_running = false
    if get_var(0, "$gt") ~= "n/a" then
        game_running = true
        timer(1000 * INTERVAL, "FetchJoke")
    end
end

function OnGameEnd()
    game_running = false
end

function OnScriptUnload()
    ---@diagnostic disable-next-line: unnecessary-if
    if request_handle then
        sapp_http.sapp_http_request_free(request_handle)
        request_handle = nil
    end

    if http_initialized then
        sapp_http.sapp_http_global_cleanup()
        http_initialized = false
    end
end
