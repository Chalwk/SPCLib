--[[
=====================================================================================
SCRIPT NAME:      show_admin_names.lua
DESCRIPTION:      Identifies and displays all online administrators with their
                  permission levels via simple chat command.

FEATURES:
                  - Real-time admin list display
                  - Shows admin name and permission level
                  - Works for all online admins
                  - Lightweight with minimal overhead

USAGE:
                  Simply type: /whois
                  Output format: "AdminName [level: X]"

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Command used to check for admins
local command = 'whois'
api_version = '1.12.0.0'

-- Event handlers
function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, 'checkAdmins')
end

local function isAdmin(playerIndex)
    local playerLevel = tonumber(get_var(playerIndex, "$lvl"))
    return playerLevel and playerLevel > 0
end

function checkAdmins(playerIndex, cmd)
    if cmd:sub(1, command:len()):lower() == command then
        for i = 1, 16 do
            if player_present(i) then
                local adminLevel = isAdmin(i)
                if adminLevel then
                    rprint(playerIndex, get_var(i, '$name') .. ' [level: ' .. adminLevel .. ']')
                end
            end
        end
        return false
    end
end

function OnScriptUnload() end
