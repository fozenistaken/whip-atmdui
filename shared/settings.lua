-- The ATM's settings as a page in /whip -> Settings -> ATM. config.lua holds the defaults; an admin's change is
-- written into Config on both sides and counts from the next transaction.
Whip.configPage({
    label = 'ATM',
    groups = {
        { label = 'Limits and fees', settings = {
            { key = 'Transactions.maxWithdraw', type = 'int', min = 1, max = 100000000, unit = '$', label = 'Largest withdrawal' },
            { key = 'Transactions.maxDeposit', type = 'int', min = 1, max = 100000000, unit = '$', label = 'Largest deposit' },
            { key = 'Transactions.maxTransfer', type = 'int', min = 1, max = 100000000, unit = '$', label = 'Largest transfer' },
            { key = 'Transactions.fee', type = 'int', min = 0, max = 10000, unit = '$', label = 'Fee per withdrawal or transfer',
              help = 'Taken from the account after the withdrawal or transfer, and gone (a money sink).' },
            { key = 'Transactions.feePercent', type = 'number', min = 0, max = 20, step = 0.5, unit = '%', label = 'Fee, percent of the amount' },
            { key = 'Transactions.quickAmounts', type = 'list', item = { type = 'int', min = 1, max = 100000 },
              minItems = 5, maxItems = 5, label = 'Quick cash amounts',
              help = 'The five quick withdrawal buttons, in order.' },
        } },
        { label = 'Cards and PIN', settings = {
            { key = 'PIN.allowCardCreation', type = 'bool', label = 'ATMs issue new cards' },
            { key = 'PIN.cardCreationCost', type = 'int', min = 0, max = 100000, unit = '$', label = 'New card costs' },
            { key = 'PIN.maxAttempts', type = 'int', min = 1, max = 10, label = 'Wrong PINs before the card locks' },
            { key = 'PIN.lockoutTime', type = 'int', min = 30, max = 86400, unit = 's', label = 'Card locked for' },
        } },
        { label = 'Look', settings = {
            { key = 'UI.bankName', type = 'string', maxLen = 20, label = 'Bank name on the screen' },
            { key = 'UI.language', type = 'enum', label = 'Language',
              options = { { value = 'en', label = 'English' }, { value = 'tr', label = 'Türkçe' } } },
        } },
    },
})
