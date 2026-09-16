# LittleThings

Small touches on the default UI: the bits that were missing. Nothing is replaced and nothing is heavy. Each module has its own settings page that opens with its switch, off means the game runs exactly as Blizzard shipped it, and a module that is off costs nothing.

Retail only, patch 12.1. No libraries, no dependencies.

Formerly DamageMeterCompanion. Everything it did is the Damage meter module, settings and key bindings carry over, and `/dmc` still opens the page.

## Modules

### Damage meter

A companion for Blizzard's built-in Damage Meter. It computes nothing itself - every number you see is still Blizzard's - and it never touches the meter's data or its windows' content. What it adds is layout and readability.

**Readable numbers.** `56716 K` becomes `56.72M`, in combat too. The abbreviation is the client's own routine, which accepts the Secret values an addon may not read and hands back a string the bar may show - the same chain Details paints with. Each of Blizzard's three Numbers modes keeps its own layout - the same format strings and rounding as without the addon. The percentage in Complete is the one part that needs arithmetic, which the client refuses on Secret values by every route, so in combat a Complete row is left as Blizzard paints it (percentage present, their abbreviation) and takes our abbreviation again once the values are readable.

**Window snapping.** Drag a window near another and a green bar shows which edges will meet. Release and they attach: the pair moves together, and the axis you joined on matches size. Windows chain, a gap between them is configurable, and a window dropped near a screen edge lands flush with it.

**A window page.** Lists Blizzard's three windows with their exact size in pixels, what is attached to what, the gap, a lock per window and Lock all / Unlock all. Window 1's size is routed through Edit Mode, which is the only thing allowed to set it.

**Transparency and layer.** The meter dims when the mouse is away and comes back when it is over it, as a fraction of the Edit Mode transparency you already set. The frame layer is a dropdown, for when another addon covers the meter.

**One place for the meter's settings.** The game's own Enable and Auto Reset switches are mirrored at the bottom of the page, marked as Blizzard's, and the meter's gear menu has an entry that opens the page (out of combat - in combat an entry of ours would taint the menu's own layout).

**Key bindings** to show or hide the meter, hide every extra window, and reset the data.

What it deliberately does not do, and why: on 12.x the meter's data is Secret to addons in combat, and anything an addon writes into Blizzard's meter windows taints them: their own refresh then logs a warning per row, in combat, until you reload. So this module never opens Blizzard's own breakdown (click it - that is Blizzard's own, untainted handler), does not switch a window's type or segment (the header dropdowns do, untainted), does not create windows beyond Blizzard's three, and does not show a hidden window (the gear menu's Show new window does). Each of those was built, seen to taint the meter, and removed. The reasoning with line references is in `docs/DECISIONS.md`.

Three things on the window page do go through Blizzard's code and taint it the same way: locking a window, setting a size (typed, or matched onto a neighbour by a hand resize), and showing a hidden slot. They stay because a reload clears them completely - Blizzard restores the lock, the size and the window itself at login. A size change or a show offers a reload, once per session; a lock does not (its only effect is on the gear menu opened in combat). Dragging, snapping and the gap are position only and never need it.

No parsing, no storage, no analysis, no skins, no report-to-chat. Blizzard's meter is the meter. If you want a meter of your own, use Details.

### Character panel

Off by default. Spec row: two rows of icons next to the character panel: your specializations on the left, loot specialization on the right (the first icon follows the current spec). One click switches, the active one is framed, the rest are dimmed. Drag the row to wherever it stays out of whatever other addons draw on the panel; the settings page shows the same position as a corner and an X and Y offset.

### Mythic+ log link

Off by default. Right-click a player - in a unit frame, chat, the guild roster or the group finder - and copy their Warcraft Logs page, opened on the Mythic+ season rather than the raid tab. Off leaves every menu exactly as Blizzard built it. `/wcl name-realm` works either way.

## Commands

- `/lt` (or `/littlethings`, `/dmc`) - settings
- `/lt format`, `/lt snap` - toggle one damage meter feature
- `/lt diag` - what the addon sees, per meter window; useful when reporting a bug
- `/lt probe` - what the API says about Secret values right now
- `/wcl` - Warcraft Logs link for a name, or the target

## Development

`busted tests` runs the pure-logic suite - number composition, snap geometry, the drop preview and the transparency rules. Everything frame-bound is verified in game against `docs/IN-GAME-CHECKLIST.md`.

A module is one file (or one folder) under `Modules/`. It registers itself with `ns.RegisterModule(name, module)` and names its switch in `module.key`; a switch is a row in `ns.MODULES` in `Core.lua`, which also gives the module its settings page as `ns.pages[key]`, opened with the switch. The module adds its own options to that page from `Enable`.
