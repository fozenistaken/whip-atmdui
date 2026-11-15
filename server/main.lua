-- atmdui server, on WHIP.
--
-- Ported from osm-atmdui (osmfxmods.com, CC BY-NC-SA 4.0). What changed for WHIP:
--  * Money is WHIP's bank. A card belongs to one account (the holder's default account when it is issued);
--    withdraw / deposit / transfer go through BankWithdraw / BankDeposit / BankTransfer, so the bank's own
--    permission, frozen-account and own-character rules apply, and every move is on the account's statement
--    and visible at WHIP's bank and phone.
--  * Cash is WHIP's cash item: a withdrawal pays notes (PayPlayer), a deposit takes them (ChargePlayer,
--    refunded if the bank refuses).
--  * The PIN is never on the card: item metadata is visible to the holder's game. The server keeps a hash
--    (GetPasswordHash) in its own table, with the wrong-PIN count and lockout, so a lockout survives a relog.
--  * A correct PIN opens a server-side session bound to that card and account; the client sends amounts and
--    digits only. Every call is a SecureCallback/SecureEvent (rate limits; refusals in /whip -> Monitor).
--  * Items, table and declarations live in Whip.register, so a whip_core restart re-declares them.

local SESSION_SECONDS = 600
-- The items are named after this resource (WHIP's rule: a resource's item names start with its own name), so they
-- are atmdui_card / atmdui_receipt in a folder called atmdui, and still never clash under any other folder name
-- (GitHub's ZIP unpacks as whip-atmdui-main). Pick the folder name once: renaming it later renames the items.
local RES = GetCurrentResourceName()
local CARD_ITEM, RECEIPT_ITEM = RES .. '_card', RES .. '_receipt'

local sessions = {}   -- [src] = { cardId, accountId, accountNumber, untilAt, charId }
local lastTx   = {}   -- [src] = { type, amount, account, balance, at, receipted }

local function dbg(...)
    if Config.Debug then print('[atmdui]', ...) end
end

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src], lastTx[src] = nil, nil
end)

AddEventHandler('whip_core:player:logout', function(e)
    if type(e) == 'table' and e.source then sessions[e.source], lastTx[e.source] = nil, nil end
end)

local function fullName(src, player)
    return exports.whip_core:GetPlayerFullName(src)
        or ('%s %s'):format(player and player.firstName or '', player and player.lastName or '')
end

--- The session for this player, still open and still the same character, or nil.
local function session(src, player)
    local s = sessions[src]
    if not s or os.time() > s.untilAt or (player and player.charId ~= s.charId) then
        sessions[src] = nil
        return nil
    end
    return s
end

local function fee(amount)
    local t = Config.Transactions
    return math.floor((t.fee or 0) + amount * ((t.feePercent or 0) / 100))
end

local function balanceOf(accountId)
    local acct = exports.whip_core:GetBankAccount(accountId)
    return acct and acct.balance or 0
end

local function remember(src, kind, amount, account, accountId)
    lastTx[src] = { type = kind, amount = amount, account = account or 'N/A', balance = balanceOf(accountId), at = os.time() }
end

--- The card the player carries (the first one), with its row, or nil and why.
local function cardOf(src)
    local found = exports.whip_core:FindItem(src, CARD_ITEM)
    local cardId = found and found.metadata and found.metadata.cardId
    if not cardId then return nil, Locale('no_card') end
    local row = MySQL.single.await('SELECT * FROM `atmdui_cards` WHERE `cardId` = ? LIMIT 1', { cardId })
    if not row or row.frozen == 1 or row.frozen == true then return nil, Locale('card_frozen') end
    return row
end

Whip.register(function()
    Whip.core:EnsureTable('atmdui_cards', [[
        CREATE TABLE IF NOT EXISTS `atmdui_cards` (
            `cardId`      VARCHAR(16)  NOT NULL,
            `charId`      INT          NOT NULL,
            `accountId`   INT          NOT NULL,
            `pinHash`     VARCHAR(255) NOT NULL,
            `fails`       INT          NOT NULL DEFAULT 0,
            `lockedUntil` INT          NOT NULL DEFAULT 0,
            `frozen`      TINYINT(1)   NOT NULL DEFAULT 0,
            `createdAt`   INT          NOT NULL,
            PRIMARY KEY (`cardId`),
            KEY `charId` (`charId`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    Whip.core:RegisterItem(CARD_ITEM, {
        name = 'Bank Card', desc = 'Insert it at an ATM. The PIN is not written on it.',
        weight = 0.01, type = 'misc', stack = false,
        image = 'html/img/items/atmdui_card.webp',      -- the picture keeps its own name whatever the folder is called
        metaFields = {
            { key = 'number', label = 'Card' },
            { key = 'account', label = 'Account' },
            { key = 'holder', label = 'Holder', format = 'uppercase' },
            { key = 'expiry', label = 'Expires' },
        },
    })

    Whip.core:RegisterItem(RECEIPT_ITEM, {
        name = 'ATM Receipt', desc = 'A printed ATM receipt.',
        weight = 0.001, type = 'misc', stack = false, usable = true,
        image = 'html/img/items/atmdui_receipt.webp',
        metaFields = {
            { key = 'type', label = 'Transaction', format = 'uppercase' },
            { key = 'amount', label = 'Amount' },
            { key = 'date', label = 'Date' },
        },
    })

    -- Reading a receipt opens it on screen; the receipt is kept
    Whip.core:RegisterUseHandler(RECEIPT_ITEM, function(source, player, slotData)
        TriggerClientEvent('atmdui:client:viewReceipt', source, slotData and slotData.metadata or {})
        return false
    end)

    -- What the ATM shows first: card or not, and the name. No balance is read until the PIN is right.
    Whip.core:SecureCallback('atmdui:start', { rateLimit = 1000 }, function(source, player)
        sessions[source] = nil
        return { hasCard = exports.whip_core:HasItem(source, CARD_ITEM), name = fullName(source, player) }
    end)

    Whip.core:SecureCallback('atmdui:verifyPIN', {
        rateLimit = 1000,
        params = { { 'pin', 'string', 8 } },
    }, function(source, player, pin)
        local card, why = cardOf(source)
        if not card then return false, why end
        local now = os.time()
        if card.lockedUntil > now then return false, Locale('too_many_pins') end

        if not VerifyPasswordHash(tostring(pin), card.pinHash) then
            local fails, lockUntil = card.fails + 1, 0
            if fails >= (Config.PIN.maxAttempts or 3) then
                fails, lockUntil = 0, now + (Config.PIN.lockoutTime or 300)
            end
            MySQL.update.await('UPDATE `atmdui_cards` SET `fails` = ?, `lockedUntil` = ? WHERE `cardId` = ?',
                { fails, lockUntil, card.cardId })
            exports.whip_core:LogActivity(source, 'atmdui_pin_fail', { detail = 'card ' .. card.cardId })
            return false, lockUntil > 0 and Locale('too_many_pins') or Locale('invalid_pin')
        end

        MySQL.update.await('UPDATE `atmdui_cards` SET `fails` = 0, `lockedUntil` = 0 WHERE `cardId` = ?', { card.cardId })
        local acct = exports.whip_core:GetBankAccount(card.accountId)
        if not acct then return false, Locale('account_not_found') end
        sessions[source] = { cardId = card.cardId, accountId = acct.accountId, accountNumber = acct.accountNumber,
                             untilAt = os.time() + SESSION_SECONDS, charId = player.charId }
        return true, { name = fullName(source, player), bank = acct.balance, account = acct.accountNumber }
    end)

    -- Issue a card for the player's default account. Only the PIN's hash is stored, never the PIN.
    Whip.core:SecureCallback('atmdui:createCard', {
        rateLimit = 3000,
        params = { { 'pin', 'string', 8 } },
    }, function(source, player, pin)
        if not Config.PIN.allowCardCreation then return false, Locale('card_failed') end
        pin = tostring(pin)
        if #pin ~= (Config.PIN.length or 4) or not pin:match('^%d+$') then return false, Locale('invalid_pin') end

        local acct = exports.whip_core:GetDefaultBankAccount(source)
        if not acct then return false, Locale('no_account') end

        local cost, receipt = Config.PIN.cardCreationCost or 0, nil
        if cost > 0 then
            local why
            receipt, why = exports.whip_core:ChargePlayer(source, cost, { reason = 'ATM card issue' })
            if not receipt then return false, why end
        end

        local cardId = ('%08x%08x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
        local number = ('%04d %04d %04d %04d'):format(math.random(1000, 9999), math.random(1000, 9999),
            math.random(1000, 9999), math.random(1000, 9999))
        local given, gwhy = exports.whip_core:AddItem(source, CARD_ITEM, 1, {
            cardId = cardId, number = number, account = acct.accountNumber,
            holder = fullName(source, player), expiry = os.date('%m/%y', os.time() + 3 * 365 * 86400),
        }, { reason = 'ATM card issued' })
        if not given then
            if receipt then exports.whip_core:RefundPlayer(receipt) end
            return false, gwhy
        end

        -- The card's row lands in the same transaction as the card itself
        local ok, cwhy = exports.whip_core:CommitWithAction({
            { query = 'INSERT INTO `atmdui_cards` (`cardId`, `charId`, `accountId`, `pinHash`, `createdAt`) VALUES (?, ?, ?, ?, ?)',
              values = { cardId, player.charId, acct.accountId, GetPasswordHash(pin), os.time() } },
        })
        if not ok then
            exports.whip_core:RemoveItem(source, CARD_ITEM, 1, { cardId = cardId }, { reason = 'ATM card not saved' })
            if receipt then exports.whip_core:RefundPlayer(receipt) end
            dbg('card row failed', cwhy)
            return false, Locale('card_failed')
        end
        exports.whip_core:LogActivity(source, 'atmdui_card_issued', { detail = acct.accountNumber })
        return true
    end)

    Whip.core:SecureCallback('atmdui:withdraw', {
        rateLimit = 1500,
        params = { { 'amount', 'amount', 100000000 } },
    }, function(source, player, amount)
        local s = session(source, player)
        if not s then return false, 0, Locale('session_expired') end
        if amount > Config.Transactions.maxWithdraw then return false, balanceOf(s.accountId), Locale('over_limit') end

        local f = fee(amount)
        if balanceOf(s.accountId) < amount + f then return false, balanceOf(s.accountId), Locale('insufficient_funds') end

        local ok, why = exports.whip_core:BankWithdraw(s.accountId, amount, source, { reason = 'ATM withdrawal' })
        if not ok then return false, balanceOf(s.accountId), why end

        -- The bank waited: still the same character before the notes are handed over?
        if not exports.whip_core:IsSessionCurrent(source, player.session) then
            exports.whip_core:BankSystemDeposit(s.accountId, amount, { reason = 'ATM withdrawal reversed', actorCharId = player.charId })
            return false, 0, Locale('session_expired')
        end
        local paid, pwhy = exports.whip_core:PayPlayer(source, amount, { method = 'cash', reason = 'ATM withdrawal' })
        if not paid then
            exports.whip_core:BankSystemDeposit(s.accountId, amount, { reason = 'ATM withdrawal reversed', actorCharId = player.charId })
            return false, balanceOf(s.accountId), pwhy
        end
        if f > 0 then exports.whip_core:BankSystemWithdraw(s.accountId, f, { reason = 'ATM fee', actorCharId = player.charId }) end

        remember(source, 'withdraw', amount, nil, s.accountId)
        return true, lastTx[source].balance
    end)

    Whip.core:SecureCallback('atmdui:deposit', {
        rateLimit = 1500,
        params = { { 'amount', 'amount', 100000000 } },
    }, function(source, player, amount)
        local s = session(source, player)
        if not s then return false, 0, Locale('session_expired') end
        if amount > Config.Transactions.maxDeposit then return false, balanceOf(s.accountId), Locale('over_limit') end

        local receipt, why = exports.whip_core:ChargePlayer(source, amount, { method = 'cash', reason = 'ATM deposit' })
        if not receipt then return false, balanceOf(s.accountId), why end
        local ok, dwhy = exports.whip_core:BankDeposit(s.accountId, amount, source, { reason = 'ATM deposit' })
        if not ok then
            exports.whip_core:RefundPlayer(receipt)
            return false, balanceOf(s.accountId), dwhy
        end

        remember(source, 'deposit', amount, nil, s.accountId)
        return true, lastTx[source].balance
    end)

    -- To another account by its number: the keypad types the digits of WB-######
    Whip.core:SecureCallback('atmdui:transfer', {
        rateLimit = 2000,
        params = { { 'account', 'string', 12 }, { 'amount', 'amount', 100000000 } },
    }, function(source, player, account, amount)
        local s = session(source, player)
        if not s then return false, 0, Locale('session_expired') end
        if amount > Config.Transactions.maxTransfer then return false, balanceOf(s.accountId), Locale('over_limit') end

        local digits = tostring(account):gsub('%D', '')
        if #digits < 1 or #digits > 6 then return false, balanceOf(s.accountId), Locale('account_not_found') end
        local number = ('WB-%06d'):format(tonumber(digits))
        local target = exports.whip_core:GetBankAccount({ number = number })
        if not target then return false, balanceOf(s.accountId), Locale('account_not_found') end
        if target.accountId == s.accountId then return false, balanceOf(s.accountId), Locale('self_transfer') end

        local f = fee(amount)
        if balanceOf(s.accountId) < amount + f then return false, balanceOf(s.accountId), Locale('insufficient_funds') end
        local ok, why = exports.whip_core:BankTransfer(s.accountId, target.accountId, amount, source, { reason = 'ATM transfer' })
        if not ok then return false, balanceOf(s.accountId), why end
        if f > 0 then exports.whip_core:BankSystemWithdraw(s.accountId, f, { reason = 'ATM fee', actorCharId = player.charId }) end

        remember(source, 'transfer', amount, number, s.accountId)
        return true, lastTx[source].balance
    end)

    Whip.core:SecureEvent('atmdui:endSession', { rateLimit = 500, burst = 3, whileDead = true }, function(source)
        sessions[source] = nil
    end)

    -- One receipt per real transaction, from the server's own figures, within two minutes of it
    Whip.core:SecureEvent('atmdui:receipt', { rateLimit = 2000 }, function(source)
        local tx = lastTx[source]
        if not tx or tx.receipted or os.time() - tx.at > 120 then return false end
        tx.receipted = true
        local given, why = exports.whip_core:AddItem(source, RECEIPT_ITEM, 1, {
            type = tx.type, amount = ('$%d'):format(tx.amount), account = tx.account,
            balance = ('$%d'):format(tx.balance), date = os.date('%Y-%m-%d %H:%M:%S'),
        }, { reason = 'ATM receipt' })
        if not given then return false, why end
        exports.whip_core:NotifyPlayer(source, Locale('receipt_given'), 'success')
    end)
end)

Whip.sayStarted()
