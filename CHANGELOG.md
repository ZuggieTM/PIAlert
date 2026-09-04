# Changelog

## 1.2.1

### New

- **Additional macro commands.** Add custom macro lines, such as `/use 13`,
  after the generated Power Infusion cast. Item and spell names can also be
  inserted into the field by Shift-clicking them.

## 1.2.0

PI Alert now focuses entirely on alerts triggered by tracked allied cooldowns,
with finer control over when the addon is active.

### New

- **Activation settings.** Choose whether PI Alert is active for Healer
  (Holy/Discipline) and/or DPS (Shadow) priest specializations.
- **Content-type controls.** Enable PI Alert separately in open world content,
  dungeons, raids, PvP, and Delves & scenarios. Dungeon, raid, and PvP
  categories can be expanded to select their relevant difficulties or modes.
- **Clearer grouped selections.** Spell and content lists now use expandable
  groups with indented child options, making large lists easier to scan.
- **Options-window branding.** The settings window now shows the PI Alert logo
  and the installed addon version.

### Changed

- PI Alert now uses tracked allied cooldown buffs exclusively. The Requests page
  focuses on requester rules, while the Alerts page contains only the visuals
  used for tracked cooldown alerts.
- Existing saved variables are migrated automatically, including cleanup of the
  retired chat-request and request-sound settings.

### Fixed

- **AutoCast and Button Glow now animate for real alerts.** These glow styles
  now use the same native animation path as the Test alert button; AutoCast also
  respects its configured scale.

### Removed

- Removed chat-based request handling, request-source selection, phrase rules,
  PI Alert request sounds, and related saved settings.

## 1.1.0

Power Infusion sounds now work on their own, the addon has an icon, and a macro
target chosen during combat is remembered instead of thrown away.

### New

- **LibSharedMedia is now bundled.** The shared-media sound list works without
  another addon supplying the library, and PI Alert's six included sounds are
  registered with LibSharedMedia so WeakAuras and other addons can use them too.
- **Addon-list icon.** PI Alert now shows its mark in the in-game AddOns list.
- **Right-click menu header.** PI Alert's entries sit under their own heading in
  the unit menu instead of loose among Blizzard's.

### Fixed

- **A macro target chosen during combat is no longer thrown away.** World of
  Warcraft does not allow macros to be edited in combat, and PI Alert used to
  discard the whole request with only a chat message. Your choice is now saved
  immediately and the macro itself is written the moment you leave combat. Log out
  before combat ends and it is applied at your next login instead.
- **"Set as PI Alert macro target" is a plain action, not a toggle.** It always
  sets the named target, and the macro keeps mouseover as its fallback.

### Under the hood

- Libraries are fetched from upstream when the addon is packaged rather than
  committed, so LibStub, CallbackHandler, LibSharedMedia and LibGetFrame all ship
  current.
- Removed an unused copy of LibCustomGlow that was never loaded.
- Folded four identical copies of a helper function into one.
- Rewrote the README and the CurseForge description, and settled on "PI Alert"
  as the name everywhere it is read.

## 1.0.0

First release.
