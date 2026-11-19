--[[
===============================================================================
SCRIPT NAME:    vehicle_library.lua
DESCRIPTION:    Configuration data for stock and custom vehicles, including seat roles and display names.

STRUCTURE:      vehicle_tag (string):       The tag path of the vehicle (e.g., 'vehicles\\warthog\\mp_warthog')
                seat_roles (table):         A table mapping seat indices to their role names
                enabled (boolean):          Whether this vehicle is enabled
                display_name (string):      Vehicle name (label)


USAGE:          local vehicle_library = require("vehicle_library")
                local banshee

                for i = 1, #vehicle_library do
                    local vehicle = vehicle_library[i]
                    if vehicle[1] == "vehicles\\banshee\\banshee_mp" then
                        banshee = vehicle
                        break
                    end
                end

                if banshee then
                    local tag_path = banshee[1]
                    local seat_roles = banshee[2]
                    local enabled = banshee[3]
                    local display_name = banshee[4]
                end


Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:    MIT License
			https://github.com/Chalwk/SPCLib/blob/main/LICENSE
=====================================================================================
]]

return {

    --================--
    -- STOCK VEHICLES:
    --================--

    {
        'vehicles\\warthog\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Chain Gun Hog'
    },

    {
        'vehicles\\rwarthog\\rwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Rocket Hog'
    },

    {
        'vehicles\\banshee\\banshee_mp',
        {
            [0] = 'driver'
        },
        true,
        'Banshee'
    },

    {
        'vehicles\\c gun turret\\c gun turret_mp',
        {
            [0] = 'gunner'
        },
        true,
        'Turret'
    },

    {
        'vehicles\\scorpion\\scorpion_mp',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'passenger',
            [3] = 'passenger',
            [4] = 'passenger'
        },
        true,
        'Tank'
    },

    {
        'vehicles\\ghost\\ghost_mp',
        {
            [0] = 'driver'
        },
        true,
        'Ghost'
    },

    --================--
    -- CUSTOM VEHICLES:
    --================--

    -- []h3[]christmas, celebration_island
    {
        'vehicles\\halo3warthog\\h3 mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H3 Warthog'
    },

    -- [h3]_sandtrap
    {
        'halo3\\vehicles\\mongoose\\mongoose',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Mongoose'
    },

    -- [h3]_sandtrap
    {
        'halo3\\vehicles\\warthog\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H2 Warthog'
    },

    -- [FBI]bloodgulch
    {
        'h2\\objects\\vehicles\\warthog\\warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H2 Warthog'
    },

    -- [h3style]containment
    {
        'vehicles\\cwarthog\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'CWarthog'
    },

    -- arctic_battleground, artillery_zone, battleforbloodgulch, bloodground_aco, cold_war, doomsday, esther, separated
    {
        'vehicles\\mwarthog\\mwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Missile Warthog'
    },

    -- atephobia
    {
        'vehicles\\warthog\\rw mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- atephobia
    {
        'vehicles\\rwarthog\\rw rwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'RWarthog'
    },

    -- atomic
    {
        'vehicles\\dangermobile\\dangermobile',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Dangermobile'
    },

    -- atomic
    {
        'vehicles\\doombuggy\\doombuggy',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Doombuggy'
    },

    -- battle
    {
        'vehicles\\civihog\\civihog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Civilian Hog'
    },

    -- bc_raceway_final_mp
    {
        'levels\\test\\racetrack\\custom_hogs\\mp_warthog',
        {
            [0] = 'driver',
            [2] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- bc_raceway_final_mp
    {
        'levels\\test\\racetrack\\custom_hogs\\mp_warthog_blue',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- bc_raceway_final_mp
    {
        'levels\\test\\racetrack\\custom_hogs\\mp_warthog_green',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- bc_raceway_final_mp
    {
        'levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi1',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- bc_raceway_final_mp
    {
        'levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi2',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- bc_raceway_final_mp
    {
        'levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi3',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- beryl_rescue, casualty_isle__v2, erosion
    {
        'vehicles\\rwarthog\\art_rwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Art Rocket Warthog'
    },

    -- beryl_rescue, delta_ruined, destiny, grove_final
    {
        'vehicles\\warthog\\art_cwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Art CWarthog'
    },

    -- Bigass
    {
        'bourrin\\halo reach\\vehicles\\warthog\\h2 mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H2 Warthog'
    },

    -- Bigass
    {
        'bourrin\\halo reach\\vehicles\\warthog\\rocket warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Rocket Warthog'
    },

    -- bob_omb_battlefield, coldsnap, combat_arena, extinction, frozen-path, hypothermia_race, hypothermia_v0.1, hypothermia_v0.2, hypo_v0.3
    {
        'vehicles\\g_warthog\\g_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'G Warthog'
    },

    -- bumper_cars_v2
    {
        'vehicles\\civvi\\civilian warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Civilian Warthog'
    },

    -- bumper_cars_v2
    {
        'vehicles\\warthog\\mp_warthogc',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog C'
    },

    -- camden_place
    {
        'vehicles\\fwarthog\\mp_fwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Flame Warthog'
    },

    -- celebration_island, hornets_nest
    {
        'halo3\\vehicles\\warthog\\rwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H3 Rocket Hog'
    },

    -- cityscape-adrenaline
    {
        'vehicles\\g_warthog\\g_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog'
    },

    -- cityscape-adrenaline
    {
        'vehicles\\rwarthog\\boogerhawg',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog'
    },

    -- cmt_cliffrun
    {
        'vehicles\\cmt_warthog\\chaingun_variant',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'CMT Chaingun Hog'
    },

    -- cmt_cliffrun
    {
        'vehicles\\cmt_warthog\\rocket_variant',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'CMT Rocket Hog'
    },

    -- cnr_island, desertdunestwo
    {
        'vehicles\\rancher\\rancher',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Rancher'
    },

    -- cnr_island
    {
        'vehicles\\sultan\\sultan',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Sultan'
    },

    -- cold_war
    {
        'vehicles\\warthog\\h2 mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H2 Warthog'
    },

    -- coldsnap
    {
        'vehicles\\coldsnap_hogs\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog'
    },

    -- combat_arena
    {
        'vehicles\\gausshog\\gausshog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Gauss Hog'
    },

    -- concealed_custom
    {
        'vehicles\\warthog_legend\\warthog_legend',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Legend Warthog'
    },

    -- concealed_custom
    {
        'vehicles\\rwarthog_legend\\rwarthog_legend',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Legend Rocket Warthog'
    },

    -- cursed-beavercreek, cursed-bloodgulch, cursed-chillout, cursed-damnation, cursed-deathisland, cursed-derelict, cursed-hangemhigh, cursed-sidewinder, cursed-wizard
    {
        'vehicles\\c warthog\\c warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'C Warthog'
    },

    -- deathrace, Human_Landscape, Jeep_Cliffs
    {
        'vehicles\\civihog\\mp_civihog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Civilian Hog'
    },

    -- desert_storm_v2
    {
        'vehicles\\trans_hog\\trans_hog',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Transport Hog'
    },

    -- desertdunestwo
    {
        'vehicles\\walton\\walton',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Walton'
    },

    -- discovery
    {
        'vehicles\\warthog\\realistic\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Realistic Warthog'
    },

    -- facing_worldsrx, gladiators_brawl, huh-what_3
    {
        'vehicles\\puma\\puma',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Puma'
    },

    -- first
    {
        'vehicles\\snow_civ_hog\\snow_civ_hog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Snow Civilian Hog'
    },

    -- fox_island_insane
    {
        'vehicles\\ravhog\\ravhog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Rav Hog'
    },

    -- gauntlet_race
    {
        'vehicles\\rwarthog2\\rwarthog2',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog'
    },

    -- gladiators_brawl
    {
        'vehicles\\warthog\\flamehog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Flamehog'
    },

    -- glenns_castle, hypo_v0.3, hypothermia_race, hypothermia_v0.1, hypothermia_v0.2
    {
        'vehicles\\civvi\\civvi',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Civvi'
    },

    -- glupo_aco
    {
        'vehicles\\sandking\\sandking',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Sandking'
    },

    -- green_canyon
    {
        'vehicles\\rwarthog\\rwarthogfix',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Fixed Rocket Warthog'
    },

    -- green_canyon
    {
        'vehicles\\warthog\\mp_warthogfix',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Fixed Warthog'
    },

    -- Halloween_Gulch_V2
    {
        'vehicles\\rwarthog\\hellrwarthogv2',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Hell Rocket Warthog V2'
    },

    -- Halloween_Gulch_V2
    {
        'vehicles\\warthog\\hellhogv2',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Hellhog V2'
    },

    -- hillbilly mudbog
    {
        'vehicles\\rpchog\\rpchog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'RPC Hog'
    },

    -- hogracing_day, hogracing_night
    {
        'vehicles\\puma\\puma_xt',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Puma XT'
    },

    -- hornets_nest
    {
        'halo3\\vehicles\\warthog\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'H3 Warthog'
    },

    -- hq_racetrack
    {
        'vehicles\\sporthog\\smileyhog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Smiley Hog'
    },

    -- hydrolysis
    {
        'vehicles\\newboathog\\newboathog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'New Boat Hog'
    },

    -- Mongoose_Point
    {
        'vehicles\\m257_multvp\\m257_multvp',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Mongoose'
    },

    -- Mongoose_Point
    {
        'vehicles\\m257_multvp\\m257_multvp2',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Mongoose'
    },

    -- liberty_nightglow
    {
        'altis\\vehicles\\mongoose\\mongoose',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Quad'
    },

    -- liberty_blockfort_race
    {
        'altis\\vehicles\\mongoose\\mongoose',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Quad'
    },

    -- liberty_blockfort_race
    {
        'bourrin\\halo reach\\vehicles\\warthog\\h2 mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Warthog'
    },

    -- liberty_blockfort_race
    {
        'bourrin\\halo reach\\vehicles\\warthog\\rocket warthog',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Rocket hog'
    },

    -- liberty_blockfort_race
    {
        'bourrin\\halo reach\\vehicles\\warthog\\reach gauss hog',
        {
            [0] = 'driver',
            [1] = 'passenger'
        },
        true,
        'Rocket hog'
    },

    -- mystic_mod
    {
        'vehicles\\puma\\puma_lt',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog'
    },

    -- mystic_mod
    {
        'vehicles\\puma\\rpuma_lt',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Warthog'
    },

    -- The-Right-of-Passage_a30
    {
        'vehicles\\bm_warthog\\bm_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'BM Warthog'
    },

    -- The-Right-of-Passage_a30
    {
        'vehicles\\rwarthog\\hellrwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Hell Rocket Warthog'
    },

    -- tsce_multiplayerv1
    {
        'cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_mp\\warthog_mp',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Chain Gun Hog'
    },

    -- tsce_multiplayerv1
    {
        'cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_rocket\\warthog_rocket',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Rocket Hog'
    }
}
