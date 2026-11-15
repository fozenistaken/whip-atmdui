-- Main Client Script
-- Handles ATM interaction, state management, and communication
-- Physical keypad buttons are used for all interaction

local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

local ATM = {}
ATM.inSession = false
ATM.currentATM = nil
ATM.sessionData = {}
ATM.pinAttempts = 0
ATM.lockedUntil = 0

-- ATM State Machine
ATM.State = {
    IDLE = 'idle',
    CARD_INSERT = 'card_insert',
    NO_CARD = 'no_card',
    CREATE_CARD_PIN = 'create_card_pin',
    PIN_ENTRY = 'pin_entry',
    MAIN_MENU = 'main_menu',
    WITHDRAW = 'withdraw',
    WITHDRAW_AMOUNT = 'withdraw_amount',
    DEPOSIT = 'deposit',
    DEPOSIT_AMOUNT = 'deposit_amount',
    TRANSFER = 'transfer',
    TRANSFER_ACCOUNT = 'transfer_account',
    TRANSFER_AMOUNT = 'transfer_amount',
    BALANCE = 'balance',
    PROCESSING = 'processing',
    SUCCESS = 'success',
    ERROR = 'error',
    RECEIPT = 'receipt',
    CARD_EJECT = 'card_eject',
}

ATM.currentState = ATM.State.IDLE
ATM.enteredPIN = ''
ATM.enteredAmount = ''
ATM.transferAccount = ''
ATM.lastTransaction = nil

-- WHIP: models and anims load the plain way (ox_lib is not used on WHIP)
local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local untilAt = GetGameTimer() + 2500
    while not HasModelLoaded(model) and GetGameTimer() < untilAt do Wait(10) end
    return HasModelLoaded(model)
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local untilAt = GetGameTimer() + 2500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < untilAt do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- WHIP: the DUI is made once; the prompt is declared in Whip.register, so a whip_core restart puts it back
local duiMade = false
Whip.register(function()
    if not duiMade then
        duiMade = true
        CreateThread(function() ATM_DUI.Create() end)
    end
    ATM.SetupInteraction()
end)

-- One WHIP prompt on every ATM prop (in place of ox_target / qb-target / a proximity loop)
function ATM.SetupInteraction()
    Whip.core:AddAction({
        id = 'atm',
        at = {
            model = Config.ATMModels,
            offset = Config.Interaction.offset,       -- on the screen, not at the prop's base
            heading = Config.Interaction.heading,
            perModel = Config.Interaction.perModel,
        },
        label = Locale('use_atm'),
        icon = 'cash',
        reach = Config.Interaction.reach,
        canInteract = function() return not ATM.inSession end,
        onSelect = function(ctx)
            ATM.StartSession(ctx.entity)
        end,
    })
end

-- Dispense cash visual effect
function ATM.DispenseCash(amount)
    print("^3[ATM DEBUG] Triggering DispenseCash for amount:^0", amount)
    if not ATM.currentATM or not DoesEntityExist(ATM.currentATM) then 
        print("^1[ATM DEBUG] currentATM does not exist!^0")
        return 
    end
    
    -- Determine cash stack size based on amount
    local model = `prop_anim_cash_pile_01`
    if amount > 500 then
        model = `prop_cash_pile_02`
    end
    
    print("^3[ATM DEBUG] Requesting model:^0", model)
    loadModel(model)
    if not HasModelLoaded(model) then
        print("^1[ATM DEBUG] Failed to load cash model!^0")
        return
    end
    
    local atmObj = ATM.currentATM
    local atmHeading = GetEntityHeading(atmObj)

    local modelHash = GetEntityModel(atmObj)
    local configKey
    for _, v in pairs(Config.ATMModels) do
        if GetHashKey(v) == modelHash then configKey = v; break end
    end
    
    local offsets = Config.PropOffsets[configKey] and Config.PropOffsets[configKey].dispense or { x = -0.11, startY = 0.15, endY = -0.15, z = 0.95 }
    
    local startPos = GetOffsetFromEntityInWorldCoords(atmObj, offsets.x, offsets.startY, offsets.z)
    local endPos = GetOffsetFromEntityInWorldCoords(atmObj, offsets.x, offsets.endY, offsets.z)
    
    print(string.format("^3[ATM DEBUG] Spawning cash at StartPos: %s^0", startPos))
    
    local prop = CreateObject(model, startPos.x, startPos.y, startPos.z, false, false, false)
    if not DoesEntityExist(prop) then
        print("^1[ATM DEBUG] Failed to create cash prop!^0")
        return
    end

    print("^3[ATM DEBUG] Cash prop created successfully:^0", prop)
    SetEntityHeading(prop, atmHeading + 90.0)
    SetEntityCollision(prop, false, false)
    
    local curPosTracker = startPos
    
    -- Debug Markers Thread (runs for 10 seconds)
    -- CreateThread(function()
    --     local endTime = GetGameTimer() + 10000
    --     while GetGameTimer() < endTime do
    --         -- Draw a Green Sphere at the Start Position
    --         DrawMarker(28, startPos.x, startPos.y, startPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, 0, 255, 0, 200, false, false, 2, false, nil, nil, false)
    --         -- Draw a Red Sphere at the End Position
    --         DrawMarker(28, endPos.x, endPos.y, endPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, 255, 0, 0, 200, false, false, 2, false, nil, nil, false)
    --         -- Draw a Yellow Sphere tracking the prop
    --         DrawMarker(28, curPosTracker.x, curPosTracker.y, curPosTracker.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.08, 0.08, 0.08, 255, 255, 0, 200, false, false, 2, false, nil, nil, false)
    --         Wait(0)
    --     end
    -- end)
    
    -- Slide out animation
    for i = 1, 60 do
        local pct = i / 60.0
        curPosTracker = vector3(
            startPos.x + (endPos.x - startPos.x) * pct,
            startPos.y + (endPos.y - startPos.y) * pct,
            startPos.z + (endPos.z - startPos.z) * pct
        )
        SetEntityCoordsNoOffset(prop, curPosTracker.x, curPosTracker.y, curPosTracker.z, false, false, false)
        Wait(30) -- Slowed down slightly so you can see it move clearer
    end
    
    print("^3[ATM DEBUG] Cash slide out complete. Waiting to take...^0")
    
    -- Wait and then visually "take" the cash
    Wait(2500)
    
    -- Slide back in / disappear
    print("^3[ATM DEBUG] Deleting cash prop.^0")
    DeleteObject(prop)
    SetModelAsNoLongerNeeded(model)
end

-- Deposit cash visual effect
function ATM.DepositCashVisual(amount)
    if not ATM.currentATM or not DoesEntityExist(ATM.currentATM) then return end
    
    local model = `prop_anim_cash_pile_01`
    if amount and amount > 500 then
        model = `prop_cash_pile_02`
    end
    
    loadModel(model)
    
    local atmObj = ATM.currentATM
    local atmHeading = GetEntityHeading(atmObj)

    local modelHash = GetEntityModel(atmObj)
    local configKey
    for _, v in pairs(Config.ATMModels) do
        if GetHashKey(v) == modelHash then configKey = v; break end
    end

    local offsets = Config.PropOffsets[configKey] and Config.PropOffsets[configKey].deposit or { x = -0.10, startY = -0.15, endY = 0.15, z = 0.95 }
    
    local startPos = GetOffsetFromEntityInWorldCoords(atmObj, offsets.x, offsets.startY, offsets.z)
    local endPos = GetOffsetFromEntityInWorldCoords(atmObj, offsets.x, offsets.endY, offsets.z)
    
    local prop = CreateObject(model, startPos.x, startPos.y, startPos.z, false, false, false)
    SetEntityHeading(prop, atmHeading + 90.0)
    SetEntityCollision(prop, false, false)

    -- Play player animation for reaching in
    ATM.PlayAnimation('cardInsert')
    Wait(500) -- brief delay to match hand
    
    for i = 1, 60 do
        local pct = i / 60.0
        local curPos = vector3(
            startPos.x + (endPos.x - startPos.x) * pct,
            startPos.y + (endPos.y - startPos.y) * pct,
            startPos.z + (endPos.z - startPos.z) * pct
        )
        SetEntityCoordsNoOffset(prop, curPos.x, curPos.y, curPos.z, false, false, false)
        Wait(30)
    end
    
    Wait(500)
    DeleteObject(prop)
    SetModelAsNoLongerNeeded(model)
end

-- Insert card visual effect
function ATM.InsertCardVisual(atmEntity)
    if not atmEntity or not DoesEntityExist(atmEntity) then return end
    
    local model = `prop_cs_credit_card`
    loadModel(model)
    
    local atmHeading = GetEntityHeading(atmEntity)

    local modelHash = GetEntityModel(atmEntity)
    local configKey
    for _, v in pairs(Config.ATMModels) do
        if GetHashKey(v) == modelHash then configKey = v; break end
    end

    local offsets = Config.PropOffsets[configKey] and Config.PropOffsets[configKey].card or { x = 0.25, startY = -0.10, endY = 0.20, z = 1.2 }
    
    local startPos = GetOffsetFromEntityInWorldCoords(atmEntity, offsets.x, offsets.startY, offsets.z)
    local endPos = GetOffsetFromEntityInWorldCoords(atmEntity, offsets.x, offsets.endY, offsets.z)
    
    local prop = CreateObject(model, startPos.x, startPos.y, startPos.z, false, false, false)
    SetEntityHeading(prop, atmHeading)
    SetEntityRotation(prop, 90.0, 90.0, atmHeading, 2, true)
    SetEntityCollision(prop, false, false)

    for i = 1, 40 do
        local pct = i / 40.0
        local curPos = vector3(
            startPos.x + (endPos.x - startPos.x) * pct,
            startPos.y + (endPos.y - startPos.y) * pct,
            startPos.z + (endPos.z - startPos.z) * pct
        )
        SetEntityCoordsNoOffset(prop, curPos.x, curPos.y, curPos.z, false, false, false)
        Wait(20)
    end
    
    Wait(500)
    DeleteObject(prop)
    SetModelAsNoLongerNeeded(model)
end

-- Create card visual effect (spit out of ATM)
function ATM.CreateCardVisual(atmEntity)
    if not atmEntity or not DoesEntityExist(atmEntity) then return end
    
    local model = `prop_cs_credit_card`
    loadModel(model)
    
    local atmHeading = GetEntityHeading(atmEntity)

    local modelHash = GetEntityModel(atmEntity)
    local configKey
    for _, v in pairs(Config.ATMModels) do
        if GetHashKey(v) == modelHash then configKey = v; break end
    end

    local offsets = Config.PropOffsets[configKey] and Config.PropOffsets[configKey].createCard or { x = 0.25, startY = 0.20, endY = -0.10, z = 1.2 }
    
    local startPos = GetOffsetFromEntityInWorldCoords(atmEntity, offsets.x, offsets.startY, offsets.z)
    local endPos = GetOffsetFromEntityInWorldCoords(atmEntity, offsets.x, offsets.endY, offsets.z)
    
    local prop = CreateObject(model, startPos.x, startPos.y, startPos.z, false, false, false)
    SetEntityHeading(prop, atmHeading)
    SetEntityRotation(prop, 90.0, 90.0, atmHeading, 2, true)
    SetEntityCollision(prop, false, false)

    for i = 1, 40 do
        local pct = i / 40.0
        local curPos = vector3(
            startPos.x + (endPos.x - startPos.x) * pct,
            startPos.y + (endPos.y - startPos.y) * pct,
            startPos.z + (endPos.z - startPos.z) * pct
        )
        SetEntityCoordsNoOffset(prop, curPos.x, curPos.y, curPos.z, false, false, false)
        Wait(20)
    end
    
    Wait(500)
    DeleteObject(prop)
    SetModelAsNoLongerNeeded(model)
end

-- Start ATM session
function ATM.StartSession(atmEntity)
    if ATM.inSession then return end
    
    if not atmEntity or not DoesEntityExist(atmEntity) then return end
    -- WHIP: the server says whether a card is carried, and the name; balances come after the PIN
    local info = Whip.core:Callback('atmdui:start')
    if type(info) ~= 'table' then return end
    ATM.startInfo = info
    if Config.PIN.requireCard and not info.hasCard then
        if Config.PIN.allowCardCreation then
            ATM.StartNoCardSession(atmEntity)
        else
            Whip.core:Notify(Locale('insert_card'), 'error')
        end
        return
    end
    
    -- Check if locked out
    if ATM.lockedUntil > GetGameTimer() then
        Whip.core:Notify(Locale('card_locked'), 'error')
        return
    end
    
    ATM.inSession = true
    ATM.currentATM = atmEntity
    ATM.pinAttempts = 0
    ATM.enteredPIN = ''
    ATM.enteredAmount = ''
    ATM.transferAccount = ''
    
    -- Get player data
    local playerData = { name = ATM.startInfo and ATM.startInfo.name or '', bank = 0 }
    ATM.sessionData = playerData
    
    -- Apply DUI texture
    local atmModel = GetEntityModel(atmEntity)
    ATM_DUI.ApplyTexture(atmModel)
    
    -- Initialize DUI session
    ATM_DUI.InitSession(playerData)
    
    -- Transition camera
    ATM_Camera.TransitionTo(atmEntity)
    
    -- Play card insert animation & visual prop
    ATM.PlayAnimation('cardInsert')
    CreateThread(function()
        ATM.InsertCardVisual(atmEntity)
    end)
    
    -- Wait for animation then show card insert screen
    Wait(500)
    ATM.SetState(ATM.State.CARD_INSERT)
    ATM_DUI.SetScreen('card_insert')
    
    -- Auto-advance to PIN entry after animation
    Wait(1500)
    if ATM.inSession then
        ATM.SetState(ATM.State.PIN_ENTRY)
        ATM_DUI.SetScreen('pin_entry', { attempts = Config.PIN.maxAttempts - ATM.pinAttempts })
    end
end

-- Start ATM session when no card is present
function ATM.StartNoCardSession(atmEntity)
    if ATM.inSession then return end
    
    ATM.inSession = true
    ATM.currentATM = atmEntity
    ATM.pinAttempts = 0
    ATM.enteredPIN = ''
    ATM.enteredAmount = ''
    ATM.transferAccount = ''
    
    -- Get player data
    local playerData = { name = ATM.startInfo and ATM.startInfo.name or '', bank = 0 }
    ATM.sessionData = playerData
    
    -- Apply DUI texture
    local atmModel = GetEntityModel(atmEntity)
    ATM_DUI.ApplyTexture(atmModel)
    
    -- Initialize DUI session
    ATM_DUI.InitSession(playerData)
    
    -- Transition camera
    ATM_Camera.TransitionTo(atmEntity)
    
    ATM.SetState(ATM.State.NO_CARD)
    ATM_DUI.SetScreen('no_card', { cost = Config.PIN.cardCreationCost })
end

-- End ATM session
function ATM.EndSession()
    if not ATM.inSession then return end
    
    TriggerServerEvent('atmdui:endSession')

    -- Show card eject screen
    ATM.SetState(ATM.State.CARD_EJECT)
    ATM_DUI.SetScreen('card_eject')
    
    -- Play sound
    ATM.PlaySound('cardEject')
    
    Wait(1500)
    
    ATM.inSession = false
    ATM.currentATM = nil
    ATM.currentState = ATM.State.IDLE
    ATM.sessionData = {}
    ATM.enteredPIN = ''
    ATM.enteredAmount = ''
    ATM.transferAccount = ''
    ATM.lastTransaction = nil
    
    -- End DUI session
    ATM_DUI.EndSession()
    
    -- Remove texture replacement
    ATM_DUI.RemoveTexture()
    
    -- Transition camera back
    ATM_Camera.TransitionBack()
end

-- Set ATM state (no layout needed — physical buttons are always the same)
function ATM.SetState(state)
    ATM.currentState = state
end

-- Play ATM sound
function ATM.PlaySound(soundType)
    if not Config.Sounds.enabled then return end
    
    local sounds = {
        cardInsert = { name = 'PIN_BUTTON', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        cardEject = { name = 'PIN_BUTTON', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        keyPress = { name = 'SELECT', ref = 'HUD_MINI_GAME_SOUNDSET' },
        success = { name = 'WAYPOINT_SET', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        error = { name = 'ERROR', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        cashDispense = { name = 'PICK_UP', ref = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    }
    
    local sound = sounds[soundType]
    if sound then
        PlaySoundFrontend(-1, sound.name, sound.ref, false)
    end
end

-- Play animation
function ATM.PlayAnimation(animType)
    local ped = PlayerPedId()
    
    if animType == 'cardInsert' then
        loadDict(Config.Animation.cardDict)
        TaskPlayAnim(ped, Config.Animation.cardDict, Config.Animation.cardAnim, 8.0, -8.0, -1, 0, 0, false, false, false)
    elseif animType == 'idle' then
        loadDict(Config.Animation.dict)
        TaskPlayAnim(ped, Config.Animation.dict, Config.Animation.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

-- Handle PIN entry
function ATM.EnterPINDigit(digit)
    if ATM.currentState ~= ATM.State.PIN_ENTRY and ATM.currentState ~= ATM.State.CREATE_CARD_PIN then return end
    if #ATM.enteredPIN >= Config.PIN.length then return end
    
    ATM.enteredPIN = ATM.enteredPIN .. tostring(digit)
    ATM.PlaySound('keyPress')
    
    ATM_DUI.SendMessage('PIN_UPDATE', { length = #ATM.enteredPIN })
end

-- Clear PIN
function ATM.ClearPIN()
    ATM.enteredPIN = ''
    ATM.PlaySound('keyPress')
    ATM_DUI.SendMessage('PIN_UPDATE', { length = 0 })
end

-- Submit PIN
function ATM.SubmitPIN()
    if ATM.currentState ~= ATM.State.PIN_ENTRY then return end
    if #ATM.enteredPIN ~= Config.PIN.length then return end
    
    ATM.SetState(ATM.State.PROCESSING)
    ATM_DUI.SetProcessing(true)
    
    -- Verify PIN with server
    local success, data = Whip.core:Callback('atmdui:verifyPIN', ATM.enteredPIN)
    if success and type(data) == 'table' then
        ATM.sessionData.name = data.name or ATM.sessionData.name
        ATM.sessionData.bank = data.bank or 0
    end
    
    ATM_DUI.SetProcessing(false)
    
    if success then
        ATM.PlaySound('success')
        ATM.pinAttempts = 0
        ATM.SetState(ATM.State.MAIN_MENU)
        ATM_DUI.SetScreen('main_menu', { 
            name = ATM.sessionData.name,
            balance = ATM.sessionData.bank 
        })
    else
        ATM.PlaySound('error')
        ATM.pinAttempts = ATM.pinAttempts + 1
        ATM.enteredPIN = ''
        
        if ATM.pinAttempts >= Config.PIN.maxAttempts then
            ATM.lockedUntil = GetGameTimer() + (Config.PIN.lockoutTime * 1000)
            ATM_DUI.ShowNotification(Locale('card_locked'), 'error')
            Wait(2000)
            ATM.EndSession()
        else
            ATM_DUI.SetScreen('pin_entry', { 
                attempts = Config.PIN.maxAttempts - ATM.pinAttempts,
                error = true 
            })
            ATM.SetState(ATM.State.PIN_ENTRY)
        end
    end
end

-- Handle amount entry
function ATM.EnterAmountDigit(digit)
    if ATM.currentState ~= ATM.State.WITHDRAW_AMOUNT and 
       ATM.currentState ~= ATM.State.DEPOSIT_AMOUNT and
       ATM.currentState ~= ATM.State.TRANSFER_AMOUNT then 
        return 
    end
    
    if #ATM.enteredAmount >= 8 then return end
    
    ATM.enteredAmount = ATM.enteredAmount .. tostring(digit)
    ATM.PlaySound('keyPress')
    
    ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = ATM.enteredAmount })
end

-- Clear amount
function ATM.ClearAmount()
    ATM.enteredAmount = ''
    ATM.PlaySound('keyPress')
    ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = '0' })
end

-- Handle transfer account entry
function ATM.EnterAccountDigit(digit)
    if ATM.currentState ~= ATM.State.TRANSFER_ACCOUNT then return end
    if #ATM.transferAccount >= 15 then return end
    
    ATM.transferAccount = ATM.transferAccount .. tostring(digit)
    ATM.PlaySound('keyPress')
    
    ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = ATM.transferAccount })
end

-- Clear transfer account
function ATM.ClearAccount()
    ATM.transferAccount = ''
    ATM.PlaySound('keyPress')
    ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = '0' })
end

-- Process withdrawal
function ATM.ProcessWithdraw(amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        ATM_DUI.ShowNotification(Locale('invalid_amount'), 'error')
        return
    end
    
    if amount > Config.Transactions.maxWithdraw then
        ATM_DUI.ShowNotification(Locale('invalid_amount'), 'error')
        return
    end
    
    ATM.SetState(ATM.State.PROCESSING)
    ATM_DUI.SetProcessing(true)
    
    local success, newBalance, message = Whip.core:Callback('atmdui:withdraw', amount)
    
    ATM_DUI.SetProcessing(false)
    
    if success then
        SendNUIMessage({ action = 'playSound', sound = 'dispenser' })
        if ATM_DUI and ATM_DUI.SendMessage then
            ATM_DUI.SendMessage('playSound', { sound = 'dispenser' })
        end
        
        ATM_DUI.SetProcessing(true, 11000)
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 11000 do
            local percent = ((GetGameTimer() - startTime) / 11000.0) * 100
            if ATM_DUI and ATM_DUI.SendMessage then
                ATM_DUI.SendMessage('UPDATE_PROGRESS', { progress = percent })
            end
            Wait(100)
        end
        ATM_DUI.SetProcessing(false)

        ATM.sessionData.bank = newBalance
        ATM.lastTransaction = { type = 'withdraw', amount = amount }
        ATM.SetState(ATM.State.SUCCESS)
        ATM_DUI.SetScreen('success', {
            message = Locale('take_cash'),
            amount = amount,
            newBalance = newBalance
        })
        
        -- Trigger cash dispensing visual
        CreateThread(function()
            ATM.DispenseCash(amount)
        end)
        
        Wait(2000)
        ATM.ShowReceiptPrompt()
    else
        ATM.PlaySound('error')
        ATM_DUI.ShowNotification(message or Locale('error'), 'error')
        ATM.SetState(ATM.State.MAIN_MENU)
        ATM_DUI.SetScreen('main_menu', { 
            name = ATM.sessionData.name,
            balance = ATM.sessionData.bank 
        })
    end
end

-- Process deposit
function ATM.ProcessDeposit(amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        ATM_DUI.ShowNotification(Locale('invalid_amount'), 'error')
        return
    end
    
    if amount > Config.Transactions.maxDeposit then
        ATM_DUI.ShowNotification(Locale('invalid_amount'), 'error')
        return
    end
    
    ATM.SetState(ATM.State.PROCESSING)
    ATM_DUI.SetProcessing(true)
    
    local success, newBalance, message = Whip.core:Callback('atmdui:deposit', amount)
    
    ATM_DUI.SetProcessing(false)
    
    if success then
        SendNUIMessage({ action = 'playSound', sound = 'dispenser' })
        if ATM_DUI and ATM_DUI.SendMessage then
            ATM_DUI.SendMessage('playSound', { sound = 'dispenser' })
        end
        
        ATM_DUI.SetProcessing(true, 8000)
        
        -- Start deposit visuals parallel to progress bar
        CreateThread(function()
            Wait(1000)
            ATM.DepositCashVisual(amount)
        end)
        
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 8000 do
            local percent = ((GetGameTimer() - startTime) / 8000.0) * 100
            if ATM_DUI and ATM_DUI.SendMessage then
                ATM_DUI.SendMessage('UPDATE_PROGRESS', { progress = percent })
            end
            Wait(100)
        end
        ATM_DUI.SetProcessing(false)

        ATM.sessionData.bank = newBalance
        ATM.lastTransaction = { type = 'deposit', amount = amount }
        ATM.SetState(ATM.State.SUCCESS)
        ATM_DUI.SetScreen('success', {
            message = Locale('transaction_complete'),
            amount = amount,
            newBalance = newBalance
        })
        
        Wait(2000)
        ATM.ShowReceiptPrompt()
    else
        ATM.PlaySound('error')
        ATM_DUI.ShowNotification(message or Locale('error'), 'error')
        ATM.SetState(ATM.State.MAIN_MENU)
        ATM_DUI.SetScreen('main_menu', { 
            name = ATM.sessionData.name,
            balance = ATM.sessionData.bank 
        })
    end
end

-- Process transfer
function ATM.ProcessTransfer(targetAccount, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        ATM_DUI.ShowNotification(Locale('invalid_amount'), 'error')
        return
    end
    
    if amount > Config.Transactions.maxTransfer then
        ATM_DUI.ShowNotification(Locale('invalid_amount'), 'error')
        return
    end
    
    ATM.SetState(ATM.State.PROCESSING)
    ATM_DUI.SetProcessing(true)
    
    local success, newBalance, message = Whip.core:Callback('atmdui:transfer', targetAccount, amount)
    
    ATM_DUI.SetProcessing(false)
    
    if success then
        ATM.PlaySound('success')
        ATM.sessionData.bank = newBalance
        ATM.lastTransaction = { type = 'transfer', amount = amount, to = targetAccount }
        ATM.SetState(ATM.State.SUCCESS)
        ATM_DUI.SetScreen('success', {
            message = Locale('transaction_complete'),
            amount = amount,
            newBalance = newBalance
        })
        
        Wait(2000)
        ATM.ShowReceiptPrompt()
    else
        ATM.PlaySound('error')
        ATM_DUI.ShowNotification(message or Locale('error'), 'error')
        ATM.SetState(ATM.State.MAIN_MENU)
        ATM_DUI.SetScreen('main_menu', { 
            name = ATM.sessionData.name,
            balance = ATM.sessionData.bank 
        })
    end
end

-- Show receipt prompt
function ATM.ShowReceiptPrompt()
    ATM.SetState(ATM.State.RECEIPT)
    ATM_DUI.SetScreen('receipt_prompt')
end

-- Handle receipt choice
function ATM.HandleReceiptChoice(wantsReceipt)
    if wantsReceipt then
        -- Trigger server event to give receipt item
        local info = {
            type = ATM.lastTransaction and ATM.lastTransaction.type or 'unknown',
            amount = ATM.lastTransaction and ATM.lastTransaction.amount or 0,
            account = ATM.lastTransaction and ATM.lastTransaction.to or 'N/A',
            balance = ATM.sessionData.bank or 0
        }
        TriggerServerEvent('atmdui:receipt')
    end
    
    -- Return to main menu
    ATM.SetState(ATM.State.MAIN_MENU)
    ATM_DUI.SetScreen('main_menu', { 
        name = ATM.sessionData.name,
        balance = ATM.sessionData.bank 
    })
end

-- Check balance
function ATM.CheckBalance()
    ATM.SetState(ATM.State.BALANCE)
    ATM_DUI.SetScreen('balance', {
        balance = ATM.sessionData.bank,
        name = ATM.sessionData.name
    })
end

-- Handle button clicks from physical ATM keypad
-- Buttons: pin_0 through pin_9, pin_clear, pin_enter (keypad)
--          side_l1-l4, side_r1-r4 (screen side buttons)
-- Different states interpret them differently (contextual mapping)
AddEventHandler('atmdui:client:buttonClicked', function(buttonId)
    if not ATM.inSession then return end
    
    -- Extract digit from button ID (keypad numbers)
    local digit = nil
    if buttonId:match('^pin_%d$') then
        digit = tonumber(buttonId:match('pin_(%d)'))
    elseif buttonId == 'pin_0' then
        digit = 0
    end
    
    -- Map side buttons to menu position (1-4)
    local sidePos = nil
    if buttonId:match('^side_l(%d)$') then
        sidePos = tonumber(buttonId:match('side_l(%d)'))
    elseif buttonId:match('^side_r(%d)$') then
        sidePos = tonumber(buttonId:match('side_r(%d)'))
    end
    
    -- Handle based on current state
    if ATM.currentState == ATM.State.PIN_ENTRY then
        -- Direct digit-to-PIN mapping
        if digit ~= nil then
            ATM.EnterPINDigit(digit)
        elseif buttonId == 'pin_clear' then
            ATM.ClearPIN()
        elseif buttonId == 'pin_enter' or buttonId == 'side_r3' then
            ATM.SubmitPIN()
        end
        
    elseif ATM.currentState == ATM.State.CREATE_CARD_PIN then
        if digit ~= nil then
            ATM.EnterPINDigit(digit)
        elseif buttonId == 'pin_clear' then
            ATM.ClearPIN()
        elseif buttonId == 'pin_enter' or buttonId == 'side_r3' then
            if #ATM.enteredPIN == Config.PIN.length then
                ATM.SetState(ATM.State.PROCESSING)
                ATM_DUI.SetProcessing(true)
                
                local success = Whip.core:Callback('atmdui:createCard', ATM.enteredPIN)
                ATM_DUI.SetProcessing(false)
                
                if success then
                    ATM.PlaySound('success')
                    ATM_DUI.ShowNotification("Kart başarıyla oluşturuldu!", "success")
                    CreateThread(function()
                        ATM.CreateCardVisual(ATM.currentATM)
                    end)
                    Wait(2000)
                    ATM.EndSession()
                else
                    ATM.PlaySound('error')
                    ATM_DUI.ShowNotification("Kart oluşturulamadı", "error")
                    ATM.enteredPIN = ''
                    ATM.SetState(ATM.State.CREATE_CARD_PIN)
                    ATM_DUI.SetScreen('pin_entry', { attempts = -1, title = "YENİ PIN BELİRLE", error = true })
                end
            end
        end

    elseif ATM.currentState == ATM.State.NO_CARD then
        if buttonId == 'side_r4' then
            ATM.SetState(ATM.State.CREATE_CARD_PIN)
            ATM_DUI.SetScreen('pin_entry', { attempts = -1, title = "YENİ PIN BELİRLE" })
        elseif buttonId == 'side_l4' or buttonId == 'pin_clear' then
            ATM.EndSession()
        end

    elseif ATM.currentState == ATM.State.MAIN_MENU then
        -- Numbered menu: 1=Withdraw, 2=Deposit, 3=Transfer, 4=Balance
        -- CANCEL (pin_clear) = Exit
        
        local menuChoice = digit
        if buttonId == 'side_l1' then menuChoice = 1
        elseif buttonId == 'side_l2' then menuChoice = 2
        elseif buttonId == 'side_l3' then menuChoice = 3
        elseif buttonId == 'side_l4' then menuChoice = 4
        end

        if menuChoice == 1 then
            ATM.SetState(ATM.State.WITHDRAW)
            ATM_DUI.SetScreen('withdraw', { 
                quickAmounts = Config.Transactions.quickAmounts,
                balance = ATM.sessionData.bank 
            })
        elseif menuChoice == 2 then
            ATM.SetState(ATM.State.DEPOSIT_AMOUNT)
            ATM_DUI.SetScreen('deposit', { balance = ATM.sessionData.bank })
            ATM.enteredAmount = ''
        elseif menuChoice == 3 then
            ATM.SetState(ATM.State.TRANSFER_ACCOUNT)
            ATM_DUI.SetScreen('transfer_account')
            ATM.transferAccount = ''
        elseif menuChoice == 4 then
            ATM.CheckBalance()
        elseif buttonId == 'pin_clear' or buttonId == 'side_r4' then
            ATM.EndSession()
        end
        
    elseif ATM.currentState == ATM.State.WITHDRAW then
        -- Quick amounts mapping matching App.tsx SideBtn layout:
        -- L1=1, L2=2, L3=3, L4=4, R1=5
        local quickChoice = digit
        if buttonId == 'side_l1' then quickChoice = 1
        elseif buttonId == 'side_l2' then quickChoice = 2
        elseif buttonId == 'side_l3' then quickChoice = 3
        elseif buttonId == 'side_l4' then quickChoice = 4
        elseif buttonId == 'side_r1' then quickChoice = 5
        end

        if quickChoice and quickChoice >= 1 and quickChoice <= #Config.Transactions.quickAmounts then
            local amount = Config.Transactions.quickAmounts[quickChoice]
            if amount then
                ATM.ProcessWithdraw(amount)
            end
        elseif digit == 6 or buttonId == 'side_r2' then
            -- "Other amount" option (key 6 or side_r2)
            ATM.SetState(ATM.State.WITHDRAW_AMOUNT)
            ATM_DUI.SetScreen('withdraw_amount', { balance = ATM.sessionData.bank })
            ATM.enteredAmount = ''
        elseif buttonId == 'pin_clear' or buttonId == 'side_r4' then
            ATM.SetState(ATM.State.MAIN_MENU)
            ATM_DUI.SetScreen('main_menu', { 
                name = ATM.sessionData.name,
                balance = ATM.sessionData.bank 
            })
        end
        
    elseif ATM.currentState == ATM.State.WITHDRAW_AMOUNT or 
           ATM.currentState == ATM.State.DEPOSIT_AMOUNT or
           ATM.currentState == ATM.State.TRANSFER_AMOUNT then
        -- Digit entry mode for amounts
        if digit ~= nil then
            ATM.EnterAmountDigit(digit)
          elseif buttonId == 'pin_clear' then
              ATM.ClearAmount()
          elseif buttonId == 'side_r4' then
              -- Cancel entirely, go to main menu
              ATM.SetState(ATM.State.MAIN_MENU)
              ATM_DUI.SetScreen('main_menu', { 
                  name = ATM.sessionData.name,
                  balance = ATM.sessionData.bank 
              })
              ATM.enteredAmount = ''
              ATM.transferAccount = ''
              ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = '0' })
          elseif buttonId == 'pin_enter' or buttonId == 'side_r3' then
              local amount = tonumber(ATM.enteredAmount)
              if ATM.currentState == ATM.State.WITHDRAW_AMOUNT then
                  ATM.ProcessWithdraw(amount)
              elseif ATM.currentState == ATM.State.DEPOSIT_AMOUNT then
                  ATM.ProcessDeposit(amount)
              elseif ATM.currentState == ATM.State.TRANSFER_AMOUNT then
                  ATM.ProcessTransfer(ATM.transferAccount, amount)
              end
          end
      
      elseif ATM.currentState == ATM.State.TRANSFER_ACCOUNT then
          -- Digit entry for account number
          if digit ~= nil then
              ATM.EnterAccountDigit(digit)
          elseif buttonId == 'pin_clear' then
              ATM.ClearAccount()
          elseif buttonId == 'side_r4' then
              ATM.SetState(ATM.State.MAIN_MENU)
              ATM_DUI.SetScreen('main_menu', { 
                  name = ATM.sessionData.name,
                  balance = ATM.sessionData.bank 
              })
              ATM.transferAccount = ''
              ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = '0' })
          elseif buttonId == 'pin_enter' or buttonId == 'side_r3' then
              if #ATM.transferAccount > 0 then
                  ATM.SetState(ATM.State.TRANSFER_AMOUNT)
                  ATM_DUI.SetScreen('transfer_amount', { 
                      account = ATM.transferAccount,
                      balance = ATM.sessionData.bank
                  })
                  ATM.enteredAmount = ''
                  ATM_DUI.SendMessage('AMOUNT_UPDATE', { value = '0' })
              end
          elseif buttonId == 'pin_cancel' or buttonId == 'side_r4' then
              ATM.SetState(ATM.State.MAIN_MENU)
              ATM_DUI.SetScreen('main_menu', { 
                  name = ATM.sessionData.name,
                  balance = ATM.sessionData.bank 
              })
          end
        
    elseif ATM.currentState == ATM.State.RECEIPT then
        -- L1 = Yes, R4 = No (or ENTER=Yes, CANCEL=No, keypad 1=Yes, 2=No)
        if digit == 1 or buttonId == 'pin_enter' or buttonId == 'side_l1' then
            ATM.HandleReceiptChoice(true)
        elseif digit == 2 or buttonId == 'pin_clear' or buttonId == 'side_r4' then
            ATM.HandleReceiptChoice(false)
        end
    end
end)

-- Handle session ended from camera
AddEventHandler('atmdui:client:sessionEnded', function()
    if ATM.inSession then
        TriggerServerEvent('atmdui:endSession')   -- Esc at the keypad: the server's session ends too
        ATM.inSession = false
        ATM.currentATM = nil
        ATM.currentState = ATM.State.IDLE
        ATM.sessionData = {}
        ATM_DUI.EndSession()
        ATM_DUI.RemoveTexture()
    end
end)

-- NUI Callbacks (kept for alternative keyboard input if needed)
RegisterNUICallback('pinInput', function(data, cb)
    if data.digit then
        ATM.EnterPINDigit(data.digit)
    elseif data.action == 'clear' then
        ATM.ClearPIN()
    elseif data.action == 'submit' then
        ATM.SubmitPIN()
    end
    cb('ok')
end)

RegisterNUICallback('amountInput', function(data, cb)
    if data.digit then
        ATM.EnterAmountDigit(data.digit)
    elseif data.action == 'clear' then
        ATM.ClearAmount()
    end
    cb('ok')
end)

RegisterNUICallback('menuAction', function(data, cb)
    TriggerEvent('atmdui:client:buttonClicked', data.action)
    cb('ok')
end)

RegisterNUICallback('closeATM', function(_, cb)
    ATM.EndSession()
    cb('ok')
end)

RegisterNetEvent('atmdui:client:viewReceipt', function(info)
    SetNuiFocus(true, true)
    Whip.core:SetScreenOpen(true, 'receipt')
    SendNUIMessage({
        action = 'SET_SCREEN',
        data = {
            screen = 'receipt_view',
            data = info
        }
    })
end)

RegisterNUICallback('closeReceipt', function(data, cb)
    SetNuiFocus(false, false)
    Whip.core:SetScreenOpen(false, 'receipt')
    if cb then cb({}) end
end)

-- Export ATM module
_G.ATM_Client = ATM
