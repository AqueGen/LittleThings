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
