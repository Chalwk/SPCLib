--[[
=====================================================================================
SCRIPT NAME:      random_fact_generator.lua
DESCRIPTION:      Periodically announces random Chuck Norris facts from an external API.
                  Optionally replaces "Chuck Norris" with a random player's name.

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json
                  - SAPP HTTP Client: https://opencarnage.net/index.php?/topic/5998-sapp-http-client/)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- API version required by SAPP
api_version = "1.12.0.0"

-- Configuration
local config = {
    interval = 120, -- How often (in seconds) to announce a random message. Do not set lower than 3 seconds.
    end_point = "https://api.chucknorris.io/jokes/random", -- URL to Chuck Norris Joke API
    replace_name = true, -- If true, Chuck Norris's name will be replaced with a random player's name
    server_prefix = "**SAPP**" -- Server prefix for messages
}

-- Dependencies
local json = (loadfile "json.lua")()
local ffi = require("ffi")

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
local client = ffi.load("lua_http_client")

-- State variables
local async_data
local game_started
local players = {}

-- Function to handle script load event
function OnScriptLoad()
    register_callback(cb["EVENT_JOIN"], "OnPlayerJoin")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerLeave")
    register_callback(cb["EVENT_GAME_END"], "OnGameEnd")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    OnGameStart()
end

-- Function to handle script unload event
function OnScriptUnload()
    -- No cleanup required
end

-- Function to handle player join event
function OnPlayerJoin(player_id)
    players[player_id] = get_var(player_id, "$name")
end

-- Function to handle player leave event
function OnPlayerLeave(player_id)
    players[player_id] = nil
end

-- Function to handle game start event
function OnGameStart()
    game_started = false
    if get_var(0, "$gt") ~= "n/a" then
        game_started = true
        config.interval = math.max(config.interval, 3)
        timer(1000 * config.interval, "FetchAndAnnounceJoke")
    end
end

-- Function to handle game end event
function OnGameEnd()
    game_started = false
end

-- Function to fetch and announce a joke
function FetchAndAnnounceJoke()
    async_data = client.http_get(config.end_point, true)
    timer(1, "ProcessJokeResponse")
    return game_started
end

-- Function to process the joke response
function ProcessJokeResponse()
    if client.http_response_received(async_data) then
        if not client.http_response_is_null(async_data) then
            local response = ffi.string(client.http_read_response(async_data))
            local joke_data = json:decode(response)
            local joke = joke_data.value

            if config.replace_name and #players > 0 then
                local random_player = players[math.random(1, #players)]
                joke = joke:gsub("Chuck Norris", random_player)
            end

            execute_command('msg_prefix ""')
            say_all(joke)
            execute_command('msg_prefix "' .. config.server_prefix .. '"')
            cprint(joke)
        end
        client.http_destroy_response(async_data)
        async_data = nil
        return false
    end
    return true
end