--[[
=====================================================================================
SCRIPT NAME:      snipers_dream_team.lua
DESCRIPTION:      Comprehensive weapon/vehicle overhaul.

FEATURES:
                - Overhauls 20+ weapons and vehicle armaments
                - Enhanced projectile physics and damage profiles
                - Custom explosion effects and impact behaviors
                - Weapon-specific modifications (AR, Pistol, Sniper, etc.)
                - Vehicle weapon upgrades (Warthog, Scorpion, Banshee, etc.)
                - Grenade behavior modifications
                - Global gameplay tweaks

MODIFICATIONS INCLUDE:
                - Assault Rifle bullet physics
                - Pistol damage and melee enhancements
                - Warthog chain gun upgrades
                - Scorpion tank shell behavior
                - Ghost plasma bolts
                - Rocket Launcher projectiles
                - Banshee fuel rod cannon
                - Plasma Rifle charged shots
                - Frag/Plasma grenade effects
                - Sniper Rifle ballistic overhaul

TECHNICAL NOTES:
                - Direct memory modification of game tags
                - No external dependencies required
                - Compatible with most game modes and all stock maps
                - Preserves original gameplay balance

WARNING: This mod significantly alters core gameplay mechanics.
         Not recommended for competitive play.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local shell_explosion, rocket_explosion
local shell_explosion_jpt = { 'jpt!', 'vehicles\\scorpion\\shell explosion' }
local rocket_explosion_jpt = { 'jpt!', 'weapons\\rocket launcher\\explosion' }

local function getTagID(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function inVehicle(playerId)
    local dyn_player = get_dynamic_player(playerId)
    if dyn_player == 0 then return false end
    return read_dword(dyn_player + 0x11C) ~= 0xFFFFFFFF
end

local function swap(address, toTag, toClass, tagAddress, tagCount)
    for i = 0, tagCount - 1 do
        local tag = tagAddress + 0x20 * i
        if read_dword(tag) == toClass and read_string(read_dword(tag + 0x10)) == toTag then
            write_dword(address, read_dword(tag + 0xC))
            return
        end
    end
end

local function modifyTags()
    local tag_address = read_dword(0x40440000)
    local tag_count = read_dword(0x4044000C)
    local modifications = {
        {
            class = 1785754657,
            name = 'weapons\\assault rifle\\bullet',
            offsets = { [0x1d0] = 1133936640, [0x1d4] = 1137213440, [0x1d8] = 1140490240, [0x1f4] = 1075838976 }
        },
        {
            class = 2003132784,
            name = 'weapons\\pistol\\pistol',
            offsets = {
                [0x308] = 32,
                [0x3e0] = 1082130432,
                [0x71c] = 34340864,
                [0x720] = 1573114,
                [0x730] = 24,
                [0x7a8] = 1103626240,
                [0x7ac] = 1103626240,
                [0x7c4] = 0,
                [0x820] = 841731191,
                [0x824] = 869711765
            }
        },
        {
            class = 1785754657,
            name = 'weapons\\pistol\\melee',
            offsets = { [0x1d0] = 1148846080, [0x1d4] = 1148846080, [0x1d8] = 1148846080 }
        },
        {
            class = 1886547818,
            name = 'weapons\\pistol\\bullet',
            offsets = { [0x1c8] = 1148846080, [0x1e4] = 1097859072, [0x1e8] = 1097859072 }
        },
        {
            class = 1785754657,
            name = 'weapons\\pistol\\bullet',
            offsets = {
                [0x1d0] = 1133903872,
                [0x1d4] = 1133903872,
                [0x1d8] = 1133903872,
                [0x1e4] = 1065353216,
                [0x1ec] = 1041865114,
                [0x1f4] = 1073741824
            }
        },
        {
            class = 2003132784,
            name = 'vehicles\\warthog\\warthog gun',
            callback = function(tag_data)
                write_dword(tag_data + 0x928, 1078307906)
                swap(tag_data + 0x930, 'vehicles\\scorpion\\tank shell', 1886547818, tag_address, tag_count)
            end
        },
        {
            class = 1886547818,
            name = 'vehicles\\scorpion\\tank shell',
            offsets = { [0x1e4] = 1114636288, [0x1e8] = 1114636288 }
        },
        {
            class = 1785754657,
            name = 'vehicles\\scorpion\\shell explosion',
            offsets = {
                [0x0] = 1073741824,
                [0x4] = 1081081856,
                [0xcc] = 1061158912,
                [0xd4] = 1011562294,
                [0x1d0] = 1131413504,
                [0x1f4] = 1092091904
            }
        },
        {
            class = 1785754657,
            name = 'weapons\\frag grenade\\shock wave',
            offsets = { [0xd4] = 1048576000, [0xd8] = 1022739087 }
        },
        {
            class = 2003132784,
            name = 'vehicles\\ghost\\mp_ghost gun',
            offsets = { [0x6dc] = 1638400 }
        },
        {
            class = 1886547818,
            name = 'vehicles\\ghost\\ghost bolt',
            offsets = { [0x1c8] = 1140457472, [0x1ec] = 1056964608 }
        },
        {
            class = 1785754657,
            name = 'vehicles\\ghost\\ghost bolt',
            offsets = { [0x1d4] = 1103626240, [0x1d8] = 1108082688, [0x1f4] = 1073741824 }
        },
        {
            class = 2003132784,
            name = 'vehicles\\rwarthog\\rwarthog_gun',
            offsets = {
                [0x64c] = 655294464,
                [0x650] = 1320719,
                [0x660] = 20,
                [0x6c0] = 993039,
                [0x6d0] = 15,
                [0x794] = 131072
            }
        },
        {
            class = 1886547818,
            name = 'weapons\\rocket launcher\\rocket',
            offsets = { [0x1c8] = 1148846080 }
        },
        {
            class = 1785754657,
            name = 'weapons\\rocket launcher\\explosion',
            offsets = {
                [0x0] = 1077936128,
                [0x4] = 1080033280,
                [0xcc] = 1061158912,
                [0xd4] = 1011562294,
                [0x1d0] = 1120403456,
                [0x1d4] = 1137180672,
                [0x1d8] = 1137180672,
                [0x1f4] = 1094713344
            }
        },
        {
            class = 2003132784,
            name = 'vehicles\\banshee\\mp_banshee gun',
            callback = function(tag_data)
                write_dword(tag_data + 0x5cc, 8224)
                write_dword(tag_data + 0x5ec, 65536)
                write_dword(tag_data + 0x604, 655294464)
                write_dword(tag_data + 0x608, 141071)
                write_dword(tag_data + 0x618, 2)
                write_dword(tag_data + 0x638, 196608)
                write_dword(tag_data + 0x64c, 0)
                write_dword(tag_data + 0x678, 665359)
                write_dword(tag_data + 0x688, 10)
                write_dword(tag_data + 0x74c, 196608)
                write_dword(tag_data + 0x860, 196608)
                write_dword(tag_data + 0x88c, 1078314612)
                swap(tag_data + 0x894, 'weapons\\rocket launcher\\rocket', 1886547818, tag_address, tag_count)
            end
        },
        {
            class = 1886547818,
            name = 'vehicles\\banshee\\banshee bolt',
            offsets = { [0x1c8] = 1148846080, [0x1ec] = 1056964608 }
        },
        {
            class = 1785754657,
            name = 'vehicles\\banshee\\banshee bolt',
            offsets = {
                [0x0] = 1082130432,
                [0x4] = 1084227584,
                [0x1d0] = 1125515264,
                [0x1d4] = 1125515264,
                [0x1d8] = 1125515264,
                [0x1f4] = 1069547520
            }
        },
        {
            class = 1886547818,
            name = 'vehicles\\banshee\\mp_banshee fuel rod',
            offsets = { [0x1c8] = 1148846080, [0x1cc] = 0, [0x1e4] = 1053609165, [0x1e8] = 1051372091 }
        },
        {
            class = 2003132784,
            name = 'weapons\\shotgun\\shotgun',
            offsets = { [0x3e8] = 1120403456, [0x3f0] = 1120403456, [0xaf0] = 1638400 }
        },
        {
            class = 1886547818,
            name = 'weapons\\shotgun\\pellet',
            offsets = { [0x1c8] = 1148846080, [0x1d4] = 1112014848 }
        },
        {
            class = 1785754657,
            name = 'weapons\\shotgun\\pellet',
            offsets = {
                [0x1d0] = 1137213440,
                [0x1d4] = 1140490240,
                [0x1d8] = 1142308864,
                [0x1f4] = 1077936128
            }
        },
        {
            class = 2003132784,
            name = 'weapons\\plasma rifle\\plasma rifle',
            offsets = { [0x3e8] = 1140457472, [0x3f0] = 1140457472, [0xd10] = 327680 }
        },
        {
            class = 1785754657,
            name = 'weapons\\plasma rifle\\bolt',
            offsets = { [0x1d4] = 1097859072, [0x1d8] = 1103626240, [0x1f4] = 1065353216 }
        },
        {
            class = 1785754657,
            name = 'weapons\\frag grenade\\explosion',
            offsets = {
                [0x0] = 1073741824,
                [0x4] = 1083703296,
                [0xcc] = 1061158912,
                [0xd4] = 1011562294,
                [0x1d0] = 1131413504,
                [0x1d4] = 1135575040,
                [0x1d8] = 1135575040,
                [0x1f4] = 1092091904
            }
        },
        {
            class = 1785754657,
            name = 'weapons\\rocket launcher\\melee',
            offsets = { [0x1d0] = 1148846080, [0x1d4] = 1148846080, [0x1d8] = 1148846080 }
        },
        {
            class = 1785754657,
            name = 'weapons\\rocket launcher\\trigger',
            offsets = { [0xcc] = 1061158912, [0xd4] = 1008981770, [0xd8] = 1017370378 }
        },
        {
            class = 2003132784,
            name = 'weapons\\sniper rifle\\sniper rifle',
            callback = function(tag_data)
                write_dword(tag_data + 0x3e8, 1128792064)
                write_dword(tag_data + 0x3f0, 1128792064)
                write_dword(tag_data + 0x894, 7340032)
                write_dword(tag_data + 0x898, 786532)
                write_dword(tag_data + 0x8a8, 12)
                write_dword(tag_data + 0x920, 1075838976)
                write_dword(tag_data + 0x924, 1075838976)
                write_dword(tag_data + 0x9b4, 1078307906)
                swap(tag_data + 0x9bc, 'vehicles\\scorpion\\tank shell', 1886547818, tag_address, tag_count)
            end
        },
        {
            class = 1785754657,
            name = 'weapons\\sniper rifle\\melee',
            offsets = {
                [0xcc] = 1061158912,
                [0xd4] = 1011562294,
                [0x1d0] = 1148846080,
                [0x1d4] = 1148846080,
                [0x1d8] = 1148846080
            }
        },
        {
            class = 1886547818,
            name = 'weapons\\sniper rifle\\sniper bullet',
            callback = function(tag_data)
                write_dword(tag_data + 0x144, 1081053092)
                write_dword(tag_data + 0x180, 0)
                write_dword(tag_data + 0x1b0, 1078308047)
                swap(tag_data + 0x1b8, 'vehicles\\scorpion\\shell explosion', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x1e4, 1114636288)
                write_dword(tag_data + 0x1e8, 1114636288)
                write_dword(tag_data + 0x1f0, 2)
                write_dword(tag_data + 0x208, 1078308640)
                swap(tag_data + 0x210, 'sound\\sfx\\impulse\\impacts\\scorpion_projectile', 1936614433, tag_address,
                    tag_count)
                write_dword(tag_data + 0x228, 0)
                write_dword(tag_data + 0x230, 4294967295)
                write_dword(tag_data + 0x244, 1081053164)
                write_dword(tag_data + 0x250, 1078307935)
                swap(tag_data + 0x258, 'vehicles\\scorpion\\shell', 1668247156, tag_address, tag_count)
                write_dword(tag_data + 0x294, 65536)
                write_dword(tag_data + 0x29c, 0)
                write_dword(tag_data + 0x2a4, 4294967295)
                write_dword(tag_data + 0x300, 1078308686)
                swap(tag_data + 0x308, 'vehicles\\scorpion\\shell impact dirt', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x334, 65536)
                write_dword(tag_data + 0x33c, 0)
                write_dword(tag_data + 0x344, 4294967295)
                write_dword(tag_data + 0x3d4, 65536)
                write_dword(tag_data + 0x3dc, 0)
                write_dword(tag_data + 0x3e4, 4294967295)
                write_dword(tag_data + 0x440, 1078308835)
                swap(tag_data + 0x448, 'vehicles\\wraith\\effects\\impact stone', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x474, 65536)
                write_dword(tag_data + 0x47c, 0)
                write_dword(tag_data + 0x484, 4294967295)
                write_dword(tag_data + 0x4e0, 1078309337)
                swap(tag_data + 0x4e8, 'vehicles\\wraith\\effects\\impact snow', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x514, 65536)
                write_dword(tag_data + 0x51c, 0)
                write_dword(tag_data + 0x524, 4294967295)
                write_dword(tag_data + 0x580, 1078309578)
                swap(tag_data + 0x588, 'vehicles\\wraith\\effects\\impact wood', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x5b4, 65536)
                write_dword(tag_data + 0x5bc, 0)
                write_dword(tag_data + 0x5c4, 4294967295)
                write_dword(tag_data + 0x620, 1078309614)
                swap(tag_data + 0x628, 'weapons\\rocket launcher\\effects\\impact metal', 1701209701, tag_address,
                    tag_count)
                write_dword(tag_data + 0x654, 65536)
                write_dword(tag_data + 0x65c, 0)
                write_dword(tag_data + 0x664, 4294967295)
                write_dword(tag_data + 0x6c0, 1078309614)
                swap(tag_data + 0x6c8, 'weapons\\rocket launcher\\effects\\impact metal', 1701209701, tag_address,
                    tag_count)
                write_dword(tag_data + 0x6f4, 65536)
                write_dword(tag_data + 0x6fc, 0)
                write_dword(tag_data + 0x704, 4294967295)
                write_dword(tag_data + 0x760, 1078309614)
                swap(tag_data + 0x768, 'weapons\\rocket launcher\\effects\\impact metal', 1701209701, tag_address,
                    tag_count)
                write_dword(tag_data + 0x794, 65536)
                write_dword(tag_data + 0x79c, 0)
                write_dword(tag_data + 0x7a4, 4294967295)
                write_dword(tag_data + 0x800, 1078309614)
                swap(tag_data + 0x808, 'weapons\\rocket launcher\\effects\\impact metal', 1701209701, tag_address,
                    tag_count)
                write_dword(tag_data + 0x834, 65536)
                write_dword(tag_data + 0x83c, 0)
                write_dword(tag_data + 0x844, 4294967295)
                write_dword(tag_data + 0x8a0, 1078309659)
                swap(tag_data + 0x8a8, 'vehicles\\wraith\\effects\\impact ice', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x8d4, 65536)
                write_dword(tag_data + 0x8dc, 0)
                write_dword(tag_data + 0x8e4, 4294967295)
                write_dword(tag_data + 0x974, 65536)
                write_dword(tag_data + 0x97c, 0)
                write_dword(tag_data + 0x984, 4294967295)
                write_dword(tag_data + 0xa14, 65536)
                write_dword(tag_data + 0xa1c, 0)
                write_dword(tag_data + 0xa24, 4294967295)
                write_dword(tag_data + 0xab4, 65536)
                write_dword(tag_data + 0xabc, 0)
                write_dword(tag_data + 0xac4, 4294967295)
                write_dword(tag_data + 0xb54, 65536)
                write_dword(tag_data + 0xb5c, 0)
                write_dword(tag_data + 0xb64, 4294967295)
                write_dword(tag_data + 0xbf4, 65536)
                write_dword(tag_data + 0xbfc, 0)
                write_dword(tag_data + 0xc04, 4294967295)
                write_dword(tag_data + 0xc94, 65536)
                write_dword(tag_data + 0xc9c, 0)
                write_dword(tag_data + 0xca4, 4294967295)
                write_dword(tag_data + 0xd34, 65536)
                write_dword(tag_data + 0xd3c, 0)
                write_dword(tag_data + 0xd44, 4294967295)
                write_dword(tag_data + 0xdd4, 65536)
                write_dword(tag_data + 0xddc, 0)
                write_dword(tag_data + 0xde4, 4294967295)
                write_dword(tag_data + 0xe74, 65536)
                write_dword(tag_data + 0xe7c, 0)
                write_dword(tag_data + 0xe84, 4294967295)
                write_dword(tag_data + 0xf14, 65536)
                write_dword(tag_data + 0xf1c, 0)
                write_dword(tag_data + 0xf24, 4294967295)
                write_dword(tag_data + 0xfb4, 65536)
                write_dword(tag_data + 0xfbc, 0)
                write_dword(tag_data + 0xfc4, 4294967295)
                write_dword(tag_data + 0x1054, 65536)
                write_dword(tag_data + 0x105c, 0)
                write_dword(tag_data + 0x1064, 4294967295)
                write_dword(tag_data + 0x10f4, 65536)
                write_dword(tag_data + 0x10fc, 0)
                write_dword(tag_data + 0x1104, 4294967295)
                write_dword(tag_data + 0x1194, 65536)
                write_dword(tag_data + 0x119c, 0)
                write_dword(tag_data + 0x11a4, 4294967295)
                write_dword(tag_data + 0x1234, 65536)
                write_dword(tag_data + 0x123c, 0)
                write_dword(tag_data + 0x1244, 4294967295)
                write_dword(tag_data + 0x12d4, 65536)
                write_dword(tag_data + 0x12dc, 0)
                write_dword(tag_data + 0x12e4, 4294967295)
                write_dword(tag_data + 0x1374, 65536)
                write_dword(tag_data + 0x137c, 0)
                write_dword(tag_data + 0x1384, 4294967295)
                write_dword(tag_data + 0x1414, 65536)
                write_dword(tag_data + 0x141c, 0)
                write_dword(tag_data + 0x1424, 4294967295)
                write_dword(tag_data + 0x1480, 1078309694)
                swap(tag_data + 0x1488, 'weapons\\rocket launcher\\effects\\impact water', 1701209701, tag_address,
                    tag_count)
                write_dword(tag_data + 0x14b4, 65536)
                write_dword(tag_data + 0x14bc, 0)
                write_dword(tag_data + 0x14c4, 4294967295)
                write_dword(tag_data + 0x1520, 1078309777)
                swap(tag_data + 0x1528, 'weapons\\frag grenade\\effects\\impact water pen', 1701209701, tag_address,
                    tag_count)
                write_dword(tag_data + 0x1554, 65536)
                write_dword(tag_data + 0x155c, 0)
                write_dword(tag_data + 0x1564, 4294967295)
                write_dword(tag_data + 0x15f4, 65536)
                write_dword(tag_data + 0x15fc, 0)
                write_dword(tag_data + 0x1604, 4294967295)
                write_dword(tag_data + 0x1660, 1078309659)
                swap(tag_data + 0x1668, 'vehicles\\wraith\\effects\\impact ice', 1701209701, tag_address, tag_count)
                write_dword(tag_data + 0x1694, 65536)
                write_dword(tag_data + 0x169c, 0)
                write_dword(tag_data + 0x16a4, 4294967295)
            end
        },
        {
            class = 1785754657,
            name = 'weapons\\plasma grenade\\explosion',
            offsets = {
                [0x4] = 1086324736,
                [0x1d0] = 1140457472,
                [0x1d4] = 1140457472,
                [0x1d8] = 1140457472,
                [0x1f4] = 1094713344
            }
        },
        {
            class = 2003132784,
            name = 'weapons\\plasma_cannon\\plasma_cannon',
            offsets = { [0x92c] = 196608 }
        },
        {
            class = 1886547818,
            name = 'weapons\\plasma_cannon\\plasma_cannon',
            callback = function(tag_data)
                write_dword(tag_data + 0x1b0, 1078308047)
                swap(tag_data + 0x1b8, 'vehicles\\scorpion\\shell explosion', 1701209701, tag_address, tag_count)
            end
        },
        {
            class = 1785754657,
            name = 'weapons\\plasma_cannon\\effects\\plasma_cannon_explosion',
            offsets = {
                [0x1d0] = 1142308864,
                [0x1d4] = 1142308864,
                [0x1d8] = 1142308864,
                [0x1f4] = 1083179008
            }
        },
        {
            class = 1785754657,
            name = 'weapons\\plasma_cannon\\impact damage',
            offsets = {
                [0x1d0] = 1142308864,
                [0x1d4] = 1142308864,
                [0x1d8] = 1142308864,
                [0x1f4] = 1083179008
            }
        },
        {
            class = 1785754657,
            name = 'weapons\\plasma rifle\\charged bolt',
            offsets = {
                [0x0] = 1084227584,
                [0x4] = 1090519040,
                [0xcc] = 1065353216,
                [0xd4] = 1017370378,
                [0x1d0] = 1140457472,
                [0x1d4] = 1140457472,
                [0x1d8] = 1140457472,
                [0x1f4] = 1097859072
            }
        },
        {
            class = 1886547818,
            name = 'weapons\\frag grenade\\frag grenade',
            offsets = {
                [0x1bc] = 1050253722,
                [0x1c0] = 1050253722,
                [0x1cc] = 1057803469,
                [0x1ec] = 1065353216
            }
        },
        {
            class = 1886547818,
            name = 'weapons\\plasma grenade\\plasma grenade',
            offsets = {
                [0x1bc] = 1065353216,
                [0x1c0] = 1065353216,
                [0x1cc] = 1056964608,
                [0x1ec] = 1077936128
            }
        },
        {
            class = 1785754657,
            name = 'weapons\\plasma grenade\\attached',
            offsets = {
                [0x1d0] = 1137180672,
                [0x1d4] = 1137180672,
                [0x1d8] = 1137180672,
                [0x1f4] = 1092616192
            }
        },
        {
            class = 1986357353,
            name = 'vehicles\\c gun turret\\c gun turret_mp',
            offsets = { [0x8c] = 4294967295, [0x9c0] = 973078558 }
        },
        {
            class = 2003132784,
            name = 'vehicles\\c gun turret\\mp gun turret gun',
            offsets = { [0x8b4] = 3276800 }
        },
        {
            class = 1785754657,
            name = 'globals\\falling',
            offsets = { [0x1d4] = 1092616192, [0x1d8] = 1092616192 }
        }
    }

    for i = 0, tag_count - 1 do
        local tag = tag_address + 0x20 * i
        local tag_class = read_dword(tag)
        local tag_name_ptr = read_dword(tag + 0x10)
        local tag_name = tag_name_ptr ~= 0 and read_string(tag_name_ptr) or ""
        local tag_data = read_dword(tag + 0x14)

        for _, mod in ipairs(modifications) do
            if tag_class == mod.class and tag_name == mod.name then
                if mod.callback then
                    mod.callback(tag_data)
                else
                    for offset, value in pairs(mod.offsets) do
                        write_dword(tag_data + offset, value)
                    end
                end
                break
            end
        end
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], "OnDamage")
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    shell_explosion = getTagID(shell_explosion_jpt[1], shell_explosion_jpt[2])
    rocket_explosion = getTagID(rocket_explosion_jpt[1], rocket_explosion_jpt[2])
    if shell_explosion and rocket_explosion then
        modifyTags()
    end
end

function OnDamage(playerIndex, causer, metaId)
    playerIndex = tonumber(playerIndex)
    causer = tonumber(causer)

    if playerIndex == causer and (metaId == shell_explosion or (metaId == rocket_explosion and inVehicle(causer))) then
        return false  -- block this damage
    end
end

function OnScriptUnload() end
