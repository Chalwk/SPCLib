---@meta
-- SAPP Lua API (api_version "1.12.0.0") for EmmyLua and lua-language-server.
-- Runtime is LuaJIT (Lua 5.1).
-- 
-- Copyright (c) 2026 Jericho Crosby (Chalwk).
-- 

---@alias HaloType "PC"|"CE"

--- Platform of the running server. Case sensitive.
---@type HaloType
halo_type = "PC"

--- Process ID of the server.
---@type integer
pid = 0

--- Lua API version of the loaded SAPP build.
---@type string
lua_api_version = ""

--- Loaded SAPP version.
---@type string
sapp_version = ""

---@alias SappEvent integer

--- Event ids for register_callback. Hover a field for the callback signature.
---@class SappCallbackIds
---@field EVENT_ALIVE SappEvent OnAlive(player_id). Once per second while a player is alive.
---@field EVENT_AREA_ENTER SappEvent OnAreaEnter(player_id, area). Player enters a custom area.
---@field EVENT_AREA_EXIT SappEvent OnAreaExit(player_id, area). Player exits a custom area.
---@field EVENT_ASSIST SappEvent OnAssist(player_id). Player gets an assist.
---@field EVENT_BETRAY SappEvent OnBetray(killer_id, victim_id). Player kills a teammate.
---@field EVENT_CAMP SappEvent OnCamp(player_id). Anti-camp triggers.
---@field EVENT_CHAT SappEvent OnChat(player_id, message, chat_type): boolean|nil. Return false to block. chat_type 0 global, 1 team, 2 vehicle.
---@field EVENT_COMMAND SappEvent OnCommand(executor_id, command, environment, rcon_password): boolean|nil. Return false to block. environment 0 console, 1 rcon, 2 chat.
---@field EVENT_CUSTOM SappEvent OnCustom(player_id, event_name). Raised by cevent.
---@field EVENT_DAMAGE_APPLICATION SappEvent OnDamageApplication(victim_id, causer_id, damage_tag_id, damage, collision_material, backtap): boolean|nil, number|nil. Return false to block, or true and a new damage value.
---@field EVENT_DIE SappEvent OnDie(victim_id, killer_id). killer_id is a string: -1 server/falling/distance, 0 non-player source, 1+ player. Called after EVENT_KILL.
---@field EVENT_ECHO SappEvent OnEcho(player_id, message). Output of execute_command(..., true).
---@field EVENT_GAME_END SappEvent OnGameEnd(). Before the post game carnage report.
---@field EVENT_GAME_START SappEvent OnGameStart(). A game begins.
---@field EVENT_JOIN SappEvent OnJoin(player_id). Player fully joined.
---@field EVENT_KILL SappEvent OnKill(killer_id, victim_id). Called before EVENT_DIE.
---@field EVENT_LEAVE SappEvent OnLeave(player_id). Player disconnected.
---@field EVENT_LOGIN SappEvent OnLogin(player_id). Admin logged in.
---@field EVENT_MAP_RESET SappEvent OnMapReset(). sv_map_reset was executed.
---@field EVENT_OBJECT_SPAWN SappEvent OnObjectSpawn(player_id, tag_id, parent_object_id, new_object_id, sapp_spawning): boolean|nil, number|nil. Return false to block, or true and a replacement tag id.
---@field EVENT_PREJOIN SappEvent OnPreJoin(player_id). get_player() is not valid yet.
---@field EVENT_PRESPAWN SappEvent OnPreSpawn(player_id). Before the player spawns.
---@field EVENT_SCORE SappEvent OnScore(player_id). Player scores a point.
---@field EVENT_SNAP SappEvent OnSnap(suspect_id, snap_score). Requires aimbot_ban.
---@field EVENT_SPAWN SappEvent OnSpawn(player_id). After the player spawned.
---@field EVENT_STICK SappEvent OnStick(player_id, victim_id, object_id, victim_object_id, body_part).
---@field EVENT_SUICIDE SappEvent OnSuicide(player_id).
---@field EVENT_TEAM_SWITCH SappEvent OnTeamSwitch(player_id).
---@field EVENT_TICK SappEvent OnTick(). Every tick (1/30 s).
---@field EVENT_VEHICLE_ENTER SappEvent OnVehicleEnter(player_id, seat_index). seat_index is a string.
---@field EVENT_VEHICLE_EXIT SappEvent OnVehicleExit(player_id).
---@field EVENT_WARP SappEvent OnWarp(player_id).
---@field EVENT_WEAPON_DROP SappEvent OnWeaponDrop(player_id, weapon_slot). weapon_slot is a string (0-3).
---@field EVENT_WEAPON_PICKUP SappEvent OnWeaponPickup(player_id, weapon_slot, weapon_type). Strings. weapon_type 1 weapon, 2 grenade.

---@type SappCallbackIds
cb = {}

--- Registers a global function as the handler for an event.
---@param event SappEvent
---@param callback_name string Name of a global function
function register_callback(event, callback_name) end

---@param event SappEvent
function unregister_callback(event) end

--- Variable names for get_var and set_var. Global variables use player id 0.
--- Custom variables made with add_var are also accepted.
---@alias SappVariable
---| "$afk" # (P: player) Seconds the player has been AFK
---| "$app" # (P: player) Bitfield: 1 SAPP, 2 Anticheat, 4 HAC2, 8 RefleX
---| "$area" # (E: event only) Area name for EVENT_AREA_ENTER / EVENT_AREA_EXIT
---| "$assists" # (P: player) Assist count
---| "$blues" # (G: global, use id 0) Players on blue team
---| "$bluescore" # (G: global, use id 0) Blue team score
---| "$botscore" # (P: player) Aimbot score
---| "$campkills" # (P: player) Kills while camping
---| "$combo" # (P: player) Current kill combo (resets after 4 s without a kill)
---| "$deaths" # (P: player) Deaths this game
---| "$ename" # (E: event only) Name passed to cevent for EVENT_CUSTOM
---| "$ffa" # (G: global, use id 0) 1 if FFA, 0 if teams
---| "$gt" # (G: global, use id 0) ctf, slayer, king, race, oddball, or n/a when no game is running
---| "$hash" # (P: player) CD-key hash
---| "$hp" # (P: player) Health as a decimal
---| "$index" # (E: event only) Weapon slot index for weapon drop/pickup
---| "$invis" # (P: player) 1 if active camo
---| "$ip" # (P: player) IP:Port
---| "$killed" # (E: event only) Victim player index for EVENT_KILL / EVENT_BETRAY
---| "$killer" # (E: event only) Killer player index for EVENT_DIE; -1 unknown, 0 AI/vehicle/world
---| "$kills" # (P: player) Kills this game
---| "$lvl" # (P: player) Admin level
---| "$map" # (G: global, use id 0) Loaded map
---| "$mode" # (G: global, use id 0) Game variant name
---| "$n" # (P: player) Player index
---| "$name" # (P: player) Player name
---| "$oteam" # (P: player) Opposite team name
---| "$ping" # (P: player) Ping in ms
---| "$pn" # (G: global, use id 0) Players on server (stale during EVENT_LEAVE, subtract 1)
---| "$rand" # (G: global, use id 0) Random number 1-16
---| "$reds" # (G: global, use id 0) Players on red team
---| "$redscore" # (G: global, use id 0) Red team score
---| "$running" # (G: global, use id 0) 1 if a game is running
---| "$score" # (P: player) Player score
---| "$sh" # (P: player) Shield as a decimal
---| "$snapscore" # (E: event only) Aimbot score from the snap for EVENT_SNAP
---| "$streak" # (P: player) Kills since last respawn
---| "$suicides" # (P: player) Suicides this game
---| "$svname" # (G: global, use id 0) Server name
---| "$team" # (P: player) red or blue
---| "$ticks" # (G: global, use id 0) Ticks since match start
---| "$tk" # (P: player) Team kills this game
---| "$type" # (E: event only) Picked-up type for EVENT_WEAPON_PICKUP: 1 weapon, 2 grenade
---| "$valid" # (P: player) Whether the CD key is valid
---| "$x" # (P: player) Player X coordinate
---| "$y" # (P: player) Player Y coordinate
---| "$z" # (P: player) Player Z coordinate

-- Variables --------------------------------------------------------------------------------

--- Always returns a string. Wrap in tonumber() for math.
---@param player_id integer 0 for global variables
---@param variable SappVariable|string
---@return string
function get_var(player_id, variable) end

--- Returns false if the variable is not defined.
---@param player_id integer
---@param name string Variable name without the leading "$"
---@param value any
---@param copy_id? integer
---@return boolean
function set_var(player_id, name, value, copy_id) end

--- Creates a custom variable. Types: 0 global str, 1 global int, 2 global float,
--- 3 player str, 4 player int, 5 player float.
---@param name string
---@param type 0|1|2|3|4|5
function add_var(name, type) end

---@param name string
function del_var(name) end

-- Memory -----------------------------------------------------------------------------------
-- A bad address crashes the server.

--- Reads an unsigned 8-bit integer.
---@param address integer
---@return integer
function read_byte(address) end

--- Reads a signed 8-bit integer.
---@param address integer
---@return integer
function read_char(address) end

--- Reads an unsigned 16-bit integer.
---@param address integer
---@return integer
function read_word(address) end

--- Reads a signed 16-bit integer.
---@param address integer
---@return integer
function read_short(address) end

--- Reads an unsigned 32-bit integer.
---@param address integer
---@return integer
function read_dword(address) end

--- Reads a signed 32-bit integer.
---@param address integer
---@return integer
function read_int(address) end

--- Reads a 32-bit float.
---@param address integer
---@return number
function read_float(address) end

--- Reads a 64-bit float.
---@param address integer
---@return number
function read_double(address) end

--- Writes an unsigned 8-bit integer.
---@param address integer
---@param value integer
function write_byte(address, value) end

--- Writes a signed 8-bit integer.
---@param address integer
---@param value integer
function write_char(address, value) end

--- Writes an unsigned 16-bit integer.
---@param address integer
---@param value integer
function write_word(address, value) end

--- Writes a signed 16-bit integer.
---@param address integer
---@param value integer
function write_short(address, value) end

--- Writes an unsigned 32-bit integer.
---@param address integer
---@param value integer
function write_dword(address, value) end

--- Writes a signed 32-bit integer.
---@param address integer
---@param value integer
function write_int(address, value) end

--- Writes a 32-bit float.
---@param address integer
---@param value number
function write_float(address, value) end

--- Writes a 64-bit float.
---@param address integer
---@param value number
function write_double(address, value) end

--- Reads a null-terminated 8-bit string. UTF-16LE fields (names) read as "", use a wide string helper.
---@param address integer
---@param length? integer
---@return string
function read_string(address, length) end

--- Writes a null-terminated 8-bit string.
---@param address integer
---@param value string
function write_string(address, value) end

---@param address integer
---@param bit integer Bit index
---@return integer bit 0 or 1
function read_bit(address, bit) end

---@param address integer
---@param bit integer Bit index
---@param value integer 0 or 1
function write_bit(address, bit, value) end

---@param address integer
---@return number x
---@return number y
---@return number z
function read_vector3d(address) end

---@param address integer
---@param x number
---@param y number
---@param z number
function write_vector3d(address, x, y, z) end

--- Toggles safe mode for reads. Costs performance, leave off unless needed.
---@param enabled boolean
function safe_read(enabled) end

--- Toggles safe mode for writes. Costs performance, leave off unless needed.
---@param enabled boolean
function safe_write(enabled) end

--- Finds a byte pattern ("??" is a wildcard). Returns the match address, or 0.
--- Guard against 0 before dereferencing.
---@param signature string
---@return integer address
function sig_scan(signature) end

-- Messaging --------------------------------------------------------------------------------

--- In-game chat, one player.
---@param player_id integer
---@param message string
function say(player_id, message) end

--- In-game chat, everyone.
---@param message string
function say_all(message) end

--- One player's console (~).
---@param player_id integer
---@param message string
function rprint(player_id, message) end

--- Server console only. color = foreground + (background * 16), each 0-15.
---@param message string
---@param color? integer
function cprint(message, color) end

-- Players and objects ----------------------------------------------------------------------

---@param player_id integer
---@return boolean
function player_present(player_id) end

---@param player_id integer
---@return boolean
function player_alive(player_id) end

--- Static player table address.
---@param player_id integer
---@return integer address
function get_player(player_id) end

--- Dynamic player object address, or 0 if the player is dead.
---@param player_id integer
---@return integer address
function get_dynamic_player(player_id) end

--- Object address, or 0 if the id is invalid.
---@param object_id integer
---@return integer address
function get_object_memory(object_id) end

--- SAPP index (1-16) to Halo index (0-15).
---@param player_index integer
---@return integer real_index
function to_real_index(player_index) end

--- Halo index (0-15) to SAPP index (1-16).
---@param real_index integer
---@return integer player_index
function to_player_index(real_index) end

--- Adds a death and applies the respawn time.
---@param player_id integer
function kill(player_id) end

--- Returns success. Silently fails if the player is dead or has 4 weapons.
---@param object_id integer
---@param player_id integer
---@return boolean
function assign_weapon(object_id, player_id) end

---@param player_id integer
function drop_weapon(player_id) end

---@param vehicle_id integer
---@param player_id integer
---@param seat string|integer
function enter_vehicle(vehicle_id, player_id, seat) end

---@param player_id integer
function exit_vehicle(player_id) end

--- No effect if the player is already camouflaged.
---@param player_id integer
---@param ticks integer
function camo(player_id, ticks) end

---@param object_id integer
---@param player_id integer
---@return boolean
function powerup_interact(object_id, player_id) end

--- Returns the object id (0 on failure). Pass "" for class and path when spawning by tag_id.
---@param tag_class string
---@param tag_path string
---@param x? number
---@param y? number
---@param z? number
---@param rotation? number Radians
---@param tag_id? integer Overrides tag_class and tag_path
---@return integer object_id
function spawn_object(tag_class, tag_path, x, y, z, rotation, tag_id) end

--- Spawns at a named location (see loc_add).
---@param tag_class string
---@param tag_path string
---@param location string
---@param rotation? number Radians
---@param tag_id? integer Overrides tag_class and tag_path
---@return integer object_id
function spawn_object_location(tag_class, tag_path, location, rotation, tag_id) end

---@param tag_id integer
---@param player_id integer Parent/owner
---@param x number
---@param y number
---@param z number
---@param rx? number Radians
---@param ry? number Radians
---@param rz? number Radians
---@return integer object_id
function spawn_projectile(tag_id, player_id, x, y, z, rx, ry, rz) end

--- Destroying flags, oddballs or non-SAPP vehicles may crash the server.
---@param object_id integer
function destroy_object(object_id) end

--- Syncs loaded and unloaded ammo.
---@param object_id integer
function sync_ammo(object_id) end

--- 3D raycast. The direction vector is multiplied by the reach in world units.
--- hit_object_id is 0xFFFFFFFF for map geometry or no hit.
---@param x number
---@param y number
---@param z number
---@param vx number
---@param vy number
---@param vz number
---@param ignore_object_id? integer
---@return boolean success
---@return number hit_x
---@return number hit_y
---@return number hit_z
---@return integer hit_object_id
function intersect(x, y, z, vx, vy, vz, ignore_object_id) end

--- Returns the tag address, or 0 if not found. Use the tag id form on protected maps.
---@overload fun(tag_id: integer): integer
---@param tag_class string Four-letter class, e.g. "weap"
---@param tag_name string
---@return integer address
function lookup_tag(tag_class, tag_name) end

-- Commands and timers ----------------------------------------------------------------------

--- player_id runs the command on a player's behalf. echo = true raises EVENT_ECHO with the output.
---@param command string
---@param player_id? integer
---@param echo? boolean
function execute_command(command, player_id, echo) end

--- Splits on ";". Use single-quoted Lua strings with double-quoted arguments.
---@param commands string
---@param player_id? integer
---@param echo? boolean
function execute_command_sequence(commands, player_id, echo) end

--- The upper bound is exclusive: rand(1, 4) returns 1-3.
---@param min? integer
---@param max? integer
---@return integer
function rand(min, max) end

--- Calls a global function once after delay ms. The callback returns true to repeat. Returns nil.
---@param delay integer Milliseconds
---@param callback_name string Name of a global function
---@param ... any Forwarded to the callback
function timer(delay, callback_name, ...) end
