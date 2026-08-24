# SimpleDispel

Lightweight, secure click-to-dispel frames for **World of Warcraft Retail 12.1+**.

## What it does

SimpleDispel shows up to one Blizzard-filtered harmful aura per supported unit. Left-click the affected unit's frame to cast your selected friendly dispel directly on that unit—**your current target does not change**.

- Five-slot solo/party frame: `player` and `party1`–`party4`.
- Raid frame: up to 40 fixed units in an 8-column × 5-row grid.
- Automatically detects a known friendly-dispel spell and refreshes after specialization, talent, or spell changes.
- Shows the native aura icon, stack count, tooltip, duration/cooldown display, and party member name where the client provides them.
- Marks out-of-range units with a red border and `×`; an unknown range stays neutral. Range is visual guidance only and never disables clicks.
- Keeps debuffs visible while the dispel is on its real cooldown and adds a `CD` marker; the global cooldown alone does not trigger it.
- Separate saved position and scale for party and raid layouts, plus `dark` and `light` themes.
- No dependencies.

SimpleDispel is **not** an automatic dispel or decision engine: it does not select a target, prioritize debuffs, switch targets, or cast without your click.

## Quick setup

1. Run `/sd unlock`.
2. Drag the party title bar or the raid frame's small `SD` handle.
3. Optionally set scale and theme, then run `/sd lock`.
4. Left-click a unit frame when it shows a debuff you want to dispel.

Both `/sd` and `/simpledispel` are command aliases. Running `/sd` with no recognized subcommand prints the in-game help.

## Commands

| Command | Description |
|---|---|
| `/sd status` | Prints version/build, active layout, Aura Container support, filter, saved scales, theme, selected spell, and cooldown state. Useful for bug reports. |
| `/sd lock` | Locks both party and raid layouts and disables dragging. |
| `/sd unlock` | Unlocks both layouts so their visible handles can be dragged. |
| `/sd scale <0.60-2.00>` | Sets the active layout's scale. |
| `/sd scale <0.60-2.00> party` | Sets the party layout's scale. `/sd scale party <value>` also works. |
| `/sd scale <0.60-2.00> raid` | Sets the raid layout's scale. `/sd scale raid <value>` also works. |
| `/sd reset` | Resets the active layout's position and scale. |
| `/sd reset party` | Resets only the party layout's position and scale. |
| `/sd reset raid` | Resets only the raid layout's position and scale. |
| `/sd reset all` | Resets both layouts' positions and scales. |
| `/sd theme` | Prints the active theme. |
| `/sd theme dark` | Selects the default dark theme. |
| `/sd theme light` | Selects the light theme. Theme changes also work during combat. |
| `/sd spell auto` | Clears a manual override and returns to automatic spell selection. |
| `/sd spell <spellID>` | Uses a spell-ID override. The character must know the spell; the addon does not verify that it is a friendly dispel. |
| `/sd filter mine` | Uses `HARMFUL\|RAID` (default). |
| `/sd filter group` | Uses `HARMFUL\|RAID_PLAYER_DISPELLABLE`. |
| `/sd filter all` | Uses `HARMFUL\|DISPELLABLE`. |

Run `/reload` after changing the aura filter. The filter names map directly to Blizzard client filters; SimpleDispel does not inspect or rank aura data itself.

## Automatic spell detection

Candidates are checked in the order shown:

| Class | Friendly dispel candidates |
|---|---|
| Druid | Nature's Cure (`88423`) → Remove Corruption (`2782`) |
| Evoker | Naturalize (`360823`) → Expunge (`365585`) |
| Mage | Remove Curse (`475`) |
| Monk | Detox (`115450`) |
| Paladin | Cleanse (`4987`) → Cleanse Toxins (`213644`) |
| Priest | Purify (`527`) → Purify Disease (`213634`) |
| Shaman | Purify Spirit (`77130`) → Cleanse Spirit (`51886`) |

If the current character has no known candidate, the unit buttons are replaced with an inactive message. You may override detection with the ID of a known friendly-dispel spell.

## Important behavior and limitations

- Only one system-filtered harmful aura is displayed per unit.
- Raid slots remain in Blizzard's `raid1`–`raid40` order and are not sorted by role, class, group, name, or debuff priority. Hover a raid square to identify its unit with the normal tooltip.
- Range is checked approximately every 0.25 seconds for the selected dispel. It may briefly lag, may be unknown, and cannot detect line of sight.
- Movement, scale, lock-state layout updates, raid resizing, and secure spell changes requested during combat are applied after combat when necessary.
- Retail 12.1+ only; Classic clients are not supported.

SimpleDispel uses Blizzard's Aura Container and secure action-button systems. It performs no automatic clicking, input simulation, target switching, or combat-log-based dispel automation.
