local addonName, ns = ...

local Rules = ns.SaveRules

local SaveIndicator = {}
ns.SaveIndicator = SaveIndicator

local DEFAULTS = { x = 0, y = -140, scale = 1, locked = false,
    raid = false, showTime = true, showDR = true, corners = true }

local events

local function InitializeDb()
    local db = ns.db.saveIndicatorRow or {}
    ns.db.saveIndicatorRow = db
    if db.point and db.point ~= "CENTER" then
        db.x, db.y = DEFAULTS.x, DEFAULTS.y
    end
    db.point, db.relativePoint = nil, nil
    ns.ApplyDefaults(db, DEFAULTS)
end

function SaveIndicator.Refresh()
    local db = ns.db.saveIndicatorRow
    local center, corners = false, false
    if ns.IsOn("saveIndicator") then
        center, corners = Rules.Where({ inGroup = IsInGroup(), inRaid = IsInRaid(),
            instanceType = select(2, IsInInstance()), raidOn = db.raid })
    end
    if ns.SaveCenter then ns.SaveCenter.Apply(center) end
    if ns.SaveCorners then ns.SaveCorners.Apply(corners and db.corners) end
end

function SaveIndicator.Enable()
    InitializeDb()
    if not events then
        events = CreateFrame("Frame")
        events:RegisterEvent("GROUP_ROSTER_UPDATE")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        events:SetScript("OnEvent", SaveIndicator.Refresh)
    end
    SaveIndicator.Refresh()
end

function SaveIndicator.OnSwitch(enabled)
    if enabled then
        SaveIndicator.Enable()
    elseif events then
        SaveIndicator.Refresh()
    end
end

local function Option(key, spec, apply)
    spec.default = DEFAULTS[key]
    spec.combatLocked = true
    spec.get = function() return ns.db.saveIndicatorRow[key] end
    spec.set = function(value)
        ns.db.saveIndicatorRow[key] = value
        if apply then apply() end
    end
    return spec
end

local function Place()
    if ns.SaveCenter then ns.SaveCenter.Place() end
end

function SaveIndicator.Pages(page)
    InitializeDb()
    if page.frame and ns.SaveCenter then
        page.frame:HookScript("OnShow", function() ns.SaveCenter.SetPreview(true) end)
        page.frame:HookScript("OnHide", function() ns.SaveCenter.SetPreview(false) end)
    end

    local where = page:Group("Where")
    where:Check(Option("raid", { label = "Also in raids",
        tooltip = "Shows the centre row in raids too. Party frame icons stay party only." }, SaveIndicator.Refresh))
    where:Check(Option("corners", { label = "Icons on party frames",
        tooltip = "An icon in the corner of Blizzard's party frames on whoever has a save up that the frame's own centre icon leaves out, such as Sentinel." }, SaveIndicator.Refresh))

    local row = page:Group("Centre row")
    row:Check(Option("showTime", { label = "Time left", reload = true,
        tooltip = "Seconds left inside each icon." }))
    row:Check(Option("showDR", { label = "Damage reduction", reload = true,
        tooltip = "The reduction under each icon, orange under 20%." }))
    row:Check(Option("locked", { label = "Lock position",
        tooltip = "Drag the row while this page is open to place it, then lock it." }))
    row:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f",
        tooltip = "Size of the whole row." }, Place))
    row:Slider(Option("x", { label = "X", min = -1000, max = 1000,
        tooltip = "Pixels right of the screen centre; 0 is centred. Dragging the row sets it for you." }, Place))
    row:Slider(Option("y", { label = "Y", min = -600, max = 600,
        tooltip = "Pixels above the screen centre. Dragging the row sets it for you." }, Place))
    row:Button({ label = "Center horizontally", combatLocked = true,
        tooltip = "Puts the row in the middle of the screen, keeping its height.",
        onClick = function()
            ns.db.saveIndicatorRow.x = 0
            Place()
            ns.Window.Refresh()
        end })
    row:Button({ label = "Reset position", combatLocked = true,
        tooltip = "Moves the row back below the centre of the screen.",
        onClick = function()
            local db = ns.db.saveIndicatorRow
            db.x, db.y = DEFAULTS.x, DEFAULTS.y
            Place()
            ns.Window.Refresh()
        end })
end

SaveIndicator.key = "saveIndicator"
ns.RegisterModule("SaveIndicator", SaveIndicator)
