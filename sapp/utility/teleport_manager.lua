--[[
=====================================================================================
SCRIPT NAME:      teleport_manager.lua
DESCRIPTION:      Advanced teleport system with location memory and map-linked warps.

FEATURES:
                  - Map-specific warp persistence
                  - Location history tracking (/back command)
                  - Warp overwrite protection
                  - Paginated warp listings
                  - JSON-based storage system
                  - Permission-based command access
                  - Player position restoration

COMMANDS:
                  /setwarp [name] [-o]    - Create/overwrite warp points
                  /warp [name]            - Teleport to saved location
                  /delwarp [name]         - Delete existing warp
                  /warplist [page]        - Browse available warps (paginated)
                  /back                   - Return to previous location

CONFIGURATION:
                  file = "teleports.json"  - Warp point storage file
                  max_results = 5          - Warps per page in listings
                  commands = {             - Command permissions:
                    warp = {permission = 1},
                    back = {permission = 1},
                    setwarp = {permission = 1},
                    delwarp = {permission = 1},
                    warplist = {permission = 1}
                  }

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

Copyright (c) 2020 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration Starts ----------------------------------------------------
local TeleportManager = {
    file = "teleports.json", -- JSON database for teleport locations
    max_results = 5, -- Max results per page
    commands = {
        warp = { permission = 1, cmd_index = 1 },
        back = { permission = 1, cmd_index = 2 },
        setwarp = { permission = 1, cmd_index = 3 },
        delwarp = { permission = 1, cmd_index = 4 },
        warplist = { permission = 1, cmd_index = 5 }
    },
    players = {}, -- Table to store player positions
}

local floor, format = math.floor, string.format
local json = loadfile('./json.lua')()

-- Initialization
function OnScriptLoad()
    local cg_dir = read_string(read_dword(sig_scan("68??????008D54245468") + 0x1))
    TeleportManager.dir = cg_dir .. "\\sapp\\" .. TeleportManager.file

    register_callback(cb["EVENT_LEAVE"], "OnPlayerLeave")
    register_callback(cb["EVENT_JOIN"], "OnPlayerJoin")
    register_callback(cb["EVENT_COMMAND"], "OnCommandReceived")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")

    TeleportManager:CheckFile(true)
end

function OnScriptUnload()
    -- Cleanup actions can be added here
end

function OnGameStart()
    TeleportManager:CheckFile(true)
end

function OnPlayerJoin(player)
    TeleportManager:InitializePlayer(player)
end

function OnPlayerLeave(player)
    TeleportManager:InitializePlayer(player, true)
end

-- Command handling
function TeleportManager:OnCommandReceived(player, command)
    local args = self:ParseCommand(command)
    local cmd_info = self.commands[args[1]]

    if cmd_info then
        local player_level = tonumber(get_var(player, "$lvl"))
        if player_level >= cmd_info.permission or player == 0 then
            self:ExecuteCommand(player, cmd_info.cmd_index, args)
        else
            self:SendResponse(player, "Insufficient Permission")
        end
        return false
    end
end

function TeleportManager:ExecuteCommand(player, cmd_index, args)
    if cmd_index == 1 then
        self:Warp(player, args)
    elseif cmd_index == 2 then
        self:Back(player)
    elseif cmd_index == 3 then
        self:SetWarp(player, args)
    elseif cmd_index == 4 then
        self:DeleteWarp(player, args)
    elseif cmd_index == 5 then
        self:WarpList(player, args)
    end
end

-- Warp Management Functions
function TeleportManager:Warp(player, args)
    if player_alive(player) then
        if args[2] then
            local records, map = self:CheckFile(), get_var(0, "$map")
            local warp_location = records[map][args[2]]

            if warp_location then
                self:SendResponse(player, format("Teleporting to [%s] at X: %.2f, Y: %.2f, Z: %.2f", args[2], warp_location.x, warp_location.y, warp_location.z))
                self:Teleport(player, warp_location.x, warp_location.y, warp_location.z)
            else
                self:SendResponse(player, "Warp name not found!")
            end
        else
            self:SendResponse(player, "Please enter a warp name")
        end
    else
        self:SendResponse(player, "Please wait until you respawn.")
    end
end

function TeleportManager:Back(player)
    if player_alive(player) then
        local previous_position = self.players[player]
        if previous_position then
            self:Teleport(player, unpack(previous_position))
            self:SendResponse(player, "Returning to previous location")
        else
            self:SendResponse(player, "Previous location not saved.")
        end
    else
        self:SendResponse(player, "Please wait until you respawn.")
    end
end

function TeleportManager:SetWarp(player, args)
    if player_alive(player) then
        if args[2] then
            local records = self:CheckFile() -- Ensure records are loaded
            local map = get_var(0, "$map")
            local overwrite = args[3] and args[3]:match("-o")

            -- Check if the map exists in records; if not, initialize it
            if records[map] == nil then
                records[map] = {}
            end

            -- Now we can safely check for the warp name
            if records[map][args[2]] == nil or overwrite then
                local pos = self:GetPlayerPosition(player)
                records[map][args[2]] = { x = format("%.3f", pos.x), y = format("%.3f", pos.y), z = format("%.3f", pos.z) }

                self:SaveRecords(records)
                local action = records[map][args[2]] and "Updated" or "Saved"
                self:SendResponse(player, format("Location %s: X: %.3f, Y: %.3f, Z: %.3f", action, pos.x, pos.y, pos.z))
            else
                self:SendResponse(player, 'A location with that name already exists. Use "-o" to overwrite')
            end
        else
            self:SendResponse(player, "Please enter a warp name")
        end
    else
        self:SendResponse(player, "Please wait until you respawn.")
    end
end

function TeleportManager:DeleteWarp(player, args)
    if args[2] then
        local map = get_var(0, "$map")
        local records = self:CheckFile()

        -- Check if the map exists in records; if not, send an error message
        if records[map] == nil then
            self:SendResponse(player, format('No warps recorded for [%s]', map))
            return
        end

        -- Check if the specific warp name exists
        if records[map][args[2]] then
            records[map][args[2]] = nil
            self:SaveRecords(records)
            self:SendResponse(player, format('Successfully deleted warp "%s"', args[2]))
        else
            self:SendResponse(player, "Warp name not found!")
        end
    else
        self:SendResponse(player, "Please enter a warp name")
    end
end


-- Warp List Functions
function TeleportManager:WarpList(player, args)
    local map = get_var(0, "$map")
    local records = self:CheckFile()
    local warp_names = {}

    for name in pairs(records[map]) do
        table.insert(warp_names, name)
    end

    if #warp_names > 0 then
        local page = args[2] and tonumber(args[2]) or 1
        local total_pages = self:GetTotalPages(#warp_names)

        if page > 0 and page <= total_pages then
            self:DisplayWarpList(player, warp_names, page)
        else
            self:SendResponse(player, format('Invalid Page ID. Please type a page between 1-%d', total_pages))
        end
    else
        self:SendResponse(player, format('No warps recorded for [%s]', map))
    end
end

function TeleportManager:DisplayWarpList(player, warp_names, page)
    local max_per_page = self.max_results
    local start_index = (page - 1) * max_per_page + 1
    local end_index = math.min(start_index + max_per_page - 1, #warp_names)

    local displayed_warps = {}
    for i = start_index, end_index do
        table.insert(displayed_warps, warp_names[i])
    end

    self:SendResponse(player, format("Warps (Page %d/%d): %s", page, self:GetTotalPages(#warp_names), table.concat(displayed_warps, ", ")))
end

-- Teleportation Function
function TeleportManager:Teleport(player, x, y, z)
    local pos = self:GetPlayerPosition(player)
    self.players[player] = { pos.x, pos.y, pos.z }
    write_vector3d((pos.obj ~= 0 and pos.obj or pos.dyn) + 0x5C, x, y, (pos.obj ~= 0 and z + 0.5 or z))
    return true
end

-- Player Initialization
function TeleportManager:InitializePlayer(player, reset)
    if reset then
        self.players[player] = nil
    else
        self.players[player] = {}
    end
end

-- File Handling Functions
function TeleportManager:CheckFile(init)
    if init then
        self.players = {}
        for i = 1, 16 do
            if player_present(i) then
                self:InitializePlayer(i)
            end
        end
    end

    if not self:FileExists(self.dir) then
        self:CreateFile(self.dir)
    end

    local records = self:LoadRecords()
    return records
end

local function write_file(fileName, content)
    local file = io.open(fileName, "w")
    if file then
        file:write(content)
        file:close()
    end
end

local function read_file(fileName)
    local file = io.open(fileName, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
end

function TeleportManager:LoadRecords()
    local records = json:decode(read_file(self.dir))
    return records or {}
end

function TeleportManager:SaveRecords(records)
    write_file(self.dir, json:encode(records, { indent = true }))
end

function TeleportManager:FileExists(file_path)
    return os.rename(file_path, file_path) and true or false
end

function TeleportManager:CreateFile(file_path)
    local initial_content = json:encode({}, { indent = true })
    write_file(file_path, initial_content)
end

-- Utility Functions
function TeleportManager:SendResponse(player, message)
    rprint(player, message)
end

-- Utility functions to split string
function string.split(str, sep)
    local result = {}
    for part in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(result, part)
    end
    return result
end

function TeleportManager:ParseCommand(command)
    return string.split(command, " ")
end

function TeleportManager:GetPlayerPosition(player)
    local dynamic_player = get_dynamic_player(player)
    return {
        obj = dynamic_player,
        x = read_float(dynamic_player + 0x5C),
        y = read_float(dynamic_player + 0x5C + 0x4),
        z = read_float(dynamic_player + 0x5C + 0x8)
    }
end

function TeleportManager:GetTotalPages(total_items)
    return floor(total_items / self.max_results) + (total_items % self.max_results > 0 and 1 or 0)
end

function OnCommandReceived(player, command)
    return TeleportManager:OnCommandReceived(player, command)
end