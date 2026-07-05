--[[
=====================================================================================
SCRIPT NAME:      welcome_messages.lua
DESCRIPTION:      Simple player greeting system

CREDITS:
                  Originally requested by 'mdc81' on OpenCarnage forums

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, 'OnJoin')
end

function OnJoin(Ply)
    say(Ply, 'Welcome friend, ' .. get_var(Ply, '$name'))
end

function OnScriptUnload()
    -- N/A
end
