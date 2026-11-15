# Setting up atmdui on a WHIP server

This guide takes a WHIP server from nothing to a working ATM in a few minutes. You need access to the server's files
and its console, and an admin account in game (WHIP's `/whip` menu).

## 1. Check what you need

- **whip_core 1.0 or newer.** The setup report in `/whip` shows your version.
- **oxmysql**, started before atmdui. WHIP servers already run it.
- **A FiveM server build from 2024 or later**, with OneSync on (WHIP needs both anyway).

atmdui needs no other resource: no ox_lib, no target script, no framework bridge.

## 2. Download it

Either clone it:

```bash
git clone https://github.com/fozenistaken/whip-atmdui.git atmdui
```

or download the ZIP from GitHub (Code → Download ZIP) and unpack it. Put the folder in your server's `resources`
folder. Name the folder `atmdui`; another name works too, but the commands in this guide use `atmdui`.

## 3. Turn off WHIP's own ATM prompt

WHIP has its own ATM prompt on the same ATM props. Leave it on and players see two prompts on every ATM.

Open `resources/whip_core/config.lua`, find `Config.AtmProps`, and empty the list:

```lua
Config.AtmProps = {}
```

WHIP's own list was `'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm'`. Put it back if you ever remove
atmdui.

## 4. Start it

Add this line to `server.cfg`, after the lines that start WHIP's resources:

```cfg
ensure atmdui
```

Restart the server (or run `refresh` and then `ensure atmdui` in the console, and restart whip_core so it reads the
config change from step 3).

On the first start atmdui creates its own database table, `atmdui_cards`. There is no SQL to import.

The console should print that atmdui started. If it prints a red line instead, see Troubleshooting below.

## 5. Try it in game

1. Walk up to any ATM (a Fleeca ATM, or the ones on the street). A prompt appears: press it.
2. The camera moves to the keypad. Look at a key with the mouse and click to press it. Esc or Backspace leaves.
3. **No card yet?** The ATM offers a new one: you choose a 4-digit PIN on the keypad, and the card goes into your
   inventory. A new card costs `$50` by default, paid like any WHIP purchase.
4. Insert the card, type the PIN, and use the side keys next to the screen to withdraw, deposit, transfer or check
   the balance.

The card belongs to the bank account that was your default when it was issued. Every move shows on that account's
statement, like any other WHIP bank transaction.

## 6. Change the settings

Most settings are in game: `/whip` → **Settings** → **ATM**.

| Group | Settings |
|---|---|
| Limits and fees | Largest withdrawal, deposit and transfer; a fixed fee and a percent fee; the five quick cash amounts |
| Cards and PIN | Whether ATMs issue new cards, what a new card costs, wrong PINs before a card locks, how long it stays locked |
| Look | The bank name on the screen; the language (English or Türkçe) |

Changes apply at once and are kept across restarts. A value set there wins over the same value in `config.lua`.

Everything else is in `config.lua`: the ATM models, where the screen and the camera sit, the keypad buttons on each
model, the sounds, and where the prompt sits on the machine.

## 7. Adjust the screen rows (only if they look off)

The option bars on the screen should line up with the physical side keys. On the four stock ATM models they do. For an
ATM model you add yourself, or if they look off:

1. Stand at the ATM and use it, so the camera is at the keypad.
2. Open the F8 console and type `atmrows`. All 8 option slots show.
3. Move a side's four rows, in percent of the screen's height: `atmrows left 28 49 70 89` or
   `atmrows right 19 40 62 80`.
4. When they line up, F8 prints a line for that model. Paste it into `Config.ScreenRows` in `config.lua`.

## Troubleshooting

**Two prompts on the ATM.** WHIP's own ATM prompt is still on: see step 3, then restart whip_core.

**No prompt at all.** Check that atmdui started (`ensure atmdui` in the console prints any error). Check that the ATM
is one of `Config.ATMModels` in `config.lua`.

**The screen on the ATM is blank or black.** The screen is a web page drawn on the ATM. Restart atmdui with
`ensure atmdui`. If it stays blank, F8 shows the reason.

**"Card locked".** Too many wrong PINs. It unlocks by itself after the lockout time (5 minutes by default, set in
`/whip` → Settings → ATM).

**A player forgot their PIN.** Nobody can read it, admins included: PINs are stored only as a hash. The player gets a
new card from an ATM.

**A withdrawal or transfer is refused.** The bank's own rules apply: a frozen account, a shared account without the
right to withdraw, or an amount over the limits in `/whip` → Settings → ATM. The screen says which.

## Removing it

1. Remove `ensure atmdui` from `server.cfg` and delete the folder.
2. Put WHIP's ATM list back in `whip_core/config.lua` (step 3).
3. The `atmdui_cards` table can be dropped. Players keep their `atmdui_card` items until you remove them.
