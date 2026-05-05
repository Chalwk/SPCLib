| NAME                     | DESC                                                                               |
|--------------------------|------------------------------------------------------------------------------------|
| EVENT_ECHO               | Called when a command executed with echo outputs a message.                        |
| EVENT_OBJECT_SPAWN       | Called when the server attempts to spawn an object; can be blocked.                |
| EVENT_DIE                | Called when a player dies, with cause info.                                        |
| EVENT_PRESPAWN           | Called just before a player's spawn is visible to others; allows modifications.    |
| EVENT_CUSTOM             | Called when the `event` command is used to raise a custom event.                   |
| EVENT_WEAPON_PICKUP      | Called when a player picks up a weapon or grenade.                                 |
| EVENT_ASSIST             | Called when a player earns an assist.                                              |
| EVENT_AREA_EXIT          | Called when a player leaves a custom defined area.                                 |
| EVENT_CHAT               | Called when a player sends a chat message; can be blocked.                         |
| EVENT_SCORE              | Called when a player scores.                                                       |
| EVENT_VEHICLE_EXIT       | Called when a player exits a vehicle.                                              |
| EVENT_TEAM_SWITCH        | Called when a player switches teams.                                               |
| EVENT_TICK               | Called every game tick (1/30 second).                                              |
| EVENT_ALIVE              | Called every second while a player is alive.                                       |
| EVENT_BETRAY             | Called when a player commits a team kill.                                          |
| EVENT_STICK              | Called when a player is stuck by a grenade or object.                              |
| EVENT_LOGIN              | Called when a name/password admin logs in successfully.                            |
| EVENT_PREJOIN            | Called when a player is joining but not yet announced; can be preemptively kicked. |
| EVENT_KILL               | Called when a player earns a kill.                                                 |
| EVENT_GAME_START         | Called when the match starts.                                                      |
| EVENT_DAMAGE_APPLICATION | Called before damage is applied to a player; damage can be modified or blocked.    |
| EVENT_MAP_RESET          | Called when the map is reset via `sv_map_reset`.                                   |
| EVENT_SNAP               | Called when a player triggers an aimbot snap detection.                            |
| EVENT_GAME_END           | Called when the game ends, before the post-game report.                            |
| EVENT_SUICIDE            | Called when a player suicides.                                                     |
| EVENT_COMMAND            | Called when any command is executed via console/rcon/chat; can be blocked.         |
| EVENT_JOIN               | Called after a player fully joins the server.                                      |
| EVENT_CAMP               | Called when a camping player gets a kill while anticamp is active.                 |
| EVENT_SPAWN              | Called after a player spawns, fully visible.                                       |
| EVENT_WARP               | Called when a player exceeds the warp limit set by antiwarp.                       |
| EVENT_LEAVE              | Called when a player leaves the server.                                            |
| EVENT_WEAPON_DROP        | Called when a player drops a weapon.                                               |
| EVENT_VEHICLE_ENTER      | Called when a player enters a vehicle.                                             |
| EVENT_AREA_ENTER         | Called when a player enters a custom defined area.                                 |