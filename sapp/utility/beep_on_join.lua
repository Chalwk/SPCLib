--[[
=====================================================================================
SCRIPT NAME:      beep_on_join.lua
DESCRIPTION:      Plays a system beep sound when a player joins the server.
                  Simple auditory alert for server administrators.

FEATURES:
                  - Instant notification when players connect
                  - Uses system alert sound (works on Windows systems)
                  - Zero configuration required
                  - Minimal resource usage

NOTE:              Requires server console to be in focus for beep to be audible
                   on some operating systems.

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
end

function OnJoin(_)
    os.execute('echo \7')
end

function OnScriptUnload()
    -- N/A
end