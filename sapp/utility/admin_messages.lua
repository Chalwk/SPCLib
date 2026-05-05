--[[
=====================================================================================
SCRIPT NAME:      admin_messages.lua
DESCRIPTION:      Configurable admin join message system.
                  - Displays messages per admin level (1-4)
                  - Easy to configure per level and toggle display environment

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts --

local messages = {
    -- Level 1:
    --
    [1] = '[TRIAL-MOD] $name joined the server. Everybody hide!',

    -- Level 2:
    --
    [2] = '[MODERATOR] $name just showed up. Hold my beer!',

    -- Level 3:
    --
    [3] = '[ADMIN] $name just joined. Hide your bananas!',

    -- Level 4:
    --
    [4] = '[SENIOR-ADMIN] $name joined the server.'
}
-- config ends --

api_version = '1.11.0.0'

function OnScriptLoad()
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
end

function OnJoin(playerId)
    local lvl = tonumber(get_var(playerId, '$lvl'))
    if lvl >= 1 then
        local name = get_var(playerId, '$name')
        local msg = messages[lvl]
        msg = msg:gsub('$name', name)

        for i = 1, 16 do
            if player_present(i) then
                rprint(i, msg)
            end
        end
    end
end

function OnScriptUnload() end
