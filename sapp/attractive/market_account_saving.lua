--[[
=====================================================================================
SCRIPT NAME:      market_account_saving.lua
DESCRIPTION:      In-game economy system with purchasable perks and account management
                  - Players earn money for kills and objectives
                  - Spend money on temporary power-ups and abilities
                  - Persistent account system with login/registration
                  - Admin-controlled economy management

                  Key Features:
                  - 8 purchasable perks with cooldowns (God Mode, Camo, Teleport, etc.)
                  - Automatic money rewards/deductions for gameplay events
                  - Account system with password protection
                  - Admin fund management tools
                  - Automatic cleanup of inactive accounts

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts --

local Account = {

    -- Starting balance:
    --
    balance = 0,


    -- File that contains the user accounts:
    --
    file = 'accounts.json',


    -- Account management command syntax:
    --
    account_management_syntax = { "account", "create", "login" },


    -- Command used to view available items for purchase:
    --
    catalogue_command = 'market',


    -- Command used to view current balance:
    --
    get_balance_command = 'money',


    -- Command used to add funds:
    --
    -- Syntax: /deposit <pid> <amount>
    add_funds_command = 'deposit',
    on_add = "Deposited $$amount into $name's account",


    -- Command used to remove funds:
    --
    -- Syntax: /withdraw <pid> <amount>
    remove_funds_command = 'withdraw',
    on_remove = "Withdrew $$amount from $name's account",


    -- Players must be this level (or higher) to add/remove funds from an account:
    required_level = 1,
    --

    -- If a user doesn't log into an account after this many days, it's considered
    -- stale and will be deleted:
    stale_account_period = 30,


    -- Money deposited/withdrawn during these events:
    --
    -- Set the money value to 0 to disable event.
    --
    -- deposit:
    ['pvp'] = { 8, "+$8 (pvp)" },
    ['on_score'] = { 10, "+$10 (score)" },
    ['run_over'] = { 5, "+$5 (run over)" },
    ['guardians'] = { 6, "+$6 (guardians)" },
    ['first_blood'] = { 10, "+$10 (first blood)" },
    ['killed_from_grave'] = { 25, "+$25 (killed from grave)" },
    --
    -- withdraw:
    ['suicide'] = { -4, "-$4 (suicide)" },
    ['squashed'] = { -2, "-$2 (squashed)" },
    ['betrayal'] = { -7, "-$7 (betrayal)" },
    ['fall_damage'] = { -5, "-$5 (fall damage)" }, -- doesn't work on protected maps, but wont break the script
    ['died/unknown'] = { -5, "-$5 (died/unknown)" },
    ['distance_damage'] = { -5, "-$5 (distance damage" }, -- doesn't work on protected maps, but wont break the script


    ----------------------------------------------------
    -- COMMAND SETTINGS --------------------------------
    ----------------------------------------------------
    buy_commands = {

        --
        -- SET THE PRICE TO 0 to disable.
        --

        --
        -- DO NOT CHANGE THE SAPP COMMAND OR LABEL
        -- DO NOT CHANGE THE SAPP COMMAND OR LABEL
        -- DO NOT CHANGE THE SAPP COMMAND OR LABEL
        --

        -- Camouflage:
        -- ["LABEL"] = {sapp command, trigger command, price, duration, cooldown period, catalogue message}
        ['CAMO'] = { 'camo', 'm1', 60, 30, 60, "-$60 -> (camo | 30s)" },

        --
        -- God Mode:
        -- ["LABEL"] = {sapp command, trigger command, price, duration, cooldown period, catalogue message}
        ['GOD'] = { 'god', 'm2', 200, 30, 60, "-$200 -> (god | 30s)" },

        --
        -- Grenades:
        -- ["LABEL"] = {sapp command, trigger command, price, amount, cooldown period, catalogue message}
        ['GRENADES'] = { 'nades', 'm3', 30, 2, 60, "-$30 -> (grenades | 2x each)" },

        --
        -- Speed Boost (normal speed = 1):
        -- ["LABEL"] = {sapp command, trigger command, price, speed%, cooldown period, catalogue message}
        ['SPEED'] = { 's', 'm4', 60, 1.3, 60, "-$60 -> (speed boost | 1.3x)" },

        --
        -- Overshield (full shield = 1):
        -- ["LABEL"] = {sapp command, trigger command, price, shield%, cooldown period, catalogue message}
        ['OVERSHIELD'] = { 'sh', 'm5', 100, 1, 60, "-$100 -> (full shield)" },

        --
        -- Health (full health = 1):
        -- ["LABEL"] = {sapp command, trigger command, price, health%, cooldown period, catalogue message}
        ['HEALTH'] = { 'hp', 'm6', 100, 1, 60, "-$100 -> (full health)" },

        -----------------------------------
        -- special commands:
        -----------------------------------

        --
        -- Teleport:
        -- ["LABEL"] = {sapp command, trigger command, price, N/A, cooldown period, catalogue message}
        ['TELEPORT'] = { 'boost', 'm7', 350, 'N/A', 60, "-$350 -> (teleport where aiming)" },

        --
        -- Damage Boost:
        -- ["LABEL"] = {N/A, trigger command, price, multiplier, duration, cooldown period, catalogue message}
        ['DAMAGE'] = { 'N/A', 'm9', 500, 1.3, 120, 60, "-$500 -> (1.3x damage)" }
    }
}
-- config ends --

local players = { }
local ffa, falling, distance, first_blood

local json = loadfile('./json.lua')()
local floor = math.floor

local match, gsub = string.match, string.gsub
local gmatch, lower = string.gmatch, string.lower

local open = io.open
local time, date, diff = os.time, os.date, os.difftime

api_version = '1.12.0.0'

function OnScriptLoad()

    local dir = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    Account.dir = dir .. '\\sapp\\' .. Account.file

    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_DIE'], 'OnDeath')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_SCORE'], 'OnScore')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_TEAM_SWITCH'], 'OnSwitch')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDeath')
    OnStart()

    Account:CheckFile(true)
end

local function GetIP(Ply)
    return get_var(Ply, '$ip')
end

local function WriteToFile(self, t)
    local file = open(self.dir, 'w')
    if (file) then
        file:write(json:encode_pretty(t))
        file:close()
    end
end

function Account:new(t)

    setmetatable(t, self)
    self.__index = self

    t.meta_id = 0
    t.god = false
    t.logged_in = false
    t.damage_multiplier = 1
    return t
end

function Account:deposit(t)
    if (t[1] == 0 or not self.logged_in) then
        return
    end
    self.balance = self.balance + t[1]
    self.database[self.username].balance = self.balance
    self:respond(t[2])
end

function Account:withdraw(t)
    if (t[1] == 0 or not self.logged_in) then
        return
    end

    if (t[1] < 0) then
        self.balance = self.balance + t[1]
    else
        self.balance = self.balance - t[1]
    end

    self.balance = (self.balance < 0 and 0 or self.balance)
    self.database[self.username].balance = self.balance
    if (not t[2]) then
        return
    end
    self:respond(t[2])
end

function Account:CheckFile(ScriptLoad)
    self.database = (ScriptLoad and nil or self.database)

    if (get_var(0, '$gt') ~= 'n/a' and self.database == nil) then
        local content = ''
        local file = open(self.dir, 'r')
        if (file) then
            content = file:read('*all')
            file:close()
        end
        local data = json:decode(content)
        if (not data) then
            WriteToFile(self, {})
        end
        self.database = data or {}
    end
end

function Account:Cache(name, password, balance)

    local day = date('*t').day
    local month = date('*t').month
    local year = date('*t').year

    self.username = name
    self.logged_in = true
    self.database[name] = {
        password = password,
        balance = balance,
        last_login = { day = day, month = month, year = year }
    }
end

function Account:respond(msg)
    rprint(self.pid, msg)
end

local function GetTag(Type, Name)
    local Tag = lookup_tag(Type, Name)
    return Tag ~= 0 and read_dword(Tag + 0xC) or nil
end

function OnJoin(Ply)
    local ip = GetIP(Ply)
    local name = get_var(Ply, '$name')
    local team = get_var(Ply, '$team')
    local t = { pid = Ply, team = team, name = name }
    if (players[ip]) then
        for k, v in pairs(t) do
            players[ip][k] = v
        end
    else
        players[ip] = Account:new(t)
    end
end

function OnScore(Ply)
    local ip = GetIP(Ply)
    local t = players[ip]
    t:deposit(t['on_score'])
end

function OnSpawn(Ply)
    local ip = GetIP(Ply)
    local t = players[ip]
    if (t.god) then
        execute_command("w8 1;god " .. Ply)
    end
end

local function Plural(n)
    return (n > 1 and "s" or "")
end

function OnTick()

    -- Delete stale accounts:
    for username, acc in pairs(Account.database) do
        if (username) then
            local day = acc.last_login.day
            local month = acc.last_login.month
            local year = acc.last_login.year
            local reference = time { day = day, month = month, year = year }
            local days_from = diff(time(), reference) / (24 * 60 * 60)
            local whole_days = floor(days_from)
            if (whole_days >= Account.stale_account_period) then
                cprint("Deleting stale account for user " .. username, 12)
                Account.database[username] = nil
            end
        end
    end

    for _, t in pairs(players) do
        if (t.logged_in) then
            for cmd, perk in pairs(t.buy_commands) do
                if (cmd == 'damage_multiplier' and t.damage_multiplier > 1 and t.damage_time() >= t.damage_finish) then
                    t.damage_multiplier = 1
                    t:respond("Damage Multiplier Perk has expired.")
                elseif (cmd == 'god' and t.god and t.god_time() >= t.god_finish) then
                    t.god = false
                    t:respond("God Mode perk has expired.")
                    execute_command('ungod ' .. t.pid)
                end
                if (perk.cooldown_start and perk.cooldown_time() >= perk.cooldown_finish) then
                    perk.cooldown_start = false
                    t:respond("/", cmd .. " cooldown has expired.")
                end
            end
        end
    end
end

function OnSwitch(Ply)
    local ip = GetIP(Ply)
    players[ip].team = get_var(Ply, '$team')
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then

        Account:CheckFile(false)

        players = {}
        first_blood = true

        ffa = (get_var(0, '$ffa') == '1')

        -- these will not work on protected maps:
        falling = GetTag('jpt!', 'globals\\falling')
        distance = GetTag('jpt!', 'globals\\distance')
        --

        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function OnEnd()
    WriteToFile(Account, Account.database)
end

local function HasPermission(t)
    local l = tonumber(get_var(t.pid, '$lvl'))
    return (l >= t.required_level or t:respond("Insufficient Permission") and false)
end

function OnCommand(Ply, CMD, _, _)

    if (Ply > 0) then

        local args = { }
        for arg in gmatch(CMD, '([^%s]+)') do
            args[#args + 1] = arg
        end

        if (#args > 0) then

            local ip = GetIP(Ply)
            local t = players[ip]

            args[1], args[2] = lower(args[1]), lower(args[2] or '')

            local management = t.account_management_syntax
            if (args[1] == management[1]) then

                local name = args[3]
                local password = table.concat(args, ' ', 4)

                local acc = t.database[name]
                if (args[2] == management[2] and args[3]) then
                    if (not password or password == '') then
                        t:respond("You didn't provide a password")
                    elseif (not t.logged_in) then
                        if (acc) then
                            t:respond("That account username already exists.")
                        else
                            t:Cache(name, password, t.balance)
                            t:respond("Account successfully created.")
                        end
                    else
                        t:respond("You already have an account.")
                    end
                    return false

                elseif (args[2] == management[3] and args[3]) then
                    if (not password or password == '') then
                        t:respond("You didn't provide a password")
                    elseif (acc) then
                        if (t.logged_in) then
                            t:respond("You are already logged in.")
                        elseif (password == acc.password) then
                            local balance = acc.balance
                            t.balance = balance
                            t:Cache(name, password, balance)
                            t:respond("Successfully logged in. Balance: $" .. balance)
                        else
                            t:respond("Invalid password. Please try again.")
                        end
                    else
                        t:respond("Account username does not exist")
                    end
                    return false
                end
            end

            if (args[1] == t.get_balance_command) then
                if (t.logged_in) then
                    t:respond("You have $" .. t.balance)
                else
                    t:respond("You are not logged in.")
                end
                return false
            elseif (args[1] == t.add_funds_command or args[1] == t.remove_funds_command) then
                if HasPermission(t) then
                    local p = players[GetIP(args[2])]
                    if not player_present(args[2]) then
                        t:respond("Player #" .. args[2] .. " is not online.")
                    elseif (p.pid == t.pid and not p.logged_in) then
                        t:respond("You are not logged in.")
                    elseif (p.pid ~= t.pid and not p.logged_in) then
                        t:respond(p.name .. " is not logged in.")
                    elseif (not args[2] or not match(args[2], '%d+')) then
                        t:respond("Invalid Command syntax. Usage: /" .. args[1] .. " <pid> <amount>")
                    elseif (not args[3] or not match(args[3], '%d+')) then
                        t:respond("Invalid amount")
                    elseif (args[1] == t.add_funds_command) then
                        p.balance = p.balance + args[3]
                        t:respond(gsub(gsub(t.on_add, '$amount', args[3]), '$name', p.name))
                    elseif (args[1] == t.remove_funds_command) then
                        p.balance = p.balance - args[3]
                        t:respond(gsub(gsub(t.on_remove, '$amount', args[3]), '$name', p.name))
                    end
                end
                return false
            end

            local response = true
            for cmd, perk in pairs(t.buy_commands) do

                local sapp_command = perk[1]
                local cost = perk[3]
                local command = perk[2]
                local duration = perk[4] -- or extra data (like damage multiplier number)
                local cooldown = perk[#perk - 1]
                local catalogue_message = perk[#perk]

                if (args[1] == t.catalogue_command) then
                    t:respond('/' .. command .. ' ' .. catalogue_message)
                    response = false
                elseif (args[1] == command) then
                    if player_alive(Ply) then
                        if (not t.logged_in) then
                            t:respond("You are not logged in.")
                        elseif (perk[2] == 0) then
                            t:respond("Command disabled")
                        elseif (perk.cooldown_start) then
                            local time_remaining = perk.cooldown_finish - perk.cooldown_time()
                            t:respond("Command on cooldown")
                            t:respond("Please wait " .. time_remaining .. " second" .. Plural(time_remaining))
                        elseif (args[1] == command) then
                            if (cost == 0) then
                                t:respond("Command disabled")
                            elseif (perk.cooldown_start) then
                                local time_remaining = perk.cooldown_finish - perk.cooldown_time()
                                t:respond("Command on cooldown")
                                t:respond("Please wait " .. time_remaining .. " second" .. Plural(time_remaining))
                            elseif (t.balance >= cost) then
                                t:respond(catalogue_message)
                                t:withdraw({ cost })
                                if (cmd == "DAMAGE") then
                                    t.damage_time = time
                                    t.damage_multiplier = perk[4]
                                    t.damage_finish = time() + perk[5]
                                elseif (cmd == 'GOD') then
                                    t.god = true
                                    t.god_time = time
                                    t.god_finish = time() + duration
                                    execute_command(sapp_command .. ' ' .. t.pid)
                                elseif (cmd == 'TELEPORT') then
                                    execute_command(sapp_command .. ' ' .. t.pid)
                                else
                                    execute_command(sapp_command .. ' ' .. t.pid .. ' ' .. duration)
                                end
                                perk.cooldown_time = time
                                perk.cooldown_start = true
                                perk.cooldown_finish = time() + cooldown
                            else
                                t:respond("You do not have enough money!")
                                t:respond("You need $" .. cost - t.balance)
                            end
                        end
                    else
                        t:respond("Please wait until you respawn")
                    end
                    return false
                end
            end
            return response
        end
    end
end

function OnDeath(Victim, Killer, MetaID, Damage)

    local victim = tonumber(Victim)
    local killer = tonumber(Killer)

    local v = players[GetIP(victim)]
    local k = players[GetIP(killer)]

    if (v) then

        -- event_damage_application:
        if (MetaID) then
            v.meta_id = MetaID
            return true, (k and Damage * k.damage_multiplier or 1)
        end

        -- event_die:
        local squashed = (killer == 0)
        local guardians = (killer == nil)
        local suicide = (killer == victim)
        local pvp = (killer > 0 and killer ~= victim)
        local fell = (v.meta_id == falling or distance)
        local betrayal = ((k and not ffa) and (v.team == k.team and killer ~= victim))

        if (pvp and not betrayal) then

            if (first_blood) then
                first_blood = false
                k:deposit(k['first_blood'])
            end

            if (not player_alive(killer)) then
                k:deposit(k['killed_from_grave'])
                goto done
            end

            local DyN = get_dynamic_player(killer)
            if (DyN ~= 0) then
                local vehicle = read_dword(DyN + 0x11C)
                if (vehicle ~= 0xFFFFFFFF) then
                    k:deposit(k['run_over'])
                    goto done
                end
            end
            k:deposit(k['pvp'])

        elseif (guardians) then
            k:deposit(k['guardians'])
            v:deposit(v['guardians'])
        elseif (suicide) then
            v:withdraw(v['suicide'])
        elseif (betrayal) then
            k:withdraw(k['betrayal'])
        elseif (squashed) then
            v:withdraw(v['squashed'])
        elseif (fell ~= nil) then
            v:withdraw(v['fall_damage'])
        else
            v:withdraw(v['died/unknown'])
        end

        :: done ::
    end
end

function OnScriptUnload()
    -- N/A
end