--[[
===============================================================================
SCRIPT NAME:      custom_loadouts.lua
DESCRIPTION:      Custom weapon loadout system with multiple pre-configured
                  weapon sets, automatic application on spawn, player selection,
                  admin override capabilities, custom ammo, grenade counts, a
                  selection menu, and persistent player preferences.

Copyright (c) 2024-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG START ------------------

-- Whether to show the loadout list whenever a player dies.
local show_loadouts_on_death = true

-- The loadout ID a new player starts with (must match an id in the loadouts table).
local default_loadout = 1

local commands = {
    base = "loadout", -- Main chat command players use to interact with loadouts.
    list = "list",    -- Sub-command to list all available loadouts.
    set  = "set"      -- Sub-command for admins to force a loadout onto a player.
}

local weapon_tags = {
    -- default map tags --
    [1] = 'weapons\\pistol\\pistol',
    [2] = 'weapons\\sniper rifle\\sniper rifle',
    [3] = 'weapons\\plasma_cannon\\plasma_cannon',
    [4] = 'weapons\\rocket launcher\\rocket launcher',
    [5] = 'weapons\\plasma pistol\\plasma pistol',
    [6] = 'weapons\\plasma rifle\\plasma rifle',
    [7] = 'weapons\\assault rifle\\assault rifle',
    [8] = 'weapons\\flamethrower\\flamethrower',
    [9] = 'weapons\\needler\\mp_needler',
    [10] = 'weapons\\shotgun\\shotgun',

    --
    -- place custom map tags here --
    -- For example:
    -- [11] = 'revolution\\weapons\\pistol\\rev pistol',
}

-- The numbers in the 'weapons' list (like [7] in a loadout) correspond to the numbered entries
-- in the 'weapon_tags' list above (so [7] = Assault Rifle). Only numbers that exist in
-- 'weapon_tags' will actually give you a weapon.
-- If you use a number not listed there, nothing will be added.

local loadouts = {
    {
        id = 1,
        name = "Default",
        frags = 1,
        plasmas = 3,
        weapons = {
            [7] = { label = 'ARifle', clip = 60, ammo = 120 },
            [1] = { label = 'Pistol', clip = 12, ammo = 48 }
        }
    },
    {
        id = 2,
        name = "LoneWolf",
        frags = 0,
        plasmas = 0,
        weapons = {
            [2] = { label = 'Sniper', clip = 4, ammo = 8 }
        }
    },
    {
        id = 3,
        name = "ShottySnipes",
        frags = 0,
        plasmas = 0,
        weapons = {
            [10] = { label = 'Shotgun', clip = 12, ammo = 24 },
            [2] = { label = 'Sniper', clip = 4, ammo = 8 }
        }
    },
    {
        id = 4,
        name = "HeavyOrdnance",
        frags = 2,
        plasmas = 0,
        weapons = {
            [4] = { label = 'RLauncher', clip = 2, ammo = 4 },
            [3] = { label = 'PCannon', clip = 100, ammo = 200 },
            [5] = { label = 'PPistol', clip = 12, ammo = 48 }
        }
    }
}
-- CONFIG ENDS -------------------

api_version = '1.12.0.0'

local get_var = get_var
local write_byte = write_byte
local write_word = write_word
local lookup_tag = lookup_tag
local read_dword = read_dword
local spawn_object = spawn_object
local get_object_memory = get_object_memory
local rprint = rprint
local player_present = player_present
local get_dynamic_player = get_dynamic_player

local str_lower = string.lower
local str_format = string.format
local str_match = string.match
local str_gmatch = string.gmatch
local tbl_concat = table.concat
local tbl_sort = table.sort

local weapon_datums = {}
local players = {}
local loadouts_by_id = {}
local player_data = {}

local function set_grenades(dyn_player, frags, plasmas)
    write_byte(dyn_player + 0x31E, frags or 0)
    write_byte(dyn_player + 0x31F, plasmas or 0)
end

local function get_tag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function cache_weapon_datums()
    for _, tag_string in pairs(weapon_tags) do
        weapon_datums[tag_string] = get_tag('weap', tag_string)
    end
end

function AssignWeapon(id, weapon)
    if weapon then assign_weapon(weapon, id) end
end

local function build_loadout_indexes()
    loadouts_by_id = {}

    for i = 1, #loadouts do
        local loadout = loadouts[i]
        loadouts_by_id[loadout.id] = loadout

        local labels = {}
        for weap_idx, weapon in pairs(loadout.weapons) do
            local tag_string = weapon_tags[weap_idx]
            if tag_string then
                labels[#labels + 1] = weapon.label or tag_string
            end
        end
        tbl_sort(labels)
        loadout._weapon_text = tbl_concat(labels, ", ")
    end

    default_loadout_id = loadouts_by_id[default_loadout] and default_loadout or
        (loadouts[1] and loadouts[1].id or 1)
end

local function spawn_weapon(id, tag_string, attributes, slot)
    local tag_datum = weapon_datums[tag_string]
    if not tag_datum then return end

    local weapon = spawn_object('', '', 0, 0, 0, 0, tag_datum)
    if weapon == 0 then return end

    local weapon_mem = get_object_memory(weapon)
    if weapon_mem == 0 then return end

    write_word(weapon_mem + 0x2B6, attributes.ammo or 0)
    write_word(weapon_mem + 0x2B8, attributes.clip or 0)
    sync_ammo(weapon)

    if slot <= 2 then
        AssignWeapon(id, weapon)
    else
        timer(250, 'AssignWeapon', id, weapon)
    end
end

local function get_player_loadout_id(id)
    return players[id] or default_loadout_id
end

local function apply_loadout(id)
    local dyn_player = get_dynamic_player(id)
    if dyn_player == 0 then return end

    execute_command('wdel ' .. id)

    local loadout = loadouts_by_id[get_player_loadout_id(id)] or loadouts_by_id[default_loadout_id]
    if not loadout then return end

    local slot = 0
    for weap_idx, attributes in pairs(loadout.weapons) do
        local tag_string = weapon_tags[weap_idx]
        if tag_string then
            slot = slot + 1
            spawn_weapon(id, tag_string, attributes, slot)
        end
    end

    set_grenades(dyn_player, loadout.frags, loadout.plasmas)
end

local function show_current_loadout(id)
    local loadout_id = get_player_loadout_id(id)
    local loadout = loadouts_by_id[loadout_id] or loadouts_by_id[default_loadout_id]
    if not loadout then
        rprint(id, "No loadout configured.")
        return
    end

    rprint(id, "Current Loadout: #" .. loadout_id .. " - " .. loadout.name)
end

local function show_available_loadouts(id)
    rprint(id, "Available Loadouts:")

    for i = 1, #loadouts do
        local loadout = loadouts[i]
        rprint(id, "[" .. loadout.id .. "]: " .. loadout.name)
        rprint(id, "Weaps: " .. (loadout._weapon_text or ""))
        rprint(id, "Grenades: " .. (loadout.frags or 0) .. "/" .. (loadout.plasmas or 0))
        rprint(id, " ")
    end

    rprint(id, "Use /" .. commands.base .. " [number] to select")
end

local function process_loadout_command(id, selected_id)
    local loadout = loadouts_by_id[selected_id]
    if not loadout then return false end

    players[id] = selected_id
    player_data[id] = selected_id
    rprint(id, "Loadout #" .. selected_id .. " (" .. loadout.name .. ") selected.")
    rprint(id, "Will apply on respawn.")
    return true
end

local function process_admin_command(id, args)
    local level = tonumber(get_var(id, "$lvl")) or 0
    if level < 1 then
        rprint(id, "You do not have permission to use this command.")
        return false
    end

    local target_id = tonumber(args[3] or "")
    local loadout_id = tonumber(args[4] or "")

    if not target_id or not player_present(target_id) then
        rprint(id, "Invalid player ID.")
        return false
    end

    if not loadouts_by_id[loadout_id] then
        rprint(id, "Invalid loadout ID.")
        return false
    end

    players[target_id] = loadout_id

    local target_name = get_var(target_id, '$name')
    player_data[target_id] = loadout_id
    rprint(id, str_format("Set player ID %d (%s) loadout to #%d", target_id, target_name, loadout_id))
    return true
end

local function parse_cmd(s)
    local args = {}
    for w in str_gmatch(s, '([^%s]+)') do args[#args + 1] = str_lower(w) end
    return args
end

function OnCommand(id, command)
    if id == 0 then return true end

    local args = parse_cmd(str_lower(command or ""))
    if args[1] ~= commands.base then return true end

    if #args == 1 then
        show_current_loadout(id)
        return false
    end

    local sub = args[2]
    if sub == commands.list then
        show_available_loadouts(id)
    elseif sub == commands.set then
        process_admin_command(id, args)
    elseif sub and str_match(sub, '^%d+$') then
        local selected_id = tonumber(sub)
        if not process_loadout_command(id, selected_id) then
            rprint(id, "Unknown loadout ID. Use /" .. commands.base .. " " .. commands.list .. " to see options.")
        end
    else
        rprint(id, "Unknown command. Use /" .. commands.base .. " " .. commands.list .. " to see options.")
    end

    return false
end

function OnScriptLoad()
    build_loadout_indexes()

    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_DIE'], 'OnDeath')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')

    OnStart() -- in case script is loaded mid-game
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    cache_weapon_datums()

    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnJoin(id)
    players[id] = player_data[id] or default_loadout_id
end

function OnSpawn(id) apply_loadout(id) end

function OnDeath(id)
    if show_loadouts_on_death then show_available_loadouts(id) end
end

function OnQuit(id) players[id] = nil end

function OnScriptUnload() end