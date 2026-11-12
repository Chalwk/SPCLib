---@meta
-- SAPP Lua API (api_version "1.12.0.0") for EmmyLua and lua-language-server.
-- Runtime is LuaJIT (Lua 5.1).
--
-- Copyright (c) 2026 Jericho Crosby (Chalwk).
--

---@alias HaloType "PC" | "CE"

--- Platform of the running server. Case sensitive.
---@type HaloType
halo_type = nil

--- Process ID of the server.
---@type number
pid = nil

--- Lua API version of the loaded SAPP build.
---@type string
lua_api_version = nil

--- Loaded SAPP version.
---@type string
sapp_version = nil

-- Script lifecycle -------------------------------------------------------------------------

---@alias SappApiVersion
--- | "1.12.0.0" # SAPP 10.2.1
--- | "1.11.0.0" # SAPP 10.2.0

--- Required. The script refuses to load without it.
--- Select the API version matching the SAPP release; typing the value offers known versions.
---@type SappApiVersion
api_version = nil

--- Required. Called once when the script is loaded. Register callbacks here.
function OnScriptLoad() end

--- Optional. Called once when the script is unloaded. Useful for cleanup.
--- Not registered with `register_callback`.
function OnScriptUnload() end

--- Optional. Called when a Lua error occurs in a script. Not registered
--- with `register_callback`.
---@param message string The Lua error message
function OnError(message) end

---@alias SappEvent number

--- Event ids for register_callback. Hover a field for the callback signature.
---@class SappCallbackIds
---@field EVENT_ALIVE              SappEvent OnAlive(player_id). Once per second while a player is alive.
---@field EVENT_AREA_ENTER         SappEvent OnAreaEnter(player_id, area). Player enters a custom area.
---@field EVENT_AREA_EXIT          SappEvent OnAreaExit(player_id, area). Player exits a custom area.
---@field EVENT_ASSIST             SappEvent OnAssist(player_id). Player gets an assist.
---@field EVENT_BETRAY             SappEvent OnBetray(killer_id, victim_id). victim_id is a string. Player kills a teammate.
---@field EVENT_CAMP               SappEvent OnCamp(player_id). Anti-camp triggers.
---@field EVENT_CHAT               SappEvent OnChat(player_id, message, chat_type): boolean|nil. Return false to block. chat_type 0 global, 1 team, 2 vehicle.
---@field EVENT_COMMAND            SappEvent OnCommand(executor_id, command, environment, rcon_password): boolean|nil. Return false to block. environment 0 console, 1 rcon, 2 chat.
---@field EVENT_CUSTOM             SappEvent OnCustom(player_id, event_name). Raised by cevent.
---@field EVENT_DAMAGE_APPLICATION SappEvent OnDamageApplication(victim_id, causer_id, damage_tag_id, damage, collision_material, backtap): boolean|nil, number|nil. collision_material is a string. Return false to block, or true and a new damage value.
---@field EVENT_DIE                SappEvent OnDie(victim_id, killer_id). killer_id is a string: -1 server/falling/distance, 0 non-player source, 1+ player. Called after EVENT_KILL.
---@field EVENT_ECHO               SappEvent OnEcho(player_id, message). Output of execute_command(..., true).
---@field EVENT_GAME_END           SappEvent OnGameEnd(). Before the post game carnage report.
---@field EVENT_GAME_START         SappEvent OnGameStart(). A game begins.
---@field EVENT_JOIN               SappEvent OnJoin(player_id). Player fully joined.
---@field EVENT_KILL               SappEvent OnKill(killer_id, victim_id). victim_id is a string. Called before EVENT_DIE.
---@field EVENT_LEAVE              SappEvent OnLeave(player_id). Player disconnected.
---@field EVENT_LOGIN              SappEvent OnLogin(player_id). Admin logged in.
---@field EVENT_MAP_RESET          SappEvent OnMapReset(). sv_map_reset was executed.
---@field EVENT_OBJECT_SPAWN       SappEvent OnObjectSpawn(player_id, tag_id, parent_object_id, new_object_id, sapp_spawning): boolean|nil, number|nil. Return false to block, or true and a replacement tag id.
---@field EVENT_PREJOIN            SappEvent OnPreJoin(player_id). get_player() is not valid yet.
---@field EVENT_PRESPAWN           SappEvent OnPreSpawn(player_id). Spawned but not yet announced; biped is valid.
---@field EVENT_SCORE              SappEvent OnScore(player_id). Player scores a point.
---@field EVENT_SNAP               SappEvent OnSnap(suspect_id, snap_score). snap_score is a string. Requires aimbot_ban.
---@field EVENT_SPAWN              SappEvent OnSpawn(player_id). After the player spawned.
---@field EVENT_STICK              SappEvent OnStick(player_id, victim_id, object_id, victim_object_id, body_part).
---@field EVENT_SUICIDE            SappEvent OnSuicide(player_id).
---@field EVENT_TEAM_SWITCH        SappEvent OnTeamSwitch(player_id).
---@field EVENT_TICK               SappEvent OnTick(). Every tick (1/30 s).
---@field EVENT_VEHICLE_ENTER      SappEvent OnVehicleEnter(player_id, seat_index). seat_index is a string.
---@field EVENT_VEHICLE_EXIT       SappEvent OnVehicleExit(player_id).
---@field EVENT_WARP               SappEvent OnWarp(player_id).
---@field EVENT_WEAPON_DROP        SappEvent OnWeaponDrop(player_id, weapon_slot). weapon_slot is a string (0-3).
---@field EVENT_WEAPON_PICKUP      SappEvent OnWeaponPickup(player_id, weapon_slot, weapon_type). Strings. weapon_type 1 weapon (weapon_slot 0-3), 2 grenade (weapon_slot 1 frag, 2 plasma).

---@alias SappCallbackName
--- | "OnAlive"
--- | "OnAreaEnter"
--- | "OnAreaExit"
--- | "OnAssist"
--- | "OnBetray"
--- | "OnCamp"
--- | "OnChat"
--- | "OnCommand"
--- | "OnCustom"
--- | "OnDamageApplication"
--- | "OnDie"
--- | "OnEcho"
--- | "OnGameEnd"
--- | "OnGameStart"
--- | "OnJoin"
--- | "OnKill"
--- | "OnLeave"
--- | "OnLogin"
--- | "OnMapReset"
--- | "OnObjectSpawn"
--- | "OnPreJoin"
--- | "OnPreSpawn"
--- | "OnScore"
--- | "OnSnap"
--- | "OnSpawn"
--- | "OnStick"
--- | "OnSuicide"
--- | "OnTeamSwitch"
--- | "OnTick"
--- | "OnVehicleEnter"
--- | "OnVehicleExit"
--- | "OnWarp"
--- | "OnWeaponDrop"
--- | "OnWeaponPickup"

---@type SappCallbackIds
cb = {}

--- Registers a global function as the handler for an event.
---@param event         SappEvent
---@param callback_name SappCallbackName Name of a global callback function
function register_callback(event, callback_name) end

---@param event SappEvent
function unregister_callback(event) end

--- Variable names for get_var and set_var. Global variables use player id 0.
--- Custom variables made with add_var are also accepted.
---@alias SappVariable
--- | "$afk"       # (P: player) Seconds the player has been AFK
--- | "$app"       # (P: player) Bitfield: 1 SAPP, 2 Anticheat, 4 HAC2, 8 RefleX
--- | "$area"      # (E: event only) Area name for EVENT_AREA_ENTER / EVENT_AREA_EXIT
--- | "$assists"   # (P: player) Assist count
--- | "$blues"     # (G: global, use id 0) Players on blue team
--- | "$bluescore" # (G: global, use id 0) Blue team score
--- | "$botscore"  # (P: player) Aimbot score
--- | "$campkills" # (P: player) Kills while camping
--- | "$combo"     # (P: player) Current kill combo (resets after 4 s without a kill)
--- | "$deaths"    # (P: player) Deaths this game
--- | "$ename"     # (E: event only) Name passed to cevent for EVENT_CUSTOM
--- | "$ffa"       # (G: global, use id 0) 1 if FFA, 0 if teams
--- | "$gt"        # (G: global, use id 0) ctf, slayer, king, race, oddball, or n/a when no game is running
--- | "$hash"      # (P: player) CD-key hash
--- | "$hp"        # (P: player) Health as a decimal
--- | "$index"     # (E: event only) Weapon slot index for weapon drop/pickup
--- | "$invis"     # (P: player) 1 if active camo
--- | "$ip"        # (P: player) IP:Port
--- | "$killed"    # (E: event only) Victim player index for EVENT_KILL / EVENT_BETRAY
--- | "$killer"    # (E: event only) Killer player index for EVENT_DIE; -1 unknown, 0 AI/vehicle/world
--- | "$kills"     # (P: player) Kills this game
--- | "$lvl"       # (P: player) Admin level
--- | "$map"       # (G: global, use id 0) Loaded map
--- | "$mode"      # (G: global, use id 0) Game variant name
--- | "$n"         # (P: player) Player index
--- | "$name"      # (P: player) Player name
--- | "$oteam"     # (P: player) Opposite team name
--- | "$ping"      # (P: player) Ping in ms
--- | "$pn"        # (G: global, use id 0) Players on server (stale during EVENT_LEAVE, subtract 1)
--- | "$rand"      # (G: global, use id 0) Random number 1-16
--- | "$reds"      # (G: global, use id 0) Players on red team
--- | "$redscore"  # (G: global, use id 0) Red team score
--- | "$running"   # (G: global, use id 0) 1 if a game is running
--- | "$score"     # (P: player) Player score
--- | "$sh"        # (P: player) Shield as a decimal
--- | "$snapscore" # (E: event only) Aimbot score from the snap for EVENT_SNAP
--- | "$streak"    # (P: player) Kills since last respawn
--- | "$suicides"  # (P: player) Suicides this game
--- | "$svname"    # (G: global, use id 0) Server name
--- | "$team"      # (P: player) red or blue
--- | "$ticks"     # (G: global, use id 0) Ticks since match start
--- | "$tk"        # (P: player) Team kills this game
--- | "$type"      # (E: event only) Picked-up type for EVENT_WEAPON_PICKUP: 1 weapon, 2 grenade
--- | "$valid"     # (P: player) Whether the CD key is valid
--- | "$x"         # (P: player) Player X coordinate
--- | "$y"         # (P: player) Player Y coordinate
--- | "$z"         # (P: player) Player Z coordinate

-- Variables --------------------------------------------------------------------------------

--- Always returns a string. Wrap in tonumber() for math.
---@param player_id number                0 for globals; 1-16 for players
---@param variable  SappVariable | string
---@return string
function get_var(player_id, variable) end

--- Returns false if the variable is not defined.
---@param player_id number 0 for globals; 1-16 for players
---@param name      string Variable name without the leading "$"
---@param value     string
---@param copy_id?  number
---@return boolean
function set_var(player_id, name, value, copy_id) end

--- Variable type ids for add_var.
---@alias SappVarType
--- | 0 # Global string
--- | 1 # Global integer
--- | 2 # Global float
--- | 3 # Player string
--- | 4 # Player integer
--- | 5 # Player float

--- Creates a custom variable.
---@param name string
---@param type SappVarType
function add_var(name, type) end

---@param name string
function del_var(name) end

-- Memory -----------------------------------------------------------------------------------
-- A bad address crashes the server.

--- Reads an unsigned 8-bit integer.
---@param address number
---@return number
function read_byte(address) end

--- Reads a signed 8-bit integer.
---@param address number
---@return number
function read_char(address) end

--- Reads an unsigned 16-bit integer.
---@param address number
---@return number
function read_word(address) end

--- Reads a signed 16-bit integer.
---@param address number
---@return number
function read_short(address) end

--- Reads an unsigned 32-bit integer.
---@param address number
---@return number
function read_dword(address) end

--- Reads a signed 32-bit integer.
---@param address number
---@return number
function read_int(address) end

--- Reads a 32-bit float.
---@param address number
---@return number
function read_float(address) end

--- Reads a 64-bit float.
---@param address number
---@return number
function read_double(address) end

--- Writes an unsigned 8-bit integer.
---@param address number
---@param value   number
function write_byte(address, value) end

--- Writes a signed 8-bit integer.
---@param address number
---@param value   number
function write_char(address, value) end

--- Writes an unsigned 16-bit integer.
---@param address number
---@param value   number
function write_word(address, value) end

--- Writes a signed 16-bit integer.
---@param address number
---@param value   number
function write_short(address, value) end

--- Writes an unsigned 32-bit integer.
---@param address number
---@param value   number
function write_dword(address, value) end

--- Writes a signed 32-bit integer.
---@param address number
---@param value   number
function write_int(address, value) end

--- Writes a 32-bit float.
---@param address number
---@param value   number
function write_float(address, value) end

--- Writes a 64-bit float.
---@param address number
---@param value   number
function write_double(address, value) end

--- Reads a null-terminated 8-bit string. UTF-16LE fields (names) read as "", use a wide string helper.
---@param address number
---@param length? number
---@return string
function read_string(address, length) end

--- Writes a null-terminated 8-bit string.
---@param address number
---@param value   string
function write_string(address, value) end

---@param address number
---@param bit     number Bit index
---@return number bit 0 or 1
function read_bit(address, bit) end

---@param address number
---@param bit     number Bit index
---@param value   number 0 or 1
function write_bit(address, bit, value) end

---@param address number
---@return number x
---@return number y
---@return number z
function read_vector3d(address) end

---@param address number
---@param x       number
---@param y       number
---@param z       number
function write_vector3d(address, x, y, z) end

--- Toggles safe mode for reads. Costs performance, leave off unless needed.
---@param enabled boolean
function safe_read(enabled) end

--- Toggles safe mode for writes. Costs performance, leave off unless needed.
---@param enabled boolean
function safe_write(enabled) end

--- Known signatures. The comment shows the pointer name and how to resolve it from the match.
--- slayer_globals is left out on purpose: its pattern embeds a CE address, use the hardcoded pointer.
---@alias SappSignature
--- | "A3??????00A1??????0033DB3BC3"                                                       # banlist_header: read_dword(sig + 1)
--- | "68??????00E8??????0083C41068"                                                       # banlist_path_address: read_dword(sig + 0x1)
--- | "CCCCC605??????0000E8??????0085C0"                                                   # banlist_path_address2: read_dword(sig + 0x4)
--- | "CCCCBA??????002BD08A08"                                                             # broadcast_game_address: read_dword(sig + 0x3)
--- | "751768??????0068??????00BA"                                                         # broadcast_version_address: read_dword(sig + 0x3)
--- | "741F8B482085C9750C"                                                                 # color_patch1: patch address, use sig as is
--- | "EB1F8B482085C9750C"                                                                 # color_patch2: patch address, use sig as is
--- | "68??????0068??????0068000401006A00"                                                 # computer_name_address: read_dword(sig + 0x1)
--- | "8B3C85????????3BF9741FE8????????8B8E2C0200008B4610"                                 # ctf_globals: read_dword(sig + 3)
--- | "A1????????8B480C894D00"                                                             # gameinfo_header: read_dword(sig + 0x1)
--- | "B9360000008BF3BF????????"                                                           # gametype_base (CE only): read_dword(sig + 0x8), PC needs the hardcoded 0x671320
--- | "BE??????008BC68B4DF064890D000000005F5E5B8BE55DC36A0C"                               # hardware_info_address: read_dword(sig + 0x1)
--- | "8B42348A8C28D500000084C9"                                                           # kill_message_address: read_dword(sig + 3)
--- | "BF??????00F3ABB96B000000"                                                           # koth_globals: read_dword(sig + 0x1)
--- | "740ABB????5C00E8????0300"                                                           # logfile_path_address (CE only): read_dword(sig + 0x3)
--- | "66A3??????00890D??????00C3"                                                         # map_name_address: read_dword(sig + 0x2)
--- | "B8??????00E8??????0032C983F813"                                                     # map_name_address2: read_dword(sig + 0x1)
--- | "F3ABA1????????BA????????C740??????????E8????????668B0D"                             # network_struct: read_dword(sig + 3)
--- | "8B??3883C404????74??57FFD0"                                                         # nonslayer_score_patch: patch address, sig + 0x8
--- | "8B0D????????8B513425FFFF00008D"                                                     # object_header_pointer: read_dword(sig + 2)
--- | "BF??????00F3ABB951000000"                                                           # oddball_globals: read_dword(sig + 0x1)
--- | "DDD8A1??????008944244835"                                                           # player_header_pointer: read_dword(sig + 0x3)
--- | "68??????008D54245468"                                                               # profile_path_address: read_dword(sig + 0x1)
--- | "BF??????00F3ABB952000000"                                                           # race_globals: read_dword(sig + 0x1)
--- | "B8????????E8??000000A1????????55"                                                   # rcon_failed_address: read_dword(sig + 1)
--- | "7740BA??????008D9B000000008A01"                                                     # rcon_password_address: read_dword(sig + 0x3)
--- | "BA??????008BC72BD78A08880C024084C975F68B442404"                                     # server_ip_argument: read_dword(sig + 0x1)
--- | "F3ABA3??????00A3??????00A2??????00C705"                                             # server_password_address: read_dword(sig + 0x3)
--- | "0000BE??????005657C605"                                                             # server_path_address: read_dword(sig + 0x3)
--- | "668B0D??????000BF2C605"                                                             # server_port_address: read_dword(sig + 0x3)
--- | "5733C0B910000000BFE8E05B00F3ABB910000000"                                           # slayer_globals (CE only): read_dword(sig + 19)
--- | "74178B94242808000052518B8C24280800005157FFD083C4108B8424240800003BF8530F94C383FFFF" # slayer_score_patch: patch address, use sig as is
--- | "33C0BF??????00F3AB881D"                                                             # stats_globals: read_dword(sig + 0x3)
--- | "8B510C6A018915????????E8????????83C404"                                             # sv_map_reset_tick_address: read_dword(sig + 7)
--- | "8B2D????????807D0000C644240600"                                                     # tick_counter_sig: read_dword(read_dword(sig + 2)) + 0xC
--- | "8B0D????????83C8FF85C97E17"                                                         # timelimit_address: read_dword(sig + 2)

--- Finds a byte pattern ("??" is a wildcard). Returns the match address, or 0.
--- Guard against 0 before dereferencing.
--- See [Signature Scanning](https://chalwk.github.io/halo/sapp/utils/#signature-scanning).
---@param signature string | SappSignature
---@return number address
function sig_scan(signature) end

-- Messaging --------------------------------------------------------------------------------

--- In-game chat, one player. Prefixes with `say_prefix` if set.
---@param player_id number
---@param message   string
function say(player_id, message) end

--- In-game chat, everyone. Prefixes with `say_prefix` if set.
---@param message string
function say_all(message) end

--- One player's console (~).
---@param player_id number
---@param message   string
function rprint(player_id, message) end

--- Prints to the dedicated server console only; players do not see this message in-game.
--- Optional color is a Windows console attribute: `foreground (0-15) + background (0-15) * 16`.
--- Example: green text on black:
--- ```lua
--- cprint("Hello", 10 + (0 * 16))
--- ```
--- See [Console Colors](https://chalwk.github.io/halo/sapp/cheat-sheet/#console-colors) for color values.
---@param message string
---@param color?  number Console color attribute (`0-255`); combines foreground and background colors.
function cprint(message, color) end

---@alias TagClass
--- | "weap" # Weapon
--- | "vehi" # Vehicle
--- | "eqip" # Equipment (powerups, grenades)
--- | "proj" # Projectile
--- | "bipd" # Biped
--- | "scen" # Scenery
--- | "mach" # Device machine
--- | "ctrl" # Device control
--- | "lifi" # Device light fixture
--- | "garb" # Garbage
--- | "plac" # Placeholder
--- | "ssce" # Sound scenery
--- | "jpt!" # Damage effect
--- | "effe" # Effect
--- | "snd!" # Sound
--- | "bitm" # Bitmap
--- | "matg" # Globals
--- | "scnr" # Scenario

-- Players and objects ----------------------------------------------------------------------

--- Player indices are 1-16; 0 is reserved for global/server context where supported.
---@param player_id number
---@return boolean
function player_present(player_id) end

---@param player_id number
---@return boolean
function player_alive(player_id) end

--- Static player table address.
--- See [Players, Objects, and Actions](https://chalwk.github.io/halo/sapp/scripting-with-sapp/#players-objects-and-actions).
---@param player_id number
---@return number address
function get_player(player_id) end

--- Dynamic player object address, or 0 if the player is dead.
--- See [Players, Objects, and Actions](https://chalwk.github.io/halo/sapp/scripting-with-sapp/#players-objects-and-actions).
---@param player_id number
---@return number address
function get_dynamic_player(player_id) end

--- Object address, or 0 if the id is invalid.
--- See [Players, Objects, and Actions](https://chalwk.github.io/halo/sapp/scripting-with-sapp/#players-objects-and-actions).
---@param object_id number
---@return number address
function get_object_memory(object_id) end

--- SAPP index (1-16) to Halo index (0-15).
--- See [Index Conversion](https://chalwk.github.io/halo/sapp/utils/#index-conversion).
---@param player_index number
---@return number real_index
function to_real_index(player_index) end

--- Halo index (0-15) to SAPP index (1-16).
--- See [Index Conversion](https://chalwk.github.io/halo/sapp/utils/#index-conversion).
---@param real_index number
---@return number player_index
function to_player_index(real_index) end

--- Adds a death and applies the respawn time.
---@param player_id number
function kill(player_id) end

--- Returns success. Silently fails if the player is dead or has 4 weapons.
--- Example:
--- ```lua
--- local weapon = spawn_object("weap", "weapons\\pistol\\pistol", 0, 0, 0)
--- if weapon ~= 0 then assign_weapon(weapon, 1) end
--- ```
---@param object_id number
---@param player_id number
---@return boolean
function assign_weapon(object_id, player_id) end

---@param player_id number
function drop_weapon(player_id) end

---@param vehicle_id number
---@param player_id  number
---@param seat       string
function enter_vehicle(vehicle_id, player_id, seat) end

---@param player_id number
function exit_vehicle(player_id) end

--- No effect if the player is already camouflaged.
--- Example:
--- ```lua
--- camo(1, 300) -- 10 seconds
--- ```
---@param player_id number
---@param ticks     number
function camo(player_id, ticks) end

--- Assigns a powerup to the player.
--- Example:
--- ```lua
--- local powerup = spawn_object("eqip", "powerups\\active camouflage", 0, 0, 0)
--- if powerup ~= 0 then powerup_interact(powerup, 1) end
--- ```
---@param object_id number
---@param player_id number
---@return boolean
function powerup_interact(object_id, player_id) end

--- Returns the object id (0 on failure). Pass "" for class and path when spawning by tag_id.
--- Example:
--- ```lua
--- local object_id = spawn_object("weap", "weapons\\pistol\\pistol", 0, 0, 0)
--- ```
--- Example using a tag ID:
--- ```lua
--- local object_id = spawn_object("", "", 0, 0, 0, 0, tag_id)
--- ```
---@param tag_class TagClass | string
---@param tag_path  string
---@param x?        number
---@param y?        number
---@param z?        number
---@param rotation? number            Radians
---@param tag_id?   number            Overrides tag_class and tag_path
---@return number object_id
function spawn_object(tag_class, tag_path, x, y, z, rotation, tag_id) end

--- Spawns at a named location (see loc_add).
--- Example:
--- ```lua
--- local object_id = spawn_object_location("weap", "weapons\\pistol\\pistol", "my_location")
--- ```
--- Example using a tag ID:
--- ```lua
--- local object_id = spawn_object_location("", "", "my_location", 0, tag_id)
--- ```
---@param tag_class TagClass | string
---@param tag_path  string
---@param location  string
---@param rotation? number            Radians
---@param tag_id?   number            Overrides tag_class and tag_path
---@return number object_id
function spawn_object_location(tag_class, tag_path, location, rotation, tag_id) end

--- Example:
--- ```lua
--- local projectile = spawn_projectile(projectile_tag_id, 1, 0, 0, 0)
--- ```
--- Example with rotation:
--- ```lua
--- local projectile = spawn_projectile(projectile_tag_id, 1, 0, 0, 0, 0, 0, math.pi / 2)
--- ```
---@param tag_id    number
---@param player_id number Parent/owner
---@param x         number
---@param y         number
---@param z         number
---@param rx?       number Radians
---@param ry?       number Radians
---@param rz?       number Radians
---@return number object_id
function spawn_projectile(tag_id, player_id, x, y, z, rx, ry, rz) end

--- Destroying flags, oddballs or non-SAPP vehicles may crash the server.
---@param object_id number
function destroy_object(object_id) end

--- Syncs loaded and unloaded ammo.
---@param object_id number
function sync_ammo(object_id) end

--- 3D raycast. The direction vector is multiplied by the reach in world units.
--- See [Raycasting with intersect](https://chalwk.github.io/halo/sapp/utils/#raycasting-with-intersect).
---@param x                 number
---@param y                 number
---@param z                 number
---@param vx                number
---@param vy                number
---@param vz                number
---@param ignore_object_id? number
---@return boolean success
---@return number hit_x
---@return number hit_y
---@return number hit_z
---@return number hit_object_id 0xFFFFFFFF for map geometry or no hit
function intersect(x, y, z, vx, vy, vz, ignore_object_id) end

--- Returns the tag address, or 0 if not found. Use the tag id form on protected maps.
--- See [Players, Objects, and Actions](https://chalwk.github.io/halo/sapp/scripting-with-sapp/#players-objects-and-actions).
---@overload fun(tag_id: number): number
---@param tag_class TagClass | string Four-letter class, e.g. "weap"
---@param tag_name  string
---@return number address
function lookup_tag(tag_class, tag_name) end

-- Commands and timers ----------------------------------------------------------------------

--- player_id runs the command on a player's behalf. echo = true raises EVENT_ECHO with the output.
---@param command    string
---@param player_id? number
---@param echo?      boolean
function execute_command(command, player_id, echo) end

--- Splits on ";". Use single-quoted Lua strings with double-quoted arguments.
--- Example:
--- ```lua
--- execute_command_sequence('say_all "Hello world";god 1', true)
--- ```
---@param commands   string
---@param player_id? number
---@param echo?      boolean
function execute_command_sequence(commands, player_id, echo) end

--- The upper bound is exclusive: rand(1, 4) returns 1-3.
---@param min? number
---@param max? number
---@return number
function rand(min, max) end

--- Calls a global function once after delay ms. The callback returns true to repeat. Returns nil.
---@param delay         number Milliseconds
---@param callback_name string Name of a global function
---@param ...           any    Forwarded to the callback
function timer(delay, callback_name, ...) end
