local addonName, ns = ...

ns.defaults = {
    damageMeter = false,
    characterPanel = false,
    groupFinder = true,
    applicantSort = true,
    applicantOrder = true,
    classFilter = true,
    compareButton = true,
    defaultPlaystyle = true,
    signUpRoles = true,
    logLink = true,
    journalLoot = true,
    performance = false,
    smoothGarbageCollection = true,
    openWorldCleanup = true,
    groupLeader = false,

    format = true,
    snap = true,
    snapThreshold = 50,
    idleAlpha = 0.4,
    strata = "MEDIUM",
}

ns.charDefaults = {
    links = {},
}

ns.MODULES = {
    { key = "groupFinder", group = "Group content", label = "Group finder", live = true, tooltip = "Tools for the premade group finder: applicant keys, sorting and a filter panel, group creation helpers, a Warcraft Logs link in player menus. Each has its own switch on the Group finder page." },
    { key = "applicantSort", parent = "groupFinder", label = "Keys and raid progress on applicants", section = "Applicants", live = true, tooltip = "When your group is listed, each Mythic+ applicant shows their best key anywhere and in the listed dungeon beside the rating, and with Raider.IO each raid applicant shows their progress in the listed raid." },
    { key = "applicantOrder", parent = "groupFinder", label = "Sort applicants", section = "Applicants", live = true, tooltip = "When your group is listed, applicants who pass the filter panel come first. Within that, Mythic+ applicants are ordered by rating or item level and raid applicants by progress or item level, as chosen below. While the game restricts addons (combat, boss encounters, an active key, chat lockdown) the list goes back to Blizzard's order and is sorted again once the restriction ends." },
    { key = "classFilter", parent = "groupFinder", label = "Applicant filter panel", section = "Applicants", live = true, tooltip = "A filter panel beside the group finder while you look through applicants to your group: classes with counts, roles, minimum item level, and in 5-player listings only the roles your group still needs and Bloodlust or battle res. Applicants who fail are dimmed, and with Sort applicants on they go below the rest. Everything on the panel is saved per character." },
    { key = "compareButton", parent = "groupFinder", label = "Compare applicants button", section = "Applicants", live = true, tooltip = "A button in the top right corner of your listing's dungeon box that copies a link to your summary site's compare page: every applicant ranked by their logs and by what their class adds to the group, and the best group to fill your open slots. It appears only once the summary site address is set (Group finder page, Summary page)." },
    { key = "defaultPlaystyle", parent = "groupFinder", label = "Group creation helpers", section = "Creating a group", live = true, tooltip = "Creating a listing opens with the playstyle below already picked, choosing a dungeon picks its Mythic+ difficulty, and a list beside the screen shows your group's keystones to pick from. The game only lets its own code create a listing; if it ever blocks the screen after the addon changed it, this switch turns itself off and says so in chat." },
    { key = "signUpRoles", parent = "groupFinder", label = "Sign-up roles on the search panel", section = "Searching for a group", live = true, tooltip = "Tank, healer and damage icons at the top of the premade group search: the roles you sign up with. They are the Dungeon Finder roles, which one-click sign-up addons read too. Click an icon to switch that role." },
    { key = "logLink", parent = "groupFinder", label = "Warcraft Logs link in player menus", section = "Player menus", live = true, tooltip = "Right-click a player anywhere and copy their Warcraft Logs page, opened on the Mythic+ season. Off leaves every menu exactly as Blizzard built it. The /wcl command works either way." },
    { key = "groupLeader", group = "Group content", label = "Group leader icons", live = true, tooltip = "A crown on the group leader and an assistant icon on raid assistants, on Blizzard's party and raid frames." },
    { key = "damageMeter", group = "Combat", label = "Damage meter", tooltip = "Readable numbers, window snapping, idle transparency and a window page for Blizzard's built-in damage meter." },
    { key = "characterPanel", group = "Character and loot", label = "Character panel", live = true, tooltip = "One-click specialization and loot specialization icons next to the character panel." },
    { key = "journalLoot", group = "Character and loot", label = "Journal loot", live = true, tooltip = "Icons on every loot row of the Adventure Guide showing which specializations the item drops for." },
    { key = "performance", group = "System", label = "Performance", live = true, tooltip = "A button that sets the game's graphics options for frame rate, showing every change before it is made, and one that puts your own settings back. Smoother garbage collection, and a button that collects it now." },
}

local rows = {}
for _, row in ipairs(ns.MODULES) do
    rows[row.key] = row
end

function ns.IsOn(key)
    local row = rows[key]
    local parent = row and row.parent
    return ns.db[key] == true and (parent == nil or ns.db[parent] == true)
end

local modules = {}
local moduleOrder = {}

-- Modules register themselves at file scope and are enabled at PLAYER_LOGIN,
-- after the saved variables exist. Enable order follows registration order,
-- which follows the TOC. A module names the switch it belongs to; the switch
-- is read once at login, so flipping one takes a reload.
function ns.RegisterModule(name, module)
    if modules[name] then
        return
    end

    modules[name] = module
    table.insert(moduleOrder, module)
end

function ns.Print(message)
    print("|cff33ff99LittleThings|r: " .. message)
end

-- One reload prompt per session. A size or a show that goes through
-- Blizzard's own code runs it inside our taint (docs/DECISIONS.md), and a
-- reload is what clears that: Blizzard restores the size and the window
-- itself at login, untainted. Asking once is enough - the taint does
-- not get worse, and the popup would otherwise follow every keystroke.
local reloadRequested = false

StaticPopupDialogs["LITTLETHINGS_RELOAD"] = {
    text = "LittleThings changed a window's %s through Blizzard's code. Until the UI is reloaded the meter carries the addon's taint and logs a warning per row in combat. Reload now?",
    button1 = RELOADUI,
    button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.RequestReload(what)
    if reloadRequested then
        return
    end

    reloadRequested = true
    StaticPopup_Show("LITTLETHINGS_RELOAD", what)
end

function ns.IsAvailable()
    return DamageMeter ~= nil
        and DamageMeterSessionWindowMixin ~= nil
        and DamageMeterEntryMixin ~= nil
end

-- Rows that carry a death recap render a timestamp rather than a number, so
-- the formatting has to leave them alone. deathRecapID is documented
-- NeverSecret, so reading it in combat is safe.
function ns.HasDeathRecap(source)
    return type(source.deathRecapID) == "number" and source.deathRecapID ~= 0
end

-- Mixin methods are copied onto a frame when the frame is created, so hooking
-- a mixin table only reaches frames created after the hook. Everything that
-- already exists at PLAYER_LOGIN has to be hooked one frame at a time. The
-- flag keeps a frame from being hooked twice.
-- Keyed by method and handler together: two modules legitimately hook the same
-- method with different handlers and both must install, and one module
-- legitimately hooks several methods with one shared handler - which a
-- handler-only key silently collapsed into a single hook.
function ns.HookInstance(frame, methodName, handler)
    frame.dmtHooks = frame.dmtHooks or {}

    local key = methodName .. tostring(handler)

    if frame.dmtHooks[key] then
        return
    end

    frame.dmtHooks[key] = true
    hooksecurefunc(frame, methodName, handler)
end

-- One timer for every module that repaints or re-attaches from outside
-- Blizzard's render pass. Five times a second is the ceiling of how long
-- Blizzard's own state can show before ours is on top of it again, and the
-- work per tick is a walk over the visible bars.
ns.SWEEP_INTERVAL = 0.2

local sweeps = {}
local frameSweeps = {}

function ns.OnSweep(func)
    table.insert(sweeps, func)
end

-- Every frame, not every interval. OnUpdate runs after the frame's events
-- have been handled and before it is drawn, so work done here lands on top of
-- whatever Blizzard's event handlers just did and is what the player sees.
-- The callback decides for itself whether this frame needs it.
function ns.OnFrame(func)
    table.insert(frameSweeps, func)
end

local function StartSweeps()
    if #sweeps == 0 and #frameSweeps == 0 then
        return
    end

    local elapsed = 0
    local driver = CreateFrame("Frame", nil, UIParent)

    local function OnUpdate(_, delta)
        -- The engine runs OnUpdate handlers in registration order, and a
        -- ScrollBox that defers a full update registers its own handler in the
        -- same frame - after ours, so its repaint would land on top of our
        -- paint. Re-registering every frame keeps ours at the end of the list.
        driver:SetScript("OnUpdate", nil)
        driver:SetScript("OnUpdate", driver.OnUpdate)

        for _, func in ipairs(frameSweeps) do
            func()
        end

        elapsed = elapsed + delta

        if elapsed < ns.SWEEP_INTERVAL then
            return
        end

        elapsed = 0

        for _, func in ipairs(sweeps) do
            func()
        end
    end

    driver.OnUpdate = OnUpdate
    driver:SetScript("OnUpdate", OnUpdate)
end

function ns.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = (type(value) == "table") and {} or value
        end
    end
end

-- The addon has run under two earlier names here, so a player who used it
-- before a rename would otherwise lose every window, link and size. Adopt the
-- newest old table once, then drop the old ones so the migration cannot run
-- twice.
--
-- The old variables are still declared in the TOC, because a SavedVariable
-- that is not declared is not loaded. Once a release has shipped under the new
-- name for a while, the declarations and this function come out.
local function AdoptOldSavedVariables()
    if LittleThingsDB == nil then
        LittleThingsDB = DamageMeterCompanionDB or DamageMeterTweaksDB
        if LittleThingsDB and LittleThingsDB.damageMeter == nil then
            LittleThingsDB.damageMeter = true
        end
    end

    if LittleThingsCharDB == nil then
        LittleThingsCharDB = DamageMeterCompanionCharDB or DamageMeterTweaksCharDB
    end

    DamageMeterCompanionDB = nil
    DamageMeterCompanionCharDB = nil
    DamageMeterTweaksDB = nil
    DamageMeterTweaksCharDB = nil
end

local function InitializeSavedVariables()
    AdoptOldSavedVariables()

    LittleThingsDB = LittleThingsDB or {}
    LittleThingsCharDB = LittleThingsCharDB or {}

    if LittleThingsDB.groupFinder == nil then
        for _, row in ipairs(ns.MODULES) do
            if row.parent == "groupFinder" and LittleThingsDB[row.key] then
                LittleThingsDB.groupFinder = true
            end
        end
    end

    ns.ApplyDefaults(LittleThingsDB, ns.defaults)
    ns.ApplyDefaults(LittleThingsCharDB, ns.charDefaults)

    -- The snap distance default moved from 15 to 50 after the first version
    -- shipped. ApplyDefaults only fills nils, so a profile that already carries
    -- the old default would never see the new one. Move it once, and only when
    -- it is still exactly the old default - a value the player chose is theirs.
    if not LittleThingsDB.snapThresholdDefaultMoved then
        LittleThingsDB.snapThresholdDefaultMoved = true

        if LittleThingsDB.snapThreshold == 15 then
            LittleThingsDB.snapThreshold = ns.defaults.snapThreshold
        end
    end

    ns.db = LittleThingsDB
    ns.charDb = LittleThingsCharDB
end

-- A module whose hooks cannot be undone takes a reload to switch; the popup
-- offers one now and otherwise leaves the switch saved for the next login.
StaticPopupDialogs["LITTLETHINGS_MODULE_RELOAD"] = {
    text = "%s is switched %s. It takes effect after the UI is reloaded. Reload now?",
    button1 = RELOADUI,
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hosts = {}

local function Registered(key)
    local found = {}
    for _, registered in ipairs(moduleOrder) do
        if registered.key == key then
            found[#found + 1] = registered
        end
    end
    return found
end

local function HasContent(host)
    for _, row in ipairs(host.rows) do
        if row.parent then
            return true
        end
        for _, registered in ipairs(Registered(row.key)) do
            if registered.Pages then
                return true
            end
        end
    end
    return false
end

local function HostOf(key)
    local row = rows[key]
    local title = row.parent and rows[row.parent].label or row.label
    for _, host in ipairs(hosts) do
        if host.title == title then
            return host
        end
    end
end

local function AddModuleSwitch(category, row)
    local setting = Settings.RegisterProxySetting(category, "LT_module_" .. row.key,
        Settings.VarType.Boolean, row.label, ns.defaults[row.key],
        function() return ns.db[row.key] end,
        function(value)
            ns.SetSwitch(row.key, value)

            if not row.live then
                StaticPopup_Show("LITTLETHINGS_MODULE_RELOAD", row.label, value and "on" or "off")
            end
        end)

    local tooltip = row.tooltip
    if not row.live then
        tooltip = tooltip .. "|n|n|cff808080Takes effect after /reload.|r"
    end
    return Settings.CreateCheckbox(category, setting, tooltip)
end

local function ParentOn(row)
    return function() return ns.db[row.parent] == true end
end

local function BuildHost(host)
    host.category, host.layout = ns.RegisterSubcategory(host.title)
    local section
    for _, row in ipairs(host.rows) do
        local page = { key = row.key, category = host.category, layout = host.layout }
        if row.parent then
            if row.section and row.section ~= section and host.layout and CreateSettingsListSectionHeaderInitializer then
                section = row.section
                local header = CreateSettingsListSectionHeaderInitializer(section)
                header:AddShownPredicate(ParentOn(row))
                host.layout:AddInitializer(header)
            end
            page.switch = AddModuleSwitch(host.category, row)
            page.switch:AddShownPredicate(ParentOn(row))
        end

        ns.pages[row.key] = page
        for _, registered in ipairs(Registered(row.key)) do
            if registered.Pages then
                registered.Pages(page)
            end
        end
    end
end

local function EnsurePage(key)
    local host = HostOf(key)
    if host and not host.category and HasContent(host) then
        BuildHost(host)
    end
end

-- Blizzard has no call to take a page out of the list, so the list of our pages
-- is rewritten in place: only modules that are on keep one, in root order.
local function SyncPages(host)
    local list = ns.category:GetSubcategories()
    for index = #list, 1, -1 do
        for _, other in ipairs(hosts) do
            if list[index] == other.category then
                table.remove(list, index)
                break
            end
        end
    end
    for _, other in ipairs(hosts) do
        if other.category and ns.db[other.rows[1].key] then
            table.insert(list, other.category)
        end
    end
    if host and host.category then
        Settings.RegisterAddOnCategory(host.category)
    end
end

function ns.SetSwitch(key, value)
    ns.db[key] = value
    if value then
        EnsurePage(key)
    end
    if not rows[key].parent then
        SyncPages(HostOf(key))
    end
    for _, row in ipairs(ns.MODULES) do
        if row.key == key or row.parent == key then
            for _, registered in ipairs(Registered(row.key)) do
                if registered.OnSwitch then
                    registered.OnSwitch(ns.IsOn(row.key))
                end
            end
        end
    end
end

-- Options of a module whose switch is on its page hang indented under it.
function ns.AddToPage(page, initializer)
    if page.switch then
        initializer:SetParentInitializer(page.switch)
    end
    initializer:AddShownPredicate(function() return ns.IsOn(page.key) end)
    return initializer
end

function ns.AddHeader(page, text)
    if page.layout and CreateSettingsListSectionHeaderInitializer then
        local initializer = CreateSettingsListSectionHeaderInitializer(text)
        page.layout:AddInitializer(initializer)
        return ns.AddToPage(page, initializer)
    end
end

function ns.RegisterSubcategory(name)
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(ns.category, name)
    Settings.RegisterAddOnCategory(category)
    return category, layout
end

local function IsEnabled(module)
    if module.key and not ns.IsOn(module.key) then
        return false
    end

    if module.key == "damageMeter" and not ns.IsAvailable() then
        return false
    end

    return true
end

-- The root page holds one switch per module, its description in the tooltip.
-- A module's page is built at login when the module is on, or the moment it is
-- switched on. Group finder's tools each have their own switch on its page.
local function RegisterSettings()
    local layout
    ns.category, layout = Settings.RegisterVerticalLayoutCategory("LittleThings")
    -- A section header is the only plain-text initializer Blizzard's settings
    -- list offers, and it is guarded because a client without it should lose
    -- the text rather than the panel.
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Switch a module on to get its page in the list."))
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("|cFF0057B7Made|r |cFFFFD700in Ukraine|r"))
    end
    Settings.RegisterAddOnCategory(ns.category)

    ns.pages = {}
    local group
    for _, row in ipairs(ns.MODULES) do
        if row.parent then
            table.insert(HostOf(row.key).rows, row)
        else
            if row.group ~= group and layout and CreateSettingsListSectionHeaderInitializer then
                group = row.group
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(group))
            end
            hosts[#hosts + 1] = { title = row.label, rows = { row } }
            AddModuleSwitch(ns.category, row)
        end
    end

    for _, row in ipairs(ns.MODULES) do
        if not row.parent and ns.db[row.key] then
            EnsurePage(row.key)
        end
    end
end

-- Settings.OpenToCategory reaches the protected OpenSettingsPanel, which an
-- addon may not call in combat. Blizzard's own entries work because their
-- code is not tainted; ours is blocked and would otherwise fail silently
-- apart from a line in the error log.
function ns.OpenSettings(category)
    if InCombatLockdown() then
        ns.Print("the settings panel cannot be opened in combat")
        return
    end

    Settings.OpenToCategory((category or ns.category):GetID())
end

-- Prints what the design assumes about secrecy and CVar access so the
-- assumptions can be checked instead of trusted. Run it once in combat and
-- once out of combat.
function ns.Probe()
    local window = DamageMeter:GetPrimarySessionWindow()
    local dataProvider = window and window:GetScrollBox():GetDataProvider()
    local elementData = dataProvider and dataProvider:Find(1)

    ns.Print("in combat: " .. tostring(UnitAffectingCombat("player")))

    if not elementData then
        ns.Print("no entries in the primary window, deal some damage first")
    else
        ns.Print(("totalAmount secret: %s, amountPerSecond secret: %s, sessionTotalAmount secret: %s, deathRecapID secret: %s"):format(
            tostring(issecretvalue(elementData.totalAmount)),
            tostring(issecretvalue(elementData.amountPerSecond)),
            tostring(issecretvalue(elementData.sessionTotalAmount)),
            tostring(issecretvalue(elementData.deathRecapID))))
    end

    -- The rows above hold whatever Blizzard fetched last, which was probably
    -- during combat. This is a fetch made right now, and it is the one that
    -- decides whether anything can become readable again after a pull.
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone)
    local fresh = ok and session and session.combatSources and session.combatSources[1]

    if not fresh then
        ns.Print("fresh fetch: no current session data" .. (ok and "" or (" - " .. tostring(session))))
    else
        ns.Print(("fresh fetch right now: sourceGUID secret %s, totalAmount secret %s, name secret %s"):format(
            tostring(issecretvalue(fresh.sourceGUID)),
            tostring(issecretvalue(fresh.totalAmount)),
            tostring(issecretvalue(fresh.name))))
    end

    local current = C_CVar.GetCVar("damageMeterEnabled")
    local ok, err = pcall(C_CVar.SetCVar, "damageMeterEnabled", current)
    ns.Print("SetCVar(damageMeterEnabled) allowed: " .. tostring(ok) .. (ok and "" or (" - " .. tostring(err))))

    -- Which operations a Secret amount survives. The percentage in the
    -- Complete mode needs one of these to work in combat.
    if elementData and issecretvalue(elementData.totalAmount) then
        local value, total = elementData.totalAmount, elementData.sessionTotalAmount
        local attempts = {
            { "value / total", function() return value / total end },
            { "value * 100", function() return value * 100 end },
            { "Round(value)", function() return Round(value) end },
            { "math.floor(value)", function() return math.floor(value) end },
            { "format %d", function() return ("%d"):format(value) end },
            { "format %.0f", function() return ("%.0f"):format(value) end },
            { "FormatPercentage(value)", function() return FormatPercentage(value) end },
            { "statusbar ratio", function()
                local bar = CreateFrame("StatusBar")
                bar:SetMinMaxValues(0, total)
                bar:SetValue(value)
                return bar:GetValue()
            end },
        }

        for _, attempt in ipairs(attempts) do
            local ok, result = pcall(attempt[2])
            ns.Print(("%s: %s%s"):format(attempt[1], ok and "ok" or "ERR", ok and (", secret " .. tostring(issecretvalue(result))) or (" - " .. tostring(result))))
        end
    end
end

-- One line per window: what the addon can see about it, for bug reports.
function ns.Diagnose()
    ns.Print(("snap %s, threshold %d, format %s"):format(
        tostring(ns.db.snap), ns.db.snapThreshold, tostring(ns.db.format)))

    for _, index in ipairs(ns.Windows.Indices()) do
        local window = ns.Windows.Get(index)
        local left, bottom, width, height = window:GetRect()
        local _, relativeTo = window:GetPoint(1)
        local link = ns.charDb.links[index]

        ns.Print(("window %d: shown %s, locked %s, rect %s,%s %sx%s, anchored to %s, link %s"):format(
            index,
            tostring(window:IsShown()),
            tostring(window:IsLocked()),
            tostring(left and math.floor(left)), tostring(bottom and math.floor(bottom)),
            tostring(width and math.floor(width)), tostring(height and math.floor(height)),
            relativeTo and (relativeTo:GetName() or "unnamed") or "none",
            link and ("to " .. tostring(link.to)) or "none"))
    end
end

local function ReportTainted(label, tbl)
    local found = 0

    for key in pairs(tbl) do
        local ok, secure, taintedBy = pcall(issecurevariable, tbl, key)
        if ok and not secure then
            found = found + 1
            ns.Print(("%s.%s tainted by %s"):format(label, tostring(key), tostring(taintedBy)))
        end
    end

    return found
end

-- Names every field in the meter's windows that addon code has written, so a
-- gesture can be checked right after it instead of waiting for a fight to fail.
function ns.TaintReport()
    local windowDataList = DamageMeter:GetWindowDataList()
    local found = ReportTainted("windowDataList", windowDataList)

    for index, windowData in pairs(windowDataList) do
        found = found + ReportTainted("windowData" .. index, windowData)

        local window = windowData.sessionWindow
        if window then
            found = found + ReportTainted("window" .. index, window)
            found = found + ReportTainted("window" .. index .. ".ScrollBox", window:GetScrollBox())

            if window.onUpdateReasons then
                found = found + ReportTainted("window" .. index .. ".onUpdateReasons", window.onUpdateReasons)
            end
        end
    end

    if found == 0 then
        ns.Print("no tainted fields in the meter's windows")
    end
end

local function HandleSlashCommand(input)
    local command = string.lower(string.trim(input or ""))
    local meter = ns.db.damageMeter and ns.IsAvailable()

    if command == "" then
        ns.OpenSettings()
    elseif command == "cpu" then
        ns.Profiler.Toggle()
    elseif not meter then
        ns.Print("commands: cpu. The damage meter module is off, its commands are not available")
    elseif command == "probe" then
        ns.Probe()
    elseif command == "diag" then
        ns.Diagnose()
    elseif command == "taint" then
        ns.TaintReport()
    elseif command == "snap" or command == "format" then
        ns.db[command] = not ns.db[command]
        ns.Print(command .. ": " .. tostring(ns.db[command]))
    else
        ns.Print("commands: cpu, diag, probe, taint, format, snap")
    end
end

-- Binding names and the functions they call keep the old addon's names on
-- purpose: a key is saved against the binding name, and renaming it would
-- unbind every player's keys.
BINDING_NAME_DAMAGEMETERCOMPANION_TOGGLE = "Show or hide the damage meter"
BINDING_NAME_DAMAGEMETERCOMPANION_HIDEALL = "Hide all extra windows"
BINDING_NAME_DAMAGEMETERCOMPANION_RESET = "Reset damage meter data"

-- The primary window cannot be hidden (CanHideSessionWindow is false for it),
-- so the only way to put the whole meter away is the CVar the settings
-- checkbox uses. The CVar callback runs from Blizzard's registry, not from our
-- stack, which is what keeps this clean.
function DamageMeterCompanion_ToggleMeter()
    local enabled = C_CVar.GetCVarBool("damageMeterEnabled")

    -- SetCVar signals a refusal by returning false rather than by throwing, so
    -- both outcomes need reporting: without the second branch a refused toggle
    -- would be a key that silently does nothing.
    local ok, result = pcall(C_CVar.SetCVar, "damageMeterEnabled", enabled and "0" or "1")

    if not ok then
        ns.Print("cannot toggle the meter right now: " .. tostring(result))
    elseif result == false then
        ns.Print("the game refused to toggle the meter right now")
    end
end

-- Hide only, never show: showing a window from addon code runs Blizzard's
-- setup inside our taint and poisons that window until /reload. Bringing one
-- back is the meter's own gear menu, Show new window - untainted.
function DamageMeterCompanion_HideAll()
    if not ns.IsAvailable() or not ns.Windows then
        return
    end

    for _, index in ipairs(ns.Windows.Indices()) do
        ns.Windows.Hide(index)
    end
end

-- Same call the gear dropdown's Reset makes. Nothing Secret is touched.
function DamageMeterCompanion_ResetData()
    if ns.IsAvailable() then
        C_DamageMeter.ResetAllCombatSessions()
    end
end


local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function()
    InitializeSavedVariables()
    RegisterSettings()

    if ns.db.damageMeter and not ns.IsAvailable() then
        ns.Print("Blizzard Damage Meter not found, the damage meter module was not installed.")
    end

    for _, module in ipairs(moduleOrder) do
        if module.Enable and IsEnabled(module) then
            module.Enable()
        end
    end

    StartSweeps()

    -- /dmc and /dmt are what the addon answered to under its earlier names,
    -- and muscle memory outlives a name change.
    SLASH_LITTLETHINGS1 = "/littlethings"
    SLASH_LITTLETHINGS2 = "/lt"
    SLASH_LITTLETHINGS3 = "/dmc"
    SLASH_LITTLETHINGS4 = "/dmt"
    SlashCmdList["LITTLETHINGS"] = HandleSlashCommand
end)
