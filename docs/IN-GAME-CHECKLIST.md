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
- [ ] Lock window 2, resize window 1: window 2 does not resize.
- [ ] Detach window 2, `/reload`: it comes back where it was.
- [ ] Hide a snapped window, show it again from the gear menu: it comes back attached.
- [ ] Dropping a window near a screen edge with no window near lands it flush; the bars show on the window's and the screen's edge.
- [ ] Gap of 6 on a linked window separates the pair by six pixels and survives a reload.
- [ ] `/reload` keeps every link and size.
- [ ] **With a matched link in place, `/reload`, touch nothing, fight**: no reload popup at login and BugSack stays empty. This is the case that used to taint every session.
- [ ] Resizing window 2 by its handle while window 3 matches it shows the reload popup once; after the reload, BugSack stays empty in the next fight.

## 3a. Following an Edit Mode layout switch

Needs two Edit Mode layouts whose damage meter sits in a different place, and whose Frame Width differs. Assign the second layout to a second specialization.

- [ ] Switch layout by hand in the Edit Mode UI: window 1 moves with the layout and windows 2 and 3 stay attached to it.
- [ ] Same switch with differing Frame Width: the matched windows take window 1's new width, and the reload popup appears once.
- [ ] Switch specialization so the layout changes with the Edit Mode UI closed: the chain follows, both position and matched width.
- [ ] Switch back to a layout whose width is the same as the current one: no reload popup (the size is only set when it differs).
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

- [ ] The behaviour page has readable numbers, snapping, snap distance, idle transparency, layer, and at the bottom a Blizzard section with Enable Damage Meter and Auto Reset that mirror Gameplay Enhancements both ways.
- [ ] The addon list has one Damage meter entry, with Windows nested under it. The Windows page lists three rows. Ticking Shown on a hidden slot shows the window and offers a reload; after the reload the window is there and combat logs nothing. Window 1's size boxes route through Edit Mode; a size Edit Mode refuses prints a message.
- [ ] Typing an out-of-range width comes back clamped. A locked window's boxes are greyed.
- [ ] Lock per row, Lock all and Unlock all agree with the gear menu's lock state; no reload prompt.
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

## 8. Mythic+ applicants

- [ ] Switch on Mythic+ applicants, list a Mythic+ key: applicants are ordered by the rating column, highest first. No reload needed.
- [ ] Two applicants with the same rating: the higher item level is above. Sort by "Item level, then Mythic+ rating": the list follows the item level column at the next update.
- [ ] A new applicant with a higher rating than the ones listed lands above them, not at the bottom.
- [ ] A group applying together is placed by the rating of the player who applied.
- [ ] List a raid or a custom group: the order is Blizzard's (oldest first, new applicants at the bottom).
- [ ] Invite and decline still work from the sorted list, in and out of an instance, and BugSack stays empty.
- [ ] Switch off: the next list update goes back to Blizzard's order.

## 9. Applicant filter

- [ ] Switch on Applicant filter, list a Mythic+ key, open the applicants: the panel sits right of the finder with a solid background and shows Classes, Roles, Minimum item level, Group utility, the mode and Reset; it is gone on the search list and when the finder closes. Drag it by its background: it stays where dropped, the page's X/Y offsets show the new values, and the spot is kept after /reload. Panel side Left and the offsets move it at once.
- [ ] List a raid: the panel drops Group utility and gets shorter; nothing else changes.
- [ ] Listed, zone into the dungeon (or a raid leader into the raid), applicants arrive and cancel, someone joins: BugSack stays empty; the list is Blizzard's until you leave the instance.
- [ ] Class icons show counts, including applicants moved down or hidden; need, exclude and clear work as the tooltip says.
- [ ] Minimum item level 300: applicants below move to the bottom, dimmed; "Moved down: N" matches. Empty the box: back to normal. Type 0: nothing moves.
- [ ] Roles: tank toggled off moves tank-only applicants down; a tank/damage flex stays.
- [ ] Brings Bloodlust with no Bloodlust class in the group: shamans, mages, hunters and evokers stay on top, everyone else moves down (Hide: disappears). Once a Bloodlust class joins, the list is back. Both boxes: applications bringing either Bloodlust or battle res stay on top, the rest move down; once one of them is in the group, only the other one is asked for.
- [ ] Mode Hide: failing applicants disappear, "Hidden: N". An invited applicant stays whatever the filters say.
- [ ] Rows show two small numbers right of the rating, under a "Best / Here" label: best key anywhere on top in blue, this dungeon below in green, each dimmed when not timed, label colours matching, clear of the invite buttons; nothing on cancelled rows. Sort by "This dungeon" orders by the lower one.
- [ ] List a raid with Raider.IO installed: each row shows two small progress lines where the Rating column would be, best progress on top, this raid at this difficulty below, coloured N green / H blue / M purple; empty for players Raider.IO does not know. Without Raider.IO: no error, no text.
- [ ] An applicant cancels, times out or is declined: the row leaves the list at once. Remove closed applications off: the row stays with its X, as Blizzard shows it.
- [ ] Reset clears everything except the mode. Invite and decline from a filtered list work, BugSack stays empty.
- [ ] Reload keeps every setting; another character starts clean; a character that had class picks from the old bar keeps them. Values saved for the removed options (minimum rating, keys) have no effect.
- [ ] Switch off: the panel disappears and the list is Blizzard's again at once.

## 10. Default playstyle

- [ ] Switch on, Premade Groups > Dungeons > Create: the playstyle dropdown already says Competitive. List Group works, no "Interface action failed because of an addon".
- [ ] If listing is blocked: chat says the default playstyle was turned off, the switch is off, and after /reload listing with a hand-picked playstyle works.
- [ ] Pick Relaxed on the page: the next new listing opens with Relaxed. Editing an active listing keeps its own playstyle.
