--[[
===============================================================================
SCRIPT NAME:      pagination.lua
DESCRIPTION:      Standalone pagination library for displaying tabular data in pages.

FEATURES:         - Displays data in paginated format with configurable page sizes
                  - Handles page navigation and boundary checking
                  - Flexible formatting for different data types
                  - Easy integration with existing scripts

USAGE:
    local pages = loadfile("pagination.lua")()
    pages:Show(player_id, page, max_results, list_size, data_table, command)

PARAMETERS:
    player_id     - Player ID to send output to (nil for public message)
    page          - Page number to display (defaults to 1)
    max_results   - Maximum number of items per page
    list_size     - Total number of items in data table
    data_table    - Table containing the data to paginate
    command       - Command (args[1]) to use for pagination navigation

EXAMPLE:
    local data = {"Item 1", "Item 2", "Item 3", ...}
    local pages = loadfile("pagination.lua")()
    pages:Show(1, 1, 10, #data, data, command)

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local pagination = { DEFAULT_PAGES = 1, DEFAULT_MAX_RESULTS = 10 }

local select = select
local tostring = tostring
local math_min, math_ceil = math.min, math.ceil

local rprint = rprint

local function format(str, ...)
    return select('#', ...) > 0 and str:format(...) or str
end

local function send(id, str)
    if id == 0 then
        cprint(str)
        return
    end
    rprint(id, str)
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
