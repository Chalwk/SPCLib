# SAPP Blank Script Template

Every SAPP Lua script **must** set `api_version` and define `OnScriptLoad()`. Without `OnScriptLoad()`, SAPP will not
load the script.

```lua
api_version = "1.12.0.0" -- Required: matches server's Lua API version

function OnScriptLoad()
    -- Register your callbacks here
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
    register_callback(cb['EVENT_BETRAY'], "OnBetray") -- team kill
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

function OnScriptUnload()
    -- Cleanup code (optional)
end

-- Optional error handler
function OnError(Message)
    -- Called when a Lua error occurs in your script
end
```

---

## Callback Functions – Correct Signatures

Your callback functions **must** accept parameters in the exact order shown below.
You may omit parameters you don't need, but if you include them, the order must match.

> **Note:** Some parameters are provided as **strings** (e.g., `Causer`, `VictimIndex`). Use `tonumber()` if you need
> numeric values.

### `EVENT_ECHO`

Called when `execute_command(..., true)` echoes output.

```lua
function OnEcho(PlayerIndex, Message)
    -- PlayerIndex : number
    -- Message     : string
end
```

### `EVENT_OBJECT_SPAWN`

Called when the server attempts to spawn an object. Return `false` to block, or `true, newTagID` to change the object
type.

```lua
function OnObjectSpawn(PlayerIndex, TagID, ParentObjectID, NewObjectID)
    -- PlayerIndex    : number (who spawned it, 0 if not a player)
    -- TagID          : number
    -- ParentObjectID : number (0xFFFFFFFF if none)
    -- NewObjectID    : number
    -- Return: optional boolean allow, optional number replacementTagID
end
```

### `EVENT_DIE`

A player dies. `Causer` is `"-1"` falling/distance/server, `"0"` for non-player (vehicle/AI), or a player index as a
string.

Called **AFTER** `EVENT_KILL`

```lua
function OnDie(PlayerIndex, Causer)
    -- PlayerIndex : number
    -- Causer      : string (e.g., "3" or "-1")
end
```

```lua
function OnDie(PlayerIndex, Causer)
    -- PlayerIndex : number (victim, 1-16)
    -- Causer      : string (e.g., "-1", "0", "5")
    local killer = tonumber(Causer)
    if killer == -1 then
        -- killed by the server / falling / team-switch
    elseif killer == 0 then
        -- killed by a vehicle
    elseif killer > 0 then
        -- killed by another player
    end
end
```

### `EVENT_PRESPAWN`

Called before a player spawns (players not yet notified). Useful for moving/rotating before spawn.

```lua
function OnPreSpawn(PlayerIndex)
end
```

### `EVENT_CUSTOM`

Triggered by the `cevent` command.

```lua
function OnCustom(PlayerIndex, EventName)
    -- PlayerIndex : number (or 0 if not player-triggered)
    -- EventName   : string
end
```

### `EVENT_WEAPON_PICKUP`

A player picks up a weapon or grenade. `WeaponSlot` is the weapon index; `WeaponType` is `"1"` (weapon) or `"2"` (
grenade).

```lua
function OnWeaponPickup(PlayerIndex, WeaponSlot, WeaponType)
    -- PlayerIndex : number
    -- WeaponSlot  : string
    -- WeaponType  : string
end
```

### `EVENT_ASSIST`

A player gets an assist.

```lua
function OnAssist(PlayerIndex)
end
```

### `EVENT_AREA_EXIT`

A player exits a custom area.

```lua
function OnAreaExit(PlayerIndex, Area)
    -- PlayerIndex : number
    -- Area        : string (area name)
end
```

### `EVENT_CHAT`

A player sends a chat message. Return `false` to block the message.

```lua
function OnChat(PlayerIndex, Message, Type)
    -- PlayerIndex : number
    -- Message     : string
    -- Type        : number (0=global, 1=team, 2=vehicle)
    -- Return: optional boolean allow
end
```

### `EVENT_SCORE`

A player scores a point.

```lua
function OnScore(PlayerIndex)
end
```

### `EVENT_VEHICLE_EXIT`

A player exits a vehicle.

```lua
function OnVehicleExit(PlayerIndex)
end
```

### `EVENT_TEAM_SWITCH`

A player changes teams.

```lua
function OnTeamSwitch(PlayerIndex)
end
```

### `EVENT_TICK`

Called every tick (1/30 second). Main game loop entry point.

```lua
function OnTick()
end
```

### `EVENT_ALIVE`

Called every second while a player is alive.

```lua
function OnAlive(PlayerIndex)
end
```

### `EVENT_BETRAY` (Team Kill)

A player kills a teammate.

```lua
function OnBetray(PlayerIndex, VictimIndex)
    -- PlayerIndex  : number (killer)
    -- VictimIndex  : string (victim's index)
end
```

### `EVENT_STICK`

A player is stuck by a plasma grenade or similar.

```lua
function OnStick(PlayerIndex, VictimIndex, Object, VictimObject, Where)
    -- PlayerIndex   : number (stuck player)
    -- VictimIndex   : number (usually same as PlayerIndex?)
    -- Object        : number (object ID of the sticky)
    -- VictimObject  : number (object ID of stuck object)
    -- Where         : number (body part index)
end
```

### `EVENT_LOGIN`

A name/password-based admin logs in.

```lua
function OnLogin(PlayerIndex)
end
```

### `EVENT_PREJOIN`

A player joins but before notification. Kicking here prevents join messages. `get_player()` is **not** yet valid.

```lua
function OnPreJoin(PlayerIndex)
end
```

### `EVENT_KILL`

A player kills another. Called **BEFORE** the `EVENT_DIE` has been processed.

```lua
function OnKill(PlayerIndex, VictimIndex)
    -- PlayerIndex  : number (killer)
    -- VictimIndex  : number (victim)
end
```

### `EVENT_GAME_START`

Called when a game begins.

```lua
function OnGameStart()
    -- NOTE: It's a good idea to cache data between map cycles. Do that here.
end
```

### `EVENT_DAMAGE_APPLICATION`

Damage is applied to a player. Return `false` to block all damage, or `true, newDamage` to modify the amount.

```lua
function OnDamageApplication(PlayerIndex, Causer, DamageTagID, Damage, CollisionMaterial, Backtap)
    -- PlayerIndex       : number (victim)
    -- Causer            : number (player index of attacker, or 0)
    -- DamageTagID       : number
    -- Damage            : number
    -- CollisionMaterial : string
    -- Backtap           : number
    -- Return: optional boolean allow, optional number newDamage
end
```

### `EVENT_MAP_RESET`

Called when `sv_map_reset` is executed.

```lua
function OnMapReset()
end
```

### `EVENT_SNAP`

A player snaps (aimbot detection) while `aimbot_ban` is enabled.

```lua
function OnSnap(PlayerIndex, SnapScore)
    -- PlayerIndex : number
    -- SnapScore   : string
end
```

### `EVENT_GAME_END`

Called when the game ends, before the post-game carnage report.

```lua
function OnGameEnd()
end
```

### `EVENT_SUICIDE`

A player kills themselves (e.g., grenade or rocket at their feet).

```lua
function OnSuicide(PlayerIndex)
    -- PlayerIndex : number
end
```

### `EVENT_COMMAND`

A player or console issues a command. Return `false` to block it.

```lua
function OnCommand(PlayerIndex, Command, Environment, RconPassword)
    -- PlayerIndex   : number (0 if from console)
    -- Command       : string
    -- Environment   : number (0=console, 1=rcon, 2=chat)
    -- RconPassword  : string (nil if not rcon)
    -- Return: optional boolean allow
end
```

### `EVENT_JOIN`

A player finishes joining. `get_player()` is valid now.

```lua
function OnJoin(PlayerIndex)
    -- PlayerIndex : number
end
```

### `EVENT_CAMP`

A camping player kills someone while `anticamp` is enabled.

```lua
function OnCamp(PlayerIndex)
    -- PlayerIndex : number
end
```

### `EVENT_SPAWN`

A player finishes spawning. Position/color changes may not be visible immediately.

```lua
function OnSpawn(PlayerIndex)
    -- PlayerIndex : number
end
```

### `EVENT_WARP`

A player warps too many times.

```lua
function OnWarp(PlayerIndex)
    -- PlayerIndex : number
end
```

### `EVENT_LEAVE`

A player disconnects.

```lua
function OnLeave(PlayerIndex)
    -- PlayerIndex : number
end
```

### `EVENT_WEAPON_DROP`

A player drops a weapon.

```lua
function OnWeaponDrop(PlayerIndex, WeaponSlot)
    -- PlayerIndex : number
    -- WeaponSlot  : string (which weapon slot)
end
```

### `EVENT_VEHICLE_ENTER`

A player enters a vehicle.

```lua
function OnVehicleEnter(PlayerIndex, SeatIndex)
    -- PlayerIndex : number
    -- SeatIndex   : string
end
```

### `EVENT_AREA_ENTER`

A player enters a custom area.

```lua
function OnAreaEnter(PlayerIndex, Area)
    -- PlayerIndex : number
    -- Area        : string
end
```