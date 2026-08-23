# Changelog

## 1.3.3 — 2026-08-23

- Keep the dispel spell watermark square on party buttons. The name band added in 1.3.2 made the button taller than it is wide, and the watermark filled the whole button, so that art — a square spell icon — was stretched vertically. It now ends above the name band, occupying the same square area as the debuff icon drawn on top of it. Raid squares carry no name band and are unaffected.

## 1.3.2 — 2026-08-23

- Party buttons are now 48x62, so the unit name no longer competes with the debuff icon for space: the icon area is a full 44x44 square again (no vertical crop) and the name occupies a dedicated 14px band beneath it, with a 2px gap to the icon contour. The party frame grows 14px taller to match. Raid squares are unaffected.

## 1.3.1 — 2026-08-23

- Fix the blurred, apparently doubled text on the `light` theme introduced in 1.3.0 (for example `YOU` and `SimpleDispel Party`). Two separate causes, both font decoration that only works on a dark plate: every Blizzard default font object carries a black drop shadow offset by (1, -1), which on a pale plate becomes a legible dark copy of the glyph shifted down and to the right; the `*Outline` variants additionally draw a black outline, which separates light text from its background but thickens dark letterforms and smears them together.
- The `light` theme now selects the unoutlined font variants and switches the shadow off. The dark theme no longer hard-codes shadow values: it records each font object's original shadow colour and offset the first time the theme is applied, and restores exactly that when switching back.
- The stack count text on the debuff icon and the duration text below the button, both in `AuraDisplay`, never sit on a pale plate — they sit on the icon and on the game world outside the frame respectively — so they keep their existing outline and shadow.

## 1.3.0 — 2026-08-23

- Add an optional colour theme with no change to the default appearance: a new standalone `Theme.lua` module carries the `dark` (default) and `light` palettes. `dark` reproduces every pre-1.3.0 colour byte for byte, and saved variables written before this change (1.2.x and earlier) carry no `theme` field and fall back to it, so an upgrade is visually silent until you opt in with `/sd theme light`.
- SavedVariables schema raised from 3 to 4, adding the `SimpleDispelDB.theme` field.
- Add `/sd theme`, `/sd theme dark` and `/sd theme light`. An unrecognised theme name is rejected and leaves the saved theme untouched. Unlike `/sd scale`, `/sd reset` and `/sd lock`, switching themes is not restricted by combat protection — every property involved is a colour or an alpha, none of which is protected, so it works during combat as well.
- The `light` palette is designed to make the dispellable debuff icon the only element inside the frame that keeps full saturation and contrast: the root background, drag handle and unit button plates become near-achromatic, semi-transparent light panels; borders become fills darker than the plate; unit names become dark grey; and the dispel spell watermark on each button is desaturated and dropped to 0.08 alpha.
- The meaning of the "unavailable" states is inverted on the `light` theme: out of range and cooldown wash the button out (alpha 0.55 and 0.35 respectively) rather than darkening it, because on a pale plate darkening reads louder than washing out and drowns the dispel alert itself. The out-of-range border and the `×` and `CD` marks move to correspondingly darker tones to stay readable on a near-white plate (Blizzard's native amber is all but invisible there).
- Fix two icon rendering problems that apply to both themes: debuff icons now keep a 2px button plate margin on all four sides instead of touching the cell border, and the 13px the party button reserves at the bottom for the name used to stretch the icon vertically out of shape, which is now a correctly proportioned, centred crop instead (raid squares are square already and were unaffected).
- Add a 1px dark contour around the debuff icon, drawn above the cooldown swipe, to give pale or bright debuff art a hard edge on the light plate. The same colour is invisible against the dark theme's background, so one implementation serves both palettes.

## 1.2.2 — 2026-08-22

- Close the same class of stuck-drag hazard as 1.2.1: the party and raid frames are shown and hidden by a visibility driver (joining a raid from a party, or leaving the group), and a frame hidden mid-drag never receives the mouse-up, so `OnDragStop` never fires and the drag survives until the frame is next shown — at which point it is still stuck to the cursor and jams target switching again. A frame now ends its own drag in `OnHide`; a frame that is not being dragged does not rewrite the saved position when it hides.

## 1.2.1 — 2026-08-22

- Fix a serious problem where dragging a frame during combat made target switching impossible: when combat started mid-drag, `OnDragStop` returned early on the combat lock and skipped `StopMovingOrSizing`, so the frame followed the mouse from then on and its unit buttons swallowed every world click and hover, leaving the target stuck on whichever unit was already selected.
- `OnDragStop` now releases the drag unconditionally, and a new `PLAYER_REGEN_DISABLED` handler ends any drag in progress the moment combat starts, rather than waiting for the player to release the mouse.
- A drag ended during combat still saves the new position (neither `GetPoint` nor SavedVariables is restricted by combat protection).

## 1.2.0 — 2026-08-21

- Keep showing debuffs while the dispel spell is on a real cooldown, and mark every unit square with a neutral dark shade and an amber `CD`; both clear automatically once the cooldown ends.
- Distinguish the dispel spell's own cooldown from the global cooldown (GCD). Cooldown and out-of-range states can apply at the same time without compounding the shade or disabling clicks.

## 1.1.1 — 2026-08-19

- Fix the unit tooltip anchor to use the client's default anchor, with an interaction test to match.

## 1.1.0 — 2026-08-19

- Raid becomes a grid of 28 x 28 pixel squares, fixed at 8 columns and at most 5 rows. Member names are no longer permanently displayed; the ordinary unit button tooltip identifies members instead.
- A locked raid frame hides its title and large background and moves the grid up; unlocking it shows a small `SD` drag anchor.
- Refresh the range hint roughly every 0.25s through `C_Spell.IsSpellInRange`, using whichever friendly dispel spell is actually selected: `true` keeps the normal appearance, `false` shows a dark overlay, a red border and `×`, and `nil` stays neutral.
- The range hint is visual feedback only and does not disable clicks. It cannot account for line of sight, and may lag briefly behind the client's own refresh.

## 1.0.0 — 2026-08-17

- First stable release.
- Hide the unusable unit buttons and show an explanation in Simplified Chinese, Traditional Chinese or English when the current class or specialization has no known friendly dispel.
- Collapse the raid empty state to a compact height when no dispel spell is available, and restore the full party and raid frames automatically once one is detected again.
- Re-detect on login, on entering the world, and on specialization, spell or talent changes; protected updates that fall during combat are deferred until it ends.
- A manual spell ID only takes effect if the current character actually knows that spell, so account-wide SavedVariables cannot mis-detect a dispel on a class that has none.
- Add tests for dispel detection, empty-state switching, combat deferral and secure attribute clearing.

## 0.10.0-beta.5 — 2026-08-17

- Raid squares show the name of the corresponding `raidN` member instead of an index; names take no part in sorting or casting decisions.
- Raid becomes fixed five-column name rows: a 32 pixel debuff icon on the left, the member name on the right.
- The raid frame's row count follows the current raid size; 25 players show 5 x 5, and only 40 players show 5 x 8.
- Roster changes during combat do not modify the protected layout; the frame is resized safely once combat ends.

## 0.10.0-beta.4 — 2026-08-16

- Party buttons show actual member names instead of `P1`–`P4`.
- The party debuff icon reserves a name strip at the bottom, so members stay identifiable while an icon is showing.
- Names are only handed straight to a FontString for display; they are never read, truncated, compared or used in combat decisions.
- Raid keeps its compact, fixed `1`–`40` numbered grid.

## 0.10.0-beta.3 — 2026-08-16

- Fix secure buttons registering only `LeftButtonUp`, which performed no action under the default cast-on-down CVar.
- Register both LeftButton down and up, and use `useOnKeyDown=false` to cast exactly once, explicitly on release.
- Add dedicated tests for SecureActionButton click registration, fixed units and cast attributes.

## 0.10.0-beta.2 — 2026-08-16

- Fix clicks on the aura icon not triggering a dispel where the icon covers the secure button.
- Enable native mouse click propagation inside the aura button's initialization window, keeping the icon, cooldown swipe and tooltip intact.
- Keep `SetPassThroughButtons("LeftButton")` as a client compatibility fallback.

## 0.10.0-beta.1 — 2026-08-16

- Add a separate raid mode with pre-created, fixed `raid1`–`raid40` secure buttons.
- Add an 8 x 5 raid grid that switches in safely when in a raid, hiding the party layout.
- Party and raid keep separate saved positions and scales.
- `/sd scale` and `/sd reset` take `party`, `raid` and `all`.
- Raid buttons use 32 pixel icons and the native cooldown swipe, omitting the external duration text to avoid overlapping the grid.
- SavedVariables schema raised to 3, migrating the original five-player position and scale.
- Add a 45-button mock runtime test.

## 0.9.0-beta.1 — 2026-08-16

- Five-player party MVP: `player` and `party1`–`party4`.
- Add dragging, locking, scaling, resetting and settings persistence.
- Add an installable beta ZIP and a dungeon field-test checklist.

## 0.1.0-alpha.1 — 2026-08-16

- Establish the `player` and `party1` secure click and aura container proof of concept.
