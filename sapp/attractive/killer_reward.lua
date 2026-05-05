--[[
=====================================================================================
SCRIPT NAME:      killer_reward.lua
DESCRIPTION:      Drops random weapons/equipment at victim death locations
                  - Configurable drop conditions (consecutive kills required)
                  - Customizable drop tables (weapons and/or equipment)
                  - Detailed kill streak rewards system
                  - Player-specific tracking and notifications

                  Features:
                  - Three drop modes: Weapons only, Equipment only, or Both
                  - Optional consecutive kills requirement (default: 5 kills)
                  - Customizable drop item tables
                  - Death location detection (ground/vehicle)
                  - Player notifications about drops

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local KillerRewards = {

    -- Weapons & equipment drop candidates:
    -- Default: true
    --
    weapons_and_equipment = true,

    -- Weapon only drop candidates:
    -- Default: false
    --
    weapons = false,

    -- Equipment only drop candidates:
    -- Default: false
    --
    equipment = false,

    -- Players must have "consecutive_kills" in order for their victim
    -- to drop an item:
    -- Default: true
    --
    consecutive = true,

    -- Number of consecutive kills required to trigger a drop:
    -- Default: 5
    --
    consecutive_kills = 5,

    -------------------------------------------------------
    -- Items in these lists are candidates for drops.
    -- Remove a line to prevent it from dropping.
    -------------------------------------------------------

    -- weapon tags:
    -- (class, name, label)
    --
    weapons = {
        { 'weap', 'weapons\\pistol\\pistol', 'Pistol' },
        { 'weap', 'weapons\\shotgun\\shotgun', 'Shotgun' },
        { 'weap', 'weapons\\needler\\mp_needler', 'Needler' },
        { 'weap', 'weapons\\flamethrower\\flamethrower', 'Flamethrower' },
        { 'weap', 'weapons\\plasma rifle\\plasma rifle', 'Plasma Rifle' },
        { 'weap', 'weapons\\sniper rifle\\sniper rifle', 'Sniper Rifle' },
        { 'weap', 'weapons\\assault rifle\\assault rifle', 'Assault Rifle' },
        { 'weap', 'weapons\\plasma pistol\\plasma pistol', 'Plasma Pistol' },
        { 'weap', 'weapons\\plasma_cannon\\plasma_cannon', 'Plasma Cannon' },
        { 'weap', 'weapons\\rocket launcher\\rocket launcher', 'Rocket Launcher' }
    },

    -- equipment tags:
    -- (class, name, label)
    --
    equipment = {
        { 'eqip', 'powerups\\health pack', 'Health Pack' },
        { 'eqip', 'powerups\\over shield', 'Overshield' },
        { 'eqip', 'powerups\\active camouflage', 'Camouflage' },
        { 'eqip', 'powerups\\pistol ammo\\pistol ammo', 'Pistol Ammo' },
        { 'eqip', 'powerups\\shotgun ammo\\shotgun ammo', 'Shotgun Ammo' },
        { 'eqip', 'powerups\\needler ammo\\needler ammo', ' Needler Ammo' },
        { 'eqip', 'powerups\\flamethrower ammo\\flamethrower ammo', 'Flamethrower Ammo' },
        { 'eqip', 'powerups\\sniper rifle ammo\\sniper rifle ammo', 'Sniper Ammo' },
        { 'eqip', 'powerups\\assault rifle ammo\\assault rifle ammo', 'Assault Rifle Ammo' },
        { 'eqip', 'powerups\\rocket launcher ammo\\rocket launcher ammo', ' Rocket Launcher Ammo' }
    }
}

local weapons = { }
local equipment = { }
local players = { }

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb['EVENT_DIE'], 'OnDeath')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

-- Returns the memory address (meta id) of a tag using its tag class and name:
-- @return meta id (number)
local function GetTag(class, name)
    local tag = lookup_tag(class, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

-- Populate weapons & equipment tables with the meta id's of
-- the weapon/equipment tag addresses:
function KillerRewards:TagsToID()
    local w, e = { }, { }

    for i = 1, #self.weapons do
        local v = self.weapons[i]
        local class = v[1]
        local name = v[2]
        local label = v[3]
        local tag = GetTag(class, name)
        if (tag) then
            w[i] = { tag, label }
        end
    end

    for i = 1, #self.equipment do
        local v = self.equipment[i]
        local class = v[1]
        local name = v[2]
        local label = v[3]
        local tag = GetTag(class, name)
        if (tag) then
            e[i] = { tag, label }
        end
    end

    return w, e
end

function KillerRewards:NewPlayer(o)
    setmetatable(o, { __index = self })
    self.__index = self
    return o
end

function KillerRewards:Kills()
    return tonumber(get_var(self.id, '$kills'))
end

local function GetXYZ(Ply)
    local x, y, z

    local dyn = get_dynamic_player(Ply)
    if (dyn ~= 0) then
        local vehicle = read_dword(dyn + 0x11C)
        local object = get_object_memory(vehicle)
        if (vehicle == 0xFFFFFFFF) then
            x, y, z = read_vector3d(dyn + 0x5C)
        elseif (object ~= 0) then
            x, y, z = read_vector3d(object + 0x5C)
        end
    end

    return x, y, z
end

local function GetRandWeap()
    return weapons[rand(1, #weapons + 1)]
end

local function GetRandEquip()
    return equipment[rand(1, #equipment + 1)]
end

function KillerRewards:SpawnItem(k)

    local object
    if (self.weapons_and_equipment) then
        local n = rand(1, 3)
        object = (n == 1 and GetRandWeap() or GetRandEquip())
    elseif (self.weapons) then
        object = GetRandWeap()
    elseif (self.equipment) then
        object = GetRandEquip()
    end

    if (not object) then
        return
    end

    local x, y, z = GetXYZ(self.id)
    local z_off = 0.3

    spawn_object('', '', x, y, z + z_off, 0, object[1])
    rprint(k.id, object[2] .. ' dropped at ' .. self.name .. 's death location')
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then
        players = {}
        weapons, equipment = KillerRewards:TagsToID()
    end
end

function OnJoin(Ply)
    players[Ply] = KillerRewards:NewPlayer({
        id = Ply,
        name = get_var(Ply, '$name')
    })
end

function OnQuit(Ply)
    players[Ply] = nil
end

function OnDeath(Victim, Killer)

    local victim = tonumber(Victim)
    local killer = tonumber(Killer)

    local k = players[killer]
    local v = players[victim]

    local pvp = (killer > 0 and k and v and killer ~= victim)

    if (pvp and (k.consecutive and k:Kills() % k.consecutive_kills == 0 or not k.consecutive)) then
        v:SpawnItem(k)
    end
end

function OnScriptUnload()
    -- N/A
end