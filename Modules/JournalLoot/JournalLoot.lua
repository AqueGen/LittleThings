local addonName, ns = ...

local Icons = ns.JournalLootIcons

local JournalLoot = {}

local EVERYONE_ICON = 922035
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ROLE_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

local CORNERS = {
    topleft = { label = "Top left, on the item icon", point = "TOPLEFT", frame = "icon", x = 1, y = -1, grow = 1 },
    bottomleft = { label = "Bottom left, on the item icon", point = "BOTTOMLEFT", frame = "icon", x = 1, y = 1, grow = 1 },
    topright = { label = "Top right of the row", point = "TOPRIGHT", x = -4, y = -4, grow = -1 },
    bottomright = { label = "Bottom right, next to the armor type", point = "RIGHT", frame = "armorType", relativePoint = "LEFT", x = -4, y = 0, grow = -1 },
}
local CORNER_ORDER = { "topleft", "topright", "bottomleft", "bottomright" }

JournalLoot.defaults = { allClasses = false, corner = "bottomright", size = 16 }

local classes
local cache = {}
local hooked, waiting = false, false

local function Options()
    return ns.db.journalLootOptions
end

local function BuildClasses()
    classes = {}
    for i = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(i)
        if info then
            local class = { id = info.classID, file = info.classFile, specs = {} }
            for j = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(info.classID) or 0 do
                local specID, _, _, icon, role = GetSpecializationInfoForClassID(info.classID, j)
                if specID then
                    table.insert(class.specs, { id = specID, role = role, icon = icon })
                end
            end
            table.insert(classes, class)
        end
    end
end

local function FilterClassID()
    local classID = EJ_GetLootFilter()
    if classID and classID ~= 0 then return classID end
    return select(3, UnitClass("player"))
end

local function ScannedClasses()
    if Options().allClasses then return classes end
    local classID = FilterClassID()
    for _, class in ipairs(classes) do
        if class.id == classID then return { class } end
    end
    return {}
end

local function CurrentKey()
    return table.concat({
        EncounterJournal.instanceID or 0,
        EncounterJournal.encounterID or 0,
        EJ_GetDifficulty() or 0,
        C_EncounterJournal.GetSlotFilter() or 0,
        EJ_GetNumLoot() or 0,
        Options().allClasses and "all" or FilterClassID(),
    }, ":")
end

local function Scan(scanned)
    local previousClass, previousSpec = EJ_GetLootFilter()
    local found = {}
    for _, class in ipairs(scanned) do
        for _, spec in ipairs(class.specs) do
            EJ_SetLootFilter(class.id, spec.id)
            for i = 1, EJ_GetNumLoot() or 0 do
                local info = C_EncounterJournal.GetLootInfoByIndex(i)
                if info and info.itemID then
                    found[info.itemID] = found[info.itemID] or {}
                    found[info.itemID][spec.id] = true
                end
            end
        end
    end
    EJ_SetLootFilter(previousClass, previousSpec)

    local entries = {}
    for itemID, specs in pairs(found) do
        entries[itemID] = Icons.For(specs, scanned, Options().allClasses)
    end
    return entries
end

local function SetEntry(texture, entry)
    if entry.kind == "role" then
        texture:SetAtlas(ROLE_ATLAS[entry.role])
    elseif entry.kind == "class" then
        texture:SetTexture(CLASS_CIRCLES)
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[entry.file]))
    else
        texture:SetTexture(entry.kind == "everyone" and EVERYONE_ICON or entry.icon)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function Place(texture, button, previous, size)
    texture:ClearAllPoints()
    texture:SetSize(size, size)
    local corner = CORNERS[Options().corner] or CORNERS[JournalLoot.defaults.corner]
    if previous then
        if corner.grow > 0 then
            texture:SetPoint("LEFT", previous, "RIGHT", 1, 0)
        else
            texture:SetPoint("RIGHT", previous, "LEFT", -1, 0)
        end
    else
        local relativeTo = corner.frame and button[corner.frame] or button
        texture:SetPoint(corner.point, relativeTo, corner.relativePoint or corner.point, corner.x, corner.y)
    end
end

local function Paint(button)
    local icons = button.ltSpecIcons
    local entries = ns.db.journalLoot and button.itemID and cache.key == CurrentKey()
        and cache.entries[button.itemID]
    local count = entries and #entries or 0

    if count > 0 and not icons then
        icons = {}
        button.ltSpecIcons = icons
    end

    local size = Options().size
    for i = 1, count do
        local texture = icons[i]
        if not texture then
            texture = button:CreateTexture(nil, "OVERLAY", nil, 7)
            icons[i] = texture
        end
        SetEntry(texture, entries[i])
        Place(texture, button, icons[i - 1], size)
        texture:Show()
    end

    for i = count + 1, icons and #icons or 0 do
        icons[i]:Hide()
    end
end

local function ScrollBox()
    return EncounterJournal.encounter.info.LootContainer.ScrollBox
end

local function Refresh()
    if ns.db.journalLoot and cache.key ~= CurrentKey() then
        cache.entries = Scan(ScannedClasses())
        cache.key = CurrentKey()
    end
    for _, button in ipairs(ScrollBox():GetFrames()) do
        Paint(button)
    end
end

local function Hook()
    if hooked then return end
    hooked = true
    hooksecurefunc("EncounterJournal_LootUpdate", Refresh)
    ScrollBox():RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, button)
        Paint(button)
    end, JournalLoot)
end

local function Repaint()
    cache.key = nil
    if hooked and EncounterJournal:IsShown() then
        Refresh()
    end
end

function JournalLoot.Pages(page)
    ns.db.journalLootOptions = ns.db.journalLootOptions or {}
    ns.ApplyDefaults(ns.db.journalLootOptions, JournalLoot.defaults)

    local category = page.category
    local function Proxy(key, varType, label)
        return Settings.RegisterProxySetting(category, "LT_journalLoot_" .. key, varType, label,
            JournalLoot.defaults[key],
            function() return Options()[key] end,
            function(value)
                Options()[key] = value
                Repaint()
            end)
    end

    ns.AddToPage(page, Settings.CreateCheckbox(category, Proxy("allClasses", Settings.VarType.Boolean, "All classes"),
        "Show every class's specs, folded into a class, role or everyone icon where they all get the item. Off shows the class picked in the journal's filter, or yours."))

    local function CornerOptions()
        local container = Settings.CreateControlTextContainer()
        for _, key in ipairs(CORNER_ORDER) do
            container:Add(key, CORNERS[key].label)
        end
        return container:GetData()
    end
    ns.AddToPage(page, Settings.CreateDropdown(category, Proxy("corner", Settings.VarType.String, "Position"),
        CornerOptions, "Where the icons sit on each loot row."))

    local sizeOptions = Settings.CreateSliderOptions(12, 24, 1)
    sizeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    ns.AddToPage(page, Settings.CreateSlider(category, Proxy("size", Settings.VarType.Number, "Icon size"),
        sizeOptions, "Icon size in pixels."))
end

function JournalLoot.Enable()
    if not classes then BuildClasses() end

    if C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
        Hook()
        Repaint()
        return
    end

    if waiting then return end
    waiting = true
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_EncounterJournal" then
            self:UnregisterEvent("ADDON_LOADED")
            Hook()
        end
    end)
end

function JournalLoot.OnSwitch(enabled)
    if enabled then
        JournalLoot.Enable()
    else
        Repaint()
    end
end

JournalLoot.key = "journalLoot"
ns.RegisterModule("JournalLoot", JournalLoot)
