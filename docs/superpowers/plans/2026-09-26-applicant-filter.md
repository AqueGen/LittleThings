# Applicant Filter Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A visual filter panel for the group finder's applicant list (classes, roles, minimums, this-dungeon key, Bloodlust / battle res fit, move-down or hide), plus the best key in the listed dungeon on every applicant row and a third sort key.

**Architecture:** Everything applicant-related lives in `Modules/Applicants/`. Pure rules (`FilterRules.lua`) take plain tables and are fully unit-tested; `ApplicantData.lua` is the only file that reads the LFG API and turns it into those tables (nil on any Secret value); `Pipeline.lua` owns the single hook on `LFGListUtil_SortApplicants` and runs sort, then filter, in a fixed order. `ApplicantSort.lua` and `ApplicantFilter.lua` are the two switchable modules; `FilterPanel.lua` is the frame.

**Tech Stack:** Lua 5.1 (WoW 12.1 client), Blizzard Settings API, busted in WSL for tests.

**Spec:** `docs/superpowers/specs/2026-09-26-applicant-filter-design.md`

## Global Constraints

- Retail only, `## Interface: 120100`; no libraries, no dependencies.
- New modules default off; the switch key for the filter stays `classFilter` so saved class picks survive.
- Filter settings are per character: `LittleThingsCharDB.applicantFilter`.
- Any Secret value leaves Blizzard's list exactly as it came in ("Filter paused").
- No code comments except the kind the global rule allows (the one fact nothing else can verify); design reasoning lives in the spec and docs.
- Only format lines you change. Files in English.
- Tests: `MSYS_NO_PATHCONV=1 wsl bash -lc 'cd "/mnt/g/Games/World of Warcraft/_retail_/Interface/AddOns/LittleThings" && ~/luaenv/bin/busted'`
- Syntax check a Lua file: `MSYS_NO_PATHCONV=1 wsl bash -lc 'cd "/mnt/g/Games/World of Warcraft/_retail_/Interface/AddOns/LittleThings" && ~/luaenv/bin/luac -p <file>'`
- Commits only after the user has said yes to committing on this branch; never add attribution lines.

## Review Focus

- A minimum dungeon key is set and an applicant never ran this dungeon: the application moves down (or hides), no error. Test in Task 2.
- A minimum box is emptied: no limit; "0" typed: a limit of 0 that everyone passes. Test in Task 2 (`Rules.ParseNumber`).
- "Hide roles already filled" in a raid or custom listing (not 5 players): roles never hide anyone. Test in Task 3.
- An applicant already invited must never move down or hide, whatever the filters. Test in Task 2.
- One Secret value anywhere in the list: nothing is reordered or removed. Test in Task 5.

---

## File Structure

- `Modules/Applicants/FilterRules.lua` - create. Pure rules: settings defaults, class cycling, number parsing, per-application pass/fail, role placement, Bloodlust / battle res fit, class counts, partition, migration of old class picks.
- `Modules/Applicants/ApplicantData.lua` - create. LFG and unit API into plain tables: `Listing()`, `Application(id, listing)`, `DungeonBest(id, index, activityID)`, `Group(listing)`.
- `Modules/Applicants/Pipeline.lua` - create. One hook on `LFGListUtil_SortApplicants`, ordered steps, `Refresh()`.
- `Modules/Applicants/ApplicantOrder.lua` - move from `Modules/ApplicantSort/`.
- `Modules/Applicants/ApplicantSort.lua` - move from `Modules/ApplicantSort/`, rework onto Pipeline and ApplicantData, third key, row key text.
- `Modules/Applicants/ApplicantFilter.lua` - create. The filter module: settings adoption, pipeline step, row dimming, roster events, state for the panel.
- `Modules/Applicants/FilterPanel.lua` - create. The panel frame.
- `Modules/ClassFilter/` - delete (rules move into FilterRules).
- `Core.lua` - modify: MODULES row for `classFilter`, drop `classFilter` from `charDefaults`.
- `LittleThings.toc` - modify: file list.
- `tests/filterrules_spec.lua`, `tests/applicantdata_spec.lua` - create. `tests/classfilter_spec.lua` - delete. `tests/applicantorder_spec.lua` - modify path.
- `README.md`, `docs/IN-GAME-CHECKLIST.md`, the spec's code layout line - modify.

---

### Task 1: Baseline commit of the work already on the branch

**Files:** everything currently uncommitted (`git status -s`): `Core.lua`, `LittleThings.toc`, `README.md`, `docs/IN-GAME-CHECKLIST.md`, `Modules/ApplicantSort/`, `Modules/ClassFilter/`, `tests/applicantorder_spec.lua`, `tests/classfilter_spec.lua`, `docs/superpowers/specs/2026-09-26-applicant-filter-design.md`, this plan.

**Interfaces:** none.

- [ ] **Step 1: Run the suite**

Run the test command from Global Constraints. Expected: `103 successes / 0 failures`.

- [ ] **Step 2: Commit**

```bash
git add Core.lua LittleThings.toc README.md docs/IN-GAME-CHECKLIST.md Modules/ApplicantSort Modules/ClassFilter tests/applicantorder_spec.lua tests/classfilter_spec.lua docs/superpowers/specs/2026-09-26-applicant-filter-design.md docs/superpowers/plans/2026-09-26-applicant-filter.md
git commit -m "feat: sort Mythic+ applicants by rating and filter them by class on one Mythic+ page"
```

---

### Task 2: FilterRules - settings, classes, minimums, invited applicants, class counts

**Files:**
- Create: `Modules/Applicants/FilterRules.lua`
- Test: `tests/filterrules_spec.lua`

**Interfaces:**
- Produces:
  - Application table: `{ pinned = bool, members = { { class = "MAGE", roles = { TANK = bool, HEALER = bool, DAMAGER = bool }, rating = number|nil, itemLevel = number|nil, dungeonLevel = number|nil, dungeonTimed = bool|nil, dungeonScore = number|nil } } }`
  - Group table: `{ open = { TANK = n, HEALER = n, DAMAGER = n } | nil, hasBloodlust = bool, hasBattleRes = bool }` (`open` nil means role slots are not limited)
  - Settings table (`Rules.Defaults()`): `{ classes = {}, roles = { TANK = true, HEALER = true, DAMAGER = true }, hideFilledRoles = false, minRating = nil, minItemLevel = nil, minDungeonLevel = nil, timedOnly = false, bloodlustFit = false, battleResFit = false, mode = "down" }`
  - `Rules.NEED`, `Rules.EXCLUDE`, `Rules.ROLES`, `Rules.BLOODLUST`, `Rules.BATTLE_RES`
  - `Rules.Defaults() -> settings`, `Rules.Next(state) -> state|nil`, `Rules.ParseNumber(text) -> number|nil`, `Rules.IsActive(settings) -> bool`, `Rules.Passes(application, group, settings) -> bool`, `Rules.CountClasses(applications) -> { [class] = n }`

- [ ] **Step 1: Write the failing tests**

`tests/filterrules_spec.lua`:

```lua
package.path = "./Modules/Applicants/?.lua;" .. package.path

local Rules = require("FilterRules")

local NEED, EXCLUDE = Rules.NEED, Rules.EXCLUDE
local OPEN_GROUP = { open = { TANK = 1, HEALER = 1, DAMAGER = 3 }, hasBloodlust = false, hasBattleRes = false }

local function member(class, fields)
  local m = { class = class, roles = { TANK = false, HEALER = false, DAMAGER = true }, rating = 2500, itemLevel = 290 }
  for k, v in pairs(fields or {}) do m[k] = v end
  return m
end

local function app(...)
  return { members = { ... } }
end

local function settings(fields)
  local s = Rules.Defaults()
  for k, v in pairs(fields or {}) do s[k] = v end
  return s
end

describe("Rules.Next", function()
  it("cycles neutral, need, exclude, neutral", function()
    assert.equals(NEED, Rules.Next(nil))
    assert.equals(EXCLUDE, Rules.Next(NEED))
    assert.is_nil(Rules.Next(EXCLUDE))
  end)
end)

describe("Rules.ParseNumber", function()
  it("reads a whole number", function()
    assert.equals(2500, Rules.ParseNumber("2500"))
    assert.equals(0, Rules.ParseNumber("0"))
  end)

  it("treats empty or non-numeric text as no limit", function()
    assert.is_nil(Rules.ParseNumber(""))
    assert.is_nil(Rules.ParseNumber("abc"))
    assert.is_nil(Rules.ParseNumber(nil))
  end)
end)

describe("Rules.IsActive", function()
  it("is off for the defaults", function()
    assert.is_false(Rules.IsActive(settings()))
  end)

  it("is on for any class pick, role off, minimum or checkbox", function()
    assert.is_true(Rules.IsActive(settings({ classes = { MAGE = NEED } })))
    assert.is_true(Rules.IsActive(settings({ roles = { TANK = false, HEALER = true, DAMAGER = true } })))
    assert.is_true(Rules.IsActive(settings({ minRating = 0 })))
    assert.is_true(Rules.IsActive(settings({ timedOnly = true })))
    assert.is_true(Rules.IsActive(settings({ bloodlustFit = true })))
  end)

  it("ignores the mode", function()
    assert.is_false(Rules.IsActive(settings({ mode = "hide" })))
  end)
end)

describe("Rules.Passes, classes", function()
  it("drops an application with an excluded class in any member", function()
    assert.is_false(Rules.Passes(app(member("MAGE"), member("PALADIN")), OPEN_GROUP, settings({ classes = { PALADIN = EXCLUDE } })))
  end)

  it("keeps an application with any one needed class", function()
    local s = settings({ classes = { SHAMAN = NEED, MAGE = NEED } })
    assert.is_true(Rules.Passes(app(member("WARRIOR"), member("MAGE")), OPEN_GROUP, s))
    assert.is_false(Rules.Passes(app(member("WARRIOR")), OPEN_GROUP, s))
  end)
end)

describe("Rules.Passes, minimums", function()
  it("drops a member below the minimum rating or item level", function()
    assert.is_false(Rules.Passes(app(member("MAGE", { rating = 2400 })), OPEN_GROUP, settings({ minRating = 2500 })))
    assert.is_true(Rules.Passes(app(member("MAGE", { rating = 2500 })), OPEN_GROUP, settings({ minRating = 2500 })))
    assert.is_false(Rules.Passes(app(member("MAGE", { itemLevel = 280 })), OPEN_GROUP, settings({ minItemLevel = 285 })))
  end)

  it("needs every member of a group application to meet the minimums", function()
    local s = settings({ minRating = 2500 })
    assert.is_false(Rules.Passes(app(member("MAGE", { rating = 3000 }), member("PRIEST", { rating = 1200 })), OPEN_GROUP, s))
  end)

  it("lets everyone through a minimum of zero", function()
    assert.is_true(Rules.Passes(app(member("MAGE", { rating = 0 })), OPEN_GROUP, settings({ minRating = 0 })))
  end)

  it("drops a member with no run in this dungeon when a key minimum is set", function()
    local s = settings({ minDungeonLevel = 10 })
    assert.is_false(Rules.Passes(app(member("MAGE")), OPEN_GROUP, s))
    assert.is_true(Rules.Passes(app(member("MAGE", { dungeonLevel = 10 })), OPEN_GROUP, s))
    assert.is_false(Rules.Passes(app(member("MAGE", { dungeonLevel = 9 })), OPEN_GROUP, s))
  end)

  it("drops an untimed best run when timed only is on", function()
    local s = settings({ timedOnly = true })
    assert.is_false(Rules.Passes(app(member("MAGE", { dungeonLevel = 12, dungeonTimed = false })), OPEN_GROUP, s))
    assert.is_true(Rules.Passes(app(member("MAGE", { dungeonLevel = 12, dungeonTimed = true })), OPEN_GROUP, s))
  end)
end)

describe("Rules.Passes, invited applicants", function()
  it("keeps an invited application whatever the filters say", function()
    local invited = app(member("PALADIN", { rating = 100 }))
    invited.pinned = true
    assert.is_true(Rules.Passes(invited, OPEN_GROUP, settings({ minRating = 3000, classes = { PALADIN = EXCLUDE } })))
  end)
end)

describe("Rules.CountClasses", function()
  it("counts every member of every application", function()
    local counts = Rules.CountClasses({ app(member("MAGE")), app(member("MAGE"), member("PRIEST")) })
    assert.equals(2, counts.MAGE)
    assert.equals(1, counts.PRIEST)
    assert.is_nil(counts.ROGUE)
  end)
end)
```

- [ ] **Step 2: Run it to see it fail**

Run the test command. Expected: `filterrules_spec.lua` errors with `module 'FilterRules' not found`.

- [ ] **Step 3: Write the implementation**

`Modules/Applicants/FilterRules.lua`:

```lua
local _, ns = ...

local Rules = {}

Rules.NEED = "need"
Rules.EXCLUDE = "exclude"
Rules.ROLES = { "TANK", "HEALER", "DAMAGER" }
Rules.BLOODLUST = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
Rules.BATTLE_RES = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true }

function Rules.Defaults()
    return {
        classes = {},
        roles = { TANK = true, HEALER = true, DAMAGER = true },
        hideFilledRoles = false,
        minRating = nil,
        minItemLevel = nil,
        minDungeonLevel = nil,
        timedOnly = false,
        bloodlustFit = false,
        battleResFit = false,
        mode = "down",
    }
end

function Rules.Next(state)
    if state == nil then return Rules.NEED end
    if state == Rules.NEED then return Rules.EXCLUDE end
    return nil
end

function Rules.ParseNumber(text)
    local value = tonumber(text)
    if value then return math.floor(value) end
    return nil
end

function Rules.IsActive(s)
    if next(s.classes) ~= nil then return true end
    for _, role in ipairs(Rules.ROLES) do
        if not s.roles[role] then return true end
    end
    return s.hideFilledRoles or s.timedOnly or s.bloodlustFit or s.battleResFit
        or s.minRating ~= nil or s.minItemLevel ~= nil or s.minDungeonLevel ~= nil
end

local function MemberPasses(member, s)
    if s.classes[member.class] == Rules.EXCLUDE then return false end
    if s.minRating and (member.rating or 0) < s.minRating then return false end
    if s.minItemLevel and (member.itemLevel or 0) < s.minItemLevel then return false end
    if s.minDungeonLevel and (member.dungeonLevel or 0) < s.minDungeonLevel then return false end
    if s.timedOnly and not member.dungeonTimed then return false end
    for _, role in ipairs(Rules.ROLES) do
        if member.roles[role] and s.roles[role] then return true end
    end
    return false
end

local function HasNeededClass(application, s)
    local wantsAny = false
    for _, state in pairs(s.classes) do
        if state == Rules.NEED then wantsAny = true break end
    end
    if not wantsAny then return true end
    for _, member in ipairs(application.members) do
        if s.classes[member.class] == Rules.NEED then return true end
    end
    return false
end

function Rules.Passes(application, group, s)
    if application.pinned then return true end
    for _, member in ipairs(application.members) do
        if not MemberPasses(member, s) then return false end
    end
    return HasNeededClass(application, s)
end

function Rules.CountClasses(applications)
    local counts = {}
    for _, application in ipairs(applications) do
        for _, member in ipairs(application.members) do
            counts[member.class] = (counts[member.class] or 0) + 1
        end
    end
    return counts
end

if ns then ns.FilterRules = Rules end
return Rules
```

- [ ] **Step 4: Run the tests to see them pass**

Run the test command. Expected: all pass (103 old + the new ones).

- [ ] **Step 5: Commit**

```bash
git add Modules/Applicants/FilterRules.lua tests/filterrules_spec.lua
git commit -m "feat: add applicant filter rules for classes, minimums and invited applicants"
```

---

### Task 3: FilterRules - role slots, Bloodlust fit, battle res fit

**Files:**
- Modify: `Modules/Applicants/FilterRules.lua` (`Rules.Passes` and a new local `Leftovers`)
- Test: `tests/filterrules_spec.lua` (append)

**Interfaces:**
- Consumes: Task 2's tables and `Rules.Passes`.
- Produces: `Rules.Passes` honours `hideFilledRoles`, `bloodlustFit`, `battleResFit` using `group.open`; `group.open == nil` means no role limits.

- [ ] **Step 1: Append the failing tests** to `tests/filterrules_spec.lua`:

```lua
describe("Rules.Passes, roles", function()
  local tankOnly = member("WARRIOR", { roles = { TANK = true, HEALER = false, DAMAGER = false } })
  local tankOrDps = member("WARRIOR", { roles = { TANK = true, HEALER = false, DAMAGER = true } })
  local healer = member("PRIEST", { roles = { TANK = false, HEALER = true, DAMAGER = false } })
  local noTank = { open = { TANK = 0, HEALER = 1, DAMAGER = 3 }, hasBloodlust = false, hasBattleRes = false }

  it("drops a member whose every offered role is toggled off", function()
    assert.is_false(Rules.Passes(app(healer), OPEN_GROUP, settings({ roles = { TANK = true, HEALER = false, DAMAGER = true } })))
  end)

  it("hides a role the group already has only when asked to", function()
    assert.is_true(Rules.Passes(app(tankOnly), noTank, settings()))
    assert.is_false(Rules.Passes(app(tankOnly), noTank, settings({ hideFilledRoles = true })))
    assert.is_true(Rules.Passes(app(tankOrDps), noTank, settings({ hideFilledRoles = true })))
  end)

  it("drops a group application that does not fit the open slots", function()
    local oneDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }
    assert.is_false(Rules.Passes(app(member("MAGE"), member("ROGUE")), oneDps, settings({ hideFilledRoles = true })))
  end)

  it("never hides by role when the listing has no role slots", function()
    local raid = { open = nil, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(tankOnly), raid, settings({ hideFilledRoles = true, bloodlustFit = true, battleResFit = true })))
  end)
end)

describe("Rules.Passes, Bloodlust fit", function()
  local lastDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }
  local s = settings({ bloodlustFit = true })

  it("keeps anyone when the group already has Bloodlust", function()
    local has = { open = lastDps.open, hasBloodlust = true, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), has, s))
  end)

  it("keeps an applicant who brings Bloodlust into the last slot", function()
    assert.is_true(Rules.Passes(app(member("MAGE")), lastDps, s))
  end)

  it("drops a non-Bloodlust applicant taking the last damage or healer slot", function()
    assert.is_false(Rules.Passes(app(member("ROGUE")), lastDps, s))
  end)

  it("keeps a non-Bloodlust applicant when a slot stays open after them", function()
    local twoDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 2 }, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), twoDps, s))
  end)
end)

describe("Rules.Passes, battle res fit", function()
  local s = settings({ battleResFit = true })
  local lastDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }

  it("drops a non-res applicant taking the last slot and keeps a res class", function()
    assert.is_false(Rules.Passes(app(member("ROGUE")), lastDps, s))
    assert.is_true(Rules.Passes(app(member("DRUID")), lastDps, s))
  end)

  it("counts an open tank slot as room for a res class", function()
    local tankOpen = { open = { TANK = 1, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), tankOpen, s))
  end)
end)
```

- [ ] **Step 2: Run them to see them fail**

Run the test command. Expected: the `hideFilledRoles`, group-fit, Bloodlust and battle res cases FAIL (the toggle-off case already passes).

- [ ] **Step 3: Implement**

In `Modules/Applicants/FilterRules.lua`, add above `function Rules.Passes`:

```lua
local ALL_ROLES = { TANK = true, HEALER = true, DAMAGER = true }

local function Leftovers(members, open, allowed, index, out)
    index = index or 1
    out = out or {}
    if index > #members then
        out[#out + 1] = { TANK = open.TANK, HEALER = open.HEALER, DAMAGER = open.DAMAGER }
        return out
    end
    for _, role in ipairs(Rules.ROLES) do
        if members[index].roles[role] and allowed[role] and open[role] > 0 then
            open[role] = open[role] - 1
            Leftovers(members, open, allowed, index + 1, out)
            open[role] = open[role] + 1
        end
    end
    return out
end

local function RoomAfter(members, open, roles)
    for _, left in ipairs(Leftovers(members, open, ALL_ROLES)) do
        for _, role in ipairs(roles) do
            if left[role] > 0 then return true end
        end
    end
    return false
end

local function Brings(application, classes)
    for _, member in ipairs(application.members) do
        if classes[member.class] then return true end
    end
    return false
end
```

Replace `Rules.Passes` with:

```lua
function Rules.Passes(application, group, s)
    if application.pinned then return true end
    for _, member in ipairs(application.members) do
        if not MemberPasses(member, s) then return false end
    end
    if not HasNeededClass(application, s) then return false end

    local open = group.open
    if not open then return true end
    if s.hideFilledRoles and #Leftovers(application.members, open, s.roles) == 0 then return false end
    if s.bloodlustFit and not (group.hasBloodlust or Brings(application, Rules.BLOODLUST))
        and not RoomAfter(application.members, open, { "HEALER", "DAMAGER" }) then
        return false
    end
    if s.battleResFit and not (group.hasBattleRes or Brings(application, Rules.BATTLE_RES))
        and not RoomAfter(application.members, open, Rules.ROLES) then
        return false
    end
    return true
end
```

- [ ] **Step 4: Run the tests to see them pass**

Run the test command. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Modules/Applicants/FilterRules.lua tests/filterrules_spec.lua
git commit -m "feat: filter applicants by open role slots and Bloodlust or battle res fit"
```

---

### Task 4: FilterRules - partition and migration of old class picks

**Files:**
- Modify: `Modules/Applicants/FilterRules.lua` (append `Rules.Apply`, `Rules.Migrate`)
- Test: `tests/filterrules_spec.lua` (append)

**Interfaces:**
- Consumes: `Rules.Passes`, `Rules.Defaults`.
- Produces:
  - `Rules.Apply(ids, byId, group, settings) -> failed, count` - reorders `ids` in place: passing first, then failing (mode `"down"`) or failing removed (mode `"hide"`); each part keeps its order. `failed` is a set `{ [id] = true }`, `count` the number of failing ids.
  - `Rules.Migrate(current, oldClassPicks) -> settings` - returns `current` filled with any missing default, or new defaults with the old picks copied into `classes` when `current` is nil.

- [ ] **Step 1: Append the failing tests**:

```lua
describe("Rules.Apply", function()
  local byId = {
    [1] = app(member("MAGE")),
    [2] = app(member("PALADIN")),
    [3] = app(member("PRIEST")),
    [4] = app(member("PALADIN")),
  }
  local s = settings({ classes = { PALADIN = EXCLUDE } })

  it("moves failing applications below passing ones, keeping both orders", function()
    local ids = { 4, 1, 2, 3 }
    local failed, count = Rules.Apply(ids, byId, OPEN_GROUP, s)
    assert.same({ 1, 3, 4, 2 }, ids)
    assert.equals(2, count)
    assert.is_true(failed[4])
    assert.is_true(failed[2])
    assert.is_nil(failed[1])
  end)

  it("removes failing applications in hide mode", function()
    local ids = { 4, 1, 2, 3 }
    local hide = settings({ classes = { PALADIN = EXCLUDE }, mode = "hide" })
    local _, count = Rules.Apply(ids, byId, OPEN_GROUP, hide)
    assert.same({ 1, 3 }, ids)
    assert.equals(2, count)
  end)
end)

describe("Rules.Migrate", function()
  it("starts from the defaults and adopts the old class picks", function()
    local migrated = Rules.Migrate(nil, { MAGE = NEED })
    assert.equals(NEED, migrated.classes.MAGE)
    assert.equals("down", migrated.mode)
    assert.is_true(migrated.roles.TANK)
  end)

  it("keeps saved settings and fills what a newer version added", function()
    local saved = { classes = { ROGUE = EXCLUDE }, roles = { TANK = false, HEALER = true, DAMAGER = true }, minRating = 2000 }
    local migrated = Rules.Migrate(saved, { MAGE = NEED })
    assert.equals(EXCLUDE, migrated.classes.ROGUE)
    assert.is_nil(migrated.classes.MAGE)
    assert.is_false(migrated.roles.TANK)
    assert.equals(2000, migrated.minRating)
    assert.equals("down", migrated.mode)
    assert.is_false(migrated.timedOnly)
  end)
end)
```

- [ ] **Step 2: Run them to see them fail**

Expected: `attempt to call field 'Apply'` / `'Migrate'` (a nil value).

- [ ] **Step 3: Implement** - append before `if ns then`:

```lua
function Rules.Apply(ids, byId, group, s)
    local passing, failing, failed = {}, {}, {}
    for _, id in ipairs(ids) do
        if Rules.Passes(byId[id], group, s) then
            passing[#passing + 1] = id
        else
            failing[#failing + 1] = id
            failed[id] = true
        end
    end

    for index = #ids, 1, -1 do
        ids[index] = nil
    end
    for _, id in ipairs(passing) do
        ids[#ids + 1] = id
    end
    if s.mode ~= "hide" then
        for _, id in ipairs(failing) do
            ids[#ids + 1] = id
        end
    end
    return failed, #failing
end

function Rules.Migrate(current, oldClassPicks)
    local defaults = Rules.Defaults()
    if current == nil then
        current = defaults
        for class, state in pairs(oldClassPicks or {}) do
            current.classes[class] = state
        end
        return current
    end
    for key, value in pairs(defaults) do
        if current[key] == nil then current[key] = value end
    end
    return current
end
```

- [ ] **Step 4: Run the tests to see them pass**

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Modules/Applicants/FilterRules.lua tests/filterrules_spec.lua
git commit -m "feat: move down or hide failing applicants and adopt saved class picks"
```

---

### Task 5: ApplicantData and Pipeline

**Files:**
- Create: `Modules/Applicants/ApplicantData.lua`, `Modules/Applicants/Pipeline.lua`
- Test: `tests/applicantdata_spec.lua`

**Interfaces:**
- Consumes: `Rules.BLOODLUST`, `Rules.BATTLE_RES` (Task 2).
- Produces:
  - `Data.Listing() -> { activityID = n, isMythicPlus = bool, fiveMan = bool } | nil`
  - `Data.DungeonBest(applicantID, memberIndex, activityID) -> { level = n, timed = bool, score = n } | nil | false` (`false` = Secret)
  - `Data.Application(applicantID, listing) -> application | nil` (nil on any Secret value)
  - `Data.Group(listing) -> group`
  - `Pipeline.SORT = 1`, `Pipeline.FILTER = 2`, `Pipeline.Add(order, step)` (step is `function(applicants)`), `Pipeline.Refresh()`
  - `ns.ApplicantData`, `ns.ApplicantPipeline`

- [ ] **Step 1: Write the failing tests**

`tests/applicantdata_spec.lua`:

```lua
package.path = "./Modules/Applicants/?.lua;" .. package.path

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local function install(fakes)
  _G.issecretvalue = function(value) return value == SECRET end
  _G.C_LFGList = fakes.lfg
  _G.UnitExists = function(unit) return fakes.units[unit] ~= nil end
  _G.UnitClassBase = function(unit) return fakes.units[unit].class end
  _G.UnitGroupRolesAssigned = function(unit) return fakes.units[unit].role end
end

local function lfg(members, status, best)
  return {
    GetApplicantInfo = function() return { numMembers = #members, applicationStatus = status or "applied" } end,
    GetApplicantMemberInfo = function(_, i)
      local m = members[i]
      return "Name", m.class, "Class", 90, m.itemLevel, 0, m.tank, m.healer, m.damage, "NONE", nil, m.rating
    end,
    GetApplicantDungeonScoreForListing = function(_, i) return best and best[i] end,
    GetActiveEntryInfo = function() return { activityIDs = { 42 } } end,
    GetActivityInfoTable = function() return { isMythicPlusActivity = true, maxNumPlayers = 5 } end,
  }
end

local function load()
  package.loaded["FilterRules"] = nil
  package.loaded["ApplicantData"] = nil
  return require("ApplicantData")
end

describe("Data.Application", function()
  it("reads every member into the plain table the rules use", function()
    install({ units = {}, lfg = lfg(
      { { class = "MAGE", itemLevel = 291.4, tank = false, healer = false, damage = true, rating = 2700 } },
      "applied", { { bestRunLevel = 12, finishedSuccess = true, mapScore = 310 } }) })
    local Data = load()
    local application = Data.Application(7, { activityID = 42, isMythicPlus = true })
    local m = application.members[1]
    assert.equals("MAGE", m.class)
    assert.equals(2700, m.rating)
    assert.equals(291.4, m.itemLevel)
    assert.is_true(m.roles.DAMAGER)
    assert.equals(12, m.dungeonLevel)
    assert.is_true(m.dungeonTimed)
    assert.equals(310, m.dungeonScore)
    assert.is_false(application.pinned)
  end)

  it("marks an invited application as pinned", function()
    install({ units = {}, lfg = lfg({ { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 1 } }, "invited") })
    assert.is_true(load().Application(7, { activityID = 42, isMythicPlus = true }).pinned)
  end)

  it("returns nothing when any member value is Secret", function()
    install({ units = {}, lfg = lfg({
      { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 2000 },
      { class = "PRIEST", itemLevel = 290, tank = false, healer = true, damage = false, rating = SECRET },
    }) })
    assert.is_nil(load().Application(7, { activityID = 42, isMythicPlus = true }))
  end)

  it("returns nothing when the dungeon score is Secret", function()
    install({ units = {}, lfg = lfg(
      { { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 2000 } },
      "applied", { { bestRunLevel = SECRET, finishedSuccess = true, mapScore = 1 } }) })
    assert.is_nil(load().Application(7, { activityID = 42, isMythicPlus = true }))
  end)

  it("leaves the dungeon fields empty outside Mythic+ listings", function()
    install({ units = {}, lfg = lfg(
      { { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 2000 } },
      "applied", { { bestRunLevel = 12, finishedSuccess = true, mapScore = 1 } }) })
    local m = load().Application(7, { activityID = 42, isMythicPlus = false }).members[1]
    assert.is_nil(m.dungeonLevel)
  end)
end)

describe("Data.Group", function()
  it("counts assigned roles against one tank, one healer, three damage", function()
    install({ lfg = lfg({}), units = {
      player = { class = "PALADIN", role = "TANK" },
      party1 = { class = "SHAMAN", role = "HEALER" },
      party2 = { class = "ROGUE", role = "DAMAGER" },
    } })
    local group = load().Group({ fiveMan = true })
    assert.same({ TANK = 0, HEALER = 0, DAMAGER = 2 }, group.open)
    assert.is_true(group.hasBloodlust)
    assert.is_true(group.hasBattleRes)
  end)

  it("has no role slots for a listing that is not five players", function()
    install({ lfg = lfg({}), units = { player = { class = "ROGUE", role = "DAMAGER" } } })
    local group = load().Group({ fiveMan = false })
    assert.is_nil(group.open)
    assert.is_false(group.hasBloodlust)
  end)
end)
```

- [ ] **Step 2: Run it to see it fail**

Expected: `module 'ApplicantData' not found`.

- [ ] **Step 3: Write `Modules/Applicants/ApplicantData.lua`**

```lua
local _, ns = ...

local Rules = ns and ns.FilterRules or require("FilterRules")

local Data = {}

local function AnySecret(...)
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then return true end
    end
    return false
end

function Data.Listing()
    local entry = C_LFGList.GetActiveEntryInfo()
    local activityID = entry and entry.activityIDs and entry.activityIDs[1]
    local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
    if not activity then return nil end
    return {
        activityID = activityID,
        isMythicPlus = activity.isMythicPlusActivity == true,
        fiveMan = activity.maxNumPlayers == 5,
    }
end

function Data.DungeonBest(applicantID, memberIndex, activityID)
    local best = C_LFGList.GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID)
    if not best then return nil end
    if AnySecret(best.bestRunLevel, best.finishedSuccess, best.mapScore) then return false end
    if (best.bestRunLevel or 0) <= 0 then return nil end
    return { level = best.bestRunLevel, timed = best.finishedSuccess == true, score = best.mapScore }
end

function Data.Application(applicantID, listing)
    if issecretvalue(applicantID) then return nil end
    local info = C_LFGList.GetApplicantInfo(applicantID)
    if not info or AnySecret(info.numMembers, info.applicationStatus) then return nil end

    local status = info.applicationStatus
    local application = { members = {}, pinned = status == "invited" or status == "inviteaccepted" }
    for i = 1, info.numMembers or 0 do
        local _, class, _, _, itemLevel, _, tank, healer, damage, _, _, rating = C_LFGList.GetApplicantMemberInfo(applicantID, i)
        if AnySecret(class, itemLevel, tank, healer, damage, rating) then return nil end
        local member = {
            class = class,
            itemLevel = itemLevel,
            rating = rating,
            roles = { TANK = tank == true, HEALER = healer == true, DAMAGER = damage == true },
        }
        if listing.isMythicPlus then
            local best = Data.DungeonBest(applicantID, i, listing.activityID)
            if best == false then return nil end
            if best then
                member.dungeonLevel, member.dungeonTimed, member.dungeonScore = best.level, best.timed, best.score
            end
        end
        application.members[i] = member
    end
    return application
end

local UNITS = { "player", "party1", "party2", "party3", "party4" }

function Data.Group(listing)
    local group = { hasBloodlust = false, hasBattleRes = false }
    if listing.fiveMan then
        group.open = { TANK = 1, HEALER = 1, DAMAGER = 3 }
    end
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local class = UnitClassBase(unit)
            if Rules.BLOODLUST[class] then group.hasBloodlust = true end
            if Rules.BATTLE_RES[class] then group.hasBattleRes = true end
            local role = UnitGroupRolesAssigned(unit)
            if group.open and group.open[role] then
                group.open[role] = math.max(0, group.open[role] - 1)
            end
        end
    end
    return group
end

if ns then ns.ApplicantData = Data end
return Data
```

- [ ] **Step 4: Write `Modules/Applicants/Pipeline.lua`** (frame-bound, no unit test):

```lua
local addonName, ns = ...

local Pipeline = {}

Pipeline.SORT = 1
Pipeline.FILTER = 2

local steps = {}
local hooked = false

local function Run(applicants)
    if type(applicants) ~= "table" or issecretvalue(applicants) then return end
    for _, step in ipairs(steps) do
        step.run(applicants)
    end
end

function Pipeline.Add(order, run)
    steps[#steps + 1] = { order = order, run = run }
    table.sort(steps, function(a, b) return a.order < b.order end)
    if not hooked then
        hooked = true
        hooksecurefunc("LFGListUtil_SortApplicants", Run)
    end
end

function Pipeline.Refresh()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
    if viewer and viewer:IsVisible() then
        LFGListApplicationViewer_UpdateResultList(viewer)
        LFGListApplicationViewer_UpdateResults(viewer)
    end
end

ns.ApplicantPipeline = Pipeline
```

- [ ] **Step 5: Run the tests to see them pass**, and syntax-check `Modules/Applicants/Pipeline.lua` with the luac command. Expected: all pass, `luac` silent.

- [ ] **Step 6: Commit**

```bash
git add Modules/Applicants/ApplicantData.lua Modules/Applicants/Pipeline.lua tests/applicantdata_spec.lua
git commit -m "feat: read applicants into plain tables and run applicant steps in a fixed order"
```

---

### Task 6: Move the sort into Modules/Applicants, third key, dungeon key on rows

**Files:**
- Move: `Modules/ApplicantSort/ApplicantOrder.lua` -> `Modules/Applicants/ApplicantOrder.lua` (content unchanged)
- Move and rewrite: `Modules/ApplicantSort/ApplicantSort.lua` -> `Modules/Applicants/ApplicantSort.lua`
- Modify: `tests/applicantorder_spec.lua` (path line), `LittleThings.toc`
- Delete: `Modules/ApplicantSort/`

**Interfaces:**
- Consumes: `Order.Sort(applicants, keys)` (existing), `Data.Listing`, `Data.Application`, `Data.DungeonBest`, `Pipeline.Add`, `Pipeline.SORT`.
- Produces: sort options `rating`, `itemLevel`, `dungeon`; a font string `member.ltKey` on applicant member frames.

- [ ] **Step 1: Point the order test at the new folder and add a three-key case**

In `tests/applicantorder_spec.lua` change the first line to:

```lua
package.path = "./Modules/Applicants/?.lua;" .. package.path
```

and append:

```lua
describe("Order.Sort, dungeon first", function()
  it("orders by the dungeon score and breaks ties with the overall rating", function()
    local dungeon = { [1] = 300, [2] = 310, [3] = 300 }
    local rating = { [1] = 2400, [2] = 2000, [3] = 2600 }
    assert.equals("2 3 1", sorted({ 1, 2, 3 }, dungeon, rating))
  end)
end)
```

- [ ] **Step 2: Move the files**

```bash
git mv Modules/ApplicantSort/ApplicantOrder.lua Modules/Applicants/ApplicantOrder.lua
git mv Modules/ApplicantSort/ApplicantSort.lua Modules/Applicants/ApplicantSort.lua
```

- [ ] **Step 3: Rewrite `Modules/Applicants/ApplicantSort.lua`**

```lua
local addonName, ns = ...

local Order = ns.ApplicantOrder
local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline

local ApplicantSort = {}

local KEYS = {
    rating = "Mythic+ rating, then item level",
    itemLevel = "Item level, then Mythic+ rating",
    dungeon = "This dungeon, then Mythic+ rating",
}
local KEY_ORDER = { "rating", "itemLevel", "dungeon" }

ApplicantSort.defaults = { by = "rating" }

local enabled = false

local function Options()
    return ns.db.applicantSortOptions
end

local function Sort(applicants)
    if not ns.db.applicantSort then return end
    local listing = Data.Listing()
    if not listing or not listing.isMythicPlus then return end

    local rating, itemLevel, dungeon = {}, {}, {}
    for _, applicantID in ipairs(applicants) do
        local application = Data.Application(applicantID, listing)
        if not application then return end
        local first = application.members[1]
        if first then
            rating[applicantID] = first.rating
            itemLevel[applicantID] = first.itemLevel
            dungeon[applicantID] = first.dungeonScore
        end
    end

    local by = Options().by
    if by == "itemLevel" then
        Order.Sort(applicants, { itemLevel, rating })
    elseif by == "dungeon" then
        Order.Sort(applicants, { dungeon, rating })
    else
        Order.Sort(applicants, { rating, itemLevel })
    end
end

local function ShowKey(member, applicantID, memberIndex)
    if not member.ltKey then
        member.ltKey = member:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        member.ltKey:SetPoint("LEFT", member.Rating, "RIGHT", 6, 0)
    end

    local text = ""
    local listing = ns.db.applicantSort and not issecretvalue(applicantID) and Data.Listing()
    if listing and listing.isMythicPlus then
        local best = Data.DungeonBest(applicantID, memberIndex, listing.activityID)
        if best then
            local color = best.timed and GREEN_FONT_COLOR or GRAY_FONT_COLOR
            text = color:WrapTextInColorCode("+" .. best.level)
        end
    end
    member.ltKey:SetText(text)
end

function ApplicantSort.Pages(page)
    ns.db.applicantSortOptions = ns.db.applicantSortOptions or {}
    ns.ApplyDefaults(ns.db.applicantSortOptions, ApplicantSort.defaults)
    if not KEYS[Options().by] then
        Options().by = ApplicantSort.defaults.by
    end

    local setting = Settings.RegisterProxySetting(page.category, "LT_applicantSort_by", Settings.VarType.String,
        "Sort by", ApplicantSort.defaults.by,
        function() return Options().by end,
        function(value)
            Options().by = value
            Pipeline.Refresh()
        end)

    local function KeyOptions()
        local container = Settings.CreateControlTextContainer()
        for _, key in ipairs(KEY_ORDER) do
            container:Add(key, KEYS[key])
        end
        return container:GetData()
    end

    ns.AddToPage(page, Settings.CreateDropdown(page.category, setting, KeyOptions,
        "What puts an applicant higher. The second value only decides between applicants who tie on the first. This dungeon is the applicant's rating in the listed dungeon. A group that applies together counts as the player who sent the application."))
end

function ApplicantSort.Enable()
    if enabled then return end
    enabled = true
    Pipeline.Add(Pipeline.SORT, Sort)
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", ShowKey)
end

function ApplicantSort.OnSwitch(on)
    if on then ApplicantSort.Enable() end
    Pipeline.Refresh()
end

ApplicantSort.key = "applicantSort"
ns.RegisterModule("ApplicantSort", ApplicantSort)
```

- [ ] **Step 4: Update the TOC**

In `LittleThings.toc` replace the two `Modules/ApplicantSort/...` lines with:

```
Modules/Applicants/FilterRules.lua
Modules/Applicants/ApplicantData.lua
Modules/Applicants/Pipeline.lua
Modules/Applicants/ApplicantOrder.lua
Modules/Applicants/ApplicantSort.lua
```

(the `Modules/ClassFilter/...` lines stay until Task 7).

- [ ] **Step 5: Run the tests and syntax-check** `Modules/Applicants/ApplicantSort.lua`. Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add -A Modules/ApplicantSort Modules/Applicants tests/applicantorder_spec.lua LittleThings.toc
git commit -m "feat: sort applicants by this dungeon and show their best key here on each row"
```

---

### Task 7: ApplicantFilter module replacing ClassFilter

**Files:**
- Create: `Modules/Applicants/ApplicantFilter.lua`
- Delete: `Modules/ClassFilter/` and `tests/classfilter_spec.lua`
- Modify: `Core.lua` (the `classFilter` row in `ns.MODULES`, `ns.charDefaults`), `LittleThings.toc`

**Interfaces:**
- Consumes: `Rules.Migrate`, `Rules.IsActive`, `Rules.CountClasses`, `Rules.Apply`, `Data.Listing`, `Data.Application`, `Data.Group`, `Pipeline.Add`, `Pipeline.FILTER`, `Pipeline.Refresh`.
- Produces (for Task 8's panel), on `ns.ApplicantFilter`:
  - `ApplicantFilter.Settings() -> settings`
  - `ApplicantFilter.state` - `{ failed = { [id] = true }, count = n, paused = bool, counts = { [class] = n } | nil, listing = listing | nil }`
  - `ApplicantFilter.OnChange(fn)` - `fn()` runs after every filter pass and after `Changed()`
  - `ApplicantFilter.Changed()` - call after the panel edits settings: refreshes the list and notifies
  - `ApplicantFilter.panel` - set by Task 8; the module calls `panel:SetShown(bool)` if present
  - `ApplicantFilter.BuildPanel` - set by Task 8 (`FilterPanel.lua`); `Enable` calls it when present

- [ ] **Step 1: Write `Modules/Applicants/ApplicantFilter.lua`**

```lua
local addonName, ns = ...

local Rules = ns.FilterRules
local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline

local ApplicantFilter = {}

local DIMMED = 0.45

ApplicantFilter.state = { failed = {}, count = 0, paused = false, counts = nil, listing = nil }

local listeners = {}
local enabled = false

function ApplicantFilter.Settings()
    return ns.charDb.applicantFilter
end

function ApplicantFilter.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Notify()
    for _, fn in ipairs(listeners) do
        fn()
    end
end

local function Adopt()
    ns.charDb.applicantFilter = Rules.Migrate(ns.charDb.applicantFilter, ns.charDb.classFilter)
    ns.charDb.classFilter = nil
end

local function Filter(applicants)
    if not ns.db.classFilter then return end
    local state = ApplicantFilter.state
    state.failed, state.count, state.paused, state.counts = {}, 0, false, nil
    state.listing = Data.Listing()

    if state.listing then
        local byId, list = {}, {}
        for _, applicantID in ipairs(applicants) do
            local application = Data.Application(applicantID, state.listing)
            if not application then
                state.paused = true
                break
            end
            byId[applicantID] = application
            list[#list + 1] = application
        end

        if not state.paused then
            state.counts = Rules.CountClasses(list)
            if Rules.IsActive(ApplicantFilter.Settings()) then
                state.failed, state.count = Rules.Apply(applicants, byId, Data.Group(state.listing), ApplicantFilter.Settings())
            end
        end
    end
    Notify()
end

local function Dim(member, applicantID)
    local button = member:GetParent()
    local failed = ns.db.classFilter and not issecretvalue(applicantID) and ApplicantFilter.state.failed[applicantID]
    button:SetAlpha(failed and DIMMED or 1)
end

local function UsesGroup()
    local s = ApplicantFilter.Settings()
    return s.hideFilledRoles or s.bloodlustFit or s.battleResFit
end

function ApplicantFilter.Changed()
    Pipeline.Refresh()
    Notify()
end

function ApplicantFilter.Enable()
    Adopt()
    if ApplicantFilter.BuildPanel then ApplicantFilter.BuildPanel() end
    if ApplicantFilter.panel then ApplicantFilter.panel:SetShown(true) end
    if enabled then return end
    enabled = true
    Pipeline.Add(Pipeline.FILTER, Filter)
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", Dim)

    local events = CreateFrame("Frame")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    events:SetScript("OnEvent", function()
        if ns.db.classFilter and UsesGroup() then Pipeline.Refresh() end
    end)
end

function ApplicantFilter.OnSwitch(on)
    if on then
        ApplicantFilter.Enable()
    elseif ApplicantFilter.panel then
        ApplicantFilter.panel:SetShown(false)
    end
    ApplicantFilter.Changed()
end

ApplicantFilter.key = "classFilter"
ns.ApplicantFilter = ApplicantFilter
ns.RegisterModule("ApplicantFilter", ApplicantFilter)
```

- [ ] **Step 2: Delete the old module and its test**

```bash
git rm -r Modules/ClassFilter tests/classfilter_spec.lua
```

- [ ] **Step 3: Update `Core.lua`**

In `ns.charDefaults` remove the `classFilter = {},` line. Replace the `classFilter` row in `ns.MODULES` with:

```lua
    { key = "classFilter", label = "Applicant filter", page = "Mythic+", switch = "Applicant filter panel", live = true, tooltip = "A filter panel beside the group finder while you look through applicants to your group: classes with counts, roles, minimum rating and item level, best key in this dungeon, Bloodlust and battle res fit. Applicants who fail move to the bottom, dimmed, or are hidden. Everything on the panel is saved per character." },
```

- [ ] **Step 4: Update the TOC**

Remove the two `Modules/ClassFilter/...` lines and add after `Modules/Applicants/ApplicantSort.lua`:

```
Modules/Applicants/ApplicantFilter.lua
```

- [ ] **Step 5: Run the tests and syntax-check** `Modules/Applicants/ApplicantFilter.lua` and `Core.lua`. Expected: all pass (the class filter spec is gone, its cases live in `filterrules_spec.lua`).

- [ ] **Step 6: Commit**

```bash
git add -A Modules/Applicants/ApplicantFilter.lua Core.lua LittleThings.toc
git commit -m "feat: replace the class bar with an applicant filter module on the Mythic+ page"
```

---

### Task 8: FilterPanel frame

**Files:**
- Create: `Modules/Applicants/FilterPanel.lua`
- Modify: `LittleThings.toc`

**Interfaces:**
- Consumes: `ns.ApplicantFilter` (`Settings`, `state`, `OnChange`, `Changed`, `panel` field), `Rules.Next`, `Rules.ParseNumber`, `Rules.IsActive`, `Rules.Defaults`.
- Produces: `ApplicantFilter.panel` (a frame parented to `LFGListFrame.ApplicationViewer`) and `ApplicantFilter.BuildPanel()`.

- [ ] **Step 1: Write `Modules/Applicants/FilterPanel.lua`**

```lua
local addonName, ns = ...

local Rules = ns.FilterRules
local Filter = ns.ApplicantFilter

local WIDTH = 214
local PAD = 10
local ICON, ICON_STEP, PER_ROW = 22, 39, 5
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ROLE_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}
local BORDER = {
    [Rules.NEED] = { 0.2, 0.9, 0.2 },
    [Rules.EXCLUDE] = { 0.95, 0.15, 0.15 },
}

local panel
local classButtons, roleButtons, boxes, checks = {}, {}, {}, {}

local function S()
    return Filter.Settings()
end

local function Heading(text, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetText(text)
    return y - 18
end

local function PaintClass(button)
    local state = S().classes[button.class]
    local color = BORDER[state]
    button.border:SetShown(color ~= nil)
    if color then button.border:SetColorTexture(color[1], color[2], color[3]) end
    button.icon:SetDesaturated(state == Rules.EXCLUDE)
    button.icon:SetAlpha(state and 1 or 0.55)
end

local function ClassTooltip(button)
    local state = S().classes[button.class]
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.name, button.color.r, button.color.g, button.color.b)
    if state == Rules.NEED then
        GameTooltip:AddLine("Needed: applicants without any needed class fail.", 0.2, 0.9, 0.2, true)
    elseif state == Rules.EXCLUDE then
        GameTooltip:AddLine("Excluded: applicants of this class fail.", 0.95, 0.3, 0.3, true)
    end
    GameTooltip:AddLine("Left-click: neutral, needed, excluded. Right-click: neutral.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function ClassClick(button, mouseButton)
    local classes = S().classes
    classes[button.class] = mouseButton ~= "RightButton" and Rules.Next(classes[button.class]) or nil
    PaintClass(button)
    ClassTooltip(button)
    Filter.Changed()
end

local function BuildClasses(y)
    y = Heading("Classes", y)
    local index = 0
    for i = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(i)
        if info and CLASS_ICON_TCOORDS[info.classFile] then
            local column, row = index % PER_ROW, math.floor(index / PER_ROW)
            local button = CreateFrame("Button", nil, panel)
            button:SetSize(ICON, ICON)
            button:SetPoint("TOPLEFT", PAD + 6 + column * ICON_STEP, y - row * 36)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button.border = button:CreateTexture(nil, "BACKGROUND")
            button.border:SetPoint("TOPLEFT", -2, 2)
            button.border:SetPoint("BOTTOMRIGHT", 2, -2)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button.icon:SetTexture(CLASS_CIRCLES)
            button.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[info.classFile]))
            button.count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.count:SetPoint("TOP", button, "BOTTOM", 0, -1)
            button.class, button.name = info.classFile, info.className
            button.color = RAID_CLASS_COLORS[info.classFile] or NORMAL_FONT_COLOR
            button:SetScript("OnClick", ClassClick)
            button:SetScript("OnEnter", ClassTooltip)
            button:SetScript("OnLeave", GameTooltip_Hide)
            classButtons[#classButtons + 1] = button
            index = index + 1
        end
    end
    return y - math.ceil(index / PER_ROW) * 36 - 4
end

local function Check(key, label, x, y)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", x, y)
    check.text:SetText(label)
    check.text:SetFontObject("GameFontHighlightSmall")
    check:SetScript("OnClick", function(self)
        S()[key] = self:GetChecked() and true or false
        Filter.Changed()
    end)
    checks[key] = check
    return check
end

local function Box(key, label, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", PAD, y - 4)
    fs:SetText(label)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(54, 18)
    box:SetPoint("TOPRIGHT", -PAD - 4, y)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)
    box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        S()[key] = Rules.ParseNumber(self:GetText())
        Filter.Changed()
    end)
    box:SetScript("OnEnterPressed", EditBox_ClearFocus)
    box.label = fs
    boxes[key] = box
    return y - 24
end

local function RoleClick(button)
    S().roles[button.role] = not S().roles[button.role]
    button:SetAlpha(S().roles[button.role] and 1 or 0.3)
    Filter.Changed()
end

local function BuildRoles(y)
    y = Heading("Roles", y)
    for index, role in ipairs(Rules.ROLES) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", PAD + 6 + (index - 1) * 30, y)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetAtlas(ROLE_ATLAS[role])
        button.role = role
        button:SetScript("OnClick", RoleClick)
        roleButtons[role] = button
    end
    Check("hideFilledRoles", "Hide roles already filled", PAD, y - 26)
    return y - 54
end

local function BuildMode(y)
    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", PAD, y)
    dropdown:SetWidth(WIDTH - 2 * PAD)
    dropdown:SetupMenu(function(_, root)
        local function IsSelected(mode) return S().mode == mode end
        local function Select(mode)
            S().mode = mode
            Filter.Changed()
        end
        root:CreateRadio("Failing applicants move down", IsSelected, Select, "down")
        root:CreateRadio("Failing applicants are hidden", IsSelected, Select, "hide")
    end)
    return y - 30
end

local function ResetAll()
    local mode = S().mode
    local fresh = Rules.Defaults()
    for key in pairs(S()) do S()[key] = nil end
    for key, value in pairs(fresh) do S()[key] = value end
    S().mode = mode
    panel:Sync()
    Filter.Changed()
end

local function Sync()
    local s, state = S(), Filter.state
    for _, button in ipairs(classButtons) do
        PaintClass(button)
        local count = state.counts and state.counts[button.class]
        button.count:SetText(count and tostring(count) or "")
    end
    for role, button in pairs(roleButtons) do
        button:SetAlpha(s.roles[role] and 1 or 0.3)
    end
    for key, box in pairs(boxes) do
        if not box:HasFocus() then box:SetText(s[key] and tostring(s[key]) or "") end
    end
    for key, check in pairs(checks) do
        check:SetChecked(s[key] == true)
    end

    local mythicPlus = state.listing ~= nil and state.listing.isMythicPlus
    local dungeonBox = boxes.minDungeonLevel
    dungeonBox:SetEnabled(mythicPlus)
    dungeonBox:SetAlpha(mythicPlus and 1 or 0.4)
    dungeonBox.label:SetAlpha(mythicPlus and 1 or 0.4)
    checks.timedOnly:SetEnabled(mythicPlus)
    checks.timedOnly:SetAlpha(mythicPlus and 1 or 0.4)

    panel.reset:SetEnabled(Rules.IsActive(s))
    if state.paused then
        panel.status:SetText("Filter paused")
    elseif state.count > 0 then
        panel.status:SetText((s.mode == "hide" and "Hidden: " or "Moved down: ") .. state.count)
    else
        panel.status:SetText("")
    end
end

local function Build()
    local viewer = LFGListFrame.ApplicationViewer
    panel = CreateFrame("Frame", nil, viewer, "TooltipBackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPRIGHT", PVEFrame, "TOPLEFT", -2, 0)
    panel.Sync = Sync

    local y = -PAD
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, y)
    title:SetText("Applicant filter")
    y = y - 26

    y = BuildClasses(y)
    y = BuildRoles(y)
    y = Heading("Minimums", y)
    y = Box("minRating", "Mythic+ rating", y)
    y = Box("minItemLevel", "Item level", y)
    y = Heading("This dungeon", y)
    y = Box("minDungeonLevel", "Best key at least", y)
    Check("timedOnly", "Timed only", PAD, y)
    y = y - 28
    y = Heading("Group utility", y)
    Check("bloodlustFit", "Bloodlust fit", PAD, y)
    Check("battleResFit", "Battle res fit", PAD + 96, y)
    y = y - 30
    y = BuildMode(y)

    panel.reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.reset:SetSize(70, 22)
    panel.reset:SetPoint("TOPLEFT", PAD, y)
    panel.reset:SetText(RESET)
    panel.reset:SetScript("OnClick", ResetAll)

    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.status:SetPoint("LEFT", panel.reset, "RIGHT", 8, 0)
    y = y - 22 - PAD

    panel:SetHeight(-y)
    Filter.panel = panel
    Filter.OnChange(Sync)
    panel:SetScript("OnShow", Sync)
    panel:SetShown(ns.db.classFilter == true)
    Sync()
end

Filter.BuildPanel = function()
    if not panel and LFGListFrame then Build() end
end
```

`ApplicantFilter.Enable` (Task 7) calls `ApplicantFilter.BuildPanel()` after `Adopt()`, so the panel is built on the first enable, at login or from the switch, when `ns.charDb.applicantFilter` already exists.

- [ ] **Step 2: Add the file to the TOC** after `Modules/Applicants/ApplicantFilter.lua`:

```
Modules/Applicants/FilterPanel.lua
```

- [ ] **Step 3: Syntax-check** `Modules/Applicants/FilterPanel.lua`, run the suite. Expected: clean, all pass.

- [ ] **Step 4: Commit**

```bash
git add Modules/Applicants/FilterPanel.lua LittleThings.toc
git commit -m "feat: add the applicant filter panel beside the group finder"
```

---

### Task 9: Docs

**Files:**
- Modify: `README.md` (the Mythic+ section), `docs/IN-GAME-CHECKLIST.md` (section 9), `docs/superpowers/specs/2026-09-26-applicant-filter-design.md` (Code layout: folder is `Modules/Applicants/`, plus `Pipeline.lua`, `ApplicantOrder.lua`, `ApplicantSort.lua`, `FilterPanel.lua`), `LittleThings.toc` `## Notes` (replace "a class filter for applicants" with "an applicant filter panel").

**Interfaces:** none.

- [ ] **Step 1: README** - replace the "Class filter for applicants" paragraph with:

```markdown
**Applicant filter.** While your group is listed, a panel sits left of the group finder: class icons with how many applicants of each class there are (click once to need a class, again to exclude it, again or right-click to clear), role toggles and "Hide roles already filled", minimum Mythic+ rating and item level, the best key in the listed dungeon with "Timed only", and Bloodlust fit and battle res fit, which keep an applicant who brings it or leaves room for someone who can. Applicants who fail move to the bottom, dimmed, or are hidden, as the panel's mode says; an invited applicant never moves. A group applying together passes the minimums only if every member does. Reset clears everything but the mode. Everything is saved per character.
```

and add to the "Applicants by rating" paragraph: `Each row also shows the applicant's best key in the listed dungeon, green when timed, and the page can sort by this dungeon's rating instead.`

- [ ] **Step 2: Checklist** - replace section 9 with:

```markdown
## 9. Applicant filter

- [ ] Switch on Applicant filter, list a Mythic+ key, open the applicants: the panel sits left of the finder, clear of Raider.IO's frame on the right; it is gone on the search list and when the finder closes.
- [ ] Class icons show counts, including applicants moved down or hidden; need, exclude and clear work as the tooltip says.
- [ ] Minimum rating 2500: applicants below move to the bottom, dimmed; "Moved down: N" matches. Empty the box: back to normal. Type 0: nothing moves.
- [ ] Best key at least 10 and Timed only: an applicant who never ran the dungeon moves down. In a raid listing both are greyed out.
- [ ] Roles: tank toggled off moves tank-only applicants down; a tank/damage flex stays. Hide roles already filled with a tank in the group moves tank-only applicants down; when the tank leaves, they come back.
- [ ] Bloodlust fit with no Bloodlust class in the group and one damage slot left: a mage stays, a rogue moves down.
- [ ] Mode Hide: failing applicants disappear, "Hidden: N". An invited applicant stays whatever the filters say.
- [ ] Rows show the best key in this dungeon next to the rating, green when timed; Sort by "This dungeon" orders by it.
- [ ] Reset clears everything except the mode. Invite and decline from a filtered list work, BugSack stays empty.
- [ ] Reload keeps every setting; another character starts clean; a character that had class picks from the old bar keeps them.
- [ ] Switch off: the panel disappears and the list is Blizzard's again at once.
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/IN-GAME-CHECKLIST.md docs/superpowers/specs/2026-09-26-applicant-filter-design.md LittleThings.toc
git commit -m "docs: describe the applicant filter panel"
```
