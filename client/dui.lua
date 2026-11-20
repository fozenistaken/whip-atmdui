local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

local DUI = {}
DUI.duiObject = nil
DUI.duiHandle = nil
DUI.txdName = nil
DUI.texName = nil
DUI.isActive = false
DUI.appliedTexture = nil
DUI.currentTextureIdx = 1

local TextureCandidates = {
    ['prop_atm_01'] = {
        { dict = 'prop_atm_01', name = 'prop_cashpoint_screen' },
        { dict = 'prop_atm_01', name = 'prop_cashpoint_01' },
    },
    ['prop_atm_02'] = {
        { dict = 'prop_atm_02', name = 'prop_cashpoint_screen' },
        { dict = 'prop_atm_02', name = 'prop_cashpoint_02b' },
    },
    ['prop_atm_03'] = {
        { dict = 'prop_atm_03', name = 'prop_cashpoint_screen' },
        { dict = 'prop_atm_03', name = 'prop_cashpoint_02b' },
    },
    ['prop_fleeca_atm'] = {
        { dict = 'prop_fleeca_atm', name = 'prop_fleece_emis' },
        { dict = 'prop_fleeca_atm', name = 'prop_fleece_atm' },
    },
}

DUI.currentModel = nil

function DUI.Create()
    if DUI.duiObject then return end

    local url = ('nui://%s/html/index.html?dui=true'):format(GetCurrentResourceName())
    local width = Config.DUI.width or 512
    local height = Config.DUI.height or 512

    print('^3[atm-dui] Creating DUI with URL: ' .. url .. '^0')

    DUI.duiObject = CreateDui(url, width, height)

    if not DUI.duiObject then
        print('^1[atm-dui] Failed to create DUI object!^0')
        return false
    end

    DUI.duiHandle = GetDuiHandle(DUI.duiObject)

    DUI.txdName = 'atm_dui_txd'
    DUI.texName = 'atm_dui_tex'

    local txd = CreateRuntimeTxd(DUI.txdName)

    Wait(250)

    CreateRuntimeTextureFromDuiHandle(txd, DUI.texName, DUI.duiHandle)

    print('^2[atm-dui] DUI created successfully^0')
    print('^2[atm-dui] TXD: ' .. DUI.txdName .. ', TEX: ' .. DUI.texName .. '^0')

    Wait(500)

    return true
end

function DUI.ApplyTexture(atmModel)
    if not DUI.duiObject then
        if not DUI.Create() then
            return false
        end
    end

    local modelName = nil
    for _, model in ipairs(Config.ATMModels) do
        if GetHashKey(model) == atmModel then
            modelName = model
            break
        end
    end

    if not modelName then
        print('^1[atm-dui] Unknown ATM model: ' .. atmModel .. '^0')
        return false
    end

    local candidates = TextureCandidates[modelName]
    if not candidates or #candidates == 0 then
        print('^1[atm-dui] No texture candidates for: ' .. modelName .. '^0')
        return false
    end

    DUI.currentModel = modelName

    DUI.SendMessage('SET_MODEL', { model = modelName, rows = DUI.RowsFor(modelName) })

    local candidate = candidates[DUI.currentTextureIdx]
    if not candidate then
        DUI.currentTextureIdx = 1
        candidate = candidates[1]
    end

    print('^3[atm-dui] Applying texture replacement: ' .. candidate.dict .. '/' .. candidate.name .. ' (candidate ' .. DUI.currentTextureIdx .. '/' .. #candidates .. ')^0')

    if DUI.appliedTexture then
        RemoveReplaceTexture(DUI.appliedTexture.dict, DUI.appliedTexture.name)
    end

    AddReplaceTexture(candidate.dict, candidate.name, DUI.txdName, DUI.texName)
    DUI.appliedTexture = candidate
    DUI.isActive = true

    return true
end

function DUI.RowsFor(modelName)
    local rows = Config.ScreenRows or {}
    return rows[modelName] or rows.default
end

local calibrating = false
RegisterCommand('atmrows', function(_, args)
    if not exports.whip_core:HasDevTools() then return end
    if not DUI.currentModel then
        print('[atmdui] use an ATM first (atmrows works while you are at its keypad)')
        return
    end
    local side = args[1]
    if side == 'left' or side == 'right' then
        local rows = DUI.RowsFor(DUI.currentModel)
        local copy = { left = { table.unpack(rows.left) }, right = { table.unpack(rows.right) } }
        for i = 1, 4 do copy[side][i] = tonumber(args[i + 1]) or copy[side][i] end
        Config.ScreenRows[DUI.currentModel] = copy
        DUI.SendMessage('SET_ROWS', { rows = copy })
        print(("[atmdui] Config.ScreenRows: ['%s'] = { left = { %s }, right = { %s } },"):format(DUI.currentModel,
            table.concat(copy.left, ', '), table.concat(copy.right, ', ')))
        return
    end
    calibrating = not calibrating
    DUI.SendMessage('CALIBRATE', { on = calibrating })
    print('[atmdui] calibration ' .. (calibrating and 'on' or 'off') .. ' for ' .. DUI.currentModel)
end, false)

function DUI.RemoveTexture()
    if not DUI.isActive or not DUI.appliedTexture then return end

    RemoveReplaceTexture(DUI.appliedTexture.dict, DUI.appliedTexture.name)
    DUI.appliedTexture = nil
    DUI.isActive = false
    DUI.currentModel = nil
end

function DUI.SendMessage(action, data)
    if not DUI.duiObject then return end

    local message = json.encode({
        action = action,
        data = data
    })

    SendDuiMessage(DUI.duiObject, message)
end

function DUI.SetScreen(screen, data)
    DUI.SendMessage('SET_SCREEN', {
        screen = screen,
        data = data or {}
    })
end

function DUI.ShowNotification(message, type)
    DUI.SendMessage('NOTIFICATION', {
        message = message,
        type = type or 'info'
    })
end

function DUI.SetProcessing(isProcessing, duration)
    DUI.SendMessage('SET_PROCESSING', { processing = isProcessing, duration = duration })
end

function DUI.HighlightButton(buttonId)
    DUI.SendMessage('HIGHLIGHT_BUTTON', { buttonId = buttonId })
end

function DUI.ClickButton(buttonId)
    DUI.SendMessage('CLICK_BUTTON', { buttonId = buttonId })
end

function DUI.InitSession(playerData)
    DUI.SendMessage('INIT_SESSION', {
        playerName = playerData.name,
        bankBalance = playerData.bank,
        bankName = Config.UI.bankName,
        quickAmounts = Config.Transactions.quickAmounts,
        maxWithdraw = Config.Transactions.maxWithdraw,
        maxDeposit = Config.Transactions.maxDeposit,
        locale = Config.Locales[Config.UI.language] or Config.Locales['en'],
        language = Config.Locales[Config.UI.language] and Config.UI.language or 'en',
    })
end

function DUI.EndSession()
    DUI.SendMessage('END_SESSION', {})
    DUI.SetScreen('welcome')
end

function DUI.Destroy()
    DUI.RemoveTexture()
    if DUI.duiObject then
        DestroyDui(DUI.duiObject)
        DUI.duiObject = nil
        DUI.duiHandle = nil
    end
    DUI.isActive = false
end

_G.ATM_DUI = DUI

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DUI.Destroy()
end)
