# PI Alert

PI Alert is a Power Infusion assistant for World of Warcraft Retail. It highlights eligible party and raid members when they activate a configured major cooldown, helping Priests coordinate Power Infusion during the content where it matters.

Version: **1.2.0**
Game version: **Midnight 12.1**

## Features

- Track configured allied cooldown buffs securely on party and raid frames.
- Limit alerts to everyone in the group, your focus, or a specific-player list.
- Enable alerts by Priest role and by content type or difficulty.
- Highlight requesters with Pixel Glow, AutoCast Glow, or Button Glow.
- Show a Power Infusion icon or the tracked spell icon on party and raid frames.
- Display a movable central Power Infusion alert icon.
- Create Player, Focus, and Mouseover Power Infusion macros under General Macros.
- Add requesters or set the Player macro target from the unit right-click menu.

## Getting started

Type `/pia` to open the settings window.

- **Requests** — choose who can trigger alerts from tracked cooldowns.
- **Activation** — choose Priest roles and content types where PI Alert is active.
- **Alerts** — configure raidframe glows and icons plus the movable aura icon.
- **Spells** — choose the allied cooldown buffs that should count as PI requests, or add a custom aura spell ID.
- **Macros** — create or update the account-wide `PI Alert` macro under General Macros.

## Tracked cooldown alerts

World of Warcraft 12.1 restricts normal addon access to allied aura details. PI Alert uses Blizzard's secure `CustomAuraContainer` system and exact helpful-aura spell IDs rather than reading those protected values in Lua.

- A tracked spell must create a buff on its caster.
- Talent-dependent entries show the required talent beneath the spell name.
- The secure icon and cooldown swipe follow the matched buff's duration.
- **PI Ready Only** hides spell visuals while Power Infusion is unavailable.
- **Always Track** keeps matching spell visuals visible regardless of Power Infusion's cooldown.

## Power Infusion macros

The Macros page creates or updates one account-wide macro named `PI Alert`. Player and Focus variants fall back to a living friendly mouseover target.

```text
#showtooltip Power Infusion
/cast [@PlayerName,help,exists,nodead][@mouseover,help,exists,nodead] Power Infusion
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

PI Alert supports Blizzard party and raidframes and uses its bundled LibGetFrame copy to resolve frames from popular addons, including Cell, EllesmereUI, ElvUI, Grid, Grid2, and VuhDo.

## Saved settings

Settings are account-wide and stored by World of Warcraft in `PIAlertDB`. Updating the addon keeps supported settings; obsolete request settings are cleaned up automatically.

## Support

If an alert does not appear, confirm the player is in your group and permitted by Requests, their spell is enabled and creates a configured caster buff, and the desired visuals are enabled under Alerts. Report reproducible problems through [GitHub Issues](https://github.com/ZuggieTM/PIAlert/issues).
