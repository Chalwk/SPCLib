-- [!NOTE]
-- Some callback arguments are strings even though they represent numbers - this is not a typo.

---@type SappApiVersion
api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb.EVENT_ALIVE, "OnAlive")
    register_callback(cb.EVENT_AREA_ENTER, "OnAreaEnter")
    register_callback(cb.EVENT_AREA_EXIT, "OnAreaExit")
    register_callback(cb.EVENT_ASSIST, "OnAssist")
    register_callback(cb.EVENT_BETRAY, "OnBetray")
    register_callback(cb.EVENT_CAMP, "OnCamp")
    register_callback(cb.EVENT_CHAT, "OnChat")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_CUSTOM, "OnCustom")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")
    register_callback(cb.EVENT_DIE, "OnDie")
    register_callback(cb.EVENT_ECHO, "OnEcho")
    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_KILL, "OnKill")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_LOGIN, "OnLogin")
    register_callback(cb.EVENT_MAP_RESET, "OnMapReset")
    register_callback(cb.EVENT_OBJECT_SPAWN, "OnObjectSpawn")
    register_callback(cb.EVENT_PREJOIN, "OnPreJoin")
    register_callback(cb.EVENT_PRESPAWN, "OnPreSpawn")
    register_callback(cb.EVENT_SCORE, "OnScore")
    register_callback(cb.EVENT_SNAP, "OnSnap")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_STICK, "OnStick")
    register_callback(cb.EVENT_SUICIDE, "OnSuicide")
    register_callback(cb.EVENT_TEAM_SWITCH, "OnTeamSwitch")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_VEHICLE_ENTER, "OnVehicleEnter")
    register_callback(cb.EVENT_VEHICLE_EXIT, "OnVehicleExit")
    register_callback(cb.EVENT_WARP, "OnWarp")
    register_callback(cb.EVENT_WEAPON_DROP, "OnWeaponDrop")
    register_callback(cb.EVENT_WEAPON_PICKUP, "OnWeaponPickup")
end

-- Optional. Called when a Lua error occurs in a script. Not registered
-- with `register_callback`.
---@param message string The Lua error message
function OnError(message) end

-- `EVENT_ECHO`
-- Called when `execute_command(..., true)` echoes output.
---@param player_id number The player's index
---@param message   string The echoed message
function OnEcho(player_id, message) end

-- `EVENT_OBJECT_SPAWN`
-- Called when the server attempts to spawn an object.
---@param player_id        number The player who spawned it (0 if not a player)
---@param tag_id           number The object's tag id
---@param parent_object_id number Parent object id (`0xFFFFFFFF` if none)
---@param new_object_id    number The new object id
---@param sapp_spawning    number `1` if the object was spawned by SAPP, `0` if by Halo
---@return boolean | nil allow, number | nil new_tag_id # Return `false` to block spawn, or new tag ID if replacing object type (if allow is true)
function OnObjectSpawn(player_id, tag_id, parent_object_id, new_object_id, sapp_spawning)
    return true
    -- To replace the object type, return allow and the new tag ID:
    -- return true, new_tag_id
end

-- `EVENT_DIE`
-- Called when a player dies. Called AFTER `EVENT_KILL`.
---@param victim_id number The victim's player index
---@param killer_id string The killer source
function OnDie(victim_id, killer_id)
    -- `killer_id` values:
    --     "-1" = falling, server, or distance damage
    --     "0"  = non-player source (e.g. an unoccupied vehicle squashing a player)
    --     "1+" = player index
end

-- `EVENT_ASSIST`
-- Called when a player gets an assist.
---@param player_id number The player's index
function OnAssist(player_id) end

-- `EVENT_KILL`
-- Called when a player kills another player. Called BEFORE `EVENT_DIE`.
---@param killer_id number Killer index
---@param victim_id string Victim index
function OnKill(killer_id, victim_id) end

-- `EVENT_BETRAY`
-- Called when a player kills a teammate.
---@param killer_id number Killer index
---@param victim_id string Victim index
function OnBetray(killer_id, victim_id) end

-- `EVENT_SUICIDE`
-- Called when a player kills themselves.
---@param player_id number The player's index
function OnSuicide(player_id) end

-- `EVENT_STICK`
-- Called when a player is stuck by a plasma grenade or similar.
---@param player_id        number The stuck player's index
---@param victim_id        number Usually the same as player_id
---@param object_id        number Object id of sticky projectile
---@param victim_object_id number Object id of stuck object
---@param body_part        number Body part index
function OnStick(player_id, victim_id, object_id, victim_object_id, body_part) end

-- `EVENT_DAMAGE_APPLICATION`
-- Called when damage is applied to a player.
---@param victim_id          number Victim index
---@param causer_id          number Attacker player index, or 0
---@param damage_tag_id      number Damage tag id
---@param damage             number Damage amount
---@param collision_material string Material hit
---@param backtap            number 0|1 Whether the hit was a backtap (1 = true)
---@return boolean | nil allow, number | nil new_damage # Return `false` to block damage, or modified damage amount (if allow is true)
function OnDamageApplication(victim_id, causer_id, damage_tag_id, damage, collision_material, backtap)
    return true
    -- To modify the damage amount, return allow and the new damage value:
    -- return true, damage * 1.5
end

-- `EVENT_PREJOIN`
-- Called before a player fully joins. `get_player()` is NOT valid yet.
---@param player_id number The player's index
function OnPreJoin(player_id) end

-- `EVENT_JOIN`
-- Called after a player fully joins.
---@param player_id number The player's index
function OnJoin(player_id) end

-- `EVENT_LEAVE`
-- Called when a player disconnects.
---@param player_id number The player's index
function OnLeave(player_id) end

-- `EVENT_PRESPAWN`
-- Biped exists, spawn not yet announced; move/rotate or set armor color here.
---@param player_id number The player's index
function OnPreSpawn(player_id) end

-- `EVENT_SPAWN`
-- Called after a player finishes spawning.
---@param player_id number The player's index
function OnSpawn(player_id) end

-- `EVENT_CHAT`
-- Called when a player sends a chat message.
---@param player_id number The player's index
---@param message   string The chat message
---@param chat_type number 0|1|2 (global, team, vehicle)
---@return boolean | nil allow # Return `false` to block message
function OnChat(player_id, message, chat_type) end

-- `EVENT_COMMAND`
-- Called when a command is executed.
---@param executor_id   number       The executor's index
---@param command       string       The command being executed
---@param environment   number       0|1|2 (console, rcon, chat)
---@param rcon_password string | nil RCON password, if used
---@return boolean | nil allow # Return `false` to block the command
function OnCommand(executor_id, command, environment, rcon_password) end

-- `EVENT_LOGIN`
-- Called when an admin logs in.
---@param player_id number The admin player index
function OnLogin(player_id) end

-- `EVENT_CUSTOM`
-- Triggered by `cevent`.
---@param player_id  number 0 if not player-triggered
---@param event_name string The custom event name
function OnCustom(player_id, event_name) end

-- `EVENT_WEAPON_PICKUP`
-- Triggered when player picks up a weapon or grenade.
---@param player_id   number The player's index
---@param weapon_slot string Weapon slot (0-3, 0 = Slot 1) when `weapon_type` is `1`; grenade type (`1` = frag, `2` = plasma) when it is `2`
---@param weapon_type string `1` = weapon, `2` = grenade
function OnWeaponPickup(player_id, weapon_slot, weapon_type) end

-- `EVENT_WEAPON_DROP`
-- Called when a player drops a weapon.
---@param player_id   number The player's index
---@param weapon_slot string Weapon slot (0-3, 0 = Slot 1)
function OnWeaponDrop(player_id, weapon_slot) end

-- `EVENT_VEHICLE_ENTER`
-- Called when a player enters a vehicle.
---@param player_id  number The player's index
---@param seat_index string Vehicle seat index (varies by vehicle)
function OnVehicleEnter(player_id, seat_index)
    --     0 = Driver (all vehicles)
    --     Warthog/Rocket Hog: 1 = Passenger, 2 = Gunner
    --     Tank: 1-4 = Passenger seats
    --     Ghost/Turret/Banshee: Driver only (slot 0)
end

-- `EVENT_VEHICLE_EXIT`
-- Called when a player exits a vehicle.
---@param player_id number The player's index
function OnVehicleExit(player_id) end

-- `EVENT_AREA_ENTER`
-- Called when a player enters a custom area.
---@param player_id number The player's index
---@param area      string Area name
function OnAreaEnter(player_id, area) end

-- `EVENT_AREA_EXIT`
-- Called when a player exits a custom area.
---@param player_id number The player's index
---@param area      string Area name
function OnAreaExit(player_id, area) end

-- `EVENT_WARP`
-- Called when a player warps too many times.
---@param player_id number The player's index
function OnWarp(player_id) end

-- `EVENT_CAMP`
-- Called when anti-camp triggers.
---@param player_id number The player's index
function OnCamp(player_id) end

-- `EVENT_GAME_START`
-- Called when a game begins.
function OnGameStart() end

-- `EVENT_GAME_END`
-- Called when the game ends (before post game carnage report appears)
function OnGameEnd() end

-- `EVENT_MAP_RESET`
-- Called when sv_map_reset is executed.
function OnMapReset() end

-- `EVENT_SCORE`
-- Called when a player scores a point.
---@param player_id number The scoring player
function OnScore(player_id) end

-- `EVENT_TEAM_SWITCH`
-- Called when a player changes teams.
---@param player_id number The player who switched teams
function OnTeamSwitch(player_id) end

-- `EVENT_TICK`
-- Called every tick. Main game loop entry point. (1 tick = 1/30 s, about 33.3 ms)
function OnTick() end

-- `EVENT_ALIVE`
-- Called every second while a player is alive.
---@param player_id number The alive player
function OnAlive(player_id) end

-- `EVENT_SNAP`
-- Called when a player snaps while aimbot_ban is enabled.
---@param suspect_id number The suspect's index
---@param snap_score string The detected snap score
function OnSnap(suspect_id, snap_score) end

-- Optional. Called once when the script is unloaded. Useful for cleanup.
-- Not registered with `register_callback`.
function OnScriptUnload() end
