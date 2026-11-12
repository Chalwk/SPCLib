---@meta
-- Chimera Lua API for EmmyLua and lua-language-server.
-- Runtime is Lua 5.5.
--
-- Copyright (c) 2026 Jericho Crosby (Chalwk).
--

---@alias ChimeraEvent
--- | "command"      # (cmd: string): boolean|nil. Return false to block.
--- | "frame"        # Each rendered frame. Draw calls go here or in preframe.
--- | "preframe"     # Before frame processing.
--- | "map_load"     # A map is being loaded.
--- | "map_preload"  # Before map loading.
--- | "precamera"    # (x, y, z, fov, fx, fy, fz, ux, uy, uz). Must return all ten values.
--- | "rcon_message" # (message: string): boolean|nil. Return false to block.
--- | "tick"         # Each game tick (1/30 s).
--- | "pretick"      # Before each game tick.
--- | "unload"       # The script is unloading.

---@alias ChimeraPriority "before" | "default" | "after" | "final"

---@alias ChimeraGametype "ctf" | "slayer" | "oddball" | "king" | "race"

-- Script lifecycle -------------------------------------------------------------------------

--- Required. The script refuses to load without it.
---@type number
clua_version = nil

-- Globals ----------------------------------------------------------------------------------

--- Chimera build number (Git commit count).
---@type integer
build = 0

--- Chimera version string.
---@type string
full_build = ""

--- Current gametype.
---@type ChimeraGametype
gametype = "slayer"

--- Local player index (0-15). nil until assigned after joining a server.
---@type number | nil
local_player_index = nil

--- Currently loaded map name.
---@type string
map = ""

--- True if the map uses protected tag data.
---@type boolean
map_is_protected = false

--- True if the script runs sandboxed.
---@type boolean
sandboxed = false

--- Filename for global scripts, map name for map scripts.
---@type string
script_name = ""

---@type "global" | "map"
script_type = "global"

--- "none" is single player, "local" is hosting, "dedicated" is joined to a server.
---@type "none" | "local" | "dedicated"
server_type = "none"

-- Callbacks and timers ---------------------------------------------------------------------
--
-- NOTE: "spawn" and "prespawn" are accepted by set_callback at runtime but are not hooked
-- into any engine event by the current Chimera build.

--- Callback names for set_callback. These are the global function names.
---@alias ChimeraCallbackName
--- | "OnCommand"
--- | "OnFrame"
--- | "OnMapLoad"
--- | "OnMapPreload"
--- | "OnPreCamera"
--- | "OnPreFrame"
--- | "OnPreTick"
--- | "OnRconMessage"
--- | "OnScriptUnload"
--- | "OnTick"

--- Event names for set_callback. Hover a field for the callback signature.
---@class ChimeraCallbackIds
---@field command      ChimeraEvent OnCommand(cmd: string): boolean|nil. Return false to block.
---@field frame        ChimeraEvent OnFrame(). Each rendered frame. Draw calls go here or in preframe.
---@field map_load     ChimeraEvent OnMapLoad(). A map is being loaded.
---@field map_preload  ChimeraEvent OnMapPreload(). Before map loading.
---@field precamera    ChimeraEvent OnPreCamera(x, y, z, fov, fx, fy, fz, ux, uy, uz). Must return all ten values.
---@field preframe     ChimeraEvent OnPreFrame(). Before frame processing. Draw calls go here or in frame.
---@field pretick      ChimeraEvent OnPreTick(). Before each game tick.
---@field rcon_message ChimeraEvent OnRconMessage(message: string): boolean|nil. Return false to block.
---@field tick         ChimeraEvent OnTick(). Each game tick (1/30 s).
---@field unload       ChimeraEvent OnScriptUnload(). The script is unloading.

--- The callback must be a global function. Priorities decide the order between scripts.
---@param event         ChimeraEvent | string
---@param callback_name ChimeraCallbackName | string Name of a global function
---@param priority?     ChimeraPriority
function set_callback(event, callback_name, priority) end

--- Runs the callback every interval until it returns false or the timer is stopped.
---@param interval_ms   number
---@param callback_name string                          Name of a global function
---@param ...           boolean | number | string | nil Forwarded to the callback
---@return integer timer_id
function set_timer(interval_ms, callback_name, ...) end

--- Stopping a timer that no longer exists raises an error.
---@param timer_id number
function stop_timer(timer_id) end

-- Output -----------------------------------------------------------------------------------

---@param message string
function hud_message(message) end

---@overload fun(message: string, red: number, green: number, blue: number)
---@overload fun(message: string, alpha: number, red: number, green: number, blue: number)
---@param message string
function console_out(message) end

--- Draws inside a screen rectangle. Call it from preframe or frame.
---@param text   string
---@param left   number
---@param top    number
---@param right  number
---@param bottom number
---@param font   "small" | "large" | "ticker"
---@param align  "left" | "center" | "right"
---@param alpha  number
---@param red    number
---@param green  number
---@param blue   number
function draw_text(text, left, top, right, bottom, font, align, alpha, red, green, blue) end

-- Console and scripting --------------------------------------------------------------------

--- Runs a Halo console command or a Halo script expression (Lisp syntax).
---@param script string
function execute_script(script) end

--- Reads a Halo scripting global.
---@param name string
---@return boolean | number
function get_global(name) end

--- The value type is validated.
---@param name  string
---@param value boolean | number
function set_global(name, value) end

--- Only allow-listed Chimera commands work.
---@param command string
---@param save    boolean
function execute_chimera_command(command, save) end

-- Players, objects and tags ----------------------------------------------------------------

--- Player table pointer, or nil. No index returns the local player.
---@param index? number
---@return integer | nil address
function get_player(index) end

--- Pointer to the player's current object, or nil if the player is dead. No index returns the local player.
---@param index? number
---@return integer | nil address
function get_dynamic_player(index) end

--- Dynamic object pointer for an object id, or nil.
---@param object_id number
---@return integer | nil address
function get_object(object_id) end

--- Raises an error if the id is invalid.
---@param object_id number
function delete_object(object_id) end

--- Spawned client side only in multiplayer. Other players do not see the object.
---@overload fun(tag_class: string, tag_path: string, x: number, y: number, z: number): integer
---@param tag_id  number
---@param x       number
---@param y       number
---@param z       number
---@param parent? number
---@return integer object_id
function spawn_object(tag_id, x, y, z, parent) end

--- With a class and path, returns the tag id. With a tag id, returns the tag entry pointer.
---@overload fun(tag_id: number): integer | nil
---@param tag_class string Four-letter class, e.g. "weap"
---@param tag_path  string
---@return integer | nil tag
function get_tag(tag_class, tag_path) end

-- Memory -----------------------------------------------------------------------------------

--- Reads a signed 8-bit integer.
---@param address number
---@return integer
function read_i8(address) end

--- Reads an unsigned 8-bit integer.
---@param address number
---@return integer
function read_u8(address) end

--- Reads a signed 16-bit integer.
---@param address number
---@return integer
function read_i16(address) end

--- Reads an unsigned 16-bit integer.
---@param address number
---@return integer
function read_u16(address) end

--- Reads a signed 32-bit integer.
---@param address number
---@return integer
function read_i32(address) end

--- Reads an unsigned 32-bit integer.
---@param address number
---@return integer
function read_u32(address) end

--- Reads an unsigned 8-bit integer.
---@param address number
---@return integer
function read_byte(address) end

--- Reads an unsigned 16-bit integer.
---@param address number
---@return integer
function read_word(address) end

--- Reads an unsigned 32-bit integer.
---@param address number
---@return integer
function read_dword(address) end

--- Reads a signed 8-bit integer.
---@param address number
---@return integer
function read_char(address) end

--- Reads a signed 16-bit integer.
---@param address number
---@return integer
function read_short(address) end

--- Reads a signed 32-bit integer.
---@param address number
---@return integer
function read_int(address) end

--- Reads an integer.
---@param address number
---@return integer
function read_long(address) end

--- Reads a 32-bit float.
---@param address number
---@return number
function read_f32(address) end

--- Reads a 64-bit float.
---@param address number
---@return number
function read_f64(address) end

--- Reads a 32-bit float.
---@param address number
---@return number
function read_float(address) end

--- Reads a 64-bit float.
---@param address number
---@return number
function read_double(address) end

--- Writes a signed 8-bit integer.
---@param address number
---@param value   number
function write_i8(address, value) end

--- Writes an unsigned 8-bit integer.
---@param address number
---@param value   number
function write_u8(address, value) end

--- Writes a signed 16-bit integer.
---@param address number
---@param value   number
function write_i16(address, value) end

--- Writes an unsigned 16-bit integer.
---@param address number
---@param value   number
function write_u16(address, value) end

--- Writes a signed 32-bit integer.
---@param address number
---@param value   number
function write_i32(address, value) end

--- Writes an unsigned 32-bit integer.
---@param address number
---@param value   number
function write_u32(address, value) end

--- Writes an unsigned 8-bit integer.
---@param address number
---@param value   number
function write_byte(address, value) end

--- Writes an unsigned 16-bit integer.
---@param address number
---@param value   number
function write_word(address, value) end

--- Writes an unsigned 32-bit integer.
---@param address number
---@param value   number
function write_dword(address, value) end

--- Writes a signed 8-bit integer.
---@param address number
---@param value   number
function write_char(address, value) end

--- Writes a signed 16-bit integer.
---@param address number
---@param value   number
function write_short(address, value) end

--- Writes a signed 32-bit integer.
---@param address number
---@param value   number
function write_int(address, value) end

--- Writes an integer.
---@param address number
---@param value   number
function write_long(address, value) end

--- Writes a 32-bit float.
---@param address number
---@param value   number
function write_f32(address, value) end

--- Writes a 64-bit float.
---@param address number
---@param value   number
function write_f64(address, value) end

--- Writes a 32-bit float.
---@param address number
---@param value   number
function write_float(address, value) end

--- Writes a 64-bit float.
---@param address number
---@param value   number
function write_double(address, value) end

---@param address   number
---@param bit_index number Less than 32
---@return integer bit 0 or 1
function read_bit(address, bit_index) end

---@param address   number
---@param bit_index number           Less than 32
---@param value     boolean | number
function write_bit(address, bit_index, value) end

--- Reads a null-terminated string.
---@param address number
---@return string
function read_string8(address) end

--- Writes a null-terminated string.
---@param address number
---@param value   string
function write_string8(address, value) end

--- Alias of read_string8.
---@param address number
---@return string
function read_string(address) end

--- Alias of write_string8.
---@param address number
---@param value   string
function write_string(address, value) end

-- Filesystem -------------------------------------------------------------------------------
-- Confined to chimera/lua/data/<script_type>/<script_name>/. Paths outside raise a scope error.

---@param path string
---@return boolean ok True if created or already present
function create_directory(path) end

---@param path string
---@return boolean ok
function remove_directory(path) end

--- Directory entries end in a backslash.
---@param path string
---@return string[] | false entries
function list_directory(path) end

---@param path string
---@return boolean
function directory_exists(path) end

---@param path    string
---@param content string
---@param append? boolean
---@return boolean ok
function write_file(path, content, append) end

---@param path string
---@return string | nil content nil if the file cannot be opened
function read_file(path) end

---@param path string
---@return boolean ok
function delete_file(path) end

---@param path string
---@return boolean
function file_exists(path) end
