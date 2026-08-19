# SimpleDispel

SimpleDispel is a lightweight, secure click-to-dispel addon for World of Warcraft Retail 12.1+.

It provides compact party and raid frames that show a Blizzard-filtered harmful aura and let you click the corresponding unit frame to cast your currently selected friendly dispel. The action is performed through a secure action button, so you do not need to switch your current target first.

> [!WARNING]
> SimpleDispel 1.0.0 is the first stable release. Protected-frame behavior still needs broader live-client validation across raid sizes, combat transitions, click-through behavior, performance conditions, and taint scenarios. Test it in low-risk content before relying on it for high keys, progression, or other important encounters.

## Current status

- **Addon version:** `1.0.0`
- **Target client:** World of Warcraft Retail 12.1+ (`Interface: 120100`)
- **Supported layouts:** solo/party and raid
- **Supported units:** `player`, `party1`-`party4`, and `raid1`-`raid40`
- **Aura display:** one system-filtered harmful aura per unit
- **Dependencies:** none; the addon does not require Ace3 or another third-party library
- **License:** MIT

For the current testing procedure, see [BETA_TESTING.md](BETA_TESTING.md). For the API boundaries and development decisions, see [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Release history is documented in [CHANGELOG.md](CHANGELOG.md).

## What “click-to-dispel” means

SimpleDispel intentionally uses a narrow and predictable definition of “one-click dispel”:

1. The addon creates a fixed frame for each supported unit.
2. Blizzard’s Aura Container system displays a filtered aura in that unit’s frame.
3. You click the frame for the affected unit.
4. A secure action button casts the configured friendly dispel directly on that fixed unit.
5. Your current target is not changed.

The addon does **not** provide an automatic dispel decision engine. It does not choose a unit, rank debuffs by danger, select an optimal target, or cast without a player click.

## Features

- Compact five-slot solo/party layout.
- Raid layout with eight columns, up to five rows, and forty fixed unit slots.
- Direct display of current party member names; raid members are identified by the normal unit-button tooltip.
- Raid range feedback for the currently selected friendly-dispel spell, without disabling clicks.
- Native aura icon, application count, tooltip, and cooldown display where supported by the client.
- A separate Aura Container for every pre-created unit slot.
- Secure unit-button actions that remain bound to fixed unit tokens.
- Secure visibility drivers for units that join or leave the group.
- Automatic selection of a known friendly-dispel spell from the player’s spellbook.
- Manual spell-ID override when automatic spell detection is not sufficient.
- A localized empty state instead of inactive unit buttons when the current character has no known friendly dispel.
- Separate saved position and scale for party and raid layouts.
- Movable, lockable, resettable, and scalable layouts.
- No target switching.
- No automatic clicking, input simulation, external process, or combat-log-based automation.

## Supported layouts

### Solo and party

The party layout contains five horizontal slots:

- `player`
- `party1`
- `party2`
- `party3`
- `party4`

The player slot is always available. Missing party units are hidden by secure state drivers. Party buttons are 48 × 48 pixels by default, with the member name shown in the lower part of the button. The name remains visible when an aura icon is displayed.

The party layout is visible outside a raid and is also used when you are alone.

### Raid

The raid layout pre-creates the following fixed unit tokens:

- `raid1` through `raid40`

Raid entries are arranged in eight columns. The frame uses only as many rows as the current roster requires, up to five rows for a forty-player raid. Each entry is a compact 28 × 28 pixel square by default:

- The filtered aura icon fills the square.
- Member names are not shown persistently; hover the normal unit button for the client tooltip when identification is needed.
- Only units that currently exist are shown.
- The player appears once in the `raidN` roster and is not displayed again as a separate `YOU` slot.

The raid roster remains in Blizzard’s fixed `raidN` order. SimpleDispel does not reorder members by name, class, role, group, or debuff priority. The tooltip is for identification only; it is never parsed or used to make a combat decision.

When the raid layout is locked, its title and large background are hidden and the grid is moved upward. Unlocking reveals the small `SD` drag anchor for positioning. During combat, a roster change may temporarily leave the raid frame at its previous height. The frame is resized after combat ends, when protected layout changes are safe.

### Range feedback

For the currently selected friendly-dispel spell, SimpleDispel checks the client’s `C_Spell.IsSpellInRange` result for each existing unit approximately every 0.25 seconds:

- `true`: the square keeps its normal appearance.
- `false`: the square receives a dark overlay, red border, and `×` marker so that out-of-range targets are obvious.
- `nil`: the range state is unknown, so the square keeps a neutral appearance rather than being reported as out of range.

Range feedback is visual guidance only. It does not disable or hide the click action, cannot determine line of sight, and may briefly lag behind movement or other client state changes.

## Installation

### Using a downloaded archive

1. Download or clone this repository.
2. Place the addon directory at:

   ~~~text
   World of Warcraft/_retail_/Interface/AddOns/SimpleDispel
   ~~~

3. Confirm that the TOC file is directly inside the directory:

   ~~~text
   World of Warcraft/_retail_/Interface/AddOns/SimpleDispel/SimpleDispel.toc
   ~~~

4. If the downloaded folder is named `simpledispel-main` or `simpledispel`, rename it to `SimpleDispel`.
5. Enable **SimpleDispel** on the character-selection screen.
6. Log in and run:

   ~~~text
   /reload
   ~~~

The addon directory must not contain an extra nested directory such as `AddOns/SimpleDispel/SimpleDispel-main/SimpleDispel.toc`.

### Using Git

From a shell, clone directly into the WoW AddOns directory:

~~~bash
git clone https://github.com/xrellana/simpledispel.git "<WoW installation>/_retail_/Interface/AddOns/SimpleDispel"
~~~

The repository contains development documents and mock tests in addition to the files required by the game. They do not affect addon loading.

## First-time setup

1. Enable Lua errors while testing:

   ~~~text
   /console scriptErrors 1
   ~~~

2. Reload the UI:

   ~~~text
   /reload
   ~~~

3. Check the diagnostic output:

   ~~~text
   /sd status
   ~~~

4. Unlock the frames:

   ~~~text
   /sd unlock
   ~~~

5. Drag the Party title bar or the Raid layout's small `SD` anchor.
6. Lock the frames when the position is correct:

   ~~~text
   /sd lock
   ~~~

Both party and raid positions are saved independently. Scale values are also saved independently. When locked, the raid title bar and large background are hidden and the raid grid moves up into the freed space; unlocking shows the small `SD` drag anchor again.

Layout movement, scale changes, spell-attribute changes, and raid frame resizing are subject to combat lockdown. If a change is requested during combat, SimpleDispel defers the protected update until combat ends.

## Slash commands

Both `/sd` and `/simpledispel` are registered as command aliases.

| Command | Description |
|---|---|
| `/sd status` | Print addon version, client/build information, active mode, Aura Container support, filter, button/container counts, saved scales, and active spell information. |
| `/sd lock` | Lock both layouts and disable dragging. |
| `/sd unlock` | Unlock both layouts; drag the Party title bar or the Raid `SD` anchor. |
| `/sd scale <0.60-2.00>` | Set the scale of the currently active layout. |
| `/sd scale party <0.60-2.00>` | Set the party layout scale explicitly. |
| `/sd scale raid <0.60-2.00>` | Set the raid layout scale explicitly. |
| `/sd scale <0.60-2.00> party` | Alternative syntax for setting the party scale. |
| `/sd scale <0.60-2.00> raid` | Alternative syntax for setting the raid scale. |
| `/sd reset` | Reset the currently active layout’s position and scale. |
| `/sd reset party` | Reset only the party layout. |
| `/sd reset raid` | Reset only the raid layout. |
| `/sd reset all` | Reset both layouts. |
| `/sd spell auto` | Remove a manual spell override and return to automatic spell selection. |
| `/sd spell <spellID>` | Set a manual spell-ID override. Use a spell ID from the current client’s spellbook. |
| `/sd filter mine` | Use the default `HARMFUL|RAID` filter. |
| `/sd filter group` | Use `HARMFUL|RAID_PLAYER_DISPELLABLE`. |
| `/sd filter all` | Use `HARMFUL|DISPELLABLE`. |

The `filter` command rebuilds the aura configuration only after a reload. Run `/reload` after changing the filter.

Running `/sd` without a recognized subcommand prints the command help.

## Friendly-dispel spell selection

On login and after spell, specialization, or talent changes, SimpleDispel checks the player’s spellbook and selects the first known candidate for the current class. The candidate order is the selection priority.

| Class | Candidate spells, checked in order |
|---|---|
| Druid | Nature’s Cure (`88423`) → Remove Corruption (`2782`) |
| Evoker | Naturalize (`360823`) → Expunge (`365585`) |
| Mage | Remove Curse (`475`) |
| Monk | Detox (`115450`) |
| Paladin | Cleanse (`4987`) → Cleanse Toxins (`213644`) |
| Priest | Purify (`527`) → Purify Disease (`213634`) |
| Shaman | Purify Spirit (`77130`) → Cleanse Spirit (`51886`) |

The addon verifies whether a candidate is actually known instead of assuming that every character of a class has every spell. If no candidate is found, the inactive unit buttons are replaced by a compact explanation for the current specialization; `/sd status` also reports `spell=none`. The normal frames return automatically after a spell, specialization, or talent change makes a dispel available.

To use a manual override:

~~~text
/sd spell <spellID>
~~~

To return to automatic selection:

~~~text
/sd spell auto
~~~

A manual override is useful when a specialization, talent setup, or client change prevents automatic detection from selecting the desired spell. The override must be known by the current character and is applied to the secure buttons when protected attributes can be changed safely. A saved override that is not known on another character is ignored, allowing automatic detection or the no-dispel state to take over.

## Aura filters

SimpleDispel does not scan, parse, compare, or rank aura payloads. It asks the client’s Aura Container system to display a filtered aura slot.

The available addon filter names map to these client filter strings:

| Addon filter | Client filter string | Purpose |
|---|---|---|
| `mine` | `HARMFUL|RAID` | Default project filter. |
| `group` | `HARMFUL|RAID_PLAYER_DISPELLABLE` | Alternative group-dispellable filter for comparison and troubleshooting. |
| `all` | `HARMFUL|DISPELLABLE` | Alternative broad dispellable filter for comparison and troubleshooting. |

The exact behavior of these filters is determined by the World of Warcraft client. The `mine` label is an addon configuration name, not a custom aura parser.

Only one `dispel` aura slot is created per unit. This keeps the display simple and avoids requiring the addon to inspect or prioritize multiple protected aura values.

## Security and API design

SimpleDispel is designed around the restrictions introduced by the Retail 12.1 addon environment.

### Aura display

- Uses `CustomAuraContainerTemplate` and the client-provided Aura Container API.
- Lets the client apply the configured filter.
- Does not enumerate protected aura values with custom combat-time logic.
- Does not use `UNIT_AURA` payloads to reconstruct or classify secret aura data.
- Does not infer aura contents from frame visibility, dimensions, timing, tooltips, sounds, or other side channels.
- Does not attach combat decision logic to a protected Aura Button.

### Secure click action

- Uses `SecureActionButtonTemplate`.
- Assigns a fixed unit token to each button.
- Assigns a spell action to the left mouse button.
- Registers both mouse-button directions and explicitly executes on mouse release rather than depending on the account-wide `ActionButtonUseKeyDown` setting.
- Updates protected spell attributes only outside combat.
- Uses secure state drivers to show or hide units that exist in the current roster.

### Display-only names

Party names are passed directly to display text fields. Raid names are provided by the normal unit-button tooltip instead of a persistent text field. Neither display path is:

- Compared or sorted.
- Truncated or transformed for logic.
- Used to choose a target.
- Used to decide whether a dispel should be cast.

This separation is deliberate. Unit tokens, not displayed names, determine the recipient of a click.

## Aura-button click behavior

The aura icon is displayed above the secure unit button. During Aura Button initialization, SimpleDispel attempts to preserve native mouse motion and tooltip behavior while propagating left-button input to the secure button underneath it. A client-compatible pass-through fallback is also configured when necessary.

Because this behavior depends on protected client-side frame handling, it must be verified in the live 12.1 client. If the icon displays correctly but clicking the icon does not cast, test the edge of the unit frame and report the result with the complete Lua error, if any.

## Testing

The repository contains two types of testing material.

### Offline mock tests

The files under [tests](tests) simulate enough of the WoW API to exercise the addon’s structural behavior without launching the game:

- [tests/test.lua](tests/test.lua) checks SavedVariables migration, creation of five party and forty raid buttons, Aura Container creation, unit-button setup, grid placement, visibility drivers, raid height calculation, scale commands, reset behavior, and combat-deferred updates.
- [tests/dispel_spells_test.lua](tests/dispel_spells_test.lua) checks class spell detection, known manual overrides, cross-character override fallback, and classes without a friendly dispel.
- [tests/secure_button_test.lua](tests/secure_button_test.lua) checks fixed unit attributes, secure click registration, spell attributes, range-overlay states, and party/raid visibility drivers.
- [tests/aura_input_test.lua](tests/aura_input_test.lua) checks Aura Button initialization, icon sizing, duration/cooldown setup, native mouse motion, and click propagation.

These tests are mock-runtime tests. They are useful for catching regressions in layout and setup logic, but they cannot prove that the live game will accept a protected action, avoid taint, or behave correctly in every combat scenario.

The test files are intended to be run from the repository root with a compatible Lua interpreter.

### In-game tests

Before testing in a dungeon or raid:

1. Enable Lua errors with `/console scriptErrors 1`.
2. Run `/sd status`.
3. Confirm the reported client build, active mode, Aura Container status, filter, and selected spell.
4. Test a low-risk scenario first.
5. Check that the correct unit is dispelled without changing the current target.
6. Test party and raid roster changes, combat entry and exit, death, moving into and out of dispel range, cooldowns, and missing spells.
7. Confirm that in-range squares look normal, out-of-range squares show the dark overlay/red border/`×`, and an unknown (`nil`) result remains neutral. Confirm that range feedback never disables a click and that line-of-sight failures are not treated as a range result.
8. Watch for `ADDON_ACTION_FORBIDDEN`, secret-value errors, forbidden-frame errors, taint, click-through failures, and sustained performance problems.

The detailed test matrix and issue-report template are in [BETA_TESTING.md](BETA_TESTING.md). The earlier Aura Container and secure-click prototype procedure is in [STAGE1_TESTING.md](STAGE1_TESTING.md).

## Known limitations

- The 1.0.0 release has not completed full live-client validation for every supported raid size and combat transition.
- Only one system-filtered harmful aura is displayed per unit.
- The addon does not automatically choose the most urgent or most valuable dispel target.
- The player must click the relevant unit frame; there is no automatic casting.
- Raid entries are fixed 28 × 28 pixel squares in `raid1`-`raid40` order, arranged as eight columns and at most five rows; they are not sorted by class, role, name, group, or debuff. Member identification is provided by the normal unit-button tooltip rather than a persistent name.
- Range checks use the currently selected friendly-dispel spell and refresh approximately every 0.25 seconds. The `C_Spell.IsSpellInRange` result can be delayed or `nil`; the indicator cannot determine line of sight and never disables clicking.
- The raid frame can temporarily retain its old height when the roster changes during combat; it is resized after combat.
- Layout movement and protected spell changes are unavailable during combat and are deferred until combat ends.
- Automatic spell selection currently covers the classes and candidate spells listed above. Other situations may require a manual spell override.
- Changing the aura filter requires a UI reload.
- The aura icon’s click propagation and tooltip interaction still require live-client regression testing.
- Performance and taint behavior with forty Aura Containers in a real raid require further validation.
- Retail 12.1+ is the target; Classic-era clients are not supported.

If any of the following occurs, stop relying on the current build for important content and report it:

- A click on one unit dispels a different unit.
- The current target changes unexpectedly.
- A protected-action or forbidden-frame error appears.
- The aura icon or unit frame becomes permanently unusable after combat.
- Raid mode causes persistent stuttering or abnormal memory growth.

## Reporting a bug

Please include enough context to reproduce the issue:

~~~text
Client version and build:
Class and specialization:
Party or raid mode and group size:
Instance or encounter:
Aura filter:
Selected spell and spell ID:

Expected behavior:
Actual behavior:
Correct aura icon: yes / no
Click on frame: success / failure
Click on icon: success / failure
Current target unchanged: yes / no
Performance: normal / degraded

Complete /sd status output:
Complete Lua error:
Additional steps to reproduce:
~~~

When reporting a target-binding problem, stop testing immediately and state which displayed unit was clicked and which unit actually received the spell.

## Repository structure

~~~text
SimpleDispel/
├── SimpleDispel.toc       # Addon manifest and load order
├── Core.lua               # Initialization, events, layouts, commands, and coordination
├── DispelSpells.lua       # Candidate spells and spellbook-based resolution
├── SecureButtons.lua      # Secure unit buttons and spell attributes
├── AuraDisplay.lua        # Aura Container creation and display initialization
├── tests/                 # Offline mock-runtime tests
├── BETA_TESTING.md        # Party and raid live-testing checklist
├── STAGE1_TESTING.md      # Initial 12.1 API validation procedure
├── DEVELOPMENT_PLAN.md    # Scope, API boundaries, and development gates
├── CHANGELOG.md           # Version history
└── LICENSE                # MIT license
~~~

The TOC currently loads the Lua modules in this order:

~~~text
DispelSpells.lua
SecureButtons.lua
AuraDisplay.lua
Core.lua
~~~

## Development guidelines

Changes that affect aura handling, secure buttons, combat lockdown, or protected attributes should be evaluated against the rules in [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

In particular:

- Do not bypass secret-value or forbidden-frame restrictions.
- Do not use taint, hooks, side channels, external automation, or input simulation to recover information or perform actions that the client does not expose.
- Keep aura API-specific code isolated in [AuraDisplay.lua](AuraDisplay.lua).
- Add or update mock tests when changing layout, button, or initialization behavior.
- Update [CHANGELOG.md](CHANGELOG.md) when a user-visible behavior changes.
- Validate changes in the live client before describing a feature as production-ready.

## License

SimpleDispel is released under the [MIT License](LICENSE).
