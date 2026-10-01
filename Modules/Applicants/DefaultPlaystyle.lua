local addonName, ns = ...

local DefaultPlaystyle = {}

local STYLES = { "Learning", "FunRelaxed", "FunSerious", "Expert" }

DefaultPlaystyle.defaults = { style = "FunSerious", preferMythicPlus = true, partyKeys = true }

local hooked = false

local function Options()
    return ns.db.defaultPlaystyleOptions
end

DefaultPlaystyle.Options = Options

local function Pick(creation)
    if not ns.IsOn("defaultPlaystyle") then return end
    local style = Enum.LFGEntryGeneralPlaystyle[Options().style]
    if not style or not creation.PlayStyleDropdown:IsShown() then return end
    if creation.generalPlaystyle ~= Enum.LFGEntryGeneralPlaystyle.None then return end
    LFGListEntryCreation_OnPlayStyleSelectedInternal(creation, style)
    creation.PlayStyleDropdown:GenerateMenu()
end

function DefaultPlaystyle.Select(creation, categoryID, groupID, activityID)
    pcall(LFGListEntryCreation_Select, creation, creation.selectedFilters, categoryID, groupID, activityID)
end

local function PreferMythicPlus(creation, _, _, groupID, activityID)
    if not ns.IsOn("defaultPlaystyle") or not Options().preferMythicPlus then return end
    if not groupID or activityID or not creation.selectedActivity then return end
    local current = C_LFGList.GetActivityInfoTable(creation.selectedActivity)
    if not current or current.isMythicPlusActivity then return end
    for _, candidate in ipairs(C_LFGList.GetAvailableActivities(creation.selectedCategory, groupID) or {}) do
        local info = C_LFGList.GetActivityInfoTable(candidate)
        if info and info.isMythicPlusActivity then
            DefaultPlaystyle.Select(creation, creation.selectedCategory, groupID, candidate)
            return
        end
    end
end

local BLOCKABLE = { "SetEntryTitle", "CreateListing", "UpdateListing" }

local function OnBlocked(_, _, blockedAddon, blockedFunction)
    if not ns.IsOn("defaultPlaystyle") or blockedAddon ~= addonName or type(blockedFunction) ~= "string" then return end
    for _, name in ipairs(BLOCKABLE) do
        if blockedFunction:find(name, 1, true) then
            ns.SetSwitch("defaultPlaystyle", false)
            ns.Print("the game blocked " .. name .. " after the group creation helpers changed the screen, so they are now off. Fill it in by hand, and /reload to clear the block.")
            return
        end
    end
end

function DefaultPlaystyle.Pages(page)
    ns.db.defaultPlaystyleOptions = ns.db.defaultPlaystyleOptions or {}
    ns.ApplyDefaults(ns.db.defaultPlaystyleOptions, DefaultPlaystyle.defaults)

    local setting = Settings.RegisterProxySetting(page.category, "LT_defaultPlaystyle_style", Settings.VarType.String,
        "Playstyle", DefaultPlaystyle.defaults.style,
        function() return Options().style end,
        function(value) Options().style = value end)

    local function StyleOptions()
        local container = Settings.CreateControlTextContainer()
        for index, key in ipairs(STYLES) do
            container:Add(key, _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. index] or key)
        end
        return container:GetData()
    end

    ns.AddToPage(page, Settings.CreateDropdown(page.category, setting, StyleOptions,
        "The playstyle already picked when you create a listing. You can still change it before listing."))

    local function Checkbox(key, label, tooltip)
        local check = Settings.RegisterProxySetting(page.category, "LT_defaultPlaystyle_" .. key, Settings.VarType.Boolean,
            label, DefaultPlaystyle.defaults[key],
            function() return Options()[key] end,
            function(value) Options()[key] = value end)
        ns.AddToPage(page, Settings.CreateCheckbox(page.category, check, tooltip))
    end

    Checkbox("preferMythicPlus", "Pick Mythic+ when you choose a dungeon",
        "Choosing a dungeon picks its Mythic Keystone difficulty instead of plain Mythic, so listing someone else's key needs no extra click. Picking Mythic yourself afterwards is left alone.")
end

function DefaultPlaystyle.Enable()
    if hooked then return end
    hooked = true
    hooksecurefunc("LFGListEntryCreation_Show", Pick)
    hooksecurefunc("LFGListEntryCreation_Select", PreferMythicPlus)

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_ACTION_BLOCKED")
    events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    events:SetScript("OnEvent", OnBlocked)
end

function DefaultPlaystyle.OnSwitch(on)
    if on then DefaultPlaystyle.Enable() end
end

DefaultPlaystyle.key = "defaultPlaystyle"
ns.DefaultPlaystyle = DefaultPlaystyle
ns.RegisterModule("DefaultPlaystyle", DefaultPlaystyle)
