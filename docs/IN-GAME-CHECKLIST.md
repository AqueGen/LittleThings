# DamageMeterCompanion - in-game checklist

Everything the headless build cannot verify. Rewritten 2026-09-07 evening after the taint cut (see DECISIONS.md); windows beyond Blizzard's three and the addon's own right-click menu are gone because those features are; hover is gone.

Setup: `/reload`, hit a target dummy so the meter has data, keep BugSack open. **The bar for every section is the same: BugSack stays empty, in combat and out.**

## 1. It loads at all

- [ ] No Lua error on login.
- [ ] `/dmc` opens the settings panel; the meter's own gear menu has a DamageMeterCompanion settings entry out of combat; in combat the entry is absent and the menu opens without error.
- [ ] `/dmc probe` and `/dmc diag` print without error.

## 2. Numbers

- [ ] In combat the bars read `56.72M` or `56.72M (40.6K)` depending on the Edit Mode Numbers setting, steady, no flicker back to `56716 K`.
- [ ] Complete mode in combat shows Blizzard's own text with the percentage (`3267 K (40,639) 18%`); out of combat, once Blizzard has refreshed with plain rows, it reads `3.27M (40.6K) 18%`. Minimal and Compact read in our abbreviation in combat too.
- [ ] The spell breakdown (opened with Blizzard's own click) reads the full form.
- [ ] Turning Readable numbers off puts Blizzard's text back within a moment; on again re-formats.
- [ ] A full pull with the breakdown open and closed, then leave combat: **no `attempt to compare` warnings**.

## 3. Snapping and size matching

- [ ] Dragging window 2 so its top edge nears the bottom of window 1 shows the green bars, and on release it sits flush and matches window 1's width.
- [ ] Moving window 1 in Edit Mode carries window 2 with it.
- [ ] Resizing window 1 in Edit Mode resizes window 2's width to match.
- [ ] Dragging window 2 well away breaks the link.
- [ ] Snapping window 3 to the right of window 2 matches heights instead of widths.
- [ ] Chain: 3 under 2, 2 under 1. Resizing window 1 resizes both.
- [ ] Lock window 2, resize window 1: window 2 still follows the width (a matched axis is an anchor; the lock only stops dragging and the handle).
- [ ] Detach window 2, `/reload`: it comes back where it was.
- [ ] Hide a snapped window, show it again from the gear menu: it comes back attached.
- [ ] Dropping a window near a screen edge with no window near lands it flush; the bars show on the window's and the screen's edge.
- [ ] Gap of 6 on a linked window separates the pair by six pixels and survives a reload.
- [ ] `/reload` keeps every link and size.
- [ ] **With a matched link in place, `/reload`, touch nothing, fight**: no reload popup at login and BugSack stays empty. This is the case that used to taint every session.
- [ ] **Resizing window 1 or 2 by its handle while a neighbour matches it shows no reload popup, and the next fight leaves BugSack empty** - the matched size comes from anchors, not from our code.
- [ ] A matched window's own handle: only the free axis resizes (width is held by the anchors when matched by width). Detaching it keeps a sensible size - note any jump to an old width.
- [ ] Unticking match width on the page frees the width; ticking it again snaps it back to the target's width.
- [ ] Window 2 stacked on window 1, tick match height: window 2 takes window 1's height at once and the reload popup appears. After the reload the height is still the same and the next fight leaves BugSack empty.
- [ ] Type a size for a window that was never dragged, reload: the size is still there.

## 3a. Following an Edit Mode layout switch

Needs two Edit Mode layouts whose damage meter sits in a different place, and whose Frame Width differs. Assign the second layout to a second specialization.

- [ ] Switch layout by hand in the Edit Mode UI: window 1 moves with the layout and windows 2 and 3 stay attached to it.
- [ ] Same switch with differing Frame Width: the matched windows take window 1's new width, with no reload popup.
- [ ] Switch specialization so the layout changes with the Edit Mode UI closed: the chain follows, both position and matched width.
- [ ] Switch back and forth between layouts with different widths, then fight: no reload popup and BugSack stays empty.
- [ ] `/reload` on a character whose layouts have different widths, touch nothing, fight: **no reload popup at login** and BugSack stays empty. Login must never push a size.

## 4. Transparency and layer

- [ ] Mouse away: roughly 40 percent of the Edit Mode transparency. Mouse over: the Edit Mode value.
- [ ] Cursor moving from the bars into an open breakdown keeps both at full alpha; leaving dims them within about a fifth of a second.
- [ ] A window shown from the gear menu picks up the idle transparency and the layer immediately.
- [ ] Changing Transparency in Edit Mode still works and both states move with it.
- [ ] The Layer dropdown moves the meter above other frames, breakdown still in front of the bars.

## 5. Key bindings

- [ ] Three bindings under DamageMeterCompanion: toggle the meter, hide all extra windows, reset data.
- [ ] The toggle hides and shows the whole meter out of combat; in combat it works or prints a message, never throws.
- [ ] Hide all hides windows 2 and 3; they come back through the gear menu's Show new window.
- [ ] Reset clears the meter like the gear menu's Reset.

## 6. Settings panel

- [ ] Fresh profile: the LittleThings page has four switches, Damage meter, Character panel, Group finder and Journal loot, all off, each with its description on hover, and no module pages under it. A profile adopted from Damage Meter Companion keeps the damage meter on; a profile with any group finder tool on has Group finder on.
- [ ] Switch Journal loot on: its page appears under LittleThings at once. Switch it off: the page leaves the list at once. Pages keep the root page's order whichever is switched on first.
- [ ] Switch Group finder on: its page shows Sort applicants, Applicant filter panel, Group creation helpers and Warcraft Logs link, all ticked, each with its options indented under it. Untick one: its options go and the feature stops (the filter panel hides, the menu entry goes). Group finder off: every tool stops at once and the page goes, and the tools keep their own ticks for next time.
- [ ] The behaviour page has readable numbers, snapping, snap distance, idle transparency, layer, and at the bottom a Blizzard section with Enable Damage Meter and Auto Reset that mirror Gameplay Enhancements both ways.
- [ ] The addon list has one Damage meter entry, with Windows nested under it. The Windows page lists three rows. Ticking Shown on a hidden slot shows the window and offers a reload; after the reload the window is there and combat logs nothing. Window 1's size boxes route through Edit Mode; a size Edit Mode refuses prints a message.
- [ ] Typing an out-of-range width comes back clamped. A locked window's boxes are greyed.
- [ ] The page shows "locked" next to a window locked from its gear menu and nothing once it is unlocked there; `/lt taint` after either stays clean.
- [ ] **Lock window 2 from the panel, reload, fight, open window 2's gear menu in combat**: it opens, BugSack stays empty. (Without the reload the gear menu errors in combat - known, accepted.)
- [ ] **Type a size for window 2, reload, fight**: BugSack stays empty.
- [ ] Hide on a row hides the window; the row stays.
- [ ] Snapping two windows and reopening the page shows the link, gap and match flags; Detach drops it.
- [ ] **After typing a size for window 1, open Edit Mode and press Save**: no "Interface action failed because of an addon".

## 7. Journal loot

- [ ] Switch on Journal loot, open the Adventure Guide on a current dungeon boss, Loot tab: rows show your class's spec icons, and an item every spec of your class gets shows one class icon. No reload needed.
- [ ] Pick another class in the journal's class filter: the icons follow that class. Clear the filter: back to yours.
- [ ] Scroll the list and switch bosses, difficulty and the slot filter: icons stay on the right rows, none linger on header rows.
- [ ] All classes on: trinkets and rings fold into role icons or the everyone icon, armor into class icons plus loose specs.
- [ ] Default position "Bottom right corner": the icons form one column in the row's bottom right corner, as in EQoL. Dungeon rows put them on the boss line and the armor text never moves. Raid boss rows (no boss line): one icon fits right of the armor text, two or more push the armor text left at its own height. Nothing is covered. With the module off or on the name line the armor text is back in Blizzard's place.
- [ ] "Name line, right edge" puts the icons right of the item name, clear of a transmog addon's corner mark. Switching between the two is live, and so is the size slider.
- [ ] A profile saved with a position that no longer exists opens on the slot line.
- [ ] Switch off: icons disappear at once. BugSack stays empty throughout, and the journal's own class filter is unchanged after every step.
- [ ] Loot tab of a boss: a row of 40-pixel loot specialization icons, one per spec and no 'current specialization' icon, sits at the bottom right, below the list, not covering the journal's frame or another addon. The current loot spec is framed; with the loot spec following the current spec, the current spec is framed. The size slider resizes the row at once. Click another: it is framed at once and chat shows the game's loot spec message. The Overview and Abilities tabs do not show the row.
- [ ] Change spec or loot spec on the character panel with the journal open: the row follows. Untick Loot specialization buttons: the row goes at once; switch Journal loot off: it goes too.
- [ ] Character panel module on: both its bars still switch spec and loot spec as before, with 40-pixel icons on a profile that never set a size. Each bar's Icon size slider resizes only that bar at once, the title stays centred under the icons, and a drag still saves the position.

## 8. Applicant keys

- [ ] Switch on Keys and raid progress on applicants, list a Mythic+ key: the key numbers appear without a reload.
- [ ] Sort applicants on, Mythic+ sort by Rating: bright applicants come first, highest rating on top, dimmed ones below them. Switch to Item level: the order follows at once. In a raid listing, Progress and Item level do the same.
- [ ] Only missing roles on, a healer slot open: healers rise to the top. Someone joins as healer: healers drop down and the next missing role rises, without touching anything.
- [ ] Listed with the list sorted, pull a mob (combat), then a boss (encounter), with applicants arriving and someone joining or leaving: the list falls back to Blizzard's order, BugSack has no "secret" errors from LFGList.lua 1699 or 1760, invite and decline work; after combat the list is sorted again.
- [ ] Listed, with applicants waiting, someone joins or leaves the group, in and out of an instance: BugSack has no errors from LFGList.lua (no "secret" at 1760 or 1699), invite and decline work.
- [ ] Switch off: the key numbers and the column label go away at the next list update.

## 9. Applicant filter

- [ ] Switch on Applicant filter, list a Mythic+ key, open the applicants: the panel sits right of the finder with a solid background and shows Classes, Roles, Minimum item level, Group utility and Reset; it is gone on the search list and when the finder closes. Drag it by its background: it stays where dropped, the page's X/Y offsets show the new values, and the spot is kept after /reload. Panel side Left and the offsets move it at once.
- [ ] List a raid: the panel drops Group utility. Over the column, a Normal / Heroic / Mythic legend in green / blue / purple replaces Best / Here.
- [ ] Listed, zone into the dungeon (or a raid leader into the raid), applicants arrive and cancel, someone joins: BugSack stays empty; the list is Blizzard's, rows are not dimmed and the panel says Filter paused until you leave the instance.
- [ ] Class icons show counts, including dimmed applicants; need, exclude and clear work as the tooltip says.
- [ ] Minimum item level 300: applicants below are dimmed and stay in place; "Dimmed: N" matches. Empty the box: back to normal. Type 0: nothing is dimmed.
- [ ] Roles: tank toggled off dims tank-only applicants; a tank/damage flex stays bright, and Only missing roles unticks itself.
- [ ] Only missing roles on, group of tank, healer and two damage: only the damage toggle is lit, damage applicants are bright, the rest dimmed. Someone leaves or swaps spec: the toggles follow at once.
- [ ] Brings Bloodlust with no Bloodlust class in the group: shamans, mages, hunters and evokers stay bright, everyone else is dimmed. Once a Bloodlust class joins, nothing is dimmed. Both boxes: applications bringing either Bloodlust or battle res stay bright, the rest are dimmed; once one of them is in the group, only the other one is asked for.
- [ ] An invited applicant is never dimmed, whatever the filters say.
- [ ] Rows show two small numbers right of the rating, under a "Best / Here" label: best key anywhere on top in blue, this dungeon below in green, each dimmed when not timed, label colours matching, clear of the invite buttons; nothing on cancelled rows.
- [ ] List a raid with Raider.IO installed: each row shows two small progress lines (kills/bosses, no letter) just left of the Invite button and clear of it, this raid only (older raids never show): its best difficulty on top, the listed difficulty below, coloured N green / H blue / M purple; empty for players Raider.IO does not know. Without Raider.IO: no error, no text.
- [ ] An applicant cancels, times out or is declined: the row leaves the list at once. Remove closed applications off: the row stays with its X, as Blizzard shows it.
- [ ] List section: Sort by shows the current order (Rating / Item level / This dungeon for Mythic+, Progress / Item level for a raid); picking one resorts at once, Blizzard order stops sorting and the settings page's Sort applicants switch is unticked. Show keys and progress and Remove closed applications match the settings page and act without a reload. The section has no Sort by in PvP or other listings.
- [ ] Reset clears everything. Invite and decline from a filtered list work, BugSack stays empty.
- [ ] Reload keeps every setting; another character starts clean; a character that had class picks from the old bar keeps them. Values saved for the removed options (minimum rating, keys) have no effect.
- [ ] Switch off: the panel disappears and the list is Blizzard's again at once.

## 10. Default playstyle

- [ ] Switch on, Premade Groups > Dungeons > Create: the playstyle dropdown already says Competitive. List Group works, no "Interface action failed because of an addon".
- [ ] If the game blocks the title or the listing: chat names the blocked call and says the group creation helpers were turned off, the switch is off, the keystone list is gone, and after /reload listing with a hand-picked playstyle works.
- [ ] Choose a dungeon you hold no key for: the second dropdown says Mythic Keystone, not Mythic. Pick Mythic by hand: it stays Mythic.
- [ ] Open Create in Dungeons with a keystone in your bags, in and out of an instance: the game's own title is there (playstyle included), a title you typed stays as typed, BugSack has no ADDON_ACTION_BLOCKED for LittleThings, List Group works.
- [ ] In a party whose members run DBM or BigWigs, open Create in Dungeons: Group keystones lists everyone's key, yours first; clicking one picks that dungeon at Mythic Keystone and puts the cursor in the title with a grey 'type +N' hint on its right; typing, picking another dungeon or closing the screen clears the hint. For someone else's key the title is not left empty, so List Group stays available. A member leaving drops their key; no keys at all hides the list.
- [ ] Pick Relaxed on the page: the next new listing opens with Relaxed. Editing an active listing keeps its own playstyle.

## 11. Performance

- [ ] Switch on Performance: a Performance page appears with a Graphics section (Optimize my FPS, Restore my settings) and a Memory section (Smoother garbage collection and Clean up in the open world ticked, Collect garbage) and an Addons section (Show addon CPU). Every label in the confirmation window reads like the game's own graphics menu (Fair, Disabled, a 1-10 number for view distance), none is a bare number or blank.
- [ ] Raise shadows and view distance in the game's graphics menu, press Optimize: the window lists only what differs, as before > after. Cancel changes nothing. Apply: the game's graphics menu shows the new values, no error.
- [ ] Press Optimize again: chat says the settings are already optimized, no window.
- [ ] Press Restore: the window lists the values from before the first Optimize. Apply puts them back. Restore again: chat says nothing to restore.
- [ ] Open the page in combat and press either button: chat says it cannot be done in combat, nothing changes.
- [ ] With SmartGarbageCollector disabled: `/run local p = collectgarbage("setpause", 100) collectgarbage("setpause", p) print(p)` prints 110 while Smoother garbage collection is on. Untick it and run the line again: it prints the game's own value. Tick it again, switch Performance off, run it: the game's own value.
- [ ] In a city, out of combat, with Clean up in the open world on: `/run C_Timer.NewTicker(5, function() print(floor(collectgarbage("count") / 1024)) end)` shows Lua memory dropping every 40 seconds without a visible hitch. In a dungeon or in combat it only climbs. Untick it: no more drops in the city. `/reload` stops the printing.
- [ ] Collect garbage out of combat: chat prints Lua memory before > after, the freed amount and five addons with sizes. In combat: chat refuses, no stall.
- [ ] Show addon CPU opens the Addon performance window: every loaded addon in a row, columns lined up under their headers, Average highlighted and sorted highest first. Now changes every second, Memory does not until Refresh memory. Clicking Addon sorts by name, clicking Hitches puts red rows on top. Drag moves it, Esc and the X close it, the button again toggles it.
- [ ] In combat, `/lt cpu` opens and closes the window, no error, no "Interface action failed". `/lt` with no argument still opens the settings.
- [ ] A few hours of play with SmartGarbageCollector removed, then Show addon CPU: no addon has more frames over 50 ms than before the switch, and the game does not feel less even.

## 12. Group leader icons

- [ ] Switch on Group leader icons in a party using Blizzard's party frames: the leader's frame gets a whole crown in its top left corner, inside the frame, at once, no reload. It is not cut off by the frame above, whichever member leads. Nobody else gets an icon.
- [ ] Promote someone else: the crown moves to them. Leave and rejoin: it is on the right member again.
- [ ] In a raid, make someone an assistant: they get the assistant icon; the leader keeps the crown. Demote them: the icon goes.
- [ ] Switch raid frames between "Keep groups together" and separate frames: icons stay on the right people. Nameplates and arena frames never get one, and walking past enemies with nameplates on, in the open world and in a dungeon, leaves BugSack empty (nameplate frames are forbidden objects the module must not touch).
- [ ] Enter combat in a raid instance: icons stay put, BugSack stays empty, no "Interface action failed".
- [ ] The crown does not cover the role icon or the name enough to hurt reading them.
- [ ] Switch off: every icon disappears at once.

## 13. Sign-up roles

- [ ] Premade Groups > Dungeons: tank, healer and damage icons sit at the top of the search panel, clear of the category name and of PGF's checkbox; roles your class cannot play are missing. The lit icons match the Dungeon Finder's role checkboxes.
- [ ] Click a role: it lights or dims at once, and the Dungeon Finder's checkbox for it follows. Tick a role in the Dungeon Finder: the icon follows. The leader flag is unchanged.
- [ ] Sign up to a group: Blizzard's dialog opens with the roles the icons show. With PGF's skip-dialog on, the application goes out with those roles (the group's applicant list shows them).
- [ ] Click a role in combat: either it works, or chat says the role icons were turned off and the switch is off. BugSack has no "Interface action failed" either way.
- [ ] Switch off: the icons go at once.
