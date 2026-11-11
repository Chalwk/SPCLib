---@meta
-- Phasor 2.0 Lua API for EmmyLua and lua-language-server.
-- Runtime is Lua 5.2.
-- 
-- Copyright (c) 2026 Jericho Crosby (Chalwk).
-- 

---@alias PhasorGame "PC"|"CE"

-- Memory -----------------------------------------------------------------------------------

--- bit_offset is 0-7 and counted from data + data_offset.
---@param data integer
---@param data_offset integer
---@param bit_offset integer
---@return integer bit 0 or 1
function readbit(data, data_offset, bit_offset) end

---@param data_addr integer
---@param data_offset integer
---@param bit_offset integer
---@param bit integer 0 or 1
function writebit(data_addr, data_offset, bit_offset, bit) end

--- Reads an unsigned 8-bit integer.
---@param address integer
---@return integer
function readbyte(address) end

--- Reads a signed 8-bit integer.
---@param address integer
---@return integer
function readchar(address) end

--- Reads an unsigned 16-bit integer.
---@param address integer
---@return integer
function readword(address) end

--- Reads a signed 16-bit integer.
---@param address integer
---@return integer
function readshort(address) end

--- Reads an unsigned 32-bit integer.
---@param address integer
---@return integer
function readdword(address) end

--- Reads a signed 32-bit integer.
---@param address integer
---@return integer
function readint(address) end

--- Reads a 32-bit float.
---@param address integer
---@return number
function readfloat(address) end

--- Reads a 64-bit float.
---@param address integer
---@return number
function readdouble(address) end

--- Writes an unsigned 8-bit integer.
---@param address integer
---@param value integer
function writebyte(address, value) end

--- Writes a signed 8-bit integer.
---@param address integer
---@param value integer
function writechar(address, value) end

--- Writes an unsigned 16-bit integer.
---@param address integer
---@param value integer
function writeword(address, value) end

--- Writes a signed 16-bit integer.
---@param address integer
---@param value integer
function writeshort(address, value) end

--- Writes an unsigned 32-bit integer.
---@param address integer
---@param value integer
function writedword(address, value) end

--- Writes a signed 32-bit integer.
---@param address integer
---@param value integer
function writeint(address, value) end

--- Writes a 32-bit float.
---@param address integer
---@param value number
function writefloat(address, value) end

--- Writes a 64-bit float.
---@param address integer
---@param value number
function writedouble(address, value) end

---@param address integer
---@param length? integer
---@return string
function readstring(address, length) end

---@param address integer
---@param value string
---@param length? integer
function writestring(address, value, length) end

--- Converts UTF-16LE to ASCII for you.
---@param address integer
---@param length? integer
---@return string
function readwidestring(address, length) end

---@param address integer
---@param value string
---@param length? integer
function writewidestring(address, value, length) end

-- Messaging --------------------------------------------------------------------------------

--- In-game chat, everyone.
---@param message string
function say(message) end

--- In-game chat, one player.
---@param player integer
---@param message string
function privatesay(player, message) end

--- Server terminal only.
---@param message string
function hprintf(message) end

--- Server terminal only.
---@param message string
function hprint(message) end

--- Server terminal only.
---@param message string
function respond(message) end

--- Displays text in a player's console.
---@param player integer
---@param message string
function sendconsoletext(player, message) end

-- Players and teams ------------------------------------------------------------------------

--- Player table address, or nil if the slot is empty.
---@param player integer
---@return integer|nil address
function getplayer(player) end

---@param player integer
---@return string name ASCII
function getname(player) end

--- CD-key hash, a unique identifier.
---@param player integer
---@return string hash
function gethash(player) end

---@param player integer
---@return string|nil ip
function getip(player) end

--- 0 red, 1 blue.
---@param player integer
---@return integer team
function getteam(player) end

---@param player integer
---@return string color
function getcolor(player) end

---@param team integer
---@return integer size
function getteamsize(team) end

---@param player integer
function changeteam(player) end

---@param player integer
function kill(player) end

---@param player integer
---@return boolean in_vehicle
function isinvehicle(player) end

--- duration in seconds, 0 lasts until death.
---@param player integer
---@param duration number
function applycamo(player, duration) end

--- Movement multiplier, default 1.0.
---@param player integer
---@param speed number
function setspeed(player, speed) end

---@param player integer
---@return boolean
function isadmin(player) end

--- Memory id (0-15) to RCON id (1-16).
---@param player integer
---@return integer rcon_id
function resolveplayer(player) end

--- RCON id (1-16) to memory id (0-15).
---@param rcon_id integer
---@return integer player
function rresolveplayer(rcon_id) end

--- Executes a server command in the context of a player.
---@param command string
---@param player integer Player memory id (0-15)
function svcmdplayer(command, player) end

-- Objects ----------------------------------------------------------------------------------

--- Object id to memory address.
---@param object_id integer
---@return integer address
function getobject(object_id) end

--- Biped object id, 0xFFFFFFFF if the player is dead or invalid.
---@param player integer
---@return integer object_id
function getplayerobjectid(player) end

--- Returns the player memory id associated with an object, or nil if it is not a player object.
---@param object_id integer
---@return integer|nil player
function objectidtoplayer(object_id) end

--- A player in a vehicle returns the vehicle's coordinates.
---@param object_id integer
---@return number x
---@return number y
---@return number z
function getobjectcoords(object_id) end

--- Map id of a tag, e.g. gettagid("weap", "weapons\\pistol\\pistol"). Cache it in OnNewGame.
---@param tag_type string Four-letter class
---@param tag_name string
---@return integer map_id
function gettagid(tag_type, tag_name) end

--- Returns the tag path and class for a map tag id.
---@param map_id integer
---@return string|nil tag_name
---@return string|nil tag_type
function gettaginfo(map_id) end

--- Moves an object to absolute coordinates.
---@param object_id integer
---@param x number
---@param y number
---@param z number
function movobjectcoords(object_id, x, y, z) end

--- respawn_time: seconds, 0 never, -1 gametype default. For weapons, grenades and powerups
--- recycle is ignored and respawn_time becomes the delay before the object is destroyed.
---@param tag_type string Four-letter class
---@param tag_name string
---@param parent_id integer -1 for none
---@param respawn_time number
---@param recycle boolean true respawns, false destroys
---@param x number
---@param y number
---@param z number
---@return integer object_id
function createobject(tag_type, tag_name, parent_id, respawn_time, recycle, x, y, z) end

--- An invalid id can crash the server.
---@param object_id integer
function destroyobject(object_id) end

---@param object_id integer
---@param x number
---@param y number
---@param z number
function movobjcoords(object_id, x, y, z) end

--- Teleports to a named location such as "redbase".
---@param object_id integer
---@param name string
function movobjname(object_id, name) end

--- Gives a weapon to a player who has fewer than 4.
---@param player integer
---@param object_id integer
function assignweapon(player, object_id) end

--- Forces ammo changes on a weapon to sync.
---@param weapon_id integer
function updateammo(weapon_id) end

--- seat: 0 driver, 1 passenger, 2 gunner. The player must not already be in a vehicle.
---@param player integer
---@param vehicle_id integer
---@param seat integer
function entervehicle(player, vehicle_id, seat) end

---@param player integer
function exitvehicle(player) end

-- Timers and server ------------------------------------------------------------------------

--- Calls a global function after delay ms. The callback receives (timer_id, count, ...) and
--- returns 1 to repeat or 0 to stop.
---@param delay integer Milliseconds
---@param callback_name string Name of a global function
---@param ... any Forwarded to the callback
---@return integer timer_id
function registertimer(delay, callback_name, ...) end

---@param timer_id integer
function removetimer(timer_id) end

--- Player arguments in the command must be RCON ids. Set get_response to true to capture output.
---@param command string
---@param get_response? boolean
---@return string[]|nil response
function svcmd(command, get_response) end

--- Sets the multiplier for damage lookup processing.
---@param multiplier number
function odl_multiplier(multiplier) end

--- String helpers ---------------------------------------------------------------------------

--- Splits a string using the supplied delimiter.
---@param value string
---@param delimiter string
---@return string[] parts
function tokenizestring(value, delimiter) end

--- Splits a command string into tokens.
---@param command string
---@return string[] tokens
function tokenizecmdstring(command) end

--- Both bounds are included.
---@param min integer
---@param max integer
---@return integer
function getrandomnumber(min, max) end

--- Server data path, where banlist.txt is stored.
---@return string
function getprofilepath() end
