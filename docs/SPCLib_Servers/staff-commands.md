# Staff Rank Hierarchy:

### 🏵️ Trial-Mod - Levels 1-2

As an entry-level staff rank, Trial-Mods have access to essential moderation commands to help maintain the server's
friendly environment.

### 🛠️ Moderator - Levels 3-4

Moderators have access to all Trial-Mod commands and additional tools for managing and resolving issues efficiently.

### ⚙️ Admin (Administrator) - Levels 5-6

Admins have access to all Moderator and Trial-Mod commands, along with advanced tools for server management and
behind-the-scenes operations.

### 👑 Senior Admin - Level 6+

The highest rank in the SPCLib hierarchy, Owners have access to all staff commands and are responsible for
overseeing the entire server.

---

# PRIMARY ADMIN COMMANDS:

Used for adding, removing, and managing Halo staff members, as well as handling player bans, mutes, and other
administrative tasks.

| Command                                                                                     | Description                                                         | Permission Level |
|---------------------------------------------------------------------------------------------|---------------------------------------------------------------------|------------------|
| **login** `<password>`                                                                      | Login with a password (username is your IGN)                        | **1**            |
| **logout**                                                                                  | Logout of the server                                                | **1**            |
| **admin_chat** `<1/0 (on/off)>`                                                             | Toggle admin chat on or off for yourself                            | **2**            |
| **change_password** `<old password>` `<"new password">`                                     | Change your own password                                            | **2**            |
| **ip_mute** `<player id>` `<flag (-y -mo -d -h -m -s -r "example reason")>`                 | Mute a player by IP                                                 | **3**            |
| **ip_unmute** `<ban id>`                                                                    | Unmute a player's IP                                                | **3**            |
| **ip_mutes** `<page>`                                                                       | List all muted players by IP                                        | **3**            |
| **hash_mute** `<player id>` `<flag (-y -mo -d -h -m -s -r "example reason")>`               | Mute a player by hash                                               | **3**            |
| **hash_unmute** `<ban id>`                                                                  | Unmute a player's hash                                              | **3**            |
| **hash_mutes** `<page>`                                                                     | List all muted players by hash                                      | **3**            |
| **spy** `<1/0 (on/off)>`                                                                    | Toggle command spy on or off for yourself                           | **3**            |
| **ip_alias** `<player/ip>` `<page>`                                                         | Lookup aliases by player id or ip                                   | **4**            |
| **hash_alias** `<player/hash>` `<page>`                                                     | Lookup aliases by player id or hash                                 | **4**            |
| **ip_ban** `<player id>` `<flag (-y -mo -d -h -m -s -r "example reason")>`                  | Ban a player by IP                                                  | **4**            |
| **ip_unban** `<ban id>`                                                                     | Unban a player's IP                                                 | **4**            |
| **ip_bans** `<page>`                                                                        | List all IP-bans                                                    | **4**            |
| **hash_admin_add** `<player id / -u "name">` `<-l level>` `<-h hash>`                       | Add player as a hash-admin                                          | **5**            |
| **hash_admin_delete** `<admin id>`                                                          | Remove player as a hash-admin                                       | **5**            |
| **hash_admins** `<page>`                                                                    | List all hash-admins                                                | **5**            |
| **ip_admin_add** `<player id / -u "name">` `<-l level>` `<-ip IP>`                          | Add player as an ip-admin                                           | **5**            | 
| **ip_admin_delete** `<admin id>`                                                            | Remove player as an ip-admin                                        | **5**            |
| **ip_admins** `<page>`                                                                      | List all ip-admins                                                  | **5**            |
| **hash_ban** `<player id>` `<flag (-y -mo -d -h -m -s -r "example reason")>`                | Ban a player by hash (requires confirmation if the hash is pirated) | **5**            |
| **hash_unban** `<ban id>`                                                                   | Unban a player's hash                                               | **5**            |
| **hash_bans** `<page>`                                                                      | List all hash-bans                                                  | **5**            |
| **name_ban** `<player id or name>`                                                          | Ban a players name by ID or name                                    | **5**            |
| **name_unban** `<ban id>`                                                                   | Unban a name                                                        | **5**            |
| **name_bans** `<page>`                                                                      | List all name bans                                                  | **5**            |
| **pw_admin_add** `<player id / -u "name">` `<-l level>` `<-p "password">`                   | Add player as a password-admin                                      | **5**            |
| **pw_admin_delete** `<admin id>`                                                            | Remove player as a password-admin                                   | **5**            |
| **pw_admins** `<page>`                                                                      | List all password-admins                                            | **5**            |
| **confirm**                                                                                 | Confirm admin delete                                                | **5**            |
| **change_level** `<player id>` `<type (hash/ip/password)>`                                  | Change player admin level                                           | **6**            |
| **change_admin_password** `<player id>` `<"new password">`                                  | Change another player's password                                    | **6**            |
| **level_add** `<level>`                                                                     | Add an admin level                                                  | **6**            |
| **level_delete** `<level>`                                                                  | Delete an admin level (requires confirmation)                       | **6**            |
| **disable_command** `<command>`                                                             | Disables a command                                                  | **6**            |
| **enable_command** `<command>`                                                              | Enables a command                                                   | **6**            |
| **set_command** `<command>` `<level>` `(opt 3rd arg: "true" to enable, "false" to disable)` | Add or set a new/existing command to a new level                    | **6**            |

# SECONDARY ADMIN COMMANDS:

Used for managing server settings, map rotations, kicking players, and other server-related tasks.

| Command                                                                                              | Description                                                                                                                       | Permission Level |
|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|------------------|
| clead `[milliseconds(0-999)]`                                                                        | Adjust player ping lead for no-lead mode.                                                                                         | 1                |
| info                                                                                                 | Display server name, player count, current map, and scrim mode status.                                                            | 1                |
| lead `[boolean]`                                                                                     | Enable or disable player lead compensation in no-lead mode.                                                                       | 1                |
| stats                                                                                                | Display player's kills, deaths, and kill/death ratio.                                                                             | 1                |
| stfu                                                                                                 | Mute messages from a specific player or block server-wide rcon messages.                                                          | 1                |
| sv_stats                                                                                             | Display server statistics such as query count, command count, games played, flags captured, kills, betrayals, suicides, and more. | 1                |
| unstfu                                                                                               | Unmute messages for a player or server-wide communication.                                                                        | 1                |
| whatsnext                                                                                            | Show the next game in the map cycle.                                                                                              | 1                |
| kdr `<player id>`                                                                                    | Show the kill/death ratio of a specified player.                                                                                  | 2                |
| mapcycle                                                                                             | Display the current map cycle list.                                                                                               | 2                |
| pl                                                                                                   | List all players and their respective details (e.g., team, score, and index).                                                     | 2                |
| say `<player id>` `[message]`                                                                        | Send a message to all players as the server.                                                                                      | 2                |
| afk `<player id>`                                                                                    | Mark the executing player as AFK, disabling their respawns.                                                                       | 3                |
| afks                                                                                                 | List all players marked as AFK.                                                                                                   | 3                |
| aimbot_scores                                                                                        | Display aimbot detection scores for all players.                                                                                  | 3                |
| k `<player id>` `[reason]`                                                                           | Kick a player from the server.                                                                                                    | 3                |
| skips                                                                                                | Show a list of players who voted to skip the current map or game.                                                                 | 3                |
| balance_teams                                                                                        | Balance teams based on player statistics.                                                                                         | 4                |
| inf `<player id>`                                                                                    | Show detailed player information, including CD-key hash, IP address, and index.                                                   | 4                |
| ip `<player id>`                                                                                     | Display the IP address of a specified player.                                                                                     | 4                |
| st `<player id>` `[red/blue]`                                                                        | Change the team of the player.                                                                                                    | 4                |
| tell `<player id>` `[message]`                                                                       | Send a private message to a specific player.                                                                                      | 4                |
| uptime                                                                                               | Display the server's and operating system's uptime.                                                                               | 4                |
| map `<map>` `<game type>`                                                                            | Load a specified map with an optional game variant.                                                                               | 5                |
| maplist                                                                                              | Show all maps available on the server.                                                                                            | 5                |
| about                                                                                                | Display the current version of SAPP running on the server.                                                                        | 6                |
| admin_prefix `[prefix]`                                                                              | Set or get the prefix for administrator messages.                                                                                 | 6                |
| afk_kick `[seconds(0 or 60-86400)]`                                                                  | Automatically kick players marked as AFK for a specified amount of time.                                                          | 6                |
| aimbot_ban `[score(0 or 5000-20000)]` `[ban type(=1, 0-4)]` `[ban length in minutes(=1440)]`         | Automatically ban or kick players detected as using an aimbot.                                                                    | 6                |
| ammo `<player id>` `<amount>` `[weapon index(=0, 0-5)]`                                              | Modify a player's ammo count.                                                                                                     | 6                |
| anticamp `[seconds(0 or 10+)]` `[world units(=5)]`                                                   | Automatically trigger events if a player kills while camping in a specific area.                                                  | 6                |
| anticaps `[boolean]`                                                                                 | Prevent players from using excessive capital letters in chat.                                                                     | 6                |
| anticheat `[boolean]`                                                                                | Enable or disable SAPP's anticheat functionality.                                                                                 | 6                |
| antiglitch `[boolean]`                                                                               | Kill players who leave the map's boundaries to exploit glitches.                                                                  | 6                |
| antihalofp `[boolean]`                                                                               | Temporarily ban players who attempt to join the server too frequently in a short period.                                          | 6                |
| antilagspawn `[boolean]`                                                                             | Prevent players from exploiting lag to spawn improperly.                                                                          | 6                |
| antispam `[boolean]`                                                                                 | Mute players who send too many chat messages in a short time.                                                                     | 6                |
| antiwar `[boolean]`                                                                                  | Detect and respond to players warping on the server.                                                                              | 6                |
| area_add_cuboid `<area name>` `<Ax>` `<Ay>` `<Az>` `<Bx>` `<By>` `<Bz>`                              | Add a cuboid-shaped custom area for events or restrictions.                                                                       | 6                |
| area_add_sphere `<area name>` `<x>` `<y>` `<z>` `<radius>`                                           | Add a sphere-shaped custom area for events or restrictions.                                                                       | 6                |
| area_del `<area name>`                                                                               | Remove a previously defined custom area.                                                                                          | 6                |
| area_list                                                                                            | Display all currently defined custom areas.                                                                                       | 6                |
| area_listall                                                                                         | List all defined areas, including their details and types.                                                                        | 6                |
| assists `<player id>` `[assists]`                                                                    | Show the number of assists for a player.                                                                                          | 6                |
| auto_update `[boolean]`                                                                              | Enable or disable automatic updates for SAPP.                                                                                     | 6                |
| ayy lmao                                                                                             | Easter egg command (specific to SAPP builds).                                                                                     | 6                |
| battery battery `<player id>` `<amount(%)>` `[weapon index(=0, 0-5)]`                                | Display the server machine's battery status, if applicable.                                                                       | 6                |
| beep `[hertz(=1000)]` `[milliseconds(=1000)]`                                                        | Play a beep sound on the server host.                                                                                             | 6                |
| block_all_objects `<player id>` `<block(0-1)>`                                                       | Block all objects from being spawned on the server.                                                                               | 6                |
| block_all_vehicles `<player id>` `<block(0-1)>`                                                      | Block all vehicles from being spawned or used.                                                                                    | 6                |
| block_object `<player id>` `<object name with path>`                                                 | Block a specific object from being spawned.                                                                                       | 6                |
| block_tc `[boolean]`                                                                                 | Prevent team changing during a match.                                                                                             | 6                |
| boost `<player id>`                                                                                  | Apply a speed boost to a player.                                                                                                  | 6                |
| camo `<player id>` `[duration(=0)]`                                                                  | Grant active camouflage to a player.                                                                                              | 6                |
| cevent `<event name>` `[player index(1-16)]`                                                         | Trigger a custom event manually.                                                                                                  | 6                |
| chat_console_echo `[boolean]`                                                                        | Toggle whether in-game chat is displayed in the server console.                                                                   | 6                |
| cmd_add `<command name>` `[#arguments]...` `<command sequence>` `[level(=4, -1-4)]`                  | Add a new custom command to the server.                                                                                           | 6                |
| cmd_del `<command name>`                                                                             | Delete an existing custom command.                                                                                                | 6                |
| cmdstart1 `[character]`                                                                              | Set the first prefix character for chat commands.                                                                                 | 6                |
| cmdstart2 `[character]`                                                                              | Set the second prefix character for chat commands.                                                                                | 6                |
| color `<player id>` `[color index]`                                                                  | Change the console color scheme.                                                                                                  | 6                |
| console_input `[boolean]`                                                                            | Enable or disable direct input into the server console.                                                                           | 6                |
| coord `<playe rid>`                                                                                  | Display the coordinates of a player.                                                                                              | 6                |
| cpu                                                                                                  | Display the server's CPU usage and related stats.                                                                                 | 6                |
| custom_sleep `[ms(0-33)]`                                                                            | Adjust the amount of time the server thread sleeps per cycle.                                                                     | 6                |
| d `<player id>`                                                                                      | Display detailed player information (e.g., coordinates, health, shield, weapon, vehicle).                                         | 6                |
| deaths `<player id>` `[deaths]`                                                                      | Show the number of deaths for a player.                                                                                           | 6                |
| debug_strings `[boolean]`                                                                            | Debug custom strings in the server console.                                                                                       | 6                |
| disable_all_objects `<team(0-2)>` `<disable(0-1)>`                                                   | Disable all objects currently active on the server.                                                                               | 6                |
| disable_all_vehicles `<team(0-2)>` `<disable(0-1)>`                                                  | Disable all vehicles currently active on the server.                                                                              | 6                |
| disable_backtap `[boolean]`                                                                          | Disable the backtap mechanic for melee attacks.                                                                                   | 6                |
| disable_object                                                                                       | Disable a specific object on the server.                                                                                          | 6                |
| disable_timer_offsets `[boolean]`                                                                    | Spawn items using fixed timers rather than arbitrary counters.                                                                    | 6                |
| disabled_objects                                                                                     | List all currently disabled objects.                                                                                              | 6                |
| dns `<dns string>`                                                                                   | Set the master server DNS address.                                                                                                | 6                |
| enable_object `<object id / object name with path>` `[team(0-2)]`                                    | Re-enable a previously disabled object.                                                                                           | 6                |
| eventdel `<event id>`                                                                                | Delete an existing custom event.                                                                                                  | 6                |
| events                                                                                               | List all custom events currently defined.                                                                                         | 6                |
| files                                                                                                | List all SAPP configuration files.                                                                                                | 6                |
| gamespeed `[game speed]`                                                                             | Adjust the game speed on the server.                                                                                              | 6                |
| god `<player id>` `[time]`                                                                           | Grant invulnerability to a player.                                                                                                | 6                |
| gravity `[value]`                                                                                    | Adjust gravity on the server.                                                                                                     | 6                |
| hill_timer `[seconds]`                                                                               | Set the time interval for hill changes in "Crazy King" game type.                                                                 | 6                |
| hp `<player id>` `[health]`                                                                          | Adjust or display a player's health points.                                                                                       | 6                |
| kill `<player id>`                                                                                   | Kill a specific player on the server.                                                                                             | 6                |
| kills `<player id>` `[kills]`                                                                        | Show or set the number of kills for a player.                                                                                     | 6                |
| lag `<player id>`                                                                                    | Simulate lag for a specific player.                                                                                               | 6                |
| loc_add `<location name>` `[x]` `[y]` `[z]`                                                          | Add a custom location marker on the map.                                                                                          | 6                |
| loc_del `<location name>`                                                                            | Remove a previously defined location marker.                                                                                      | 6                |
| loc_list                                                                                             | List all defined location markers.                                                                                                | 6                |
| loc_listall                                                                                          | List all defined locations with their details.                                                                                    | 6                |
| log `[boolean]`                                                                                      | Toggle logging of server events.                                                                                                  | 6                |
| log_name `[file name]`                                                                               | Set the name of the log file.                                                                                                     | 6                |
| log_note `<message>`                                                                                 | Add a note to the server log.                                                                                                     | 6                |
| log_rotation `[kb(0 or 1024+)]`                                                                      | Set the maximum size of the log file before rotation.                                                                             | 6                |
| lua `[boolean]`                                                                                      | Enable or disable Lua scripting for the server.                                                                                   | 6                |
| lua_api_v                                                                                            | Display the current version of the Lua API used by SAPP.                                                                          | 6                |
| lua_call `<script name>` `<function name>` `[arguments]...`                                          | Manually call a Lua script function.                                                                                              | 6                |
| lua_list                                                                                             | List all loaded Lua scripts.                                                                                                      | 6                |
| lua_load `<script name>`                                                                             | Load a Lua script file.                                                                                                           | 6                |
| lua_unload `<script name>`                                                                           | Unload a Lua script file.                                                                                                         | 6                |
| m `<player id>` `<x>` `<y>` `<z>`                                                                    | Display the current map and game mode.                                                                                            | 6                |
| mag `<player id>` `<amount>` `[weapon index(=0, 0-5)]`                                               | Adjust player weapon magazine count.                                                                                              | 6                |
| map_download `<map id>`                                                                              | Enable or disable map downloading for players.                                                                                    | 6                |
| map_load `<map name>`                                                                                | Load a specific map without a game variant.                                                                                       | 6                |
| map_next                                                                                             | Skip to the next map in the map cycle.                                                                                            | 6                |
| map_prev                                                                                             | Return to the previous map in the map cycle.                                                                                      | 6                |
| map_query `<part of map name(3+)>`                                                                   | Query the current map details.                                                                                                    | 6                |
| map_skip `[value(%, 0-100)]`                                                                         | Skip the current map in the map cycle based on player votes.                                                                      | 6                |
| map_spec `<mapcycle index>`                                                                          | Skip directly to a specific map in the map cycle.                                                                                 | 6                |
| mapcycle_add `<map>` `<gametype>` `[min players(=0, 0-16)]` `[max players(= 16, 0-16)]` `[position]` | Add a new map to the map cycle with optional player limits.                                                                       | 6                |
| mapcycle_begin                                                                                       | Start the map cycle from the beginning.                                                                                           | 6                |
| mapcycle_del `<mapcycle index>`                                                                      | Remove a map from the map cycle.                                                                                                  | 6                |
| mapvote `[boolean]`                                                                                  | Enable or disable map voting.                                                                                                     | 6                |
| mapvote_add `<map>` `<gametype>` `[min players(=0, 0-16)]` `[max players(= 16, 0-16)]` `[position]`  | Add a new map to the map voting options.                                                                                          | 6                |
| mapvote_begin                                                                                        | Start the map voting process.                                                                                                     | 6                |
| mapvote_del `<mapvote index>`                                                                        | Remove a map from the voting options.                                                                                             | 6                |
| mapvotes                                                                                             | List all current map voting options.                                                                                              | 6                |
| max_idle `[seconds]`                                                                                 | Set the maximum idle time before the map cycle restarts.                                                                          | 6                |
| max_votes `[votes to display(1+)]`                                                                   | Set the maximum number of map votes displayed per round.                                                                          | 6                |
| motd `<message>`                                                                                     | Set the message of the day for the server.                                                                                        | 6                |
| msg_prefix `[prefix]`                                                                                | Set the prefix for server messages.                                                                                               | 6                |
| mtv                                                                                                  | Enable or disable multi-team vehicle sharing.                                                                                     | 6                |
| nades `<player id>` `[amount]` `[type(=0, 0-2)]`                                                     | Adjust player grenade count.                                                                                                      | 6                |
| network_thread `[boolean]`                                                                           | Enable or disable the network thread.                                                                                             | 6                |
| no_lead `[boolean]`                                                                                  | Enable or disable no-lead aiming compensation.                                                                                    | 6                |
| object_sync_cleanup `[boolean]`                                                                      | Clean up unused objects in the server's memory.                                                                                   | 6                |
| packet_limit `[value(0 or 250+)]`                                                                    | Set the maximum allowed packets per second from an IP address.                                                                    | 6                |
| ping_kick `[ms(0 or 150-999)]`                                                                       | Kick players with pings exceeding a specified threshold.                                                                          | 6                |
| query_add `<key>` `<value>`                                                                          | Add a custom entry to the server's query packet.                                                                                  | 6                |
| query_del `<query name/index>`                                                                       | Remove an entry from the server's query packet.                                                                                   | 6                |
| query_list                                                                                           | List all custom entries in the query packet.                                                                                      | 6                |
| reload                                                                                               | Reload server configuration and scripts.                                                                                          | 6                |
| reload_gametypes                                                                                     | Reload all game variants in the savegames folder.                                                                                 | 6                |
| remote_console `[boolean]`                                                                           | Enable or disable the remote console feature.                                                                                     | 6                |
| remote_console_list                                                                                  | List all connected remote console clients.                                                                                        | 6                |
| remote_console_port `[port(1-65535)]`                                                                | Set the port for the remote console.                                                                                              | 6                |
| report `<message>`                                                                                   | Submit a player report with an optional message.                                                                                  | 6                |
| rprint `<player id>` `<message>`                                                                     | Print a message to the remote console.                                                                                            | 6                |
| s `<player id>` `[speed]`                                                                            | Ser the players speed.                                                                                                            | 6                |
| sapp_console `[boolean]`                                                                             | Enable or disable detailed console logs for the server.                                                                           | 6                |
| sapp_mapcycle `[boolean]`                                                                            | Enable or disable the SAPP map cycle.                                                                                             | 6                |
| sapp_rcon `[boolean]`                                                                                | Restrict rcon access to admins.                                                                                                   | 6                |
| save_respawn_time `[boolean]`                                                                        | Save player respawn times for consistency.                                                                                        | 6                |
| save_scores `[boolean]`                                                                              | Save player scores when they disconnect.                                                                                          | 6                |
| say_prefix `[boolean]`                                                                               | Enable or disable the **SERVER** prefix for server messages.                                                                      | 6                |
| score `<player id>` `[score]`                                                                        | Display the current score for all players.                                                                                        | 6                |
| scorelimit `<scorelimit>`                                                                            | Adjust the score limit for the current game.                                                                                      | 6                |
| scrim_mode `[boolean]`                                                                               | Enable or disable scrim mode, restricting naughty commands and Lua scripts.                                                       | 6                |
| set_ccolor `[color]`                                                                                 | Set the console text color.                                                                                                       | 6                |
| setcmd                                                                                               | Modify the name or permission level of an existing command.                                                                       | 6                |
| sh `<player id>` `[shield]`                                                                          | Display or adjust a player's shield value.                                                                                        | 6                |
| sj_level `[level(-1-5)]`                                                                             | Set the minimum admin level required to use HAC2's sightjacker feature.                                                           | 6                |
| spawn `<tag type>` `<tag name>` `<player id/location name, <x>,<y>,<z>>` `<rotation>`                | Spawn a player at a specific location.                                                                                            | 6                |
| spawn_protection `[seconds(0-10)]`                                                                   | Set the duration of spawn protection for players.                                                                                 | 6                |
| t `<player id>` `<location name / <x> <y> <z>>`                                                      | Send a team-only chat message.                                                                                                    | 6                |
| team_score `[team(0-2)]` `[score]`                                                                   | Display the total score for each team.                                                                                            | 6                |
| teamup                                                                                               | Group players into teams based on clan or party affiliation.                                                                      | 6                |
| text `<message>` `[color]`                                                                           | Send a text message to a player.                                                                                                  | 6                |
| timelimit `[minutes]`                                                                                | Adjust the time limit for the current game.                                                                                       | 6                |
| tp `<player id>` `<player id>`                                                                       | Teleport a player to a specific location.                                                                                         | 6                |
| unblock_object `<player id>` `<object name with path>`                                               | Re-enable a previously blocked object.                                                                                            | 6                |
| ungod `<player id>`                                                                                  | Remove invulnerability from a player.                                                                                             | 6                |
| unlag `<player id>                                                                                   | Disable lag simulation for a player.                                                                                              | 6                |
| unlock_console_log                                                                                   | Enable more detailed console logs for troubleshooting.                                                                            | 6                |
| usage `<command name>`                                                                               | Display usage details for a specific command.                                                                                     | 6                |
| v `[version string]`                                                                                 | View or modify the server's version string.                                                                                       | 6                |
| var_add `<name>` `<type(0-5)>`                                                                       | Add a custom variable for scripts or events.                                                                                      | 6                |
| var_conv `<name>`                                                                                    | Convert an integer variable to a float or vice versa.                                                                             | 6                |
| var_del `<name>`                                                                                     | Delete a custom variable.                                                                                                         | 6                |
| var_list `[custom]`                                                                                  | List all custom variables.                                                                                                        | 6                |
| var_set `<name>` `<value>` `[player index(=0, 0-16)]`                                                | Set the value of a custom variable.                                                                                               | 6                |
| vdel ` <player id>`                                                                                  | Delete a vehicle from the game.                                                                                                   | 6                |
| vdel_all                                                                                             | Delete all vehicles currently active in the game.                                                                                 | 6                |
| venter `<player id>` `[seat(=0)]`                                                                    | Trigger an event for a player entering a vehicle.                                                                                 | 6                |
| vexit `<player id>`                                                                                  | Trigger an event for a player exiting a vehicle.                                                                                  | 6                |
| wadd `<player id>`                                                                                   | Add a weapon to a player's inventory.                                                                                             | 6                |
| wdel `<player id>` `[weapon index(=5, 0-5)]`                                                         | Delete a weapon from a player's inventory.                                                                                        | 6                |
| wdrop `<player id>`                                                                                  | Drop a weapon from a player's inventory.                                                                                          | 6                |
| yeye                                                                                                 | Play an easter egg sound effect on the server.                                                                                    | 6                |
| zombies `[value(0-2)]`                                                                               | Enable or disable zombie medals in HAC2.                                                                                          | 6                |

# Ban Command Examples

- `/hash_ban` `1` `-y 1` `-mo 6` `-r "caught cheating"`
    - This will ban player 1 by hash for 1 year, 6 months with the reason "caught cheating".

- `/hash_ban` `1`
    - This will ban player 1 by hash permanently.

- `/ip_ban` `1` `-h 1` `-m 30` `-r "caught cheating"`
    - This will ban player 1 by IP for 1 hour, 30 minutes with the reason "caught cheating".

- `/ip_ban` `1`
    - This will ban player 1 by IP permanently.

- `/name_ban` `1` `-r "explicit name"`
    - This will blacklist player 1's name with the reason "explicit name".

- `/name_ban` `penis`
    - This will blacklist the name "penis".

- `/ip_mute` `1` `-m 10` `-r "spamming"`
    - This will text-ban player 1 by IP for 10 minutes with the reason "spamming".

- `/hash_mute` `1` `-d 5` `-r "constant swearing"`
    - This will text-ban player 1 by hash for 5 days with the reason "constant swearing".

---

### **TIP:**

The order of the flags <ins>doesn't matter</ins>, but the player ID <ins>must</ins> be the first argument.

---

### **Pirated Hashes:**

> Shared CD Key hashes are detected automatically.  
> If a player has a shared CD Key hash, the admin will be informed  
> and will have to confirm the ban by typing */confirm*.  
> Otherwise, the action will time out after 10 seconds.

---