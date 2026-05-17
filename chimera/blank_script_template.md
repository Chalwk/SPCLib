# Chimera Blank Script Template

Every Chimera Lua script **must** define `clua_version` and set it the API-specific value (e.g. `2.056`). Without this,
the script will not load.

```lua
clua_version = 2.056
```

---

## Callback Functions

Your callback functions **must** accept parameters in the exact order shown below.  
You may omit parameters you don't need, but if you include them, the order must match.

### `OnNewGame`

Called when a new game is starting.  
**Note:** It's recommended to look up all tags (via `gettagid`) here and cache them - looking up tags regularly is slow.

```lua
function OnNewGame(map)
    -- map : string (the name of the map being loaded)
end
```

### `OnGameEnd`

Called when a game is ending.

```lua
function OnGameEnd(stage)
    -- stage : number
    --   - 1: The game has just ended (F1 Screen)
    --   - 2: The post-game carnage report appears (PGCR Appears)
    --   - 3: Players may quit
end
```

### `OnServerChat`

Called when a player sends a chat message.  
Return `true` to allow the message, `false` to block it. You may also return a new message and/or a new type.

```lua
function OnServerChat(player, type, message)
    -- player  : number (the player's memory id)
    -- type    : number (0=global, 1=team, 2=vehicle)
    -- message : string (the chat message)
    -- Return: optional boolean allow, optional string newMessage, optional number newType
end
```

### `OnServerCommand`

Called when a player executes a server command.

```lua
function OnServerCommand(player, command)
    -- player  : number (the player's memory id)
    -- command : string (the command being executed)
    -- Return: optional boolean allow
end
```

### `OnServerCommandAttempt`

Called when a player without the correct password is trying to execute a server command.

```lua
function OnServerCommandAttempt(player, command, password)
    -- player   : number (the player's memory id)
    -- command  : string (the command being executed)
    -- password : string (the password provided)
    -- Return: optional boolean allow
end
```

### `OnNameRequest`

Called when a player is requesting a certain name (during connection).  
If `allow` is `false`, the player will be kicked. If `newName` is provided, the player's name will be changed to that.

```lua
function OnNameRequest(hash, name)
    -- hash : string (the hash of the requesting machine)
    -- name : string (the requested name)
    -- Return: optional boolean allow, optional string newName
end
```

### `OnBanCheck`

Called when a player is attempting to join.  
If `allow` is `false`, the player will be banned.

```lua
function OnBanCheck(hash, ip)
    -- hash : string (the joining player's hash)
    -- ip   : string (the joining player's ip address)
    -- Return: optional boolean allow
end
```

### `OnPlayerJoin`

Called when a player successfully joins the game.

```lua
function OnPlayerJoin(player)
    -- player : number (the joining player's memory id)
end
```

### `OnPlayerLeave`

Called when a player quits.

```lua
function OnPlayerLeave(player)
    -- player : number (the player who left)
end
```

### `OnPlayerKill`

Called when a player is killed.

```lua
function OnPlayerKill(killer, victim, mode)
    -- killer : number (the killer's memory id, or nil if no killer)
    -- victim : number (the victim's memory id)
    -- mode   : number
    --   - 0: Killed by server
    --   - 1: Killed by fall damage
    --   - 2: Killed by guardians
    --   - 3: Killed by vehicle
    --   - 4: Killed by killer
    --   - 5: Betrayed by killer
    --   - 6: Suicide
end
```

### `OnKillMultiplier`

Called when a player gets a kill streak.

```lua
function OnKillMultiplier(player, multiplier)
    -- player     : number (the player's memory id)
    -- multiplier : number
    --   - 7:   Double Kill
    --   - 9:   Triple Kill
    --   - 10:  Killtacular
    --   - 11:  Killing Spree
    --   - 12:  Running Riot
    --   - 16:  Double Kill w/ Score
    --   - 17:  Triple Kill w/ Score
    --   - 14:  Killtacular w/ Score
    --   - 18:  Killing Spree w/ Score
    --   - 17:  Running Riot w/ Score
end
```

### `OnPlayerSpawn`

Called when a player has spawned.  
**Note:** Called before `OnPlayerSpawnEnd`.

```lua
function OnPlayerSpawn(player)
    -- player : number (the player who is spawning)
end
```

### `OnPlayerSpawnEnd`

Called when the server has been notified of the player's spawn.  
**Note:** Position/color changes may not be visible immediately.

```lua
function OnPlayerSpawnEnd(player)
    -- player : number (the player who is spawning)
end
```

### `OnWeaponAssignment`

Called when an object is being assigned its spawn weapons.  
Return a new weapon id to make the player spawn with that weapon instead.

```lua
function OnWeaponAssignment(player, objId, slot, weapId)
    -- player : number (the player's memory id, if the weapons belong to a player)
    -- objId  : number (the object id of the owner)
    -- slot   : number (the weapon slot)
    -- weapId : number (the weapon's tag id)
    -- Return: optional number newWeapId
end
```

### `OnWeaponReload`

Called when a weapon is being reloaded.  
Return `true` to allow the reload, `false` to block it.

```lua
function OnWeaponReload(player, weapId)
    -- player : number (the player who is reloading)
    -- weapId : number (the object id of the weapon being reloaded)
    -- Return: optional boolean allow
end
```

### `OnObjectCreationAttempt`

Called before an object is created.  
Return `allow = false` to block creation. Return a `newMapId` to change the object type.

```lua
function OnObjectCreationAttempt(mapId, parentId, player)
    -- mapId    : number (the tag id of the object being created)
    -- parentId : number (the object id of the parent)
    -- player   : number (the player's memory id, if the object belongs to a player)
    -- Return: optional number newMapId, optional boolean allow
end
```

### `OnObjectCreation`

Called when an object has just been created.  
You can modify most object settings and have them sync.

```lua
function OnObjectCreation(objId)
    -- objId : number (the object id of the newly created object)
end
```

### `OnObjectInteraction`

Called when a player interacts with an object (e.g., stands on it).  
Return `false` to block the interaction.

```lua
function OnObjectInteraction(player, objId, mapId)
    -- player : number (the player interacting with the object)
    -- objId  : number (the object being interacted with)
    -- mapId  : number (the tag id of the object)
    -- Return: optional boolean allow
end
```

### `OnTeamDecision`

Called when a player needs to be assigned a team.  
Return a new team number to change the player's team. Team numbers: `0` = Red, `1` = Blue.

```lua
function OnTeamDecision(team)
    -- team : number (the team the player would be assigned to)
    -- Return: optional number newTeam
end
```

### `OnTeamChange`

Called when a player has changed team.  
Return `false` to prevent the team change.

```lua
function OnTeamChange(player, old_team, new_team, voluntary)
    -- player    : number (the player's memory id)
    -- old_team  : number (the player's old team)
    -- new_team  : number (the player's new team)
    -- voluntary : boolean (whether the player voluntarily changed teams)
    -- Return: optional boolean allow
end
```

### `OnDamageLookup`

Called before damage is applied. Use this to set up damage modifications via `odl_` functions.

```lua
function OnDamageLookup(receiver, causer, mapId)
    -- receiver : number (the object id of the receiver)
    -- causer   : number (the object id of the causer)
    -- mapId    : number (the tag id of the damage)
    -- Return: optional boolean allow
end
```

### `OnDamageApplication`

Called when damage is being applied to an object.  
Return `allow = false` to block damage entirely. Return `newDamage` to override the damage amount.

```lua
function OnDamageApplication(receiver, causer, mapId, location, backtap)
    -- receiver : number (the object id of the receiver)
    -- causer   : number (the object id of the causer)
    -- mapId    : number (the tag id of the damage)
    -- location : number (the body part hit)
    -- backtap  : boolean (whether the damage is a backtap)
    -- Return: optional boolean allow, optional number newDamage
end
```

### `OnVehicleEntry`

Called when a player wants to enter a vehicle.  
Return `false` to prevent the player from entering.

```lua
function OnVehicleEntry(player, vehiId, seat, mapId, voluntary)
    -- player    : number (the player's memory id)
    -- vehiId    : number (the object id of the vehicle)
    -- seat      : number (the seat index)
    -- mapId     : number (the tag id of the vehicle)
    -- voluntary : boolean (whether the player is voluntarily entering)
    -- Return: optional boolean allow
end
```

### `OnVehicleEject`

Called when a player is leaving a vehicle.  
Return `false` to prevent the player from exiting.

```lua
function OnVehicleEject(player, voluntary)
    -- player    : number (the player's memory id)
    -- voluntary : boolean (whether the player is voluntarily leaving)
    -- Return: optional boolean allow
end
```

### `OnClientUpdate`

Called when a client sends its update packet.  
**Note:** This function is called 30 times a second for every player. Use sparingly to avoid performance issues.  
`OnClientUpdate` receives the player's memory id, not their object id.

```lua
function OnClientUpdate(player)
    -- player : number (the player's memory id)
end
```

---