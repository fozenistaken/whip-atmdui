-- atmdui for WHIP. Values here are the defaults: server owners change the money and PIN settings in game
-- (/whip -> Settings -> ATM, shared/settings.lua). Money goes through WHIP's bank (the card's account).
Config = {}

Config.Debug = false -- Enable debug prints

-- ATM Models that will have DUI applied
Config.ATMModels = {
    'prop_atm_01',
    'prop_atm_02', 
    'prop_atm_03',
    'prop_fleeca_atm'
}

-- Prop positioning by ATM Model (X = Left/Right, Y = Forward/Back, Z = Up/Down)
Config.PropOffsets = {
    ['prop_fleeca_atm'] = {
        dispense = { x = -0.11, startY = 0.15, endY = -0.15, z = 0.95 },
        deposit = { x = -0.10, startY = -0.15, endY = 0.15, z = 0.95 },
        card = { x = 0.25, startY = -0.10, endY = 0.20, z = 1.2 },
        createCard = { x = 0.25, startY = 0.20, endY = -0.10, z = 1.2 }
    },
    ['prop_atm_01'] = {
        dispense = { x = -0.05, startY = -0.20, endY = -0.35, z = 0.75 },
        deposit = { x = -0.05, startY = -0.35, endY = -0.20, z = 0.95 },
        card = { x = 0.20, startY = -0.25, endY = 0.05, z = 1.12 },
        createCard = { x = 0.20, startY = 0.05, endY = -0.25, z = 1.12 }
    },
    ['prop_atm_02'] = {
        dispense = { x = -0.11, startY = 0.15, endY = -0.15, z = 0.95 },
        deposit = { x = -0.10, startY = -0.15, endY = 0.15, z = 0.95 },
        card = { x = 0.25, startY = -0.10, endY = 0.20, z = 1.20 },
        createCard = { x = 0.25, startY = 0.20, endY = -0.10, z = 1.20 }
    },
    ['prop_atm_03'] = {
        dispense = { x = -0.11, startY = 0.15, endY = -0.15, z = 0.95 },
        deposit = { x = -0.10, startY = -0.15, endY = 0.15, z = 0.95 },
        card = { x = 0.25, startY = -0.10, endY = 0.20, z = 1.2 },
        createCard = { x = 0.25, startY = 0.20, endY = -0.10, z = 1.2 }
    }
}

-- Texture replacement settings
Config.TextureDict = 'prop_atm_01'
Config.TextureName = 'atm_screen'

-- DUI Settings
Config.DUI = {
    width = 1326,
    height = 1004,
}

-- Camera Settings
Config.Camera = {
    transitionTime = 500,       -- ms for camera transition
    fov = 45.0,                 -- Field of view (slightly narrower for better framing)
    distance = 0.65,            -- Distance from ATM (slightly further for full view)
    heightOffset = 1.45,        -- Height offset (player eye-level, ~1.55m from ATM base)
    sideOffset = -0.1,           -- Side offset (Left/Right)
    initialPitch = -15.0,       -- Initial downward angle (negative = looking down at ATM)
    mouseSensitivity = 4.0,     -- Camera rotation sensitivity
    -- Rotation limits (degrees from initial rotation)
    pitchUp = 18.0,             -- How far up from initial (to see top of screen)
    pitchDown = 55.0,           -- How far down from initial (to reach bottom keypad row)
    yawRange = 30.0,            -- How far left/right from initial (wide enough for side buttons)
}

-- Physical ATM Keypad Button Positions
-- Each button is defined as a 3D offset (x, y, z) from the ATM entity origin.
-- These offsets are in the ATM entity's local coordinate system.
-- They get quaternion-rotated by the entity heading to produce world positions,
-- then projected to screen coordinates to check if the crosshair (screen center) is near them.
Config.ButtonProximity = 0.027  -- Screen-space distance threshold for hit detection

-- Button offsets per ATM model (from benite-atm reference, verified accurate)
Config.ButtonOffsets = {
    ['prop_fleeca_atm'] = {
        -- Side buttons (left and right of screen)
        { id = 'side_l1', offset = vector3(-0.306, 0.1, 1.23) },
        { id = 'side_l2', offset = vector3(-0.306, 0.095, 1.17) },
        { id = 'side_l3', offset = vector3(-0.306, 0.09, 1.11) },
        { id = 'side_l4', offset = vector3(-0.306, 0.08, 1.06) },
        { id = 'side_r1', offset = vector3(0.065, 0.1, 1.23) },
        { id = 'side_r2', offset = vector3(0.065, 0.095, 1.17) },
        { id = 'side_r3', offset = vector3(0.064, 0.085, 1.11) },
        { id = 'side_r4', offset = vector3(0.063, 0.07, 1.055) },
        -- Number pad
        { id = 'pin_1',     offset = vector3(-0.173, 0.0, 0.88) },
        { id = 'pin_2',     offset = vector3(-0.145, 0.0, 0.88) },
        { id = 'pin_3',     offset = vector3(-0.122, 0.0, 0.88) },
        { id = 'pin_4',     offset = vector3(-0.173, -0.04, 0.87) },
        { id = 'pin_5',     offset = vector3(-0.145, -0.04, 0.87) },
        { id = 'pin_6',     offset = vector3(-0.122, -0.04, 0.87) },
        { id = 'pin_7',     offset = vector3(-0.173, -0.075, 0.865) },
        { id = 'pin_8',     offset = vector3(-0.145, -0.075, 0.865) },
        { id = 'pin_9',     offset = vector3(-0.122, -0.075, 0.865) },
        { id = 'pin_0',     offset = vector3(-0.145, -0.12, 0.865) },
        { id = 'pin_clear', offset = vector3(-0.182, -0.12, 0.865) },
        { id = 'pin_enter', offset = vector3(-0.108, -0.12, 0.865) },
    },
    ['prop_atm_01'] = {
        { id = 'side_l1', offset = vector3(-0.19, -0.11, 1.14) },
        { id = 'side_l2', offset = vector3(-0.19, -0.115, 1.1) },
        { id = 'side_l3', offset = vector3(-0.19, -0.122, 1.06) },
        { id = 'side_l4', offset = vector3(-0.19, -0.129, 1.02) },
        { id = 'side_r1', offset = vector3(0.084, -0.11, 1.14) },
        { id = 'side_r2', offset = vector3(0.084, -0.115, 1.1) },
        { id = 'side_r3', offset = vector3(0.084, -0.122, 1.06) },
        { id = 'side_r4', offset = vector3(0.084, -0.129, 1.02) },
        { id = 'pin_1',     offset = vector3(-0.089, -0.18, 0.89) },
        { id = 'pin_2',     offset = vector3(-0.058, -0.18, 0.89) },
        { id = 'pin_3',     offset = vector3(-0.027, -0.18, 0.89) },
        { id = 'pin_4',     offset = vector3(-0.089, -0.2, 0.87) },
        { id = 'pin_5',     offset = vector3(-0.058, -0.2, 0.87) },
        { id = 'pin_6',     offset = vector3(-0.027, -0.2, 0.87) },
        { id = 'pin_7',     offset = vector3(-0.089, -0.22, 0.855) },
        { id = 'pin_8',     offset = vector3(-0.058, -0.22, 0.855) },
        { id = 'pin_9',     offset = vector3(-0.027, -0.22, 0.855) },
        { id = 'pin_0',     offset = vector3(-0.058, -0.243, 0.838) },
        { id = 'pin_clear', offset = vector3(-0.089, -0.243, 0.838) },
        { id = 'pin_enter', offset = vector3(-0.027, -0.243, 0.838) },
    },
    ['prop_atm_02'] = {
        { id = 'side_l1', offset = vector3(-0.306, 0.1, 1.23) },
        { id = 'side_l2', offset = vector3(-0.306, 0.095, 1.17) },
        { id = 'side_l3', offset = vector3(-0.306, 0.09, 1.11) },
        { id = 'side_l4', offset = vector3(-0.306, 0.076, 1.05) },
        { id = 'side_r1', offset = vector3(0.065, 0.1, 1.23) },
        { id = 'side_r2', offset = vector3(0.065, 0.095, 1.17) },
        { id = 'side_r3', offset = vector3(0.064, 0.085, 1.11) },
        { id = 'side_r4', offset = vector3(0.063, 0.07, 1.055) },
        { id = 'pin_1',     offset = vector3(-0.173, 0.0, 0.88) },
        { id = 'pin_2',     offset = vector3(-0.145, 0.0, 0.88) },
        { id = 'pin_3',     offset = vector3(-0.122, 0.0, 0.88) },
        { id = 'pin_4',     offset = vector3(-0.173, -0.04, 0.87) },
        { id = 'pin_5',     offset = vector3(-0.145, -0.04, 0.87) },
        { id = 'pin_6',     offset = vector3(-0.122, -0.04, 0.87) },
        { id = 'pin_7',     offset = vector3(-0.173, -0.075, 0.865) },
        { id = 'pin_8',     offset = vector3(-0.145, -0.075, 0.865) },
        { id = 'pin_9',     offset = vector3(-0.122, -0.075, 0.865) },
        { id = 'pin_0',     offset = vector3(-0.145, -0.12, 0.865) },
        { id = 'pin_clear', offset = vector3(-0.076, 0.0, 0.88) },
        { id = 'pin_enter', offset = vector3(-0.076, -0.075, 0.865) },
    },
    ['prop_atm_03'] = {
        { id = 'side_l1', offset = vector3(-0.306, 0.095, 1.23) },
        { id = 'side_l2', offset = vector3(-0.306, 0.080, 1.17) },
        { id = 'side_l3', offset = vector3(-0.306, 0.065, 1.11) },
        { id = 'side_l4', offset = vector3(-0.306, 0.050, 1.05) },
        { id = 'side_r1', offset = vector3(0.065, 0.095, 1.23) },
        { id = 'side_r2', offset = vector3(0.065, 0.080, 1.17) },
        { id = 'side_r3', offset = vector3(0.064, 0.065, 1.11) },
        { id = 'side_r4', offset = vector3(0.063, 0.050, 1.055) },
        { id = 'pin_1',     offset = vector3(-0.181, -0.02, 0.88) },
        { id = 'pin_2',     offset = vector3(-0.153, -0.02, 0.88) },
        { id = 'pin_3',     offset = vector3(-0.116, -0.02, 0.88) },
        { id = 'pin_4',     offset = vector3(-0.181, -0.06, 0.87) },
        { id = 'pin_5',     offset = vector3(-0.153, -0.06, 0.87) },
        { id = 'pin_6',     offset = vector3(-0.116, -0.06, 0.87) },
        { id = 'pin_7',     offset = vector3(-0.181, -0.085, 0.865) },
        { id = 'pin_8',     offset = vector3(-0.153, -0.085, 0.865) },
        { id = 'pin_9',     offset = vector3(-0.116, -0.085, 0.865) },
        { id = 'pin_0',     offset = vector3(-0.153, -0.122, 0.865) },
        { id = 'pin_clear', offset = vector3(-0.076, -0.02, 0.88) },
        { id = 'pin_enter', offset = vector3(-0.076, -0.077, 0.865) },
    },
}

-- PIN Settings
Config.PIN = {
    length = 4,                 -- PIN digit length
    maxAttempts = 3,            -- Max failed attempts before card lock
    lockoutTime = 300,          -- Seconds to lock card after max attempts
    requireCard = true,         -- Require bank card item to use ATM
    allowCardCreation = true,   -- Allow players to create a new bank card via the ATM if they don't have one
    cardCreationCost = 50,      -- Cost to issue a new card
}

-- Transaction Settings  
Config.Transactions = {
    quickAmounts = {20, 50, 100, 200, 500}, -- Quick withdrawal amounts
    maxWithdraw = 10000,        -- Max single withdrawal
    maxDeposit = 50000,         -- Max single deposit
    maxTransfer = 25000,        -- Max single transfer
    fee = 0,                    -- Transaction fee (0 = no fee)
    feePercent = 0,             -- Transaction fee percentage
}

-- Sound Settings
Config.Sounds = {
    enabled = true,
    volume = 0.5,
    cardInsert = 'card_insert',
    cardEject = 'card_eject', 
    keyPress = 'key_press',
    success = 'success',
    error = 'error',
    cashDispense = 'cash_dispense',
}

-- Where the option bars sit on the ATM screen so their arrows meet the physical side keys: the centre of each of
-- the 4 rows, in percent of the screen's height, for the left and right keys. The keys sit in front of the recessed
-- screen, so from the ATM camera the two sides line up at different heights. A model without its own line uses
-- `default`. Tune one in game: stand at the ATM, F8, `atmrows` (shows the 8 slots), then
-- `atmrows left 28 49 70 89` / `atmrows right 19 40 62 80`; it prints the line for that model to paste here.
Config.ScreenRows = {
    -- The original's Config.ButtonOffsets put the left and right keys at the same heights (prop_fleeca_atm:
    -- z 1.23 / 1.17 / 1.11 / 1.06 on both sides), so both sides share the rows that fit the right side in game.
    -- Fine-tune in game with the dev command `atmrows left|right a b c d`.
    default = { left = { 19.0, 39.7, 61.8, 80.3 }, right = { 19.0, 39.7, 61.8, 80.3 } },
}

-- Interaction: a WHIP prompt on every ATM prop (AddAction at.model). WHIP's own ATM prompt must be off on these
-- models (whip_core config.lua: Config.AtmProps = {}), or both show.
Config.Interaction = {
    reach = 1.5,                -- metres to use the ATM
    -- Where the prompt sits on the ATM, from the prop's origin (its base): x across, y out of its face (negative =
    -- in front of these models), z up, and the way it turns. Same figures as WHIP's own ATM badge
    -- (whip_core config.lua Config.AtmBadgeOffset). In game, /actionplace atm aims it and copies the line.
    offset = vector3(-0.10, -0.22, 1.20),
    heading = 180.0,
    perModel = {
        ['prop_atm_01']     = { offset = vector3(-0.05, -0.20, 1.10), heading = 180.0 },
        ['prop_atm_02']     = { offset = vector3(-0.13, -0.22, 1.23), heading = 180.0 },
        ['prop_atm_03']     = { offset = vector3(-0.18, -0.21, 1.23), heading = 180.0 },
        ['prop_fleeca_atm'] = { offset = vector3(-0.06, -0.24, 1.24), heading = 179.8 },
    },
}

-- Animation Settings
Config.Animation = {
    dict = 'amb@prop_human_atm@male@idle_a',
    anim = 'idle_a',
    cardDict = 'amb@prop_human_atm@male@enter',
    cardAnim = 'enter',
}

-- UI Customization
Config.UI = {
    bankName = 'FLEECA',
    language = 'en',            -- UI language: 'en' or 'tr' (also in /whip -> Settings -> ATM)
}

-- Locales
Config.Locales = {
    en = {
        insert_card = 'Please Insert Your Card',
        enter_pin = 'Enter Your PIN',
        welcome = 'Welcome',
        main_menu = 'Select Transaction',
        withdraw = 'Withdraw',
        deposit = 'Deposit',
        transfer = 'Transfer',
        balance = 'Check Balance',
        exit = 'Exit',
        quick_cash = 'Quick Cash',
        other_amount = 'Other Amount',
        enter_amount = 'Enter Amount',
        confirm = 'Confirm',
        cancel = 'Cancel',
        back = 'Back',
        success = 'Transaction Successful',
        error = 'Transaction Failed',
        insufficient_funds = 'Insufficient Funds',
        invalid_pin = 'Invalid PIN',
        invalid_amount = 'Invalid Amount',
        card_locked = 'Card Locked - Contact Bank',
        take_card = 'Please Take Your Card',
        take_cash = 'Please Take Your Cash',
        receipt_question = 'Do You Want a Receipt?',
        yes = 'Yes',
        no = 'No',
        current_balance = 'Current Balance',
        transaction_complete = 'Transaction Complete',
        processing = 'Processing...',
        enter_account = 'Enter Account Number',
        transfer_to = 'Transfer To',
        amount = 'Amount',
        available_balance = 'Available Balance',
        attempts_remaining = 'Attempts Remaining',
        -- WHIP port: messages from the server
        use_atm = 'Use ATM',
        session_expired = 'Session expired: insert your card again',
        no_card = 'You need a bank card',
        card_frozen = 'This card is blocked',
        too_many_pins = 'Too many wrong PINs. Try again later',
        no_account = 'You have no bank account',
        account_not_found = 'Account not found',
        self_transfer = 'You cannot transfer to the same account',
        over_limit = 'Amount is over the limit',
        card_issued = 'Card issued',
        card_failed = 'Could not issue the card',
        receipt_given = 'Receipt printed',
        -- the ATM screen
        reading_card = 'Reading your card, please wait',
        press_enter = 'Press ENTER to confirm - CANCEL to clear',
        pin_hint = 'Shield the keypad while you type your PIN',
        no_card_title = 'No card found',
        no_card_text = 'You need a bank card to use this ATM. A new card is linked to your main account.',
        card_fee = 'Card fee',
        new_card = 'New card',
        please_wait = 'Please wait',
    },
    tr = {
        insert_card = 'Lütfen kartını tak',
        enter_pin = 'PIN kodunu gir',
        welcome = 'Hoş geldin',
        main_menu = 'İşlem Seç',
        withdraw = 'Para Çek',
        deposit = 'Para Yatır',
        transfer = 'Transfer',
        balance = 'Bakiye Sorgula',
        exit = 'Çıkış',
        quick_cash = 'Hızlı Nakit',
        other_amount = 'Diğer Tutar',
        enter_amount = 'Tutar Gir',
        confirm = 'Onayla',
        cancel = 'İptal',
        back = 'Geri',
        success = 'İşlem başarılı',
        error = 'İşlem başarısız',
        insufficient_funds = 'Yetersiz bakiye',
        invalid_pin = 'Hatalı PIN',
        invalid_amount = 'Geçersiz tutar',
        card_locked = 'Kart bloke edildi - Bankayla iletişime geç',
        take_card = 'Lütfen kartını al',
        take_cash = 'Lütfen paranı al',
        receipt_question = 'Fiş ister misin?',
        yes = 'Evet',
        no = 'Hayır',
        current_balance = 'Güncel Bakiye',
        transaction_complete = 'İşlem tamamlandı',
        processing = 'İşleniyor...',
        enter_account = 'Hesap numarasını gir',
        transfer_to = 'Alıcı',
        amount = 'Tutar',
        available_balance = 'Kullanılabilir Bakiye',
        attempts_remaining = 'Kalan Deneme',
        -- WHIP port: messages from the server
        use_atm = 'ATM Kullan',
        session_expired = 'Oturum sona erdi: kartını yeniden tak',
        no_card = 'Banka kartın yok',
        card_frozen = 'Bu kart bloke',
        too_many_pins = 'Çok fazla hatalı PIN. Biraz bekle',
        no_account = 'Banka hesabın yok',
        account_not_found = 'Hesap bulunamadı',
        self_transfer = 'Aynı hesaba transfer yapamazsın',
        over_limit = 'Tutar limiti aşıyor',
        card_issued = 'Kart oluşturuldu',
        card_failed = 'Kart oluşturulamadı',
        receipt_given = 'Fiş verildi',
        -- ATM ekranı
        reading_card = 'Kartın okunuyor, lütfen bekle',
        press_enter = 'Onay için ENTER - silmek için CANCEL',
        pin_hint = 'PIN girerken tuş takımını elinle kapat',
        no_card_title = 'Kart bulunamadı',
        no_card_text = 'Bu ATM için banka kartı gerekli. Yeni kart ana hesabına bağlanır.',
        card_fee = 'Kart ücreti',
        new_card = 'Yeni Kart',
        please_wait = 'Lütfen bekle',
    }
}

--- The text for a key in the server's language (Config.UI.language), falling back to English.
function Locale(key)
    local t = Config.Locales[Config.UI.language] or Config.Locales.en
    return t[key] or Config.Locales.en[key] or key
end
