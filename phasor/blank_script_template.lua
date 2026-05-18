--[[
    Phasor Blank Script Template

    Every Phasor Lua script must define both `GetRequiredVersion()`
    and `OnScriptLoad()`.

    `GetRequiredVersion()` must return `200`.

    Without these definitions, Phasor will not load the script.
]]

---@return number Required API version (200)
function GetRequiredVersion()
    return 200
end

--- Called when the script is loaded.
---@param processId  number  The process ID of the server.
---@param game       string  The game being played ("PC" or "CE").
---@param persistent boolean True if the script is persistent.
function OnScriptLoad(processId, game, persistent)
    -- Your initialization code here
end

--- Called when the script is unloaded (but recommended).
function OnScriptUnload()
    -- Cleanup code here
end

--- `OnNewGame`
-- Called when a new game is starting.
-- Note: It's recommended to look up all tags (via `gettagid`) here and cache
-- them - looking up tags regularly is slow.
---@param map string The name of the map being loaded.
function OnNewGame(map) end

--- `OnGameEnd`
-- Called when a game is ending.
---@param stage number
--- 1 = The game has just ended (F1 screen)
--- 2 = The post-game carnage report appears
--- 3 = Players may quit
function OnGameEnd(stage) end

--- `OnServerChat`
-- Called when a player sends a chat message.
-- Return:
-- true                = allow message
-- false               = block message
-- true, newMessage    = allow and change message
-- true, newMessage, newType = allow, change message and type
---@param player  number The player's memory id.
---@param type    number 0 = Global, 1 = Team, 2 = Vehicle
---@param message string The chat message.
---@return boolean allow
---@return string  newMessage
---@return number  newType
function OnServerChat(player, type, message) end

--- `OnServerCommand`
-- Called when a player executes a server command.
---@param player  number The player's memory id.
---@param command string The command being executed.
---@return boolean allow
function OnServerCommand(player, command) end

--- `OnServerCommandAttempt`
-- Called when a player without the correct password attempts to execute
-- a server command.
---@param player   number The player's memory id.
---@param command  string The command being executed.
---@param password string The password provided.
---@return boolean allow
function OnServerCommandAttempt(player, command, password) end

--- `OnNameRequest`
-- Called when a player requests a name during connection.
-- If allow is false, the player will be kicked.
-- If newName is provided, the player's name will be changed.
---@param hash string The hash of the requesting machine.
---@param name string The requested name.
---@return boolean allow
---@return string  newName
function OnNameRequest(hash, name) end

--- `OnBanCheck`
-- Called when a player attempts to join.
-- If allow is false, the player will be banned.
---@param hash string The joining player's hash.
---@param ip   string The joining player's IP address.
---@return boolean allow
function OnBanCheck(hash, ip) end

--- `OnPlayerJoin`
-- Called when a player successfully joins the game.
---@param player number The joining player's memory id.
function OnPlayerJoin(player) end

--- `OnPlayerLeave`
-- Called when a player quits.
---@param player number The player who left.
function OnPlayerLeave(player) end

--- `OnPlayerKill`
-- Called when a player is killed.
---@param killer number | nil The killer's memory id, or nil if no killer.
---@param victim number       The victim's memory id.
---@param mode   number
--- 0 = Killed by server
--- 1 = Fall damage
--- 2 = Guardians
--- 3 = Vehicle
--- 4 = Killed by player
--- 5 = Betrayal
--- 6 = Suicide
function OnPlayerKill(killer, victim, mode) end

--- `OnKillMultiplier`
-- Called when a player gets a kill streak.
---@param player     number The player's memory id.
---@param multiplier number
--- 7  = Double Kill
--- 9  = Triple Kill
--- 10 = Killtacular
--- 11 = Killing Spree
--- 12 = Running Riot
--- 16 = Double Kill w/ Score
--- 17 = Triple Kill w/ Score
--- 14 = Killtacular w/ Score
--- 18 = Killing Spree w/ Score
--- 17 = Running Riot w/ Score
function OnKillMultiplier(player, multiplier) end

--- `OnPlayerSpawn`
-- Called when a player has spawned.
-- Note: Called before `OnPlayerSpawnEnd`.
---@param player number The player who is spawning.
function OnPlayerSpawn(player) end

--- `OnPlayerSpawnEnd`
-- Called when the server has been notified of the player's spawn.
-- Note: Position/color changes may not be visible immediately.
---@param player number The player who is spawning.
function OnPlayerSpawnEnd(player) end

--- `OnWeaponAssignment`
-- Called when an object is being assigned its spawn weapons.
-- Return a new weapon id to change the spawned weapon.
---@param player number The player's memory id.
---@param objId  number The object id of the owner.
---@param slot   number The weapon slot.
---@param weapId number The weapon's tag id.
---@return number newWeapId
function OnWeaponAssignment(player, objId, slot, weapId) end

--- `OnWeaponReload`
-- Called when a weapon is reloaded.
-- Return true to allow reload, false to block.
---@param player number The player reloading.
---@param weapId number The object id of the weapon being reloaded.
---@return boolean allow
function OnWeaponReload(player, weapId) end

--- `OnObjectCreationAttempt`
-- Called before an object is created.
-- Return false to block creation, or a new mapId to change the object type.
---@param mapId    number The tag id of the object being created.
---@param parentId number The object id of the parent.
---@param player   number The player's memory id, if the object belongs to a player.
---@return number  newMapId
---@return boolean allow
function OnObjectCreationAttempt(mapId, parentId, player) end

--- `OnObjectCreation`
-- Called when an object has just been created.
---@param objId number The newly created object id.
function OnObjectCreation(objId) end

--- `OnObjectInteraction`
-- Called when a player interacts with an object.
-- Return false to block interaction.
---@param player number The interacting player.
---@param objId  number The object being interacted with.
---@param mapId  number The object's tag id.
---@return boolean allow
function OnObjectInteraction(player, objId, mapId) end

--- `OnTeamDecision`
-- Called when a player needs to be assigned a team.
-- Team Numbers: 0 = Red, 1 = Blue
---@param team number The team the player would be assigned to.
---@return number newTeam
function OnTeamDecision(team) end

--- `OnTeamChange`
-- Called when a player changes team.
-- Return false to prevent the team change.
---@param player    number  The player's memory id.
---@param old_team  number  The player's old team.
---@param new_team  number  The player's new team.
---@param voluntary boolean Whether the player changed voluntarily.
---@return boolean allow
function OnTeamChange(player, old_team, new_team, voluntary) end

--- `OnDamageLookup`
-- Called before damage is applied.
-- Use this to configure damage modifications via `odl_` functions.
---@param receiver number The receiving object id.
---@param causer   number The causing object id.
---@param mapId    number The damage tag id.
---@return boolean allow
function OnDamageLookup(receiver, causer, mapId) end

--- `OnDamageApplication`
-- Called when damage is being applied.
-- Return false to block damage, or a newDamage value to override.
---@param receiver number  The receiving object id.
---@param causer   number  The causing object id.
---@param mapId    number  The damage tag id.
---@param location number  The body part hit.
---@param backtap  boolean Whether the hit was a backtap.
---@return boolean allow
---@return number  newDamage
function OnDamageApplication(receiver, causer, mapId, location, backtap) end

--- `OnVehicleEntry`
-- Called when a player attempts to enter a vehicle.
-- Return false to prevent entry.
---@param player    number  The player's memory id.
---@param vehiId    number  The vehicle object id.
---@param seat      number  The seat index.
---@param mapId     number  The vehicle tag id.
---@param voluntary boolean Whether the player is entering voluntarily.
---@return boolean allow
function OnVehicleEntry(player, vehiId, seat, mapId, voluntary) end

--- `OnVehicleEject`
-- Called when a player leaves a vehicle.
-- Return false to prevent exiting.
---@param player    number  The player's memory id.
---@param voluntary boolean Whether the player is leaving voluntarily.
---@return boolean allow
function OnVehicleEject(player, voluntary) end

--- `OnClientUpdate`
-- Called when a client sends its update packet.
-- Note: This function is called 30 times per second for every player.
-- Use sparingly to avoid performance issues.
-- `OnClientUpdate` receives the player's memory id, not their object id.
---@param player number The player's memory id.
function OnClientUpdate(player) end
