--[[
=====================================================================================
SCRIPT NAME:      team_defender.lua
DESCRIPTION:      Objective-based team mode featuring:
                  - Dynamic flag control gameplay
                  - Team role specialization (carrier/defenders/attackers)
                  - Strategic point scoring system

GAMEPLAY MECHANICS:
                  - Random flag spawns create dynamic battles
                  - Holding flag doubles team point earnings
                  - Assist points for protecting your carrier
                  - Special bonuses for eliminating enemy carriers

CONFIGURATION:
                  - Adjustable flag respawn timers
                  - Customizable scoring values
                  - Multiple flag spawn locations per map
                  - Toggleable friendly fire protection
                  - Nav marker options for flag carriers

Copyright (c) 2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts --
local TD = {

    -- Time (in seconds) until a dropped flag will respawn:
    -- Default: 15 seconds
    respawn_delay = 15,

    -- When enabled, friendly fire will be blocked:
    --
    block_friendly_fire = true,

    -- Message broadcast when someone picks up the flag:
    -- $team will be replaced with the players team name (red/blue).
    -- $name will be replaced with the players name.
    -- Leave blank ("") to disable.
    --
    on_pickup = "[$team team] $name has the flag.",

    -- Message sent when a flag was dropped (appears at respawn_delay/2 seconds)
    -- $S will be replaced with the time remaining.
    -- $s will be replaced with a lowercase "s" if $S>1.
    -- Leave blank ("") to disable.
    --
    respawn_warning = "The flag was dropped and will respawn in $S second$s.",

    -- Message broadcast when the flag respawns:
    -- Leave blank ("") to disable.
    --
    message_on_respawn = "The flag has respawned.",

    -- Nav Marker (on by default):
    -- When enabled, the flag carrier will have a nav marker above his head.
    -- Requires the kill in order game type flag to be set to YES.
    -- Requires the objectives indicator to be st to NAV POINTS.
    -- Default: false
    --
    nav_marker = false,

    -- Scoring and custom messages:
    -- Leave messages blank ("") to disable.
    scoring = {

        -- The player holding the flag will get this many assist points
        -- for every kill that a teammate gets:
        -- Default: 20
        --
        { 20, "+20 Team Assist" },

        -- Team without flag (points per kill)
        -- Default: 50
        --
        { 50, "+50 Kill Bonus" },

        -- Team with flag (points per kill)
        -- Default: 100
        --
        { 100, "+100 Defence" },

        -- Flag carrier kill points:
        -- Default: 250
        --
        { 250, "+250 Flag Carrier kill" },

        -- Score limit:
        -- Default: 7500
        --
        7500
    },

    -- Map flag spawn coordinates:
    -- To get location coordinates, use SAPP's /coord command:
    -- Syntax: coord <player id>
    -- Alternatively, use a tools like Spark Edit, HMT, Lethargy or HEK.
    --
    ["bloodgulch"] = { 65.749, -120.409, 0.118 },
    ["deathisland"] = { -30.282, 31.312, 16.601 },
    ["icefields"] = { -26.032, 32.365, 9.007 },
    ["infinity"] = { 9.631, -64.030, 7.776 },
    ["sidewinder"] = { 2.051, 55.220, -2.801 },
    ["timberland"] = { 1.250, -1.487, -21.264 },
    ["dangercanyon"] = { -0.477, 55.331, 0.239 },
    ["beavercreek"] = { 14.015, 14.238, -0.911 },
    ["boardingaction"] = { 4.374, -12.832, 7.220 },
    ["carousel"] = { 0.033, 0.003, -0.856 },
    ["chillout"] = { 1.392, 4.700, 3.108 },
    ["damnation"] = { -2.002, -4.301, 3.399 },
    ["gephyrophobia"] = { 63.513, -74.088, -1.062 },
    ["hangemhigh"] = { 21.020, -4.632, -4.229 },
    ["longest"] = { -0.84, -14.54, 2.41 },
    ["prisoner"] = { 0.902, 0.088, 1.392 },
    ["putput"] = { -2.350, -21.121, 0.902 },
    ["ratrace"] = { 8.662, -11.159, 0.221 },
    ["wizard"] = { -5.035, -5.064, -2.750 },

    -- Repeat the structure to add custom maps:
    --
    ["map_name"] = { x, y, z },
    --

    -- A message relay function temporarily removes the server message prefix
    -- and will restore it to this when the relay is finished:
    server_prefix = "**SAPP**",

    -- Script errors (if any) will be logged to this file:
    --
    error_file = "Team Defender (errors).log",

    -- DO NOT TOUCH BELOW THIS POINT --
    script_version = 1.5
    --
}
-- config ends --

api_version = "1.12.0.0"

-- This function is called when the script is loaded into SAPP:
--
function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

-- This function is called when a new game has started:
--
function OnStart()
    TD:Init()
end

-- This function is called when a new game has started:
--
function OnEnd()
    TD.game_started = false
end

-- This function broadcasts a custom server message:
-- Temporarily removes the server message prefix and restores it.
-- @param playerId (player index) [number]
-- @param Msg (message) [string]
--
function TD:Broadcast(playerId, Msg)
    if (Msg ~= "") then
        execute_command("msg_prefix \"\"")
        if (playerId) then
            say(playerId, Msg)
        else
            say_all(Msg)
        end
        execute_command("msg_prefix \" " .. self.server_prefix .. "\"")
    end
end

local function GetScore(playerId, Type)
    return tonumber(get_var(playerId, "$" .. Type))
end

-- Updates player scores:
-- @param playerId (killer index) [number]
-- @param Team (killer team) [string]
-- @param Amount (points to add) [number]
-- @param FlagCarrier (flag carrier index) [number]
--
function TD:UpdateScores(playerId, Team, Amount, FlagCarrier)

    -- Update team score:
    local score
    if (Team == "red") then
        Team = 0
        score = get_var(0, "$redscore")
    else
        Team = 1
        score = get_var(0, "$bluescore")
    end
    score = (score - 1) + Amount
    execute_command("team_score " .. Team .. " " .. score)

    -- Update player score to reflect @param Amount:
    score = GetScore(playerId, "score")
    score = (score - 1) + Amount
    execute_command("score " .. playerId .. " " .. score)

    -- Update flag carrier assist points:
    if (FlagCarrier and FlagCarrier ~= playerId) then

        score = GetScore(FlagCarrier, "assists")
        score = score + self.scoring[1][1]

        execute_command("assists " .. FlagCarrier .. " " .. score)
        self:Broadcast(FlagCarrier, self.scoring[1][2])
    end
end

-- This function is called during event_die and event_damage_application:
-- Updates player scores.
-- @param Victim (Victim) [number]
-- @param Killer (Killer) [number]
-- @param MetaID (damage tag id) [number]
--
function TD:OnDeath(Victim, Killer, MetaID, _, _, _)

    local victim = tonumber(Victim)
    local killer = tonumber(Killer)

    if (killer > 0) then

        local k_team = get_var(killer, "$team")
        local v_team = get_var(victim, "$team")

        local suicide = (killer == victim)
        local friendly_fire = (k_team == v_team and not suicide)

        -- event_damage_application --
        if (MetaID) then
            return (self.block_friendly_fire and friendly_fire and false) or true
        end

        -- event_die --
        if (not suicide and not friendly_fire) then

            -- flag carrier kill:
            if self:HasFlag(victim) then
                self:Broadcast(killer, self.scoring[4][2])
                self:UpdateScores(killer, k_team, self.scoring[4][1])
                return
            end

            -- Team with flag:
            local flag_carrier_team, flag_carrier = self:GetFlagCarrier()
            if (flag_carrier_team == k_team) then
                self:Broadcast(killer, self.scoring[3][2])
                self:UpdateScores(killer, k_team, self.scoring[3][1], flag_carrier)
            else
                -- Team without flag:
                self:Broadcast(killer, self.scoring[2][2])
                self:UpdateScores(killer, k_team, self.scoring[2][1])
            end
        end
    end
end

-- Teleports the flag back to its starting location:
--
function TD:SpawnFlag()
    self:DestroyFlag()
    self.flag.timer = 0
    self.flag.object = spawn_object("", "", self.x, self.y, self.z, 0, self.flag.id)
    self:Broadcast(nil, self.message_on_respawn)
end

-- Checks if a player is holding the flag:
-- @return true if holding flag, false if not [bool]
--
function TD:GetFlagCarrier()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) and self:HasFlag(i) then
            return get_var(i, "$team"), i
        end
    end
    self.announce_pickup = true
    return false
end

-- Distance function using pythagoras theorem:
--
local sqrt = math.sqrt
local function AtSpawn(x, y, z, self)
    local r = 0.5
    local sx, sy, sz = self.x, self.y, self.z
    if sqrt((x - sx) ^ 2 + (y - sy) ^ 2 + (z - sz) ^ 2) <= r then
        return true
    end
    return false
end

-- Returns the flag object coordinates:
-- @return (three 32-bit floating point numbers [float]
--
function TD:GetFlagPos()
    local flag = self.flag.object
    if (flag) then
        local object = get_object_memory(flag)
        if (object ~= 0) then
            return read_vector3d(object + 0x5C)
        end
    end
    return nil
end

local function Plural(n)
    return (n > 1 and "s") or ""
end

-- This function is called once every 1/30th second (1 tick):
-- Used to respawn the flag:
--
local format = string.format
function TD:GameTick()

    if (self.game_started) then

        -- logic responsible for respawning the flag:
        local _, flag_carrier = self:GetFlagCarrier()
        if (not flag_carrier) then

            local fx, fy, fz = self:GetFlagPos()
            if (fx and not AtSpawn(fx, fy, fz - self.z_off, self)) then

                self.flag.timer = self.flag.timer + 1 / 30
                local time = self.respawn_delay - self.flag.timer % 60
                time = tonumber(format("%.2" .. "f", time))

                if (time == self.respawn_delay / 2) then
                    local msg = self.respawn_warning
                    msg = msg:gsub("$S", time):gsub("$s", Plural(time))
                    self:Broadcast(nil, msg)

                elseif (self.flag.timer >= self.respawn_delay) then
                    self:SpawnFlag()
                end
            end
            return
        end

        self:SetNavMarker(flag_carrier)
    end
end

-- This function sets a nav marker above the flag carrier's head:
--
function TD:SetNavMarker(playerId)
    if (self.nav_marker) then
        for i = 1, 16 do
            -- Get static memory address of each player:
            local player = get_player(i)
            if (player ~= 0) then
                -- Set slayer target indicator to the flag carrier:
                if (playerId ~= nil and i ~= playerId and player_alive(i)) then
                    write_word(player + 0x88, to_real_index(playerId))
                else
                    -- Set slayer target indicator to themselves:
                    write_word(player + 0x88, to_real_index(i))
                end
            end
        end
    end
end

local upper = string.upper
function TD:AnnouncePickup(playerId)
    self.flag.timer = 0
    if (self.announce_pickup) then
        self.announce_pickup = false

        local msg = self.on_pickup

        local team = get_var(playerId, "$team")
        local name = get_var(playerId, '$name')

        -- Convert first char in team name to upper.
        local char = team:sub(1, 1)
        team = team:gsub(char, upper(char))

        msg = msg:gsub("$team", team):gsub("$name", name)
        self:Broadcast(nil, msg)
    end
end

local function getWeapon(dynamic_player, weapon_index)
    local weapon_id = read_dword(dynamic_player + 0x2F8 + (weapon_index * 4))
    local object = get_object_memory(weapon_id)
    return (weapon_id ~= 0xFFFFFFFF and object ~= 0 and object or nil)
end

-- Checks if a player is holding the flag:
-- @param playerId (player index) [number]
--
function TD:HasFlag(playerId)
    local dynamic_player = get_dynamic_player(playerId)
    if (dynamic_player ~= 0) then
        for i = 0, 3 do
            local weapon = getWeapon(dynamic_player, i)
            if (weapon) then
                local tag_address = read_word(weapon)
                local tag_data = read_dword(read_dword(0x40440000) + tag_address * 0x20 + 0x14)
                if (read_bit(tag_data + 0x308, 3) == 1) then
                    self:AnnouncePickup(playerId)
                    return true
                end
            end
        end
    end
    return false
end

-- Sets up pre-game parameters:
--
function TD:Init()
    local mode = get_var(0, '$gt')
    if (mode ~= 'n/a') then

        self.flag = { }
        self.game_started = false

        local map = self:Proceed(mode)
        if (map) then

            local tag_address = read_dword(0x40440000)
            local tag_count = read_dword(0x4044000C)

            for i = 0, tag_count - 1 do
                local tag = (tag_address + 0x20 * i)
                local tag_class = read_dword(tag)
                local globals_tag = read_dword(tag + 0x14)
                if (tag_class == 0x6D617467) then

                    self.game_started = true
                    self.announce_pickup = false
                    self.flag.id = read_dword(read_dword(globals_tag + 0x164 + 4) + 0xC)

                    self.z_off = 0.2
                    self.x = self[map][1]
                    self.y = self[map][2]
                    self.z = self[map][3] + self.z_off

                    self:SpawnFlag()

                    execute_command('scorelimit ' .. self.scoring[5])

                    register_callback(cb.EVENT_DIE, 'OnDeath')
                    register_callback(cb.EVENT_TICK, 'OnTick')
                    register_callback(cb.EVENT_GAME_END, 'OnEnd')
                    register_callback(cb.EVENT_DAMAGE_APPLICATION, 'OnDeath')
                    goto done
                end
            end
        end

        unregister_callback(cb.EVENT_DIE)
        unregister_callback(cb.EVENT_TICK)
        unregister_callback(cb.EVENT_GAME_END)
        unregister_callback(cb.EVENT_DAMAGE_APPLICATION)

        :: done ::
    end
end

-- Destroys the flag:
--
function TD:DestroyFlag()
    destroy_object(self.flag and self.flag.object or 0)
end

function TD:Proceed(mode)

    local map = get_var(0, '$map')

    local valid_mode = (get_var(0, '$ffa') == '0' and mode == 'slayer')
    if (not valid_mode) then
        cprint('Team Defender - [Only Team Slayer is supported]', 10)
    end

    if (not self[map]) then
        cprint('Capture The Flag - [' .. map .. ' is not configured]', 10)
    end

    return ((self[map] and valid_mode) and map) or false
end

function OnTick()
    TD:GameTick()
end

function OnDeath(V, K, MID)
    return TD:OnDeath(V, K, MID)
end

function OnScriptUnload()
    TD:DestroyFlag()
end