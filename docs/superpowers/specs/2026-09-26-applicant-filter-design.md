# Applicant filter panel - design

Date: 2026-09-26. Branch: `feat/applicant-sort`. Replaces the bottom class bar built earlier on the same branch.

## Goal

When our group is listed in the group finder, picking people from the applicant list should need no hovering and no manual scanning. A visual filter panel does for applicants what Premade Groups Filter does for group search (PGF never touches the applicant list, checked in its code). Visual controls only: no expression box.

Success: with the panel set once, the applicants worth inviting are at the top of the list, and the reason another one is not is visible without opening a tooltip.

## Where it lives

- A panel docked beside `PVEFrame`, shown only while `LFGListFrame.ApplicationViewer` is visible: left when there is room on screen, otherwise right (the default UI puts PVEFrame at the left edge). It can be dragged anywhere (kept in `LittleThingsDB.applicantPanelPos`, clamped to the screen) and right-click docks it again, which is how it gets clear of Raider.IO's frame on the right.
- During chat messaging lockdown (inside dungeons and raids) the LFG reads are Secret, so the addon leaves the applicant list to Blizzard until the lockdown ends.
- The "This dungeon" limits apply only to Mythic+ listings.
- The bottom class bar is removed; its class icons move into the panel.
- Settings: the existing `classFilter` switch on the Mythic+ page becomes "Applicant filter" (key unchanged, so saved class picks survive). Every filter value is saved per character in `LittleThingsCharDB.applicantFilter`; the existing `classFilter` picks table is adopted into it once.

## Panel, top to bottom

1. **Classes.** 13 class icons, each with the count of applicants of that class under it (every member of a group application, hidden or moved ones included, empty for zero). Left-click cycles neutral, needed (green frame), excluded (red frame, desaturated); right-click clears.
2. **Roles.** Three toggles (tank, healer, damage), all on by default; an applicant whose offered roles are all toggled off fails. Checkbox "Hide roles already filled", off by default: counts our group's assigned roles against 1 tank, 1 healer, 3 damage.
3. **Minimums.** Number boxes: overall Mythic+ rating, item level. Empty means no limit.
4. **This dungeon** (Mythic+ listings only, greyed otherwise). Number box: minimum best key level in the listed dungeon. Checkbox "Timed only".
5. **Group utility.** Checkboxes "Bloodlust fit" and "Battle res fit".
6. **Mode.** Dropdown: "Move down" (default) or "Hide".
7. **Reset** (disabled when nothing is set) and a status line: "Moved down: N" or "Hidden: N".

## Rules

An application passes when all of these hold:

- No member has an excluded class. If any class is needed, at least one member has a needed class.
- Every member meets the minimum rating, item level, dungeon key level and "timed" (a member without a score for this dungeon fails a set dungeon minimum).
- Roles: every member offers at least one role that is toggled on; with "Hide roles already filled", the application's members can be placed into the group's open slots, each member in one of its offered roles.
- Bloodlust fit (same meaning as PGF's Bloodlust Fit): the group already has a Bloodlust class, or a member brings one, or after placing the application at least one damage or healer slot stays open. Bloodlust classes: Shaman, Mage, Hunter, Evoker.
- Battle res fit: same shape with Druid, Death Knight, Warlock, Paladin, counting any open slot.

Order: the Mythic+ applicants sort runs first (its own module, unchanged except for a third key below); the filter then splits the list into passing and failing applications, each part keeping its order. "Move down" puts failing ones after passing ones and dims their rows; "Hide" removes them.

If any value the rules need comes back Secret (`GetApplicantInfo` is Secret during chat messaging lockdown), the filter leaves the list exactly as it got it and the status line says "Filter paused".

## Row additions

- Right of the Rating column: the member's best key in the listed dungeon from `C_LFGList.GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID)` (`bestRunLevel`, `finishedSuccess`): green when timed, grey when not, nothing when absent. Mythic+ listings only.
- The Mythic+ applicants "Sort by" dropdown gains "This dungeon, then Mythic+ rating" (key: `mapScore` of the same call).
- Rows of moved-down applications are drawn at reduced alpha.

## Code layout

`Modules/Applicants/`:

- `FilterRules.lua` - pure Lua, no game API: takes applications as plain tables (`{ pinned, members = { { class, roles, rating, itemLevel, dungeonLevel, dungeonTimed, dungeonScore } } }`), the group state (`{ open = { TANK, HEALER, DAMAGER } | nil, hasBloodlust, hasBattleRes }`) and the filter settings; returns pass/fail per application, the class counts, the partitioned order, and migrates the old class picks.
- `ApplicantData.lua` - reads the game API into those plain tables; returns nil on any Secret value.
- `Pipeline.lua` - the one hook on `LFGListUtil_SortApplicants`, running sort then filter in a fixed order, and the list refresh.
- `ApplicantOrder.lua`, `ApplicantSort.lua` - the Mythic+ applicants sort, its three keys and the dungeon key on each row.
- `ApplicantFilter.lua` - the filter module: settings adoption, the pipeline step, row dimming, roster events.
- `FilterPanel.lua` - the panel frame.

`Modules/ClassFilter/` is deleted; its rules moved into `FilterRules.lua`.

## Testing

busted specs for `FilterRules.lua`: each filter alone, needed versus excluded classes, multi-member applications, role placement with and without filled roles, Bloodlust and battle res fit, both modes keeping order, class counts. `ApplicantSort` spec gains the third key. Frame work (panel, row text, dimming, refresh on roster change, invite and decline from a filtered list) goes into `docs/IN-GAME-CHECKLIST.md`.

## Out of scope

Group search filtering (PGF covers it), expression filters, sounds, spec icons, applicant notes, leaver marks.
