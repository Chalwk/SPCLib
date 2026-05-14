--[[
=====================================================================================
SCRIPT NAME:      report_system.lua
DESCRIPTION:      In-game player reporting.
                  - /s_report <id> <reason>  - file a report against a player
                  - /s_report <reason>       - file a bug / general report
                  - /reports [page]          - view current reports (admins)
                  - /report_clear <id>       - clear a report by index
                  - /players /list           - show online players with IDs (all players)
                  Auto-expires old reports, prevents spam.

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ---------------------------------------------------------------

-- Minimum admin level to manage reports
local admin_level = 2

-- Cooldown per reporter (seconds)
local cooldown = 60

-- Maximum reason length (characters)
local max_reason_len = 120

-- Reports expire after this many seconds
local expire_after = 600

-- Entries per page for /reports
local page_size = 8

-- Log reports to server console
local console_log = true

-- Log reports to file
local file_log = true
local log_file_path = "reports.txt"
-- CONFIG END -----------------------------------------------------------------

api_version = "1.12.0.0"

local get_var = get_var
local player_present = player_present
local register_callback = register_callback
local rprint, cprint = rprint, cprint
local tonumber = tonumber
local os_time = os.time
local ipairs = ipairs
local fmt = string.format
local table_insert, table_remove = table.insert, table.remove
local math_ceil, math_min = math.ceil, math.min

local reports = {}   -- list of {reporter, reporter_id, reported, reported_id, reason, time}
local cooldowns = {} -- reporter id -> last report time

local function is_admin(id)
    return id == 0 or tonumber(get_var(id, "$lvl")) >= admin_level
end

local function getConfigPath()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1)) .. '\\sapp\\'
end

local function parse_args(cmd)
    local parts = {}
    for w in cmd:gmatch("([^%s]+)") do parts[#parts + 1] = w end
    return parts
end

local function respond(id)
    if id == 0 then
        return function(msg) cprint(msg) end
    else
        return function(msg) rprint(id, msg) end
    end
end

local function clean_old_reports()
    local now = os_time()
    local i = 1
    while i <= #reports do
        if now - reports[i].time > expire_after then
            table_remove(reports, i)
        else
            i = i + 1
        end
    end
end

local function log_to_file(reporter_name, reporter_id, target_name, target_id, reason)
    if not file_log then return end
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local target_str = (target_name and target_id) and fmt("%s (%s)", target_name, target_id) or "Bug/General"
    local line = fmt("[%s] %s (%d) reported %s: %s\n",
        timestamp, reporter_name, reporter_id, target_str, reason)
    local file, err = io.open(log_file_path, "a")
    if file then
        file:write(line)
        file:close()
    else
        cprint("ERROR: Could not write to report log file: " .. (err or "unknown error"))
    end
end

function OnScriptLoad()
    log_file_path = getConfigPath() .. log_file_path

    register_callback(cb.EVENT_COMMAND, "OnCommand")
    timer(30 * 1000, "CleanupTimer")
end

function CleanupTimer()
    clean_old_reports()
    return true
end

function OnCommand(id, command)
    local args = parse_args(command)
    if #args == 0 then return true end

    local cmd = args[1]:lower()

    if cmd == "s_report" then
        if id == 0 then return end

        -- Cooldown check
        local now = os_time()
        if cooldowns[id] and now - cooldowns[id] < cooldown then
            respond(id)("You must wait before reporting again.")
            return false
        end
        cooldowns[id] = now

        local target_id, reason
        local second_arg = args[2]

        -- Determine if it's a player report or bug report
        if second_arg and tonumber(second_arg) and player_present(tonumber(second_arg)) then
            -- Player report: /s_report <id> <reason>
            target_id = tonumber(second_arg)
            if target_id == id then
                respond(id)("You cannot report yourself.")
                return false
            end
            reason = table.concat(args, " ", 3)
            if reason == "" then
                respond(id)("You must provide a reason.")
                return false
            end
        else
            -- Bug report: /s_report <reason> (no ID)
            target_id = nil
            reason = table.concat(args, " ", 2)
            if reason == "" then
                respond(id)("You must provide a reason (e.g., bug description).")
                return false
            end
        end

        -- Trim reason length
        local max_len = max_reason_len
        if #reason > max_len then
            reason = reason:sub(1, max_len) .. "..."
        end

        clean_old_reports()

        local reporter_name = get_var(id, "$name")
        local reported_name = target_id and get_var(target_id, "$name") or "Bug/General"
        local reported_id = target_id or -1

        table_insert(reports, {
            reporter = reporter_name,
            reporter_id = id,
            reported = reported_name,
            reported_id = reported_id,
            reason = reason,
            time = now
        })

        if console_log then
            if target_id then
                cprint(fmt("[REPORT] %s (%d) reported %s (%d): %s",
                    reporter_name, id, reported_name, target_id, reason))
            else
                cprint(fmt("[REPORT] %s (%d) filed bug report: %s",
                    reporter_name, id, reason))
            end
        end

        if target_id then
            log_to_file(reporter_name, id, reported_name, target_id, reason)
        else
            log_to_file(reporter_name, id, nil, nil, reason)
        end

        respond(id)("Report filed.")
        return false
    elseif cmd == "reports" then
        if not is_admin(id) then
            respond(id)("You do not have permission to view reports.")
            return false
        end
        clean_old_reports()

        local page = tonumber(args[2]) or 1
        if page < 1 then page = 1 end
        local total = #reports
        local pages = math_ceil(total / page_size)
        if total == 0 then
            respond(id)("No active reports.")
            return false
        end
        if page > pages then page = pages end
        local start = (page - 1) * page_size + 1
        local finish = math_min(start + page_size - 1, total)

        respond(id)(fmt("Reports (page %d/%d):", page, pages))
        for i = start, finish do
            local r = reports[i]
            local age = os_time() - r.time
            if r.reported_id == -1 then
                respond(id)(fmt("%d. [%dm ago] %s (%d) -> BUG: %s",
                    i, math_ceil(age / 60), r.reporter, r.reporter_id, r.reason))
            else
                respond(id)(fmt("%d. [%dm ago] %s (%d) -> %s (%d): %s",
                    i, math_ceil(age / 60), r.reporter, r.reporter_id,
                    r.reported, r.reported_id, r.reason))
            end
        end
        return false
    elseif cmd == "report_clear" then
        if not is_admin(id) then
            respond(id)("You do not have permission to clear reports.")
            return false
        end
        local index = tonumber(args[2])
        if not index or index < 1 or index > #reports then
            respond(id)("Invalid report index.")
            return false
        end
        local r = reports[index]
        table_remove(reports, index)
        respond(id)("Cleared report about " .. r.reported .. ".")
        return false
    elseif cmd == "players" then
        local player_list = {}
        for i = 0, 15 do
            if player_present(i) then
                local name = get_var(i, "$name")
                table_insert(player_list, fmt("%d: %s", i, name))
            end
        end
        if #player_list == 0 then
            respond(id)("No players online.")
        else
            respond(id)("Online players:")
            for _, entry in ipairs(player_list) do
                respond(id)(entry)
            end
        end
        return false
    end
    return true
end

function OnScriptUnload() end
