# DamageMeterCompanion - in-game checklist

Everything the headless build cannot verify. Rewritten 2026-09-07 evening after the taint cut (see DECISIONS.md); windows beyond Blizzard's three and the addon's own right-click menu are gone because those features are; hover is gone.

Setup: `/reload`, hit a target dummy so the meter has data, keep BugSack open. **The bar for every section is the same: BugSack stays empty, in combat and out.**

## 1. It loads at all

- [ ] No Lua error on login.
- [ ] `/dmc` opens the settings window; the meter's own gear menu has no LittleThings entry, and opening it in combat logs nothing in BugSack.
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

## 6. Settings pages

- [ ] Fresh profile: Damage meter, Group leader icons, Raid marker panel, Character panel and Performance are off, Group finder and Journal loot are on, each module's switch on its page with its description. A profile adopted from Damage Meter Companion keeps the damage meter on; a profile with any group finder tool on has Group finder on.
- [ ] Switch Journal loot on: its options appear on its page at once. Switch it off: the options go and only the switch and description stay, and the menu entry greys.
- [ ] Switch Group finder on: its page shows Sort Mythic+ applicants, Applicant filter panel, Group keystones and Warcraft Logs link, all ticked, each with its options under it. Untick one: its options go and the feature stops (the filter panel hides, the menu entry goes). Group finder off: every tool stops at once and the page shows only the switch and description, and the tools keep their own ticks for next time.
- [ ] The behaviour page has readable numbers, snapping, snap distance, idle transparency, layer, and at the bottom a Blizzard section with Enable Damage Meter and Auto Reset that mirror Gameplay Enhancements both ways.
- [ ] The menu has Damage meter and Meter windows entries. The Meter windows page lists three rows. A hidden slot says "hidden" and points at the gear menu's Show new window; there is no way to show a window from the page. Window 1's size boxes route through Edit Mode; a size Edit Mode refuses prints a message.
- [ ] Typing an out-of-range width comes back clamped. A locked window's boxes are greyed.
- [ ] The page shows "locked" next to a window locked from its gear menu and nothing once it is unlocked there; `/lt taint` after either stays clean.
- [ ] **Lock window 2 from the panel, reload, fight, open window 2's gear menu in combat**: it opens, BugSack stays empty. (Without the reload the gear menu errors in combat - known, accepted.)
- [ ] **Type a size for window 2, reload, fight**: BugSack stays empty.
- [ ] Hide on a row hides the window; the row stays.
- [ ] Snapping two windows and reopening the page shows the link, gap and match flags; Detach drops it.
- [ ] **After typing a size for window 1, open Edit Mode and press Save**: no "Interface action failed because of an addon".

## Settings window

- [ ] `/lt` opens the window; `/lt` again while open keeps it open on the same page. Esc and the X close it. Game > Options > AddOns > LittleThings shows a short page with Open LittleThings, which closes the game's options and opens the window. The damage meter gear menu's LittleThings settings opens the Damage meter page.
- [ ] The menu shows Group content (Group finder, Group leader icons, Raid marker panel), Combat (Damage meter, Meter windows), Character and loot (Character panel, Journal loot), System (Performance). Switched-off modules are grey but open their page, which shows only the switch and the description; Meter windows instead shows a note asking to switch the Damage meter module on.
- [ ] Drag by the title moves the window, the corner grip resizes it, it never goes below 800x480 and never changes size by itself. Position and size are the same after /reload.
- [ ] Every page's controls do what the old Blizzard pages did: damage meter behaviour, layer, the two Blizzard switches, the Meter windows rows; both character panel bars; journal loot icons and loot spec buttons; group finder sections with their own switches; Memory, Graphics and Addons buttons. Values changed elsewhere (filter panel, /lt format) show on the page when it is opened again.
- [ ] Changing Mythic+ sort by, Sort Mythic+ applicants or Damage meter offers a reload, as before.
- [ ] Enter combat with the window open: module switches, the Blizzard meter switches, Graphics buttons, Collect garbage and the Meter windows size / match controls go grey; everything else still works; after combat they come back. Open the window in combat with /lt: it opens.
- [ ] No new BugSack errors from any of the above, including opening each page once.
- [ ] Performance page, Show addon CPU: the addon CPU window opens in front of the settings window; clicking either brings it forward.
- [ ] A reload prompt or the Graphics confirmation shows in front of the window; if the window is clicked while one is open the popup can end up behind it - known, the popup stays until answered.

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
- [ ] Sort Mythic+ applicants on, Mythic+ sort by Rating: bright applicants come first, highest rating on top, dimmed ones below them. Pick Item level on the Group finder page: a reload prompt appears and the order changes only after the reload. Untick the switch: same prompt, Blizzard's order after the reload. A raid listing keeps Blizzard's order.
- [ ] Only missing roles on, a healer slot open: healers rise to the top. Someone joins as healer: healers drop down and the next missing role rises, without touching anything.
- [ ] Mythic+ listing, sorted, with applicants arriving and people being invited and leaving: count the "secret" errors from LFGList.lua 1699 / 1760 in BugSack per key, and check invite and decline still work and the header (Auto Accept, Browse Groups, Remove Listing) still looks right.
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
- [ ] List section: no sort menu. Show keys and progress and Remove closed applications match the Group finder page and act without a reload.
- [ ] Reset clears everything. Invite and decline from a filtered list work, BugSack stays empty.
- [ ] Reload keeps every setting; another character starts clean; a character that had class picks from the old bar keeps them. Values saved for the removed options (minimum rating, keys) have no effect.
- [ ] Switch off: the panel disappears and the list is Blizzard's again at once.

## 10. Group keystones

- [ ] In a party whose members run DBM or BigWigs, open Premade Groups > Dungeons > Create: Group keystones lists everyone's key, yours first. Clicking a row does nothing. A member leaving drops their key; no keys at all hides the list; another category hides it.
- [ ] Pick a dungeon, a difficulty and a playstyle by hand and press List Group: it lists, BugSack has no ADDON_ACTION_BLOCKED and no LFGList.lua error for LittleThings.
- [ ] Switch off on the Group finder page: the list is gone at once; on again: it is back without a reload.

## 11. Performance

- [ ] Switch on Performance: its page shows a Graphics section (Optimize my FPS, Restore my settings) and a Memory section (Smoother garbage collection and Clean up in the open world ticked, Collect garbage) and an Addons section (Show addon CPU). Every label in the confirmation window reads like the game's own graphics menu (Fair, Disabled, a 1-10 number for view distance), none is a bare number or blank.
- [ ] Raise shadows and view distance in the game's graphics menu, press Optimize: the window lists only what differs, as before > after. Cancel changes nothing. Apply: the game's graphics menu shows the new values, no error.
- [ ] Press Optimize again: chat says the settings are already optimized, no window.
- [ ] Press Restore: the window lists the values from before the first Optimize. Apply puts them back. Restore again: chat says nothing to restore.
- [ ] Open the window in combat: the Graphics buttons are greyed, and if one is pressed anyway chat says it cannot be done in combat, nothing changes.
- [ ] With SmartGarbageCollector disabled: `/run local p = collectgarbage("setpause", 100) collectgarbage("setpause", p) print(p)` prints 110 while Smoother garbage collection is on. Untick it and run the line again: it prints the game's own value. Tick it again, switch Performance off, run it: the game's own value.
- [ ] In a city, out of combat, with Clean up in the open world on: `/run C_Timer.NewTicker(5, function() print(floor(collectgarbage("count") / 1024)) end)` shows Lua memory dropping every 40 seconds without a visible hitch. In a dungeon or in combat it only climbs. Untick it: no more drops in the city. `/reload` stops the printing.
- [ ] Collect garbage out of combat: chat prints Lua memory before > after, the freed amount and five addons with sizes. In combat: chat refuses, no stall.
- [ ] Show addon CPU opens the Addon performance window: every loaded addon in a row, columns lined up under their headers, Average highlighted and sorted highest first. Now changes every second, Memory does not until Refresh memory. Clicking Addon sorts by name, clicking Hitches puts red rows on top. Drag moves it, Esc and the X close it, the button again toggles it.
- [ ] In combat, `/lt cpu` opens and closes the window, no error, no "Interface action failed". `/lt` with no argument still opens the settings window.
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

## 14. Summary site links

- [ ] Fresh install or a profile that never had it: Group finder page shows Summary site links unticked; no Compare applicants button on a Mythic+ listing and no Summary page entry in player menus.
- [ ] Tick it: the button appears on a Mythic+ listing at once, and right-clicking a player shows Summary page under LittleThings. No Set address button anywhere.
- [ ] Press Compare applicants: the popup holds a full https://brag-sheet.aquegen.workers.dev/compare?... link; pasted into the browser it starts checking the first batch (with a saved WCL key), and Open link from clipboard on an open compare page loads it too.

## 15. Raid marker panel

Switch on Raid marker panel (Group content). It is off by default. Its page has a Visibility group (Show when solo, In a party, only as leader, In a raid, also without lead or assist, Hide in combat; all off by default) and Lock position, Scale, Vertical, Pull left/right seconds and Reset position, and a Placement order group (1st..8th). The panel also shows while this page is open, so it can be placed solo.

- [ ] No Lua error on login with the module on and off; switching it on and off live works.
- [ ] Solo: open the Raid marker panel page - the panel appears; drag it, close the window - it hides and keeps the new spot after /reload.
- [ ] Solo, settings page open at the default position: the panel shows above the settings window.
- [ ] Solo with the window closed: Show when solo on - the panel shows; off - it hides.
- [ ] Party member without lead: In a party, only as leader on - the panel hides; off - it shows. As party leader it shows either way.
- [ ] Raid member without lead or assist: In a raid, also without lead or assist on - the panel shows; off - it hides.
- [ ] **Hide in combat on: pull a mob - the panel hides at once and returns after combat, no `ADDON_ACTION_BLOCKED`.**
- [ ] Hide in combat off: the panel stays during combat.
- [ ] Party leader: all 8 target markers set (left click) and clear (right click) on the target, Clear all removes markers from every unit, world markers place and clear one by one, the last Clear all button clears every world marker.
- [ ] Party member without lead: panel shown, the Ready, Pull and Role labels turn grey and their tooltips say why; the buttons are not disabled, a click does nothing.
- [ ] Raid as a plain member: panel hidden. Given assistant out of combat: it shows. Given assistant in combat: it shows after combat, and there is no `ADDON_ACTION_BLOCKED`.
- [ ] **In combat and inside an active key: target and world markers still work; the Ready, Pull and Role labels turn grey and their tooltips say why (the buttons are not disabled).**
- [ ] Pull: left click starts 10 s, right click 5 s; a click during the countdown cancels; another client with DBM shows the pull bar and cancels it too.
- [ ] After a countdown started by someone else during chat lockdown finishes on its own, the next Pull click starts a pull instead of cancelling.
- [ ] After a key ends out of combat, Ready and Pull become usable without a reload.
- [ ] The target highlight follows the target: a marked target lights its marker, a new target moves or clears it.
- [ ] A placed world marker shows a gold ring; the dots stay bright.
- [ ] World marker dots and the next-marker ring are round.
- [ ] The panel and every button have a thin border; the group buttons form a block right of both rows: Ready and Pull on top, Role across the bottom.
- [ ] Ready check with one decline: the button goes red. With one player silent until the end: red. All ready: green. It resets after 5 s.
- [ ] "Ready 20/20" in a 20-player raid fits the button.
- [ ] Dragging: the panel can only be grabbed by its padding and gaps, because the secure buttons take the mouse. Note whether that is comfortable. Lock position stops the drag; the position survives /reload; Reset position brings it back.
- [ ] **Start dragging the panel, pull a mob, release (Hide in combat off): no `ADDON_ACTION_BLOCKED`; the outline stops at the release point; the panel jumps there when combat ends; it survives /reload; click-targeting and right-drag camera work during the pull.**
- [ ] Hide in combat on: start dragging, pull a mob - the outline disappears at the pull, the panel keeps the spot where the outline was, no `ADDON_ACTION_BLOCKED`.
- [ ] `/dump LittleThingsRaidMarkers:IsProtected()` in a group - note the result.
- [ ] Scale and Vertical change the panel at once out of combat and are greyed in combat.
- [ ] Key bindings (under LittleThings): Next world marker at the cursor follows the Placement order (1..8 by default) and wraps, and works in combat; Clear all world markers removes everything and the next press of the first key places the 1st slot again.
- [ ] Horizontal layout: the Place button sits between the world dots and the world clear icon, both rows end at the same edge, and "Place" fits its button.
- [ ] Placement mode: left click on Place - the label turns gold with "1/N", the button gets a gold border and the next world dot a white ring.
- [ ] With the mode on, every left click on the ground places the next marker of the Placement order at the cursor: with the default order four clicks place 1, 2, 3, 4 (not 1, 3, 5, 7); after the last one it wraps to the first and the mode stays on.
- [ ] Right click on Place ends the mode; so does Esc, and Esc does not open the game menu while the mode is on. A second left click on Place also ends it.
- [ ] **The mode turns on, places markers and turns off in combat, with no `ADDON_ACTION_BLOCKED`.**
- [ ] After the mode ends, left click targets and left-drag turns the camera again.
- [ ] The mode ends when the panel hides by the visibility rule (for example leaving the group) and when the module is switched off, after combat if that happens in combat. After /reload the mode is off and left click targets.
- [ ] **Hide in combat on, placement mode on, pull: the mode ends at once, left click targets again during the fight, no `ADDON_ACTION_BLOCKED`.**
- [ ] Placement mode: the panel's world clear icon removes all ground markers and the next click places the first marker of the order.
- [ ] Placement mode without lead/assist: the button is grey and does not turn on.
- [ ] Healer mana on, party with a healer: the bar follows the healer's mana in and out of combat and inside a key, no Lua errors.
- [ ] No healer / raid / solo: no bar.
- [ ] Healer mana: a healer role icon sits left of the bar; with mana text on, the healer's name shows in class colour before the numbers.
- [ ] Mana text Percent/Value/Both shows the healer's mana in that form in and out of combat and in a key; None shows only the bar.
- [ ] Dead or offline count shows "1 down" when a member dies or disconnects and disappears when they are back.
- [ ] Placement order: set a few slots to None - the mode and the key skip them; set all to None - Place turns grey, its tooltip says "Placement order is empty" and a click does nothing. A duplicate slot places the same marker again.
- [ ] Vertical layout: one column, each target marker next to the world marker of the same symbol (star next to the yellow star, and so on); Clear all and the world clear icon under the pairs, then Place, Ready, Pull and Role across the column; "Clear all" fits its button.
- [ ] **The key binding works on an unparented hidden button, and `/wm [@cursor]N` set from the combat snippet places the marker under the cursor.**
- [ ] **`/console taintLog 1`, a full key: no LittleThings entries in `Logs/taint.log`.**
- [ ] MRT's own Marks Bar is switched off by the owner (`/rt mb` toggle) so the two panels do not overlap.

## 16. Battle res guard

Switch on Battle res guard (Group content). It is off by default. Its page has an Ask before release as group with Tank, Healer and Damage, all on by default.

- [ ] In a key with a battle res charge left and a druid, death knight, warlock or paladin alive, die: the Release button gets a gold frame. A click on it opens the window above the death popup with "Battle res available: N" and "Can res: Name"; Blizzard's popup does not release.
- [ ] Release anyway releases and the window and frame go. Wait for res closes the window, you stay dead, and the frame stays on Release.
- [ ] Get battle ressed while the window is open: the window and frame go with the death popup.
- [ ] Switch off the role of your current spec, die: plain Release, no frame.
- [ ] No battle res class alive in the group (or the only one offline), die: plain Release, no frame. The caster dies while you are dead: the frame goes within a moment.
- [ ] Open world or a dungeon outside a key, die: plain Release, no frame.
- [ ] On a raid boss while the encounter suppresses release: no frame while Release is greyed.
- [ ] Dead in a key, run `/run local c=C_Spell.GetSpellCharges(20484) print(c and c.currentCharges, c and issecretvalue(c.currentCharges))` and note whether the count is secret; the window's number matches the game's charge count.
- [ ] Switch the module off while dead: the frame and window go at once and Release works.
- [ ] **`/console taintLog 1`, die and release through the window and through Blizzard's own button: no LittleThings entries in `Logs/taint.log`, BugSack empty.**

## 17. New in LittleThings

- [ ] With an existing account DB, `/run LittleThingsDB.battleResGuard = nil` then `/reload`: a couple of seconds after login the New in LittleThings panel shows in the middle of the screen with one Battle res guard row: title, description and an Enable box.
- [ ] Tick Enable: the settings window's Battle res guard page shows the switch on and the menu entry is no longer grey, no reload prompt.
- [ ] `/run LittleThingsDB.damageMeter = nil` then `/reload`: tick Enable on the Damage meter row - the reload prompt names Damage meter.
- [ ] `/run LittleThingsDB.groupFinder = false LittleThingsDB.signUpRoles = nil` then `/reload`: the row reads Group finder: Sign-up roles on the search panel. Tick Enable: Group finder is on too. Untick it: only Sign-up roles goes off, Group finder stays on.
- [ ] Open settings closes the panel and opens the module's page (the parent's page for a child row). Close, Esc, then `/reload` again: no panel.
- [ ] Clear a switch as above, `/reload` while in combat: no panel until combat ends, then it shows. Enter combat with the panel open: Enable greys and comes back after combat.
- [ ] Delete `WTF/Account/<account>/SavedVariables/LittleThings.lua` with the game closed (fresh install), log in: no panel.
- [ ] BugSack stays empty throughout.

## 18. Low level gear

Switch on Low level gear (Character and loot). It is off by default.

- [ ] `/lt gear`: the first line lists every worn slot as level/trackStringID; each bag gear line ends in `-> true` exactly where the rules below say so.
- [ ] A soulbound Champion piece while wearing Hero in that slot: the tooltip shows "LittleThings: low level gear (Champion N, worn Hero M)" in grey. A Hero piece below the worn Hero level (Poison-Proof Stompers, Hero 5/6 318 against worn Hero 6/6 321): not marked.
- [ ] A Hero piece while wearing Champion in that slot: not marked.
- [ ] An item with an appearance you have not collected: no line, no marker.
- [ ] A tier set piece, a trinket, a weapon, an off-hand or shield, a Bind on Equip piece, a Warbound until equipped piece: none of them marked.
- [ ] A ring is compared with the worse of the two worn rings (lower track, then lower level). Take one ring off: no ring is marked.
- [ ] A neck and a ring (no appearance) still get marked when below the worn one.
- [ ] A soulbound Myth-track piece (the Silken Voodoo Drape, Myth 1/6 at 318) is never marked, even below a worn Myth piece.
- [ ] Equip a different item in a slot: markers and tooltip lines for that slot update without reopening the bags.
- [ ] Disable Baganator, `/reload`: Blizzard's bags (separate and combined) show a small red cross in the top right of marked items; Blizzard's own junk coin at a merchant is unchanged. Switch the module off: the crosses go at once.
- [ ] With Baganator: marked items show "Low" in the bottom left corner, under the equipment set mark; the item level still shows in the top left. Grey items keep Baganator's own junk coin. Icon Corners on the Icons tab of Baganator's settings lists "LittleThings: low level gear" in the bottom left corner. Equip a different item: "Low" updates without reopening the bags. Switch the module off: every "Low" goes.
- [ ] Hover items in the bank, in chat links and in the Adventure Guide: no line.
- [ ] **`/console taintLog 1`, use and equip items from Blizzard's bags in combat: no LittleThings entries in `Logs/taint.log`, BugSack empty.**

## 19. Save indicator

Switch on Save indicator (Group content). It is off by default. Its page has Where (Also in raids off, Icons on party frames on) and Centre row (Time left, Damage reduction, Lock position, Scale, Reset position).

- [ ] Solo, Sentinel: an icon below the centre of the screen with seconds inside and `-30%` under it; the number falls by 2 per stack in combat and turns orange at `-18%`.
- [ ] Ardent Defender or Guardian of Ancient Kings: its own icon with `-30%` / `-50%`, stronger saves left of weaker ones, Sentinel left of a fixed 30% save.
- [ ] Two externals of the same strength on you at once (two 40% saves): both icons show, nothing overlaps.
- [ ] Blessing of Protection shows `phys`, Spellwarding `magic`, Life Cocoon `shield`, in blue, right of the percentage saves; Power Word: Barrier shows `-20%`.
- [ ] The page lists Tracked saves in three groups with icons; untick one, /reload: it no longer shows in the row or on party frames.
- [ ] One, two and three saves at once: the row stays centred on its X/Y point.
- [ ] Settings page open: a gold outlined sample (Sentinel -24%, Pain Suppression -40%) shows; drag it, close the page: the row sits there, also after /reload. Lock position stops the drag, Scale resizes, Reset position puts it back.
- [ ] Untick Time left or Damage reduction, /reload: the seconds or the reduction are gone.
- [ ] Party with Blizzard raid-style party frames, a paladin tank pops Sentinel: a small icon in the top right of that member's frame; Ardent Defender on the same member shows no corner icon (Blizzard's centre icon has it).
- [ ] **Someone joins or leaves the party in combat: corner icons stay on the right members' frames, no `ADDON_ACTION_BLOCKED`.**
- [ ] Raid: nothing shows. Also in raids on: the centre row shows, corner icons do not. Battleground or arena: nothing.
- [ ] Zone from a party into a raid with a save up: the row hides; back in a party it returns.
- [ ] **`/console taintLog 1`, a full key: no LittleThings entries in `Logs/taint.log`, BugSack empty.**

## 20. Party frames when solo

Switch on Party frames when solo (Group content). It is off by default. Needs Use Raid-Style Party Frames in Edit Mode.

- [ ] Solo: your own party frame shows. Join a group: Blizzard's frames as usual. Leave: your frame stays.
- [ ] Leave a group in combat: the frame comes back after combat, no `ADDON_ACTION_BLOCKED`.
- [ ] Switch off: the solo frame hides at once. Old-style party frames: nothing changes.
- [ ] **After a fight with the frame up solo, BugSack empty, `Logs/taint.log` has no LittleThings entries.**
