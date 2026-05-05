--[[

==================================
VEHICLE CONFIGURATION
==================================

STRUCTURE:
    {vehicle_tag, seat_roles, enabled/disabled, display_name, insertion_order}

PARAMETERS:
    vehicle_tag (string):       The tag path of the vehicle (e.g., 'vehicles\\warthog\\mp_warthog')
    seat_roles (table):         A table mapping seat indices to their role names
                                    Example: {[0] = 'driver', [1] = 'passenger', [2] = 'gunner'}
    enabled (boolean):          Whether this vehicle is enabled for Uber calls
    display_name (string):      The name shown to players when entering this vehicle
    insertion_order (table):    The order in which seats should be filled for THIS VEHICLE
                                    Example: {0, 2, 1} means try driver first, then gunner, then passenger

IMPORTANT NOTES:

1. VEHICLE WHITELIST:
   - This table defines which vehicles can be called via Uber
   - Vehicles NOT listed here can still be used normally but won't be available for Uber calls
   - Vehicles listed with enabled=false will prevent Uber calls and may eject players (if configured)

2. SEAT ROLES:
   - The script respects the roles defined for each vehicle
   - Even if a seat is listed in insertion_order, only players who can occupy that role will be placed there
   - Example: In a Warthog, seat 2 is the gunner seat - only players who can be gunners will be placed there

3. INSERTION ORDER:
   - Each vehicle can have its own insertion order priority
   - This determines which seats get filled first when multiple seats are available
   - Seats are tried in the order specified until a valid, empty seat is found

4. VEHICLE SELECTION SYSTEM:
   - The script prioritizes vehicles with fewer occupants

BEHAVIOR EXAMPLES:
   - If Banshee is NOT in this table: Players can use it normally but can't call Uber to it
   - If Banshee IS listed but enabled=false: Players will be prevented from using it for Uber
   - If a vehicle has no driver: Passengers may be ejected after a delay (if configured)
]]

return {

    -- Format: {tag_path, seat_roles, enabled, display_name, insertion_order}

    --================--
    -- STOCK VEHICLES:
    --================--

    { 'vehicles\\warthog\\mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner',
    }, true, 'Chain Gun Hog', { 0, 2, 1 } },

    { 'vehicles\\rwarthog\\rwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Rocket Hog', { 0, 2, 1 } },

    --================--
    -- CUSTOM VEHICLES:
    --================--

    -- []h3[]christmas, celebration_island
    { 'vehicles\\halo3warthog\\h3 mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'H3 Warthog', { 0, 2, 1 } },

    -- [h3]_sandtrap
    { 'halo3\\vehicles\\mongoose\\mongoose', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Mongoose', { 0, 1 } },

    -- [h3]_sandtrap
    { 'halo3\\vehicles\\warthog\\mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner',
    }, true, 'H2 Warthog', { 0, 2, 1 } },

    -- [FBI]bloodgulch
    { 'h2\\objects\\vehicles\\warthog\\warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner',
    }, true, 'H2 Warthog', { 0, 2, 1 } },

    -- [h3style]containment
    { 'vehicles\\cwarthog\\mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner',
    }, true, 'CWarthog', { 0, 2, 1 } },

    -- arctic_battleground, artillery_zone, battleforbloodgulch, bloodground_aco, cold_war, doomsday, esther, separated
    { 'vehicles\\mwarthog\\mwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Missile Warthog', { 0, 2, 1 } },

    -- atomic
    { 'vehicles\\dangermobile\\dangermobile', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Dangermobile', { 0, 1 } },

    -- atomic
    { 'vehicles\\doombuggy\\doombuggy', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Doombuggy', { 0, 1 } },

    -- battle
    { 'vehicles\\civihog\\civihog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Civilian Hog', { 0, 2, 1 } },

    -- bc_raceway_final_mp
    { 'levels\\test\\racetrack\\custom_hogs\\mp_warthog', {
        [0] = 'driver',
        [2] = 'passenger'
    }, true, 'Warthog', { 0, 2 } },

    -- bc_raceway_final_mp
    { 'levels\\test\\racetrack\\custom_hogs\\mp_warthog_blue', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Warthog', { 0, 1 } },

    -- bc_raceway_final_mp
    { 'levels\\test\\racetrack\\custom_hogs\\mp_warthog_green', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Warthog', { 0, 1 } },

    -- bc_raceway_final_mp
    { 'levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi1', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Warthog', { 0, 1 } },

    -- bc_raceway_final_mp
    { 'levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi2', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Warthog', { 0, 1 } },

    -- bc_raceway_final_mp
    { 'levels\\test\\racetrack\\custom_hogs\\mp_warthog_multi3', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Warthog', { 0, 1 } },

    -- beryl_rescue, casualty_isle__v2, erosion
    { 'vehicles\\rwarthog\\art_rwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Art Rocket Warthog', { 0, 2, 1 } },

    -- beryl_rescue, delta_ruined, destiny, grove_final
    { 'vehicles\\warthog\\art_cwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Art CWarthog', { 0, 2, 1 } },

    -- Bigass
    { 'bourrin\\halo reach\\vehicles\\warthog\\h2 mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'H2 Warthog', { 0, 2, 1 } },

    -- Bigass
    { 'bourrin\\halo reach\\vehicles\\warthog\\rocket warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Rocket Warthog', { 0, 2, 1 } },

    -- bob_omb_battlefield, coldsnap, combat_arena, extinction, frozen-path, hypothermia_race, hypothermia_v0.1, hypothermia_v0.2, hypo_v0.3
    { 'vehicles\\g_warthog\\g_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'G Warthog', { 0, 2, 1 } },

    -- bumper_cars_v2
    { 'vehicles\\civvi\\civilian warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Civilian Warthog', { 0, 2, 1 } },

    -- bumper_cars_v2
    { 'vehicles\\warthog\\mp_warthogc', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog C', { 0, 2, 1 } },

    -- camden_place
    { 'vehicles\\fwarthog\\mp_fwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Flame Warthog', { 0, 2, 1 } },

    -- celebration_island, hornets_nest
    { 'halo3\\vehicles\\warthog\\rwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'H3 Rocket Hog', { 0, 2, 1 } },

    -- cityscape-adrenaline
    { 'vehicles\\g_warthog\\g_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog', { 0, 2, 1 } },

    -- cityscape-adrenaline
    { 'vehicles\\rwarthog\\boogerhawg', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog', { 0, 2, 1 } },

    -- cmt_cliffrun
    { 'vehicles\\cmt_warthog\\chaingun_variant', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'CMT Chaingun Hog', { 0, 2, 1 } },

    -- cmt_cliffrun
    { 'vehicles\\cmt_warthog\\rocket_variant', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'CMT Rocket Hog', { 0, 2, 1 } },

    -- cnr_island, desertdunestwo
    { 'vehicles\\rancher\\rancher', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Rancher', { 0, 1 } },

    -- cnr_island
    { 'vehicles\\sultan\\sultan', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Sultan', { 0, 1 } },

    -- cold_war
    { 'vehicles\\warthog\\h2 mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'H2 Warthog', { 0, 2, 1 } },

    -- coldsnap
    { 'vehicles\\coldsnap_hogs\\mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog', { 0, 2, 1 } },

    -- combat_arena
    { 'vehicles\\gausshog\\gausshog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Gauss Hog', { 0, 2, 1 } },

    -- concealed_custom
    { 'vehicles\\warthog_legend\\warthog_legend', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Legend Warthog', { 0, 2, 1 } },

    -- concealed_custom
    { 'vehicles\\rwarthog_legend\\rwarthog_legend', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Legend Rocket Warthog', { 0, 2, 1 } },

    -- cursed-beavercreek, cursed-bloodgulch, cursed-chillout, cursed-damnation, cursed-deathisland, cursed-derelict, cursed-hangemhigh, cursed-sidewinder, cursed-wizard
    { 'vehicles\\c warthog\\c warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'C Warthog', { 0, 2, 1 } },

    -- deathrace, Human_Landscape, Jeep_Cliffs
    { 'vehicles\\civihog\\mp_civihog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Civilian Hog', { 0, 2, 1 } },

    -- desert_storm_v2
    { 'vehicles\\trans_hog\\trans_hog', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Transport Hog', { 0, 1 } },

    -- desertdunestwo
    { 'vehicles\\walton\\walton', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Walton', { 0, 1 } },

    -- discovery
    { 'vehicles\\warthog\\realistic\\mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Realistic Warthog', { 0, 2, 1 } },

    -- facing_worldsrx, gladiators_brawl, huh-what_3
    { 'vehicles\\puma\\puma', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Puma', { 0, 1 } },

    -- first
    { 'vehicles\\snow_civ_hog\\snow_civ_hog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Snow Civilian Hog', { 0, 2, 1 } },

    -- fox_island_insane
    { 'vehicles\\ravhog\\ravhog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Rav Hog', { 0, 2, 1 } },

    -- gauntlet_race
    { 'vehicles\\rwarthog2\\rwarthog2', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog', { 0, 2, 1 } },

    -- gladiators_brawl
    { 'vehicles\\warthog\\flamehog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Flamehog', { 0, 2, 1 } },

    -- glenns_castle, hypo_v0.3, hypothermia_race, hypothermia_v0.1, hypothermia_v0.2
    { 'vehicles\\civvi\\civvi', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Civvi', { 0, 1 } },

    -- glupo_aco
    { 'vehicles\\sandking\\sandking', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Sandking', { 0, 1 } },

    -- green_canyon
    { 'vehicles\\rwarthog\\rwarthogfix', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Fixed Rocket Warthog', { 0, 2, 1 } },

    -- green_canyon
    { 'vehicles\\warthog\\mp_warthogfix', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Fixed Warthog', { 0, 2, 1 } },

    -- Halloween_Gulch_V2
    { 'vehicles\\rwarthog\\hellrwarthogv2', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Hell Rocket Warthog V2', { 0, 2, 1 } },

    -- Halloween_Gulch_V2
    { 'vehicles\\warthog\\hellhogv2', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Hellhog V2', { 0, 2, 1 } },

    -- hillbilly mudbog
    { 'vehicles\\rpchog\\rpchog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'RPC Hog', { 0, 2, 1 } },

    -- hogracing_day, hogracing_night
    { 'vehicles\\puma\\puma_xt', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Puma XT', { 0, 1 } },

    -- hornets_nest
    { 'halo3\\vehicles\\warthog\\mp_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'H3 Warthog', { 0, 2, 1 } },

    -- hq_racetrack
    { 'vehicles\\sporthog\\smileyhog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Smiley Hog', { 0, 2, 1 } },

    -- hydrolysis
    { 'vehicles\\newboathog\\newboathog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'New Boat Hog', { 0, 2, 1 } },

    -- Mongoose_Point
    { 'vehicles\\m257_multvp\\m257_multvp', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Mongoose', { 0, 1 } },

    -- Mongoose_Point
    { 'vehicles\\m257_multvp\\m257_multvp2', {
        [0] = 'driver',
        [1] = 'passenger'
    }, true, 'Mongoose', { 0, 1 } },

    -- mystic_mod
    { 'vehicles\\puma\\puma_lt', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog', { 0, 2, 1 } },

    -- mystic_mod
    { 'vehicles\\puma\\rpuma_lt', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Warthog', { 0, 2, 1 } },

    -- The-Right-of-Passage_a30
    { 'vehicles\\bm_warthog\\bm_warthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'BM Warthog', { 0, 2, 1 } },

    -- The-Right-of-Passage_a30
    { 'vehicles\\rwarthog\\hellrwarthog', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Hell Rocket Warthog', { 0, 2, 1 } },

    -- tsce_multiplayerv1
    { 'cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_mp\\warthog_mp', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Chain Gun Hog', { 0, 2, 1 } },

    -- tsce_multiplayerv1
    { 'cmt\\vehicles\\evolved_h1-spirit\\warthog\\_warthog_rocket\\warthog_rocket', {
        [0] = 'driver',
        [1] = 'passenger',
        [2] = 'gunner'
    }, true, 'Rocket Hog', { 0, 2, 1 } },
}