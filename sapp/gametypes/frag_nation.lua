--[[
=====================================================================================
SCRIPT NAME:      frag_nation.lua
DESCRIPTION:      Grenade-focused combat mode with strategic resource management
                  where players must carefully conserve and earn grenade supplies.

KEY FEATURES:
                 - Grenade-based economy system:
                   * Limited starting grenades
                   * Kill rewards replenish supplies
                   * Melee-only when depleted
                 - Custom weapon loadouts:
                   * Plasma pistol as primary
                   * Configurable starting ammo
                 - Map control options:
                   * Toggle weapons/vehicles/equipment
                   * Stock map optimization
                 - Adjustable victory conditions

CONFIGURATION OPTIONS:
                 - Customizable score limit
                 - Starting grenade quantities
                 - Kill reward values
                 - Primary weapon selection
                 - Ammo settings
                 - Map object management

Copyright (c) 2021-2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts --

local FragNation = {

    -- Number of kills to win:
    -- (Default: 25)
    --
    scorelimit = 25,

    -- Number of grenades (frags, plasmas, etc.) to give each player:
    -- Default: 2 of each
    --
    starting_grenades = { 2, 2 },

    -- Grenades rewarded per kill:
    --
    rewards = {

        --
        -- Format: {amount, output message}
        --

        -- Frag explosion:
        { 1, '+1 Frag' },

        -- Plasma Explosion:
        { 1, '+1 Plasma' },

        -- Plasma (sticky):
        { 2, '+2 Plasmas' },
    },

    -- Tag name of the primary weapon:
    --
    primary_weapon = 'weapons\\plasma pistol\\plasma pistol',

    -- Starting ammo for primary weapon:
    -- {loaded (ammo), unloaded (mag), battery (plasma weapons)}
    --
    ammo = {
        0,
        0,
        0
    },

    map_objects = {

        --
        -- Format: {tag class, tag name, enabled/disabled}
        --

        -- weapons:
        --
        { 'weap', 'weapons\\pistol\\pistol', false },
        { 'weap', 'weapons\\shotgun\\shotgun', false },
        { 'weap', 'weapons\\needler\\mp_needler', false },
        { 'weap', 'weapons\\flamethrower\\flamethrower', false },
        { 'weap', 'weapons\\plasma rifle\\plasma rifle', false },
        { 'weap', 'weapons\\sniper rifle\\sniper rifle', false },
        { 'weap', 'weapons\\assault rifle\\assault rifle', false },
        { 'weap', 'weapons\\plasma pistol\\plasma pistol', true }, -- primary weapon (do not disable)
        { 'weap', 'weapons\\plasma_cannon\\plasma_cannon', false },
        { 'weap', 'weapons\\rocket launcher\\rocket launcher', false },

        -- vehicles:
        --
        { 'weap', 'vehicles\\ghost\\ghost_mp', false },
        { 'weap', 'vehicles\\rwarthog\\rwarthog', false },
        { 'weap', 'vehicles\\warthog\\mp_warthog', false },
        { 'weap', 'vehicles\\banshee\\banshee_mp', false },
        { 'weap', 'vehicles\\scorpion\\scorpion_mp', false },
        { 'weap', 'vehicles\\c gun turret\\c gun turret_mp', false },

        -- equipment:
        --
        { 'eqip', 'powerups\\health pack', 'Health Pack', true },
        { 'eqip', 'powerups\\active camouflage', 'Camouflage', true },
        { 'eqip', 'powerups\\over shield', 'Over Shield', true },
        { 'eqip', 'weapons\\frag grenade\\frag grenade', true },
        { 'eqip', 'weapons\\plasma grenade\\plasma grenade', true },
    }
}

-- config ends --

local players = {}

local primary_weapon

local frag_grenade
local plasma_grenade
local plasma_grenade_sticky

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_DIE, 'DamageHandler')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_DAMAGE_APPLICATION, 'DamageHandler')
    OnStart()
end

local function GetTag(Class, Name)
    local tag = lookup_tag(Class, Name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

function FragNation:InitGameObjects()

    for _, v in pairs(self.map_objects) do
        local name = v[2]
        local enabled = v[3]
        if (not enabled) then
            execute_command('disable_object "' .. name .. '"')
        end
    end

    primary_weapon = GetTag('weap', self.primary_weapon)
    frag_grenade = GetTag('jpt!', 'weapons\\frag grenade\\explosion')
    plasma_grenade = GetTag('jpt!', 'weapons\\plasma grenade\\explosion')
    plasma_grenade_sticky = GetTag('jpt!', 'weapons\\plasma grenade\\attached')
end

function FragNation:SetAmmo(dyn)

    local p = self.id
    local ammo = self.ammo[1]
    local mag = self.ammo[2]
    local battery = self.ammo[3]
    local frags = self.starting_grenades[1]
    local plasmas = self.starting_grenades[2]

    execute_command('ammo ' .. p .. ' ' .. ammo .. ' 5')
    execute_command('mag ' .. p .. ' ' .. mag .. ' 5')
    execute_command('battery ' .. p .. ' ' .. battery .. ' 5')

    self:UpdateNades(dyn, 1, frags)
    self:UpdateNades(dyn, 2, plasmas)

    rprint(self.id, 'You have been assigned a plasma pistol.')
end

function FragNation:UpdateNades(dyn, type, amount)
    write_byte(dyn + (type == 1 and 0x31E or 0x31F), amount)
end

function FragNation:NewPlayer(o)

    setmetatable(o, self)
    self.__index = self

    o.assign = true
    o.meta_id = 0

    return o
end

function OnStart()

    if (get_var(0, '$gt') ~= 'n/a') then

        players = { }

        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end

        FragNation:InitGameObjects()
    end
end

function OnTick()
    for i, v in pairs(players) do

        local dyn = get_dynamic_player(i)

        if (player_present(i) and player_alive(i) and v.assign and dyn ~= 0) then

            v.assign = false

            execute_command('wdel ' .. i)
            assign_weapon(spawn_object('', '', 0, 0, 0, 0, primary_weapon), i)

            v:SetAmmo(dyn)

        end
    end
end

function OnJoin(Ply)
    players[Ply] = FragNation:NewPlayer({
        id = Ply
    })
end

function OnQuit(Ply)
    players[Ply] = nil
end

function DamageHandler(Victim, Killer, MetaID)

    local killer = tonumber(Killer)
    local victim = tonumber(Victim)

    local k = players[killer]
    local pvp = (k and killer > 0 and killer ~= victim)

    if (MetaID and pvp) then
        k.meta_id = MetaID
        return
    end

    local dyn = get_dynamic_player(killer)
    if (pvp and dyn ~= 0) then

        local frags = tonumber(read_byte(dyn + 0x31E))
        local plasmas = tonumber(read_byte(dyn + 0x31F))

        local str = ''
        local meta_id = k.meta_id

        if (meta_id == frag_grenade) then
            frags = frags + k.rewards[1][1]
            k:UpdateNades(dyn, 1, frags)
            str = k.rewards[1][2]

        elseif (meta_id == plasma_grenade) then
            k:UpdateNades(dyn, 2, plasmas)
            plasmas = plasmas + k.rewards[2][1]
            str = k.rewards[2][2]

        elseif (meta_id == plasma_grenade_sticky) then
            k:UpdateNades(dyn, 3, plasmas)
            plasmas = plasmas + k.rewards[3][1]
            str = k.rewards[3][2]
        end
        k.meta_id = 0

        rprint(killer, str)
    end
end

function OnScriptUnload()
    -- N/A
end