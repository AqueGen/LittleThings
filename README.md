# LittleThings

Small touches on the default UI: the bits that were missing. Nothing is replaced and nothing is heavy. The LittleThings page has one switch per module, with what it does in the tooltip, and every switch starts off. Switch one on and its settings page appears under LittleThings; switch it off and the page goes. Off means the game runs exactly as Blizzard shipped it, and a module that is off costs nothing.

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

Off by default. Two bars of icons next to the character panel: your specializations, and the loot specialization (its first icon follows the current spec). One click switches, the active one is framed, the rest are dimmed. Each bar is placed on its own: drag it to wherever it stays out of whatever other addons draw on the panel, and the settings page shows the same position as a corner and an X and Y offset, plus where the bar's title sits (above, below or left of the icons).

### Group finder

One switch on the LittleThings page, off by default. Turned on, it brings up the Group finder page, where each of the four tools below has its own switch (all on) and its options, in three sections: Applicants, Creating a group, Player menus.

**Warcraft Logs link.** Right-click a player - in a unit frame, chat, the guild roster or the group finder - and copy their Warcraft Logs page, opened on the Mythic+ season rather than the raid tab. Off leaves every menu exactly as Blizzard built it. `/wcl name-realm` works either way.

**Keys and raid progress on applicants.** When your group is listed for a Mythic+ dungeon, each row shows two small numbers right of the rating, as the column label says: the applicant's best key anywhere on top in blue and their best key in the listed dungeon below in green, dimmed to grey-blue or grey when not timed. In raid listings, with Raider.IO installed, the same column shows raid progress from its public API instead, both for the listed raid only: its best difficulty with kills on top, the listed difficulty below (for example 9/9 over 6/9, right up against the wide Invite button raids get), coloured by difficulty: green Normal, blue Heroic, purple Mythic, with that legend over the column in place of Best / Here. Raider.IO has no LFR progress, so LFR has no colour. Without Raider.IO, or for a player it has no data on, the column stays empty; PvP and other listings are left alone. The list keeps Blizzard's order: on 12.x any addon change to it taints the applicant viewer, and the viewer then breaks with errors on the next roster change. The switch takes effect the next time the list updates, with no reload.

**Applicant filter.** While your group is listed, a panel sits beside the group finder, on the side the settings page sets; drag it where you want it and the page's X/Y offsets take the new spot, for fine-tuning by the pixel: class icons with how many applicants of each class there are (click once to need a class, again to exclude it, again or right-click to clear), role toggles, a minimum item level, and, in 5-player listings, Brings Bloodlust / Brings battle res, which, while your group lacks it, fail applications that bring none of what is missing (with both ticked, bringing either one is enough). Applicants who fail are dimmed and keep their place, for the same reason the list is not sorted; an invited applicant is never dimmed. A group applying together passes the item level only if every member does. Keys and raid progress are read off each row rather than filtered. Reset clears everything. Cancelled, timed out and declined applications leave the list at once (a setting on the page, on by default). Everything is saved per character.

**Group creation helpers.** Choosing a dungeon picks its Mythic+ difficulty rather than plain Mythic, so a leader listing someone else's key needs no extra click, and a list beside the screen shows the keystones your group shares through LibKeystone (DBM, BigWigs, EllesmereUI and others carry it), yours first, one click picks that dungeon at Mythic+ and puts the cursor in the title, with a grey hint of the level to type (such as type +16) that goes away once you type. The title itself stays yours to type, and the one the game builds is left as it is: the game does not let addons write it (tested, and blocked again when only stripping the playstyle from it). Each part has its own checkbox.

**Default playstyle.** Creating a listing opens with a playstyle already picked (Competitive unless you choose another on the page). The game lets only its own code create listings, so a playstyle the addon picked may get List Group blocked; if the game reports that, the switch turns itself off and says so in chat, and picking the playstyle by hand always works.

### Journal loot

Off by default. Every loot row in the Adventure Guide gets small icons for the specializations the item drops for: your class, or the class picked in the journal's filter. When every spec of the class gets it, one class icon stands in for them. With All classes on it shows every class, folded the same way into a class icon, a role icon (tank, healer, damage) or a single icon when everyone gets the item. By default the icons stand in one column in each row's bottom right corner, on the boss line where the row has one, and the armor type moves left only where they would cover it. They can sit on the name line instead, right of the item name. Size is 12 to 24 pixels.

### Group leader icons

Off by default. Blizzard's party and raid frames show nobody's rank, so this puts a crown on the group leader and an assistant icon on raid assistants, on the top left edge of their frame. It follows leader and assistant changes as they happen. Frames from other addons are left alone.

### Performance

Off by default. The page has Graphics, Memory and Addons sections.

**Graphics.** **Optimize my FPS** lowers the options that cost the most frames and matter least in a fight: shadows to Fair, ambient occlusion, depth and compute effects and outlines off, liquid detail, spell density, view distance, environment detail and ground clutter to their lowest, one set of settings for raids too. Textures stay High, particles stay Ultra and projected textures stay on, so spell effects and ground markers remain readable. Before anything changes, a window lists every setting it will touch, as it is now and as it will be, and nothing happens until you press Apply. **Restore my settings** puts back what you had before the first Optimize, with the same window first. The game keeps graphics settings itself, so they stay after the module or the addon is switched off. Neither button works in combat.

**Memory.** **Smoother garbage collection**, on by default, starts a collection after the Lua heap grows by 10% rather than by the game's default, so memory is freed in many small steps instead of one pass that shows as a hitch. Off, or the module off, puts the game's own values back at once. **Clean up in the open world**, on by default, frees thrown-away memory every 40 seconds in small steps spread over up to two seconds, only outside instances, never in combat or on a loading screen. **Collect garbage** frees everything now and prints the Lua memory before and after and the five addons holding the most. It is a diagnostic, not a speed-up: it stalls the game for a moment and gains no frames, and it refuses to run in combat.

**Addons.** **Show addon CPU**, or `/lt cpu` (also in combat), opens a table of every loaded addon with the game's own profiler figures: time per frame over the last second and since login, the slowest single frame, the average on the last boss, how many frames took over 50 ms (the hitches, by name; those rows are red) and memory. Click a column to sort by it. Times update every second while the table is open; memory updates when it opens and on Refresh memory, because measuring it is itself expensive.

## Commands

- `/lt` (or `/littlethings`, `/dmc`) - settings
- `/lt format`, `/lt snap` - toggle one damage meter feature
- `/lt cpu` - the addon performance table, also in combat
- `/lt diag` - what the addon sees, per meter window; useful when reporting a bug
- `/lt probe` - what the API says about Secret values right now
- `/wcl` - Warcraft Logs link for a name, or the target

## Development

`busted tests` runs the pure-logic suite - number composition, snap geometry, the drop preview and the transparency rules. Everything frame-bound is verified in game against `docs/IN-GAME-CHECKLIST.md`.

A module is one file (or one folder) under `Modules/`. It registers itself with `ns.RegisterModule(name, module)` and names its switch in `module.key` (a module with no key is always enabled and reads its switch itself); a switch is a row in `ns.MODULES` in `Core.lua`. A row without a `parent` is a switch on the root page and owns a settings page, `ns.pages[key]`, built at login when it is on or the moment it is switched on, and listed only while it is on; the module adds its options to it from `Pages`. A row with a `parent` is a switch on its parent's page, its options indented under it, and it is on only while its parent is: modules read `ns.IsOn(key)`, never `ns.db[key]`.
