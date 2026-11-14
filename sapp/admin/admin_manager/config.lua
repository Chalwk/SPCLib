-- ============================================================================
-- Edit this file, then reload the script.
--
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================
return {
    -- Console runs at this level. The console bypasses most permission checks anyway.
    console_default_level = 6,

    -- Min and max length for user-chosen passwords.
    password_length_limit = { 8, 32 },

    -- Seconds before a pending /confirm action times out.
    confirmation_timeout = 10,

    -- Fallback ban duration when no duration flags are given. All zeros = permanent.
    default_ban_duration = { y = 0, mo = 0, d = 0, h = 0, m = 0, s = 0 },

    -- Database filenames. All live in the instance's sapp folder (<instance>\sapp\).
    files = {
        admins = 'admins.txt',
        commands = 'commands.txt',
        bans = 'bans.txt',
        logs = 'logs.txt',
        aliases = 'aliases.txt'
    },

    -- SAPP custom variable used to expose a player's level to other scripts.
    custom_level_var = 'admin_level',

    -- management: admin actions and permission failures.
    -- default: every other command and its result.
    logging = { management = true, default = true },

    -- Join messages per level: { format string (%s = name), show to everyone? }.
    -- Disable the whole thing with enabled = false.
    admin_join_messages = {
        enabled = true,
        [1] = { '[PUBLIC] %s joined the server.', false },
        [2] = { '[ADMIN] %s just showed up. Hold my beer!', true },
        [3] = { '[MOD] %s just joined. Hide your bananas!', true },
        [4] = { '[VIP] %s joined the server. Sexy is as sexy does.', true },
        [5] = { '[PRO] %s joined the server. Pro noob.', true },
        [6] = { '[OWNER] %s joined the server. Everybody hide!', true }
    },

    -- Which levels may use command spy / admin chat. true = allowed.
    command_spy = { [1] = false, [2] = false, [3] = true, [4] = true, [5] = true, [6] = true },
    admin_chat = { [1] = false, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true },

    -- Security: the console is always exempt from both rules.
    -- true = nobody can ban/mute/kick/modify someone of equal or higher level.
    protect_higher_levels = true,
    -- false = nobody can grant a level above their own (e.g. a level 5 creating an owner).
    allow_level_escalation = false,

    -- Session key used for password-admin logins. 1 = raw $ip (ip:port), 2 = ip only.
    cache_session_index = 1,

    -- Hours a password-admin stays logged in before the session expires.
    login_timeout = 24,

    -- Default level for each command this script provides (level -> names).
    -- Real permissions live in commands.txt; this only seeds missing entries.
    management_commands = {
        [1] = { 'login', 'logout', 'my_level', 'admins_online' },
        [2] = { 'admin_chat', 'change_password' },
        [3] = {
            'command_spy',
            'ip_mute',
            'ip_mutes',
            'ip_unmute',
            'hash_mute',
            'hash_mutes',
            'hash_unmute'
        },
        [4] = { 'alias_ip', 'alias_hash', 'ip_ban', 'ip_bans', 'ip_unban' },
        [5] = {
            'confirm',
            'hash_admin_add',
            'hash_admin_delete',
            'hash_admins',
            'hash_ban',
            'hash_bans',
            'hash_unban',
            'ip_admin_add',
            'ip_admin_delete',
            'ip_admins',
            'name_ban',
            'name_bans',
            'name_unban',
            'pw_admin_add',
            'pw_admin_delete',
            'pw_admins'
        },
        [6] = {
            'change_admin_password',
            'level_add',
            'level_delete',
            'change_level',
            'set_command',
            'disable_command',
            'enable_command',
            'reload'
        }
    }
}
