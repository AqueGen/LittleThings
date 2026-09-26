local addonName, ns = ...

local DefaultPlaystyle = {}

local STYLES = { "Learning", "FunRelaxed", "FunSerious", "Expert" }

DefaultPlaystyle.defaults = { style = "FunSerious" }

local hooked = false
local picked = false

local function Options()
    return ns.db.defaultPlaystyleOptions
end

local function Pick(creation)
    if not ns.db.defaultPlaystyle then return end
    local style = Enum.LFGEntryGeneralPlaystyle[Options().style]
    if not style or not creation.PlayStyleDropdown:IsShown() then return end
    if creation.generalPlaystyle ~= Enum.LFGEntryGeneralPlaystyle.None then return end
    LFGListEntryCreation_OnPlayStyleSelectedInternal(creation, style)
    creation.PlayStyleDropdown:GenerateMenu()
    picked = true
end

local function OnBlocked(_, _, blockedAddon, blockedFunction)
    if not picked or blockedAddon ~= addonName then return end
    if type(blockedFunction) ~= "string" or not blockedFunction:find("CreateListing", 1, true) then return end
    ns.db.defaultPlaystyle = false
    ns.Print("the game blocked listing the group after the playstyle was picked for you, so the default playstyle is now off. Pick it by hand, and /reload to clear the block.")
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
        for _, key in ipairs(STYLES) do
            local value = Enum.LFGEntryGeneralPlaystyle[key]
            container:Add(key, value and GetGeneralPlaystyleString(value) or key)
        end
        return container:GetData()
    end

    ns.AddToPage(page, Settings.CreateDropdown(page.category, setting, StyleOptions,
        "The playstyle already picked when you create a Mythic+ listing. You can still change it before listing."))
end

function DefaultPlaystyle.Enable()
    if hooked then return end
    hooked = true
    hooksecurefunc("LFGListEntryCreation_Show", Pick)

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_ACTION_BLOCKED")
    events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    events:SetScript("OnEvent", OnBlocked)
end

function DefaultPlaystyle.OnSwitch(on)
    if on then DefaultPlaystyle.Enable() end
end

DefaultPlaystyle.key = "defaultPlaystyle"
ns.RegisterModule("DefaultPlaystyle", DefaultPlaystyle)
