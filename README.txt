PI Alert 1.0.48-beta
====================

A Power Infusion request assistant for World of Warcraft Midnight 12.1.

INSTALL
-------
1. Extract the PIAlert folder into:
   World of Warcraft/_retail_/Interface/AddOns/
2. Start/reload WoW.
3. Type /pia to open settings.

REQUEST SOURCES
---------------
- Whispers & Spell Cast
- Whispers only
- Spell Cast only

The Requests page also controls who may request: Everyone in Group, Focus, or
Specific Players. Whisper phrases appear only when whispers are enabled, and
the configured-player list appears only when Specific Players is selected.

Whisper requests and allied spell requests intentionally use different timing
models because Blizzard keeps allied aura transitions secret to normal addon Lua.

WHISPER CONFIGURATION
---------------------
Alert Duration under Alerts > Whisper settings applies to whisper requests only.
By default matching whispers are ignored while Power Infusion is on cooldown;
the same settings card can allow them during PI's cooldown.

- Alert Duration: once active, the whisper request remains visible for this
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
- follow the selected Always Track or PI Ready Only alert policy;
- ignore the normal global cooldown when checking whether PI is ready;
- in PI Ready Only mode, disappear immediately when PI is cast.

Because Blizzard does not expose a normal Lua event saying exactly when the
restricted allied buff appeared, Whisper Request Duration does not apply to
spell-triggered visuals.

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
- Power Infusion or tracked spell icon on raid/party frames. Whispers always
  fall back to the Power Infusion icon because they have no spell aura.
- Optional cooldown swipe showing the tracked buff's remaining duration for
  spell alerts and the request duration for whisper alerts
- Movable Power Infusion aura icon with configurable size
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
alerts only and never play a sound. Whisper sounds have a fixed three-second
anti-spam window.

MACROS
------
The Macros page creates or updates one account-wide PI Alert macro under General
Macros. Player, Focus and Mouseover variants are available. Player and Focus
always fall back to a living friendly mouseover target.

Right-clicking a party/raid member can set or clear the Player macro target.
/pia focus creates the Focus variant; /pia mo and /pia mouseover create the
Mouseover variant.

FRAME SUPPORT
-------------
PI Alert bundles LibGetFrame-1.0 to resolve unit tokens such as party2 or
raid6 to the visible party/raid frame. This covers Blizzard frames and many
popular frame addons including Grid/Grid2, EllesmereUI, Cell, ElvUI and VuhDo.

COMMANDS
--------
/pia            Open/close settings
/pia mouseover  Create or update the PI Alert mouseover macro in General Macros
/pia mo         Short alias for /pia mouseover
/pia focus      Create or update the PI Alert focus macro in General Macros
/pia test       Show a test request
/pia status     Print configured-player and secure spell-tracker status
/pia debug      Toggle debug logging
/pia frames     Print unit-token -> raid/party frame mappings
/pia clear      Clear all requests
/pia reset      Reset settings
/pia help       Show the formatted command list

1.0.48-beta
-----------
- Fixed /pia help color rendering by using Blizzard's native color wrapper.
- Swapped the help colors so the heading is blue and commands are green.

1.0.47-beta
-----------
- Completed the internal PI Alert rename across the addon folder, TOC, saved
  database, frame names, media paths and test identifiers.
- Removed two obsolete Lua files that were no longer loaded by the addon.
- Renamed the saved database to PIAlertDB as part of the completed addon rename.

1.0.46-beta
-----------
- Made /pia the only registered addon slash command.
- Added a colored, readable command reference under /pia help.

1.0.45-beta
-----------
- Added the friendly-unit condition to Player and Focus macro targets so an
  invalid hostile target falls through to the mouseover fallback.

1.0.44-beta
-----------
- Added a dedicated Macros page with Player, Focus and Mouseover macro creators.
- Added /pia focus and made /pia mo and /pia mouseover explicitly select the
  mouseover-only macro.
- Added mouseover fallback targeting to both Player and Focus macros.
- Removed the macro creator button from Alerts.

1.0.43-beta
-----------
- Added a right-click PI Alert macro target option beneath the Specific Players
  requester toggle.
- Named macro targets are saved and placed before the mouseover fallback; toggling
  the selected target off returns the macro to mouseover-only behavior.

1.0.42-beta
-----------
- Added a Create PI macro button that creates or updates an account-wide
  PI Alert mouseover macro under General Macros.
- Added /pia mo and /pia mouseover as aliases for the same macro action.

1.0.41-beta
-----------
- Moved Alerts before Spells in the settings navigation.

1.0.40-beta
-----------
- Merged the Requests and Requesters settings into one responsive Requests page.
- Moved Who can request and the Specific Players fallback into Request handling.
- Showed whisper phrases and the specific-player list only when their matching
  modes are selected.

1.0.39-beta
-----------
- Replaced the configurable sound cooldown with a fixed three-second anti-spam
  window.
- Moved configurable whisper Alert Duration into the Whisper settings card.
- Simplified Requests to request-source and accepted-phrase configuration.

1.0.38-beta
-----------
- Routed tracked player buffs through the same secure aura tracker as allies.
- Removed the five-second synthetic self-cast path; /pia test remains the
  dedicated alert preview.
- Player raidframe icons now use the tracked buff's real duration swipe.

1.0.37-beta
-----------
- Refined spacing and wording across all three Alerts settings cards.
- Moved AutoCast scale beside speed and gave the color selector a full row.
- Moved and shortened the raidframe icon cooldown-swipe option.
- Added a request-duration swipe to whisper raidframe icons.

1.0.36-beta
-----------
- Reorganized Alerts into Raidframe, Aura icon and Whisper settings cards.
- Added a raidframe icon choice between Power Infusion and the tracked spell.
- Added independent cooldown-swipe and aura-icon-size controls.
- Added an option to accept and alert for whispers while PI is on cooldown.

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
While PI Alert is active, right-click a party/raid member and toggle "PI Alert requester" to add or remove them from the Specific Players list. The option directly below it sets that player as the named target in the General PI Alert macro while retaining mouseover as the fallback.
