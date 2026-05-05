--[[
=====================================================================================
SCRIPT NAME:      tactical_airstrike.lua
DESCRIPTION:      Players on a kill streak can call in an airstrike with 3 modes:
                  - Target specific player
                  - Strike enemy base locations
                  - Random map coordinates

COMMANDS:
                  /nuke [player id]    - Call airstrike on player (Mode 1)
                  /nuke                - Call airstrike (Modes 2 & 3)
                  /nuke mode [mode id] - Switch between strike modes (1-3)
                  /nuke info           - Show mode information
                  /nuke pl             - Show online player IDs

TODO: rewrite this garbage

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration [starts] ===================================================
local airstrike = {

    -- This is the main command a player will type to activate an airstrike.
    base_command = "nuke",

    -- This command displays information about the 3 strike modes
    -- and lists each mode's ID (used for mode selection)
    info_command = "info",

    -- Use this command to select your Strike Mode (see description at top of script)
    mode_command = "mode",

    -- Players can view the ID's of all players currently online with this command.
    player_list_command = "pl",

    -- One function temporarily removes the server prefix white it relays specific messages then restores it.
    -- The prefix will be restored to this:
    server_prefix = "** SAPP ** ",

    -- All output messages:
    messages = {

        mode_select = "STRIKE MODE %mode% SELECTED",
        mode_not_enabled = "Mode #%mode% is not enabled for this map.",
        not_enough_kills = "You do not have enough kills to call an airstrike",
        game_over = "Please wait until the next game begins!",
        cannot_strike_self = "You cannot call an airstrike on yourself!",
        player_offline_or_dead = "Player is offline or dead!",
        invalid_player_id = "Invalid Player ID!",
        console_error = "You cannot execute this command from the console!",
        mode_invalid_syntax = "Invalid Syntax or Invalid Mode. Usage: /%cmd% %mode_cmd% [mode id]",
        team_play_incompatible = "This mode is incompatible with team play!",
        strike_failed = "Unable to initiate Airstrike. Please contact an Administrator.",

        -- When enabled, the server will periodically broadcast information about this mod.
        -- Messages are displayed in RCON or CHAT.
        periodic_broadcast = {
            enabled = true,
            interval = 120, -- timer (in seconds) between each announcement
            environment = "chat", -- Valid environment = "rcon" or "chat"
            lines = {
                "This server has an Airstrike Feature.",
                " ",
                "Get a five-kill streak (5 consecutive kills) without dying and gain",
                "the ability to call in an airstrike using 1 of 3 special Strike Modes.",
                "Type /%cmd% %info_cmd% for information about these Strike Modes."
            }
        },

        player_list_cmd_feedback = {
            header = "[ID - NAME]",
            player_info = "%id%  -  %name%",
            offline = "No other players online",
        },

        on_airstrike_call = {
            broadcast = {
                ["Mode A"] = { "%killer% called an airstrike on %victim%" },
                ["Mode B"] = { "%killer% called an airstrike on %opposing_team% team's base!" },
                ["Mode C"] = { "%killer% called an airstrike!" },
            },
            killer_feedback = {
                "==========================",
                "  -- AIRSTRIKE CALLED --",
                "        B O O M !!",
                "=========================="
            }
        },
        incorrect_mode = {
            "You are not in the correct mode!",
            "Use: /%cmd% %mode_cmd% [mode id]"
        },
        info = {
            "-- ============== MODE INFORMATION ============== --",
            "Mode 1). Call an airstrike at a specific player's X, Y, Z map coordinates.",
            "Type /%cmd% [player id] to call an airstrike on a player!",
            "Type /%cmd% %pl_cmd% to view a list of Player IDs",
            " ",
            " ",
            "Mode 2). Call an airstrike to (1 of X) locations surrounding the enemy base.",
            "Type /%cmd% to call an airstrike on the enemy base!",
            " ",
            " ",
            "Mode 3). Call an airstrike to a random (pre-defined) x,y,z coordinate on the map.",
            "Type /%cmd% to call an airstrike at a random location on the map!",
            " ",
            " ",
            " ",
            "COMMAND SYNTAX TO SELECT A MODE: /%cmd% %mode_cmd% [mode id]",
            "--=============================================================================--"
        },
        on_kill = {
            ["Mode A"] = {
                "-- ============ AIRSTRIKE AVAILABLE ============ --",
                "Type /%cmd% [player id] to call an airstrike on a player!",
                "Type /%cmd% %pl_cmd% to view a list of Player IDs"
            },

            ["Mode B"] = {
                "-- ============ AIRSTRIKE AVAILABLE ============ --",
                "Type /%cmd% to call an airstrike on the enemy base!"
            },

            ["Mode C"] = {
                "-- ============ AIRSTRIKE AVAILABLE ============ --",
                "Type /%cmd% to call an airstrike at a random location on the map!"
            },
        },
    },

    maps = {

        ["beavercreek"] = {
            enabled = true, -- enable airstrike feature for this map (set to false to disable).
            default_mode = "Mode A", -- Default "mode" a player is put into when they join the server.

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true, -- enable|disable this mode.
                    kills_required = 5, -- Number of kills required to enable airstrike mode
                    height_from_ground = 20 -- height from ground the projectiles will spawn
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        -- X,Y,Z, Height From Ground
                        ["red"] = {
                            { 28.937, 13.523, 0.836, 20 },
                            { 25.841, 19.198, -0.217, 20 },
                            { 32.852, 13.935, -0.217, 20 },
                            { 26.323, 6.408, -0.217, 20 },
                            { 19.510, 13.729, -0.217, 20 },
                        },
                        ["blue"] = {
                            { 7.934, 13.743, -0.217, 20 },
                            { -0.964, 13.743, 0.836, 20 },
                            { 2.418, 8.010, -0.217, 20 },
                            { -4.459, 13.678, -0.217, 20 },
                            { 0.848, 20.180, -0.217, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 11.362, 18.538, -0.217, 20 },
                        { 17.996, 8.274, -0.217, 20 },
                        { 18.001, 5.870, 3.548, 20 },
                        { 16.268, 17.293, 5.135, 20 },
                        { 24.902, 14.849, 2.061, 20 },
                        { 28.474, 15.185, 2.495, 20 },
                        { 28.804, 11.453, 2.494, 20 },
                        { 3.639, 11.435, 1.800, 20 },
                        { -0.687, 16.919, 2.259, 20 },
                        { 14.016, 8.132, -0.843, 20 },
                    }
                }
            }
        },

        ["bloodgulch"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 100,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 95.738, -159.466, -0.287, 20 },
                            { 102.924, -159.576, 0.187, 20 },
                            { 95.482, -166.738, 0.116, 20 },
                            { 88.513, -159.604, 0.116, 20 },
                            { 95.500, -152.701, 0.100, 20 },
                            { 95.436, -162.429, 1.783, 20 },
                            { 95.577, -156.274, 1.703, 20 },
                            { 84.881, -155.846, -0.075, 20 },
                            { 89.931, -172.344, 0.209, 20 },
                            { 100.009, -170.296, 0.227, 20 },
                            { 119.462, -182.986, 6.781, 20 },
                            { 112.651, -142.841, 0.239, 20 },
                            { 113.154, -128.205, 1.390, 20 },
                            { 63.167, -169.477, 3.651, 20 },
                            { 63.591, -176.145, 3.999, 20 },
                        },
                        ["blue"] = {
                            { 40.238, -79.124, -0.287, 20 },
                            { 40.314, -72.410, 0.186, 20 },
                            { 47.047, -79.165, 0.125, 20 },
                            { 40.016, -85.736, 0.131, 20 },
                            { 33.317, -79.109, 0.071, 20 },
                            { 40.276, -76.249, 1.783, 20 },
                            { 40.114, -81.944, 1.703, 20 },
                            { 28.655, -70.226, 0.460, 20 },
                            { 28.014, -112.472, 6.247, 20 },
                            { 44.626, -93.932, 0.810, 20 },
                            { 68.350, -73.734, 1.531, 20 },
                            { 77.544, -65.869, 4.725, 20 },
                            { 49.942, -81.076, 0.108, 20 },
                            { 59.401, -92.119, 0.174, 20 },
                            { 35.852, -65.083, 0.496, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 95.696, -158.750, 1.703, 20 },
                        { 98.109, -151.062, 0.044, 20 },
                        { 82.585, -151.451, 0.121, 20 },
                        { 62.700, -168.103, 3.969, 20 },
                        { 60.492, -149.435, 6.265, 20 },
                        { 41.995, -126.763, 0.163, 20 },
                        { 63.247, -124.611, 0.813, 20 },
                        { 71.909, -125.715, 1.074, 20 },
                        { 64.594, -136.829, 1.977, 20 },
                        { 81.375, -117.107, 0.407, 20 },
                        { 82.755, -100.448, 1.984, 20 },
                        { 65.480, -104.017, 1.792, 20 },
                        { 53.695, -100.258, -0.077, 20 },
                        { 58.931, -96.066, 0.293, 20 },
                        { 44.190, -94.972, 0.879, 20 },
                        { 24.251, -105.223, 3.002, 20 },
                        { 40.899, -85.687, 0.132, 20 },
                        { 29.091, -73.504, 1.097, 20 },
                        { 58.638, -66.808, 1.266, 20 },
                        { 40.045, -80.791, 1.703, 20 },
                        { 97.752, -132.690, 0.549, 20 },
                        { 75.352, -136.137, 0.518, 20 },
                        { 57.396, -140.704, 1.015, 20 },
                        { 71.486, -138.073, 0.977, 20 },
                        { 95.902, -96.726, 4.048, 20 },
                        { 90.307, -91.818, 5.083, 20 },
                        { 68.473, -95.509, 1.551, 20 },
                    }
                }
            }
        },

        ["boardingaction"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 3.463, -1.260, 0.220, 3 },
                            { -0.360, -1.590, 0.220, 3 },
                            { -0.340, 2.618, 0.220, 3 },
                            { 2.861, 3.821, 0.220, 3 },
                            { 3.180, -6.274, 0.220, 3 },
                            { -0.568, 5.113, 0.220, 3 },
                            { -0.631, 9.367, 0.220, 3 },
                            { -0.556, 12.966, 0.220, 3 },
                            { 0.266, 16.793, 0.220, 3 },
                            { 0.581, 21.682, 0.220, 3 },
                        },
                        ["blue"] = {
                            { 16.669, 1.473, 0.220, 3 },
                            { 16.901, -3.694, 0.220, 3 },
                            { 20.371, -2.470, 0.220, 3 },
                            { 20.534, -4.379, 0.220, 3 },
                            { 20.193, 1.394, 0.220, 3 },
                            { 16.951, 6.297, 0.220, 3 },
                            { 20.675, -9.011, 0.220, 3 },
                            { 20.538, -13.429, 0.220, 3 },
                            { 19.988, -16.314, 0.220, 3 },
                            { 19.689, -21.496, 0.220, 3 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 3.077, -19.802, 5.218, 3 },
                        { 0.984, -10.769, 5.218, 3 },
                        { 2.452, -12.817, 7.220, 3 },
                        { -0.437, -8.173, 5.218, 3 },
                        { 0.605, -2.045, 5.218, 3 },
                        { 0.605, 7.874, 5.218, 3 },
                        { 0.169, 17.625, 5.218, 3 },
                        { 1.161, 20.476, 5.218, 3 },
                        { 3.722, -17.002, 2.720, 3 },
                        { 0.773, -11.982, 2.720, 3 },
                        { -3.373, -6.386, 2.720, 3 },
                        { -2.464, -4.736, 2.720, 3 },
                        { -0.587, 0.425, 2.720, 3 },
                        { 2.933, 6.219, 2.520, 3 },
                        { 3.175, 11.235, 2.520, 3 },
                        { -0.221, 6.376, 2.720, 3 },
                        { 0.936, 9.583, 2.720, 3 },
                        { 0.424, 16.640, 2.720, 3 },
                        { 0.534, 20.834, 2.720, 3 },
                        { 1.252, -9.785, 0.220, 3 },
                        { 2.682, -4.743, 0.220, 3 },
                        { 3.027, -1.318, 0.220, 3 },
                        { 0.093, -1.566, 0.220, 3 },
                        { 0.064, 0.499, 0.220, 3 },
                        { -0.068, 2.741, 0.220, 3 },
                        { 2.939, 3.666, 0.220, 3 },
                        { -0.364, 6.721, 0.220, 3 },
                        { -1.933, 9.015, 0.220, 3 },
                        { -0.500, 11.837, 0.220, 3 },
                        { 0.169, 16.688, 0.220, 3 },
                        { 1.122, 14.675, 0.220, 3 },
                        { 0.549, 21.332, 0.220, 3 },
                        { 3.414, -20.539, -2.281, 3 },
                        { 0.785, -14.204, -2.281, 3 },
                        { 1.256, -7.433, -2.281, 3 },
                        { 3.787, -4.985, -2.281, 3 },
                        { 3.827, -0.389, -2.281, 3 },
                        { 3.714, 4.433, -2.281, 3 },
                        { 1.418, 14.699, -2.281, 3 },
                        { 1.207, 20.461, -2.281, 3 },
                        { 3.910, 21.232, -4.779, 3 },
                        { 3.581, 14.737, -4.779, 3 },
                        { 3.249, 9.184, -4.779, 3 },
                        { 3.303, 3.921, -2.281, 3 },
                        { 4.072, -1.063, -2.281, 3 },
                        { 3.241, -4.216, -4.779, 3 },
                        { 3.252, -8.563, -4.779, 3 },
                        { 3.748, -19.211, -4.779, 3 },
                        { 16.179, 19.253, 5.218, 3 },
                        { 19.072, 10.567, 5.218, 3 },
                        { 19.560, 1.670, 5.218, 3 },
                        { 22.249, -2.532, 5.218, 3 },
                        { 16.859, -7.295, 2.520, 3 },
                        { 16.634, -11.985, 2.520, 3 },
                        { 19.253, -19.703, 2.720, 3 },
                        { 18.956, -9.204, 2.720, 3 },
                        { 16.936, 12.785, 7.220, 3 },
                        { 15.872, 16.997, 2.720, 3 },
                        { 19.661, 9.673, 2.720, 3 },
                        { 23.144, 6.892, 2.720, 3 },
                        { 23.462, 4.388, 2.720, 3 },
                        { 21.052, 0.656, 2.720, 3 },
                        { 16.962, -7.248, 2.520, 3 },
                        { 16.918, -12.293, 2.520, 3 },
                        { 19.779, -20.488, 2.720, 3 },
                        { 18.998, -9.041, 2.720, 3 },
                        { 19.202, -21.364, 0.220, 3 },
                        { 20.199, -16.405, 0.220, 3 },
                        { 21.461, -8.917, 0.220, 3 },
                        { 20.569, -5.726, 0.220, 3 },
                        { 20.059, -2.793, 0.220, 3 },
                        { 16.681, -3.013, 0.220, 3 },
                        { 19.081, 1.040, 0.220, 3 },
                        { 16.570, 1.429, 0.220, 3 },
                        { 16.976, 6.121, 0.220, 3 },
                        { 20.305, 5.341, 0.220, 3 },
                        { 18.754, 19.191, 0.220, 3 },
                        { 16.572, 20.458, -2.281, 3 },
                        { 20.045, 16.693, -2.281, 3 },
                        { 15.920, 14.677, -2.281, 3 },
                        { 19.088, 7.286, -2.281, 3 },
                        { 17.089, 3.745, -2.281, 3 },
                        { 16.828, -4.406, -2.281, 3 },
                        { 19.634, -20.184, -2.281, 3 },
                        { 16.289, -21.026, -4.779, 3 },
                        { 16.893, -9.813, -4.779, 3 },
                        { 16.850, 4.735, -4.779, 3 },
                        { 16.760, 13.942, -4.779, 3 },
                        { 15.860, 20.192, -4.779, 3 },
                    }
                }
            }
        },

        ["carousel"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 4.733, -11.292, -3.358, 3 },
                            { 6.963, -12.817, -3.358, 3, 3 },
                            { 4.003, -13.948, -3.358 },
                            { -1.020, -13.754, -3.358, 3 },
                            { 9.320, -8.742, -3.358, 3 },
                            { 4.733, -11.292, -3.358, 6 },
                            { 6.963, -12.817, -3.358, 6 },
                            { 4.003, -13.948, -3.358, 6 },
                            { -1.020, -13.754, -3.358, 6 },
                            { 9.320, -8.742, -3.358, 6 },
                            { 2.049, -9.197, -3.358, 6 },
                            { -2.165, -9.160, -3.358, 6 },
                            { -6.677, -6.768, -3.358, 6 },
                            { 5.080, -10.380, -0.856, 6 },
                            { -0.218, -10.429, -0.856, 6 },
                            { -8.408, -9.678, -0.856, 6 },
                        },
                        ["blue"] = {
                            { -4.763, 11.222, -3.358, 3 },
                            { -4.292, 13.943, -3.358, 3 },
                            { -6.959, 12.801, -3.358, 3 },
                            { -9.911, 9.887, -3.358, 3 },
                            { 0.076, 13.896, -3.358, 3 },
                            { -0.047, 10.069, -0.856, 3, },
                            { 7.602, 7.578, -3.358, 3 },
                            { -5.416, 10.236, -0.856, 3 },
                            { -10.813, 5.053, -0.856, 3 },
                            { -3.848, 9.312, -3.358, 6 },
                            { -1.967, 6.683, -2.732, 6 },
                            { -6.964, 5.311, -3.264, 6 },
                            { 2.044, 7.588, -2.973, 6 },
                            { 6.751, 6.361, -3.358, 6 },
                            { 3.480, 3.070, -2.556, 6 },
                            { -3.920, 3.923, -2.556, 6 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 3.072, -3.370, -2.556, 6 },
                        { 9.606, -1.664, -3.358, 6 },
                        { 1.727, -9.578, -3.358, 6 },
                        { 6.583, -6.751, -3.358, 6 },
                        { 4.615, -4.807, -2.725, 6 },
                        { 3.556, -5.053, -2.571, 6 },
                        { 4.906, -3.155, -2.556, 6 },
                        { -11.023, -3.664, -0.856, 3 },
                        { -14.010, 0.215, -0.856, 3 },
                        { -9.603, 5.250, -0.856, 3 },
                        { -7.550, 7.970, -0.856, 3 },
                        { -5.123, 9.955, -0.856, 3 },
                        { 0.081, 10.486, -0.856, 3 },
                        { 9.910, 9.885, -0.856, 3 },
                        { 14.064, -0.016, -0.856, 3 },
                        { 10.659, 0.086, -0.856, 3 },
                        { 0.143, -0.045, -0.856, 3 },
                        { -5.582, 0.008, -0.856, 3 },
                        { 6.485, 0.017, -0.856, 3 },
                        { 0.011, 6.380, -0.856, 3 },
                        { 0.043, -5.961, -0.856, 3 },
                        { 4.398, 0.039, -2.556, 1 },
                        { -0.088, 4.866, -2.556, 1 },
                        { -4.783, 0.062, -2.556, 1 },
                        { 0.007, -4.530, -2.556, 1 },
                        { 4.620, -0.109, -2.556, 1 },
                        { 0.152, 4.555, -2.556, 1 },
                    }
                }
            }
        },

        ["chillout"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 6.071, -4.513, 2.381, 3 },
                            { 10.198, -4.316, 2.381, 3 },
                            { 8.809, 0.977, 2.381, 3 },
                            { 7.060, 0.902, 2.381, 3 },
                            { 3.881, -0.433, 2.381, 3 },
                            { 8.749, -0.367, 3.535, 1 },
                            { 10.605, 2.609, 3.535, 1 },
                        },
                        ["blue"] = {
                            { -6.582, 2.230, 1.215, 6 },
                            { -4.689, 8.050, 0.501, 6 },
                            { -5.792, 4.590, -0.000, 6 },
                            { -8.823, 4.956, -0.000, 6 },
                            { -8.704, 8.811, -0.000, 6 },
                            { -6.212, 9.880, -0.000, 6 },
                            { -6.204, 0.660, -0.000, 6 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 7.617, -4.106, 2.381, 1 },
                        { 7.294, -0.070, 2.381, 1 },
                        { 3.700, -0.461, 2.381, 1 },
                        { -0.605, -0.461, 2.784, 1 },
                        { 1.524, -2.938, -0.000, 1 },
                        { 4.099, -0.528, -0.000, 1 },
                        { -1.629, -0.555, -0.000, 1 },
                        { 0.064, 4.074, 0.746, 1 },
                        { 2.929, 3.727, 0.746, 1 },
                        { 1.493, 0.282, -0.000, 1 },
                        { -0.036, 6.650, 0.746, 1 },
                        { 1.320, 10.128, 0.746, 1 },
                        { 5.714, 9.889, 1.263, 1 },
                        { 4.710, 7.300, 3.535, 1 },
                        { -0.323, 9.012, 3.668, 1 },
                        { -0.275, 11.112, 4.168, 1 },
                        { 11.023, 2.865, 3.535, 1 },
                        { 9.682, 9.924, -0.000, 1 },
                        { 10.376, 5.052, -0.000, 1 },
                        { 9.763, 2.717, -0.000, 1 },
                        { 5.429, -0.452, -0.000, 1 },
                        { -6.249, 0.791, -0.000, 1 },
                        { -6.255, 2.253, 1.215, 1 },
                        { -6.289, 4.804, -0.000, 1 },
                        { -5.556, 10.122, -0.000, 1 },
                    }
                }
            }
        },

        ["damnation"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 10.560, -13.452, 6.700, 10 },
                            { 10.776, -7.786, 4.500, 10 },
                            { 6.486, -8.108, 4.500, 10 },
                            { 6.473, -11.058, 4.500, 10 },
                            { 8.510, -10.977, 4.500, 10 },
                            { 7.452, -14.240, 6.700, 10 },
                            { 4.185, -13.470, 6.700, 10 },
                            { 3.807, -10.499, 6.700, 10 },
                            { 2.915, -8.577, 6.700, 10 },
                            { 7.320, -5.827, 6.700, 10 },
                            { -1.578, -9.129, 3.400, 10 },
                            { -3.038, -6.205, 3.400, 10 },
                            { -1.143, -5.833, 3.400, 10 },
                        },
                        ["blue"] = {
                            { 3.100, 14.720, 3.400, 10 },
                            { -2.460, 14.824, 1.200, 10 },
                            { -9.681, 14.815, -0.400, 10 },
                            { -9.784, 9.922, -0.400, 10 },
                            { -11.722, 10.141, -0.400, 10 },
                            { -10.498, 12.950, -0.400, 10 },
                            { -5.322, 14.765, 0.607, 10 },
                            { 0.999, 12.941, 1.200, 10 },
                            { -1.865, 10.090, 1.200, 10 },
                            { 0.755, 9.422, 1.200, 10 },
                            { 2.709, 8.615, 3.400, 10 },
                            { -2.365, 7.354, 3.400, 10 },
                            { -6.715, 7.406, 3.400, 10 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 3.744, 14.602, 3.400, 10 },
                        { 2.684, 9.426, 3.400, 10 },
                        { -0.319, 10.883, 1.200, 10 },
                        { -2.217, 14.364, 1.200, 10 },
                        { -10.139, 14.102, -0.400, 10 },
                        { -10.825, 10.921, -0.400, 10 },
                        { -9.778, 7.348, -0.200, 10 },
                        { -9.811, 4.185, -0.200, 10 },
                        { -9.867, -1.802, -0.200, 10 },
                        { -2.208, 1.551, -0.200, 10 },
                        { -10.842, -6.051, -0.200, 10 },
                        { -11.582, -11.300, 0.242, 10 },
                        { -5.903, -12.359, 2.300, 10 },
                        { -5.890, -7.645, 3.400, 10 },
                        { -2.147, -6.245, 3.400, 10 },
                        { 1.670, -6.073, 3.400, 10 },
                        { 3.406, -2.426, 3.400, 10 },
                        { 6.768, -0.088, 3.758, 10 },
                        { 8.530, 2.993, 3.400, 10 },
                        { 3.623, 8.220, 3.400, 10 },
                        { -3.798, 7.381, 3.400, 10 },
                        { 1.522, 1.976, -0.100, 10 },
                        { 1.495, -3.178, -0.013, 10 },
                        { -1.569, -6.157, 3.400, 10 },
                        { 6.626, -8.247, 4.500, 10 },
                        { 10.679, -10.122, 5.555, 10 },
                        { 10.583, -13.218, 6.700, 10 },
                        { 4.856, -13.335, 6.700, 10 },
                        { 2.592, -8.636, 6.700, 10 },
                        { 7.029, -5.139, 6.700, 10 },
                        { 6.331, -1.887, 6.700, 10 },
                        { 2.693, 4.467, 6.705, 10 },
                        { 3.711, -1.417, 6.700, 10 },
                        { -0.483, 1.332, 8.200, 10 },
                        { -0.621, 6.556, 8.200, 10 },
                    }
                }
            }
        },

        ["dangercanyon"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -6.320, -3.402, -4.029, 15 },
                            { -17.896, -3.420, -4.029, 15 },
                            { -12.094, -9.954, -4.067, 15 },
                            { -12.099, -7.449, -3.144, 15 },
                            { -12.117, -4.633, -2.337, 15 },
                            { -13.225, -3.443, -2.337, 15 },
                            { -12.053, -1.200, -2.338, 15 },
                            { -10.564, -3.482, -2.335, 15 },
                            { -15.896, -3.503, -3.085, 15 },
                            { -7.496, -0.067, -4.031, 15 },
                            { -7.123, -8.898, -4.028, 15 },
                            { -17.086, -8.701, -4.027, 15 },
                            { -24.736, -0.164, -3.742, 15 },
                            { -26.407, -7.343, -3.428, 15 },
                            { -17.826, 0.782, -4.034, 15 },
                        },
                        ["blue"] = {
                            { 6.389, -8.807, -4.028, 15 },
                            { 6.144, -3.606, -4.028, 15 },
                            { 6.290, -0.684, -4.029, 15 },
                            { 8.474, 1.220, -4.032, 15 },
                            { 8.031, -3.426, -3.190, 15 },
                            { 10.835, -3.400, -2.337, 15 },
                            { 12.098, -4.869, -2.335, 15 },
                            { 12.051, -7.571, -3.207, 15 },
                            { 12.096, -10.350, -4.082, 15 },
                            { 12.010, 0.715, -2.338, 15 },
                            { 13.767, -3.348, -2.334, 15 },
                            { 16.097, -3.361, -3.260, 15 },
                            { 19.386, -3.381, -4.025, 15 },
                            { 17.627, 0.948, -4.035, 15 },
                            { 17.714, -8.763, -4.031, 15 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -8.184, -3.581, -3.161, 15 },
                        { -12.107, -0.684, -2.338, 15 },
                        { -18.848, -3.392, -4.026, 15 },
                        { -16.918, -9.057, -4.039, 15 },
                        { -44.228, -1.833, -2.177, 15 },
                        { -20.218, 33.214, -6.042, 15 },
                        { -28.164, 26.552, 0.177, 15 },
                        { -2.865, 45.508, -8.366, 15 },
                        { 3.054, 45.527, -8.364, 15 },
                        { -0.028, 46.970, -6.626, 15 },
                        { -0.090, 40.265, -7.411, 15 },
                        { -0.551, 56.085, 0.241, 15 },
                        { -10.914, 53.448, 0.345, 15 },
                        { 7.810, 54.639, 0.206, 15 },
                        { 7.434, 34.037, 0.249, 15 },
                        { 4.510, 34.374, 0.260, 15 },
                        { 2.866, 34.519, 0.264, 15 },
                        { -0.101, 33.755, 0.264, 15 },
                        { -2.521, 34.124, 0.249, 15 },
                        { -5.040, 34.033, 0.244, 15 },
                        { -7.667, 33.326, 0.256, 15 },
                        { 39.048, -6.653, -1.139, 15 },
                        { 18.950, -3.423, -4.026, 15 },
                        { 8.038, -7.321, -4.028, 15 },
                        { 7.955, -3.471, -3.234, 15 },
                        { 12.010, -0.622, -2.338, 15 },
                        { 11.977, 4.706, -2.353, 3 },
                        { 4.255, 9.994, 0.649, 3 },
                        { 4.122, 15.666, 1.314, 3 },
                        { 6.115, 20.285, 1.314, 3 },
                        { 11.493, 20.369, 0.300, 3 },
                        { 15.942, 20.441, 0.300, 3 },
                        { 16.081, 25.091, 0.300, 3 },
                        { 23.015, 20.458, 0.313, 3 },
                        { -4.354, 15.482, 1.314, 3 },
                        { -6.347, 20.395, 1.314, 3 },
                        { -0.288, 15.896, -0.650, 3 },
                        { -2.281, 20.290, -1.131, 3 },
                        { 2.504, 21.104, -1.131, 3 },
                        { -4.302, 9.998, 0.649, 3 },
                        { -12.127, 4.757, -2.353, 3 },
                        { -12.653, 20.360, 0.300, 3 },
                        { -20.686, 20.290, 0.300, 3 },
                        { -16.309, 24.804, 0.300, 3 },
                    }
                }
            }
        },

        ["deathisland"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -18.588, -6.956, 9.677, 2 },
                            { -18.516, -5.198, 9.677, 2 },
                            { -18.520, -8.722, 9.677, 2 },
                            { -21.022, -6.986, 9.677, 2 },
                            { -21.105, -5.280, 9.677, 2 },
                            { -21.037, -8.730, 9.677, 2 },
                            { -23.760, -6.988, 9.672, 2 },
                            { -23.591, -8.861, 9.677, 2 },
                            { -23.637, -5.271, 9.677, 2 },
                            { -26.529, -6.997, 9.662, 2 },
                            { -28.894, -6.982, 9.564, 2 },
                            { -26.530, -4.744, 9.662, 2 },
                            { -26.599, -8.925, 9.662, 2 },
                            { -30.649, -12.498, 9.416, 15 },
                            { -34.059, -10.664, 9.416, 15 },
                            { -31.682, -6.981, 9.416, 15 },
                            { -33.969, -3.570, 9.416, 15 },
                            { -28.631, -0.952, 9.408, 15 },
                            { -38.020, -6.686, 5.316, 20 },
                            { -42.612, -7.212, 4.666, 20 },
                            { -42.266, -12.649, 4.465, 20 },
                            { -42.988, -2.140, 4.902, 20 },
                            { -47.924, -4.688, 4.202, 20 },
                            { -48.121, -11.837, 3.912, 20 },
                            { -44.263, -23.117, 4.829, 20 },
                            { -35.040, -19.712, 9.505, 20 },
                            { -41.584, -28.861, 7.335, 20 },
                        },
                        ["blue"] = {
                            { 21.863, 16.006, 8.294, 3 },
                            { 21.843, 14.091, 8.294, 3 },
                            { 21.780, 17.963, 8.294, 3 },
                            { 24.160, 16.074, 8.294, 3 },
                            { 24.379, 17.598, 8.294, 3 },
                            { 24.365, 14.361, 8.294, 3 },
                            { 26.875, 16.103, 8.294, 3 },
                            { 26.902, 17.979, 8.294, 3 },
                            { 26.959, 14.345, 8.294, 3 },
                            { 29.575, 16.016, 8.294, 3 },
                            { 32.196, 16.053, 8.198, 3 },
                            { 29.842, 18.078, 8.294, 3 },
                            { 29.913, 13.903, 8.294, 3 },
                            { 31.683, 10.345, 8.049, 15 },
                            { 37.329, 13.190, 8.049, 15 },
                            { 34.696, 15.915, 8.049, 15 },
                            { 32.511, 22.701, 8.049, 15 },
                            { 37.548, 18.870, 8.049, 15 },
                            { 33.330, 32.451, 7.532, 15 },
                            { 43.087, 26.775, 3.545, 20 },
                            { 46.908, 14.475, 3.827, 20 },
                            { 42.825, 16.145, 4.696, 20 },
                            { 46.628, 19.931, 3.609, 20 },
                            { 47.261, 13.683, 3.728, 20 },
                            { 42.411, 8.833, 4.555, 20 },
                            { 38.196, 5.345, 7.238, 20 },
                            { 41.742, 18.667, 8.049, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 31.031, 20.747, 8.049, 20 },
                        { 30.925, 10.818, 8.049, 20 },
                        { 45.111, 16.200, 4.341, 20 },
                        { 32.932, 32.899, 7.584, 20 },
                        { 11.061, 30.764, 9.786, 20 },
                        { 0.049, 21.436, 12.602, 20 },
                        { -1.735, 9.479, 12.453, 20 },
                        { -13.046, 22.077, 15.394, 20 },
                        { -24.650, 27.947, 14.698, 20 },
                        { -33.368, 34.147, 14.270, 20 },
                        { -36.205, 22.090, 14.924, 20 },
                        { -28.690, -1.745, 9.427, 20 },
                        { -29.951, -12.417, 9.416, 20 },
                        { -35.581, -21.191, 9.423, 20 },
                        { -40.664, -7.066, 4.934, 20 },
                        { -64.051, 20.642, 3.998, 20 },
                        { -46.672, 49.734, 5.174, 20 },
                        { -31.223, 53.175, 10.631, 20 },
                        { -26.395, 51.440, 9.650, 20 },
                        { -34.455, 43.171, 12.494, 20 },
                        { -19.520, -6.815, 22.362, 20 },
                        { -18.610, -3.499, 22.362, 20 },
                        { -18.760, -10.364, 22.362, 20 },
                        { -23.469, -7.020, 22.717, 20 },
                        { -29.744, -6.910, 23.428, 20 },
                        { -31.988, -6.941, 24.223, 20 },
                        { 21.706, 12.857, 20.972, 20 },
                        { 22.018, 19.369, 20.972, 20 },
                        { 22.417, 16.061, 20.972, 20 },
                        { 28.652, 16.048, 21.675, 20 },
                        { 32.967, 16.104, 22.057, 20 },
                        { 35.454, 15.993, 22.860, 20 },
                        { 22.273, 0.800, 19.709, 20 },
                        { 20.910, -8.176, 19.302, 20 },
                        { 17.177, -20.452, 18.454, 20 },
                        { 24.678, -17.478, 17.814, 20 },
                        { 32.903, -32.132, 15.157, 20 },
                        { 48.077, -34.604, 14.019, 20 },
                        { 46.444, -37.775, 13.937, 20 },
                        { -69.262, 19.778, 15.252, 20 },
                        { -67.126, 16.237, 15.378, 20 },
                        { -39.718, 11.277, 13.028, 20 },
                        { -31.809, 19.309, 16.751, 20 },
                    }
                }
            }
        },

        ["gephyrophobia"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 26.828, -150.701, -16.612, 5 },
                            { 24.973, -151.207, -16.612, 5 },
                            { 28.722, -151.106, -16.612, 5 },
                            { 26.850, -146.871, -16.327, 5 },
                            { 29.920, -145.371, -17.734, 5 },
                            { 28.342, -146.884, -17.734, 5 },
                            { 23.629, -144.958, -17.734, 5 },
                            { 25.229, -146.490, -17.734, 5 },
                            { 26.801, -143.311, -17.858, 5 },
                            { 24.039, -141.964, -17.734, 5 },
                            { 30.118, -141.766, -17.734, 5 },
                            { 26.781, -139.184, -17.858, 5 },
                            { 26.804, -133.365, -16.917, 5 },
                            { 74.202, -112.611, -1.062, 5 },
                            { -27.322, -107.194, -1.255, 5 },
                            { 26.770, -128.482, -15.630, 20 },
                            { 23.001, -127.907, -15.627, 20 },
                            { 30.690, -128.047, -15.627, 20 },
                            { 30.488, -124.681, -15.630, 20 },
                            { 22.918, -124.777, -15.630, 20 },
                            { 26.900, -121.871, -15.633, 20 },
                            { 68.229, -112.415, -1.062, 20 },
                            { -20.625, -107.339, -1.255, 20 },
                        },
                        ["blue"] = {
                            { 26.737, 5.886, -16.629, 5 },
                            { 28.688, 6.055, -16.629, 5 },
                            { 24.669, 6.156, -16.629, 5 },
                            { 26.728, 2.285, -16.327, 5 },
                            { 23.537, 0.718, -17.734, 5 },
                            { 24.981, 3.024, -17.734, 5 },
                            { 28.508, 2.205, -17.734, 5 },
                            { 30.068, 0.796, -17.734, 5 },
                            { 30.059, -2.903, -17.734, 5 },
                            { 26.774, -5.050, -17.859, 5 },
                            { 26.806, -1.001, -17.857, 5 },
                            { 23.557, -2.904, -17.734, 5 },
                            { 26.832, -11.077, -16.962, 5 },
                            { 26.815, -15.815, -15.630, 20 },
                            { 22.872, -16.330, -15.628, 20 },
                            { 23.031, -19.551, -15.630, 20 },
                            { 30.598, -16.303, -15.628, 20 },
                            { 30.586, -19.676, -15.630, 20 },
                            { 26.436, -22.368, -15.633, 20 },
                            { -24.252, -28.220, -1.255, 20 },
                            { -18.444, -29.731, -1.255, 20 },
                            { 68.013, -37.641, -1.062, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 21.414, -129.183, -15.630, 20 },
                        { 31.709, -127.743, -15.629, 20 },
                        { 21.505, -117.542, -17.043, 20 },
                        { 32.114, -117.471, -17.043, 20 },
                        { 28.551, -111.056, -15.633, 20 },
                        { 24.673, -111.484, -15.633, 20 },
                        { 25.381, -102.080, -14.474, 20 },
                        { 15.630, -98.056, -14.474, 20 },
                        { 16.975, -90.236, -14.474, 20 },
                        { 12.679, -80.623, -12.773, 20 },
                        { 16.853, -70.343, -12.712, 20 },
                        { 11.702, -57.591, -14.474, 20 },
                        { 17.712, -49.448, -14.474, 20 },
                        { 18.804, -39.008, -14.695, 20 },
                        { 28.353, -33.959, -15.633, 20 },
                        { 25.335, -34.513, -15.633, 20 },
                        { 21.529, -27.158, -17.043, 20 },
                        { 31.735, -26.659, -17.043, 20 },
                        { 29.982, -21.627, -15.633, 20 },
                        { 31.961, -17.271, -15.630, 20 },
                        { 29.830, -36.489, -15.204, 20 },
                        { 31.928, -44.045, -14.474, 20 },
                        { 38.874, -47.603, -14.474, 20 },
                        { 36.543, -55.368, -14.474, 20 },
                        { 41.969, -67.836, -12.712, 20 },
                        { 37.091, -79.502, -12.712, 20 },
                        { 41.534, -92.387, -14.474, 20 },
                        { 33.159, -100.126, -14.474, 20 },
                        { 31.175, -107.325, -14.940, 20 },
                        { 26.569, -98.572, -18.326, 20 },
                        { 24.291, -91.998, -18.326, 20 },
                        { 28.383, -82.926, -18.775, 20 },
                        { 24.787, -75.324, -20.316, 20 },
                        { 26.524, -66.489, -20.316, 20 },
                        { 24.559, -58.880, -18.663, 20 },
                        { 29.473, -48.285, -18.326, 20 },
                        { 68.300, -37.532, -1.062, 20 },
                        { 70.554, -49.213, -1.062, 20 },
                        { 71.893, -59.528, -1.062, 20 },
                        { 63.324, -74.202, -1.062, 20 },
                        { 70.266, -81.635, -1.062, 20 },
                        { 71.248, -89.120, -1.062, 20 },
                        { 70.403, -99.441, -1.062, 20 },
                        { 69.359, -110.713, -1.062, 20 },
                        { -20.352, -106.863, -1.255, 20 },
                        { -21.774, -98.266, -1.255, 20 },
                        { -21.789, -71.619, -1.255, 20 },
                        { -21.350, -63.922, -1.255, 20 },
                        { -24.601, -55.247, -1.255, 20 },
                        { -25.018, -44.083, -1.255, 20 },
                        { -20.606, -33.471, -1.255, 20 },
                    }
                }
            }
        },

        ["hangemhigh"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 10.935, 13.545, -6.435, 10 },
                            { 10.427, 10.153, -6.435, 10 },
                            { 7.600, 8.601, -6.435, 10 },
                            { 7.358, 12.591, -6.435, 10 },
                            { 11.025, 15.103, -6.435, 10 },
                            { 15.209, 12.686, -6.839, 10 },
                            { 12.599, 10.574, -6.435, 10 },
                            { 12.407, 8.072, -5.757, 10 },
                            { 15.312, 8.029, -4.900, 10 },
                            { 16.257, 10.978, -4.378, 10 },
                            { 14.389, 9.709, -3.359, 10 },
                            { 17.292, 14.523, -7.950, 10 },
                            { 10.333, 6.523, -6.435, 10 },
                            { 7.455, 3.875, -6.435, 10 },
                            { 11.928, 3.081, -6.435, 10 },
                            { 18.654, 12.563, -7.727, 10 },
                            { 15.365, 15.061, -5.615, 10 },
                            { 20.436, 15.041, -5.136, 10 },
                            { 18.045, 7.372, -7.950, 10 },
                            { 13.457, 6.882, -7.950, 10 },
                        },
                        ["blue"] = {
                            { 31.502, -8.446, -4.797, 10 },
                            { 34.675, -11.912, -3.909, 10 },
                            { 32.024, -12.956, -3.909, 10 },
                            { 29.384, -13.038, -2.793, 10 },
                            { 32.390, -13.994, -1.874, 10 },
                            { 30.468, -16.316, -1.874, 10 },
                            { 28.114, -16.277, -2.793, 10 },
                            { 26.097, -15.920, -3.909, 10 },
                            { 24.270, -14.203, -3.909, 10 },
                            { 24.478, -18.353, -3.909, 10 },
                            { 24.279, -21.596, -3.909, 10 },
                            { 27.046, -21.507, -3.909, 10 },
                            { 30.796, -21.484, -3.909, 10 },
                            { 34.171, -21.498, -3.909, 10 },
                            { 34.117, -18.950, -3.909, 10 },
                            { 31.536, -18.545, -3.909, 10 },
                            { 34.210, -15.417, -3.909, 10 },
                            { 34.680, -10.290, -3.909, 10 },
                            { 34.964, -3.897, -4.092, 10 },
                            { 32.557, -4.127, -3.909, 10 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 7.538, 14.448, -6.435, 10 },
                        { 9.878, 11.636, -6.352, 10 },
                        { 12.129, 7.821, -5.753, 10 },
                        { 15.499, 15.022, -5.557, 10 },
                        { 15.769, 12.744, -6.975, 10 },
                        { 9.224, 5.644, -6.231, 10 },
                        { 9.955, 0.635, -6.435, 10 },
                        { 8.110, -2.260, -6.290, 10 },
                        { 9.526, -7.346, -6.435, 10 },
                        { 12.147, -9.287, -7.950, 10 },
                        { 9.434, -11.995, -7.950, 10 },
                        { 9.539, -14.806, -7.950, 10 },
                        { 12.649, -18.638, -7.950, 10 },
                        { 15.874, -21.109, -7.950, 10 },
                        { 18.634, -15.449, -7.950, 10 },
                        { 22.548, -15.535, -7.950, 10 },
                        { 24.697, -12.342, -7.950, 10 },
                        { 25.391, -8.569, -7.539, 10 },
                        { 27.009, -6.371, -7.950, 10 },
                        { 26.615, -2.596, -9.252, 10 },
                        { 23.426, -2.582, -8.810, 10 },
                        { 19.554, -2.567, -9.252, 10 },
                        { 18.903, -5.276, -7.950, 10 },
                        { 20.198, 5.032, -7.950, 10 },
                        { 26.423, 7.581, -7.746, 10 },
                        { 31.245, 10.806, -7.950, 10 },
                        { 29.634, 13.797, -7.950, 10 },
                        { 17.592, 15.013, -5.136, 10 },
                        { 25.277, 14.941, -5.135, 10 },
                        { 34.681, 15.159, -5.138, 10 },
                        { 34.845, 6.002, -5.131, 10 },
                        { 34.935, -1.652, -4.617, 10 },
                        { 34.874, -9.553, -3.909, 10 },
                        { 31.870, -8.427, -4.632, 10 },
                        { 31.575, -10.964, -3.909, 10 },
                        { 28.548, -13.943, -2.793, 10 },
                        { 31.556, -15.701, -1.874, 10 },
                        { 31.127, -19.265, -3.909, 10 },
                        { 34.102, -21.351, -3.909, 10 },
                        { 25.255, -21.601, -3.909, 10 },
                        { 22.048, -18.449, -5.583, 10 },
                        { 15.926, -18.439, -5.583, 10 },
                        { 15.098, -16.450, -5.583, 10 },
                        { 9.768, -16.387, -5.565, 10 },
                        { 8.416, -14.259, -6.327, 10 },
                        { 11.004, -15.102, -7.425, 10 },
                        { 15.966, -7.479, -3.469, 10 },
                        { 15.919, -2.514, -3.469, 10 },
                        { 19.409, 3.239, -3.469, 10 },
                        { 28.781, 3.263, -3.469, 10 },
                    }
                }
            }
        },

        ["icefields"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -84.242, 93.968, 0.796, 20 },
                            { -79.371, 92.625, 0.702, 20 },
                            { -75.946, 94.190, 0.965, 20 },
                            { -70.347, 90.216, 1.061, 20 },
                            { -69.799, 86.009, 0.852, 20 },
                            { -69.348, 82.464, 0.553, 20 },
                            { 22.000, -31.267, 1.121, 20 },
                            { 19.301, -24.831, 0.796, 20 },
                            { 18.428, -31.469, 0.746, 20 },
                            { 16.540, -24.041, 0.781, 20 },
                            { 20.759, -22.067, 2.100, 20 },
                            { 15.404, -17.065, 0.878, 20 },
                            { 16.196, -13.166, 0.796, 20 },
                            { 20.815, -15.687, 0.756, 20 },
                            { 22.668, -12.170, 0.664, 20 },
                            { 27.269, -9.890, 0.758, 20 },
                            { 28.216, -12.983, 0.542, 20 },
                            { 29.245, -16.621, 0.795, 20 },
                            { 34.490, -16.677, 0.852, 20 },
                            { 31.458, -20.177, 0.767, 20 },
                            { 34.516, -25.447, 0.835, 20 },
                            { 30.824, -26.135, 0.746, 20 },
                            { 28.467, -31.114, 0.999, 20 },
                            { 22.966, -28.710, 0.840, 20 },
                            { 23.504, -22.152, 0.800, 20 },
                            { 24.751, -20.709, 2.100, 20 },
                            { 24.846, -23.249, 2.100, 20 },
                            { 26.309, -22.153, 0.800, 20 },
                        },
                        ["blue"] = {
                            { -74.606, 96.465, 1.186, 20 },
                            { -73.595, 91.425, 0.773, 20 },
                            { -69.080, 90.552, 0.822, 20 },
                            { -73.635, 86.584, 2.100, 20 },
                            { -69.956, 83.381, 0.620, 20 },
                            { -68.911, 76.939, 0.787, 20 },
                            { -73.284, 79.071, 0.690, 20 },
                            { -76.344, 74.268, 0.746, 20 },
                            { -80.717, 76.811, 0.751, 20 },
                            { -82.692, 81.807, 0.692, 20 },
                            { -87.903, 83.309, 0.948, 20 },
                            { -82.164, 86.547, 2.100, 20 },
                            { -83.771, 90.237, 0.763, 20 },
                            { -82.392, 95.772, 1.171, 20 },
                            { -77.705, 92.315, 0.720, 20 },
                            { -76.410, 86.542, 0.800, 20 },
                            { -77.807, 86.506, 2.100, 20 },
                            { -77.755, 85.105, 2.100, 20 },
                            { -77.896, 87.644, 2.100, 20 },
                            { -79.203, 86.554, 0.800, 20 },
                            { -73.201, 82.184, 0.696, 20 },
                            { -78.670, 72.561, 0.768, 20 },
                            { -88.206, 83.768, 0.972, 20 },
                            { -83.019, 96.753, 1.053, 20 },
                            { -66.481, 88.213, 0.889, 20 },
                            { -82.952, 90.145, 0.758, 20 },
                            { -86.790, 77.853, 0.737, 20 },
                            { -77.567, 96.905, 1.040, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -74.912, 96.052, 1.151, 15 },
                        { -67.939, 91.301, 0.754, 15 },
                        { -74.206, 86.411, 2.100, 15 },
                        { -77.960, 86.547, 2.100, 15 },
                        { -79.481, 86.512, 0.800, 15 },
                        { -76.670, 87.133, 0.800, 15 },
                        { -83.993, 86.451, 1.351, 15 },
                        { -81.790, 77.758, 0.661, 15 },
                        { -82.623, 92.901, 0.678, 15 },
                        { -78.215, 73.318, 0.753, 15 },
                        { -73.480, 68.948, 0.775, 15 },
                        { -77.412, 59.293, 0.750, 15 },
                        { -73.035, 53.398, 0.578, 15 },
                        { -67.721, 50.285, 0.772, 15 },
                        { -63.146, 52.446, 0.747, 15 },
                        { -59.806, 61.098, 1.567, 15 },
                        { -64.391, 68.482, 1.613, 15 },
                        { -68.257, 75.527, 1.014, 15 },
                        { -73.576, 43.321, 0.748, 15 },
                        { -66.488, 42.771, 0.821, 15 },
                        { -66.043, 37.985, 0.776, 15 },
                        { -58.021, 39.271, 0.660, 15 },
                        { -53.812, 35.192, 0.748, 15 },
                        { -46.907, 40.739, 0.680, 15 },
                        { -42.816, 33.127, 0.680, 15 },
                        { -43.621, 24.523, 0.680, 15 },
                        { -34.472, 30.556, 0.716, 15 },
                        { -31.137, 32.897, 0.729, 15 },
                        { -20.486, 32.841, 0.680, 15 },
                        { -12.575, 31.288, 0.680, 15 },
                        { -5.836, 33.330, 0.680, 15 },
                        { -3.552, 26.184, 0.680, 15 },
                        { 2.173, 29.262, 0.730, 15 },
                        { 18.006, 17.078, 0.816, 15 },
                        { 12.118, 11.643, 0.793, 15 },
                        { 5.135, 7.651, 1.179, 15 },
                        { 6.493, 0.499, 1.619, 15 },
                        { 12.426, -2.486, 1.899, 15 },
                        { 15.079, -13.419, 0.767, 15 },
                        { 18.511, -13.974, 0.814, 15 },
                        { 25.672, -15.225, 0.628, 15 },
                        { 32.596, -15.669, 0.990, 15 },
                        { 34.771, -19.492, 1.058, 15 },
                        { 29.822, -22.138, 1.813, 15 },
                        { 26.065, -22.068, 0.800, 15 },
                        { 24.879, -22.156, 2.100, 15 },
                        { 23.073, -22.140, 0.800, 15 },
                        { 17.302, -23.504, 0.791, 15 },
                        { 20.061, -22.021, 1.964, 15 },
                        { 22.103, -31.072, 1.107, 15 },
                        { 14.753, -11.487, 0.806, 15 },
                        { 24.583, -10.211, 0.693, 15 },
                        { 20.774, -3.538, 0.703, 15 },
                        { 23.597, 4.293, 0.754, 15 },
                        { 21.800, 9.219, 0.803, 15 },
                        { 21.031, 17.785, 0.755, 15 },
                        { 0.847, 1.310, 2.293, 15 },
                        { -23.684, 32.571, 8.957, 15 },
                        { -28.133, 32.403, 8.957, 15 },
                        { -26.074, 31.073, 9.007, 15 },
                        { -26.075, 42.506, 8.942, 15 },
                        { -27.461, 48.205, 8.704, 15 },
                        { -24.920, 53.410, 8.626, 15 },
                        { -27.885, 62.849, 7.664, 15 },
                        { -31.216, 67.595, 5.799, 15 },
                        { -34.557, 69.370, 5.328, 15 },
                        { -41.601, 66.533, 5.050, 15 },
                        { -50.070, 68.004, 2.885, 15 },
                        { -53.654, 62.884, 2.186, 15 },
                        { -60.419, 65.540, 1.922, 15 },
                        { -67.255, 69.979, 1.415, 15 },
                        { -67.874, 77.669, 0.746, 15 },
                    }
                }
            }
        },

        ["infinity"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 0.686, -164.685, 15.038, 20 },
                            { 4.989, -164.719, 14.017, 20 },
                            { -3.570, -164.606, 14.008, 20 },
                            { 0.704, -167.515, 13.227, 20 },
                            { -4.897, -153.384, 12.864, 20 },
                            { -10.454, -145.870, 12.832, 20 },
                            { -6.197, -140.054, 12.750, 20 },
                            { -8.992, -133.295, 12.993, 20 },
                            { -4.956, -133.410, 12.550, 20 },
                            { -3.065, -128.470, 12.521, 20 },
                            { 4.863, -132.037, 12.616, 20 },
                            { 10.001, -132.225, 12.487, 20 },
                            { 6.781, -142.249, 12.705, 20 },
                            { 9.832, -146.660, 12.705, 20 },
                            { 7.635, -150.163, 12.789, 20 },
                            { 9.087, -157.260, 13.413, 20 },
                            { 14.758, -136.086, 12.254, 20 },
                            { 16.349, -132.681, 14.634, 20 },
                            { 18.018, -128.061, 15.629, 20 },
                            { -12.662, -134.979, 13.968, 20 },
                            { -14.156, -130.673, 16.730, 20 },
                            { -13.490, -124.021, 18.444, 20 },
                            { -2.434, -139.294, 15.970, 20 },
                            { -3.731, -143.295, 15.970, 20 },
                            { -2.109, -147.638, 15.970, 20 },
                            { -2.194, -152.699, 15.970, 20 },
                            { 2.467, -154.370, 15.970, 20 },
                            { 4.668, -149.094, 15.970, 20 },
                            { 3.438, -141.575, 15.988, 20 },
                            { 4.427, -136.033, 15.970, 20 },
                            { 5.052, -138.278, 14.661, 20 },
                            { -3.932, -138.630, 14.585, 20 },
                        },
                        ["blue"] = {
                            { -1.938, 50.735, 10.006, 20 },
                            { 4.622, 47.836, 9.915, 20 },
                            { 1.690, 47.832, 11.107, 20 },
                            { -1.718, 47.784, 11.790, 20 },
                            { -5.056, 47.811, 11.366, 20 },
                            { -9.197, 47.827, 9.963, 20 },
                            { -1.855, 42.980, 10.363, 20 },
                            { -1.881, 45.137, 11.486, 20 },
                            { -1.718, 38.946, 10.547, 20 },
                            { -7.506, 33.977, 10.830, 20 },
                            { -10.847, 29.404, 10.930, 20 },
                            { -8.172, 27.405, 10.913, 20 },
                            { -11.696, 22.293, 11.591, 20 },
                            { -12.939, 17.652, 13.430, 20 },
                            { -12.242, 12.757, 15.941, 20 },
                            { -14.574, 7.748, 17.674, 20 },
                            { -8.540, 18.406, 10.997, 20 },
                            { -3.009, 13.322, 10.751, 20 },
                            { 3.399, 16.562, 10.838, 20 },
                            { 7.599, 21.071, 10.809, 20 },
                            { 11.146, 28.654, 10.176, 20 },
                            { 5.212, 33.471, 10.493, 20 },
                            { 12.399, 20.679, 10.355, 20 },
                            { 13.197, 13.251, 15.068, 20 },
                            { 13.697, 7.526, 16.376, 20 },
                            { 2.668, 21.892, 12.665, 20 },
                            { -6.262, 19.711, 12.959, 20 },
                            { -6.557, 24.753, 14.134, 20 },
                            { -4.890, 32.203, 14.086, 20 },
                            { -1.946, 37.379, 14.086, 20 },
                            { -1.792, 36.219, 19.767, 20 },
                            { 2.367, 32.404, 14.086, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -1.673, 13.364, 10.737, 20 },
                        { -9.647, 25.165, 10.989, 20 },
                        { -13.174, 10.282, 16.860, 20 },
                        { -1.803, 36.155, 19.767, 20 },
                        { -1.801, 48.004, 11.790, 20 },
                        { -7.179, 35.791, 10.805, 20 },
                        { -1.906, 40.054, 10.338, 20 },
                        { 4.381, 35.539, 10.517, 20 },
                        { 7.001, 24.615, 10.667, 20 },
                        { 14.006, 9.352, 16.441, 20 },
                        { 16.072, 36.245, 10.227, 20 },
                        { 36.496, 33.079, 10.333, 20 },
                        { 46.545, 2.253, 9.806, 20 },
                        { 64.470, -19.806, 10.597, 20 },
                        { 11.606, -42.398, 18.706, 20 },
                        { 18.944, -44.807, 28.170, 20 },
                        { 19.059, -52.038, 28.328, 20 },
                        { 19.202, -61.057, 28.116, 20 },
                        { 19.007, -69.531, 27.970, 20 },
                        { 18.989, -77.412, 28.054, 20 },
                        { -15.352, -77.274, 28.170, 20 },
                        { -15.413, -72.266, 27.970, 20 },
                        { -15.402, -65.942, 28.174, 20 },
                        { -15.384, -56.032, 27.970, 20 },
                        { -15.372, -49.323, 28.328, 20 },
                        { -18.032, -79.930, 21.917, 20 },
                        { 13.627, -60.558, 14.545, 20 },
                        { 14.977, -69.282, 14.507, 20 },
                        { 5.670, -59.580, 11.992, 20 },
                        { 6.556, -66.863, 12.287, 20 },
                        { -21.789, -63.978, 12.131, 20 },
                        { -25.488, -56.693, 12.008, 20 },
                        { -36.383, -47.963, 11.521, 20 },
                        { -54.055, -29.485, 11.411, 20 },
                        { -59.507, 0.490, 10.438, 20 },
                        { -40.848, 20.845, 11.156, 20 },
                        { -24.005, 39.456, 10.606, 20 },
                        { -52.235, -96.152, 12.814, 20 },
                        { -55.177, -104.444, 12.395, 20 },
                        { -53.130, -121.837, 12.846, 20 },
                        { -45.726, -116.586, 13.903, 20 },
                        { -45.491, -103.391, 13.498, 20 },
                        { -40.965, -139.432, 12.723, 20 },
                        { -26.268, -152.716, 12.219, 20 },
                        { -12.288, -157.239, 12.940, 20 },
                        { -5.269, -164.808, 13.148, 20 },
                        { 1.079, -164.570, 15.038, 20 },
                        { 0.649, -167.501, 13.229, 20 },
                        { 6.827, -164.495, 13.302, 20 },
                        { 4.323, -159.640, 13.733, 20 },
                        { 5.286, -154.611, 12.800, 20 },
                        { 8.777, -144.470, 12.651, 20 },
                        { 11.082, -137.186, 12.288, 20 },
                        { 7.912, -135.082, 12.591, 20 },
                        { 4.270, -130.298, 12.575, 20 },
                        { -5.641, -130.446, 12.688, 20 },
                        { -8.739, -139.134, 12.828, 20 },
                        { -7.040, -146.146, 12.810, 20 },
                        { -13.569, -132.767, 15.674, 20 },
                        { -13.476, -124.615, 18.141, 20 },
                        { 16.039, -132.915, 14.484, 20 },
                        { 18.466, -126.902, 15.683, 20 },
                        { -3.785, -138.137, 14.692, 20 },
                        { 5.195, -138.787, 14.551, 20 },
                        { 16.348, -155.554, 12.912, 20 },
                        { 24.476, -151.784, 12.183, 20 },
                        { 37.129, -142.117, 11.399, 20 },
                        { 23.509, -160.462, 13.799, 20 },
                        { 47.011, -140.446, 14.986, 20 },
                        { 60.925, -118.600, 13.845, 20 },
                        { 56.744, -102.522, 12.235, 20 },
                        { 41.703, -81.739, 11.442, 20 },
                        { 41.517, -81.490, 11.451, 20 },
                        { 27.106, -76.270, 13.489, 20 },
                    }
                }
            }
        },

        ["longest"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -12.807, -21.511, -0.600, 3 },
                            { -15.131, -21.587, -0.600, 3 },
                            { -10.557, -21.679, -0.600, 3 },
                            { -10.657, -19.582, -0.600, 3 },
                            { -12.780, -19.051, -0.600, 3 },
                            { -14.955, -19.066, -0.600, 3 },
                            { -14.830, -15.243, -0.000, 3 },
                            { -16.907, -12.583, -0.000, 3 },
                            { -15.271, -9.964, -0.000, 3 },
                            { -11.502, -15.831, -0.000, 3 },
                            { -12.975, -13.109, -0.000, 3 },
                        },
                        ["blue"] = {
                            { 11.169, -7.582, -0.600, 3 },
                            { 9.296, -7.623, -0.600, 3 },
                            { 13.018, -7.540, -0.600, 3 },
                            { 13.087, -9.849, -0.600, 3 },
                            { 9.434, -10.106, -0.600, 3 },
                            { 9.459, -13.283, -0.000, 3 },
                            { 12.973, -13.224, -0.000, 3 },
                            { 13.777, -16.002, -0.000, 3 },
                            { 14.981, -16.607, -0.000, 3 },
                            { 13.459, -18.853, -0.000, 3 },
                            { 11.346, -15.897, -0.000, 3 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -12.959, -21.454, -0.600, 3 },
                        { -14.425, -18.984, -0.600, 3 },
                        { -11.583, -18.699, -0.600, 3 },
                        { -11.648, -15.749, -0.000, 3 },
                        { -14.579, -15.324, -0.000, 3 },
                        { -15.902, -12.469, -0.000, 3 },
                        { -15.028, -10.077, -0.000, 3 },
                        { -12.518, -13.055, -0.000, 3 },
                        { -8.712, -13.089, -0.504, 3 },
                        { -5.637, -13.103, -0.000, 3 },
                        { -1.378, -12.986, -0.000, 3 },
                        { 3.347, -13.094, -0.000, 3 },
                        { 9.345, -13.483, -0.000, 3 },
                        { 9.396, -9.793, -0.600, 3 },
                        { 11.097, -7.580, -0.600, 3 },
                        { 13.136, -9.929, -0.600, 3 },
                        { 12.719, -13.742, -0.000, 3 },
                        { 14.196, -16.621, -0.000, 3 },
                        { 9.799, -15.805, -0.000, 3 },
                        { 3.536, -16.043, -0.000, 3 },
                        { -0.355, -16.203, -0.000, 3 },
                        { -6.341, -15.679, -0.000, 3 },
                        { 0.661, -14.670, 2.104, 1 },
                        { -2.810, -15.323, 2.104, 1 },
                        { -3.974, -18.100, 2.056, 1 },
                        { -7.435, -18.038, 2.056, 1 },
                        { 4.500, -18.491, 2.056, 1 },
                        { -6.418, -10.009, 2.056, 1 },
                        { -2.584, -14.049, 2.104, 1 },
                        { 1.157, -13.753, 2.104, 1 },
                        { 2.170, -11.126, 2.056, 1 },
                        { 5.738, -11.058, 2.056, 1 },
                    }
                }
            }
        },

        ["prisoner"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -9.045, -4.793, 5.592, 1 },
                            { -7.103, -6.117, 5.592, 1 },
                            { -7.084, -3.884, 5.592, 1 },
                            { -7.196, -6.306, 3.192, 1 },
                            { -7.123, -6.204, 1.392, 1 },
                            { -9.414, -6.376, 1.392, 1 },
                            { -9.432, -3.711, 2.007, 1 },
                            { -9.493, -0.920, 2.702, 1 },
                            { -9.470, 2.531, 3.192, 1 },
                            { -5.986, 4.413, 3.192, 1 },
                            { -3.644, -6.378, 1.392, 1 },
                            { -3.810, -4.421, 1.392, 1 },
                            { -8.412, -6.212, 3.192, 3 },
                            { -5.927, -6.141, 3.192, 3 },
                            { -3.903, -6.168, 3.192, 3 },
                            { -3.891, -3.771, 3.192, 3 },
                            { -5.489, -2.346, 3.192, 3 },
                            { -5.498, 2.002, 3.192, 3 },
                            { -7.146, 1.936, 3.192, 3 },
                            { -3.412, 2.155, 3.192, 3 },
                            { -7.204, -0.239, 1.392, 3 },
                            { -7.121, -2.562, 1.392, 3 },
                            { -5.103, -4.915, -0.424, 3 },
                            { -6.390, -2.443, -0.432, 3 },
                            { -6.372, 0.339, -0.437, 3 },
                            { -3.837, -0.284, -0.528, 3 },
                        },
                        ["blue"] = {
                            { 9.217, 5.184, 5.592, 1 },
                            { 7.123, 6.533, 5.592, 1 },
                            { 7.068, 4.134, 5.592, 1 },
                            { 2.487, 5.641, 3.192, 1 },
                            { 7.134, 6.447, 3.192, 1 },
                            { 7.102, 3.723, 3.192, 1 },
                            { 7.437, 4.307, 1.392, 1 },
                            { 7.180, 0.093, 1.392, 1 },
                            { 3.600, 3.947, 1.392, 1 },
                            { 3.778, 6.471, 1.392, 1 },
                            { 7.275, 1.757, -0.408, 1 },
                            { 7.061, 0.253, 3.192, 3 },
                            { 7.113, 2.853, 3.192, 3 },
                            { 8.298, 6.347, 3.192, 3 },
                            { 3.934, 6.445, 3.192, 3 },
                            { 3.920, 2.519, 3.192, 3 },
                            { 5.351, 4.345, 1.392, 3 },
                            { 5.560, 6.158, -0.408, 3 },
                            { 5.759, 2.372, -0.528, 3 },
                            { 5.871, 0.043, -0.528, 3 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -3.837, -6.270, 3.192, 3 },
                        { -5.820, -6.238, 3.192, 3 },
                        { -5.175, -3.037, 3.192, 3 },
                        { -5.588, 1.077, 3.192, 3 },
                        { -7.215, 2.103, 3.192, 3 },
                        { -3.402, 2.298, 3.192, 3 },
                        { -1.739, 1.503, 3.192, 3 },
                        { -0.362, 0.463, 3.192, 3 },
                        { 0.955, -0.531, 3.192, 3 },
                        { 2.216, -2.054, 3.192, 3 },
                        { 0.628, -2.185, 3.192, 3 },
                        { -1.321, -2.146, 3.192, 3 },
                        { 2.046, 2.198, 3.192, 3 },
                        { 3.809, 2.787, 3.192, 3 },
                        { 3.861, 5.880, 3.192, 3 },
                        { 7.062, 2.987, 3.192, 3 },
                        { 7.235, 0.200, 3.192, 3 },
                        { 7.025, -2.321, 1.392, 3 },
                        { 3.278, -2.365, 1.392, 3 },
                        { 5.125, 4.045, 1.392, 3 },
                        { -1.557, -0.866, 1.392, 3 },
                        { -4.877, -4.656, -0.502, 3 },
                        { -6.270, -3.555, -0.468, 3 },
                        { -4.569, -1.919, -0.420, 3 },
                        { -3.563, 0.604, -0.518, 3 },
                        { -0.514, -1.547, -0.408, 3 },
                        { 1.092, 0.901, -0.428, 3 },
                        { 0.844, -0.967, -0.410, 3 },
                        { 2.110, 1.101, -0.408, 3 },
                        { 3.737, -0.484, -0.528, 3 },
                        { 5.630, -1.017, -0.408, 3 },
                        { 6.212, 1.439, -0.485, 3 },
                        { 4.566, 2.529, -0.419, 3 },
                        { 5.305, 5.640, -0.408, 3 },
                    }
                }
            }
        },

        ["putput"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -18.877, -20.343, 0.902, 1 },
                            { -18.880, -19.143, 0.902, 1 },
                            { -18.868, -17.053, 0.902, 1 },
                            { -16.836, -16.734, 0.902, 1 },
                            { -16.729, -18.076, 0.902, 1 },
                            { -16.818, -20.024, 0.902, 1 },
                            { -16.792, -22.643, 0.902, 1 },
                            { -18.573, -22.547, 0.902, 1 },
                            { -16.705, -23.647, 0.902, 1 },
                            { -18.912, -20.024, 2.302, 1 },
                            { -17.060, -18.430, 2.302, 1 },
                            { -15.185, -18.419, 2.302, 1 },
                            { -17.168, -21.965, 2.302, 1 },
                            { -15.143, -21.967, 2.302, 1 },
                        },
                        ["blue"] = {
                            { 34.965, -28.117, -0.000, 1 },
                            { 31.845, -25.448, 1.000, 1 },
                            { 31.940, -30.875, 1.000, 1 },
                            { 29.746, -32.661, 1.000, 1 },
                            { 27.040, -28.219, -0.000, 1 },
                            { 31.744, -23.794, 1.000, 1 },
                            { 33.425, -26.345, 0.582, 1 },
                            { 29.911, -29.942, 0.494, 1 },
                            { 33.025, -28.469, -0.000, 1 },
                            { 30.514, -27.782, -0.000, 1 },
                            { 32.536, -28.163, 1.000, 1 },
                            { 31.013, -28.258, 1.000, 1 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 34.911, -28.112, -0.000, 1 },
                        { 33.083, -29.194, -0.000, 1 },
                        { 31.900, -25.684, 1.000, 1 },
                        { 29.329, -28.130, -0.000, 1 },
                        { 16.820, -20.426, 0.500, 1 },
                        { 14.253, -20.374, -0.000, 1 },
                        { 13.823, -22.087, -0.000, 1 },
                        { 13.214, -18.665, -0.000, 1 },
                        { 15.761, -8.171, 0.902, 1 },
                        { 15.917, -4.602, 0.102, 1 },
                        { 17.286, -4.527, 1.702, 1 },
                        { 31.162, -9.113, 0.902, 1 },
                        { 34.240, -9.062, 1.302, 1 },
                        { 33.683, -11.440, 0.902, 1 },
                        { 15.607, -34.436, 0.902, 1 },
                        { 11.874, -34.472, 0.902, 1 },
                        { -1.496, -34.573, 0.902, 1 },
                        { -4.936, -35.924, 2.302, 1 },
                        { -1.186, -34.465, 3.003, 1 },
                        { -3.863, -34.547, 3.402, 1 },
                        { -5.059, -33.110, 2.302, 1 },
                        { -2.134, -33.065, 2.302, 1 },
                        { -16.762, -22.184, 2.302, 1 },
                        { -17.438, -18.259, 2.302, 1 },
                        { -18.894, -21.778, 0.902, 1 },
                        { -18.969, -18.277, 0.902, 1 },
                        { -5.305, -20.270, 0.902, 1 },
                        { -3.251, -18.192, 0.902, 1 },
                        { -2.272, -21.063, 0.902, 1 },
                        { -3.791, -20.897, 0.902, 1 },
                        { -3.026, -22.511, 0.902, 1 },
                        { -4.989, -22.108, 0.902, 1 },
                        { -0.986, -20.241, 0.902, 1 },
                        { -0.858, -17.961, 0.902, 1 },
                        { -0.821, -2.799, 0.902, 1 },
                        { -5.132, -2.797, 0.902, 1 },
                        { -6.032, -2.858, 2.202, 1 },
                        { -3.031, -2.755, 0.902, 1 },
                        { -3.019, -6.423, 0.902, 1 },
                    }
                }
            }
        },

        ["ratrace"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -4.265, -0.841, -0.591, 1.2 },
                            { -4.171, -3.893, -0.591, 1.2 },
                            { -4.221, 2.387, -0.591, 1.2 },
                            { -1.296, 2.380, -0.591, 1.2 },
                            { 1.179, 2.347, -0.591, 1.2 },
                            { 3.804, 2.312, -0.591, 1.2 },
                            { 6.278, 2.279, -0.591, 1.2 },
                            { 6.223, 0.180, -0.591, 1.2 },
                            { 6.165, -1.995, -0.591, 1.2 },
                            { 6.111, -4.019, -0.591, 1.2 },
                            { 3.936, -4.029, -0.591, 1.2 },
                            { 1.686, -4.039, -0.591, 1.2 },
                            { -0.639, -4.050, -0.591, 1.2 },
                            { -0.736, -0.855, -0.398, 1.2 },
                            { 1.814, -0.852, -0.398, 1.2 },
                            { -1.780, -6.610, -0.985, 1.2 },
                            { -4.768, -6.625, -0.989, 1.2 },
                        },
                        ["blue"] = {
                            { 18.555, -22.638, -3.612, 1.2 },
                            { 18.602, -19.649, -3.612, 1.2 },
                            { 18.656, -16.274, -3.612, 1.2 },
                            { 21.437, -22.694, -3.612, 1.2 },
                            { 15.863, -22.692, -3.612, 1.2 },
                            { 13.880, -25.187, -3.612, 1.2 },
                            { 13.079, -19.926, -3.612, 1.2 },
                            { 11.118, -22.600, -3.612, 1.2 },
                            { 11.521, -25.449, -3.612, 1.2 },
                            { 15.754, -20.938, -3.612, 1.2 },
                            { 17.079, -24.394, -3.612, 1.2 },
                            { 21.787, -24.403, -3.612, 1.2 },
                            { 18.345, -19.676, -3.612, 1.2 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 18.598, -22.751, -3.612, 1.5 },
                        { 18.700, -19.976, -3.612, 1.5 },
                        { 21.494, -22.848, -3.612, 1.5 },
                        { 18.562, -24.034, -3.612, 1.5 },
                        { 15.306, -22.695, -3.612, 1.5 },
                        { 18.345, -19.823, -3.612, 1.5 },
                        { 18.575, -16.395, -3.612, 1.5 },
                        { 18.521, -11.157, -2.977, 1.5 },
                        { 16.452, -9.325, -2.392, 1.5 },
                        { 20.851, -9.360, -2.403, 1.5 },
                        { 20.879, -5.811, -2.119, 1.5 },
                        { 18.559, -5.792, -2.123, 1.5 },
                        { 16.202, -5.774, -2.127, 1.5 },
                        { 20.548, -1.707, -2.124, 1.5 },
                        { 20.599, 0.205, -2.126, 1.5 },
                        { 18.492, -1.653, -2.128, 1.5 },
                        { 16.693, -1.682, -2.131, 1.5 },
                        { 16.660, 0.318, -2.133, 1.5 },
                        { 15.023, -1.491, -2.044, 1.5 },
                        { 11.808, -1.520, -1.431, 1.5 },
                        { 9.046, -1.533, -0.903, 1.5 },
                        { 5.896, -1.437, -0.591, 1.5 },
                        { 5.284, -4.283, -0.591, 1.5 },
                        { 2.422, -4.127, -0.591, 1.5 },
                        { -0.500, -4.072, -0.591, 1.5 },
                        { -4.353, -0.690, -0.591, 1.5 },
                        { 0.722, -0.951, -0.398, 1.5 },
                        { 0.625, 2.046, -0.591, 1.5 },
                        { 6.407, 2.659, -0.591, 1.5 },
                        { -6.510, -0.817, -0.591, 1.5 },
                        { -1.688, -5.587, -0.747, 1.5 },
                        { -5.353, -7.544, -1.202, 1.5 },
                        { -3.255, -11.025, -2.012, 1.5 },
                        { -7.804, -12.288, -2.434, 1.5 },
                        { -5.010, -12.769, -2.434, 1.5 },
                        { -4.821, -15.572, -2.121, 1.5 },
                        { -1.997, -14.492, -2.128, 1.5 },
                        { 1.032, -12.396, -2.434, 1.5 },
                        { 4.650, -14.496, -2.491, 1.5 },
                        { 8.910, -14.003, -2.897, 1.5 },
                        { 7.350, -16.855, -3.175, 1.5 },
                        { 10.278, -18.159, -3.476, 1.5 },
                        { 10.907, -22.602, -3.612, 1.5 },
                        { 10.404, -26.288, -3.612, 1.5 },
                        { 8.770, -26.114, -3.612, 1.5 },
                        { 5.092, -25.330, -3.612, 1.5 },
                        { 3.570, -22.596, -3.612, 1.5 },
                        { 8.342, -9.050, 0.222, 1.5 },
                        { 8.388, -11.264, 0.222, 1.5 },
                        { 4.224, -11.436, 0.222, 1.5 },
                        { 1.041, -12.093, 0.222, 1.5 },
                        { -2.376, -12.925, 0.222, 1.5 },
                        { 12.679, -11.210, 0.222, 1.5 },
                        { 13.886, -15.353, -0.448, 1.5 },
                        { 16.857, -19.610, -1.158, 1.5 },
                        { 12.713, -8.137, -0.027, 1.5 },
                        { 11.997, -4.852, -0.334, 1.5 },
                        { 8.948, -3.961, -0.595, 1.5 },
                    }
                }
            }
        },

        ["sidewinder"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -32.038, -42.030, -3.842, 1 },
                            { -32.058, -38.088, -3.842, 1 },
                            { -34.378, -37.616, -3.842, 1 },
                            { -29.882, -38.288, -3.842, 1 },
                            { -32.052, -34.400, -3.842, 1 },
                            { -32.000, -30.297, -3.842, 1 },
                            { -34.306, -31.102, -3.842, 1 },
                            { -29.971, -30.995, -3.842, 1 },
                            { -33.083, -34.203, 0.558, 1 },
                            { -30.817, -34.064, 0.558, 1 },
                            { -31.922, -38.540, 0.558, 1 },
                            { -29.894, -37.741, 0.558, 1 },
                            { -34.150, -38.193, 0.558, 1 },
                            { -34.019, -25.996, -3.758, 20 },
                            { -32.237, -26.019, -3.842, 20 },
                            { -30.649, -26.327, -3.842, 20 },
                            { -32.438, -27.435, -3.842, 20 },
                            { -37.184, -30.359, -3.788, 20 },
                            { -19.200, -35.590, -3.842, 20 },
                            { -26.949, -31.019, -3.842, 20 },
                            { -24.517, -28.190, -3.842, 20 },
                            { -39.419, -26.127, -3.607, 20 },
                            { -35.667, -20.120, -3.712, 20 },
                            { -29.906, -18.405, -3.751, 20 },
                        },
                        ["blue"] = {
                            { 30.346, -46.092, -3.842, 1 },
                            { 30.222, -42.002, -3.842, 1 },
                            { 28.175, -41.588, -3.842, 1 },
                            { 32.524, -42.273, -3.842, 1 },
                            { 30.344, -38.561, -3.842, 1 },
                            { 30.318, -34.491, -3.842, 1 },
                            { 28.489, -35.124, -3.842, 1 },
                            { 32.228, -35.015, -3.842, 1 },
                            { 31.191, -38.078, 0.558, 1 },
                            { 29.498, -38.389, 0.558, 1 },
                            { 32.529, -41.659, 0.558, 1 },
                            { 28.206, -42.282, 0.558, 1 },
                            { 30.482, -42.579, 0.558, 1 },
                            { 29.155, -29.057, -3.544, 20 },
                            { 30.813, -28.128, -3.545, 20 },
                            { 32.263, -29.028, -3.640, 20 },
                            { 35.152, -33.516, -3.842, 20 },
                            { 24.737, -34.233, -3.842, 20 },
                            { 32.985, -22.856, -3.686, 20 },
                            { 18.673, -29.437, -3.842, 20 },
                            { 25.869, -26.272, -3.600, 20 },
                            { 38.628, -27.061, -3.768, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -27.878, -31.234, -3.842, 20 },
                        { -36.953, -30.721, -3.811, 20 },
                        { -37.436, -27.419, -3.661, 20 },
                        { -34.456, -21.788, -3.742, 20 },
                        { -32.096, -26.285, -3.842, 20 },
                        { -29.634, -25.168, -3.832, 20 },
                        { -34.866, -28.083, -3.787, 20 },
                        { -26.645, -28.899, -3.842, 20 },
                        { -21.355, -27.144, -3.922, 20 },
                        { -20.884, -35.450, -3.842, 20 },
                        { -35.229, 24.631, -1.388, 20 },
                        { -34.224, 29.399, -0.094, 20 },
                        { -36.717, 30.853, 0.158, 20 },
                        { -40.560, 32.969, 0.158, 20 },
                        { -42.575, 30.380, 0.158, 20 },
                        { -44.805, 27.597, 0.158, 20 },
                        { -49.385, 29.869, 0.158, 20 },
                        { -50.090, 26.902, 0.158, 20 },
                        { -41.823, 36.213, 0.158, 20 },
                        { -46.082, 40.089, 0.158, 20 },
                        { -43.472, 41.391, 0.158, 20 },
                        { -32.423, 30.293, -0.500, 20 },
                        { -30.045, 34.901, -1.744, 20 },
                        { -30.980, 40.681, -3.266, 20 },
                        { 2.643, 56.783, -1.989, 20 },
                        { -12.992, -20.466, 0.254, 20 },
                        { -11.841, -16.246, 0.186, 20 },
                        { -9.446, -11.425, 0.169, 20 },
                        { -7.991, -5.461, 0.163, 20 },
                        { 5.015, -4.136, 0.174, 20 },
                        { 7.795, 1.243, 0.158, 20 },
                        { 10.593, -4.632, 0.179, 20 },
                        { 11.898, -10.340, 0.207, 20 },
                        { 11.558, -17.742, 0.264, 20 },
                        { 15.593, -16.291, 0.182, 20 },
                        { 15.459, -10.598, 0.176, 20 },
                        { 13.497, -5.461, 0.165, 20 },
                        { 11.771, 1.393, -0.261, 20 },
                        { 24.847, -3.390, -3.842, 20 },
                        { 31.486, -3.823, -3.278, 20 },
                        { 48.085, -9.741, -3.922, 20 },
                        { 40.663, -18.889, -3.418, 20 },
                        { 36.204, -27.681, -3.677, 20 },
                        { 35.384, -33.673, -3.842, 20 },
                        { 32.389, -28.745, -3.634, 20 },
                        { 29.506, -29.255, -3.562, 20 },
                        { 25.352, -33.592, -3.842, 20 },
                        { 18.557, -29.519, -3.842, 20 },
                        { 24.622, -25.480, -3.645, 20 },
                        { 31.636, -14.489, -3.042, 20 },
                        { 45.987, 17.752, -2.748, 20 },
                        { 51.712, 16.487, -1.386, 20 },
                        { 49.478, 20.863, -0.081, 20 },
                        { 45.941, 23.812, 0.158, 20 },
                        { 41.784, 26.710, 0.362, 20 },
                        { 49.532, 28.777, 0.158, 20 },
                        { 39.415, 34.509, 0.159, 20 },
                        { 44.177, 39.506, 0.158, 20 },
                    }
                }
            }
        },

        ["timberland"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { 17.266, -52.192, -17.752, 1 },
                            { 17.290, -49.567, -17.751, 1 },
                            { 15.247, -50.437, -17.751, 1 },
                            { 19.106, -50.375, -17.751, 1 },
                            { 19.440, -56.868, -17.752, 1 },
                            { 15.454, -57.572, -17.752, 1 },
                            { 17.993, -63.795, -17.752, 1 },
                            { 17.398, -63.888, -13.352, 1 },
                            { 16.001, -61.757, -13.352, 1 },
                            { 18.789, -61.377, -13.352, 1 },
                            { 15.258, -57.089, -13.352, 1 },
                            { 19.348, -57.537, -13.352, 1 },
                            { 18.582, -53.587, -13.352, 1 },
                            { 16.165, -53.552, -13.352, 1 },
                            { 12.986, -43.723, -17.994, 20 },
                            { 14.782, -41.508, -18.271, 20 },
                            { 19.289, -40.736, -17.749, 20 },
                            { 20.498, -44.292, -17.896, 20 },
                            { 22.242, -49.547, -17.463, 20 },
                            { 12.560, -49.415, -17.485, 20 },
                            { 17.253, -46.154, -17.966, 20 },
                        },
                        ["blue"] = {
                            { -16.351, 52.506, -17.752, 1 },
                            { -16.285, 49.600, -17.752, 1 },
                            { -14.417, 50.332, -17.752, 1 },
                            { -18.039, 50.303, -17.752, 1 },
                            { -18.514, 56.821, -17.752, 1 },
                            { -14.219, 57.682, -17.752, 1 },
                            { -17.878, 61.449, -17.752, 1 },
                            { -15.029, 61.382, -17.752, 1 },
                            { -17.031, 63.912, -17.752, 1 },
                            { -16.328, 64.042, -13.352, 1 },
                            { -15.025, 61.383, -13.352, 1 },
                            { -17.623, 61.409, -13.352, 1 },
                            { -14.134, 57.009, -13.352, 1 },
                            { -18.472, 57.544, -13.352, 1 },
                            { -17.858, 53.538, -13.352, 1 },
                            { -15.204, 53.527, -13.352, 1 },
                            { -12.287, 43.964, -17.993, 20 },
                            { -14.429, 41.743, -18.242, 20 },
                            { -17.752, 39.922, -17.756, 20 },
                            { -19.917, 44.001, -17.835, 20 },
                            { -23.075, 46.887, -17.469, 20 },
                            { -21.215, 49.963, -17.489, 20 },
                            { -11.237, 49.210, -17.437, 20 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { -21.760, 49.401, -17.444, 20 },
                        { -20.022, 44.604, -17.853, 20 },
                        { -16.316, 44.815, -18.084, 20 },
                        { -14.583, 41.449, -18.228, 20 },
                        { -8.793, 45.747, -17.469, 20 },
                        { -7.346, 38.298, -16.684, 20 },
                        { -25.237, 40.575, -16.176, 20 },
                        { -39.780, 35.372, -19.299, 20 },
                        { -31.149, 28.498, -20.286, 20 },
                        { -21.448, 23.095, -21.139, 20 },
                        { -16.827, 14.981, -20.812, 20 },
                        { -11.558, 23.765, -20.167, 20 },
                        { -7.061, 21.281, -20.526, 20 },
                        { -1.332, 26.554, -20.946, 20 },
                        { 3.228, 27.498, -21.966, 20 },
                        { 6.234, 34.909, -21.564, 20 },
                        { 7.905, 40.746, -19.280, 20 },
                        { 0.856, 40.589, -16.734, 20 },
                        { 13.843, 38.274, -19.172, 20 },
                        { 11.696, 32.539, -18.103, 20 },
                        { 12.970, 26.667, -16.735, 20 },
                        { 18.880, 24.073, -16.790, 20 },
                        { 17.343, 27.706, -16.000, 20 },
                        { 17.160, 20.517, -16.170, 20 },
                        { 9.417, 4.501, -19.195, 20 },
                        { 1.282, -0.845, -21.188, 20 },
                        { -8.667, 4.216, -19.001, 20 },
                        { -8.786, -1.680, -18.706, 20 },
                        { -13.124, -5.128, -18.890, 20 },
                        { -20.641, -0.111, -20.032, 20 },
                        { -23.259, -1.345, -19.504, 20 },
                        { -26.120, 1.292, -18.403, 20 },
                        { -26.584, 18.929, -18.647, 20 },
                        { -32.882, 23.135, -17.802, 20 },
                        { 23.406, 0.481, -19.558, 20 },
                        { 25.989, 13.101, -20.708, 20 },
                        { 30.436, 23.595, -20.652, 20 },
                        { 24.135, 25.197, -18.038, 20 },
                        { 24.302, 36.122, -19.387, 20 },
                        { 34.926, 34.225, -21.383, 20 },
                        { 31.237, 38.197, -21.085, 20 },
                        { 17.456, -8.934, -20.985, 20 },
                        { 19.799, -6.107, -20.900, 20 },
                        { 14.680, -12.478, -21.133, 20 },
                        { 17.895, -16.702, -20.916, 20 },
                        { 27.622, -18.947, -18.653, 20 },
                        { 33.339, -23.670, -17.908, 20 },
                        { 36.868, -24.827, -17.576, 20 },
                        { 24.930, -9.421, -20.987, 20 },
                        { 40.627, -20.787, -20.971, 20 },
                        { 41.431, -30.132, -20.133, 20 },
                        { 33.012, -29.047, -20.302, 20 },
                        { 24.360, -24.418, -21.089, 20 },
                        { 18.477, -20.258, -20.955, 20 },
                        { 38.118, -42.371, -18.024, 20 },
                        { 31.121, -39.883, -15.299, 20 },
                        { 21.939, -35.448, -15.605, 20 },
                        { 16.508, -33.407, -15.662, 20 },
                        { 9.779, -33.350, -15.335, 20 },
                        { 5.462, -35.370, -15.013, 20 },
                        { 3.269, -41.080, -15.467, 20 },
                        { 4.409, -43.730, -15.842, 20 },
                        { 9.123, -40.396, -17.330, 20 },
                        { 13.527, -38.877, -17.608, 20 },
                        { 17.841, -39.843, -17.908, 20 },
                        { 23.256, -42.197, -17.150, 20 },
                        { 24.764, -48.621, -17.306, 20 },
                        { 21.074, -48.021, -17.678, 20 },
                        { 13.414, -50.025, -17.571, 20 },
                        { 11.942, -48.090, -17.459, 20 },
                        { 16.845, -43.607, -18.191, 20 },
                        { 17.288, -46.850, -17.948, 20 },
                        { -4.425, -39.284, -19.355, 20 },
                        { -11.422, -37.669, -19.557, 20 },
                        { -10.684, -31.710, -17.800, 20 },
                        { -4.416, -31.971, -21.852, 20 },
                        { -0.201, -22.997, -22.046, 20 },
                        { -3.052, -14.447, -20.818, 20 },
                        { -14.698, -13.986, -20.642, 20 },
                        { -23.180, -14.819, -20.756, 20 },
                        { -28.423, -19.072, -20.797, 20 },
                        { -30.746, -30.112, -20.792, 20 },
                        { -23.019, -35.703, -19.251, 20 },
                        { -16.071, -23.479, -16.571, 20 },
                        { -16.651, -27.846, -16.007, 20 },
                        { -10.678, -29.598, -17.121, 20 },
                        { -32.103, -34.882, -21.270, 20 },
                    }
                }
            }
        },

        ["wizard"] = {
            enabled = true,
            default_mode = "Mode A",

            -- Airstrike projectile object:
            projectile = { "proj", "weapons\\rocket launcher\\rocket" },
            dmg = { "jpt!", "weapons\\rocket launcher\\explosion" },

            -- Quantity of projectiles spawned:
            min_projectiles = 1,
            max_projectiles = 10,

            modes = {
                ["Mode A"] = {
                    enabled = true,
                    kills_required = 5,
                    height_from_ground = 20
                },
                ["Mode B"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        ["red"] = {
                            { -9.113, 9.420, -2.750, 4 },
                            { -7.135, 10.076, -2.750, 4 },
                            { -10.274, 6.711, -2.750, 4 },
                            { -8.034, 8.036, -2.750, 4 },
                            { -5.445, 5.435, -2.750, 4 },
                            { -3.430, 3.419, -2.750, 4 },
                            { -6.845, 3.657, -2.750, 4 },
                            { -3.862, 6.522, -2.750, 4 },
                            { -9.262, 3.318, -4.500, 4 },
                            { -6.953, 7.130, -4.500, 4 },
                            { -2.679, 8.833, -4.500, 4 },
                            { -11.351, 3.312, -2.750, 1.5 },
                        },
                        ["blue"] = {
                            { 9.216, -9.200, -2.750, 4 },
                            { 7.551, -10.592, -2.750, 4 },
                            { 8.352, -7.709, -2.750, 4 },
                            { 10.243, -6.717, -2.750, 4 },
                            { 5.520, -5.651, -2.750, 4 },
                            { 3.628, -3.621, -2.750, 4 },
                            { 6.581, -3.622, -2.750, 4 },
                            { 4.050, -6.500, -2.750, 4 },
                            { 9.263, -3.314, -4.500, 4 },
                            { 6.913, -7.079, -4.500, 4 },
                            { 2.643, -8.722, -4.500, 4 },
                            { 11.135, -3.364, -2.750, 1 },
                        }
                    }
                },
                ["Mode C"] = {
                    enabled = true,
                    kills_required = 5,
                    strike_locations = {
                        { 9.156, -9.219, -2.750, 4 },
                        { 7.303, -10.556, -2.750, 4 },
                        { 10.252, -6.711, -2.750, 4 },
                        { 4.286, -6.500, -2.750, 4 },
                        { 6.209, -3.963, -2.750, 4 },
                        { 0.755, -6.433, -3.724, 4 },
                        { 6.442, 1.365, -3.419, 4 },
                        { 6.393, 4.496, -2.750, 4 },
                        { 3.884, 5.823, -2.750, 4 },
                        { 6.772, 10.761, -2.750, 4 },
                        { 9.217, 9.193, -2.750, 4 },
                        { 10.258, 7.004, -2.750, 4 },
                        { -1.491, 6.523, -3.358, 4 },
                        { -3.980, 6.463, -2.750, 4 },
                        { -6.039, 3.986, -2.750, 4 },
                        { -10.831, 6.579, -2.750, 4 },
                        { -9.171, 9.272, -2.750, 4 },
                        { -7.080, 10.269, -2.750, 4 },
                        { -6.552, -1.644, -3.280, 4 },
                        { -6.119, -4.347, -2.750, 4 },
                        { -3.751, -6.182, -2.750, 4 },
                        { -6.942, -10.948, -2.750, 4 },
                        { -10.693, -7.161, -2.750, 4 },
                        { -3.237, -8.959, -4.500, 4 },
                        { -7.107, -6.929, -4.500, 4 },
                        { -8.885, -2.909, -4.500, 4 },
                        { -8.882, 0.616, -4.500, 4 },
                        { -8.867, 3.166, -4.500, 4 },
                        { -6.874, 7.139, -4.500, 4 },
                        { -2.979, 8.621, -4.500, 4 },
                        { 0.895, 8.576, -4.241, 4 },
                        { 4.421, 8.741, -4.500, 4 },
                        { 7.620, 6.434, -4.500, 4 },
                        { 8.646, 2.501, -4.500, 4 },
                        { 8.678, -2.917, -4.500, 4 },
                        { 4.682, -1.593, -4.500, 4 },
                        { 0.486, -3.671, -4.500, 4 },
                        { -3.152, -1.553, -4.500, 4 },
                        { -1.565, 3.139, -4.500, 4 },
                        { 2.425, 2.118, -4.500, 4 },
                        { 1.372, 1.649, -2.300, 4 },
                        { 1.422, -1.331, -2.300, 4 },
                        { -1.576, -1.492, -2.300, 4 },
                        { -1.648, 1.470, -2.300, 4 },
                        { 1.431, 6.474, -4.500, 4 },
                        { 6.474, -1.047, -4.500, 4 },
                        { -1.120, -6.105, -4.500, 4 },
                        { -6.529, 1.037, -4.500, 4 },
                        { 1.089, 6.494, -4.500, 4 },
                        { 6.587, -1.181, -4.500, 4 },
                        { -0.019, -10.990, -4.500, 1 },
                        { -0.118, 10.797, -4.500, 1 },
                        { 10.911, 0.033, -4.500, 1 },
                        { -10.898, -0.059, -4.500, 1 },
                    }
                }
            }
        }
    }
}
-- Configuration [ends] ===================================================


-- Do Not Touch --
-- TABLES:
local players = { }

-- Variables
local delta_time = 1 / 30 -- 1-30th seconds (0.03333333333333333 seconds)
local game_over, map_name
local gmatch, lower, upper, gsub = string.gmatch, string.lower, string.upper, string.gsub
local floor = math.floor

function OnScriptLoad()

    -- Register needed event callbacks:
    register_callback(cb["EVENT_TICK"], "OnTick")
    register_callback(cb["EVENT_DIE"], "OnPlayerDeath")
    register_callback(cb["EVENT_GAME_END"], "OnGameEnd")
    register_callback(cb["EVENT_SPAWN"], "OnPlayerSpawn")
    register_callback(cb["EVENT_JOIN"], "OnPlayerConnect")
    register_callback(cb["EVENT_GAME_START"], "OnGameStart")
    register_callback(cb["EVENT_COMMAND"], "OnServerCommand")
    register_callback(cb["EVENT_LEAVE"], "OnPlayerDisconnect")
    register_callback(cb["EVENT_DAMAGE_APPLICATION"], "OnDamageApplication")

    if (get_var(0, "$gt") ~= "n/a") then
        map_name = get_var(0, "$map")
        airstrike.messages.periodic_broadcast.timer = 0
    end
end

-- for projectile debugging --
local projectile_debug_mode = false
local TIMER = 0
local DELAY = 2 -- in seconds
local MiddleX, MiddleY, MiddleZ, MiddleHeight = 65.749893188477, -120.40949249268, 0.11860413849354, 20
--

function OnTick()

    if (not game_over) and mapIsEnabled() then
        local t = airstrike.messages.periodic_broadcast
        t.timer = t.timer + delta_time

        local time_remaining = floor(t.interval - t.timer)

        if (time_remaining <= 0) then
            t.timer = 0
            for i = 1, 16 do
                if player_present(i) then
                    for j = 1, #t.lines do
                        local msg = gsub(gsub(gsub(t.lines[j],
                                "%%cmd%%", airstrike.base_command),
                                "%%mode_cmd%%", airstrike.mode_command),
                                "%%info_cmd%%", airstrike.info_command)
                        Send(i, msg, t.environment)
                    end
                end
            end
        end
    end

    -- PROJECTILE DEBUGGING:
    if (projectile_debug_mode) then
        TIMER = TIMER + 1 / 30
        if (TIMER >= DELAY) then
            TIMER = 0
            InitiateStrike(_, _, MiddleX, MiddleY, MiddleZ, MiddleHeight)
        end
    end

    local t = airstrike.objects
    if (not game_over) and (t) then

        if (#t > 0) then
            for i = 1, #t do
                if (t[i] ~= nil) then
                    local projectile_memory = get_object_memory(t[i])
                    if (projectile_memory == 0) then
                        t[i] = nil
                    end
                end
            end
        end
    end
end

function OnDamageApplication(_, CauserIndex, MetaID, Damage, _, _)
    if (not game_over) and (CauserIndex == 0) then
        local t = airstrike.maps[map_name].dmg
        if (MetaID == TagInfo(t[1], t[2])) then
            return Damage * 10
        end
    end
end

function OnPlayerConnect(PlayerIndex)
    InitPlayer(PlayerIndex, false)
end

function OnPlayerSpawn(PlayerIndex)
    -- Reset victim kill count:
    players[PlayerIndex].kills = 0
end

function OnPlayerDisconnect(PlayerIndex)
    InitPlayer(PlayerIndex, true)
end

function OnGameStart()
    game_over = false
    if (get_var(0, "$gt") ~= "n/a") then
        map_name = get_var(0, "$map")
        airstrike.messages.periodic_broadcast.timer = 0
    end
end

function OnGameEnd()
    game_over = true
end

function OnPlayerDeath(VictimIndex, KillerIndex)

    if (not game_over) then
        local killer, victim = tonumber(KillerIndex), tonumber(VictimIndex)
        if (killer > 0) and (killer ~= victim) then

            players[killer].kills = players[killer].kills + 1

            if HasRequiredKills(killer) then
                cls(killer, 25)
                local m = airstrike.messages.on_kill[players[killer].mode]
                for i = 1, #m do
                    local msg = gsub(gsub(m[i], "%%cmd%%", airstrike.base_command), "%%pl_cmd%%", airstrike.player_list_command)
                    Send(killer, msg, "rcon")
                end
            end
        end
    end
end

function HasRequiredKills(PlayerIndex)
    local t = players[PlayerIndex].mode
    local kills_required = airstrike.maps[map_name].modes[t].kills_required
    return players[PlayerIndex].kills >= kills_required
end

function IsTeamGame()
    if (get_var(0, "$ffa") == "0") then
        return true
    end
end

function InitPlayer(PlayerIndex, Reset)
    if (Reset) then
        players[PlayerIndex] = {}
    else
        players[PlayerIndex] = {
            name = get_var(PlayerIndex, "$name"),
            mode = airstrike.maps[map_name].default_mode
        }
    end
end

function InitiateStrike(Killer, Victim, x, y, z, height)

    local params = airstrike.maps[map_name]

    -- todo: Calculate rocket spread based on min/max projectile quantities

    local min_x_vel = 0
    local max_x_vel = 0

    local min_y_vel = 0
    local max_y_vel = 0

    local min_z_vel = -1
    local max_z_vel = -1

    local projectile_object = params.projectile
    local object = TagInfo(projectile_object[1], projectile_object[2])
    if (object) then

        players[Killer].kills = 0

        for _ = params.min_projectiles, params.max_projectiles do

            local payload = spawn_object(projectile_object[1], projectile_object[2], x, y, z + height)
            local projectile = get_object_memory(payload)
            if (projectile ~= 0) then

                math.randomseed(os.clock())
                local projectile_x_vel = math.random(min_x_vel, max_x_vel)
                local projectile_y_vel = math.random(min_y_vel, max_y_vel)
                local projectile_z_vel = math.random(min_z_vel, max_z_vel)

                write_float(projectile + 0x68, projectile_x_vel)
                write_float(projectile + 0x6C, projectile_y_vel)
                write_float(projectile + 0x70, projectile_z_vel)

                airstrike.objects = airstrike.objects or {}
                airstrike.objects[#airstrike.objects + 1] = payload
            end
        end

        local msg = airstrike.messages.on_airstrike_call
        local Feedback = msg.killer_feedback
        for i = 1, #Feedback do
            Send(Killer, Feedback[i], "rcon")
        end

        local mode = players[Killer].mode
        for i = 1, 16 do
            if player_present(i) and (tonumber(i) ~= Killer) then
                Victim = Victim or 0
                local victim_name = get_var(Victim, "$name")
                local team = GetOpposingTeam(Killer)
                for j = 1, #msg.broadcast[mode] do
                    local Msg = gsub(gsub(gsub(msg.broadcast[mode][j],
                            "%%killer%%", players[Killer].name),
                            "%%victim%%", victim_name),
                            "%%opposing_team%%", team)
                    Send(i, Msg, "chat")
                end
            end
        end
    else
        Send(Killer, airstrike.messages.strike_failed, "rcon")
    end
end

function OnServerCommand(Killer, Command, _, _)

    local Cmd = CmdSplit(Command)
    if (#Cmd == 0) then
        return false
    else
        Cmd[1] = lower(Cmd[1]) or upper(Cmd[1])
        if (Cmd[1] == airstrike.base_command) then
            if (not game_over) then
                if (Killer ~= 0) then
                    for player, v in pairs(players) do

                        if (player == Killer) then

                            cls(Killer, 25)
                            local args1, args2 = Cmd[2], Cmd[3]

                            -- MODE INFO COMMAND:
                            if (args1 ~= nil) then
                                if (tostring(args1) == airstrike.info_command) then

                                    local t = airstrike.messages.info
                                    for i = 1, #t do
                                        local msg = gsub(gsub(gsub(t[i],
                                                "%%cmd%%", airstrike.base_command),
                                                "%%mode_cmd%%", airstrike.mode_command),
                                                "%%pl_cmd%%", airstrike.player_list_command)
                                        Send(Killer, msg, "rcon")
                                    end

                                    -- MODE SELECT COMMAND:
                                elseif (tostring(args1) == airstrike.mode_command) then
                                    local mode = tonumber(args2)
                                    if (mode ~= nil) then

                                        local old_mode = v.mode

                                        if (mode == 1) then
                                            v.mode = "Mode A"
                                        elseif (mode == 2) then
                                            v.mode = "Mode B"
                                        elseif (mode == 3) then
                                            v.mode = "Mode C"
                                        else
                                            mode = nil
                                        end

                                        local enabled, msg = airstrike.maps[map_name].modes[v.mode].enabled, ""
                                        if (mode) and (not enabled) then
                                            v.mode = old_mode
                                            msg = gsub(airstrike.messages.mode_not_enabled, "%%mode%%", mode)
                                        elseif (mode) and (enabled) then
                                            msg = gsub(airstrike.messages.mode_select, "%%mode%%", mode)
                                        end
                                        Send(Killer, msg, "rcon")
                                    end

                                    if (mode == nil) then
                                        local t = airstrike.messages.mode_invalid_syntax
                                        local msg = gsub(gsub(t, "%%cmd%%", airstrike.base_command), "%%mode_cmd%%", airstrike.mode_command)
                                        Send(Killer, msg, "rcon")
                                    end

                                    -- CUSTOM PLAYER LIST COMMAND
                                elseif (tostring(args1) == airstrike.player_list_command) then

                                    local pl = GetPlayers(Killer)
                                    if (#pl > 0) then
                                        local t = airstrike.messages.player_list_cmd_feedback
                                        Send(Killer, t.header, "rcon")
                                        for i = 1, #pl do
                                            local msg = gsub(gsub(t.player_info, "%%id%%", pl[i].id), "%%name%%", pl[i].name)
                                            Send(Killer, msg, "rcon")
                                        end
                                    else
                                        --Send(Killer, t.offline, "rcon")
                                    end

                                    -- AIRSTRIKE COMMAND MODE A
                                elseif (tonumber(args1) ~= nil) and (tonumber(args1) > 0 and tonumber(args1) < 17) then
                                    if IsCorrectMode(Killer, "Mode A") then
                                        args1 = tonumber(args1)
                                        if (args1 ~= Killer) then
                                            local valid_player = player_present(args1) and player_alive(args1)
                                            if (valid_player) then
                                                if HasRequiredKills(Killer) then
                                                    local DynamicPlayer = get_dynamic_player(args1)
                                                    if (DynamicPlayer ~= 0) then
                                                        local player = GetXYZ(DynamicPlayer)
                                                        if (player) then
                                                            local height = airstrike.maps[map_name].modes["Mode A"].height_from_ground
                                                            InitiateStrike(Killer, args1, player.x, player.y, player.z, height)
                                                        end
                                                    end
                                                else
                                                    Send(Killer, airstrike.messages.not_enough_kills, "rcon")
                                                end
                                            else
                                                Send(Killer, airstrike.messages.player_offline_or_dead, "rcon")
                                            end
                                        else
                                            Send(Killer, airstrike.messages.cannot_strike_self, "rcon")
                                        end
                                    end
                                else
                                    Send(Killer, airstrike.messages.invalid_player_id, "rcon")
                                end
                                -- AIRSTRIKE COMMAND MODE B
                            elseif (v.mode == "Mode B") then
                                if IsTeamGame(Killer) then
                                    if HasRequiredKills(Killer) then

                                        local team = GetOpposingTeam(Killer)
                                        local t = airstrike.maps[map_name].modes[v.mode].strike_locations[team]
                                        math.randomseed(os.clock())
                                        local coordinates = math.random(#t)
                                        local C = t[coordinates]
                                        local x, y, z, height = C[1], C[2], C[3], C[4]
                                        InitiateStrike(Killer, _, x, y, z, height)

                                    else
                                        Send(Killer, airstrike.messages.not_enough_kills, "rcon")
                                    end
                                else
                                    Send(Killer, airstrike.messages.team_play_incompatible, "rcon")
                                end
                                -- AIRSTRIKE COMMAND MODE C
                            elseif (v.mode == "Mode C") then
                                if HasRequiredKills(Killer) then
                                    local t = airstrike.maps[map_name].modes[v.mode].strike_locations
                                    math.randomseed(os.clock())
                                    local coordinates = math.random(#t)
                                    local C = t[coordinates]
                                    local x, y, z, height = C[1], C[2], C[3], C[4]
                                    InitiateStrike(Killer, _, x, y, z, height)
                                else
                                    Send(Killer, airstrike.messages.not_enough_kills, "rcon")
                                end
                            end
                        end
                    end
                else
                    cprint(airstrike.messages.console_error, 4 + 8)
                end
            else
                Send(Killer, airstrike.messages.game_over, "rcon")
            end
            return false
        end
    end
end

function GetXYZ(DynamicPlayer)
    local coordinates, x, y, z = {}
    local VehicleID = read_dword(DynamicPlayer + 0x11C)
    if (VehicleID == 0xFFFFFFFF) then
        coordinates.invehicle = false
        x, y, z = read_vector3d(DynamicPlayer + 0x5c)
    else
        coordinates.invehicle = true
        x, y, z = read_vector3d(get_object_memory(VehicleID) + 0x5c)
    end
    coordinates.x, coordinates.y, coordinates.z = x, y, z
    return coordinates
end

function CmdSplit(Command)
    local t, i = {}, 1
    for Args in gmatch(Command, "([^%s]+)") do
        t[i] = Args
        i = i + 1
    end
    return t
end

function GetPlayers(ExcludePlayer)
    local pl = {}
    for i = 1, 16 do
        if player_present(i) then
            if (i ~= ExcludePlayer) then
                pl[#pl + 1] = { id = i, name = players[i].name }
            end
        end
    end
    return pl
end

function Send(PlayerIndex, Message, Environment)

    local responseFunction = say
    if (Environment == "rcon") then
        responseFunction = rprint
    end

    execute_command("msg_prefix \"\"")
    if (type(Message) ~= "table") then
        responseFunction(PlayerIndex, Message)
    else
        for j = 1, #Message do
            responseFunction(PlayerIndex, Message[j])
        end
    end
    execute_command("msg_prefix \" " .. airstrike.server_prefix .. "\"")
end

function TagInfo(Type, Name)
    local tag_id = lookup_tag(Type, Name)
    return tag_id ~= 0 and read_dword(tag_id + 0xC) or nil
end

function GetOpposingTeam(PlayerIndex)
    local team = get_var(PlayerIndex, "$team")
    if (team == "red") then
        return "blue"
    elseif (team == "blue") then
        return "red"
    end
end

function IsCorrectMode(Killer, Mode)
    local CurrentMode = players[Killer].mode

    if (CurrentMode == Mode) then
        return true
    else
        local t = airstrike.messages.incorrect_mode
        for i = 1, #t do
            local msg = gsub(gsub(t[i], "%%cmd%%", airstrike.base_command), "%%mode_cmd%%", airstrike.mode_command)
            Send(Killer, msg, "rcon")
        end
    end
end

function mapIsEnabled()
    local map = airstrike.maps["bloodgulch"]
    if (map ~= nil) and (map.enabled) then
        return true
    end
    return false
end

function cls(PlayerIndex, Count)
    for _ = 1, Count do
        Send(PlayerIndex, " ", "rcon")
    end
end

function OnScriptUnload()

end
