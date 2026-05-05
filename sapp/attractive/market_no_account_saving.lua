--[[
=====================================================================================
SCRIPT NAME:      market_no_account_saving.lua
DESCRIPTION:      Session-based economy system with purchasable perks
                  - Players earn/deduct money for in-game actions
                  - Temporary perks available for purchase
                  - Admin-controlled economy management
                  - No persistent accounts (resets each game)

                  Core Features:
                  - 8 power-ups with cooldowns (God Mode, Teleport, Damage Boost, etc.)
                  - Automatic money rewards for kills/objectives
                  - Penalties for deaths/suicides/betrayals
                  - Real-time balance tracking

                  Admin Controls:
                  - Fund deposits/withdrawals
                  - Perk customization
                  - Economy balancing

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration
local Account = {

    -- Initial balance for each account
    balance = 5000,

    -- Command to view available perks for purchase
    catalogue_command = 'market',

    -- Command to view current balance
    get_balance_command = 'money',

    -- Command to add funds to an account
    add_funds_command = 'deposit',

    -- Message displayed when funds are added
    on_add = "Deposited $$amount into $name's account",

    -- Command to remove funds from an account
    remove_funds_command = 'withdraw',

    -- Message displayed when funds are removed
    on_remove = "Withdrew $$amount from $name's account",

    -- Required admin level to use add/remove funds commands
    required_level = 1,

    -- Events and their corresponding rewards/penalties
    events = {
        pvp = { 8, "+$8 (pvp)" }, -- Reward for player vs player kill
        on_score = { 10, "+$10 (score)" }, -- Reward for scoring
        run_over = { 5, "+$5 (run over)" }, -- Reward for running over an enemy
        guardians = { 6, "+$6 (guardians)" }, -- Reward for killing guardians
        first_blood = { 10, "+$10 (first blood)" }, -- Reward for first blood
        killed_from_grave = { 25, "+$25 (killed from grave)" }, -- Reward for killing from the grave
        suicide = { -4, "-$4 (suicide)" }, -- Penalty for suicide
        squashed = { -2, "-$2 (squashed)" }, -- Penalty for being squashed
        betrayal = { -7, "-$7 (betrayal)" }, -- Penalty for betrayal
        fall_damage = { -5, "-$5 (fall damage)" }, -- Penalty for fall damage
        died_unknown = { -5, "-$5 (died/unknown)" }, -- Penalty for unknown death
        distance_damage = { -5, "-$5 (distance damage)" } -- Penalty for distance damage
    },

    -- Commands to buy perks and their details
    buy_commands = {
        CAMO = { 'camo', 'm1', 60, 30, 60, "-$60 -> (camo | 30s)" }, -- Camouflage perk
        GOD = { 'god', 'm2', 200, 30, 60, "-$200 -> (god | 30s)" }, -- God mode perk
        GRENADES = { 'nades', 'm3', 30, 2, 60, "-$30 -> (grenades | 2x each)" }, -- Grenades perk
        SPEED = { 's', 'm4', 60, 1.3, 60, "-$60 -> (speed boost | 1.3x)" }, -- Speed boost perk
        OVERSHIELD = { 'sh', 'm5', 100, 1, 60, "-$100 -> (full shield)" }, -- Overshield perk
        HEALTH = { 'hp', 'm6', 100, 1, 60, "-$100 -> (full health)" }, -- Health perk
        TELEPORT = { 'boost', 'm7', 350, 'N/A', 60, "-$350 -> (teleport where aiming)" }, -- Teleport perk
        DAMAGE = { 'N/A', 'm9', 500, 1.3, 120, 60, "-$500 -> (1.3x damage)" } -- Damage boost perk
    }
}

local players = {}
local ffa, falling, distance, first_blood
local time = os.time
local gmatch = string.gmatch

api_version = '1.12.0.0'

-- Event Callbacks
function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_DIE'], 'OnDeath')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_SCORE'], 'OnScore')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_TEAM_SWITCH'], 'OnSwitch')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDeath')
    OnStart()
end

function OnScriptUnload()
    -- N/A
end

--[[
    Initializes a new account with default values.

    @param t {table} - A table containing:
        t.meta_id {number} - The meta ID of the account, initialized to 0.
        t.god {boolean} - A flag indicating if the account has god mode, initialized to false.
        t.damage_multiplier {number} - The damage multiplier for the account, initialized to 1.

    @return {table} - The initialized account table.
]]
function Account:new(t)
    setmetatable(t, self)
    self.__index = self
    t.meta_id = 0
    t.god = false
    t.damage_multiplier = 1
    return t
end

--[[
    Deposits a specified amount into the account balance.

    @param t {table} - A table containing:
        t[1] {number} - The amount to deposit. If 0, the function returns immediately.
        t[2] {string} - An optional message to respond with after the deposit.

    The function adds the specified amount to the balance.
    If a message is provided, it responds with that message.
]]
function Account:deposit(t)
    if t[1] == 0 then
        return
    end
    self.balance = self.balance + t[1]
    self:respond(t[2])
end

--[[
    Withdraws a specified amount from the account balance.

    @param t {table} - A table containing:
        t[1] {number} - The amount to withdraw. If 0, the function returns immediately.
        t[2] {string} - An optional message to respond with after the withdrawal.

    The function ensures the balance does not go below zero.
    If a message is provided, it responds with that message.
]]
function Account:withdraw(t)
    if t[1] == 0 then
        return
    end
    self.balance = self.balance + (t[1] < 0 and t[1] or -t[1])
    self.balance = math.max(self.balance, 0)
    if t[2] then
        self:respond(t[2])
    end
end

--[[
    Sends a message to the player.

    @param msg {string} - The message to be sent to the player.

    The function uses the player's ID to send the specified message.
]]
function Account:respond(msg)
    rprint(self.pid, msg)
end

--[[
    Retrieves the memory address of a tag.

    @param Type {string} - The type of the tag (e.g., 'jpt!', 'bipd').
    @param Name {string} - The name of the tag (e.g., 'globals\\falling').

    @return {number|nil} - The memory address of the tag if found, otherwise nil.
]]
local function GetTag(Type, Name)
    local Tag = lookup_tag(Type, Name)
    return Tag ~= 0 and read_dword(Tag + 0xC) or nil
end

--[[
    Handles the event when a player joins the game.

    @param Ply {number} - The player ID of the joining player.

    The function retrieves the player's name and team, then initializes a new account for the player.
]]
function OnJoin(Ply)
    local name = get_var(Ply, '$name')
    local team = get_var(Ply, '$team')
    players[Ply] = Account:new({ pid = Ply, team = team, name = name })
end

--[[
    Handles the event when a player scores in the game.

    @param Ply {number} - The player ID of the scoring player.

    The function deposits the score reward into the player's account.
]]
function OnScore(Ply)
    local t = players[Ply]
    t:deposit(t.events.on_score)
end

--[[
    Handles the event when a player spawns in the game.

    @param Ply {number} - The player ID of the spawning player.

    The function checks if the player has god mode enabled and executes the god mode command if true.
]]
function OnSpawn(Ply)
    local t = players[Ply]
    if t.god then
        execute_command("w8 1;god " .. Ply)
    end
end

--[[
    Returns the plural form of a word based on the given number.

    @param n {number} - The number to determine the plural form.

    @return {string} - Returns "s" if the number is greater than 1, otherwise an empty string.
]]
local function Plural(n)
    return n > 1 and "s" or ""
end

--[[
    Handles the periodic update of player perks and their cooldowns.

    Iterates through all players and their purchased perks to check if any cooldowns have expired.
    If a perk's cooldown has expired, it resets the perk's state and notifies the player.

    The function specifically handles the 'DAMAGE' and 'GOD' perks, resetting their states when their durations end.

    The function is called on every tick of the game.

    No parameters.
    No return value.
]]
function OnTick()
    for _, t in pairs(players) do
        for cmd, perk in pairs(t.buy_commands) do
            local now = time()
            if cmd == 'DAMAGE' and t.damage_multiplier > 1 and now >= t.damage_finish then
                t.damage_multiplier = 1
                t:respond(cmd .. " cooldown has expired.")
            elseif cmd == 'GOD' and t.god and now >= t.god_finish then
                t.god = false
                t:respond(cmd .. " cooldown has expired.")
                execute_command('ungod ' .. t.pid)
            end
            if perk.cooldown_start and now >= perk.cooldown_finish then
                perk.cooldown_start = false
                t:respond(cmd .. " cooldown has expired.")
            end
        end
    end
end

function OnSwitch(Ply)
    players[Ply].team = get_var(Ply, '$team')
end

--[[
    Initializes the game state when the script starts.

    This function is called when the script is loaded. It performs the following tasks:
    - Checks if the game type is valid.
    - Resets the players table.
    - Sets the first blood flag to true.
    - Determines if the game is free-for-all (FFA).
    - Retrieves the memory addresses for the 'falling' and 'distance' tags.
    - Initializes accounts for all currently present players.

    No parameters.
    No return value.
]]
function OnStart()

    if get_var(0, '$gt') == 'n/a' then
        return
    end

    players = {}
    first_blood = true
    ffa = get_var(0, '$ffa') == '1'
    falling = GetTag('jpt!', 'globals\\falling')
    distance = GetTag('jpt!', 'globals\\distance')

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

--[[
    Checks if a player has the required permission level.

    @param t {table} - A table containing:
        t.pid {number} - The player ID.
        t.required_level {number} - The required permission level.

    @return {boolean} - Returns true if the player has the required permission level, otherwise false.
    If the player does not have the required permission level, a message is sent to the player.
]]
local function HasPermission(t)
    local level = tonumber(get_var(t.pid, '$lvl'))
    if level >= t.required_level then
        return true
    else
        t:respond("Insufficient Permission")
        return false
    end
end

local function CMDSplit(s)
    local args = {}
    for word in gmatch(s, '([^%s]+)') do
        args[#args + 1] = word:lower()
    end
    return args
end

--[[
    Handles player commands and executes the appropriate actions.

    @param Ply {number} - The player ID who issued the command.
    @param CMD {string} - The command string issued by the player.

    The function processes various commands such as checking balance, adding/removing funds, and purchasing perks.
    It ensures the player has the required permissions and sufficient balance before executing commands.
    It also handles cooldowns for perk commands.

    @return {boolean} - Returns false to indicate the command was handled.
]]
function OnCommand(Ply, CMD)
    local args = CMDSplit(CMD)
    if Ply <= 0 or not args then
        return
    end

    local t = players[Ply]
    local cmd = args[1]

    if cmd == t.get_balance_command then
        t:respond("You have $" .. t.balance)
        return false
    elseif cmd == t.add_funds_command or cmd == t.remove_funds_command then
        if HasPermission(t) then

            local pid = tonumber(args[2])
            local amount = tonumber(args[3])
            local p = players[pid]

            if not player_present(pid) then
                t:respond("Player #" .. args[2] .. " is not online.")
            elseif not pid or not amount then
                t:respond("Invalid Command syntax. Usage: /" .. cmd .. " <pid> <amount>")
            elseif cmd == t.add_funds_command then
                p.balance = p.balance + amount
                t:respond(t.on_add:gsub('$amount', args[3]):gsub('$name', p.name))
            elseif cmd == t.remove_funds_command then
                p.balance = p.balance - amount
                t:respond(t.on_remove:gsub('$amount', args[3]):gsub('$name', p.name))
            end
        end
        return false
    end

    for _, perk in pairs(t.buy_commands) do
        local sapp_command, command, cost, duration, cooldown, catalogue_message = unpack(perk)

        if cmd == t.catalogue_command then
            t:respond('/' .. command .. " " .. catalogue_message)
            return false
        elseif cmd == command then
            if not player_alive(Ply) then
                t:respond("Please wait until you respawn")
                return false
            elseif cost == 0 then
                t:respond("Command disabled")
            elseif perk.cooldown_start then
                local time_remaining = perk.cooldown_finish - time()
                t:respond("Command on cooldown. Please wait " .. time_remaining .. " second" .. Plural(time_remaining))
            elseif t.balance >= cost then
                t:respond(catalogue_message)
                t:withdraw({ cost })
                if cmd == "DAMAGE" then
                    t.damage_multiplier = perk[4]
                    t.damage_finish = time() + perk[5]
                elseif cmd == 'GOD' then
                    t.god = true
                    t.god_finish = time() + duration
                    execute_command(sapp_command .. ' ' .. t.pid)
                elseif cmd == 'TELEPORT' then
                    execute_command(sapp_command .. ' ' .. t.pid)
                else
                    execute_command(sapp_command .. ' ' .. t.pid .. ' ' .. duration)
                end
                perk.cooldown_start = true
                perk.cooldown_finish = time() + cooldown
            else
                t:respond("You do not have enough money! You need $" .. (cost - t.balance))
            end
            return false
        end
    end
end

--[[
    Handles the event when a player dies in the game.

    @param Victim {number} - The player ID of the victim.
    @param Killer {number} - The player ID of the killer.
    @param MetaID {number} - The meta ID of the damage type.
    @param Damage {number} - The amount of damage inflicted.

    The function processes various scenarios such as player vs player kills, suicides, betrayals, and environmental deaths.
    It updates the players' accounts with rewards or penalties based on the type of death.
    It also handles special cases like first blood, killing from the grave, and running over enemies.

    @return {boolean, number} - Returns true and the modified damage if MetaID is provided, otherwise no return value.
]]
function OnDeath(Victim, Killer, MetaID, Damage)
    local victim = tonumber(Victim)
    local killer = tonumber(Killer)
    local v = players[victim]
    local k = players[killer]

    if v then
        if MetaID then
            v.meta_id = MetaID
            return true, (k and Damage * k.damage_multiplier or 1)
        end

        local squashed = (killer == 0)
        local guardians = (killer == nil)
        local suicide = (killer == victim)
        local pvp = (killer > 0 and killer ~= victim)
        local fell = (v.meta_id == falling or distance)
        local betrayal = ((k and not ffa) and (v.team == k.team and killer ~= victim))

        if pvp and not betrayal then
            if first_blood then
                first_blood = false
                k:deposit(k.events.first_blood)
            end
            if not player_alive(killer) then
                k:deposit(k.events.killed_from_grave)
                goto done
            end
            local DyN = get_dynamic_player(killer)
            if DyN ~= 0 then
                local vehicle = read_dword(DyN + 0x11C)
                if vehicle ~= 0xFFFFFFFF then
                    k:deposit(k.events.run_over)
                    goto done
                end
            end
            k:deposit(k.events.pvp)
        elseif guardians then
            k:deposit(k.events.guardians)
            v:deposit(v.events.guardians)
        elseif suicide then
            v:withdraw(v.events.suicide)
        elseif betrayal then
            k:withdraw(k.events.betrayal)
        elseif squashed then
            v:withdraw(v.events.squashed)
        elseif fell ~= nil then
            v:withdraw(v.events.fall_damage)
        else
            v:withdraw(v.events.died_unknown)
        end
        :: done ::
    end
end