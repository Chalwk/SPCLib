--[[
    SAPP Blank Script Template

    Every SAPP Lua script must define both `api_version`
    and `OnScriptLoad()`.

    Set `api_version` to match your server's SAPP API version
    (for example: "1.12.0.0").

    Without these definitions, SAPP will not load the script.
]]

api_version = "1.12.0.0"

-- Required Functions

function OnScriptLoad()
    --
    -- Register your callbacks here
    --

    register_callback(cb['EVENT_ECHO'], "OnEcho")
    register_callback(cb['EVENT_OBJECT_SPAWN'], "OnObjectSpawn")
    register_callback(cb['EVENT_DIE'], "OnDie")
    register_callback(cb['EVENT_PRESPAWN'], "OnPreSpawn")
    register_callback(cb['EVENT_CUSTOM'], "OnCustom")
    register_callback(cb['EVENT_WEAPON_PICKUP'], "OnWeaponPickup")
    register_callback(cb['EVENT_ASSIST'], "OnAssist")
    register_callback(cb['EVENT_AREA_EXIT'], "OnAreaExit")
    register_callback(cb['EVENT_CHAT'], "OnChat")
    register_callback(cb['EVENT_SCORE'], "OnScore")
    register_callback(cb['EVENT_VEHICLE_EXIT'], "OnVehicleExit")
    register_callback(cb['EVENT_TEAM_SWITCH'], "OnTeamSwitch")
    register_callback(cb['EVENT_TICK'], "OnTick")
    register_callback(cb['EVENT_ALIVE'], "OnAlive")
    register_callback(cb['EVENT_BETRAY'], "OnBetray") -- Team kill
    register_callback(cb['EVENT_STICK'], "OnStick")
    register_callback(cb['EVENT_LOGIN'], "OnLogin")
    register_callback(cb['EVENT_PREJOIN'], "OnPreJoin")
    register_callback(cb['EVENT_KILL'], "OnKill")
    register_callback(cb['EVENT_GAME_START'], "OnGameStart")
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], "OnDamageApplication")
    register_callback(cb['EVENT_MAP_RESET'], "OnMapReset")
    register_callback(cb['EVENT_SNAP'], "OnSnap")
    register_callback(cb['EVENT_GAME_END'], "OnGameEnd")
    register_callback(cb['EVENT_SUICIDE'], "OnSuicide")
    register_callback(cb['EVENT_COMMAND'], "OnCommand")
    register_callback(cb['EVENT_JOIN'], "OnJoin")
    register_callback(cb['EVENT_CAMP'], "OnCamp")
    register_callback(cb['EVENT_SPAWN'], "OnSpawn")
    register_callback(cb['EVENT_WARP'], "OnWarp")
    register_callback(cb['EVENT_LEAVE'], "OnLeave")
    register_callback(cb['EVENT_WEAPON_DROP'], "OnWeaponDrop")
    register_callback(cb['EVENT_VEHICLE_ENTER'], "OnVehicleEnter")
    register_callback(cb['EVENT_AREA_ENTER'], "OnAreaEnter")
end

--- Called when the script is unloaded (optional cleanup).
function OnScriptUnload()
    -- Cleanup code (optional)
end

--- Optional error handler.
-- Called when a Lua error occurs in your script.
---@param message string The Lua error message
function OnError(message) end

--- `EVENT_ECHO`
-- Called when `execute_command(..., true)` echoes output.
---@param PlayerIndex number The player index
---@param Message     string The echoed message
function OnEcho(PlayerIndex, Message) end

--- `EVENT_OBJECT_SPAWN`
-- Called when the server attempts to spawn an object.
-- Return:
-- false          = block spawn
-- true, newTagID = replace object type
---@param PlayerIndex    number The player who spawned it (0 if not a player)
---@param TagID          number The object's tag id
---@param ParentObjectID number Parent object id (`0xFFFFFFFF` if none)
---@param NewObjectID    number The new object id
---@return boolean|nil   allow    (false to block)
---@return number|nil    newTagID (if allow is true)
function OnObjectSpawn(PlayerIndex, TagID, ParentObjectID, NewObjectID)
    return true
end

--- `EVENT_DIE`
-- Called when a player dies. Called AFTER `EVENT_KILL`.
-- `Causer` values:
-- "-1" = falling / server / distance
-- "0"  = non-player (vehicle / AI)
-- "1+" = player index as a string
---@param PlayerIndex number The victim's player index
---@param Causer      string The killer source as a string
function OnDie(PlayerIndex, Causer) end

--- `EVENT_ASSIST`
-- Called when a player gets an assist.
---@param PlayerIndex number The assisting player
function OnAssist(PlayerIndex) end

--- `EVENT_KILL`
-- Called when a player kills another player. Called BEFORE `EVENT_DIE`.
---@param PlayerIndex number Killer index
---@param VictimIndex number Victim index
function OnKill(PlayerIndex, VictimIndex) end

--- `EVENT_BETRAY`
-- Called when a player kills a teammate.
---@param PlayerIndex number Killer index
---@param VictimIndex string Victim index
function OnBetray(PlayerIndex, VictimIndex) end

--- `EVENT_SUICIDE`
-- Called when a player kills themselves.
---@param PlayerIndex number The player index
function OnSuicide(PlayerIndex) end

--- `EVENT_STICK`
-- Called when a player is stuck by a plasma grenade or similar.
---@param PlayerIndex  number The stuck player's index
---@param VictimIndex  number Usually the same as PlayerIndex
---@param Object       number Object id of sticky projectile
---@param VictimObject number Object id of stuck object
---@param Where        number Body part index
function OnStick(PlayerIndex, VictimIndex, Object, VictimObject, Where) end

--- `EVENT_DAMAGE_APPLICATION`
-- Called when damage is applied to a player.
-- Return:
-- false           = block damage
-- true, newDamage = modify damage amount
---@param PlayerIndex       number Victim index
---@param Causer            number Attacker player index, or 0
---@param DamageTagID       number Damage tag id
---@param Damage            number Damage amount
---@param CollisionMaterial string Material hit
---@param Backtap           number Whether the hit was a backtap
---@return boolean|nil      allow     (false to block damage)
---@return number|nil       newDamage (if allow is true)
function OnDamageApplication(PlayerIndex, Causer, DamageTagID, Damage, CollisionMaterial, Backtap) end

--- `EVENT_PREJOIN`
-- Called before a player fully joins. `get_player()` is NOT valid yet.
---@param PlayerIndex number The joining player
function OnPreJoin(PlayerIndex) end

--- `EVENT_JOIN`
-- Called after a player fully joins.
---@param PlayerIndex number The joining player
function OnJoin(PlayerIndex) end

--- `EVENT_LEAVE`
-- Called when a player disconnects.
---@param PlayerIndex number The leaving player
function OnLeave(PlayerIndex) end

--- `EVENT_PRESPAWN`
-- Called before a player spawns.
---@param PlayerIndex number The spawning player
function OnPreSpawn(PlayerIndex) end

--- `EVENT_SPAWN`
-- Called after a player finishes spawning.
---@param PlayerIndex number The spawning player
function OnSpawn(PlayerIndex) end

--- `EVENT_CHAT`
-- Called when a player sends a chat message.
-- Return false to block message.
---@param PlayerIndex number The player's index
---@param Message     string The chat message
---@param Type        number 0=Global, 1=Team, 2=Vehicle
---@return boolean|nil allow (false to block)
function OnChat(PlayerIndex, Message, Type) end

--- `EVENT_COMMAND`
-- Called when a player or console executes a command.
-- Return false to block command.
---@param PlayerIndex  number       0 if from console
---@param Command      string       The command being executed
---@param Environment  number       0=Console, 1=RCON, 2=Chat
---@param RconPassword string | nil RCON password if used
---@return boolean|nil allow (false to block)
function OnCommand(PlayerIndex, Command, Environment, RconPassword) end

--- `EVENT_LOGIN`
-- Called when an admin logs in.
---@param PlayerIndex number The admin player index
function OnLogin(PlayerIndex) end

--- `EVENT_CUSTOM`
-- Triggered by `cevent`.
---@param PlayerIndex number 0 if not player-triggered
---@param EventName   string The custom event name
function OnCustom(PlayerIndex, EventName) end

--- `EVENT_WEAPON_PICKUP`
-- Called when a player picks up a weapon or grenade.
---@param PlayerIndex number The player's index
---@param WeaponSlot  string Weapon slot index
---@param WeaponType  string "1" weapon, "2" grenade
function OnWeaponPickup(PlayerIndex, WeaponSlot, WeaponType) end

--- `EVENT_WEAPON_DROP`
-- Called when a player drops a weapon.
---@param PlayerIndex number The player's index
---@param WeaponSlot  string Weapon slot
function OnWeaponDrop(PlayerIndex, WeaponSlot) end

--- `EVENT_VEHICLE_ENTER`
-- Called when a player enters a vehicle.
---@param PlayerIndex number The player's index
---@param SeatIndex   string Seat index
function OnVehicleEnter(PlayerIndex, SeatIndex) end

--- `EVENT_VEHICLE_EXIT`
-- Called when a player exits a vehicle.
---@param PlayerIndex number The player's index
function OnVehicleExit(PlayerIndex) end

--- `EVENT_AREA_ENTER`
-- Called when a player enters a custom area.
---@param PlayerIndex number The player's index
---@param Area        string Area name
function OnAreaEnter(PlayerIndex, Area) end

--- `EVENT_AREA_EXIT`
-- Called when a player exits a custom area.
---@param PlayerIndex number The player's index
---@param Area        string Area name
function OnAreaExit(PlayerIndex, Area) end

--- `EVENT_WARP`
-- Called when a player warps too many times.
---@param PlayerIndex number The player's index
function OnWarp(PlayerIndex) end

--- `EVENT_CAMP`
-- Called when anti-camp triggers.
---@param PlayerIndex number The player's index
function OnCamp(PlayerIndex) end

--- `EVENT_GAME_START`
-- Called when a game begins.
function OnGameStart() end

--- `EVENT_GAME_END`
-- Called when the game ends before PGCR.
function OnGameEnd() end

--- `EVENT_MAP_RESET`
-- Called when sv_map_reset is executed.
function OnMapReset() end

--- `EVENT_SCORE`
-- Called when a player scores a point.
---@param PlayerIndex number The scoring player
function OnScore(PlayerIndex) end

--- `EVENT_TEAM_SWITCH`
-- Called when a player changes teams.
---@param PlayerIndex number The player who switched teams
function OnTeamSwitch(PlayerIndex) end

--- `EVENT_TICK`
-- Called every tick (30 times per second). Main game loop entry point.
function OnTick() end

--- `EVENT_ALIVE`
-- Called every second while a player is alive.
---@param PlayerIndex number The alive player
function OnAlive(PlayerIndex) end

--- `EVENT_SNAP`
-- Called when a player snaps while aimbot_ban is enabled.
---@param PlayerIndex number The player's index
---@param SnapScore   string The detected snap score
function OnSnap(PlayerIndex, SnapScore) end
