--[[
===============================================================================
SCRIPT NAME:    pagination.lua
DESCRIPTION:    Cross-platform pagination library for displaying tabular data in pages.

FEATURES:       - Displays data in paginated format with configurable page sizes
                - Handles page navigation and boundary checking
                - Flexible formatting for different data types
                - Easy integration with existing scripts

USAGE:          local pages = require("pagination")
                pages:Show(player_id, page, max_results, list_size, data_table, command)

PARAMETERS:     player_id     Player ID to send output to (nil or 0 for server console; Chimera ignores it)
                page          Page number to display (defaults to 1)
                max_results   Maximum number of items per page
                list_size     Total number of items in data table
                data_table    Table containing the data to paginate
                command       Command (args[1]) to use for pagination navigation

EXAMPLE:        local data = {"Item 1", "Item 2", "Item 3", ...}
                local pages = require("pagination")
                pages:Show(1, 1, 10, #data, data, command)

COMPATIBILITY:  This script is Compatible with SAPP, Phasor, and Chimera.

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
			https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

local pagination = { DEFAULT_PAGES = 1, DEFAULT_MAX_RESULTS = 10 }

local select = select
local tostring = tostring
local math_min, math_ceil = math.min, math.ceil

local sapp_cprint = type(cprint) == "function" and cprint or nil
local sapp_rprint = type(rprint) == "function" and rprint or nil
local phasor_privatesay = type(privatesay) == "function" and privatesay or nil
local chimera_console_out = type(console_out) == "function" and console_out or nil

local function format(str, ...)
    return select('#', ...) > 0 and str:format(...) or str
end

local send
if sapp_cprint and sapp_rprint then
    send = function (id, str)
        if id == nil or id == 0 then
            sapp_cprint(str)
        else
            sapp_rprint(id, str)
        end
    end
elseif phasor_privatesay then
    send = function (id, str)
        if id ~= nil and id ~= 0 then
            phasor_privatesay(id, str)
        else
            print(str)
        end
    end
elseif chimera_console_out then
    send = function (_, str)
        chimera_console_out(str)
    end
elseif sapp_cprint then
    send = function (_, str)
        sapp_cprint(str)
    end
elseif sapp_rprint then
    send = function (id, str)
        if id ~= nil and id ~= 0 then
            sapp_rprint(id, str)
        else
            print(str)
        end
    end
else
    send = function (_, str)
        print(str)
    end
end

function pagination:Show(player_id, page, max_results, list_size, data_table, cmd)
    -- Validate inputs
    if not data_table or #data_table == 0 then
        send(player_id, "No data to display")
        return
    end

    -- Set defaults
    page = page or self.DEFAULT_PAGES
    max_results = max_results or self.DEFAULT_MAX_RESULTS
    list_size = list_size or #data_table

    -- Calculate pagination values
    local total_entries = list_size
    local total_pages = math_ceil(total_entries / max_results)

    -- Validate page number
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_index = (page - 1) * max_results + 1
    local end_index = math_min(start_index + max_results - 1, total_entries)

    -- Display header
    send(player_id, format("Page %d/%d:", page, total_pages))

    -- Display data items
    for i = start_index, end_index do
        local item = data_table[i]
        if item then
            send(player_id, format("%d. %s", i, tostring(item)))
        end
    end

    -- Display navigation hint if there are multiple pages
    if total_pages > 1 then
        if page < total_pages then
            send(player_id, format("Use '/" .. cmd .. " %s' for next page", page + 1))
        end
        if page > 1 then
            send(player_id, format("Use '/" .. cmd .. " %s' for previous page", page - 1))
        end
    end
end

return pagination
