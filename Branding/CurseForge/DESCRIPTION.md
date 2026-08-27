# PIAlert

**Power Infusion requests, impossible to miss.**

PIAlert is a focused request assistant for Priests in World of Warcraft Retail. It turns accepted whispers and tracked allied cooldowns into clear raidframe cues, so you can find the right player and cast Power Infusion without losing focus on the fight.

## Request your way

- Accept **whispers**, **tracked spell casts**, or both.
- Allow everyone in your group, your focus, or a priority list of specific players.
- Add custom whisper phrases with Exact or Contains matching.
- Configure fallback behavior when none of your preferred players are present.

## Alerts that fit your UI

- Animated **Pixel Glow**, **AutoCast Glow**, or **Button Glow** on party and raidframes.
- Power Infusion or tracked-spell icons directly on the requester.
- Secure cooldown swipes that follow the tracked aura or whisper-alert duration.
- A configurable, movable central Power Infusion icon.
- Six original included request sounds, plus Blizzard and LibSharedMedia sounds.

Whisper sounds are intentionally limited to accepted whisper requests. Tracked spell alerts remain visual-only to work safely with World of Warcraft's protected allied-aura system.

## Know which cooldowns matter

PIAlert includes organized presets for major class cooldowns and supports custom aura spell IDs. Talent-dependent entries explain their requirements in the spell list, and cooldowns with multiple valid caster buffs can track multiple aura IDs.

## Target faster

Create an account-wide **Player**, **Focus**, or **Mouseover** Power Infusion macro from inside the addon. Player and Focus variants automatically fall back to a valid friendly mouseover target.

You can also right-click a party or raid member to:

- Add or remove them from Specific Players.
- Set them as the Player macro target.

## Raidframe support

PIAlert supports Blizzard party and raidframes and resolves frames from popular addons through its bundled LibGetFrame integration, including:

- Cell
- EllesmereUI
- ElvUI
- Grid and Grid2
- VuhDo

## Quick setup

1. Type `/pia` to open PIAlert.
2. Choose how requests are accepted under **Requests**.
3. Enable the spells and visuals you want under **Spells** and **Alerts**.
4. Use `/pia test` to preview your alert setup.

## Commands

- `/pia` — Open or close settings.
- `/pia test` — Preview the configured alert.
- `/pia mo` or `/pia mouseover` — Create the Mouseover macro.
- `/pia focus` — Create the Focus macro.
- `/pia reset` — Reset settings.
- `/pia help` — Show the in-game command list.

## Compatibility and support

- World of Warcraft Retail 12.1 or later.
- No required external dependencies.
- Settings are account-wide and retained between updates in `PIAlertDB`.

Found a reproducible issue or have a feature request? Please use the [PIAlert issue tracker](https://github.com/ZuggieTM/PIAlert/issues).
