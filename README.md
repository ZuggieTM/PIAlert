# PI Alert

PI Alert is a Power Infusion request assistant for World of Warcraft Retail. It helps Priests notice when an eligible party or raid member requests Power Infusion through a whisper or activates a tracked damage cooldown.

Version: **1.0.0**  
Game version: **Midnight 12.1**

## Features

- Accept requests through whispers, tracked allied cooldown buffs, or both.
- Limit requesters to everyone in the group, your focus, or a specific-player list.
- Highlight requesters with Pixel Glow, AutoCast Glow, or Button Glow.
- Show a Power Infusion icon or the tracked spell icon on party and raidframes.
- Show a secure cooldown swipe for tracked buffs and timed whisper requests.
- Display a movable central Power Infusion alert icon.
- Play one of six included original PI request sounds, a Blizzard sound, or a LibSharedMedia sound for accepted whispers.
- Create Player, Focus, and Mouseover Power Infusion macros under General Macros.
- Add requesters or set the Player macro target from the unit right-click menu.

## Requirements

- World of Warcraft Retail 12.1 or later.
- Power Infusion is required to use the alert-readiness and macro features.

PI Alert has no required external dependencies. It includes LibGetFrame for raidframe resolution and supports LibSharedMedia sounds when that library is available from another addon. When LibSharedMedia is present, PI Alert also registers all six included sounds so other addons can use them.

## Installation

1. Download `PIAlert-v1.0.0.zip` from the [latest GitHub release](https://github.com/ZuggieTM/PIAlert/releases/latest).
2. Extract the archive into:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/
   ```

3. Confirm the resulting path is:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/PIAlert/PIAlert.toc
   ```

4. Start World of Warcraft or type `/reload` if the game is already running.
5. Type `/pia` to open the settings window.

## Getting started

The settings window contains four pages:

- **Requests** — Choose how requests are accepted, who may request, accepted whisper phrases, and specific players.
- **Alerts** — Configure raidframe glows and icons, the movable aura icon, and whisper sound behavior.
- **Spells** — Choose the allied cooldown buffs that should count as requests or add a custom aura spell ID.
- **Macros** — Create or update the account-wide `PI Alert` macro under General Macros.

Use `/pia test` after configuring Alerts to preview the glow, icon, swipe, and selected whisper sound.

## Request handling

PI Alert supports three request sources:

- **Whispers & Spell Cast**
- **Whispers only**
- **Spell Cast only**

The requester policy can allow everyone currently in the party or raid, only your focus, or only configured specific players. Specific Players can optionally fall back to your focus or everyone in the group when none of the listed players are present.

Whisper phrases support **Exact** and **Contains** matching. Contains uses word and phrase boundaries, so `PI` matches `PI on Zuggie` but does not match `spirit`.

Whisper alerts have a configurable duration and are cleared when Power Infusion is cast. They are ignored while Power Infusion is unavailable unless **Alert on cooldown** is enabled. Whisper sounds use a built-in three-second anti-spam window.

## Tracked spell alerts

World of Warcraft 12.1 restricts normal addon access to allied aura details. PI Alert uses Blizzard's secure `CustomAuraContainer` system and exact helpful aura spell IDs instead of reading those protected values in Lua.

As a result:

- Spell alerts are visual-only and do not play a sound.
- A tracked spell must create a buff on its caster.
- Talent-dependent entries show the required talent beneath the spell name.
- The secure icon and cooldown swipe follow the matched buff's duration.
- **PI Ready Only** hides spell visuals while Power Infusion is unavailable.
- **Always Track** keeps matching spell visuals visible regardless of Power Infusion's cooldown.
- If a tracked buff is already active when Power Infusion becomes ready, Blizzard may show the remaining portion of that buff.

Custom spells are treated as aura spell IDs for secure allied tracking.

## Alert options

### Raidframe settings

- Enable or disable raidframe glow.
- Choose Pixel Glow, AutoCast Glow, or Button Glow.
- Configure glow color, speed, lines, thickness, or scale where applicable.
- Use a custom glow color or the requester's class color.
- Show a Power Infusion or tracked spell icon.
- Enable or disable the icon cooldown swipe.

Whisper requests fall back to the Power Infusion icon because they do not have a tracked spell aura.

### Aura icon settings

- Enable or disable the movable central Power Infusion icon.
- Choose its size and unlock it for positioning.

### Whisper settings

- Enable or disable whisper-request sounds.
- Choose among six included PIAlert sounds—including a single-note pulse and two spoken “P I” voices—or use a Blizzard or LibSharedMedia sound.
- Configure how long whisper alerts remain visible.
- Allow or suppress whisper alerts while Power Infusion is on cooldown.

## Power Infusion macros

The Macros page creates or updates one account-wide macro named `PI Alert` under General Macros. Player and Focus variants always fall back to a living friendly mouseover target.

### Player

```text
#showtooltip Power Infusion
/cast [@PlayerName,help,exists,nodead][@mouseover,help,exists,nodead] Power Infusion
```

### Focus

```text
#showtooltip Power Infusion
/cast [@focus,help,exists,nodead][@mouseover,help,exists,nodead] Power Infusion
```

### Mouseover

```text
#showtooltip Power Infusion
/cast [@mouseover,help,exists,nodead] Power Infusion
```

Right-click a party or raid member to add or remove them from Specific Players or set them as the Player macro target.

## Slash commands

| Command | Description |
| --- | --- |
| `/pia` | Open or close settings |
| `/pia mo` or `/pia mouseover` | Create the Mouseover macro |
| `/pia focus` | Create the Focus macro |
| `/pia test` | Preview the configured alert |
| `/pia reset` | Reset PI Alert settings |
| `/pia help` | Show the in-game command list |

## Raidframe support

PI Alert supports Blizzard party and raidframes and uses its bundled LibGetFrame copy to resolve frames from popular addons, including:

- Cell
- EllesmereUI
- ElvUI
- Grid and Grid2
- VuhDo

## Saved settings

Settings are account-wide and stored by World of Warcraft in `PIAlertDB`. Updating the addon does not remove your settings.

## Support

If an alert does not appear:

1. Confirm the requester is currently in your party or raid and is allowed by the Requests settings.
2. Confirm the spell is enabled and that it creates one of the configured caster buffs for the player's selected talents.
3. Confirm the desired visual is enabled under Alerts.
4. Use `/pia test` to verify the visual configuration and raidframe resolution.
5. Report reproducible problems through [GitHub Issues](https://github.com/ZuggieTM/PIAlert/issues).

Detailed development history is retained in `README.txt`.
