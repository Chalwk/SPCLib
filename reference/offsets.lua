---@diagnostic disable: assign-type-mismatch, global-in-non-module, undefined-global, unnecessary-if

-- Addresses and Offsets
-- Created by Wizard, edited by aLTis

--	The reason why I'm editing this is because Wizard's thing has a lot of wrong offsets and missing information
--	I'll try to fill in what I find and write my name where I change stuff
--	You can ctrl+f my name to see what I've changed
--	I've also changed reading functions to use sapp's API

-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<
-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<
-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<
-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<
--DO NOT DOWNLOAD THIS SCRIPT. YOU SHOULD BE VISITING THIS PAGE WHENEVER YOU NEED AN OFFSET.
--THIS PAGE IS UPDATED FREQUENTLY, SO IF YOU DOWNLOAD THIS YOU WILL HAVE  AN  OUTDATED COPY.
-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<
-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<
-->>>>>>>>!!!!>>>>>>>>WARNING>>>>>>>>>>>>>>WARNING<<<<<<<<<<<<<<WARNING<<<<<<<<!!!!<<<<<<<<

function OnScriptLoad(process, Game, persistent)
    --For Chimera:
    map_name_address = read_string(0x00643064) -- maybe wrong?
    server_ip_address = read_string(0x0063EE28)

    -- node information is stored here:
    read_float(object + 0x550) -- Biped
    read_float(object + 0x5C0) -- Vehicle
    read_float(object + 0x340) -- Weapon
    read_float(object + 0x294) -- Equipment
    read_float(object + 0x244) -- Grenade
    read_float(object + 0x2B0) -- Projectile
    read_float(object + 0x1F8) -- Scenery
    read_float(object + 0x228) -- Machine
    read_float(object + 0x21C) -- Machine Control


    -- random cheat engine stuff:
    screen_render_stuff = 0xB25B7FE -- what's being rendered on the screen I guess
    shadow_color = read_byte(0x51312F)
    sun_god_ray_count = read_byte(0x529893)
    ticks_per_second = read_float(0x612190)
    tick_length = read_float(0x612194)
    shadow_darkness = read_float(0x6122F0) -- this changes shadow darkness but probably other things too
    navpoint_z_offset = read_float(0x6122F4)
    navpoint_conversion_to_meters = read_float(0x6128E0)
    navpoint_x_offset = read_float(0x6128EC)
    navpoint_y_offset = read_float(0x6128F0)
    near_clip_plane = read_float(0x61226C)       -- 0.0625
    node_rotation_multiplier = read_float(0x6122AC) -- affects all nodes in a weird way
    screen_height = read_word(0x637CF0)
    screen_width = read_word(0x637CF2)
    lightmap_thingy = read_dword(0x75C4DC) -- lowering this messes up lightmaps

    --004CB16F, 004CB1AF player biped movement stuff?
    --haloce.exe+130ED8 - 6A 00   changing this to 01 will make the scopes not blurry but keep the dark areas blurry
    --haloce.exe+1123F5 - 68 44040000  object render limit?


    gravity_global = read_float(0x637BE4) -- Found by 002
    game_pause_address = read_byte(0x622058) -- is true when in the menus or console
    show_hud = read_byte(0x400003bc)      -- set to 0 to hide hud (needs testing)

    game_state_address = 0x400002E8
    game_render = read_byte(game_state_address)   -- if 0 the screen will be black
    game_running = read_byte(game_state_address + 1) -- if 0 the screen will be black (0 when paused in sp)
    game_paused = read_byte(game_state_address + 2) -- 1 when paused in sp. in mp it will just disable muouse aiming
    --unknown values
    game_time = read_word(game_state_address + 12) -- time since map was loaded in ticks (affects "hold F1 to show score")
    game_over = read_word(game_state_address + 14) -- setting to 1 will end the game
    unknown = read_word(game_state_address + 16)  -- changes to 1 sometimes but only on preframe but not on tick?
    unknown = read_word(game_state_address + 18)  -- always 0
    game_time2 = read_word(game_state_address + 20)
    unknown = read_word(game_state_address + 22)  -- always 0
    game_speed = read_float(game_state_address + 24) -- game speed (only works in single player)
    game_time3 = read_dword(game_state_address + 28) -- unlike other 2, this one counts even when single player game is paused (not sure what this is tbh)
    unknown = read_byte(game_state_address + 32)  -- changes to 1 on single player sometimes
    unknown = read_byte(game_state_address + 3)   -- changing breaks animations and crashes the game sometimes
    -- the rest of the values change sometimes but no idea what they mean

    function HUD()
        local hud_address = 0x400007F4
        local hud_seat_id = read_byte(hud_address)          -- changes depending on vehicle seat or weapon (from hud_icon_messages)
        local unknown = read_byte(hud_address + 1)          --changes based on weapon but 0 when vehicle?
        local unknown = read_byte(hud_address + 2)          --changes based on weapon but 0 when vehicle?
        local unknown = read_byte(hud_address + 3)          --always 64?
        local hud_vehicle_id = read_byte(hud_address + 4)   -- changes depending on vehicle (from hud_icon_messages)
        -- 8 - 28 - unknown
        local unknown = read_dword(hud_address + 32)        -- idk
        local unknown = read_byte(hud_address + 36)         -- turns to 1 when interacting with a weapon or a vehicle
        local unknown = read_byte(hud_address + 37)         -- turns to 3 when interacting with a vehicle
        -- 38 - 41 - unknown
        local unknown = read_byte(hud_address + 42)         -- turns to 1 when interacting with a weapon
        -- missed some health and shield values here...
        local unknown = read_byte(hud_address + 94)         -- never changes?
        local game_time = read_dword(hud_address + 96)      -- ticks since the game started
        local player_object = read_dword(hud_address + 112) -- ID of the player biped object
        local flashlight = read_word(hud_address + 116)     -- 1 if flashlight is on
        local flashlight_timer = read_word(hud_address + 118) -- counts up to like 176 and resets when flashlight is on
        local shield_recharge = read_dword(hud_address + 120) -- number increases when shields are down and decreases as they charge
        local some_damage = read_dword(hud_address + 124)   -- number changes when getting damaged, not sure what this means
        local shield_recharge2 = read_dword(hud_address + 128) -- number changes when shields are charging, not sure what this means
        local shield_recharge3 = read_dword(hud_address + 132) -- number changes when shields are charging, not sure what this means
        local shield_down = read_dword(hud_address + 136)   -- number changes when shields are down and not recharging
        -- 140 - 168 - unknown
        local unknown = read_dword(hud_address + 172)       -- always 0?
        local some_timer = read_dword(hud_address + 176)    -- changes only in some vehicles. Probably related to the time since the game started
        local some_timer2 = read_dword(hud_address + 180)   -- changes only in some vehicles. Time when the player entered the vehicle?
        local some_timer3 = read_dword(hud_address + 184)   -- usually 1 but counts up on some maps?
        -- 188 - unknown
        local some_timer4 = read_dword(hud_address + 192)   -- counts up every 16 ticks. I think it has to do with low ammo/shields blinking
        local some_timer5 = read_dword(hud_address + 196)   -- counts up every 16 ticks when zoomed in
        -- 200 - 204 - unknown
        local weapon_object = read_dword(hud_address + 208) -- current weapon ID (applies to vehicle weapons too!)
        local grenade_timer = read_dword(hud_address + 212) -- sometimes changes when throwing a grenade
        local reticle_is_red = read_dword(hud_address + 216) -- turns to 1 when reticle is red
        local zoom_level = read_dword(hud_address + 220)    -- for HUD only. Zoom level that is shown on the hud
        -- 224 - unknown
        local should_reload_warning = read_dword(hud_address + 228) -- time when weapon shows "should reload" warning
        -- 232 - 236 - unknown
        local low_battery_warning = read_dword(hud_address + 240) -- time when weapon shows "flash battery" warning
        local reloading_warning = read_dword(hud_address + 244) -- time when weapon shows "reload/overheat" warning
        local no_ammo_warning = read_dword(hud_address + 248) -- time when weapon shows "flash when firing and no ammo" warning
        local no_grenades_warning = read_dword(hud_address + 252) -- time when weapon shows "flash when throwing and no grenades" warning
        local low_ammo_warning = read_dword(hud_address + 256) -- time when weapon shows "low ammo and none left to reload" warning
        -- 260 - 288 - unknown

        -- hud_address+292 - Here is a bitmask of which reticle warning should be shown. They match the order of crosshair type in the tag. Can use this to hide reticle and stuff

        -- 294 - 344 - unknown
    end

    function fp()
        fp_anim_address = 0x40000EB8                         -- from aLTis
        game_time = read_dword(fp_anim_address)              -- time since map was started
        some_timer = read_byte(fp_anim_address + 4)          -- counts up to 9 and resets?
        unknown = read_byte(fp_anim_address + 5)             -- always 0
        loading = read_byte(fp_anim_address + 6)             -- is 0 when game is loading
        unknown = read_byte(fp_anim_address + 7)             -- always 0
        fp_is_rendered = read_byte(fp_anim_address + 8)      -- changes to 1 when fp is rendered
        unknown = read_byte(fp_anim_address + 9)             -- always 0
        unknown = read_byte(fp_anim_address + 10)            -- always 0
        unknown = read_byte(fp_anim_address + 11)            -- always 0
        biped_obj_id = read_dword(fp_anim_address + 12)      -- player biped object
        weapon_obj_id = read_dword(fp_anim_address + 16)     -- first person weapon object
        unknown = read_byte(fp_anim_address + 20)            -- changes when a new base animation plays
        unknown = read_byte(fp_anim_address + 21)            -- always 0
        unknown = read_word(fp_anim_address + 22)            -- no idea
        posing_anim_timer = read_word(fp_anim_address + 24)  -- counts up until posing animation plays
        some_timer = read_word(fp_anim_address + 26)         -- counts down from 30 to 0?
        unknown = read_word(fp_anim_address + 28)            -- changes every time you switch weapons
        weapon_base_anim_id = read_word(fp_anim_address + 30) -- ID of the base animation from fp animations tag currently playing
        weapon_base_anim_frame = read_word(fp_anim_address + 32) -- frame of the base animation
        weapon_moving_anim_id = read_word(fp_anim_address + 34) -- ID of the moving animation from fp animations tag currently playing
        weapon_moving_anim_frame = read_word(fp_anim_address + 36) -- frame of the moving animation
        unknown = read_word(fp_anim_address + 38)            -- always 0
        unknown = read_word(fp_anim_address + 40)            -- always 0xFFFF
        unknown = read_word(fp_anim_address + 42)
        -- 0s here
        weapon_firing_amount = read_float(fp_anim_address + 48) -- increases to 1 when firing
        weapon_firing_vel = read_float(fp_anim_address + 52) -- changes based on whether the gun moves backwards or forwards when firing/not firing
        moving_forward_amount = read_float(fp_anim_address + 56)
        moving_left_amount = read_float(fp_anim_address + 60)
        moving_forward_vel = read_float(fp_anim_address + 64)
        moving_left_vel = read_float(fp_anim_address + 68)
        aim_left_amount = read_float(fp_anim_address + 72)
        aim_down_amount = read_float(fp_anim_address + 76)
        aim_left_vel = read_float(fp_anim_address + 80)
        aim_down_vel = read_float(fp_anim_address + 84)
        unknown = read_dword(fp_anim_address + 88) -- always 1 (also rotation?)

        fp_rot1 = read_float(fp_anim_address + 92)
        fp_rot2 = read_float(fp_anim_address + 96)
        fp_rot3 = read_float(fp_anim_address + 100)
        fp_rot4 = read_float(fp_anim_address + 104)
        fp_rot5 = read_float(fp_anim_address + 108)
        fp_rot6 = read_float(fp_anim_address + 112)
        fp_rot7 = read_float(fp_anim_address + 116)
        fp_x = read_float(fp_anim_address + 120)
        fp_y = read_float(fp_anim_address + 124)
        fp_z = read_float(fp_anim_address + 128)
        fp_x2 = read_float(fp_anim_address + 132)
        fp_y2 = read_float(fp_anim_address + 136)
        fp_z2 = read_float(fp_anim_address + 140)
        some_timer = read_dword(fp_anim_address + 144) -- counts up to 6 after animation switches
        -- from here on it's just node data which sadly cannot be changed

        fp_weapon_nodes_address = 0x40002C4C            -- apparently there's more useful stuff here after node data!
        render_fp_weapon = read_byte(fp_weapon_nodes_address) -- setting to 0 disables weapon
        --here is the node indexes for fp weapon, you can change them for interesting results :v


        more_fp_address = 0x40002CCE
        render_fp_hands = read_byte(more_fp_address) -- setting to 0 disables fp hands
        --here is the node indexes for fp hands, you can change them for interesting results :v
    end

    function camera_stuff()
        camera_address = 0x647498
        camera_type = read_word(camera_address)               -- from giraffe. 22192-scripted, 30400-first person, 30704-devcam, 31952-vehicle, 23776-dead camera
        camera_interpolation_scale = read_float(camera_address - 4) -- only changes when entering or leaving a vehicle (from aLTis)
        --unknown = read_word(camera_address + 2) -- always 68. maybe related to camera_address itself? (from aLTis)
        camera_object_id = read_dword(camera_address + 12)    -- the object camera is tracking when vehicle camera is active (from aLTis)
        vehicle_seat = read_word(camera_address + 16)         -- vehicle seat when vehicle camera is active (from aLTis)

        devcam_x = read_float(camera_address + 4)             -- (from aLTis)
        devcam_y = read_float(camera_address + 8)             -- (from aLTis)
        devcam_z = read_float(camera_address + 12)            -- (from aLTis)
        devcam_yaw = read_float(camera_address + 16)          -- (from aLTis)
        devcam_pitch = read_float(camera_address + 20)        -- (from aLTis)
        devcam_roll = read_float(camera_address + 24)         -- (from aLTis)

        camera_track_scale = read_float(camera_address + 28)  -- 0 means camera track is ignored, 1 means default camera track amount (from aLTis)
        death_camera_distance = read_float(camera_address + 32) -- has something to do with how far away the death camera is from the biped (from aLTis)

        -- values below seem to be read only
        camera_rot_x = read_float(camera_address + 0x74)        -- rotation of the camera
        camera_rot_y = read_float(camera_address + 0x78)        -- rotation of the camera
        camera_rot_z = read_float(camera_address + 0x7C)        -- rotation of the camera
        camera_some_rot1 = read_float(camera_address + 0x80)    -- rotation of the camera
        camera_some_rot2 = read_float(camera_address + 0x84)    -- rotation of the camera
        camera_some_rot3 = read_float(camera_address + 0x88)    -- rotation of the camera
        camera_vel_x = read_float(camera_address + 0x8C)        -- rotation of the camera
        camera_vel_y = read_float(camera_address + 0x90)        -- rotation of the camera
        camera_vel_z = read_float(camera_address + 0x94)        -- rotation of the camera
        camera_veh_acc_scale = read_float(camera_address + 0x98) -- changes when entering/leaving a vehicle
        camera_zoom_acc_scale = read_float(camera_address + 0x9C) -- seems to change when zooming in/out??? idk
        camera_unknown = read_dword(camera_address + 0xA0)      -- equals 3 when not in vehicle
        camera_veh_enter_scale = read_dword(camera_address + 0xA4) -- changes only when entering a vehicle
        camera_veh_enter_scale2 = read_dword(camera_address + 0xA8) -- changes only when entering a vehicle
        camera_veh_enter_scale3 = read_dword(camera_address + 0xAC) -- changes only when entering a vehicle
        camera_veh_and_zoom_scale = read_dword(camera_address + 0xB0) -- changes when entering/leaving veh and zooming in/out
        camera_veh_enter_scale4 = read_dword(camera_address + 0xB4) -- changes only when entering a vehicle
        camera_unknown2 = read_float(camera_address + 0xB8)     -- always 0?
        devcam_speed = read_float(camera_address + 0xBC)        -- the devcam speed you can adjust using scroll wheel
        devcam_up = read_float(camera_address + 0xC0)
        devcam_up_vel = read_dword(camera_address + 0xC4)
        devcam_up_vel2 = read_float(camera_address + 0xC8) -- same as above?
        devcam_roll = read_float(camera_address + 0xCC) -- seems to be roll of devcam in radians
        devcam_roll_vel = read_dword(camera_address + 0xD0)
        devcam_roll_vel2 = read_dword(camera_address + 0xD4) -- same as above?
        devcam_forward = read_dword(camera_address + 0xD8)
        devcam_forward_vel = read_dword(camera_address + 0xDC)
        devcam_forward_vel2 = read_dword(camera_address + 0xE0) -- same as above?
        devcam_left = read_dword(camera_address + 0xE4)
        devcam_left_vel = read_dword(camera_address + 0xE8)
        devcam_left_vel2 = read_dword(camera_address + 0xEC) -- same as above?
        -- unknown value 0xF0 - 0xF8
        camera_unknown3 = read_dword(camera_address + 0xFC) -- equals 9 when in menu or cutscene but 1 when playing
        camera_x = read_float(camera_address + 0x100)
        camera_y = read_float(camera_address + 0x104)
        camera_z = read_float(camera_address + 0x108)
        vehicle_camera_rot = read_float(camera_address + 0x10C) -- not too sure what these are, maybe autocentering or camera track related?
        vehicle_camera_rot2 = read_float(camera_address + 0x110)
        vehicle_camera_rot3 = read_float(camera_address + 0x114)
        vehicle_camera_rot4 = read_float(camera_address + 0x118)
        camera_unknown3 = read_dword(camera_address + 0x11C) -- changes when switched to devcam?
        camera_rot_x2 = read_float(camera_address + 0x120)
        camera_rot_y2 = read_float(camera_address + 0x124)
        camera_rot_z2 = read_float(camera_address + 0x128)
        camera_rot_x3 = read_float(camera_address + 0x12C)
        camera_rot_y3 = read_float(camera_address + 0x130)
        camera_rot_z3 = read_float(camera_address + 0x134)
        camera_x_vel = read_float(camera_address + 0x138)
        camera_y_vel = read_float(camera_address + 0x13C)
        camera_z_vel = read_float(camera_address + 0x140)
        camera_veh_acc_scale2 = read_float(camera_address + 0x144)
        camera_first_person = read_dword(camera_address + 0x148) -- 3 when in fp, 0 when tp
        camera_first_person2 = read_dword(camera_address + 0x14C) -- same as above
        camera_veh_enter_scale5 = read_float(camera_address + 0x150) -- why are there so many of these
        camera_veh_enter_scale6 = read_float(camera_address + 0x154) -- just why
        camera_veh_enter_scale7 = read_float(camera_address + 0x158) -- pls
        camera_veh_enter_scale8 = read_float(camera_address + 0x15C) -- why
        camera_veh_enter_scale9 = read_float(camera_address + 0x160) -- stop
        camera_unknown4 = read_dword(camera_address + 0x164)   -- no idea
        camera_x2 = read_float(camera_address + 0x168)
        camera_y2 = read_float(camera_address + 0x16C)
        camera_z2 = read_float(camera_address + 0x170)
        camera_cluster_id = read_dword(camera_address + 0x174)  -- not 100% sure it's correct but yea..\
        camera_cluster_id2 = read_word(camera_address + 0x178)
        camera_unknown5 = read_word(camera_address + 0x17A)     -- no idea
        camera_veh_enter_scale10 = read_float(camera_address + 0x17C) -- how many more
        camera_veh_enter_scale11 = read_float(camera_address + 0x180) -- ...
        camera_veh_enter_scale12 = read_float(camera_address + 0x184) -- what are these why are there so many aaaa
        camera_rot_x4 = read_float(camera_address + 0x188)
        camera_rot_y4 = read_float(camera_address + 0x18C)
        camera_rot_z4 = read_float(camera_address + 0x190)
        camera_rot_x5 = read_float(camera_address + 0x194)
        camera_rot_y5 = read_float(camera_address + 0x198)
        camera_rot_z5 = read_float(camera_address + 0x19C)
        camera_fov = read_float(camera_address + 0x1A0) -- wow finally something almost useful I guess
        camera_x3 = read_float(camera_address + 0x1A4)
        camera_y3 = read_float(camera_address + 0x1A8)
        camera_z3 = read_float(camera_address + 0x1AC)
        vehicle_camera_rot5 = read_float(camera_address + 0x1B0)
        vehicle_camera_rot6 = read_float(camera_address + 0x1B4)
        vehicle_camera_rot7 = read_float(camera_address + 0x1B8)
        vehicle_camera_rot8 = read_float(camera_address + 0x1BC)
        camera_fov2 = read_float(camera_address + 0x1C0)
        camera_rot_x6 = read_float(camera_address + 0x1C4)
        camera_rot_y6 = read_float(camera_address + 0x1C8)
        camera_rot_z6 = read_float(camera_address + 0x1CC)
        camera_rot_x7 = read_float(camera_address + 0x1D0)
        camera_rot_y7 = read_float(camera_address + 0x1D4)
        camera_rot_z7 = read_float(camera_address + 0x1D8)
        camera_veh_enter_scale13 = read_float(camera_address + 0x1DC) -- ...
        camera_veh_enter_scale14 = read_float(camera_address + 0x1E0)
        camera_veh_enter_scale15 = read_float(camera_address + 0x1E4)
        camera_veh_vel1 = read_float(camera_address + 0x1E8) -- camera velocities?
        camera_veh_vel2 = read_float(camera_address + 0x1EC)
        camera_veh_vel3 = read_float(camera_address + 0x1F0)
        camera_veh_vel3 = read_float(camera_address + 0x1F4)
        camera_transitioning = read_float(camera_address + 0x1F8) -- 0x80000000 when camera is being normal and 0 when camera is switching between first and third person
        camera_veh_vel4 = read_float(camera_address + 0x1FC)
        camera_veh_vel5 = read_float(camera_address + 0x200)
        camera_veh_vel6 = read_float(camera_address + 0x204)
        -- the rest of the values seem to be really pointless so I give up...

        --camera interpolation data is stored here camera_address + 0x354
        camera_interpolation_rot_down = read_float(camera_address + 0x374)
        camera_interpolation_rot_something = read_float(camera_address + 0x378)
        camera_interpolation_rot_left = read_float(camera_address + 0x37C)
    end

    -- multiplayer announcer stuff (from aLTis)
    announcer_address = 0x64C020
    unknown = read_dword(announcer_address)
    sound_id = read_dword(announcer_address + 4)                  -- id of the sound tag from globals tag
    sound_timer = read_dword(announcer_address + 8)               -- how many ticks until the sound finishes playing
    unknown2 = read_dword(announcer_address + 12)                 -- changes to 1 when interacting with objective
    unknown3 = read_dword(announcer_address + 16)
    sound_id2 = read_dword(announcer_address + 20)                -- id of the sound tag from globals tag
    gametype = read_dword(announcer_address + 24)                 -- changes based on gametype
    announcer_currently_playing = read_dword(announcer_address + 80) -- 0 if not, 1 if true and 2 if game hasn't started. If it's 1 then new announcer sounds won't play

    --use this function to play a sound on client side

    function PlayAnnouncerSound(sound_id)
        local announcer_address = 0x64C020
        write_dword(announcer_address + 8, 1)   -- delay until the sound starts
        write_dword(announcer_address + 20, sound_id) -- not sure what this is but it makes the sound play
        write_dword(announcer_address + 80, 2)  -- announcer currently playing
    end

    --use this function to play a sound on server side

    function PlayAnnouncerSound(sound_id)
        local server_announcer_address = 0x5BDE00
        write_dword(server_announcer_address + 0x8, 1)   -- time until first sound in the queue stops playing
        write_dword(server_announcer_address + 0x14, sound_id) -- second sound ID in the queue (from globals multiplayer information > sounds)
        write_dword(server_announcer_address + 0x1C, 1)  -- second sound in the queue will play
        write_dword(server_announcer_address + 0x50, 2)  -- announcer sound queue
    end

    -- keyboard input (from aLTis)
    function keyboard_inputs()
        keyboard_input_address = 0x64C550
        esc_key = read_byte(keyboard_input_address)
        f1_key = read_byte(keyboard_input_address + 1)
        f2_key = read_byte(keyboard_input_address + 2)
        f3_key = read_byte(keyboard_input_address + 3)
        f4_key = read_byte(keyboard_input_address + 4)
        f5_key = read_byte(keyboard_input_address + 5)
        f6_key = read_byte(keyboard_input_address + 6)
        f7_key = read_byte(keyboard_input_address + 7)
        f8_key = read_byte(keyboard_input_address + 8)
        f9_key = read_byte(keyboard_input_address + 9)
        f10_key = read_byte(keyboard_input_address + 10)
        f11_key = read_byte(keyboard_input_address + 11)
        f12_key = read_byte(keyboard_input_address + 12)
        print_screen_key = read_byte(keyboard_input_address + 13)
        unknow_key = read_byte(keyboard_input_address + 14)
        pause_key = read_byte(keyboard_input_address + 15)
        unknow_key = read_byte(keyboard_input_address + 16)
        no1_key = read_byte(keyboard_input_address + 17)
        no2_key = read_byte(keyboard_input_address + 18)
        no3_key = read_byte(keyboard_input_address + 19)
        no4_key = read_byte(keyboard_input_address + 20)
        no5_key = read_byte(keyboard_input_address + 21)
        no6_key = read_byte(keyboard_input_address + 22)
        no7_key = read_byte(keyboard_input_address + 23)
        no8_key = read_byte(keyboard_input_address + 24)
        no9_key = read_byte(keyboard_input_address + 25)
        no10_key = read_byte(keyboard_input_address + 26)
        minus_key = read_byte(keyboard_input_address + 27)
        equal_key = read_byte(keyboard_input_address + 28)
        backspace_key = read_byte(keyboard_input_address + 29)
        tab_key = read_byte(keyboard_input_address + 30)
        q_key = read_byte(keyboard_input_address + 31)
        w_key = read_byte(keyboard_input_address + 32)
        e_key = read_byte(keyboard_input_address + 33)
        r_key = read_byte(keyboard_input_address + 34)
        t_key = read_byte(keyboard_input_address + 35)
        y_key = read_byte(keyboard_input_address + 36)
        u_key = read_byte(keyboard_input_address + 37)
        i_key = read_byte(keyboard_input_address + 38)
        o_key = read_byte(keyboard_input_address + 39)
        p_key = read_byte(keyboard_input_address + 40)
        open_bracket_key = read_byte(keyboard_input_address + 41)
        close_bracket_key = read_byte(keyboard_input_address + 42)
        backslash_key = read_byte(keyboard_input_address + 43)
        caps_lock_key = read_byte(keyboard_input_address + 44)
        a_key = read_byte(keyboard_input_address + 45)
        s_key = read_byte(keyboard_input_address + 46)
        d_key = read_byte(keyboard_input_address + 47)
        f_key = read_byte(keyboard_input_address + 48)
        g_key = read_byte(keyboard_input_address + 49)
        h_key = read_byte(keyboard_input_address + 50)
        j_key = read_byte(keyboard_input_address + 51)
        k_key = read_byte(keyboard_input_address + 52)
        l_key = read_byte(keyboard_input_address + 53)
        colon_key = read_byte(keyboard_input_address + 54)
        quote_key = read_byte(keyboard_input_address + 55)
        enter_key = read_byte(keyboard_input_address + 56)
        shift_key = read_byte(keyboard_input_address + 57)
        z_key = read_byte(keyboard_input_address + 58)
        x_key = read_byte(keyboard_input_address + 59)
        c_key = read_byte(keyboard_input_address + 60)
        v_key = read_byte(keyboard_input_address + 61)
        b_key = read_byte(keyboard_input_address + 62)
        n_key = read_byte(keyboard_input_address + 63)
        m_key = read_byte(keyboard_input_address + 64)
        comma_key = read_byte(keyboard_input_address + 65)
        period_key = read_byte(keyboard_input_address + 66)
        forward_slash_key = read_byte(keyboard_input_address + 67)
        right_shift_key = read_byte(keyboard_input_address + 68)
        ctrl_key = read_byte(keyboard_input_address + 69)
        unknown_key = read_byte(keyboard_input_address + 70)
        alt_key = read_byte(keyboard_input_address + 71)
        space_key = read_byte(keyboard_input_address + 72)
        right_alt_key = read_byte(keyboard_input_address + 73)
        unknown_key = read_byte(keyboard_input_address + 74)
        menu_key = read_byte(keyboard_input_address + 75)
        right_ctrl_key = read_byte(keyboard_input_address + 76)
        up_arrow_key = read_byte(keyboard_input_address + 77)
        down_arrow_key = read_byte(keyboard_input_address + 78)
        left_arrow_key = read_byte(keyboard_input_address + 79)
        right_arrow_key = read_byte(keyboard_input_address + 80)
        d_key = read_byte(keyboard_input_address + 81)
        home_key = read_byte(keyboard_input_address + 82)
        page_up_key = read_byte(keyboard_input_address + 83)
        delete_key = read_byte(keyboard_input_address + 84)
        end_key = read_byte(keyboard_input_address + 85)
        page_down_key = read_byte(keyboard_input_address + 86)
        num_lock_key = read_byte(keyboard_input_address + 87)
        num_division_key = read_byte(keyboard_input_address + 88)
        num_multiply_key = read_byte(keyboard_input_address + 89)
        num_0_key = read_byte(keyboard_input_address + 90)
        num_1_key = read_byte(keyboard_input_address + 91)
        num_2_key = read_byte(keyboard_input_address + 92)
        num_3_key = read_byte(keyboard_input_address + 93)
        num_4_key = read_byte(keyboard_input_address + 94)
        num_5_key = read_byte(keyboard_input_address + 95)
        num_6_key = read_byte(keyboard_input_address + 96)
        num_7_key = read_byte(keyboard_input_address + 97)
        num_8_key = read_byte(keyboard_input_address + 98)
        num_9_key = read_byte(keyboard_input_address + 99)
        num_minus_key = read_byte(keyboard_input_address + 100)
        num_plus_key = read_byte(keyboard_input_address + 101)
        num_enter_key = read_byte(keyboard_input_address + 102)
        num_comma_key = read_byte(keyboard_input_address + 103)
    end

    -- text input (from aLTis)
    chat_is_open = read_byte(0x64E788)

    text_input_address = 0x64C62C
    unknown = read_word(text_input_address) -- changes to 1 sometimes

    -- formatting bitmask (from aLTis)
    shift_key = read_bit(text_input_address + 2, 0)
    alt_key = read_bit(text_input_address + 2, 1)
    ctrl_key = read_bit(text_input_address + 2, 2)
    unknown_key = read_bit(text_input_address + 2, 3)
    unknown_key = read_bit(text_input_address + 2, 4)
    unknown_key = read_bit(text_input_address + 2, 5)
    unknown_key = read_bit(text_input_address + 2, 6)
    unknown_key = read_bit(text_input_address + 2, 7)

    character = read_char(text_input_address + 3) -- character with correct formatting
    character2 = read_char(text_input_address + 4) -- character but with different formatting
    unknown = read_char(text_input_address + 5)   -- changes to 0xFF when holding control + character or when sending a chat message
    unknown = read_char(text_input_address + 6)   -- always 0
    editing_keys = read_char(text_input_address + 7) -- possibly bitmask? 27 when esc, 13 when enter and 8 when backspace
    unknown = read_word(text_input_address + 8)   -- changes to 0xFFFF sometimes and goes to 0 when tabbing out


    -- mouse input (from aLTis)
    mouse_input_address = 0x64C73C
    mouse_right = read_long(mouse_input_address)         -- how fast mouse is moving right
    mouse_up = read_long(mouse_input_address + 4)        -- how fast mouse is moving up
    mouse_scroll_wheel = read_char(mouse_input_address + 8) -- 1 when scrolling down, -1 when up and 0 when not scrolling
    mouse_left_click = read_byte(mouse_input_address + 12)
    mouse_scroll_wheel_click = read_byte(mouse_input_address + 13)
    mouse_right_click = read_byte(mouse_input_address + 14)
    mouse_button_4_click = read_byte(mouse_input_address + 15)
    mouse_button_5_click = read_byte(mouse_input_address + 16)
    mouse_left_click_release = read_byte(mouse_input_address + 20)
    mouse_scroll_wheel_release = read_byte(mouse_input_address + 21)
    mouse_right_click_release = read_byte(mouse_input_address + 22)
    mouse_button_4_release = read_byte(mouse_input_address + 23)
    mouse_button_5_release = read_byte(mouse_input_address + 24)

    mouse_sensitivity_horizontal = 0x6ABB50
    mouse_sensitivity_vertical = 0x6ABB54
    --controller sensitivity here as well? I haven't tested

    -- controller input (from aLTis)
    for controller_id = 0, 3 do
        controller_input_address = 0x64D998 + controller_id * 0xA0
        controller_a = read_char(controller_input_address)
        controller_b = read_char(controller_input_address + 1)
        controller_x = read_char(controller_input_address + 2)
        controller_y = read_char(controller_input_address + 3)
        controller_lb = read_char(controller_input_address + 4)
        controller_rb = read_char(controller_input_address + 5)
        controller_back = read_char(controller_input_address + 6)
        controller_start = read_char(controller_input_address + 7)
        controller_ls = read_char(controller_input_address + 8)
        controller_rs = read_char(controller_input_address + 9)
        -- there is probably more buttons here for other controllers, I only tested x360
        controller_ls_down = read_long(controller_input_address + 30)
        controller_ls_right = read_long(controller_input_address + 32)
        controller_rs_down = read_long(controller_input_address + 34)
        controller_rs_right = read_long(controller_input_address + 36)
        controller_trigger = read_long(controller_input_address + 38) -- this value is for both left and right triggers
        -- ?
        controller_dpad = read_word(controller_input_address + 96) -- 0xFFFF when nothing is pressed, 0-up, 2-right, 4-down, 6-left
    end

    GetGameAddresses(Game) -- declare addresses and confirm the game (pc or ce)
    game = Game
    -- gametype info

    gametype_name = readwidestring(gametype_base, 0x2C)                -- Confirmed. Real name of gametype.
    gametype_game = read_byte(gametype_base + 0x30)                    -- Confirmed. (CTF = 1) (Slayer = 2) (Oddball = 3) (KOTH = 4) (Race = 5)
    gametype_team_play = read_byte(gametype_base + 0x34)               -- Confirmed. (Off = 0) (On = 1)
    --	gametype parameters
    gametype_other_players_on_radar = read_bit(gametype_base + 0x38, 0) -- Confirmed. (On = True, Off = False)
    gametype_friends_indicator = read_bit(gametype_base + 0x38, 1)     -- Confirmed. (On = True, Off = False)
    gametype_infinite_grenades = read_bit(gametype_base + 0x38, 2)     -- Confirmed. (On = True, Off = False)
    gametype_shields = read_bit(gametype_base + 0x38, 3)               -- Confirmed. (Off = True, On = False)
    gametype_invisible_players = read_bit(gametype_base + 0x38, 4)     -- Confirmed. (On = True, Off = False)
    gametype_starting_equipment = read_bit(gametype_base + 0x38, 5)    -- Confirmed. (Generic = True, Custom = False)
    gametype_only_friends_on_radar = read_bit(gametype_base + 0x38, 6) -- Confirmed.
    --	unkBit[7] 0. - always 0?
    gametype_indicator = read_byte(gametype_base + 0x3C)               -- Confirmed. (Motion Tracker = 0) (Nav Points = 1) (None = 2)
    gametype_odd_man_out = read_byte(gametype_base + 0x40)             -- Confirmed. (No = 0) (Yes = 1)
    gametype_respawn_time_growth = read_dword(gametype_base + 0x44)    -- Confirmed. (1 sec = 30 ticks)
    gametype_respawn_time = read_dword(gametype_base + 0x48)           -- Confirmed. (1 sec = 30 ticks)
    gametype_suicide_penalty = read_dword(gametype_base + 0x4C)        -- Confirmed. (1 sec = 30 ticks)
    gametype_lives = read_byte(gametype_base + 0x50)                   -- Confirmed. (Unlimited = 0)
    gametype_maximum_health = read_float(gametype_base + 0x54)         -- Confirmed.
    gametype_score_limit = read_byte(gametype_base + 0x58)             -- Confirmed.
    gametype_weapons = read_byte(gametype_base + 0x5C)                 -- Confirmed. (Normal = 0) (Pistols = 1) (Rifles = 2) (Plasma Weapons = 3) (Sniper = 4) (No Sniping = 5) (Rocket Launchers = 6) (Shotguns = 7) (Short Range = 8) (Human = 9) (Convenant = 10) (Classic = 11) (Heavy Weapons = 12)
    gametype_red_vehicles = read_dword(gametype_base + 0x60)           -- (???) Binary?
    gametype_blue_vehicles = read_dword(gametype_base + 0x64)          -- (???) Binary?
    gametype_vehicle_respawn_time = read_dword(gametype_base + 0x68)   -- Confirmed. (1 sec = 30 ticks)
    gametype_friendly_fire = read_byte(gametype_base + 0x6C)           -- Confirmed. (Off = 0) (On = 1)
    gametype_friendly_fire_penalty = read_dword(gametype_base + 0x70)  -- Confirmed. (1 sec = 30 ticks)
    gametype_auto_team_balance = read_byte(gametype_base + 0x74)       -- Confirmed. (Off = 0) (On = 1)
    gametype_time_limit = read_dword(gametype_base + 0x78)             -- Confirmed. (1 sec = 30 ticks)
    gametype_ctf_assault = read_byte(gametype_base + 0x7C)             -- Confirmed. (No = 0) (Yes = 1)
    gametype_koth_moving_hill = read_byte(gametype_base + 0x7C)        -- Confirmed. (No = 0) (Yes = 1)
    gametype_oddball_random_start = read_byte(gametype_base + 0x7C)    -- Confirmed. (No = 0) (Yes = 1)
    gametype_race_type = read_byte(gametype_base + 0x7C)               -- Confirmed. (Normal = 0) (Any Order = 1) (Rally = 2)
    gametype_slayer_death_bonus = read_byte(gametype_base + 0x7c)      -- Confirmed. (Yes = 0) (No = 1)
    gametype_slayer_kill_penalty = read_byte(gametype_base + 0x7D)     -- Confirmed. (Yes = 0) (No = 1)
    gametype_ctf_flag_must_reset = read_byte(gametype_base + 0x7E)     -- Confirmed. (No = 0) (Yes = 1)
    gametype_slayer_kill_in_order = read_byte(gametype_base + 0x7E)    -- Confirmed. (No = 0) (Yes = 1)
    gametype_ctf_flag_at_home_to_score = read_byte(gametype_base + 0x7F) -- Confirmed. (No = 0) (Yes = 1)
    gametype_ctf_single_flag_time = read_dword(gametype_base + 0x80)   -- Confirmed. (1 sec = 30 ticks)
    gametype_oddball_speed_with_ball = read_byte(gametype_base + 0x80) -- Confirmed. (Slow = 0) (Normal = 1) (Fast = 2)
    gametype_race_team_scoring = read_byte(gametype_base + 0x80)       -- Confirmed. (Minimum = 0) (Maximum = 1) (Sum = 2)
    gametype_oddball_trait_with_ball = read_byte(gametype_base + 0x84) -- Confirmed. (None = 0) (Invisible = 1) (Extra Damage = 2) (Damage Resistant = 3)
    gametype_oddball_trait_without_ball = read_byte(gametype_base + 0x88) -- Confirmed. (None = 0) (Invisible = 1) (Extra Damage = 2) (Damage Resistant = 3)
    gametype_oddball_ball_type = read_byte(gametype_base + 0x8C)       -- Confirmed. (Normal = 0) (Reverse Tag = 1) (Juggernaut = 2)
    gametype_oddball_ball_spawn_count = read_byte(gametype_base + 0x90) -- Confirmed.
    gametype_koth_moving_hill = read_byte(gametype_base + 0x9C)        -- Confirmed. (No = 0) (Yes = 1) (from aLTis) means assault too apparently

    --mapcycle header
    mapcycle_pointer = read_dword(mapcycle_header)                     -- (???) index * 0xA4 + 0xC + this = something.
    mapcycle_total_indicies = read_dword(mapcycle_header + 0x4)        -- From DZS. Number of options in the mapcycle.
    mapcycle_total_indicies_allocated = read_dword(mapcycle_header + 0x8) -- From Phasor.
    mapcycle_current_index = read_dword(mapcycle_header + 0xC)         -- Confirmed. Current mapcycle index.

    --mapcycle struct
    mapcycle_something = readwidestring(mapcycle_pointer + mapcycle_current_index * 0xE4 + 0xC) -- (???) LOTS OF BAADF00D!
    mapcycle_current_map_name = read_string(read_dword(mapcycle_pointer))                    -- Confirmed. Real name of the map.
    mapcycle_current_gametype_name = read_string(read_dword(mapcycle_pointer + 0x4))         -- Confirmed. Real name of the gametype. Case-sensitive.
    mapcycle_current_gametype_name2 = readwidestring(mapcycle_pointer + 0xC)                 -- Confirmed. Real name of gametype. Case-sensitive.

    --Server globals
    server_initialized = read_bit(network_server_globals, 0)                 -- Tested.
    server_last_display_time = read_dword(network_server_globals + 0x4)      -- From OS.
    server_password = read_string(network_server_globals + 0x8, 8)           -- Confirmed.
    server_single_flag_force_reset = read_bit(network_server_globals + 0x10, 0) -- Confirmed.
    server_banlist_path = read_string(network_server_globals + 0x1C)         -- Confirmed. Path to the banlist file.
    server_friendly_fire_type = read_word(network_server_globals + 0x120)    -- Tested. Something to do with the friendly fire.
    server_rcon_password = read_string(network_server_globals + 0x128)       -- Confirmed.
    if game == "CE" then
        server_motd_filename = read_string(network_server_globals + 0x13C, 0x100) -- From OS.
        server_motd_contents = read_string(network_server_globals + 0x23C, 0x100) -- From OS.
    end

    --banlist header
    banlist_size = read_dword(banlist_header)
    banlist_base = read_dword(banlist_header + 0x4)

    --banlist struct
    banlist_struct_size = 0x44
    for j = 1, banlist_size do
        ban_name = readwidestring(banlist_base + j * 0x44, 13)   -- Confirmed. Name of banned player.
        ban_hash = read_string(banlist_base + j * 0x44 + 0x1A, 32) -- Confirmed. Hash of banned player.
        ban_some_bool = read_bit(banlist_base + j * 0x44 + 0x3A, 0) -- (???)
        ban_count = read_word(banlist_base + j * 0x44 + 0x3C)    -- Confirmed. How many times the specified player has been banned.
        ban_indefinitely = read_bit(banlist_base + j * 0x44 + 0x3E, 0) -- Confirmed. 1 if permanently banned, 0 if not.
        ban_time = read_dword(banlist_base + j * 0x44 + 0x40)    -- Confirmed. Ban end date.
    end

    --String/data addresses that aren't in a struct/header (to my knowledge).
    server_broadcast_version = read_string(broadcast_version_address) -- Confirmed. Version that the server is broadcasting on.
    version_info = read_string(version_info_address, 0x2A)         -- Confirmed. Some version info for halo
    halo_broadcast_game = read_string(broadcast_game_address, 5)   -- Confirmed. Basically determines whether the server will broadcast on PC/CE/Trial ("halor" = PC, "halom" = CE, "halo?" = Trial).
    server_port = read_dword(server_port_address)                  -- Confirmed. Port that the server is broadcasting on.
    server_path = read_string(server_path_address)                 -- Confirmed. Path to the server's haloded.exe
    server_computer_name = read_string(computer_name_address)      -- Confirmed. Server Computer (domain) name.
    profile_path = read_string(profile_path_address)               -- Confirmed. Path to the profile path.
    map_name = readwidestring(map_name_address)                    -- Confirmed. Halo's map name (e.g. Blood Gulch)
    computer_specs = read_string(computer_specs_address)           -- Confirmed. Some address I found that stores information about the server (processor speed, brand)
    map_name2 = read_string(map_name_address2)                     -- Confirmed. Map file name. (e.g. bloodgulch)
    server_password = read_string(server_password_address, 8)      -- Confirmed. Current server password for the server (will be nullstring if there is no password)
    banlist_path = read_string(banlist_path_address)               -- Confirmed. Path to the banlist file.
    rcon_password = read_string(rcon_password_address, 8)          -- Confirmed. Current rcon password for the server.

    -- random unuseful crap (string stuff) don't care enough to do CE
    -- don't know why I even cared enough to write these down.
    if game == "PC" then
        halo_profilepath_cmdline = read_string(0x5D45B0, 5) -- Confirmed. The -path cmdline string.
        halo_cpu_cmdline = read_string(0x5E4760, 4)   -- Confirmed. The -cpu cmdline string.
        halo_broadcast_game = read_string(0x5E4768, 5) -- Confirmed. Basically determines whether the server will broadcast on PC/CE/Trial ("halor" = PC, "halom" = CE, "halo?" = Trial).
        halo_ip_cmdline = read_string(0x5E4770, 3)    -- Confirmed. The -ip cmdline string.
        halo_port_cmdline = read_string(0x5E4774, 5)  -- Confirmed. The -port cmdline string.
        halo_checkfpu_cmdline = read_string(0x5E477C, 9) -- Confirmed. The -checkfpu cmdline string.
        halo_windowname = read_string(0x5E4788, 4)    -- "The console windowname and classname (basically windowtitle, always 'Halo Console (#)').
        --0x5E4790 - 0x5E473C is registry key stuff
        halo_dw15_exe_path = read_string(0x5E4940, 26) --Confirmed. Path to dw15.exe (.\Watson\dw15.exe -x -s %u) probably from client code.
        --other random crap/strings here
    end
end

-- All of these are confirmed, unless said otherwise.
function GetGameAddresses(game)
    -- Structs/headers. -- these should be lower by 0x20
    stats_header = 0x5BD740
    stats_globals = 0x5BD8B8
    ctf_globals = 0x5BDBB8 -- tested value = 0x5BDB98 0x64BDB8 ??????
    slayer_globals = 0x5BE108
    oddball_globals = 0x5BDE78
    koth_globals = 0x5BDBF0 -- tested value = 0x5BDBD0
    race_globals = 0x5BDFC0
    race_locs = 0x5F5098
    map_pointer = 0x5B927C
    gametype_base = 0x5F5498 -- is it 0x5F5478 ?? or maybe 0x68CC48 ????
    network_struct = 0x6C7980
    camera_base = 0x62075C
    player_globals = 0x6E1478 -- From OS.
    player_header_pointer = 0x6E1480
    obj_header_pointer = 0x6C69F0
    collideable_objects_pointer = 0x6C6A14
    map_header_base = 0x6E2CA4
    banlist_header = 0x5C52A0
    game_globals = 0x61CFE0 -- (???)
    gameinfo_header = 0x5F55BC
    mapcycle_header = 0x598A8C
    network_server_globals = 0x61FB64
    hash_table_base = 0x5AFB34

    -- String/Data Addresses.
    broadcast_version_address = 0x564B34
    version_info_address = 0x565104
    broadcast_game_address = 0x569EAC
    server_port_address = 0x5A91A0
    server_path_address = 0x5B0670
    computer_name_address = 0x5B0D40
    profile_path_address = 0x5B9630
    map_name_address = 0x5BFC98
    computer_specs_address = 0x5E6E5C
    map_name_address2 = 0x61D151
    server_password_address = 0x61FB6C
    banlist_path_address = 0x61FB80
    rcon_password_address = 0x61FC8C


    --Patches
    hashcheck_patch = 0x530130
    servername_patch = 0x4CE0CD
    versioncheck_patch = 0x4CB587
end

function OnClientUpdate(player, objectId)
    local thisHash = gethash(player)
    local team = getteam(player)

    if thisHash ~= nil then
        -- Confirmed/tested addresses and offsets
        -- teams: red = 0, blue = 1

        --stats header (size = 0x178 = 376 bytes)
        --This header is seriously unfinished.
        stats_header_recorded_animations_data = read_dword(stats_header + 0x0) -- Confirmed. Pointer to Recorded Animations data table.
        --unkByte[4] 0x4-0x8 (Zero's)
        stats_header_last_decal_location_x = read_float(stats_header + 0x8) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_y = read_float(stats_header + 0xC) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_x2 = read_float(stats_header + 0x10) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_y2 = read_float(stats_header + 0x14) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_x3 = read_float(stats_header + 0x18) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_y3 = read_float(stats_header + 0x1C) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_x4 = read_float(stats_header + 0x20) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_y4 = read_float(stats_header + 0x24) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_x5 = read_float(stats_header + 0x28) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_y5 = read_float(stats_header + 0x2C) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_x6 = read_float(stats_header + 0x30) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location_y6 = read_float(stats_header + 0x34) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        --unkByte[48] 0x38-0x68 (Zero's)
        stats_header_last_decal_location2_x = read_float(stats_header + 0x68) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_y = read_float(stats_header + 0x6C) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_x2 = read_float(stats_header + 0x70) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_y2 = read_float(stats_header + 0x74) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_x3 = read_float(stats_header + 0x78) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_y3 = read_float(stats_header + 0x7C) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_x4 = read_float(stats_header + 0x80) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_y4 = read_float(stats_header + 0x84) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_x5 = read_float(stats_header + 0x88) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_y5 = read_float(stats_header + 0x8C) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_x6 = read_float(stats_header + 0x90) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        stats_header_last_decal_location2_y6 = read_float(stats_header + 0x94) -- From Silentk. World coordinates of the last bullet/nade hit anywhere on map x,y, applies to BSP only, not objects
        --unkFloat[2] 0x98-0xA0 (???)
        --unkByte[40] 0xA0-0xC8 (Zero's)
        stats_header_decalID_table = read_dword(stats_header + 0xC8) -- From Silentk. Pointer to an array of Decal ID's (correlates with LastDecalLocation)
        --unkPointer[1] 0xCC-0xD0 (???)
        --unkByte[20] 0xD0-0xE4 (???)
        stats_header_locationID = read_dword(stats_header + 0xE4) -- From Silentk
        stats_header_locationID2 = read_dword(stats_header + 0xE8) -- From Silentk
        --unkLong[1] 0xEC-0xF0 (???)
        --unkByte[130] 0xF0-0x172 (Zero's)
        --unkPointer[2] 0x172-0x17A

        --stats struct (size = 0x30 = 48 bytes)
        stats_base = stats_globals + player * 0x30
        stats_player_ingame = read_byte(stats_base + 0x0)           -- From Silentk (1 = Ingame, 0 if not)
        --unkByte[3] 0x1-0x4 (???)
        stats_player_id = readident(stats_base, 0x4)                --Confirmed. Full DWORD ID of player.
        stats_player_kills = read_word(stats_base + 0x8)            -- Confirmed.
        --unkByte[6] 0xA-0x10 (???)
        stats_player_assists = read_word(stats_base + 0x10)         -- From Silentk
        --unkByte[6] 0x12-0x18 (???)
        stats_player_betrays = read_word(stats_base + 0x18)         -- From Silentk. Actually betrays + suicides.
        stats_player_deaths = read_word(stats_base + 0x1A)          -- From Silentk Everytime you die, no matter what..
        stats_player_suicides = read_word(stats_base + 0x1C)        -- Confirmed.
        stats_player_flag_steals = read_word(stats_base + 0x1E)     -- From Silentk. Flag steals for CTF.
        stats_player_hill_time = read_word(stats_base + 0x1E)       -- Confirmed. Time for KOTH. (1 sec = 30 ticks)
        stats_player_race_time = read_word(stats_base + 0x1E)       -- Guess. Time for Race. (1 sec = 30 ticks)
        stats_player_flag_returns = read_word(stats_base + 0x20)    -- From Silentk. Flag returns for CTF.
        stats_player_oddball_target_kills = read_word(stats_base + 0x20) -- Guess. Number of times you killed the Juggernaut or It.
        stats_player_race_laps = read_word(stats_base + 0x20)       -- Guess. Laps for Race.
        stats_player_flag_scores = read_word(stats_base + 0x22)     -- From Silentk. Flag scores for CTF.
        stats_player_oddball_kills = read_word(stats_base + 0x22)   -- Guess. Number of kills you have as Juggernaut or It.
        stats_player_race_best_time = read_word(stats_base + 0x22)  -- Guess. Best time for Race. (1 sec = 30 ticks)
        --unkByte[12] 0x24-0x30 (???)

        -- ctf globals (size = 0x34 = 52 bytes)
        ctf_flag_coords_pointer = read_dword(ctf_globals + team * 4) -- Confirmed. Pointer to the coords where the flag respawns.
        ctf_flag_x_coord = read_float(ctf_flag_coords_pointer)      -- Confirmed.
        ctf_flag_y_coord = read_float(ctf_flag_coords_pointer + 0x4) -- Confirmed.
        ctf_flag_z_coord = read_float(ctf_flag_coords_pointer + 0x8) -- Confirmed.
        ctf_flag_object_id = readident(ctf_globals + team * 4 + 0x8) -- Confirmed.
        ctf_team_score = read_dword(ctf_globals + team * 4 + 0x10)  -- Confirmed.
        ctf_score_limit = read_dword(ctf_globals + 0x18)            -- Confirmed.
        ctf_team_missing_flag_bool = read_bit(ctf_globals + 0x1C + team, 0) -- Confirmed. (True if team doesn't have flag, False if their flag is at home)
        ctf_flag_istaken_red_soundtimer = read_dword(ctf_globals + 0x20) -- Confirmed. (Announcer repeats 'Red team, has the flag' after this number gets to 600 ticks = 20 seconds)
        ctf_flag_istaken_blue_soundtimer = read_dword(ctf_globals + 0x24) -- Confirmed. (Announcer repeats 'Blue team, has the flag' after this number gets to 600 ticks = 20 seconds)
        ctf_flag_swap_timer = read_dword(ctf_globals + 0x28)        -- Confirmed. Single flag only. Counts down until 0, then offense team swaps with defense team. (1 second = 30 ticks)
        ctf_failure_timer = read_dword(ctf_globals + 0x2C)          -- From OS. Sound timer for failure. Counts down until 0. (1 second = 30 ticks)
        ctf_team_on_defense = read_byte(ctf_globals + 0x30)         -- Confirmed. Team on defense (single flag gametypes) (Red = 0, Blue = 1)

        --koth globals (size = 0x200 = 512 bytes)
        --Reminder: There are 16 teams in FFA, one for each person.
        koth_team_score = read_dword(koth_globals + team * 4)              -- Confirmed. (1 second = 30 ticks)
        koth_team_last_time_in_hill = read_dword(koth_globals + player * 4 + 0x40) -- Confirmed. gameinfo_current_time - this = time since team was last in the hill. (1 sec = 30 ticks)
        koth_player_in_hill = read_byte(koth_globals + player + 0x80)      -- Confirmed. (1 if in hill, 0 if not)
        koth_hill_marker_count = read_dword(koth_globals + 0x90)           -- Confirmed. Number of hill markers.
        --These are coordinates for each hill marker
        for i = 0, koth_hill_marker_count - 1 do
            koth_hill_marker_x_coord = read_float(koth_globals + i * 12 + 0x94) -- X coordinate for hill marker (from aLTis: math here was wrong)
            koth_hill_marker_y_coord = read_float(koth_globals + i * 12 + 0x98) -- Y coordinate for hill marker
            koth_hill_marker_z_coord = read_float(koth_globals + i * 12 + 0x9C) -- Z coordinate for hill marker
        end
        --wth... these are coordinates but they're 2 dimensional, no z axis. Probably just the area that determines if you are in a hill
        for i = 0, koth_hill_marker_count - 1 do
            koth_hill_marker_x_coord2 = read_float(koth_globals + i * 8 + 0x124) -- Tested. X coordinate for 2d hill. (from aLTis: math here was wrong
            koth_hill_marker_y_coord2 = read_float(koth_globals + i * 8 + 0x128) -- Tested. Y coordinate for 2d hill.
        end
        koth_center_of_hill_x_coord = read_float(koth_globals + 0x184) -- Confirmed. Center of hill X.
        koth_center_of_hill_y_coord = read_float(koth_globals + 0x188) -- Confirmed. Center of hill Y.
        koth_center_of_hill_z_coord = read_float(koth_globals + 0x18C) -- Confirmed. Center of hill Z.
        koth_occupied = read_dword(koth_globals + 0x190)              -- from aLTis
        koth_occupied_time = read_dword(koth_globals + 0x194)         -- from aLTis
        koth_occupied_object_id = read_dword(koth_globals + 0x198)    -- from aLTis (unconfirmed)
        koth_move_timer_real = read_dword(koth_globals + 0x1A8)       -- from aLTis (actually works)
        koth_move_timer = read_dword(koth_globals + 0x200)            -- Confirmed. (1 second = 30 ticks)

        -- oddball globals
        oddball_score_to_win = read_dword(oddball_globals)                       -- Confirmed.
        oddball_team_score = read_dword(oddball_globals + team * 4 + 0x4)        -- Confirmed. There's actually 16 teams if the gametype is FFA.
        oddball_player_score = read_dword(oddball_globals + player * 4 + 0x44)   -- Confirmed.
        --oddball_something = read_dword(oddball_globals + player*4 + 0x64) -- (???)
        oddball_ball_indexes = read_dword(oddball_globals + 0x84)                -- Tested. Idk what this is for but it holds oddball indexes that are differentiated by 0x1C2.
        oddball_it_people = read_dword(oddball_globals + 0x84)                   -- Tested. It's filled with stuff depending on the amount of 'it' people in jugg/tag
        oddball_player_holding_ball = readident(oddball_globals + player * 4 + 0xC4) -- Confirmed.
        oddball_player_time_with_ball = read_dword(oddball_globals + player * 4 + 0x104) -- Confirmed. (1 second = 30 ticks)

        --race globals
        race_checkpoint_count = read_dword(race_globals)                      -- Confirmed. Total number of checkpoints required for a lap. Stored very awkwardly. (0x1 = 1, 0x3 = 2, 0x7 = 3, 0xF = 4, 0x1F = 5 etc)
        race_player_current_checkpoint = read_dword(race_globals + player * 4 + 0x44) -- Confirmed. Current checkpoint the player needs to go to. Stored very awkwardly. (0x1 = first checkpoint, 0x3 = second checkpoint, 0x7 = 3rd checkpoint, 0xF = 4th checkpoint, 0x1F = 5th checkpoint etc)
        race_team_score = read_dword(race_globals + team * 4 + 0x88)          -- Confirmed.

        --race checkpoint locations
        for i = 0, race_checkpoint_count do
            race_checkpoint_x_coord = read_float(race_locs + i * 0x20) -- Confirmed.
            race_checkpoint_y_coord = read_float(race_locs + i * 0x20 + 0x4) -- Confirmed.
            race_checkpoint_z_coord = read_float(race_locs + i * 0x20 + 0x8) -- Confirmed.
        end

        --slayer globals
        slayer_team_score = read_dword(slayer_globals + team * 4)    -- Confirmed.
        slayer_player_score = read_dword(slayer_globals + player * 4 + 0x40) -- Confirmed.
        slayer_game = read_byte(slayer_globals + 0x20)               -- Tested. I think its always 1. I guess 1 if slayer, 0 if not? Something like that.

        -- camera struct
        camera_size = 0x30
        camera_xy = read_float(camera_base + player * camera_size)
        camera_z = read_float(camera_base + player * camera_size + 0x4)
        camera_x_aim = read_float(camera_base + player * camera_size + 0x1C)
        camera_y_aim = read_float(camera_base + player * camera_size + 0x20)
        camera_z_aim = read_float(camera_base + player * camera_size + 0x24)

        -- mp flags table (race checkpoints, hill markers, vehicle spawns, etc)
        -- REM figure out wth this is since I now know where flags really are...
        flags_table_base = read_dword(flags_pointer)         -- Tested.
        flags_count = read_dword(flags_table_base + 0x378)   -- Tested.
        flags_table_address = read_dword(flags_table_base + 0x37C) -- Tested.
        for i = 0, flags_count do                            -- i is each individual flag index
            flag_address = flags_table_address + i * 148
            flag_x_coord = read_float(flag_address)          -- Confirmed.
            flag_y_coord = read_float(flag_address + 0x4)    -- Confirmed.
            flag_z_coord = read_float(flag_address + 0x8)    -- Confirmed.
            flag_type = read_word(flag_address + 0x10)       -- Tested. (3 if race checkpoint, 6 if spawnpoint, sometimes 0 meaning something else)
            --flag_something = read_word(flag_address + 0x12) -- (???) Always 1?
            flag_tagtype = read_string(flag_address + 0x14, 4) -- Tested. It's usually ITMC or WPCL, which makes no sense...
        end

        -- player struct setup
        m_player = getplayer(player)

        -- player struct
        player_id = read_word(m_player, 0x0)                  -- Confirmed. WORD ID of this player. (0xEC70 etc)
        player_host = read_word(m_player + 0x2)               -- Confirmed. (Host = 0) (Not host = 0xFFFFFFFF)
        player_name = readwidestring(m_player + 0x4, 12)      -- Confirmed.
        --unkIdent[1] 0x1C-0x20 (???)
        player_team = read_byte(m_player + 0x20)              -- Confirmed. (Red = 0) (Blue = 1)
        --Padding[3] 0x21-0x24
        player_interaction_obj_id = readident(m_player + 0x24) -- Confirmed. Returns vehi/weap id on interaction. (does not apply to weapons you're already holding)
        player_interaction_object_type = read_word(m_player + 0x28) -- Confirmed. (Vehicle = 8, Weapon pick up = 7, Weapon swap = 6, vehicle flip = 11)
        player_interaction_vehi_seat = read_word(m_player + 0x2A) -- Confirmed. Takes seat number from vehi tag starting with 0. Warthog Seats: (0 = Driver, 1 = Gunner, 2 = Passenger)
        player_respawn_time = read_dword(m_player + 0x2C)     -- Confirmed. Counts down when dead. When 0 you respawn. (1 sec = 30 ticks)
        player_respawn_time_growth = read_dword(m_player + 0x30) -- Confirmed. Current respawn time growth for player. (1 second = 30 ticks)
        player_obj_id = readident(m_player + 0x34)            -- Confirmed.
        player_last_obj_id = readident(m_player + 0x38)       -- Confirmed. 0xFFFFFFFF if player hasn't died/hasn't had their object destroyed yet. sv_kill or kill(player) DOES NOT AFFECT THIS AT ALL.
        player_cluster_index = read_word(m_player + 0x3C)     -- Tested. Not sure what this is, but it's definitely something.
        --	bitmask16:
        player_weapon_pickup = read_bit(m_player + 0x3E, 0)   -- Confirmed. (True if picking up weapon, False if not.)
        --	bitPadding[15] 1-15
        --player_auto_aim_target_objId = readident(m_player + 0x40)	-- (???) Always 0xFFFFFFFF
        player_last_bullet_time = read_dword(m_player + 0x44) -- Confirmed. gameinfo_current_time - this = time since last shot fired. (1 second = 30 ticks). Auto_aim_update_time in OS.

        --This stuff comes directly from the client struct:
        player_name2 = readwidestring(m_player + 0x48, 12) -- Confirmed.
        player_color = read_word(m_player + 0x60)    -- Confirmed. Color of the player (FFA Gametypes Only.) (0 = white) (1 = black) (2 = red) (3 = blue) (4 = gray) (5 = yellow) (6 = green) (7 = pink) (8 = purple) (9 = cyan) (10 = cobalt) (11 = orange) (12 = teal) (13 = sage) (14 = brown) (15 = tan) (16 = maroon) (17 = salmon)
        --player_icon_index = read_word(m_player + 0x62) -- (???) Always 0xFFFF?
        player_machine_index = read_byte(m_player + 0x64) -- Confirmed with resolveplayer(player). Player Machine Index (rconId - 1).
        --player_controller_index = read_byte(m_player + 0x65) -- (???) Always 0?
        player_team2 = read_byte(m_player + 0x66)    -- Confirmed. (Red = 0) (Blue = 1)
        player_index = read_byte(m_player + 0x67)    -- Confirmed. Player memory id/index (0 - 15) (To clarify: this IS the 'player' argument passed to phasor functions)
        --End of client struct stuff.

        player_invis_time = read_word(m_player + 0x68)    -- Confirmed. Time until player is no longer camouflaged. (1 sec = 30 ticks)
        --unkWord[1] 0x6A-0x6C (???) Has something to do with player_invis_time.
        player_speed = read_float(m_player + 0x6C)        -- Confirmed.
        player_teleporter_flag_id = readident(m_player + 0x70) -- Tested. Index to a netgame flag in the scenario, or -1 (Always 0xFFFFFFFF?)
        player_objective_mode = read_dword(m_player + 0x74) -- From Smiley. (Hill = 0x22 = 34) (Juggernaut = It = 0x23 = 35) (Race = 0x16 = 22) (Ball = 0x29 = 41) (Others = -1)
        player_objective_player_id = readident(m_player + 0x78) -- Confirmed. Becomes the full DWORD ID of this player once they interact with the objective. (DOES NOT APPLY TO CTF) (0xFFFFFFFF / -1 if not interacting)
        player_target_player = read_dword(m_player + 0x7C) -- From OS. Values (this and below) used for rendering a target player's name. (Always 0xFFFFFFFF?)
        player_target_time = read_dword(m_player + 0x80)  -- From OS. Timer used to fade in the target player name.
        player_last_death_time = read_dword(m_player + 0x84) -- Confirmed. gameinfo_current_time - this = time since last death time. (1 sec = 30 ticks)
        player_slayer_target = readident(m_player + 0x88) -- Confirmed. Slayer Target Player
        --	bitmask32:
        player_oddman_out = read_bit(m_player + 0x8C, 0)  -- Confirmed. (1 if oddman out, 0 if not)
        --	bitPadding[31]
        --Padding[6] 0x90-0x96
        player_killstreak = read_word(m_player + 0x96) -- Confirmed. How many kills the player has gotten in their lifetime.
        player_multikill = read_word(m_player + 0x98) -- (???) 0 on spawn, 1 when player gets a kill, then stays 1 until death.
        player_last_kill_time = read_word(m_player + 0x9A) -- Confirmed. gameinfo_current_time - this = time since last kill time. (1 sec = 30 ticks)
        player_kills = read_word(m_player + 0x9C)    -- Confirmed.
        --unkByte[6] 0x9E-0xA4 (Padding Maybe?)
        player_assists = read_word(m_player + 0xA4)  -- Confirmed.
        --unkByte[6] 0xA6-0xAC (Padding Maybe?)
        player_betrays = read_word(m_player + 0xAC)  -- Confirmed. Actually betrays + suicides.
        player_deaths = read_word(m_player + 0xAE)   -- Confirmed.
        player_suicides = read_word(m_player + 0xB0) -- Confirmed.
        --Padding[14] 0xB2-0xC0
        player_teamkills = read_word(m_player + 0xC0) -- From OS.
        --Padding[2] 0xC2-0xC4

        --This is all copied from the stat struct
        player_flag_steals = read_word(m_player + 0xC4)     -- Confirmed. Flag steals for CTF.
        player_hill_time = read_word(m_player + 0xC4)       -- Confirmed. Time for KOTH. (1 sec = 30 ticks)
        player_race_time = read_word(m_player + 0xC4)       -- Confirmed. Time for Race. (1 sec = 30 ticks)
        player_flag_returns = read_word(m_player + 0xC6)    -- Confirmed. Flag returns for CTF.
        player_oddball_target_kills = read_word(m_player + 0xC6) -- Confirmed. Number of times you killed the Juggernaut or It.
        player_race_laps = read_word(m_player + 0xC6)       -- Confirmed. Laps for Race.
        player_flag_scores = read_word(m_player + 0xC8)     -- Confirmed. Flag scores for CTF.
        player_oddball_kills = read_word(m_player + 0xC8)   -- Confirmed. Number of kills you have as Juggernaut or It.
        player_race_best_time = read_word(m_player + 0xC8)  -- Confirmed. Best time for Race. (1 sec = 30 ticks)

        --unkByte[2] 0xCA-0xCC (Padding Maybe?)
        player_telefrag_timer = read_dword(m_player + 0xCC) -- Confirmed. Time spent blocking a tele. Counts down after other player stops trying to teleport. (1 sec = 30 ticks)
        player_quit_time = read_dword(m_player + 0xD0) -- Confirmed. gameinfo_current_time - this = time since player quit. 0xFFFFFFFF if player not quitting. (1 sec = 30 ticks)
        --	bitmask16:
        --	player_telefrag_enabled = read_bit(m_player + 0xD4, 0) -- (???) Always False?
        --	bitPadding[7] 1-7
        --	player_quit = read_bit(m_player + 0xD4, 8) -- (???) Always False?
        --	bitPadding[7] 9-15
        --Padding[6] 0xD6-0xDC
        player_ping = read_dword(m_player + 0xDC)      -- Confirmed.
        player_teamkill_number = read_dword(m_player + 0xE0) -- Confirmed.
        player_teamkill_timer = read_dword(m_player + 0xE4) -- Confirmed. Time since last betrayal. (1 sec = 30 ticks)
        player_some_timer = read_word(m_player + 0xE8) -- Tested. It increases once every half second until it hits 36, then repeats.
        --unkByte[14] 0xEA-0xF8 (???)
        player_x_coord = read_float(m_player + 0xF8)   -- Confirmed.
        player_y_coord = read_float(m_player + 0xFC)   -- Confirmed.
        player_z_coord = read_float(m_player + 0x100)  -- Confirmed.
        --unkIdent[1] 0x104-0x108 (???)


        --unkByte[8] 0x108-0x110 (???)
        player_last_update_time = read_dword(m_player + 0xF0) -- This is the time that the last update was sent (tick count -1)
        --unkByte[8] 0x114-0x11C (???)
        --	Player Action Keypresses.
        player_melee_key = read_bit(m_player + 0x11C, 0) -- Confirmed.
        player_action_key = read_bit(m_player + 0x11C, 1) -- Confirmed.
        --	unkBit[1] 2
        player_flashlight_key = read_bit(m_player + 0x11C, 3) -- Confirmed.
        --	unkBit[9] 4-12
        player_reload_key = read_bit(m_player + 0x11C, 13) -- Confirmed.
        --	unkBit[2] 14-15

        -- I think the above bitmask is wrong, this is what it actually is:
        player_flashlight_key = read_bit(m_player + 0x11C, 4)
        player_action_key = read_bit(m_player + 0x11C, 6)
        player_melee_key = read_bit(m_player + 0x11C, 7)
        player_reload_key = read_bit(m_player + 0x11C, 10)

        --unkByte[30] 0x11E-0x134 (???)
        player_xy_aim = read_float(m_player + 0x138)     -- Confirmed. Lags. (0 to 2pi) In radians.
        player_z_aim = read_float(m_player + 0x13C)      -- Confirmed. Lags. (-pi/2 to pi/2) In radians.
        player_forward = read_float(m_player + 0x140)    -- Confirmed. Negative means backward. Lags. (-1, -sqrt(2)/2, 0, sqrt(2)/2, 1)
        player_left = read_float(m_player + 0x144)       -- Confirmed. Negative means right. Lags. (-1, -sqrt(2)/2, 0, sqrt(2)/2, 1)
        player_rateoffire_speed = read_float(m_player + 0x148) -- Confirmed. As player is shooting, this will gradually increase until it hits the max (0 to 1 only)
        player_weap_type = read_word(m_player + 0x14C)   -- Confirmed. Lags. (Primary = 0) (Secondary = 1) (Tertiary = 2) (Quaternary = 3)
        player_nade_type = read_word(m_player + 0x14E)   -- Confirmed. Lags. (Frag = 0) (Plasma = 1)
        --unkByte[4] 0x150-0x154 (Padding Maybe?)
        player_x_aim2 = read_float(m_player + 0x154)     -- Confirmed. Lags.
        player_y_aim2 = read_float(m_player + 0x158)     -- Confirmed. Lags.
        player_z_aim2 = read_float(m_player + 0x15C)     -- Confirmed. Lags.
        --unkByte[16] 0x160-0x170 (Padding Maybe?)
        player_x_coord2 = read_float(m_player + 0x170)   -- Confirmed. Lags. (Possibly what the client reports is _its_ world coord?)
        player_y_coord2 = read_float(m_player + 0x174)   -- Confirmed. Lags. (Possibly what the client reports is _its_ world coord?)
        player_z_coord2 = read_float(m_player + 0x178)   -- Confirmed. Lags. (Possibly what the client reports is _its_ world coord?)
        --unkByte[132] 0x17C-0x200



        --LOCAL PLAYER STUFF (or whatever you'd like to call this stuff)
        local_player = read_dword(0x815918)   -- from aLTis -- other addresses here too, need to research later!
        unknown = read_dword(local_player)
        unknown = read_word(local_player + 4) -- changes when joining a server
        unknown = read_word(local_player + 6) -- changes when joining a server
        unknown = read_dword(local_player + 8)
        player_count = read_byte(local_player + 12) -- setting to 0 disables your player and setting to higher than 1 will enable split screen bars
        unknown = read_word(local_player + 16) -- always 0
        cutscene = read_byte(local_player + 17) -- changes to 1 during cutscenes (maybe related to value above)
        cutscene = read_byte(local_player + 18)
        unknown = read_dword(local_player + 20)
        unknown = read_word(local_player + 24) -- some timer, changes when loading
        -- these values seem to change based on which cluster you're in
        unknown = read_word(local_player + 26) -- changes based on map, 1 when in menu
        unknown = read_word(local_player + 28) -- changes based on map
        unknown = read_word(local_player + 30)
        unknown = read_word(local_player + 32)
        unknown = read_word(local_player + 34)   -- changes to 1 on some maps

        unknown = read_word(local_player + 152)  -- bitmask. changes to 1 after a key is pressed and only resets when a new map is loaded?
        player_obj_id = read_dword(local_player + 168) -- object ID of the biped player is controlling

        -- input bitmask:
        crouch = read_bit(local_player + 172, 0)
        jump = read_bit(local_player + 172, 1)
        -- unknow 2-3
        flashlight = read_bit(local_player + 172, 4)
        -- unknow 5
        action = read_bit(local_player + 172, 6)
        melee = read_bit(local_player + 172, 7)
        -- unknow 8-9
        reload = read_bit(local_player + 172, 10)
        primary_trigger = read_bit(local_player + 172, 11)
        secondary_trigger = read_bit(local_player + 172, 12)
        secondary_trigger2 = read_bit(local_player + 172, 13) -- why are there 2?
        exchange_weapon = read_bit(local_player + 172, 14)
        -- unknow 15

        -- you can actually control the player using these. please don't make an aimbot :'v
        player_yaw = read_float(local_player + 180) -- in radians
        player_pitch = read_float(local_player + 184) -- in radians
        player_forward = read_float(local_player + 188)
        player_left = read_float(local_player + 192)
        player_primary_trigger = read_float(local_player + 196)
        player_current_weapon_slot = read_word(local_player + 200)
        player_current_grenade_slot = read_word(local_player + 202)
        player_zoom_level = read_word(local_player + 204)

        unknown = read_word(local_player + 206)
        unknown = read_dword(local_player + 208)

        camera_pitch_range_down = read_float(local_player + 224) -- how low can the player aim (in radians)
        camera_pitch_range_up = read_float(local_player + 228) -- how high can the player aim (in radians)


        -- everything from here on is related to contrails

        --sounds (from aLTis)
        sounds_global = read_dword(0x6C0580)
        sound_count = read_word(sounds_global + 44) --(id of the new sound in the struct? idk)
        sound_count2 = read_word(sounds_global + 46) --(id of the new sound in the struct? idk)
        sound_count3 = read_word(sounds_global + 48) -- actual count of sounds currently playing
        sound_count3 = read_byte(sounds_global + 50) -- counts up
        --unknown = read_byte(sounds_global + 51)
        sound_struct_address = read_dword(sounds_global + 52)

        --struct size 176
        local count = 0
        for i = 0, 100 do -- there's probably a better way of doing this
            local struct = sound_struct_address + i * 176
            if count >= sound_count3 then
                break
            end
            if read_word(struct + 140) ~= 0xFFFF then
                count = count + 1

                sound_counter = read_byte(struct + 0) -- increases every time a sound is played
                --unknown = read_word(struct + 1) -- 0, changes when a sound is playing, maybe counter related? bitmask??
                --unknown = read_word(struct + 2) -- 0, changes to 1 or 2. bitmask??
                --unknown = read_dword(struct + 4) -- always 2? sometimes 6
                sound_tag_id = read_dword(struct + 8) -- tag id of the sound
                sound_parent = read_dword(struct + 12) -- object that the sound is coming from
                --unknown = read_dword(struct + 16) -- changes sometimes when a sound plays
                --unknown = read_word(struct + 20) -- either 0 or 1. Seems to be 0 when playing UI related sounds
                --unknown = read_word(struct + 22) -- changes to some random number sometimes
                sound_scale = read_float(struct + 24) -- usually 1.0 (not 100% sure this is correct)
                sound_gain = read_float(struct + 28) -- usually 1.0
                sound_x = read_float(struct + 32) -- position
                sound_y = read_float(struct + 36) -- position
                sound_z = read_float(struct + 40) -- position
                sound_rot1 = read_float(struct + 44) -- rotation
                sound_rot2 = read_float(struct + 48) -- rotation
                sound_rot3 = read_float(struct + 52) -- rotation
                sound_vel_x = read_float(struct + 56) -- velocity
                sound_vel_y = read_float(struct + 60) -- velocity
                sound_vel_z = read_float(struct + 64) -- velocity
                --unknown = read_dword(struct + 68) -- no idea
                --unknown = read_dword(struct + 72) -- no idea
                --unknown = read_dword(struct + 76) -- 0, changes only when UI sounds play
                --unknown = read_dword(struct + 80) -- 0, changes only when UI sounds play (source of the sound?)
                --unknown = read_word(struct + 84) -- 0, changes to 1 when firing and to other numbers when doing other actions
                --unknown = read_char(struct + 86) -- 0, changes to -1 sometimes?
                --unknown = read_dword(struct + 88) -- 0, changes when firing?
                --unknown = read_dword(struct + 92) -- 0, changes when firing?
                --unknown = read_dword(struct + 96) -- 0, changes when firing?
                --unknown = read_dword(struct + 100) -- maybe float?
                --unknown = read_dword(struct + 104) -- always 0, only changes when firing chaingun hog???
                --???
                --unknown = read_dword(struct + 132) -- increases like a time when sound started but in a weird way?
                sound_pitch = read_float(struct + 136) -- pitch of the sound
                sound_order_id = read_word(struct + 140) -- counts up with every sound that is currently playing and reset if they stop. 0xFFFF if the sound is not playing
                sound_pitch_range = read_word(struct + 142) --from the .sound tag
                sound_permutation = read_dword(struct + 144) --from the .sound tag
                --unknown = read_dword(struct + 148) -- changes to 0 or 1 for sound loops
                --unknown = read_dword(struct + 152) -- 0xFFFFFFFF for sound loops?
                sound_fade = read_float(struct + 156) -- 1.0 when sound is fading in or out
                --some float = read_float(struct + 160) -- sound fade related
                --unknown = read_dword(struct + 164) -- fade related
                --unknown = read_dword(struct + 168) -- similar to the value above
                sound_fp = read_dword(struct + 172) -- 1 if sound happens in fp?
            end
        end


        --particles (from aLTis)
        particles = read_dword(0x8160F0) + 0x20
        unknown = read_byte(particles + 0x1)      -- always 4
        unknown = read_byte(particles + 0x2)      -- always 70
        game_active = read_byte(particles + 0x3)  -- 0 when the game is loading, 1 otherwise
        data = read_dword(particles + 0x8)        -- just says d@t@ :v
        particle_count = read_word(particles + 0xC) -- these seem to be different from each other
        particle_count2 = read_word(particles + 0xE) -- these seem to be different from each other
        particle_count3 = read_word(particles + 0x10) -- these seem to be different from each other
        particle_count4 = read_word(particles + 0x12) -- keeps counting up and doesn't reset
        particle_address = read_dword(particles + 0x14) -- particles array here
        particle_size = 0x70                      -- still dont know this one
        for i = 0, particle_count2 - 1 do
            local address = particle_address + i * particle_size
            unknown = read_word(address + 0x0) -- seems to change when particle is active (visible), otherwise it's 0
            unknown = read_word(address + 0x2) -- always 0, maybe related to value above?
            particle_tag_id = read_dword(address + 0x4) -- tag id of the particle tag
            parent_object = read_dword(address + 0x8) -- object id of the object that created this particle (if object is attached to marker!)
            unknown = read_word(address + 0xC)
            unknown = read_dword(address + 0xE)
            -- I don't know what these values are and I can't be bothered looking into it
            part_timer = read_float(address + 0x14) -- increases from 0 to it's lifetime value (in seconds)
            unknown = read_float(address + 0x1C) -- similar to the value above but not exactly?
            -- I don't know what these values are and I can't be bothered looking into it
            part_x = read_float(address + 0x30) -- position
            part_y = read_float(address + 0x34) -- position
            part_z = read_float(address + 0x38) -- position
            part_rot_1 = read_float(address + 0x3C) -- rotation
            part_rot_2 = read_float(address + 0x40) -- rotation
            part_rot_3 = read_float(address + 0x44) -- rotation
            part_vel_x = read_float(address + 0x48) -- velocity
            part_vel_y = read_float(address + 0x4C) -- velocity
            part_vel_z = read_float(address + 0x50) -- velocity
            part_rot_vel1 = read_float(address + 0x54) -- rotation velocity
            part_rot_vel2 = read_float(address + 0x58) -- rotation velocity
            part_scale = read_float(address + 0x5C) -- scale
        end


        --effect locations
        effect_loc_address = read_dword(0x816100) -- 0x402EB5CC












        -- obj/weap struct setup
        object = getobject(player_obj_id)           -- obj struct setup
        m_vehicle = getobject(read_dword(object + 0x11C)) -- vehi check setup

        -- vehi check
        if m_vehicle then
            object = m_vehicle
        end

        --*****************************************	OBJECTS	**************************************************************

        -- obj struct. This struct applies to ALL OBJECTS. 0x0 - 0x1F4
        obj_tag_id = read_dword(object)      -- Confirmed with HMT. Tag Meta ID / MapID / TagID.
        obj_object_role = read_dword(object + 0x4) -- From OS. (0 = Master, 1 = Puppet, 2 = Puppet controlled by local player, 3 = ???) Only works on client side?

        -- maybe these 2 are just bytes?
        --	bitmask32:
        obj_is_not_moving = read_bit(object + 0x8, 0)           -- Tested. Is true when object is not moving (from aLTis)
        --	unkBits[8] 1-7 (???)
        obj_should_force_baseline_update = read_bit(object + 0x8, 8) -- From OS.
        --	unkBits[23] 9-32 (???)
        obj_existance_time = read_dword(object + 0xC)           -- Confirmed. (1 second = 30 ticks)


        --	Physics bitmask32:
        obj_ghost_mode = read_bit(object + 0x10, 0)       -- (Ghost mode = True)
        obj_is_on_ground = read_bit(object + 0x10, 1)     -- (Object is on the ground = True, otherwise False)
        obj_ignoreGravity = read_bit(object + 0x10, 2)    -- From Phasor
        obj_is_in_water = read_bit(object + 0x10, 3)      -- For vehicles only? (from aLTis)
        --	unkBits[1] 0x10 4 seems to be water related too (vehicle only?)
        obj_stationary = read_bit(object + 0x10, 5)       -- This bit is set (true) when the object is stationary.
        --	unkBits[1] 0x10 6
        obj_noCollision2 = read_bit(object + 0x10, 7)     -- From Phasor. When player enters/exits vehicles, its animations are weird
        obj_dynamic_lights = read_bit(object + 0x10, 8)   -- Setting this to false makes lights derender if you move the object away from where it was (from aLTis)
        --	unkBits[3] 0x10 9-10
        obj_connected_to_map = read_bit(object + 0x10, 11) -- Setting this to false will make the sounds attached to this stay in place if object moves (probably has more changes than just that) (from aLTis)
        obj_node_rotation_thingy = read_bit(object + 0x10, 12) -- Setting this to true messes up rotations of the nodes. Not 100% sure what this is (from aLTis)
        obj_dynamic_lights2 = read_bit(object + 0x10, 13) -- similar to the first one but more harsh? (from aLTis)
        obj_dynamic_shading = read_bit(object + 0x10, 14) -- Setting this to false will prevent shading and shadows from changing when object moves to darker/lighter areas (from aLTis)
        obj_dynamic_shading2 = read_bit(object + 0x10, 15) -- Also shading related but can't quite tell what it does (from aLTis)
        obj_garbage_bit = read_bit(object + 0x10, 16)     -- From OS.
        --	unkBits[1] 0x10 17
        obj_does_not_cast_shadow = read_bit(object + 0x10, 18) -- From OS.
        --	unkBits[2] 0x10 19
        obj_frozen = read_bit(object + 0x10, 20)          -- Center of object's radius stays where the object was spawned, moving the object away from it usually derenders it. Object cannot be removed too when when it's true so it might mean something else (from aLTis)
        obj_is_outside_of_map = read_bit(object + 0x10, 21) -- True if outside of map, False if not
        --	obj_beautify_bit = read_bit(object + 0x10, 22) -- (???) Always False?
        obj_optimized = read_bit(object + 0x10, 23)       -- When true vehicle will not aim unless it's moving. If set on biped then the biped's model will stay still while the invisible biped moves. It will also prevent the biped from being affected by velocity (from aLTis)
        obj_is_collideable = read_bit(object + 0x10, 24)  -- Set this to true to allow other objects to pass through you. (doesn't apply to bipeds and vehicle on vehicle collision).
        --	unkBits[1] 0x10 125
        obj_pickup = read_bit(object + 0x10, 26)          -- If object is a weapon it turns true when being picked up (from aLTis)
        --	unkBits[7] 0x10 26-31


        obj_marker_id = read_dword(object + 0x14) -- Tested. Continually counts up from like 89000...
        --Padding[0x38] 0x18-0x50
        --obj_owner_player_id = readident(object + 0x50) -- (???) Always 0?
        --obj_owner_id = readident(object + 0x54) -- (???) Always 0?
        --obj_timestamp = read_dword(object + 0x58) -- (???) Always 0?

        obj_x_coord = read_float(object + 0x5C) -- Confirmed.
        obj_y_coord = read_float(object + 0x60) -- Confirmed.
        obj_z_coord = read_float(object + 0x64) -- Confirmed.
        obj_x_vel = read_float(object + 0x68) -- Confirmed.
        obj_y_vel = read_float(object + 0x6C) -- Confirmed.
        obj_z_vel = read_float(object + 0x70) -- Confirmed.
        obj_rot1 = read_float(object + 0x74) -- Confirmed. First rotation vector (from aLTis)
        obj_rot2 = read_float(object + 0x78) -- Confirmed. First rotation vector (from aLTis)
        obj_rot3 = read_float(object + 0x7C) -- Confirmed. First rotation vector (from aLTis)
        obj_rot4 = read_float(object + 0x80) -- Confirmed. Second rotation vector (from aLTis)
        obj_rot5 = read_float(object + 0x84) -- Confirmed. Second rotation vector (from aLTis)
        obj_rot6 = read_float(object + 0x88) -- Confirmed. Second rotation vector (from aLTis)
        obj_pitch_vel = read_float(object + 0x8C) -- Confirmed for vehicles. Current velocity for pitch.
        obj_yaw_vel = read_float(object + 0x90) -- Confirmed for vehicles. Current velocity for yaw.
        obj_roll_vel = read_float(object + 0x94) -- Confirmed for vehicles. Current velocity for roll.

        obj_locId = read_dword(object + 0x98) -- Confirmed. Each map has dozens of location IDs, used for general location checking.
        obj_cluster_id = read_word(object + 0x9C) -- Tested. Seems to be the ID of the cluster the object is in (from aLTis)
        --unknown = read_word(object + 0x9E) -- I don't know what this is (from aLTis)
        -- Apparently these are coordinates, used for the game code's trigger volume point testing
        obj_center_x_coord = read_float(object + 0xA0) -- Tested. Coordinate + origin offset
        obj_center_y_coord = read_float(object + 0xA4) -- Tested. Coordinate + origin offset
        obj_center_z_coord = read_float(object + 0xA8) -- Tested. Coordinate + origin offset
        obj_bounding_radius = read_float(object + 0xAC) -- Confirmed. Radius of object. In Radians. (-1 to 1)
        obj_scale = read_float(object + 0xB0)     -- Tested. Seems to be some random float for all objects (all same objects have same value)
        obj_type = read_word(object + 0xB4)       -- Confirmed. (0 = Biped) (1 = Vehicle) (2 = Weapon) (3 = Equipment) (4 = Garbage) (5 = Projectile) (6 = Scenery) (7 = Machine) (8 = Control) (9 = Light Fixture) (10 = Placeholder) (11 = Sound Scenery)
        --Padding[2] 0xB6-0xB8
        obj_team = read_word(object + 0xB8)       -- Confirmed. If objective then this >= 0, -1 = is NOT game object. Otherwise: (Red = 0) (Blue = 1) also means object team
        obj_namelist_index = read_word(object + 0xBA) -- From OS. Index of the object name in the scenario tag. (from aLTis)
        obj_moving_time = read_word(object + 0xBC) -- Tested. Ticks since the last time the object has moved (from aLTis)
        --obj_region_permutation_variant_id = read_word(object + 0xBE) -- (???) Always 0?
        obj_player_id = readident(object + 0xC0)  -- Confirmed. Full DWORD ID of player.
        obj_owner_obj_id = readident(object + 0xC4) -- Confirmed. Parent object ID of this object (DOES NOT APPLY TO BIPEDS/PLAYER OBJECTS)
        --Padding[4] 0xC8-0xCC


        obj_antr_meta_id = readident(object + 0xCC)          -- From DZS. Animation tag (from aLTis)
        obj_base_animation = read_word(object + 0xD0)        -- Tested. The base animation that is currently playing. (by aLTis)
        obj_base_animation_frame = read_word(object + 0xD2)  -- Tested. Current frame of the base animation (by aLTis)
        obj_animation_transition_frame = read_word(object + 0xD4) -- Interpolates between previous and new animation. Counts up every frame until the value below is reached (from aLTis)
        obj_animation_transition_length = read_word(object + 0xD6) -- How many frames it takes to interpolate the animation (from aLTis)

        obj_max_health = read_float(object + 0xD8)           -- Confirmed. Takes value from coll tag.
        obj_max_shields = read_float(object + 0xDC)          -- Confirmed. Takes value from coll tag.
        obj_health = read_float(object + 0xE0)               -- Confirmed. (0 to 1)
        obj_shields = read_float(object + 0xE4)              -- Confirmed. (0 to 3) (Normal = 1) (Full overshield = 3)
        obj_current_shield_damage = read_float(object + 0xE8) -- Confirmed. CURRENT INSTANTANEOUS amount of shield being damaged.
        obj_current_body_damage = read_float(object + 0xEC)  -- Confirmed. CURRENT INSTANTANEOUS amount of health being damaged.
        --obj_some_obj_id = readident(object + 0xF0) -- (???) Always 0xFFFFFFFF?
        obj_last_shield_damage_amount = read_float(object + 0xF4) -- Tested. Total shield damage taken (counts back down to 0 after 2 seconds)
        obj_last_body_damage_amount = read_float(object + 0xF8) -- Tested. Total health damage taken (counts back down to 0 after 2 seconds)
        obj_last_shield_damage_time = read_dword(object + 0xFC) -- Tested. Counts up to 75 after shield is damaged, then becomes 0xFFFFFFFF.
        obj_last_body_damage_time = read_dword(object + 0x100) -- Tested. Counts up to 75 after health is damaged, then becomes 0xFFFFFFFF.
        obj_shields_recharge_time = read_word(object + 0x104) -- Tested. Counts down when shield is damaged. When 0 your shields recharge. (1 sec = 30 ticks). based on ftol(s_shield_damage_resistance->stun_time * 30f)
        -- damageFlags bitmask16
        --obj_body_damage_effect_applied = read_bit(object + 0x106, 0) -- (???) Always False?
        --obj_shield_damage_effect_applied = read_bit(object + 0x106, 1) -- (???) Always False?
        obj_body_health_empty = read_bit(object + 0x106, 2) -- Tested. True when health is empty. Set to true to make player "die" without actually dying (from aLTis)
        obj_shield_empty = read_bit(object + 0x106, 3)     -- Tested. True when shield is empty (from aLTis)
        obj_overshield = read_bit(object + 0x106, 4)       -- Tested. True when overshield is full (from aLTis)
        obj_silent_kill_bit = read_bit(object + 0x106, 5)  -- Tested. True when player dies. (from aLTis)
        obj_damage_berserk = read_bit(object + 0x106, 6)   -- Tested. Same as above? (from aLTis)
        --	unkBits[4] 0x106 7-9
        obj_cannot_use_weapons = read_bit(object + 0x106, 10) -- Tested. I assume this is when you shoot off left hand from flood. Drops weapon when true (from aLTis)
        obj_cannot_take_damage = read_bit(object + 0x106, 11) -- Confirmed. Set this to true to make object undamageable (even from backtaps!)
        obj_shield_recharging = read_bit(object + 0x106, 12) -- Confirmed. (True = shield recharging, False = not recharging)
        obj_killed_no_statistics = read_bit(object + 0x106, 13) -- Tested. True when commiting suicide (set to commit suicide) (from aLTis)
        --	unkBits[2] 0x106 14-15
        --Padding[4] 0x108
        obj_cluster_partition_index = readident(object + 0x10C) -- Tested. This number continually counts up, and resumes even after object is destroyed and recreated (killed)
        --obj_some_obj_id2 = readident(object + 0x110) -- object_index, garbage collection related
        --obj_next_obj_id = readident(object + 0x114) -- (???) I wonder what this is. If you set this to your weapon id then you will see your weapon's third person model (from aLTis)

        obj_weap_obj_id = readident(object + 0x118)      -- Confirmed. Current weapon  id. (also applies to a grenade you're throwing!!!)
        obj_vehi_obj_id = readident(object + 0x11C)      -- Confirmed. Current vehicle id. (Could also be known as the object's parent ID.)
        obj_vehi_seat = read_word(object + 0x120)        -- Confirmed. Current seat index (actually same as player_interaction_vehi_seat once inside a vehicle) ALSO NODE INDEX OF THE PARENT!!!
        --	bitmask8:
        obj_force_shield_update = read_bit(object + 0x122, 0) -- From OS.
        --	unkBits[15] 1-15 (???)

        --Functions.
        obj_shields_hit = read_float(object + 0x124)     -- Tested. Counts down from 1 after shields are hit (0 to 1)
        obj_shields_target = read_float(object + 0x128)  -- Tested. When you have an overshield it stays at 1 which is why I think the overshield drains. (0 to 1) [2nd function]
        obj_flashlight_scale = read_float(object + 0x12C) -- Confirmed. Intensity of flashlight as it turns on and off. (0 to 1) (On > 0) (Off = 0) [3rd function]
        obj_assaultrifle_function = read_float(object + 0x130) -- The Assault rifle is the only one that uses this function.
        obj_export_function1 = read_float(object + 0x134) -- Tested. (Assault rifle = 1)
        obj_flashlight_scale2 = read_float(object + 0x138) -- Confirmed. Intensity of flashlight as it turns on and off. (0 to 1) (On > 0) (Off = 0) [2nd function]
        obj_shields_hit2 = read_float(object + 0x13C)    -- Tested. Something to do with shields getting hit. [3rd function]
        obj_export_function4 = read_float(object + 0x140) -- Tested. (1 = Assault Rifle)
        --End of functions.

        --Regions/Attachments.
        obj_attachment_type = read_byte(object + 0x144) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type2 = read_byte(object + 0x145) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type3 = read_byte(object + 0x146) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type4 = read_byte(object + 0x147) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type5 = read_byte(object + 0x148) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type6 = read_byte(object + 0x149) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type7 = read_byte(object + 0x14A) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)
        obj_attachment_type8 = read_byte(object + 0x14B) -- From OS. (0 = light, 1 = looping sound, 2 = effect, 3 = contrail, 4 = particle, 5 = ???, 0xFF = invalid)

        -- game state identity
        -- ie, if Attachments[x]'s definition (object_attachment_block[x]) says it is a 'cont'
        -- then the identity is a contrail_data handle
        obj_attachment_id = readident(object + 0x14C)       -- From OS.
        obj_attachment2_id = readident(object + 0x150)      -- From OS.
        obj_attachment3_id = readident(object + 0x154)      -- From OS.
        obj_attachment4_id = readident(object + 0x158)      -- From OS.
        obj_attachment5_id = readident(object + 0x15C)      -- From OS.
        obj_attachment6_id = readident(object + 0x160)      -- From OS.
        obj_attachment7_id = readident(object + 0x164)      -- From OS.
        obj_attachment8_id = readident(object + 0x168)      -- From OS.
        obj_first_widget_id = readident(object + 0x16C)     -- (???) Always 0xFFFFFFFF?
        obj_cached_render_state_index = readident(object + 0x170) -- (???) Always 0xFFFFFFFF?
        --unkByte[2] 0x174-0x176 (Padding Maybe?)
        obj_shader_permutation = read_word(object + 0x176)  -- From OS. shader's bitmap block index
        obj_health_region = read_byte(object + 0x178)       -- From OS.
        obj_health_region2 = read_byte(object + 0x179)      -- From OS.
        obj_health_region3 = read_byte(object + 0x17A)      -- From OS.
        obj_health_region4 = read_byte(object + 0x17B)      -- From OS.
        obj_health_region5 = read_byte(object + 0x17C)      -- From OS.
        obj_health_region6 = read_byte(object + 0x17D)      -- From OS.
        obj_health_region7 = read_byte(object + 0x17E)      -- From OS.
        obj_health_region8 = read_byte(object + 0x17F)      -- From OS.
        obj_region_permutation_index = read_char(object + 0x180) -- From OS.
        obj_region_permutation2_index = read_char(object + 0x181) -- From OS.
        obj_region_permutation3_index = read_char(object + 0x182) -- From OS.
        obj_region_permutation4_index = read_char(object + 0x183) -- From OS.
        obj_region_permutation5_index = read_char(object + 0x184) -- From OS.
        obj_region_permutation6_index = read_char(object + 0x185) -- From OS.
        obj_region_permutation7_index = read_char(object + 0x186) -- From OS.
        obj_region_permutation8_index = read_char(object + 0x187) -- From OS.
        --End of regions/attachments

        obj_color_change_red = read_float(object + 0x188) -- From OS.
        obj_color_change_green = read_float(object + 0x18C) -- From OS.
        obj_color_change_blue = read_float(object + 0x190) -- From OS.
        obj_color_change2_red = read_float(object + 0x194) -- From OS.
        obj_color_change2_green = read_float(object + 0x198) -- From OS.
        obj_color_change2_blue = read_float(object + 0x19C) -- From OS.
        obj_color_change3_red = read_float(object + 0x1A0) -- From OS.
        obj_color_change3_green = read_float(object + 0x1A4) -- From OS.
        obj_color_change3_blue = read_float(object + 0x1A8) -- From OS.
        obj_color_change4_red = read_float(object + 0x1AC) -- From OS.
        obj_color_change4_green = read_float(object + 0x1B0) -- From OS.
        obj_color_change4_blue = read_float(object + 0x1B4) -- From OS.
        obj_color2_change_red = read_float(object + 0x1B8) -- From OS.
        obj_color2_change_green = read_float(object + 0x1BC) -- From OS.
        obj_color2_change_blue = read_float(object + 0x1C0) -- From OS.
        obj_color2_change2_red = read_float(object + 0x1C4) -- From OS.
        obj_color2_change2_green = read_float(object + 0x1C8) -- From OS.
        obj_color2_change2_blue = read_float(object + 0x1CC) -- From OS.
        obj_color2_change3_red = read_float(object + 0x1D0) -- From OS.
        obj_color2_change3_green = read_float(object + 0x1D4) -- From OS.
        obj_color2_change3_blue = read_float(object + 0x1D8) -- From OS.
        obj_color2_change4_red = read_float(object + 0x1DC) -- From OS.
        obj_color2_change4_green = read_float(object + 0x1E0) -- From OS.
        obj_color2_change4_blue = read_float(object + 0x1E4) -- From OS.

        --one of these are for interpolating:
        obj_header_block_ref_node_orientation_size = read_word(object + 0x1E8) -- From OS.
        obj_header_block_ref_node_orientation_offset = read_word(object + 0x1EA) -- From OS.
        obj_header_block_ref_node_orientation2_size = read_word(object + 0x1EC) -- From OS.
        obj_header_block_ref_node_orientation2_offset = read_word(object + 0x1EE) -- From OS.
        obj_header_block_ref_node_matrix_block_size = read_word(object + 0x1F0) -- From OS.
        obj_header_block_ref_node_matrix_block_offset = read_word(object + 0x1F2) -- From OS.

        --unkLong[2] 0x1E8-0x1F0 (???) Some sort of ID? Points to some random tag
        --obj_node_matrix_block = read_dword(object + 0x1F0) -- From OS. (???)

        if obj_type == 0 or obj_type == 1 then -- check if object is biped or vehicle
            --unit struct (applies to bipeds (players and AI) and vehicles)
            m_unit = object

            unit_actor_index = readident(m_unit + 0x1F4)   -- From OS.
            unit_swarm_actor_index = readident(m_unit + 0x1F8) -- From OS.
            unit_swarm_next_actor_index = readident(m_unit + 0x1FC) -- Guess.
            unit_swarm_prev_obj_id = readident(m_unit + 0x200) -- From OS.

            --	Client Non-Instantaneous bitmask32
            unit_is_active = read_bit(m_unit + 0x204, 0)             -- Set to false to prevent unit from moving in any way (from aLTis)
            --	unkBit[4] 1-3 (???)
            unit_is_invisible = read_bit(m_unit + 0x204, 4)          -- Confirmed. (True if currently invisible, False if not)
            unit_powerup_additional = read_bit(m_unit + 0x204, 5)    -- From OS. Guessing this is set if you have multiple powerups at the same time.
            unit_is_currently_controllable_bit = read_bit(m_unit + 0x204, 6) -- From OS. Same as the first bit?
            --	unkBit[9] 7-14 (???)
            --	unit_vehicle_exit_thingy = read_bit(m_unit + 0x204, 8) turns true for a moment when exiting a vehicle? (from aLTis)
            --	unkBit[9] 9-14 (???)
            unit_doesNotAllowPlayerEntry = read_bit(m_unit + 0x204, 16) -- From DZS. For vehicles. (True if vehicle is allowing players to enter, False if not)
            --	unkBit[2] 17-18 (???)
            unit_flashlight = read_bit(m_unit + 0x204, 19)      -- Confirmed. (True = flashlight on, False = flashlight off)
            unit_doesnt_drop_items = read_bit(m_unit + 0x204, 20) -- Confirmed. (True if object doesn't drop items on death, otherwise False). (Clients will see player drop items, then immediately despawn)
            --	unkBit[1] 21 (???)
            --	unit_can_blink = read_bit(m_unit + 0x204, 22) -- (???) Always False?
            --	unkBit[1] 23 (???)
            unit_is_suspended = read_bit(m_unit + 0x204, 24)     -- Confirmed. (True if frozen/suspended, False if not)
            unit_is_moving_randomly = read_bit(m_unit + 0x204, 25) -- Tested. If you set this to true the unit will move around randomly lol (from aLTis)
            unit_night_vision = read_bit(m_unit + 0x204, 26)     -- True when night vision is on (from aLTis)
            --	unit_is_possessed = read_bit(m_unit + 0x204, 27) -- (???) Always False?
            unit_flashlight_currently_on = read_bit(m_unit + 0x204, 28) -- Forces the unit to enable flashlight when true (from aLTis)
            unit_flashlight_currently_off = read_bit(m_unit + 0x204, 29) -- Forces the unit to disable flashlight when true (from aLTis)
            --	unkBit[2] 30-31 (???)

            --	Client Action Keypress bitmask32 (Instantaneous actions).
            unit_crouch_presshold = read_bit(m_unit + 0x208, 0) -- Confirmed. (True when holding crouch, False when not)
            unit_jump_presshold = read_bit(m_unit + 0x208, 1) -- Confirmed. (True when holding jump key, False when not)
            --	unit_user1 = read_bit(m_unit + 0x208, 3) -- (???) Always False?
            --	unit_user2 = read_bit(m_unit + 0x208, 4) -- (???) Always False?
            unit_flashlightkey = read_bit(m_unit + 0x208, 4) -- Confirmed. (True when pressing flashlight key, False when not)
            --	unit_exact_facing = read_bit(m_unit + 0x208, 5) -- (???) Always False?
            unit_actionkey = read_bit(m_unit + 0x208, 6) -- Confirmed. (True when pressing action key, False when not)
            unit_meleekey = read_bit(m_unit + 0x208, 7) -- Confirmed. (True when pressing melee key, False when not)
            --	unit_look_without_turn = read_bit(m_unit + 0x208, 8) -- (???) Always False?
            --	unit_force_alert = read_bit(m_unit + 0x208, 9) -- (???) Always False?
            unit_reload_key = read_bit(m_unit + 0x208, 10)            -- Confirmed. (True when pressing action/reload key, False when not)
            unit_primaryWeaponFire_presshold = read_bit(m_unit + 0x208, 11) -- Confirmed. (True when holding left click, False when not)
            unit_secondaryWeaponFire_presshold = read_bit(m_unit + 0x208, 12) -- Confirmed. (True when holding right click, False when not)
            unit_grenade_presshold = read_bit(m_unit + 0x208, 13)     -- Confirmed. (True when holding right click, False when not)
            unit_actionkey_presshold = read_bit(m_unit + 0x208, 14)   -- Confirmed. (True when holding action key,  False when not)
            --	emptyBit[1] 15

            --unkWord[1] 0x20A related to first two words in unit_global_data
            unit_some_timer = read_word(m_unit + 0x20C)     -- Tested. Counts from 0 to 18 (or a different number) and resets. (from aLTis)
            --unit_shield_sapping = read_char(m_unit + 0x20E) -- (???) Always 0?
            unit_base_seat_index = read_char(m_unit + 0x20F) -- From OS.
            --unit_time_remaining = read_dword(m_unit + 0x210) -- (???) Always 0?
            unit_flags = read_dword(m_unit + 0x214)         -- From OS. Bitmask32 (breakdown of this coming soon)
            unit_player_id = readident(m_unit + 0x218)      -- Confirmed. Full DWORD ID of the Player.
            unit_ai_effect_type = read_word(m_unit + 0x21C) -- From OS. ai_unit_effect
            unit_emotion_animation_index = read_word(m_unit + 0x21E) -- From OS.
            unit_last_bullet_time = read_dword(m_unit + 0x220) -- Confirmed. gameinfo_current_time - this = time since last shot fired. (1 second = 30 ticks) Related to unit_ai_effect_type. Lags immensely behind player_last_bullet_time.
            unit_x_facing = read_float(m_unit + 0x224)      -- Confirmed. Same as unit_x_aim.
            unit_y_facing = read_float(m_unit + 0x228)      -- Confirmed. Same as unit_y_aim.
            unit_z_facing = read_float(m_unit + 0x22C)      -- Confirmed. Same as unit_z_aim.
            unit_desired_x_aim = read_float(m_unit + 0x230) -- Confirmed. This is where the unit WANTS to aim.
            unit_desired_y_aim = read_float(m_unit + 0x234) -- Confirmed. This is where the unit WANTS to aim.
            unit_desired_z_aim = read_float(m_unit + 0x238) -- Confirmed. This is where the unit WANTS to aim.
            unit_x_aim = read_float(m_unit + 0x23C)         -- Confirmed.
            unit_y_aim = read_float(m_unit + 0x240)         -- Confirmed.
            unit_z_aim = read_float(m_unit + 0x244)         -- Confirmed.
            unit_x_aim_vel = read_float(m_unit + 0x248)     -- Confirmed. Does not apply to multiplayer bipeds
            unit_y_aim_vel = read_float(m_unit + 0x24C)     -- Confirmed. Does not apply to multiplayer bipeds
            unit_z_aim_vel = read_float(m_unit + 0x250)     -- Confirmed. Does not apply to multiplayer bipeds
            unit_x_aim2 = read_float(m_unit + 0x254)        -- Confirmed.
            unit_y_aim2 = read_float(m_unit + 0x258)        -- Confirmed.
            unit_z_aim2 = read_float(m_unit + 0x25C)        -- Confirmed.
            unit_x_aim3 = read_float(m_unit + 0x260)        -- Confirmed.
            unit_y_aim3 = read_float(m_unit + 0x264)        -- Confirmed.
            unit_z_aim3 = read_float(m_unit + 0x268)        -- Confirmed.
            --unit_x_aim_vel2 = read_float(m_unit + 0x26C) -- (???) Always 0?
            --unit_y_aim_vel2 = read_float(m_unit + 0x26C) -- (???) Always 0?
            --unit_z_aim_vel2 = read_float(m_unit + 0x26C) -- (???) Always 0?

            unit_forward = read_float(m_unit + 0x278)        -- Confirmed. Negative means backward. (-1, -sqrt(2)/2, 0, sqrt(2)/2, 1)
            unit_left = read_float(m_unit + 0x27C)           -- Confirmed. Negative means right. (-1, -sqrt(2)/2, 0, sqrt(2)/2, 1)
            unit_up = read_float(m_unit + 0x280)             -- Confirmed. Negative means down. (-1, -sqrt(2)/2, 0, sqrt(2)/2, 1) (JUMPING/FALLING DOESNT COUNT)
            unit_shooting = read_float(m_unit + 0x284)       -- Confirmed. (Shooting = 1, Not Shooting = 0)
            --unkByte[2] 0x288-0x28A melee related (state enum and counter?)
            unit_time_until_flaming_death = read_char(m_unit + 0x28A) -- From OS (1 second = 30 ticks)
            --unkByte[2] 0x28B-0x28D looks like the amount of frames left for the ping animation. Also set to the same PersistentControlTicks value when an actor dies and they fire-wildly
            unit_throwing_grenade_state = read_byte(m_unit + 0x28D) -- Confirmed. (0 = not throwing) (1 = Arm leaning back) (2 = Grenade leaving hand) (3 = Grenade Thrown, going back to normal state)
            --unkWord[2] 0x28E-0x292 grenade throw animation related (from aLTis)
            --Padding[2] 0x292-0x294
            unit_thrown_grenade_obj_id = readident(m_unit + 0x294) -- Confirmed. 0xFFFFFFFF when grenade leaves hand.

            -- ANIMATION STUFF
            --unkBit[16] 0x298 Something to do with states/animations. First bit is 1 when unit is in impulse state. (from aLTis)
            unit_aim_animation_index = read_word(m_unit + 0x29A)             -- Tested. Aim-still or aim-move animation that is playing (from aLTis)
            unit_look_animation_index = read_word(m_unit + 0x29C)            -- Tested. Look animation that is playing (stand look) (from aLTis)
            --unkWord[1] 0x29E-0x2A0 appears unused except for getting initialized
            unit_state = read_byte(m_unit + 0x2A0)                           -- Confirmed. Unit from animation tag. (Standing = 4) (Crouching = 3) (W-driver = 0) (W-gunner = 1) (from aLTis)
            unit_weap_slot = read_byte(m_unit + 0x2A1)                       -- Confirmed. index of "weapons" slot in the unit of animation tag
            unit_weap_index_type = read_byte(m_unit + 0x2A2)                 -- Tested. (0 = Rocket Launcher) (1 = Plasma Pistol) (2 = Shotgun) (3 = Plasma Rifle) don't care to continue
            unit_animation_state = read_byte(m_unit + 0x2A3)                 -- Confirmed. (0 = Idle, 1 = Gesture, Turn Left = 2, Turn Right = 3, Move Front = 4, Move Back = 5, Move Left = 6, Move Right = 7, Stunned Front = 8, Stunned Back = 9, Stunned Left = 10, Stunned Right = 11, Slide Front = 12, Slide Back = 13, Slide Left = 14, Slide Right = 15, Ready = 16, Put Away = 17, Aim Still = 18, Aim Move = 19, Airborne = 20, Land Soft = 21, Land Hard = 22, ??? = 23, Airborne Dead = 24, Landing Dead = 25, Seat Enter = 26, Seat Exit = 27, Custom Animation = 28, Impulse = 29, Melee = 30, Melee Airborne = 31, Melee Continuous = 32, Grenade Toss = 33, Resurrect Front = 34, Ressurect Back = 35, Feeding = 36, Surprise Front = 37, Surprise Back = 38, Leap Start = 39, Leap Airborne = 40, Leap Melee = 41, Unused AFAICT = 42, Berserk = 43)
            unit_reloadmelee = read_byte(m_unit + 0x2A4)                     -- Confirmed. (Reloading = 5) (Meleeing = 7)
            unit_shooting2 = read_byte(m_unit + 0x2A5)                       -- Confirmed. (Shooting = 1) (No = 0)
            unit_animation_state2 = read_byte(m_unit + 0x2A6)                -- Confirmed. Some kind of unit states (5 - default, 3 - berserk), could also be shield states? (from aLTis)
            unit_crouch2 = read_byte(m_unit + 0x2A7)                         -- Confirmed. (Standing = 2) (Crouching = 3) (Flaming? = 5)
            --unkByte[2] 0x2A8-0x2AA (???)
            unit_replacement_animation_index = read_word(m_unit + 0x2AA)     -- Tested. Replacement animation index from animations tag that is currently playing. (from aLTis)
            unit_replacement_animation_frame_index = read_word(m_unit + 0x2AC) -- Tested. Current frame of the replacement animation. (from aLTis)
            unit_recoil_animation_index = read_word(m_unit + 0x2AE)          -- Tested. Firing overlay animation that is playing (from aLTis)
            unit_recoil_frame_index = read_word(m_unit + 0x2B0)              -- From OS. Recoil amount for the animation. when firing = 0, counts up to 5 when not (from aLTis)
            unit_ping_animation_index = read_word(m_unit + 0x2B2)            -- From OS. Unit ping animation that is playing, different depending on where the unit is hit (from aLTis)
            unit_ping_frame_index = read_word(m_unit + 0x2B4)                -- From OS. Frame index of the ping animation (from aLTis)
            unit_able_to_fire = read_byte(biped_object + 0x2B6)              --	Tested. 1 when unit can fire, 0 otherwise (from aLTis)
            unit_able_to_fire2 = read_byte(biped_object + 0x2B7)             --	Tested. same as above (from aLTis)

            unit_aim_rectangle_top_x = read_float(m_unit + 0x2B8)            -- Confirmed. Top-most aim possible.
            unit_aim_rectangle_bottom_x = read_float(m_unit + 0x2BC)         -- Confirmed. Bottom-most aim possible.
            unit_aim_rectangle_left_y = read_float(m_unit + 0x2C0)           -- Confirmed. Left-most aim possible.
            unit_aim_rectangle_right_y = read_float(m_unit + 0x2C4)          -- Confirmed. Right-most aim possible.
            unit_look_rectangle_top_x = read_float(m_unit + 0x2C8)           -- Confirmed. Top-most aim possible. Same as unit_aim_rectangle_top_x.
            unit_look_rectangle_bottom_x = read_float(m_unit + 0x2CC)        -- Confirmed. Bottom-most aim possible. Same as unit_aim_rectangle_bottom_x.
            unit_look_rectangle_left_y = read_float(m_unit + 0x2D0)          -- Confirmed. Left-most aim possible. Same as unit_aim_rectangle_left_y.
            unit_look_rectangle_right_y = read_float(m_unit + 0x2D4)         -- Confirmed. Right-most aim possible. Same as unit_aim_rectangle_right_y.
            --Padding[8] 0x2D8-0x2E0
            unit_ambient = read_float(m_unit + 0x2E0)                        -- Tested. Being in a bright place increases this value and shooting the weapon sets it to 1. I think AI can't see you on low values. (from aLTis)
            unit_illumination = read_float(m_unit + 0x2E4)                   -- Tested. Firing the weapon or throwing a grenade increases this value. Might be AI related as well.
            unit_mouth_aperture = read_float(m_unit + 0x2E8)                 -- From OS.
            --Padding[4] 0x2EC-0x2F0
            unit_vehi_seat = read_word(m_unit + 0x2F0)                       -- Confirmed. (Warthog seats: Driver = 0, Passenger = 1, Gunner = 2 Not in vehicle = 0xFFFF)
            unit_weap_slot2 = read_word(m_unit + 0x2F2)                      -- Confirmed. Current weapon slot. (Primary = 0) (Secondary = 1) (Ternary = 2) (Quaternary = 3)
            unit_next_weap_slot = read_word(m_unit + 0x2F4)                  -- Confirmed. Weapon slot the player is trying to change to. (Primary = 0) (Secondary = 1) (Ternary = 2) (Quaternary = 3)
            --unkByte[2] 0x2F6-0x2F8 (Padding Maybe?)
            unit_next_weap_obj_id = readident(m_unit + 0x2F8 + unit_next_weap_slot * 4) -- Confirmed. Object ID of the weapon that the player is trying to change to.
            unit_primary_weap_obj_id = readident(m_unit + 0x2F8)             -- Confirmed.
            unit_secondary_weap_obj_id = readident(m_unit + 0x2FC)           -- Confirmed.
            unit_tertiary_weap_obj_id = readident(m_unit + 0x300)            -- Confirmed.
            unit_quaternary_weap_obj_id = readident(m_unit + 0x304)          -- Confirmed.
            unit_primaryWeaponLastUse = read_dword(m_unit + 0x308)           -- From DZS. gameinfo_current_time - this = time since this weapon was last swapped to/picked up. (1 second = 30 ticks)
            unit_secondaryWeaponLastUse = read_dword(m_unit + 0x30C)         -- From DZS. gameinfo_current_time - this = time since this weapon was last swapped to/picked up. (1 second = 30 ticks)
            unit_tertiaryWeaponLastUse = read_dword(m_unit + 0x310)          -- From DZS. gameinfo_current_time - this = time since this weapon was last swapped to/picked up. (1 second = 30 ticks)
            unit_quaternaryWeaponLastUse = read_dword(m_unit + 0x314)        -- From DZS. gameinfo_current_time - this = time since this weapon was last swapped to/picked up. (1 second = 30 ticks)
            unit_objective = read_dword(m_unit + 0x318)                      -- Tested. Increases every time you interact with the objective.
            unit_current_nade_type = read_char(m_unit + 0x31C)               -- Confirmed. (Frag = 0) (Plasma = 1)
            unit_next_nade_type = read_byte(m_unit + 0x31D)                  -- Confirmed. Grenade type the player is trying to change to. (Frag = 0) (Plasma = 1)
            unit_primary_nades = read_byte(m_unit + 0x31E)                   -- Confirmed. Amount of frag grenades you have.
            unit_secondary_nades = read_byte(m_unit + 0x31F)                 -- Confirmed. Amount of plasma grenades you have.
            unit_zoom_level = read_byte(m_unit + 0x320)                      -- Confirmed. The level of zoom the player is at. (0xFF = not zoomed, 0 = first zoom lvl, 1 = second zoom lvl, etc...)
            unit_desired_zoom_level = read_byte(m_unit + 0x321)              -- Confirmed. Where the player wants to zoom. (0xFF = not zoomed, 0 = first zoom lvl, 1 = second zoom lvl, etc...)
            unit_vehicle_speech_timer = read_char(m_unit + 0x322)            -- Tested. Counts up from 0 after reloading, shooting, or throwing nade.
            unit_aiming_change = read_byte(m_unit + 0x323)                   -- Tested. This is 'confirmed' except I don't know what units. Does not apply to multiplayer bipeds.
            unit_master_obj_id = readident(m_unit + 0x324)                   -- Confirmed. Object ID controlling this unit (driver)
            unit_masterofweapons_obj_id = readident(m_unit + 0x328)          -- Confirmed. Object ID controlling the weapons of this unit (gunner)
            unit_passenger_obj_id = readident(m_unit + 0x32C)                -- Confirmed for vehicles. 0xFFFFFFFF for bipeds
            unit_time_abandoned_parent = read_dword(m_unit + 0x330)          -- Confirmed. gameinfo_current_time - this = time since player ejected from vehicle.
            unit_some_obj_id = readident(m_unit + 0x334)                     -- From OS.
            unit_vehicleentry_scale = read_float(m_unit + 0x338)             -- Tested. Intensity of vehicle entry as you enter a vehicle (0 to 1)
            --unit_power_of_masterofweapons = read_float(m_unit + 0x33C) -- (???) Always 0?
            unit_flashlight_scale = read_float(m_unit + 0x340)               -- Confirmed. Intensity of flashlight as it turns on and off. (0 to 1) (On > 0) (Off = 0)
            unit_flashlight_energy = read_float(m_unit + 0x344)              -- Confirmed. Amount of flashlight energy left. (0 to ~1)
            unit_nightvision_scale = read_float(m_unit + 0x348)              -- Confirmed. Intensity of nightvision as it turns on and off. (0 to 1) (On = 1) (Off = 0)
            unit_vehicle_position_x = read_float(m_unit + 0x348)             -- Confirmed. Position of the vehicle that unit is riding (from aLTis)
            unit_vehicle_position_y = read_float(m_unit + 0x34C)             -- Confirmed. Position of the vehicle that unit is riding (from aLTis)
            unit_vehicle_position_z = read_float(m_unit + 0x350)             -- Confirmed. Position of the vehicle that unit is riding (from aLTis)
            unit_invis_scale = read_float(m_unit + 0x37C)                    -- Confirmed. How invisible you are. (0 to 1) (Completely = 1) (None = 0)
            --unit_fullspectrumvision_scale = read_float(m_unit + 0x380) -- (???) Always 0, even when picking up a fullspectrum vision.
            unit_dialogue_definition = readident(m_unit + 0x384)             -- Confirmed. Dialog tag for this unit.

            -->>SPEECH<<--
            --AI Current Speech:
            unit_speech_priority = read_word(m_unit + 0x388) -- From OS. (0 = None) (1 = Idle) (2 = Pain) (3 = Talk) (4 = Communicate) (5 = Shout) (6 = Script) (7 = Involuntary) (8 = Exclaim) (9 = Scream) (10 = Death)
            unit_speech_scream_type = read_word(m_unit + 0x38A) -- From OS. (0 = Fear) (1 = Enemy Grenade) (2 = Pain) (3 = Maimed Limb) (4 = Maimed Head) (5 = Resurrection)
            unit_sound_definition = readident(m_unit + 0x38C) -- From OS.
            --unkWord[1] 0x390-0x392 time-related.
            --Padding[2] 0x392-0x394
            --unkLong[2] 0x394-0x39C (???)
            --unkWord[1] 0x39C-0x39E (???)
            unit_ai_current_communication_type = read_word(m_unit + 0x39E) -- From OS. (0 = Death) (1 = Killing Spree) (2 = Hurt) (3 = Damage) (4 = Sighted Enemy) (5 = Found Enemy) (6 = Unexpected Enemy) (7 = Found dead friend) (8 = Allegiance Changed) (9 = Grenade Throwing) (10 = Grenade Startle) (11 = Grenade Sighted) (12 = Grenade Danger) (13 = Lost Contact) (14 = Blocked) (15 = Alert Noncombat) (16 = Search Start) (17 = Search Query) (18 = Search Report) (19 = Search Abandon) (20 = Search Group Abandon) (21 = Uncover Start) (22 = Advance) (23 = Retreat) (24 = Cover) (25 = Sighted Friend Player) (26 = Shooting) (27 = Shooting Vehicle) (28 = Shooting Berserk) (29 = Shooting Group) (30 = Shooting Traitor) (31 = Flee) (32 = Flee Leader Died) (33 = Flee Idle) (34 = Attempted Flee) (35 = Hiding Finished) (36 = Vehicle Entry) (37 = Vehicle Exit) (38 = Vehicle Woohoo) (39 = Vehicle Scared) (40 = Vehicle Falling) (41 = Surprise) (42 = Berserk) (43 = Melee) (44 = Dive) (45 = Uncover Exclamation) (46 = Falling) (47 = Leap) (48 = Postcombat Alone) (49 = Postcombat Unscathed) (50 = Postcombat Wounded) (51 = Postcombat Massacre) (52 = Postcombat Triumph) (53 = Postcombat Check Enemy) (54 = Postcombat Check Friend) (55 = Postcombat Shoot Corpse) (56 = Postcombat Celebrate)
            --unkWord[1] 0x3A0-0x3A2 (???)
            --Padding[2] 0x3A2-0x3A4
            --unkWord[1] 0x3A4-0x3A6 (???)
            --Padding[6] 0x3A6-0x3AC
            --unkWord[1] 0x3AC-0x3AE (???)
            --Padding[2] 0x3AE-0x3B0
            --unkWord[2] 0x3B0-0x3B4 (???)
            --	bitmask8
            unit_ai_current_communication_broken = read_bit(m_unit + 0x3B4, 0) -- From OS. 1C false = reformed
            --	unkBit[7] 1-7 (???)
            --Padding[3] 0x3B5-0x3B8

            --AI Next Speech (I think):
            unit_speech_priority2 = read_word(m_unit + 0x3B8) -- From OS. (0 = None) (1 = Idle) (2 = Pain) (3 = Talk) (4 = Communicate) (5 = Shout) (6 = Script) (7 = Involuntary) (8 = Exclaim) (9 = Scream) (10 = Death)
            unit_speech_scream_type2 = read_word(m_unit + 0x3BA) -- From OS. (0 = Fear) (1 = Enemy Grenade) (2 = Pain) (3 = Maimed Limb) (4 = Maimed Head) (5 = Resurrection)
            unit_sound_definition2 = readident(m_unit + 0x3BC) -- From OS.
            --unkWord[1] 0x3C0-0x3C2 time-related.
            --Padding[2] 0x3C2-0x3C4
            --unkLong[2] 0x3C4-0x3CC (???)
            --unkWord[1] 0x3CC-0x3CE (???)
            --unit_ai_current_communication_type2 = read_word(m_unit + 0x3CE) -- always 0?
            --unkWord[1] 0x3D0-0x3D2 (???)
            --Padding[2] 0x3D2-0x3D4
            --unkWord[1] 0x3D4-0x3D6 (???)
            --Padding[6] 0x3D6-0x3DC
            --unkWord[1] 0x3DC-0x3DE (???)
            --Padding[2] 0x3DE-0x3E0
            --unkWord[2] 0x3E0-0x3E4 (???)
            --	bitmask8
            unit_ai_current_communication_broken2 = read_bit(m_unit + 0x3E4, 0) -- From OS. 1C false = reformed
            --	unkBit[7] 1-7 (???)
            --Padding[3] 0x3E5-0x3E8

            --unkWord[4] 0x3E8-0x3F0
            --unkLong[1] 0x3F0 time related
            --unkBit[32] 0x3F4-0x3F8 0-31 (???)
            --unkWord[4] 0x3F8-0x400 (???)
            --unkLong[1] 0x400-0x404 (???)
            -->>END OF SPEECH<<--

            -- Unit damage bitmask:
            unit_aoe_damage_recieved = read_bit(m_unit + 0x404, 0) -- Tested. True when getting AOE damage (from aLTis)
            unit_any_damage_recieved = read_bit(m_unit + 0x404, 1) -- Tested. True when getting any damage (from aLTis)
            --unkBit 2
            unit_plasma_damage_recieved = read_bit(m_unit + 0x404, 3) -- Tested. True when getting damaged by plasma weapons (from aLTis)
            --unkBit 4-15

            unit_damage2 = read_word(m_unit + 0x406) -- Tested. Changes to 45 when damaged and counts down (from aLTis)
            --unit_damage3 = read_float(m_unit + 0x408) -- Tested. Changes when damaged. Changes back.
            unit_causing_objId = readident(m_unit + 0x40C) -- Confirmed. ObjId causing damage to this object.
            --unit_flamer_causer_objId = readident(m_unit + 0x410) -- (???) Always 0xFFFFFFFF?
            --Padding[8] 0x414-0x41C
            unit_death_time = read_dword(m_unit + 0x41C) -- Tested. Time when the biped was killed (by aLTis)
            --unit_feign_death_timer = read_word(m_unit + 0x420) -- (???) Always 0xFFFFFFFF?
            unit_camo_regrowth = read_word(m_unit + 0x422) -- Confirmed. (1 = Camo Failing due to damage/shooting)
            unit_stun_amount = read_float(m_unit + 0x424) -- Tested. Changes to almost 1 when getting hit by plasma weapons
            unit_stun_timer = read_word(m_unit + 0x428) -- Tested. Counts down to 0 after getting hit by plasma weapons
            unit_killstreak = read_word(m_unit + 0x42A) -- Tested. Same as player_killstreak.
            unit_last_kill_time = read_dword(m_unit + 0x42C) -- Confirmed. gameinfo_current_time - this = time since last kill time. (1 sec = 30 ticks)

            --I realize the below are confusing, and if you really don't understand them after looking at it, I will explain it if you contact me about them:
            --I have no idea why halo stores these, only thing I can think of is because of betrayals or something.. but still..
            unit_last_damage_time_by_mostrecent_objId = read_dword(m_unit + 0x430) -- Confirmed. gameinfo_current_time - this = Time since last taken damage by MOST RECENT object. (1 second = 30 ticks)
            unit_total_damage_by_mostrecent_objId = read_float(m_unit + 0x434)  -- Confirmed. Total damage done by the MOST RECENT PLAYER (NOT TOTAL DAMAGE TO EVERYONE)
            unit_damage_mostrecent_causer_objId = readident(m_unit + 0x438)     -- Confirmed. the MOST RECENT object ID to do damage to this object (or 0xFFFFFFFF)
            unit_damage_mostrecent_causer_playerId = readident(m_unit + 0x43C)  -- Confirmed. Full DWORD ID of the MOST RECENT PLAYER to do damage to this object.. (AI = 0xFFFFFFFF)
            unit_last_damage_time_by_secondtomostrecent_obj = read_dword(m_unit + 0x440) -- Confirmed. gameinfo_current_time - this = Time since last taken damage by the SECOND TO MOST RECENT object. (1 second = 30 ticks)
            unit_total_damage_by_secondtomostrecent_obj = read_float(m_unit + 0x444) -- Confirmed. Total damage done by the SECOND TO MOST RECENT PLAYER (NOT TOTAL DAMAGE TO EVERYONE)
            unit_damage_secondtomostrecent_causing_objId = readident(m_unit + 0x448) -- Confirmed. the SECOND TO MOST RECENT object ID to do damage to this object (or 0xFFFFFFFF)
            unit_damage_secondtomostrecent_causing_playerId = readident(m_unit + 0x44C) -- Confirmed. Full DWORD ID of the SECOND TO MOST RECENT PLAYER to do damage to this object.. (AI = 0xFFFFFFFF)
            unit_last_damage_time_by_thirdtomostrecent_obj = read_dword(m_unit + 0x450) -- Confirmed. gameinfo_current_time - this = Time since last taken damage by the THIRD TO MOST RECENT object. (1 second = 30 ticks)
            unit_total_damage_by_thirdtomostrecent_obj = read_float(m_unit + 0x454) -- Confirmed. Total damage done by the THIRD TO MOST RECENT PLAYER (NOT TOTAL DAMAGE TO EVERYONE)
            unit_damage_thirdtomostrecent_causing_objId = readident(m_unit + 0x458) -- Confirmed. the THIRD TO MOST RECENT object ID to do damage to this object (or 0xFFFFFFFF)
            unit_damage_thirdtomostrecent_causing_playerId = readident(m_unit + 0x45C) -- Confirmed. Full DWORD ID of the THIRD TO MOST RECENT PLAYER to do damage to this object.. (AI = 0xFFFFFFFF)
            unit_last_damage_time_by_fourthtomostrecent_obj = read_dword(m_unit + 0x460) -- Confirmed. gameinfo_current_time - this = Time since last taken damage by the FOURTH TO MOST RECENT object. (1 second = 30 ticks)
            unit_total_damage_by_fourthtomostrecent_obj = read_float(m_unit + 0x464) -- Confirmed. Total damage done by the FOURTH TO MOST RECENT PLAYER (NOT TOTAL DAMAGE TO EVERYONE)
            unit_damage_fourthtomostrecent_causing_objId = readident(m_unit + 0x468) -- Confirmed. the FOURTH TO MOST RECENT object ID to do damage to this object (or 0xFFFFFFFF)
            unit_damage_fourthtomostrecent_causing_playerId = readident(m_unit + 0x46C) -- Confirmed. Full DWORD ID of the FOURTH TO MOST RECENT PLAYER to do damage to this object.. (AI = 0xFFFFFFFF)
            --Padding[4] 0x470-0x474
            unit_shooting3 = read_byte(m_unit + 0x474)                          -- Confirmed. (Shooting = 1) (No = 0) 'unused'
            --unkByte[1] 0x475-0x476 (???) 'unused'
            --Padding[2] 0x476-0x478
            unit_animation_state3 = read_byte(m_unit + 0x478) -- Same as 2 - 5 by default and 3 when berserk (from aLTis)
            --unit_aiming_speed2 = read_byte(m_unit + 0x479) -- (???) Always 0?
            --	Client Action Keypress bitmask32 (Instantaneous actions).
            unit_crouch2_presshold = read_bit(m_unit + 0x47A, 0) -- Confirmed. (True when holding crouch, False when not)
            unit_jump2_presshold = read_bit(m_unit + 0x47A, 1) -- Confirmed. (True when holding jump key, False when not)
            --	unit_user1_2 = read_bit(m_unit + 0x47A, 3) -- (???) Always false?
            --	unit_user2_2 = read_bit(m_unit + 0x47A, 4) -- (???) Always false?
            unit_flashlightkey2 = read_bit(m_unit + 0x47A, 4) -- Confirmed. (True when pressing flashlight key, False when not)
            unit_exact_facing2 = read_bit(m_unit + 0x47A, 5) -- True when AI is walking forward (from aLTis)
            unit_actionkey2 = read_bit(m_unit + 0x47A, 6) -- Confirmed. (True when pressing action key, False when not)
            unit_meleekey2 = read_bit(m_unit + 0x47A, 7) -- Confirmed. (True when pressing melee key, False when not)
            --	unit_look_without_turn2 = read_bit(m_unit + 0x47A, 8) -- (???) Always false?
            --	unit_force_alert2 = read_bit(m_unit + 0x47A, 9) -- (???) Always false?
            unit_reload_key2 = read_bit(m_unit + 0x47A, 10)                  -- Confirmed. (True when pressing action/reload key, False when not)
            unit_primaryWeaponFire_presshold2 = read_bit(m_unit + 0x47A, 11) -- Confirmed. (True when holding left click, False when not)
            unit_secondaryWeaponFire_presshold2 = read_bit(m_unit + 0x47A, 12) -- Confirmed. (True when holding right click, False when not)
            unit_grenade_presshold2 = read_bit(m_unit + 0x47A, 13)           -- Confirmed. (True when holding right click, False when not)
            unit_actionkey_presshold2 = read_bit(m_unit + 0x47A, 14)         -- Confirmed. (True when holding action key,  False when not)
            --	emptyBit[1] 15
            unit_weap_slot3 = read_byte(m_unit + 0x47C)                      -- Confirmed. (Primary = 0) (Secondary = 1) (Ternary = 2) (Quaternary = 3)
            unit_nade_type = read_byte(m_unit + 0x47E)                       -- Confirmed. (Frag = 0) (Plasma = 1)
            unit_zoom_level2 = read_word(m_unit + 0x480)                     -- Confirmed. The level of zoom the player is at. (0xFFFF = not zoomed, 0 = first zoom lvl, 1 = next zoom lvl, etc...)
            --Padding[2] 0x482-0x484
            unit_x_vel2 = read_float(m_unit + 0x484)                         -- Confirmed. Unit forward
            unit_y_vel2 = read_float(m_unit + 0x488)                         -- Confirmed. Unit left
            unit_z_vel2 = read_float(m_unit + 0x48C)                         -- Confirmed. Unit up?
            unit_primary_trigger = read_float(m_unit + 0x490)                -- Confirmed. (1 = Holding down primaryFire button) (0 = not firing) Doesn't necessarily mean unit is shooting.
            unit_x_aim4 = read_float(m_unit + 0x494)                         -- Confirmed.
            unit_y_aim4 = read_float(m_unit + 0x498)                         -- Confirmed.
            unit_z_aim4 = read_float(m_unit + 0x49C)                         -- Confirmed.
            unit_x_aim5 = read_float(m_unit + 0x4A0)                         -- Confirmed.
            unit_y_aim5 = read_float(m_unit + 0x4A4)                         -- Confirmed.
            unit_z_aim5 = read_float(m_unit + 0x4A8)                         -- Confirmed.
            unit_x_aim6 = read_float(m_unit + 0x4AC)                         -- Confirmed.
            unit_y_aim6 = read_float(m_unit + 0x4B0)                         -- Confirmed.
            unit_z_aim6 = read_float(m_unit + 0x4B4)                         -- Confirmed.
            --	bitmask32:
            unit_last_completed_client_update_id_valid = read_bit(m_unit + 0x4B8, 0) -- From OS.
            --	unkBit[31] 1-31 (???)
            unit_last_completed_client_update_id = read_dword(m_unit + 0x4BC) -- From OS.
            --Padding[12] 0x4C0-0x4CC unused.
        end

        if obj_type == 0 then -- check if object is a biped.
            -- Biped Struct. Definition is a two legged creature, but applies to ALL AI and all players.
            m_biped = object
            --	bitmask32:
            bipd_is_airborne = read_bit(m_biped + 0x4CC, 0) -- Confirmed. (Airborne = True, No = False)
            bipd_is_slipping = read_bit(m_biped + 0x4CC, 1) -- Tested. True when hit by a grenade. (from aLTis)
            bipd_is_flying = read_bit(m_biped + 0x4CC, 2) -- Tested. If true then the biped ignores gravity and flies (from aLTis)
            bipd_ignores_collision = read_bit(m_biped + 0x4CC, 3) -- Tested. Basically noclip (from aLTis)
            --	unkBit[30] 4-31

            landing_timer = read_byte(m_biped + 0x4D0)    --	Counts up when biped lands, value gets higher depending on height (from aLTis)
            landing_strentgh = read_byte(m_biped + 0x4D1) --	Instantly changes to a value depenging of how hard the fall was (from aLTis)
            bipd_movement_state = read_byte(m_biped + 0x4D2) -- Confirmed. (Standing = 0) (Walking = 1) (Idle/Turning = 2) (Gesturing?? = 3)
            --unkByte[5] 0x4D3-0x4D8 (Padding Maybe?)
            bipd_surface_id = read_dword(m_biped + 0x4D8) -- Tested. ID of the collision BSP surface the biped is walking on, 0xFFFFFFFF when in air (from aLTis)
            --unknown dword 0x4D8 + 4
            bipd_x_coord = read_float(m_biped + 0x4E0)    -- Confirmed.
            bipd_y_coord = read_float(m_biped + 0x4E4)    -- Confirmed.
            bipd_z_coord = read_float(m_biped + 0x4E8)    -- Confirmed.
            bipd_walking_counter = read_long(m_biped + 0x4EC) --	Counts up every time biped moves, not sure what's the type of this value though (from aLTis)
            bipd_bumped_obj_id = readident(m_biped + 0x4FC) -- Confirmed. Object ID of any object you bump into (rocks, weapons, players, vehicles, ANY object)
            bipd_time_since_last_bump = read_char(m_biped + 0x500) -- Tested. Counts backwards from 0 to -15 when bumped. Glitchy. Don't rely on this.
            bipd_airborne_time = read_char(m_biped + 0x501) -- Confirmed. (1 sec = 30 ticks)
            bipd_slipping_time = read_char(m_biped + 0x502) -- Counts up when hit by a grenade (from aLTis)
            bipd_walking_direction = read_char(m_biped + 0x503) -- 0 when not walking, 1 when walking forward etc (from aLTis)
            bipd_jump_time = read_char(m_biped + 0x504)   -- Tested. Counts up from 0 after landing from a jump, and returns to 0 after you hit the ground (1 sec = 30 ticks).
            bipd_melee_timer = read_byte(m_biped + 0x505) -- Time until melee is finished (by aLTis)
            --Padding[1] 0x507-0x508
            bipd_landing_thingy = read_byte(m_biped + 0x508) -- turns to 0 when landing, 1 when landing hard. 0xFF otherwise. (from aLTis)
            --Padding[2] 0x50A-0x50C
            bipd_crouch_scale = read_float(m_biped + 0x50C) -- Confirmed. How crouched you are. (0 to 1) (Crouching = 1) (Standing = 0)
            --unkFloat[1] 0x510-0x514 (???) always 0
            bipd_surface_angle_x = read_float(m_biped + 0x514) -- Tested. the angle of the surface where biped stands (from aLTis)
            bipd_surface_angle_y = read_float(m_biped + 0x518) -- Tested. the angle of the surface where biped stands (from aLTis)
            bipd_surface_angle_z = read_float(m_biped + 0x51C) -- Tested. the angle of the surface where biped stands (from aLTis)
            bipd_surface_angle_d = read_float(m_biped + 0x520) -- Tested. Not 100% sure
            --unkChar[2] 0x524-0x526 (???)
            --	bitmask8
            bipd_baseline_valid = read_bit(m_biped + 0x526, 0) -- From OS.
            --	unkBit[7] 1-7 (???)
            bipd_baseline_index = read_char(m_biped + 0x527) -- From OS.
            bipd_message_index = read_char(m_biped + 0x528) -- From OS.
            --Padding[3] 0x529-0x52C

            --	baseline update
            bipd_primary_nades = read_byte(m_biped + 0x52C)                -- Confirmed. Number of frag grenades.
            bipd_secondary_nades = read_byte(m_biped + 0x52D)              -- Confirmed. Number of plasma grenades.
            --Padding[2] 0x52E-0x530
            bipd_health = read_float(m_biped + 0x530)                      -- Confirmed. (0 to 1). Lags behind obj_health.
            bipd_shield = read_float(m_biped + 0x534)                      -- Confirmed. (0 to 1). Lags behind obj_health.
            --	bitmask8
            bipd_shield_stun_time_greater_than_zero = read_bit(m_biped + 0x538, 0) -- From OS.
            --	unkBit[7] 1-7 (???)
            --Padding[3] 0x539-0x53C
            --	bitmask8
            --	unkBit[8] 0x53C 0-7 (???)
            --Padding[3] 0x53D-0x540

            --	delta update
            --bipd_primary_nades2 = read_byte(m_biped + 0x540) -- (???) Always 0?
            --bipd_secondary_nades2 = read_byte(m_biped + 0x541) -- (???) Always 0?
            --Padding[2] 0x542-0x544
            --bipd_health2 = read_float(m_biped + 0x544) -- (???) Always 0? (0 to 1)
            --bipd_shield2 = read_float(m_biped + 0x548) -- (???) Always 0? (0 to 1)
            --	bitmask8
            bipd_shield_stun_time_greater_than_zero2 = read_bit(m_biped + 0x54C, 0) -- From OS.
            --	unkBit[7] 1-7 (???)
            --Padding[3] 0x54D-0x550

            --this function gets the material type and shader that the player is walking on. BSP only. (from aLTis)
            function GetPlayerBSPSurface(player, bsp_tag)
                local surface_touched = read_dword(player + 0x4D8)
                local tag = get_tag("sbsp", bsp_tag)
                if tag then
                    local bsp = read_dword(tag + 0x14)
                    local bsp_col = read_dword(bsp + 0xB0 + 4)
                    local surface_count = read_dword(bsp_col + 0x3C)
                    local surface_address = read_dword(bsp_col + 0x3C + 4)
                    if surface_touched <= surface_count then
                        local address = surface_address + surface_touched * 12
                        local material = read_short(address + 0x0A)
                        local materials_address = read_dword(bsp + 0xBC - 0x18 + 4)


                        local material_type = read_word(materials_address + material * 20 + 0x12)
                        local shader_name = read_string(read_dword(materials_address + material * 20 + 0x4))
                    end
                end
            end

            --these are all just friggin rediculous...
            function getBodyPart(address, offset)
                address = address + (offset or 0x0)
                local bodypart = {}
                bodypart.scale = read_float(address + 0x0) -- From 002
                bodypart.rotationx0 = read_float(address + 0x4) -- From 002
                bodypart.rotationy0 = read_float(address + 0x8) -- From 002
                bodypart.rotationz0 = read_float(address + 0xC) -- From 002
                bodypart.rotationx1 = read_float(address + 0x10) -- From 002
                bodypart.rotationy1 = read_float(address + 0x14) -- From 002
                bodypart.rotationz1 = read_float(address + 0x18) -- From 002
                bodypart.rotationx2 = read_float(address + 0x1C) -- From 002
                bodypart.rotationy2 = read_float(address + 0x20) -- From 002
                bodypart.rotationz2 = read_float(address + 0x24) -- From 002
                bodypart.x = read_float(address + 0x28) -- Confirmed.
                bodypart.y = read_float(address + 0x2C) -- Confirmed.
                bodypart.z = read_float(address + 0x30) -- Confirmed.
                return bodypart
            end

            function getBodyPartLocation(address, offset)
                address = address + (offset or 0x0)
                --unkFloats[10] (???) Probably rotations.
                bipd_bodypart_x = read_float(m_biped + 0x28)
                bipd_bodypart_y = read_float(m_biped + 0x2C)
                bipd_bodypart_z = read_float(m_biped + 0x30)
                return bipd_bodypart_x, bipd_bodypart_y, bipd_bodypart_z
            end

            --All of these are from SuperAbyll.
            --getBodyPart returns a table full of x,y,z coords + unknown floats
            --getBodyPartLocation returns 3 values (x, y, and z coordinates)
            bipd_left_thigh = getBodyPart(m_biped + 0x550)
            --if you just want the coordinates, you can do this instead for each bodypart:
            x, y, z = getBodyPartLocation(m_biped + 0x550) -- XYZ coordinates for the left thigh.
            bipd_right_thigh = getBodyPart(m_biped + 0x584)
            bipd_pelvis = getBodyPart(m_biped + 0x5B8)
            bipd_left_calf = getBodyPart(m_biped + 0x5EC)
            bipd_right_calf = getBodyPart(m_biped + 0x620)
            bipd_spine = getBodyPart(m_biped + 0x654)
            bipd_left_clavicle = getBodyPart(m_biped + 0x688)
            bipd_left_foot = getBodyPart(m_biped + 0x6BC)
            bipd_neck = getBodyPart(m_biped + 0x6F0)
            bipd_right_clavicle = getBodyPart(m_biped + 0x724)
            bipd_right_foot = getBodyPart(m_biped + 0x758)
            bipd_head = getBodyPart(m_biped + 0x78C)
            bipd_left_upper_arm = getBodyPart(m_biped + 0x7C0)
            bipd_right_upper_arm = getBodyPart(m_biped + 0x7F4)
            bipd_left_lower_arm = getBodyPart(m_biped + 0x828)
            bipd_right_lower_arm = getBodyPart(m_biped + 0x85C)
            bipd_left_hand = getBodyPart(m_biped + 0x890)
            bipd_right_hand = getBodyPart(m_biped + 0x8C4)

            --The coordinates from these can be accessed doing the following
            --let's say I want to tell the whole server the y coordinate of this object's right foot. I would do: say(bipd_right_foot.y)
            say(bipd_right_foot.y) -- **SERVER**: 52.7130341548629
        elseif obj_type == 1 then -- check if object is a vehicle
            -- vehi struct
            -- Thank you 002 and shaft for figuring out that there's a struct here:
            --	bitmask16:
            vehi_tires_blur = read_bit(m_vehicle + 0x4CC, 0) -- Tested. True when warthog's tires switch to blurred permutation (from aLTis)
            --	unkBit[2] 0x4CC 1
            vehi_crouch = read_bit(m_vehicle + 0x4CC, 2)
            vehi_jump = read_bit(m_vehicle + 0x4CC, 3)
            --	unkBit[4] 0x4CC 4-7
            vehi_physics_active_timer = read_word(m_vehicle + 0x4CE) -- Tested. 15 when physics are activated by the player (not when moved by other things), counts down to 0 otherwise (from aLTis)
            vehi_airborne_timer = read_byte(m_vehicle + 0x4D0) -- Tested. Counts up from 0 to 255 when vehicle is in the air. Hovering doesn't count. (from aLTis)
            vehi_speed = read_float(m_vehicle + 0x4D4)
            vehi_slide = read_float(m_vehicle + 0x4D8)
            vehi_turn = read_float(m_vehicle + 0x4DC)
            vehi_tireposition = read_float(m_vehicle + 0x4E0)
            vehi_treadpositionleft = read_float(m_vehicle + 0x4E4)
            vehi_treadpositionright = read_float(m_vehicle + 0x4E8)
            vehi_hover = read_float(m_vehicle + 0x4EC)
            vehi_thrust = read_float(m_vehicle + 0x4F0)
            --unkByte[4] 0x4F4-0x4F8 something to do with suspension states... enum?
            vehi_hoveringposition_x = read_float(m_vehicle + 0x4FC)
            vehi_hoveringposition_y = read_float(m_vehicle + 0x500)
            vehi_hoveringposition_z = read_float(m_vehicle + 0x504)
            vehi_collision_pushback_x = read_float(m_vehicle + 0x508) -- Tested. When colliding with another vehicle, this is how hard it will be pushed away (from aLTis)
            vehi_collision_pushback_y = read_float(m_vehicle + 0x50C) -- Tested.
            vehi_collision_pushback_z = read_float(m_vehicle + 0x510) -- Tested.
            vehi_collision_pushback_x_rot = read_float(m_vehicle + 0x514) -- Tested.
            vehi_collision_pushback_y_rot = read_float(m_vehicle + 0x518) -- Tested.
            vehi_collision_pushback_z_rot = read_float(m_vehicle + 0x51C) -- Tested.
            --unkLong[7] 0x520-0x524
            --	bitmask16
            vehi_networkTimeValid = read_bit(m_vehicle + 0x524, 0)
            --	unkBit[7] 1-7
            vehi_baselineValid = read_bit(m_vehicle + 0x524, 8)
            --	unkBit[7] 9-15
            vehi_baselineIndex = read_byte(m_vehicle + 0x526)
            vehi_messageIndex = read_byte(m_vehicle + 0x527)
            --	bitmask32
            vehi_at_rest = read_bit(m_vehicle + 0x528, 0)
            --	unkBit[30] 1-31
            vehi_x_coord = read_float(m_vehicle + 0x52C)
            vehi_y_coord = read_float(m_vehicle + 0x530)
            vehi_z_coord = read_float(m_vehicle + 0x534)
            vehi_x_vel = read_float(m_vehicle + 0x538)
            vehi_y_vel = read_float(m_vehicle + 0x53C)
            vehi_z_vel = read_float(m_vehicle + 0x540)
            vehi_x_aim_vel = read_float(m_vehicle + 0x544)
            vehi_y_aim_vel = read_float(m_vehicle + 0x548)
            vehi_z_aim_vel = read_float(m_vehicle + 0x54C)
            vehi_pitch = read_float(m_vehicle + 0x550)
            vehi_yaw = read_float(m_vehicle + 0x554)
            vehi_roll = read_float(m_vehicle + 0x558)
            vehi_x_scale = read_float(m_vehicle + 0x55C)
            vehi_y_scale = read_float(m_vehicle + 0x560)
            vehi_z_scale = read_float(m_vehicle + 0x564)
            --Padding[4] 0x568-0x56C
            vehi_x_coord2 = read_float(m_vehicle + 0x56C)
            vehi_y_coord2 = read_float(m_vehicle + 0x570)
            vehi_z_coord2 = read_float(m_vehicle + 0x574)
            vehi_x_vel2 = read_float(m_vehicle + 0x578)
            vehi_y_vel2 = read_float(m_vehicle + 0x57C)
            vehi_z_vel2 = read_float(m_vehicle + 0x580)
            vehi_x_aim_vel2 = read_float(m_vehicle + 0x584)
            vehi_y_aim_vel2 = read_float(m_vehicle + 0x588)
            vehi_z_aim_vel2 = read_float(m_vehicle + 0x58C)
            vehi_pitch2 = read_float(m_vehicle + 0x590)
            vehi_yaw2 = read_float(m_vehicle + 0x594)
            vehi_roll2 = read_float(m_vehicle + 0x598)
            vehi_x_scale2 = read_float(m_vehicle + 0x59C)
            vehi_y_scale2 = read_float(m_vehicle + 0x5A0)
            vehi_z_scale2 = read_float(m_vehicle + 0x5A4)
            --Padding[4] 0x5A8-0x5AC
            vehi_some_timer = read_dword(m_vehicle + 0x5AC) -- Tested. Vehicle respawn timer?. Can force vehicle to respawn with this (from aLTis)

            --block index of the scenario datum used for respawning
            --For all game engines besides race, this will be a scenario vehicle datum
            --For race, it's a scenario_netpoint, aka "scenario_netgame_flags_block"
            vehi_respawn_timer = read_word(m_vehicle + 0x5B0) -- Confirmed. (1 sec = 30 ticks)
            --Padding[2] 0x5B2-0x5B4
            vehi_respawn_x_coord = read_float(m_vehicle + 0x5B4) -- Respawn coordinates
            vehi_respawn_y_coord = read_float(m_vehicle + 0x5B8) -- Respawn coordinates
            vehi_respawn_z_coord = read_float(m_vehicle + 0x5BC) -- Respawn coordinates
        end

        --server network struct
        network_machine_pointer = read_dword(network_struct)             -- Confirmed.
        network_state = read_word(network_struct + 0x4)                  -- Confirmed. (Inactive = 0, Game = 1, Results = 2)
        --unkWord[1] 0x6 (???)
        network_name = readwidestring(network_struct + 0x8, 0x42)        -- Confirmed. Current server name.
        --unkWord[3] 0x86 (Padding Maybe?)
        network_current_map = read_string(network_struct + 0x8C, 0x80)   -- Confirmed. Current map the server is currently running.
        network_current_gametype = readwidestring(network_struct + 0x10C, 0x18) -- Confirmed. Current gametype that the server is currently running.
        --	partial of Gametype need to break them down.
        --	unkByte[39] (???)
        --	unkFloat[1] 0x160 (???) Always 1.
        network_score_limit = read_byte(network_struct + 0x164) -- Confirmed. Current score limit for gametype. (1 second = 30 ticks)
        --Padding[3] 0x165
        local ce = 0x0
        if game == "CE" then
            --This exists in CE but not PC, therefore making the struct size larger in CE.
            --unkByte[64] 0x168 (???)
            ce = 0x40
        end
        --unkFloat[1] 0x1A0+ce (???) --0xBAADF00D (lol)
        network_max_players = read_byte(network_struct + (0x1A5 + ce))            -- Confirmed. The maximum amount of players allowed to join the server (sv_maxplayers)
        network_difficulty_level = read_word(network_struct + (0x1A6 + ce))       -- Tested. For SP only. Always 1 for server.
        network_player_count = read_word(network_struct + (0x1A8 + ce))           -- Confirmed. Total number of players currently in the server.
        --	client network struct
        client_struct_size = 0x20                                                 -- Confirmed.
        client_network_struct = network_struct + 0x1AA + ce +
        player * client_struct_size                                               -- Strange. It starts in the middle of the dword.
        client_name = readwidestring(client_network_struct, 12)                   -- Confirmed. Name of player.
        client_color = read_word(client_network_struct + 0x18)                    -- Confirmed. Color of the player (ffa gametypes only.) (0 = white) (1 = black) (2 = red) (3 = blue) (4 = gray) (5 = yellow) (6 = green) (7 = pink) (8 = purple) (9 = cyan) (10 = cobalt) (11 = orange) (12 = teal) (13 = sage) (14 = brown) (15 = tan) (16 = maroon) (17 = salmon)
        client_icon_index = read_word(client_network_struct + 0x1A)               -- From OS.
        client_machine_index = read_byte(client_network_struct + 0x1C)            -- Confirmed. Player machine index (or rconId - 1)
        client_status = read_byte(client_network_struct + 0x1D)                   -- From Phasor. (1 = Genuine, 2 = Invalid hash (or auth, or w/e))
        client_team = read_byte(client_network_struct + 0x1E)                     -- Confirmed. (0 = red) (1 = blue)
        client_player_id = read_byte(client_network_struct + 0x1F)                -- Confirmed. Player memory id/index (0 - 15) (To clarify: this IS the 'player' argument passed to phasor functions)
        --Padding[2] 0x3AA+ce
        network_game_random_seed = read_dword(network_struct + (0x3AC + ce))      -- Tested.
        network_games_played = read_dword(network_struct + (0x3B0 + ce))          -- Confirmed. Total number of games played. (First game = 1, Second game = 2, etc..)
        network_local_data = read_dword(network_struct + (0x3B4 + ce))            -- From OS.
        --	client_machine_info struct
        client_machineinfo_size = 0x60
        if game == "CE" then
            client_machineinfo_size = 0xEC
        end
        client_machineinfo_struct = network_struct + 0x3B8 + ce + player * client_machineinfo_size
        client_connectioninfo_pointer = read_dword(client_machineinfo_struct) -- From Phasor.
        --	Padding[8] 0x4
        client_machine_index = read_word(client_machineinfo_struct + 0xC) -- Confirmed. Player machine index (or rconId - 1)
        --	unkWord[1] 0xE (Padding Maybe?)
        client_machine_unknown = read_word(client_machineinfo_struct + 0x10) -- From DZS. First is 1, then 3, then 7 and back to 0 if not in used (1 is found during the CD Hash Check, 7 if currently playing the game)
        --	unkWord[1] 0x12 (Padding Maybe?)
        --	unkLong[2] 0x14 (???)
        --	unkLong[1] 0x1C (???) most of the time 1, but sometimes changes to 2 for a moment.
        --	unkLong[1] 0x20 (???)
        --		action bitmask 16
        client_crouch = read_bit(client_machineinfo_struct + 0x24, 0) -- From DZS.
        client_jump = read_bit(client_machineinfo_struct + 0x24, 1)  -- From DZS.
        client_flashlight = read_bit(client_machineinfo_struct + 0x24, 2) -- From DZS.
        --		unkBit[5] 3-7
        client_reload = read_bit(client_machineinfo_struct + 0x24, 8) -- From DZS.
        client_fire = read_bit(client_machineinfo_struct + 0x24, 9)  -- From DZS.
        client_actionkey = read_bit(client_machineinfo_struct + 0x24, 10) -- From DZS.
        client_grenade = read_bit(client_machineinfo_struct + 0x24, 11) -- From DZS.
        --		unkBit[4] 12-15
        --	unkWord[1] 0x26 (Padding Maybe?)
        client_yaw = read_float(client_machineinfo_struct + 0x28)                    -- From DZS.
        client_pitch = read_float(client_machineinfo_struct + 0x2C)                  -- From DZS.
        client_roll = read_float(client_machineinfo_struct + 0x30)                   -- From DZS.
        --	unkByte[8] 0x34 (???)
        client_forwardVelocityMultiplier = read_float(client_machineinfo_struct + 0x3C) -- From DZS.
        client_horizontalVelocityMultiplier = read_float(client_machineinfo_struct + 0x40) -- From DZS.
        client_ROFVelocityMultiplier = read_float(client_machineinfo_struct + 0x44)  -- From DZS.
        client_weap_type = read_word(client_machineinfo_struct + 0x48)               -- Confirmed. (Primary = 0, Secondary = 1, Tertiary = 2, Quaternary = 3)
        client_nade_type = read_word(client_machineinfo_struct + 0x4A)               -- Confirmed. (Frag Grenades = 0, Plasma Grenades = 1)
        --unkWord[1] 0x4C The index is -1 if no choices are even available.
        --unkWord[2] 0x4E
        client_machine_encryption_key = read_string(client_machineinfo_struct + 0x52, 0xA) -- From Phasor. Used for encrypting packets.
        client_machineNum = read_dword(client_machineinfo_struct + 0x5C)             -- From Phasor. 0 - 0xFFFFFFFF Increased for each connection in server's life.
        if game == "CE" then
            client_last_player_name = read_string(client_machineinfo_struct + 0x60)  -- Confirmed. Changes to the player name when they quit. (Could be useful for BOS if PC had this too :/)
            client_machine_ip_address = read_string(client_machineinfo_struct + 0x80, 32) -- From Phasor.
            client_machine_player_cdhash = read_string(client_machineinfo_struct + 0xA0, 32) -- From Phasor.
            --unkByte[76] 0xC0 (???) Maybe Padding? Nothing here. Possibly was going to be used for something else?
        end

        -- machine struct
        --I've found two methods of getting this struct :D
        local method = 1
        if method == 1 then
            machine_base = read_dword(network_machine_pointer)        -- Confirmed.
            machine_table = machine_base + 0xAA0                      -- Confirmed. Player machine table
            machine_struct = read_dword(machine_table + player_machine_index * 4) -- Confirmed. Player machine struct
        elseif method == 2 then
            --This is the way most server apps do it (including Phasor) since it's less lines of code.
            machine_table = read_dword(client_connectioninfo_pointer)
            machine_struct = read_dword(machine_table)
            machine_network = read_dword(machine_network)
        end
        machine_player_first_ip_byte = read_byte(machine_struct)                                                                                                                    -- Confirmed. 127 if host.
        machine_player_second_ip_byte = read_byte(machine_struct + 0x1)                                                                                                             -- Confirmed. 0 if host.
        machine_player_third_ip_byte = read_byte(machine_struct + 0x2)                                                                                                              -- Confirmed. 0 if host.
        machine_player_fourth_ip_byte = read_byte(machine_struct + 0x3)                                                                                                             -- Confirmed. 1 if host.
        machine_player_ip_address = string.format("%i.%i.%i.%i", machine_player_first_ip_byte,
            machine_player_second_ip_byte, machine_player_third_ip_byte, machine_player_fourth_ip_byte)                                                                             -- Player's IP Address (127.0.0.1 if host)
        machine_player_port = read_word(machine_struct + 0x4)                                                                                                                       -- Confirmed. Usually 2303.

        -- address/offset checker
        --hprintf("---")

        --[[local offset = 0x0

		while offset < camera_size do

			if read_byte(camera_base, offset) ~= nil then
				hprintf(string.format("%X", offset) .. " - " .. read_byte(camera_base, offset))
			end

			offset = offset + 0x1

		end]] --
    end
end

function OnObjectCreation(objectId)
    local object = getobject(objectId)
    if object then
        local obj_type = read_word(object + 0xB4)
        if obj_type == 2 or obj_type == 3 or obj_type == 4 then
            -- item struct
            -- This applies to equipment, weapons, and garbage only.
            item_struct = object

            --	bitmask32:
            item_in_inventory = read_bit(item_struct + 0x1F4, 0) -- From OS.
            item_in_inventory2 = read_bit(item_struct + 0x1F4, 1) -- Same as above?? (from aLTis)
            item_collision = read_bit(item_struct + 0x1F4, 2)    -- Setting to true removes collision from the weapon (aLTis)
            item_on_ground = read_bit(item_struct + 0x1F4, 3)    -- Turns true when item is stationary (aLTis)
            --	unkBit[31] 3-31 (Padding Maybe?)
            item_detonation_countdown = read_word(item_struct + 0x1F8) -- Confirmed. (1 sec = 30 ticks)
            item_collision_surface_index = read_word(item_struct + 0x1FA) -- From OS.
            item_structure_bsp_index = read_word(item_struct + 0x1FC) -- From OS.
            --Padding[2] 0x1FE-0x200
            item_unknown_obj_id = readident(item_struct + 0x200)
            item_last_update_time = read_dword(item_struct + 0x204) -- From OS.
            item_unknown_obj_id2 = readident(item_struct + 0x208)
            item_unknown_x_coord = read_float(item_struct + 0x20C)
            item_unknown_y_coord = read_float(item_struct + 0x210)
            item_unknown_z_coord = read_float(item_struct + 0x214)
            item_unknown_x_vel = read_float(item_struct + 0x218)
            item_unknown_y_vel = read_float(item_struct + 0x21C)
            item_unknown_z_vel = read_float(item_struct + 0x220)
            item_rot_vel_xy = read_float(item_struct + 0x224)
            item_rot_vel_z = read_float(item_struct + 0x228) -- 1 by default?

            if obj_type == 2 then                   -- weapons
                -- weap struct
                weap_struct = object

                weap_meta_id = read_dword(weap_struct)       -- Confirmed with HMT. Tag Meta ID.
                weap_fuel = read_float(weap_struct + 0x124)  -- Confirmed. Only for Flamethrower. (0 to 1)
                weap_charge = read_float(weap_struct + 0x140) -- Confirmed. Only for Plasma Pistol. (0 to 1)
                --	weapon flags bitmask32:
                weap_overheated = read_bit(weap_struct + 0x22C, 0) -- Tested. True when weapon is overheated (from aLTis)
                weap_overheat_over = read_bit(weap_struct + 0x22C, 1) -- Tested. True when overheat animation ends (from aLTis)
                --	unkBit[3] 2 (???)
                weap_must_be_readied = read_bit(weap_struct + 0x22C, 3) -- From OS. True when reloading
                --	unkBit[28] 4-31 (???)

                --	ownerObjFlags bitmask16:
                --	unkBit[16] 0x230 0 (???)
                weapon_primary_trigger_hold = read_bit(weap_struct + 0x230, 1) -- is true when player is trying to fire (from aLTis)
                weapon_secondary_trigger_hold = read_bit(weap_struct + 0x230, 2) -- is true when player is trying to throw a grenade (from aLTis)
                weapon_reload_press = read_bit(weap_struct + 0x230, 3) -- is true when player is trying to reload (from aLTis)
                weapon_melee = read_bit(weap_struct + 0x230, 4)       -- is true when melee or grenade throw animation is playing (from aLTis)
                --unkBit[16] 0x230 5
                weapon_zoom = read_bit(weap_struct + 0x230, 6)        -- is true when zoomed in (from aLTis)
                --	unkBit[16] 0x230 7-15 (???)
                --Padding[2] 0x232-0x234
                weap_primary_trigger = read_float(weap_struct + 0x234) -- From OS.
                weap_state = read_byte(weap_struct + 0x238)      -- From OS. (0 = Idle) (1 = PrimaryFire) (2 = SecondaryFire) (3 = Chamber1) (4 = Chamber2) (5 = Reload1) (6 = Reload2) (7 = Charged1) (8 = Charged2) (9 = Ready) (10 = Put Away)
                --Padding[1] 0x239-0x23A
                weap_readyWaitTime = read_word(weap_struct + 0x23A) -- From DZS.
                weap_heat = read_float(weap_struct + 0x23C)      -- Confirmed. (0 to 1)
                weap_age = read_float(weap_struct + 0x240)       -- Confirmed. Equal to 1 - batteries. (0 to 1)
                weap_illumination_fraction = read_float(weap_struct + 0x244) -- From OS.
                weap_light_power = read_float(weap_struct + 0x248) -- From OS.
                --Padding[4] 0x24C-0x250 Unused.
                weap_tracked_objId = readident(weap_struct + 0x250) -- From OS.
                --Padding[8] 0x254-0x25C Unused.
                weap_alt_shots_loaded = read_word(weap_struct + 0x25C) -- From OS.
                --Padding[2] 0x25E-0x260

                --Trigger State:
                --Padding[1] 0x260-0x261
                weap_trigger_state = read_byte(weap_struct + 0x261)            -- From OS. 0-idle,1-firing,2-charged fire?,3-charged fire?,7-no battery
                weap_trigger_time = read_word(weap_struct + 0x262)             -- From OS.
                --	trigger_flags bitmask32:
                weap_trigger_currently_not_firing = read_bit(weap_struct + 0x264, 0) -- From DZS.
                --	unkBit[31] 0x264-0x268 1-31 (???)
                weap_trigger_autoReloadCounter = read_word(weap_struct + 0x268) -- From DZS.
                weap_trigger_firing_effect_id = read_word(weap_struct + 0x26A) -- The ID of weapon's firing effect that should play next. Somehow related to previous value (from aLTis)
                --unkWord[2] 0x26C-0x26E firing effect related. Always 0, if you set it to a higher value it counts down with every shot. No idea what this is
                weap_trigger_rounds_since_last_tracer = read_word(weap_struct + 0x26E) -- From OS.
                weap_trigger_rate_of_fire = read_float(weap_struct + 0x270)    -- From OS.
                weap_trigger_ejection_port_recovery_time = read_float(weap_struct + 0x274) -- From OS.
                weap_trigger_illumination_recovery_time = read_float(weap_struct + 0x278) -- From OS.
                --unkFloat[1] 0x27C-0x280 used in the calculation of projectile error angle
                weap_trigger_charging_effect_id = readident(weap_struct + 0x280) -- From OS.
                --unkByte[4] 0x284-0x288 (???)
                --Padding[1] 0x288-0x289
                weap_trigger2_state = read_byte(weap_struct + 0x289)            -- From OS. Some counter.
                weap_trigger2_time = read_word(weap_struct + 0x28A)             -- From OS.
                --	trigger_flags bitmask32:
                weap_trigger2_currently_not_firing = read_bit(weap_struct + 0x28C, 0) -- From DZS.
                --	unkBit[31] 0x28C-0x290 1-31 (???)
                weap_trigger2_autoReloadCounter = read_dword(weap_struct + 0x290) -- From DZS.
                --unkWord[2] 0x294-0x296 firing effect related.
                weap_trigger2_rounds_since_last_tracer = read_word(weap_struct + 0x296) -- From OS.
                weap_trigger2_rate_of_fire = read_float(weap_struct + 0x298)    -- From OS.
                weap_trigger2_ejection_port_recovery_time = read_float(weap_struct + 0x29C) -- From OS.
                weap_trigger2_illumination_recovery_time = read_float(weap_struct + 0x2A0) -- From OS.
                --unkFloat[1] 0x2A4-0x2A8 used in the calculation of projectile error angle
                weap_trigger2_charging_effect_id = readident(weap_struct + 0x2A8) -- From OS.
                --unkByte[4] 0x2AC-0x2B0 (???)

                --Primary Magazine State:
                weap_mag1_state = read_word(weap_struct + 0x2B0)       -- From OS. (0 = Idle) (1 = Chambering Start) (2 = Chambering Finish) (3 = Chambering)
                weap_mag1_chambering_time = read_word(weap_struct + 0x2B2) -- From OS. Can set to 0 to finish reloading. (1 sec = 30 ticks)
                weap_reload_animation_frame_count = read_word(weap_struct + 0x2B4) -- Tested. Same as in animation tag (from aLTis)
                weap_primary_ammo = read_word(weap_struct + 0x2B6)     -- Confirmed. Unloaded ammo for magazine 1.
                weap_primary_clip = read_word(weap_struct + 0x2B8)     -- Confirmed. Loaded clip for magazine 1.
                --unkWord[3] 0x2BA-0x2C0 game tick value,unkWord,possible enum

                --Secondary Magazine State:
                weap_mag2_state = read_word(weap_struct + 0x2C0) -- From OS. (0 = Idle) (1 = Chambering Start) (2 = Chambering Finish) (3 = Chambering)
                weap_mag2_chambering_time = read_word(weap_struct + 0x2C2) -- From OS. Can set to 0 to finish reloading. (1 sec = 30 ticks)
                --unkWord[1] 0x2C4-0x2C6 game tick based value (animations?)
                weap_secondary_ammo = read_word(weap_struct + 0x2C6) -- Confirmed. Unloaded ammo for magazine 1.
                weap_secondary_clip = read_word(weap_struct + 0x2C8) -- Confirmed. Loaded clip for magazine 1.
                --unkWord[3] 0x2CA-0x2D0 game tick value,unkWord,possible enum

                weap_last_fired_time = read_dword(weap_struct + 0x2D0) -- From DZS. gameinfo_current_time - this = time since this weapon was fired. (1 second = 30 ticks)
                weap_mag1_starting_total_rounds = read_word(weap_struct + 0x2D4) -- From OS. The total unloaded primary ammo the weapon has by default.
                weap_mag1_starting_loaded_rounds = read_word(weap_struct + 0x2D6) -- From OS. The total loaded primary clip the weapon has by default.
                weap_mag2_starting_total_rounds = read_word(weap_struct + 0x2D8) -- From OS. The total unloaded secondary ammo the weapon has by default.
                weap_mag2_starting_loaded_rounds = read_word(weap_struct + 0x2DA) -- From OS. The total loaded secondary clip the weapon has by default.
                --unkByte[4] 0x2DC-0x2E0 (Padding Maybe?)
                weap_baseline_valid = read_byte(weap_struct + 0x2E0)  -- From OS.
                weap_baseline_index = read_byte(weap_struct + 0x2E1)  -- From OS.
                weap_message_index = read_byte(weap_struct + 0x2E2)   -- From OS.
                --Padding[1] 0x2E3-0x2E4
                weap_x_coord = read_float(weap_struct + 0x2E4)        -- Spawn coordinates (from aLTis)
                weap_y_coord = read_float(weap_struct + 0x2E8)        -- Spawn coordinates (from aLTis)
                weap_z_coord = read_float(weap_struct + 0x2EC)        -- Spawn coordinates (from aLTis)
                weap_x_vel = read_float(weap_struct + 0x2F0)          -- From OS.
                weap_y_vel = read_float(weap_struct + 0x2F2)          -- From OS.
                weap_z_vel = read_float(weap_struct + 0x2F4)          -- From OS.
                --Padding[12] 0x2F8-0x300
                weap_primary_ammo2 = read_word(weap_struct + 0x300)   -- From OS. Unloaded ammo for magazine 1.
                weap_secondary_ammo2 = read_word(weap_struct + 0x302) -- From OS. Unloaded ammo for magazine 2.
                weap_age2 = read_float(weap_struct + 0x304)           -- From OS. Equal to 1 - batteries. (0 to 1)
                --Duplicates of above below this point, will add later.
            elseif obj_type == 3 then                                 -- equipment
                -- eqip struct
                eqip_struct = item_struct

                --unkByte[16] 0x22C-0x23C (???) possibly unused?
                --unkByte[8] 0x23C-0x244 (???) possibly unused?
                --	bitmask8:
                eqip_baseline_valid = read_bit(eqip_struct + 0x244, 0) -- From OS.
                --	unkBit[7] 1-7 (Padding Maybe?)
                eqip_baseline_index = read_char(eqip_struct + 0x245) -- From OS.
                eqip_message_index = read_char(eqip_struct + 0x246) -- From OS.
                --Padding[1] 0x247-0x248
                -- baseline update
                eqip_x_coord = read_float(eqip_struct + 0x248) -- Spawn coordinates (from aLTis)
                eqip_y_coord = read_float(eqip_struct + 0x24C) -- Spawn coordinates (from aLTis)
                eqip_z_coord = read_float(eqip_struct + 0x250) -- Spawn coordinates (from aLTis)
                eqip_x_vel = read_float(eqip_struct + 0x254) -- From OS.
                eqip_y_vel = read_float(eqip_struct + 0x258) -- From OS.
                eqip_z_vel = read_float(eqip_struct + 0x25C) -- From OS.
                eqip_pitch_vel = read_float(eqip_struct + 0x260) -- From OS.
                eqip_yaw_vel = read_float(eqip_struct + 0x264) -- From OS.
                eqip_roll_vel = read_float(eqip_struct + 0x268) -- From OS.

                --	delta update
                --	bitmask8:
                eqip_delta_valid = read_bit(eqip_struct + 0x26C, 0) -- Guess.
                --	unkBit[7] 1-7 (Padding Maybe?)
                --Padding[3] 0x26D-0x270
                eqip_x_coord2 = read_float(eqip_struct + 0x270) -- From OS.
                eqip_y_coord2 = read_float(eqip_struct + 0x274) -- From OS.
                eqip_z_coord2 = read_float(eqip_struct + 0x278) -- From OS.
                eqip_x_vel2 = read_float(eqip_struct + 0x27C) -- From OS.
                eqip_y_vel2 = read_float(eqip_struct + 0x280) -- From OS.
                eqip_z_vel2 = read_float(eqip_struct + 0x284) -- From OS.
                eqip_pitch_vel2 = read_float(eqip_struct + 0x288) -- From OS.
                eqip_yaw_vel2 = read_float(eqip_struct + 0x28C) -- From OS.
                eqip_roll_vel2 = read_float(eqip_struct + 0x290) -- From OS.
            elseif obj_type == 4 then                 -- garbage object
                -- garbage struct
                garb_struct = item_struct

                garb_time_until_garbage = read_word(garb_struct + 0x22C) -- From OS.
                --Padding[2] 0x22E-0x230
                --Padding[20] 0x230-0x244 unused
            elseif obj_type == 5 then -- projectile
                -- proj struct
                proj_struct = object

                --It appears Smiley didn't know how to read Open-Sauce very effectively, which explains the previous failure in this projectile structure's documentation:

                proj_mapId = readident(proj_struct + 0x0) -- Confirmed.
                --INSERT REST OF OBJECT STRUCT FROM 0x4 TO 0x1F4 HERE
                --Padding[52] 0x1F4-0x22C -- Item data struct not used in projectile.

                --unkBit 0
                proj_contrail = read_bit(proj_struct + 0x22C, 1) -- Tested. If true then projectile will have a contrail
                --unkBit 2
                proj_frozen = read_bit(proj_struct + 0x22C, 3) -- Tested. If true then the projectile will be frozen in time (from aLTis)
                proj_at_rest = read_bit(proj_struct + 0x22C, 4) -- Tested. If true then the grenade detonation timer starts (from aLTis)
                proj_at_rest2 = read_bit(proj_struct + 0x22C, 5) -- Tested. Same as above?? (from aLTis)
                --unkBit 6-31 unused

                proj_action = read_word(proj_struct + 0x230)         -- From OS. (enum) 0-explodes, 1-disappears, everything higher will make projectile freeze (from aLTis)
                proj_material = read_word(proj_struct + 0x232)       -- Tested. Material type that the projectile touched (from aLTis)
                proj_source_obj_id = readident(proj_struct + 0x234)  -- From OS.
                proj_target_obj_id = readident(proj_struct + 0x238)  -- From OS.
                proj_contrail_attachment_index = read_dword(proj_struct + 0x23C) -- From OS. index for the proj's definition's object_attachment_block, index is relative to object.attachments.attachment_indices or -1
                proj_time_remaining = read_float(proj_struct + 0x240) -- From OS. Time remaining to target.
                proj_detonation_time = read_float(proj_struct + 0x244) -- Tested. Math for this: (1/30/'timer' from projectile tag) (from aLTis)
                proj_arming_timer = read_float(proj_struct + 0x248)  -- Tested. If 'aiming time' in tag is not 0, then this tells how long the projectile has existed in seconds (from aLTis)
                proj_arming_time = read_float(proj_struct + 0x24C)   --Tested. Math for this: (1/30/'arming time' from projectile tag) (from aLTis)
                proj_range_traveled = read_float(proj_struct + 0x250) -- From OS. If the proj definition's "maximum range" is > 0, divide this value by "maximum range" to get "range remaining".
                proj_x_vel = read_float(proj_struct + 0x254)         -- From OS.
                proj_y_vel = read_float(proj_struct + 0x258)         -- From OS.
                proj_z_vel = read_float(proj_struct + 0x25C)         -- From OS.
                proj_water_damage_range = read_float(proj_struct + 0x260) --Tested. set to water_damage_range's maximum.
                proj_pitch = read_float(proj_struct + 0x264)         -- From OS.
                proj_yaw = read_float(proj_struct + 0x268)           -- From OS.
                proj_roll = read_float(proj_struct + 0x26C)          -- From OS.
                --unkFloat[2] 0x270-0x278 real_euler_angles2d
                --unkBit[8] 0x278-0x279 (???) -- first bit is true for grenades
                --	bitmask8:
                proj_baseline_valid = read_bit(proj_struct + 0x279, 0) -- From OS.
                --	unkBit[7] 1-7
                proj_baseline_index = read_char(proj_struct + 0x27A) -- From OS.
                proj_message_index = read_char(proj_struct + 0x27B) -- From OS.

                --	baseline update
                proj_x_coord = read_float(proj_struct + 0x27C) -- From OS.
                proj_y_coord = read_float(proj_struct + 0x280) -- From OS.
                proj_z_coord = read_float(proj_struct + 0x284) -- From OS.
                proj_x_vel2 = read_float(proj_struct + 0x288) -- From OS.
                proj_y_vel2 = read_float(proj_struct + 0x28C) -- From OS.
                proj_z_vel2 = read_float(proj_struct + 0x290) -- From OS.
                --unkBit[8] 0x294-0x295 delta_valid?
                --Padding[3] 0x295-0x298

                --	delta update
                proj_x_coord2 = read_float(proj_struct + 0x298) -- From OS.
                proj_y_coord2 = read_float(proj_struct + 0x29C) -- From OS.
                proj_z_coord2 = read_float(proj_struct + 0x2A0) -- From OS.
                proj_x_vel3 = read_float(proj_struct + 0x2A4) -- From OS.
                proj_y_vel3 = read_float(proj_struct + 0x2A8) -- From OS.
                proj_z_vel3 = read_float(proj_struct + 0x2AC) -- From OS.
            elseif obj_type >= 6 and obj_type <= 9 then -- device
                -- device struct
                device_struct = object

                device_position_reversed = read_bit(device_struct + 0x1F4, 0) -- Tested. Same as in the tag (from aLTis)
                --	unkBit 1-2 they do something but not sure what
                --	unkBit 3-31 unused?

                device_power_group_index = read_word(device_struct + 0x1F8) -- From OS.
                --Padding[2] 0x1FA-0x1FC
                device_power_amount = read_float(device_struct + 0x1FC) -- From OS.
                device_power_change = read_float(device_struct + 0x200) -- From OS.
                device_position_group_index = read_word(device_struct + 0x204) -- From OS.
                --Padding[2] 0x206-0x208
                device_position_amount = read_float(device_struct + 0x208) -- From OS.
                device_position_change = read_float(device_struct + 0x20C) -- From OS.
                --	user interaction bitmask32:
                device_one_sided = read_bit(device_struct + 0x210, 0)   -- From OS.
                device_operates_automatically = read_bit(device_struct + 0x210, 1) -- From OS.
                --	unkBit[30] 2-31 (Padding Maybe?)

                if obj_type == 7 then -- machine
                    -- mach struct
                    mach_struct = device_struct

                    mach_does_not_operate_automatically = read_bit(device_struct + 0x214, 0) -- Tested. Same as in tag (from aLTis)
                    --unkBit 1-2 maybe flags one sided and never appears locked?
                    mach_opened_by_melee = read_bit(device_struct + 0x214, 3) -- Tested. Same as in tag (from aLTis)
                    --unkBit 4-31
                    mach_door_timer = read_dword(mach_struct + 0x218)         -- Tested. looks like a timer used for door-type machines.
                    mach_elevator_x_coord = read_dword(mach_struct + 0x21C)   -- From OS.
                    mach_elevator_y_coord = read_dword(mach_struct + 0x220)   -- From OS.
                    mach_elevator_z_coord = read_dword(mach_struct + 0x224)   -- From OS.
                elseif obj_type == 8 then                                     -- control
                    -- ctrl struct
                    ctrl_struct = device_struct

                    ctrl_flags = read_dword(mach_struct + 0x214) -- breakdown coming soon!
                    ctrl_custom_name_index = read_word(mach_struct + 0x218) -- From OS.
                    --Padding[2] 0x21A-0x21C
                elseif obj_type == 9 then -- lightfixture
                    --lightfixture struct
                    lifi_struct = device_struct

                    lifi_red_color = read_float(lifi_struct + 0x214) -- From OS.
                    lifi_green_color = read_float(lifi_struct + 0x218) -- From OS.
                    lifi_blue_color = read_float(lifi_struct + 0x21C) -- From OS.
                    lifi_intensity = read_float(lifi_struct + 0x220) -- From OS.
                    lifi_falloff_angle = read_float(lifi_struct + 0x224) -- From OS.
                    lifi_cutoff_angle = read_float(lifi_struct + 0x228) -- From OS.
                end
            end
        end
    end
end

function readident(address, offset)
    address = address + (offset or 0)
    identity = read_dword(address)             -- DWORD ID.
    --	Thank you WaeV for helping me wrap my head around this.
    ident_table_index = read_word(address)     -- Confirmed. This is what most functions use. (player number, object index, etc)
    ident_table_flags = read_byte(address + 0x2) -- Tested. From Phasor. 0x44 by default, dunno what they're for.
    ident_type = read_byte(address + 0x3)      -- Confirmed. [Object values: (Weapon = 6) (Vehicle = 8) (Others = -1) (Probably more)]
    return identity
end

function getplayer(player_number)
    player_number = tonumber(player_number) or
    raiseerror("bad argument #1 to getplayer (valid player required, got " .. tostring(type(player_number)) .. ")")
    -- player header setup
    local player_header = read_dword(player_header_pointer) - 0x8 -- Confirmed. (0x4029CE88)
    local player_header_size = 0x40                            -- Confirmed.

    -- player header
    --Padding[8] 0x0-0x8
    local player_header_name = read_string(player_header + 0x8, 0xE)       -- Confirmed. Always "players".
    --Padding[24] 0x10-0x20
    local player_header_maxplayers = read_word(player_header + 0x28)       -- Confirmed. (0 - 16)
    local player_struct_size = read_word(player_header + 0x2A)             -- Confirmed. (0x200 = 512)
    local player_header_data = read_string(player_header + 0x30, 0x4)      -- Confirmed. Always "@t@d". Translates to data?
    local player_header_ingame = read_word(player_header + 0x34)           -- Tested. Always seems to be 0 though... (In game = 0) (Not in game = 1)
    local player_header_current_players = read_word(player_header + 0x36)  -- Confirmed.
    local player_header_next_player_id = readident(player_header + 0x38)   -- Confirmed. Full DWORD ID of the next player to join.
    local player_header_first_player_struct = readident(player_header + 0x3C) -- Confirmed with getplayer(0). Player struct of the first player. (0x4029CEC8 for PC/CE)

    -- player struct setup
    local player_base = player_header + player_header_size                -- Confirmed. (0x4029CEC8)
    local player_struct = player_base + (player_number * player_struct_size) -- Confirmed with getplayer(player).

    return player_struct
end

function getLowerWord16(x)
    local highervals = math.floor(x / 2 ^ 16)
    highervals = highervals * 2 ^ 16
    local lowervals = x - highervals
    return lowervals
end

function rshift(x, by)
    return math.floor(x / 2 ^ by)
end

function getobject(objectId)
    -- obj header setup
    local obj_header = read_dword(obj_header_pointer) -- Confirmed. (0x4005062C)
    local obj_header_size = 0x38                   -- Confirmed.

    -- obj header
    local obj_header_name = read_string(obj_header, 0x6)         -- Confirmed. Always "object".
    local obj_header_maxobjs = read_word(obj_header + 0x20)      -- Confirmed. (0x800 = 2048 objects)
    local obj_table_size = read_word(obj_header + 0x22)          -- Confirmed. (0xC = 12)
    local obj_header_data = read_string(obj_header + 0x28, 0x3)  -- Confirmed. Always "@t@d". Translates to data?
    local obj_header_objs = read_word(obj_header + 0x2C)         -- Needs to be tested.
    local obj_header_current_maxobjs = read_word(obj_header + 0x2E) -- Tested.
    local obj_header_current_objs = read_word(obj_header + 0x30) -- Tested.
    local obj_header_next_obj_index = read_word(obj_header + 0x32) -- Tested. Corresponds with obj_struct_obj_index.
    local obj_table_base_pointer = read_dword(obj_header + 0x34) -- Confirmed. (0x40050664)
    --local obj_header_next_obj_id = readident(obj_header + 0x34) -- Incorrect?
    --local obj_header_first_obj = readident(obj_header + 0x36) -- Incorrect?

    -- obj table setup
    local obj_table_index = getLowerWord16(objectId)                                 -- grab last two bytes of objId
    local obj_table_flags = rshift(objectId, 4 * 4) - rshift(objectId, 6 * 4) * 0x100 -- part of the objId salt
    local obj_table_type = rshift(objectId, 6 * 4)                                   -- part of the objId salt
    local obj_table_base = obj_header + obj_header_size                              -- Confirmed. (0x40050664)
    local obj_table_address = obj_table_base + (obj_table_index * obj_table_size) + 0x8 -- Confirmed.

    -- obj_table (needs testing)
    local obj_struct = read_dword(obj_table_address + 0x0)       -- Confirmed with getobject().
    local obj_struct_obj_id = read_word(obj_table_address + 0x2) -- (???)
    local obj_struct_obj_index = read_word(obj_table_address + 0x4) -- Tested. Corresponds with obj_header_next_obj_index.
    local obj_struct_size = read_word(obj_table_address + 0x6)   -- Wrong offset?

    return obj_struct
end

function gettagaddress(tagtype, tagname)
    -- map header
    local map_header_size = 0x800                                          -- Confirmed. (2048 bytes)
    local map_header_head = read_string(map_header_base, 4, true)          -- Confirmed. "head" (head = daeh)
    local map_header_version = read_byte(map_header_base + 0x4)            -- Confirmed. (Xbox = 5) (Trial = 6) (PC = 7) (CE = 0x261 = 609)
    local map_header_map_size = read_dword(map_header_base + 0x8, 0x3)     -- Confirmed. (Bytes)
    local map_header_index_offset = read_dword(map_header_base + 0x10, 0x2) -- Confirmed. (Hex)
    local map_header_meta_data_size = read_dword(map_header_base + 0x14, 0x2) -- Confirmed. (Hex)
    local map_header_map_name = read_string(map_header_base + 0x20, 0x9)   -- Confirmed.
    local map_header_build = read_string(map_header_base + 0x40, 12)       -- Confirmed.
    local map_header_map_type = read_byte(map_header_base + 0x60)          -- Confirmed. (SP = 0) (MP = 1) (UI = 2)
    -- Something from 0x64 to 0x67.
    local map_header_foot = read_string(map_header_base + 0x7FC, 4, true)  -- Confirmed. "foot" (foot = toof)

    --tag table setup
    local map_base = read_dword(map_pointer)               -- Confirmed. (0x40440000)
    local tag_table_base_pointer = read_dword(map_base)
    local tag_table_first_tag_id = read_dword(map_base + 0x4) -- Confirmed. Also known as the scenario tagId.
    local tag_table_tag_id = read_dword(map_base + 0x8)    -- Confirmed. MapId/TagId for specified tag
    local tag_table_count = read_dword(map_base + 0xC)     -- Confirmed. Number of tags in the tag table.
    local map_verticie_count = read_dword(map_base + 0x10)
    local map_verticie_offset = read_dword(map_base + 0x14)
    local map_indicie_count = read_dword(map_base + 0x18)
    local map_indicie_offset = read_dword(map_base + 0x1C)
    local map_model_data_size = read_dword(map_base + 0x20)
    local tag_table_tags = read_string(map_base + 0x24, 4, true) -- Confirmed. "tags" (tags = sgat)
    local tag_table_base = read_dword(map_base)               -- Confirmed. (0x40440028)
    local tag_table_size = 0x20                               -- Confirmed.
    local tag_allocation_size = 0x01700000                    -- From OS.
    local tag_max_address = map_base + tag_allocation_size    -- From OS. (0x41B40000)

    -- tag table
    -- the scenario is always the first tag located in the table.
    local scnr_tag_class1 = read_string(tag_table_base, 4, true)    -- Confirmed. "weap", "obje", etc. (weap = paew). Never 0xFFFF.
    local scnr_tag_class2 = read_string(tag_table_base + 0x4, 4, true) -- Confirmed. "weap", "obje", etc. (weap = paew) 0xFFFF if not existing.
    local scnr_tag_class3 = read_string(tag_table_base + 0x8, 4, true) -- Confirmed. "weap", "obje", etc. (weap = paew) 0xFFFF if not existing.
    local scnr_tag_id = readident(tag_table_base + 0xC)             -- Confirmed. TagID/MapID/MetaID
    local scnr_tag_name_address = read_dword(tag_table_base + 0x10) -- Confirmed. Pointer to the tag name.
    local scnr_tag_name = read_string(scnr_tag_name_address)        -- Confirmed. Name of the tag ("weapons\\pistol\\pistol")
    local scnr_tag_data_address = read_dword(tag_table_base + 0x14) -- Confirmed. This is where map mods made with Eschaton/HMT/HHT are stored.
    --unkByte[8]

    local tag_address = 0
    for i = 0, (tag_table_count - 1) do
        local tag_class = read_string(tag_table_base, (tag_table_size * i), 4)
        local tag_id = read_dword(tag_table_base + 0xC + (tag_table_size * i))
        local tag_name_address = read_dword(tag_table_base + 0x10 + tag_table_size * i)
        local tag_name = read_string(tag_name_address)

        --this function can accept mapId or tagtype, tagname
        if tag_id == tagtype or (tag_class == tagtype and tag_name == tagname) then
            tag_address = todec(read_dword(tag_table_base + 0x14 + (tag_table_size * i)))
            break
        end
    end

    return tag_address
end

function endian(address, offset, length)
    if offset and not length then
        length = offset
        offset = nil
    end
    local data_table = {}
    local data = ""

    for i = 0, length do
        local hex = string.format("%X", read_byte(address, offset + i))

        if tonumber(hex, 16) < 16 then
            hex = 0 .. hex
        end

        table.insert(data_table, hex)
    end

    for k, v in pairs(data_table) do
        data = v .. data
    end

    return data
end

function tohex(number)
    return string.format("%X", number)
end

function todec(number)
    return tonumber(number, 16)
end
