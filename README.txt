PI Alert 1.0.28-beta
====================

A Power Infusion request assistant for World of Warcraft Midnight 12.1.

INSTALL
-------
1. Extract the PIPriority folder into:
   World of Warcraft/_retail_/Interface/AddOns/
2. Start/reload WoW.
3. Type /pia to open settings.

REQUEST SOURCES
---------------
- Whispers & Spell Cast
- Whispers only
- Spell Cast only

Whisper requests and allied spell requests intentionally use different timing
models because Blizzard keeps allied aura transitions secret to normal addon Lua.

WHISPER CONFIGURATION
---------------------
Request Duration applies to whisper requests only. Matching whispers are ignored
while Power Infusion is on cooldown.

- Request Duration: once active, the whisper request remains visible for this
  many seconds, or until PI is cast.

Whisper phrases support Exact and Contains matching. Contains uses word/phrase
boundaries, so "PI" matches "PI on Zuggie" but does not match "spirit".

SPELL CAST CONFIGURATION
------------------------
Allied major cooldowns are tracked through Blizzard's 12.1 CustomAuraContainer
using exact helpful aura spell IDs. PI Alert tells Blizzard which buffs to
track for party/raid units; Blizzard securely controls when the visual is shown.

Spell-triggered visuals:
- follow the tracked buff while it is active;
- are completely hidden while Power Infusion itself is on cooldown;
- ignore the normal global cooldown when checking whether PI is ready;
- disappear immediately when PI is cast.

Because Blizzard does not expose a normal Lua event saying exactly when the
restricted allied buff appeared, Whisper Request Duration does not apply to
spell-triggered visuals.

REQUESTERS
----------
- Everyone in Group
- Focus
- Specific Players

Specific player names are case-insensitive and realm-insensitive. Enter only the
base character name, for example: Senilemammy.

Specific Players also has an optional fallback: No fallback, Focus, or Everyone
in Group. The fallback activates only when none of the configured specific players
are currently present in the party/raid. If at least one configured player is
present, only configured players are accepted.

ALERTS
------
Each alert type can be enabled independently:
- Glow on raid/party frame
- Power Infusion icon on raid/party frame, with a secure swipe showing the
  tracked buff's remaining duration
- Movable Power Infusion aura icon
- Sound for accepted whisper requests only

Spell alert timing has two modes:
- Always Track: tracked allied buffs stay visible regardless of PI's
  cooldown.
- PI Ready Only (default): visuals are gated by PI readiness. If a tracked
  buff is already active when PI becomes ready, Blizzard may show its remaining
  visual.

PI Alert uses native AnimationGroups for ordinary whisper requests. Blizzard-
managed allied spell alerts start their C-side animation inside the secure
initialization window. Both paths share the selected style, speed and color
without reading protected aura state.

Glow styles:
- Pixel Glow: speed, number of lines and thickness
- AutoCast Glow: speed and scale
- Button Glow: speed
- Custom color or requester class color

Secure Pixel uses native marching-dash "ants" created before Blizzard seals the
AuraButton. Secure AutoCast and Button visuals use the native alpha pulse. The
selected speed and color apply to both paths.

Use /pia test to preview the configured alert behavior on your own resolved
party/raidframe.

The sound picker supports LibSharedMedia-3.0 registrations and is searchable.
Only accepted whisper requests trigger the selected sound during normal use;
/pia test also plays it as a preview. Tracked allied buff activations use visual
alerts only and never play a sound. Whisper sounds use the local Whisper Sound
Cooldown setting.

FRAME SUPPORT
-------------
PI Alert bundles LibGetFrame-1.0 to resolve unit tokens such as party2 or
raid6 to the visible party/raid frame. This covers Blizzard frames and many
popular frame addons including Grid/Grid2, EllesmereUI, Cell, ElvUI and VuhDo.

COMMANDS
--------
/pia            Open/close settings
/pia test       Show a test request
/pia status     Print configured-player and secure spell-tracker status
/pia debug      Toggle debug logging
/pia frames     Print unit-token -> raid/party frame mappings
/pia clear      Clear all requests
/pia reset      Reset settings

1.0.35-beta
-----------
- Removed sounds from tracked allied buff activations; spell tracking is now
  visual-only.
- Made the sound toggle, picker and cooldown apply only to accepted whisper
  requests (plus /pia test previews).
- Removed the protected allied aura-sound registration code and its combat
  lifecycle restrictions.

1.0.34-beta
-----------
- Kept pre-combat allied aura-sound registrations armed throughout restricted
  combat so sounds continue after the first PI cooldown cycle.
- Stopped calling Blizzard's protected aura-sound add/remove APIs in combat,
  fixing ADDON_ACTION_BLOCKED errors from RegisterAuraSound.
- Kept PI Ready Only gating on secure raidframe visuals.

1.0.33-beta
-----------
- Added a Blizzard-driven duration swipe to each secure raidframe PI icon.
- The swipe shows the remaining duration of the tracked active buff without
  reading protected timer values in addon Lua.

1.0.32-beta
-----------
- Fixed Everyone in Group whisper authorization by resolving the whisper sender
  from Blizzard's exact sender GUID before falling back to display-name matching.
- Added native full-name roster comparison for connected/cross-realm players.

1.0.31-beta
-----------
- Restored the native secure Pixel Glow ants engine and loaded it before the
  allied cooldown detector.
- Kept the secure alpha pulse as a fallback if native dash translation is rejected.

1.0.30-beta
-----------
- Replaced the forbidden per-frame secure-glow driver with a native C-side alpha
  AnimationGroup created inside the AuraButton initialization window.
- Changed the default spell-alert timing to PI Ready Only, including existing
  1.0.29 settings, so casting PI immediately hides tracked allied-buff visuals.

1.0.29-beta
-----------
- Added Always Track and PI Ready Only spell-alert timing modes.
- Made Always Track the default: allied cooldown visuals stay active while PI is
  unavailable, while their activation sounds still require PI to be ready.
- Kept allied aura sounds activation-only; PI becoming ready does not replay an
  already-active cooldown sound.

1.0.28-beta
-----------
- Re-enabled existing secure trackers immediately when PI becomes ready during
  combat, instead of waiting until combat ended.
- Removed allied aura-sound registrations while PI is unavailable and restored
  them when PI becomes ready, including safe in-combat attempts and retries.
- Animated secure Pixel, AutoCast and Button visuals from an unrestricted driver.

1.0.27-beta
-----------
- Stopped changing restricted AuraButtons after initialization, fixing the
  forbidden-object SetAlpha error seen during dungeons and raids.
- Secure Pixel, AutoCast and Button alerts now have distinct static visuals
  using the selected glow color.
- Cosmetic secure-alert changes now rebuild a frozen visual out of combat.

1.0.26-beta
-----------
- Corrected the Retail 12.1 AuraContainer order: SetUnit, add slots, then SetEnabled.
- Fixed foreign-class cooldowns disappearing when Blizzard's cooldown-aura lookup returns nil.
- Added the Arcane Surge buff ID and all current Ascendance cast/aura variants.
- Added /pia status for live selected-player and secure-tracker diagnostics.

1.0.25-beta
-----------
- Deferred all secure aura construction and structural changes until combat ends.
- Reused secure trackers for cosmetic changes and removed the unbounded retired-state list.
- Prevented helpful-aura filters from failing open on non-assistable group units.
- Resolved preset cast IDs through C_UnitAuras.GetCooldownAuraBySpellID.
- Replaced non-ticking restricted glow animations with a reliable static border.
- Fixed empty whisper phrase persistence, reset positioning, TOC paths and slash command availability.

1.0.24-beta
- Fixed allied cooldown request sound registration output-channel handling.
- Removed the obsolete AddAuraAppliedSound branch; Patch 12.1 uses C_UnitAuras.AddAuraSound with UnitAuraSoundTrigger.Added.
- Aura sound registration is now tracked per spell. A partial registration no longer incorrectly marks the whole unit as complete, and failed registrations can be retried.
- Added an out-of-combat retry for partial aura-sound registrations.
- Kept the secret-safe Power Infusion cooldown readiness logic; no numeric secret cooldown values are compared.

1.0.23-beta
-----------
- Fixed allied spell-request sounds by preferring Blizzard's dedicated
  C_UnitAuras.AddAuraAppliedSound registration for tracked cooldown buffs.
- Kept C_UnitAuras.AddAuraSound Added as a compatibility fallback.
- Allied aura sound registrations are now removed through the matching API.
- Kept the secret-safe Power Infusion cooldown readiness logic from 1.0.22.

1.0.19-beta
-----------
- Renamed the addon from PI Priority to PI Alert.
- /pia is now the primary slash command; /pialert is also supported.
- /pip remains available as a legacy alias so existing habits/macros keep working.
- Kept the internal PIPriority folder and SavedVariables name for upgrade compatibility.

1.0.16-beta
-----------
- Added a Specific Players fallback dropdown: No fallback, Focus, or Everyone in Group.
- The fallback is used only when none of the configured specific players are currently present.
- The same requester fallback applies to both whispers and secure allied spell alerts.

1.0.15-beta
-----------
- Removed the separate Raidframe Glow Preview button; /pia test covers alert testing.
- Renamed visible "raid-frame" wording to "raidframe" in the settings/debug UI.

1.0.11-beta
-----------
- Removed the runtime dependency on LibCustomGlow-1.0.
- Whisper frame glows use the native AnimationGroup renderer.
- Added Blizzard-managed sound registration for allied tracked buffs using
  C_UnitAuras.AddAuraSound with the Added trigger.
- SharedMedia sounds can be used for allied aura sounds when Blizzard accepts
  the registered sound path/FileDataID.
- Sound selections now rebuild secure allied trackers immediately.
- Renamed the local sound throttle in the UI to Whisper Sound Cooldown to make
  the secure-spell behavior explicit.

Right-click group members
-------------------------
While PI Alert is active, right-click a party/raid member and toggle "PI Alert requester" to add or remove them from the Specific Players list.
