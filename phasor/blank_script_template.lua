-- TECHNICAL NOTE:
-- Phasor calls global functions by event name. Define only the events your script uses.
-- Player arguments are memory IDs (0-15). Server commands use RCON IDs (1-16), so
-- convert with resolveplayer() before building a command string.

--- Required. Without this, Phasor will not load the script.
---@return number version Required API version (must be 200)
function GetRequiredVersion() return 200 end

--- Required. Called when the script is loaded.
---@param process_id number The process ID of the server
---@param game string The game being played ("PC" or "CE")
---@param persistent boolean True if the script is persistent
function OnScriptLoad(process_id, game, persistent)
    -- Your initialization code here
end

--- Called when the script is unloaded (optional, but recommended).
function OnScriptUnload() end

--- Called when a new game is starting.
--- Look up all tags (via `gettagid`) here and cache them. Looking up tags
--- repeatedly is slow.
---@param map string The name of the map being loaded
function OnNewGame(map) end

--- Called when a game is ending.
--- `stage` values:
---     1 = The game has just ended (F1 screen)
---     2 = The post-game carnage report appears
---     3 = Players may quit
---@param stage number 1|2|3
function OnGameEnd(stage) end

--- Called when a player sends a chat message.
--- Return values:
---     true                        = allow the message
---     false                       = block the message
---     true, new_message           = allow and change the message
---     true, new_message, new_type = allow, change the message and its type
---@param player number The player's memory id
---@param chat_type number 0|1|2 (global, team, vehicle)
---@param message string The chat message
---@return boolean allow
---@return string|nil new_message
---@return number|nil new_type
function OnServerChat(player, chat_type, message) return true end

--- Called when a player executes a server command.
---@param player number The player's memory id
---@param command string The command being executed
---@return boolean|nil allow # Return `false` to block the command
function OnServerCommand(player, command) return true end

--- Called when a player without the correct password attempts to execute
--- a server command.
---@param player number The player's memory id
---@param command string The command being executed
---@param password string The password provided
---@return boolean|nil allow # Return `false` to block the command
function OnServerCommandAttempt(player, command, password) return true end

--- Called when a player requests a name during connection.
--- If `allow` is false, the player is kicked. If `new_name` is returned,
--- the player's name is changed.
---@param hash string The hash of the requesting machine
---@param name string The requested name
---@return boolean allow
---@return string|nil new_name
function OnNameRequest(hash, name) return true end

--- Called when a player attempts to join.
--- If `allow` is false, the player is banned.
---@param hash string The joining player's hash
---@param ip string The joining player's IP address
---@return boolean allow
function OnBanCheck(hash, ip) return true end

--- Called when a player successfully joins the game.
---@param player number The joining player's memory id
function OnPlayerJoin(player) end

--- Called when a player quits.
---@param player number The player who left
function OnPlayerLeave(player) end

--- Called when a player is killed.
--- `mode` values:
---     0 = Killed by server
---     1 = Fall damage
---     2 = Guardians
---     3 = Vehicle
---     4 = Killed by player
---     5 = Betrayal
---     6 = Suicide
---@param killer number|nil The killer's memory id, or nil if there is no killer
---@param victim number The victim's memory id
---@param mode number 0|1|2|3|4|5|6
function OnPlayerKill(killer, victim, mode) end

--- Called when a player gets a kill streak.
--- `multiplier` values:
---     7  = Double Kill
---     9  = Triple Kill
---     10 = Killtacular
---     11 = Killing Spree
---     12 = Running Riot
---     16 = Double Kill w/ Score
---     17 = Triple Kill w/ Score
---     18 = Killtacular w/ Score
---     19 = Killing Spree w/ Score
---     20 = Running Riot w/ Score
---@param player number The player's memory id
---@param multiplier number The kill streak value
function OnKillMultiplier(player, multiplier) end

--- Called when a player has spawned. Called BEFORE `OnPlayerSpawnEnd`.
---@param player number The player who is spawning
function OnPlayerSpawn(player) end

--- Called when the server has been notified of the player's spawn.
--- Position and color changes may not be visible immediately.
---@param player number The player who is spawning
function OnPlayerSpawnEnd(player) end

--- Called when an object is being assigned its spawn weapons.
--- Return a new weapon id to change the spawned weapon.
---@param player number The player's memory id
---@param object_id number The object id of the owner
---@param slot number The weapon slot
---@param weapon_id number The weapon's tag id
---@return number new_weapon_id
function OnWeaponAssignment(player, object_id, slot, weapon_id) return weapon_id end

--- Called when a weapon is reloaded.
---@param player number The player reloading
---@param weapon_id number The object id of the weapon being reloaded
---@return boolean|nil allow # Return `false` to block the reload
function OnWeaponReload(player, weapon_id) return true end

--- Called before an object is created.
--- Return `false` to block creation, or a new map id to change the object type.
---@param map_id number The tag id of the object being created
---@param parent_id number The object id of the parent
---@param player number The player's memory id, if the object belongs to a player
---@return boolean|number allow # `false` blocks, a number replaces the tag id
function OnObjectCreationAttempt(map_id, parent_id, player) return true end

--- Called when an object has just been created.
---@param object_id number The newly created object id
function OnObjectCreation(object_id) end

--- Called when a player interacts with an object.
---@param player number The interacting player
---@param object_id number The object being interacted with
---@param map_id number The object's tag id
---@return boolean|nil allow # Return `false` to block the interaction
function OnObjectInteraction(player, object_id, map_id) return true end

--- Called when a player needs to be assigned a team.
--- Team numbers: 0 = Red, 1 = Blue
---@param team number The team the player would be assigned to
---@return number new_team
function OnTeamDecision(team) return team end

--- Called when a player changes team.
---@param player number The player's memory id
---@param old_team number The player's old team
---@param new_team number The player's new team
---@param voluntary boolean Whether the player changed voluntarily
---@return boolean|nil allow # Return `false` to prevent the team change
function OnTeamChange(player, old_team, new_team, voluntary) return true end

--- Called before damage is applied.
--- Use this to configure damage modifications via `odl_` functions.
---@param receiver number The receiving object id
---@param causer number The causing object id
---@param map_id number The damage tag id
---@return boolean|nil allow
function OnDamageLookup(receiver, causer, map_id) return true end

--- Called when damage is being applied.
--- Return `false` to block the damage, or a new damage value to override it.
---@param receiver number The receiving object id
---@param causer number The causing object id
---@param map_id number The damage tag id
---@param location number The body part hit
---@param backtap boolean Whether the hit was a backtap
---@return boolean allow
---@return number|nil new_damage
function OnDamageApplication(receiver, causer, map_id, location, backtap) return true end

--- Called when a player attempts to enter a vehicle.
---@param player number The player's memory id
---@param vehicle_id number The vehicle object id
---@param seat number The seat index
---@param map_id number The vehicle tag id
---@param voluntary boolean Whether the player is entering voluntarily
---@return boolean|nil allow # Return `false` to prevent entry
function OnVehicleEntry(player, vehicle_id, seat, map_id, voluntary) return true end

--- Called when a player leaves a vehicle.
---@param player number The player's memory id
---@param voluntary boolean Whether the player is leaving voluntarily
---@return boolean|nil allow # Return `false` to prevent exiting
function OnVehicleEject(player, voluntary) return true end

--- Called when a client sends its update packet.
--- Runs 30 times per second for every player, so keep it light.
--- Receives the player's memory id, not their object id.
---@param player number The player's memory id
function OnClientUpdate(player) end