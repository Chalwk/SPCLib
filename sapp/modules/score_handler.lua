--[[
=====================================================================================
SCRIPT NAME:      score_handler.lua
DESCRIPTION:      Comprehensive score management system with customizable point values
                  for all game events and advanced scoring mechanics.

FEATURES:
                  - Custom point values for every game action (kills, deaths, events)
                  - Support for special scoring scenarios:
                    * First blood rewards
                    * Headshot bonuses
                    * Assassination (back tap) bonuses
                    * Killing sprees and multi-kill combos
                    * Zombie infection mechanics
                  - Team-specific flag carrier kill bonuses
                  - Detailed damage source tracking (weapons, vehicles, grenades)
                  - Customizable scoring messages
                  - Vehicle collision detection

CONFIGURATION:
                  custom_messages:  Toggle scoring notifications (default: true)
                  score:           Base points for flag captures
                  red_flag_kill:   Points for killing red flag carrier
                  blue_flag_kill:  Points for killing blue flag carrier
                  assist:          Points for assists
                  first_blood:     Bonus for first kill
                  head_shot:       Headshot bonus
                  assassination:   Back tap melee bonus
                  suicide:         Penalty for suicide
                  betrayal:        Penalty for team kills
                  spree:           Killing spree bonuses (configurable tiers)
                  multi_kill:      Combo kill bonuses (configurable tiers)
                  tags:            Detailed weapon/vehicle damage point values

USAGE:
                  Fully automatic operation - no commands needed
                  Configure all settings in the Scoring table at script top
                  Set point values to 0 to disable specific scoring events

ADVANCED FEATURES:
                  - Zombie mode configuration (human/zombie teams, infection points)
                  - Vehicle-specific collision detection
                  - Weapon-specific damage tracking
                  - Custom damage messages for each damage source

Copyright (c) 2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local Scoring = {

    --=================================================--
    -- Configuration Starts --
    --=================================================--

    -- If true, players will see custom scoring messages:
    -- Example: "-1 Suicide"
    --
    custom_messages = true,

    --------------------------------------------------------------
    -- To disable scoring for any option below, set the value to 0
    --------------------------------------------------------------

    -- FLAG CAPTURE:
    score = { 1, "Flag Capture" },

    -- RED FLAG CARRIER KILL:
    red_flag_kill = {5, "Red Flag Carrier Kill"},

    -- BLUE FLAG CARRIER KILL:
    blue_flag_kill = {5, "Blue Flag Carrier Kill"},

    -- ASSIST:
    assist = { 1, "Assist" },

    -- KILLED BY SERVER:
    server = { 0, "Killed by Server" },

    -- KILLED FROM THE GRAVE:
    killed_from_the_grave = { 1, "Killed from the grave" },

    -- FIRST BLOOD:
    first_blood = { 1, "First Blood" },

    -- HEADSHOT:
    head_shot = { 3, "Headshot" },

    -- BACK TAP (melee from behind)
    assassination = { 1, "Assassination" },

    -- KILLED BY GUARDIANS:
    guardians = { -1, "Guardians" },

    -- SUICIDE:
    suicide = { -1, "Suicide (rip)" },

    -- BETRAYAL:
    betrayal = { -1, "Betrayal" },

    -- TEAM CHANGE:
    team_change = { -1, "Team Change Penalty" },

    -- SQUASHED BY VEHICLE:
    squashed = { -1, "Squashed" },

    -- ZOMBIE INFECT:
    --
    zombies = {
        points = { 1, "Zombie Infect" },
        enabled = false,
        human_team = "red",
        zombie_team = "blue",
    },

    -- KILLING SPREE:
    --
    spree = {

        -- 1 bonus point every 5 kills (up to 45 kills)
        { 5, 1, "Spree" },
        { 10, 1, "Spree" },
        { 15, 1, "Spree" },
        { 20, 1, "Spree" },
        { 25, 1, "Spree" },
        { 30, 1, "Spree" },
        { 35, 1, "Spree" },
        { 40, 1, "Spree" },
        { 45, 1, "Spree" },

        -- 2 bonus points every 5 kills at or above 50 kills:
        { 50, 2, 5, "Spree" },
    },

    -- KILL COMBOS:
    --
    multi_kill = {

        -- 1 bonus point every kill (up to 9)
        { 2, 1, "Combo Kill" },
        { 3, 1, "Combo Kill" },
        { 4, 1, "Combo Kill" },
        { 5, 1, "Combo Kill" },
        { 6, 1, "Combo Kill" },
        { 7, 1, "Combo Kill" },
        { 8, 1, "Combo Kill" },
        { 9, 1, "Combo Kill" },

        -- 2 points every 2 kills at or above 10 kills:
        { 10, 2, 2, "Combo Kill" },
    },

    tags = {

        -- FALL DAMAGE --
        --
        { "jpt!", "globals\\falling", -1, "Hit the ground too hard" },
        { "jpt!", "globals\\distance", -1, "Fall Damage" },

        -- VEHICLE PROJECTILES --
        --
        { "jpt!", "vehicles\\ghost\\ghost bolt", 1, "Ghost Bolt" },
        { "jpt!", "vehicles\\scorpion\\bullet", 1, "Tank Bullet" },
        { "jpt!", "vehicles\\warthog\\bullet", 1, "Hog Bullet" },
        { "jpt!", "vehicles\\c gun turret\\mp bolt", 1, "Turret Bolt" },
        { "jpt!", "vehicles\\banshee\\banshee bolt", 1, "Banshee Bolt" },
        { "jpt!", "vehicles\\scorpion\\shell explosion", 1, "Tank Shell" },
        { "jpt!", "vehicles\\banshee\\mp_fuel rod explosion", 1, "Banshee Fuel Rod" },

        -- WEAPON PROJECTILES --
        --
        { "jpt!", "weapons\\pistol\\bullet", 1, "Pistol Bullet" },
        { "jpt!", "weapons\\shotgun\\pellet", 1, "Shotgun Bullet" },
        { "jpt!", "weapons\\plasma rifle\\bolt", 1, "Plasma Rifle Bolt" },
        { "jpt!", "weapons\\needler\\explosion", 1, "Needler Explosion" },
        { "jpt!", "weapons\\plasma pistol\\bolt", 1, "Plasma Pistol Bolt" },
        { "jpt!", "weapons\\assault rifle\\bullet", 1, "Assault Rifle Bullet" },
        { "jpt!", "weapons\\needler\\impact damage", 1, "Needler Explosion" },
        { "jpt!", "weapons\\flamethrower\\explosion", 1, "Flames" },
        { "jpt!", "weapons\\flamethrower\\burning", 1, "Flames" },
        { "jpt!", "weapons\\flamethrower\\impact damage", 1, "Flames" },
        { "jpt!", "weapons\\rocket launcher\\explosion", 1, "Rocket Explosion" },
        { "jpt!", "weapons\\needler\\detonation damage", 1, "Needler Explosion" },
        { "jpt!", "weapons\\plasma rifle\\charged bolt", 1, "Plasma Rifle Bolt (charged)" },
        { "jpt!", "weapons\\sniper rifle\\sniper bullet", 1, "Sniper Bullet" },
        { "jpt!", "weapons\\plasma_cannon\\effects\\plasma_cannon_explosion", 1, "Fuel Rod Explosion" },

        -- GRENADES --
        --
        { "jpt!", "weapons\\frag grenade\\explosion", 1, "Frag Explosion" },
        { "jpt!", "weapons\\plasma grenade\\attached", 2, "Sticky" }, -- sticky
        { "jpt!", "weapons\\plasma grenade\\explosion", 1, "Plasma Explosion" },

        -- MELEE --
        --
        { "jpt!", "weapons\\flag\\melee", 2, "Flag Melee" },
        { "jpt!", "weapons\\ball\\melee", 2, "Skull Melee" },
        { "jpt!", "weapons\\pistol\\melee", 2, "Pistol Melee" },
        { "jpt!", "weapons\\needler\\melee", 2, "Needler Melee" },
        { "jpt!", "weapons\\shotgun\\melee", 2, "Shotgun Melee" },
        { "jpt!", "weapons\\flamethrower\\melee", 2, "Flamethrower Melee" },
        { "jpt!", "weapons\\sniper rifle\\melee", 2, "Sniper Melee" },
        { "jpt!", "weapons\\plasma rifle\\melee", 2, "Plasma Rifle Melee" },
        { "jpt!", "weapons\\plasma pistol\\melee", 2, "Plasma Pistol Melee" },
        { "jpt!", "weapons\\assault rifle\\melee", 2, "Assault Rifle Melee" },
        { "jpt!", "weapons\\rocket launcher\\melee", 2, "Rocket Launcher Melee" },
        { "jpt!", "weapons\\plasma_cannon\\effects\\plasma_cannon_melee", 2, "Plasma Cannon Melee" },

        -- VEHICLE COLLISION --
        --
        collision = { "jpt!", "globals\\vehicle_collision" },
        vehicles = {
            { "vehi", "vehicles\\ghost\\ghost_mp", 1, "Ghost Squash" },
            { "vehi", "vehicles\\rwarthog\\rwarthog", 1, "Rocket Hog Squash" },
            { "vehi", "vehicles\\warthog\\mp_warthog", 1, "Hog Squash" },
            { "vehi", "vehicles\\banshee\\banshee_mp", 1, "Banshee Squash" },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 1, "Tank Squash" },
            { "vehi", "vehicles\\c gun turret\\c gun turret_mp", 0, "Turret Squash (how?)" }
        }
    }

    --=================================================--
    -- Configuration Ends --
    --=================================================--
}

api_version = "1.12.0.0"

local globals

function OnScriptLoad()

    register_callback(cb.EVENT_SCORE, "OnScore")

    register_callback(cb.EVENT_GAME_START, "OnNewGame")
    register_callback(cb.EVENT_GAME_END, "OnGameEnd")

    register_callback(cb.EVENT_TEAM_SWITCH, "TeamChange")

    register_callback(cb.EVENT_JOIN, "OnPlayerJoin")
    register_callback(cb.EVENT_LEAVE, "OnPlayerQuit")

    register_callback(cb.EVENT_SPAWN, "OnPlayerSpawn")

    register_callback(cb.EVENT_DIE, "DeathHandler")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "DeathHandler")

    local gp = sig_scan("8B3C85????????3BF9741FE8????????8B8E2C0200008B4610") + 3
    if (gp == 3) then
        return
    end
    globals = read_dword(gp)

    OnNewGame(globals)
end

local function GetTag(Type, Name)
    local Tag = lookup_tag(Type, Name)
    return Tag ~= 0 and read_dword(Tag + 0xC) or nil
end

function Scoring:OnNewGame()

    if (get_var(0, "$gt") ~= "n/a") then

        self.melee = { }
        self.players = { }

        self.game_over = false
        self.init_first_blood = true
        self.team_play = (get_var(0, "$ffa") == "0")

        self.fall_damage = GetTag(self.tags[1][1], self.tags[1][2])
        self.distance_damage = GetTag(self.tags[2][1], self.tags[2][2])

        local collision = self.tags.collision
        self.vehicle_collision = GetTag(collision[1], collision[2])

        self.red_flag, self.blue_flag = read_dword(globals + 0x8), read_dword(globals + 0xC)

        for i = 1, 16 do
            if player_present(i) then
                self:InitPlayer(i, false)
            end
        end
    end
end

function OnGameEnd()
    Scoring.game_over = true
end

function OnPlayerJoin(Ply)
    Scoring:InitPlayer(Ply, false)
end

function OnPlayerQuit(Ply)
    Scoring:InitPlayer(Ply, true)
end

function OnPlayerSpawn(Ply)
    if (Scoring.players[Ply]) then
        Scoring.players[Ply].meta_id = 0
    end
end

function TeamChange(Ply)
    if (Scoring.players[Ply]) then
        Scoring.players[Ply].team_change = true
        Scoring.players[Ply].team = get_var(Ply, "$team")
    end
end

local function SetPoints(Ply, Amount, Offset, Msg)

    if (Amount ~= 0) then

        if (Offset) then
            execute_command("score " .. Ply .. " " .. Offset)
        end

        local score = tonumber(get_var(Ply, "$score"))
        execute_command("score " .. Ply .. " " .. (score + Amount))

        if (Scoring.custom_messages) then
            local char = (Amount > 0 and "+") or ""
            rprint(Ply, "(" .. char .. Amount .. ") " .. Msg)
        end
    end
end

local function GetPoints(MetaID)
    for _, v in pairs(Scoring.tags) do
        local tag = GetTag(v[1], v[2])
        if (tag ~= nil and tag == MetaID) then
            return v[3], v[4]
        end
    end
    return 0, ""
end

local function Falling(MetaID)
    if (MetaID == Scoring.fall_damage) then
        return Scoring.tags[1][3], Scoring.tags[1][3][4]
    elseif (MetaID == Scoring.distance_damage) then
        return Scoring.tags[2][3], Scoring.tags[2][3][4]
    end
    return nil
end

local function MultiKill(Ply)
    local player = get_player(Ply)
    if (player ~= 0) then
        local k = read_word(player + 0x98)
        local t = Scoring.multi_kill
        for _, v in pairs(t) do
            if (k == v[1]) or (k >= t[#t][1] and k % t[#t][3] == 0) then
                SetPoints(Ply, v[2], nil, v[3])
            end
        end
    end
end

local function KillingSpree(Ply)
    local player = get_player(Ply)
    if (player ~= 0) then
        local k = read_word(player + 0x96)
        local t = Scoring.spree
        for _, v in pairs(t) do
            if (k == v[1]) or (k >= t[#t][1] and k % t[#t][3] == 0) then
                SetPoints(Ply, v[2], nil, v[3])
            end
        end
    end
end

local function FirstBlood(Ply)
    local kills = tonumber(get_var(Ply, "$kills"))
    if (Scoring.init_first_blood and kills == 1) then
        Scoring.init_first_blood = false
        SetPoints(Ply, Scoring.first_blood[1], nil, Scoring.first_blood[2])
    end
end

local function GetTagName(TAG)
    if (TAG ~= nil and TAG ~= 0) then
        return read_string(read_dword(read_word(TAG) * 32 + 0x40440038))
    end
    return nil
end

function Scoring:DeathHandler(V, K, MetaID, _, HitString, BackTap)

    local killer, victim = tonumber(K), tonumber(V)

    local k = self.players[killer]
    local v = self.players[victim]

    -- event_damage_application:
    --
    if (MetaID) then
        if player_present(victim) then
            if (killer > 0 and k) then
                k.meta_id = MetaID
                if (HitString == "head") then
                    k.head_shot = true
                elseif (BackTap ~= 0) then
                    k.assassination = true
                end
            end
            if (v) then
                v.meta_id = MetaID
            end
        end
        return
    end

    -- event_die:
    --
    local server = (killer == -1)
    local squashed = (killer == 0)
    local guardians = (killer == nil)
    local suicide = (killer == victim)
    local falling, falling_msg = Falling(v.meta_id)
    local pvp = ((killer > 0) and killer ~= victim)
    local vehicle_collision = self.vehicle_collision
    local team_change = (server and v.team_change and not falling)
    local betrayal = (k and k.team == v.team and (not suicide) and self.team_play)

    v.team_change = false

    if (pvp and not betrayal) then

        -- first blood:
        --
        FirstBlood(killer)

        -- kill combo:
        --
        MultiKill(killer)

        -- killing spree:
        --
        KillingSpree(killer)

        -- flag carrier kill:
        --
        local flag, flag_points = self:HasFlag(victim)
        if (flag) then
            SetPoints(killer, flag_points[1], nil, flag_points[2])
        end

        -- killed from the grave:
        --
        if (not player_alive(killer)) then
            SetPoints(killer, self.killed_from_the_grave[1], nil, self.killed_from_the_grave[2])
        end

        if (k) then

            -- Assists:
            --
            local assists = tonumber(get_var(killer, "$assists"))
            if (assists ~= 0 and assists > k.assists) then
                k.assists = assists
                SetPoints(killer, self.assist[1], nil, self.assist[2])
            end

            -- Zombie Infect:
            --
            local z = self.zombies
            local case = (k.team == z.zombie_team and v.team == z.human_team)
            if (z.enabled and case) then
                return SetPoints(killer, z.points[1], "-1", z.points[2])
            end

            -- Back-Tap & Head Shot
            --
            if (k.assassination) then
                SetPoints(killer, self.assassination[1], nil, self.assassination[2])
            elseif (k.head_shot) then
                SetPoints(killer, self.head_shot[1], nil, self.head_shot[2])
            end

            k.head_shot = false
            k.assassination = false

            -- Vehicle Squash:
            --
            if (k.meta_id == vehicle_collision) then
                local DyN = get_dynamic_player(killer)
                if (DyN ~= 0) then
                    local VehicleID = read_dword(DyN + 0x11C)
                    local Object = get_object_memory(VehicleID)
                    if (Object ~= 0) then
                        local tag = GetTagName(Object)
                        if (tag) then
                            for _, a in pairs(self.tags.vehicles) do
                                if (tag == a[2]) then
                                    local points, msg = a[3], a[4]
                                    SetPoints(killer, points, nil, msg)
                                end
                            end
                        end
                    end
                end
                return
            end
        end

        -- PvP:
        --
        local points, msg = GetPoints(v.meta_id)
        SetPoints(killer, points, "-1", msg)

        -- Team Change:
        --
    elseif (team_change) then
        SetPoints(victim, self.team_change[1], nil, self.team_change[2])

        -- Server:
        --
    elseif (server and not falling) then
        SetPoints(victim, self.server[1], nil, self.server[2])

        -- Guardians:
        --
    elseif (guardians) then

        SetPoints(victim, self.guardians[1], nil, self.guardians[2])
        SetPoints(killer, self.guardians[1], nil, self.guardians[2])

        -- Suicide:
        --
    elseif (suicide) then

        SetPoints(victim, self.suicide[1], "+1", self.suicide[2])

        -- Betrayal:
        --
    elseif (betrayal) then

        SetPoints(killer, self.betrayal[1], "+1", self.betrayal[2])

        -- Squashed:
        --
    elseif (squashed) then
        SetPoints(victim, self.squashed[1], nil, self.squashed[2])

        -- Falling:
        --
    elseif (falling ~= nil) then
        SetPoints(victim, falling, nil, falling_msg)
    else

        -- Died/Unknown
        --
        local points, msg = GetPoints(v.meta_id)
        SetPoints(victim, points, msg)
    end
end

function Scoring:InitPlayer(Ply, Reset)

    if (not Reset) then
        self.players[Ply] = {
            assists = 0,
            meta_id = 0,
            head_shot = false,
            team_change = false,
            assassination = false,
            team = get_var(Ply, "$team")
        }
        return
    end

    self.players[Ply] = nil
end

function Scoring:HasFlag(Ply)
    local DyN = get_dynamic_player(Ply)
    if (DyN ~= 0) then
        local Weapon = read_dword(DyN + 0x118)
        if (Weapon ~= 0) then
            for j = 0, 3 do
                local Object = read_dword(DyN + 0x2F8 + 4 * j)
                if (Object == self.red_flag) then
                    return true, self.red_flag_kill
                elseif (Object == self.blue_flag) then
                    return true, self.blue_flag_kill
                end
            end
        end
    end
    return nil, nil
end

function OnScore(Ply)
    SetPoints(Ply, Scoring.score[1], "-1", Scoring.score[2])
end

function DeathHandler(A, B, C, E, F, G)
    return Scoring:DeathHandler(A, B, C, E, F, G)
end

function OnNewGame()
    return Scoring:OnNewGame()
end

function OnScriptUnload()

end