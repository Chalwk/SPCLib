@echo off
setlocal enabledelayedexpansion

echo Moving confirmed misplaced files...

move /Y "utility\live_on_3.lua" "notifications\live_on_3.lua" >nul 2>&1 && echo Moved: live_on_3.lua
move /Y "utility\custom_colors.lua" "gameplay\custom_colors.lua" >nul 2>&1 && echo Moved: custom_colors.lua
move /Y "utility\client_crasher.lua" "admin\client_crasher.lua" >nul 2>&1 && echo Moved: client_crasher.lua
move /Y "utility\breadcrumb_tracker.lua" "admin\breadcrumb_tracker.lua" >nul 2>&1 && echo Moved: breadcrumb_tracker.lua
move /Y "gameplay\melee_kicker.lua" "admin\melee_kicker.lua" >nul 2>&1 && echo Moved: melee_kicker.lua

pause >nul