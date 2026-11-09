-- TECHNICAL NOTE:
-- Some function arguments are strings, despite representing numerical values.
-- These are not typos.

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

--- Optional error handler.
--- Called when a Lua error occurs in a script.
---@param message string The Lua error message
function OnError(message) end

--- `EVENT_ECHO`
--- Called when `execute_command(..., true)` echoes output.
---@param PlayerIndex number The player's index
---@param Message string The echoed message
function OnEcho(PlayerIndex, Message) end

--- `EVENT_OBJECT_SPAWN`
--- Called when the server attempts to spawn an object.
---@param PlayerIndex number The player who spawned it (0 if not a player)
---@param TagID number The object's tag id
---@param ParentObjectID number Parent object id (`0xFFFFFFFF` if none)
---@param NewObjectID number The new object id
---@param SappSpawning number `1` if the object was spawned by SAPP, `0` if by Halo
---@return boolean|nil allow # Return `false` to block spawn
---@return number|nil newTagID # Return new tag ID if replacing object type (if allow is true)
function OnObjectSpawn(PlayerIndex, TagID, ParentObjectID, NewObjectID, SappSpawning) return true end

--- `EVENT_DIE`
--- Called when a player dies. Called AFTER `EVENT_KILL`.
--- `Causer` values:
--- 	"-1" = falling / server / distance
--- 	"0"  = non-player source (e.g. an unoccupied vehicle squashing a player)
--- 	"1+" = player index
---@param VictimIndex number The victim's player index
---@param KillerIndex string The killer source
function OnDie(VictimIndex, KillerIndex) end

--- `EVENT_ASSIST`
--- Called when a player gets an assist.
---@param PlayerIndex number The player's index
function OnAssist(PlayerIndex) end

--- `EVENT_KILL`
--- Called when a player kills another player. Called BEFORE `EVENT_DIE`.
---@param PlayerIndex number Killer index
---@param VictimIndex string Victim index
function OnKill(PlayerIndex, VictimIndex) end

--- `EVENT_BETRAY`
--- Called when a player kills a teammate.
---@param PlayerIndex number Killer index
---@param VictimIndex string Victim index
function OnBetray(PlayerIndex, VictimIndex) end

--- `EVENT_SUICIDE`
--- Called when a player kills themselves.
---@param PlayerIndex number The player's index
function OnSuicide(PlayerIndex) end

--- `EVENT_STICK`
--- Called when a player is stuck by a plasma grenade or similar.
---@param PlayerIndex number The stuck player's index
---@param VictimIndex number Usually the same as PlayerIndex
---@param Object number Object id of sticky projectile
---@param VictimObject number Object id of stuck object
---@param Where number Body part index
function OnStick(PlayerIndex, VictimIndex, Object, VictimObject, Where) end

--- `EVENT_DAMAGE_APPLICATION`
--- Called when damage is applied to a player.
---@param VictimIndex number Victim index
---@param CauserIndex number Attacker player index, or 0
---@param DamageTagID number Damage tag id
---@param Damage number Damage amount
---@param CollisionMaterial string Material hit
---@param Backtap number 0|1 Whether the hit was a backtap (1 = true)
---@return boolean|nil allow # Return `false` to block damage
---@return number|nil newDamage # Return modified damage amount (if allow is true)
function OnDamageApplication(VictimIndex, CauserIndex, DamageTagID, Damage, CollisionMaterial, Backtap)
    return true
    -- Example format 1.5x damage buff:
    -- return true, Damage * 1.5
end

--- `EVENT_PREJOIN`
--- Called before a player fully joins. `get_player()` is NOT valid yet.
---@param PlayerIndex number The player's index
function OnPreJoin(PlayerIndex) end

--- `EVENT_JOIN`
--- Called after a player fully joins.
---@param PlayerIndex number The player's index
function OnJoin(PlayerIndex) end

--- `EVENT_LEAVE`
--- Called when a player disconnects.
---@param PlayerIndex number The player's index
function OnLeave(PlayerIndex) end

--- `EVENT_PRESPAWN`
--- Called before a player spawns.
--- Move/rotate a player or change armor colour before spawn (i.e., custom spawns)
---@param PlayerIndex number The player's index
function OnPreSpawn(PlayerIndex) end

--- `EVENT_SPAWN`
--- Called after a player finishes spawning.
---@param PlayerIndex number The player's index
function OnSpawn(PlayerIndex) end

--- `EVENT_CHAT`
--- Called when a player sends a chat message.
---@param PlayerIndex number The player's index
---@param Message string The chat message
---@param Type number 0|1|2 (global, team, vehicle)
---@return boolean|nil allow # Return `false` to block message
function OnChat(PlayerIndex, Message, Type) end

--- `EVENT_COMMAND`
--- Called when a command is executed.
---@param ExecutorIndex number The executors's index
---@param Command string The command being executed
---@param Environment number 0|1|2 (console, rcon, chat)
---@param RconPassword string|nil RCON password, if used
---@return boolean|nil allow # Return `false` to block the command
function OnCommand(ExecutorIndex, Command, Environment, RconPassword) end

--- `EVENT_LOGIN`
--- Called when an admin logs in.
---@param PlayerIndex number The admin player index
function OnLogin(PlayerIndex) end

--- `EVENT_CUSTOM`
--- Triggered by `cevent`.
---@param PlayerIndex number 0 if not player-triggered
---@param EventName string The custom event name
function OnCustom(PlayerIndex, EventName) end

--- `EVENT_WEAPON_PICKUP`
--- Triggered when player picks up a weapon or grenade.
---@param PlayerIndex number The player's index
---@param WeaponSlot string 0 to 4 = weapon slot (0 = Slot 1, 3 = Slot 4); 1 = frag, 2 = plasma (grenades only)
---@param WeaponType string 1 = weapon, 2 = grenade
function OnWeaponPickup(PlayerIndex, WeaponSlot, WeaponType) end

--- `EVENT_WEAPON_DROP`
--- Called when a player drops a weapon.
---@param PlayerIndex number The player's index
---@param WeaponSlot string 0 to 3 = weapon slot index (0 = Slot 1, 3 = Slot 4)
function OnWeaponDrop(PlayerIndex, WeaponSlot) end

--- `EVENT_VEHICLE_ENTER`
--- Called when a player enters a vehicle.
---@param PlayerIndex number The player's index
---@param SeatIndex string Vehicle seat index (varies by vehicle):
---     0 = Driver (all vehicles)
---     Warthog/Rocket Hog: 1 = Passenger, 2 = Gunner
---     Tank: 1-4 = Passenger seats
---     Ghost/Turret/Banshee: Driver only (slot 0)
function OnVehicleEnter(PlayerIndex, SeatIndex) end

--- `EVENT_VEHICLE_EXIT`
--- Called when a player exits a vehicle.
---@param PlayerIndex number The player's index
function OnVehicleExit(PlayerIndex) end

--- `EVENT_AREA_ENTER`
--- Called when a player enters a custom area.
---@param PlayerIndex number The player's index
---@param Area string Area name
function OnAreaEnter(PlayerIndex, Area) end

--- `EVENT_AREA_EXIT`
--- Called when a player exits a custom area.
---@param PlayerIndex number The player's index
---@param Area string Area name
function OnAreaExit(PlayerIndex, Area) end

--- `EVENT_WARP`
--- Called when a player warps too many times.
---@param PlayerIndex number The player's index
function OnWarp(PlayerIndex) end

--- `EVENT_CAMP`
--- Called when anti-camp triggers.
---@param PlayerIndex number The player's index
function OnCamp(PlayerIndex) end

--- `EVENT_GAME_START`
--- Called when a game begins.
function OnGameStart() end

--- `EVENT_GAME_END`
--- Called when the game ends (before post game carnage report appears)
function OnGameEnd() end

--- `EVENT_MAP_RESET`
--- Called when sv_map_reset is executed.
function OnMapReset() end

--- `EVENT_SCORE`
--- Called when a player scores a point.
---@param PlayerIndex number The scoring player
function OnScore(PlayerIndex) end

--- `EVENT_TEAM_SWITCH`
--- Called when a player changes teams.
---@param PlayerIndex number The player who switched teams
function OnTeamSwitch(PlayerIndex) end

--- `EVENT_TICK`
--- Called every tick. Main game loop entry point. (1 tick = 1/30 s ~ 33.333 ms)
function OnTick() end

--- `EVENT_ALIVE`
--- Called every second while a player is alive.
---@param PlayerIndex number The alive player
function OnAlive(PlayerIndex) end

--- `EVENT_SNAP`
--- Called when a player snaps while aimbot_ban is enabled.
---@param SuspectIndex number The suspects's index
---@param SnapScore string The detected snap score
function OnSnap(SuspectIndex, SnapScore) end

--- Called when the script is unloaded (optional cleanup).
function OnScriptUnload() end