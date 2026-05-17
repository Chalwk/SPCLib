# Phasor Blank Script Template

Every Phasor Lua script **must** define `GetRequiredVersion()` and set its return value to `200` and define
`OnScriptLoad()`. Without these, Phasor will not load the script.

```lua
function GetRequiredVersion() -- Required or script will not load
	return 200
end

function OnScriptLoad(processId, game, persistent) -- Required or script will not load
    -- processId : number (the process ID of the server)
    -- game      : number (the game being played: "PC", "CE")
    -- persistent: boolean - True if script is persistent 
end

function OnScriptUnload() -- If this is not present when you unload, you will get a Lua error
    -- Cleanup code (optional)
end

function OnNewGame(map)
    -- Called when a new game is starting
    -- map : string (the name of the map being loaded)
    -- Note: It's recommended to look up all tags (via gettagid) here
    --       and store them globally. Looking up tags by name is slow.
end

function OnGameEnd(stage)
    -- Called when a game is ending
    -- stage : number (the stage of the game ending)
    --   - 1: The game has just ended (F1 Screen)
    --   - 2: The post-game carnage report appears (PGCR Appears)
    --   - 3: Players may quit
end

function OnServerChat(player, type, message)
    -- Called when a player sends a chat message
    -- player  : number (the player's memory id)
    -- type    : number (0=global, 1=team, 2=vehicle)
    -- message : string (the chat message)
    -- Return: optional boolean allow, optional string newMessage, optional number newType
    -- Return true to allow the message, false to block it
end

function OnServerCommandAttempt(player, command, password)
	--return true
end

function OnServerCommandAttempt(player, command, password)
    -- Called when a player without the correct password is trying to execute a server command
    -- player   : number (the player's memory id)
    -- command  : string (the command being executed)
    -- password : string (the password provided)
    -- Return: optional boolean allow
end

function OnNameRequest(hash, name)
    -- Called when a player is requesting a certain name (during connection)
    -- hash : string (the hash of the requesting machine)
    -- name : string (the requested name)
    -- Return: optional boolean allow, optional string newName
    -- If allow is false, the player will be kicked.
    -- If newName is provided, the player's name will be changed to newName.
end

function OnBanCheck(hash, ip)
    -- Called when a player is attempting to join
    -- hash : string (the joining player's hash)
    -- ip   : string (the joining player's ip address)
    -- Return: optional boolean allow
    -- If allow is false, the player will be banned.
end

function OnPlayerJoin(player)
    -- Called when a player successfully joins the game
    -- player : number (the joining player's memory id)
end

function OnPlayerLeave(player)
    -- Called when a player quits
    -- player : number (the player who left)
end

function OnPlayerKill(killer, victim, mode)
    -- Called when a player is killed
    -- killer : number (the killer's memory id, or nil if no killer)
    -- victim : number (the victim's memory id)
    -- mode   : number (the kill mode)
    --   - 0: Killed by server
    --   - 1: Killed by fall damage
    --   - 2: Killed by guardians
    --   - 3: Killed by vehicle
    --   - 4: Killed by killer
    --   - 5: Betrayed by killer
    --   - 6: Suicide
end

function OnKillMultiplier(player, multiplier)
    -- Called when a player gets a kill streak
    -- player     : number (the player's memory id)
    -- multiplier : number (the kill streak multiplier)
    -- Multipliers:
    --   7: Double Kill
    --   9: Triple Kill
    --   10: Killtacular
    --   11: Killing Spree
    --   12: Running Riot
    --   16: Double Kill w/ Score
    --   17: Triple Kill w/ Score
    --   14: Killtacular w/ Score
    --   18: Killing Spree w/ Score
    --   17: Running Riot w/ Score
end

function OnPlayerSpawn(player)
    -- Called when a player has spawned
    -- player : number (the player who is spawning)
    -- Note: This is called before OnPlayerSpawnEnd.
end

function OnPlayerSpawnEnd(player)
    -- Called when the server has been notified on the player's spawn
    -- player : number (the player who is spawning)
    -- Note: Position/color changes may not be visible immediately.
end

function OnWeaponAssignment(player, objId, slot, weapId)
    -- Called when an object is being assigned their spawn weapons
    -- player : number (the player's memory id, if the weapons belong to a player)
    -- objId  : number (the object id of the owner)
    -- slot   : number (the weapon slot)
    -- weapId : number (the weapon's tag id)
    -- Return: optional number newWeapId
    -- If you return a new weapon id, the player will spawn with that weapon instead.
end

function OnWeaponReload(player, weapId)
    -- Called when a weapon is being reloaded
    -- player  : number (the player who is reloading)
    -- weapId  : number (the object id of the weapon being reloaded)
    -- Return: optional boolean allow
    -- Return true to allow the reload, false to block it.
end

function OnObjectCreationAttempt(mapId, parentId, player)
    -- Called when an object wants to be created
    -- mapId    : number (the tag id of the object being created)
    -- parentId : number (the object id of the parent)
    -- player   : number (the player's memory id, if the object belongs to a player)
    -- Return: optional number newMapId, optional boolean allow
    -- Return allow = false to block the object creation.
    -- Return a newMapId to change the object type.
end

function OnObjectCreation(objId)
    -- Called when an object has just been created
    -- objId : number (the object id of the newly created object)
    -- You can modify most object settings and have it sync.
end

function OnObjectInteraction(player, objId, mapId)
    -- Called when a player interacts with an object (e.g., stands on it)
    -- player : number (the player interacting with the object)
    -- objId  : number (the object being interacted with)
    -- mapId  : number (the tag id of the object)
    -- Return: optional boolean allow
    -- Return false to block the interaction.
end

function OnTeamDecision(team)
    -- Called when a player needs to be assigned a team
    -- team : number (the team the player would be assigned to)
    -- Return: optional number newTeam
    -- Return a new team number to change the player's team.
    -- Team numbers: 0 = Red, 1 = Blue
end

function OnTeamChange(player, old_team, new_team, voluntary)
    -- Called when a player has changed team
    -- player    : number (the player's memory id)
    -- old_team  : number (the player's old team)
    -- new_team  : number (the player's new team)
    -- voluntary : boolean (whether the player voluntarily changed teams)
    -- Return: optional boolean allow
    -- Return false to prevent the team change.
end

function OnDamageLookup(receiver, causer, mapId)
    -- Called before damage is applied
    -- receiver : number (the object id of the receiver)
    -- causer   : number (the object id of the causer)
    -- mapId    : number (the tag id of the damage)
    -- Return: optional boolean allow
    -- Use this to set up damage modifications via odl_ functions.
end

function OnDamageApplication(receiver, causer, mapId, location, backtap)
    -- Called when damage is being applied to an object
    -- receiver : number (the object id of the receiver)
    -- causer   : number (the object id of the causer)
    -- mapId    : number (the tag id of the damage)
    -- location : number (the body part hit)
    -- backtap  : boolean (whether the damage is a backtap)
    -- Return: optional boolean allow, optional number newDamage
    -- Return allow = false to block the damage entirely.
    -- Return newDamage to override the damage amount.
end

function OnVehicleEntry(player, vehiId, seat, mapId, voluntary)
    -- Called when a player is wanting to enter a vehicle
    -- player    : number (the player's memory id)
    -- vehiId    : number (the object id of the vehicle)
    -- seat      : number (the seat index)
    -- mapId     : number (the tag id of the vehicle)
    -- voluntary : boolean (whether the player is voluntarily entering)
    -- Return: optional boolean allow
    -- Return false to prevent the player from entering the vehicle.
end

function OnVehicleEject(player, voluntary)
    -- Called when a player is leaving a vehicle
    -- player    : number (the player's memory id)
    -- voluntary : boolean (whether the player is voluntarily leaving)
    -- Return: optional boolean allow
    -- Return false to prevent the player from leaving the vehicle.
end

function OnClientUpdate(player)
    -- Called when a client sends its update packet
    -- player : number (the player's memory id)
    -- Note: This function is called 30 times a second for every player.
    -- Use sparingly to avoid performance issues.
    -- OnClientUpdate only receives the player's memory id, not their object id.
end
```

---