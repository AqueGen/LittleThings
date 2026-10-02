local addonName, ns = ...

local Data = ns.ApplicantData

local Pipeline = {}

local steps = {}
local hooked = false

local function Run(applicants)
    if type(applicants) ~= "table" or issecretvalue(applicants) then return end
    for _, step in ipairs(steps) do
        step(applicants)
    end
end

function Pipeline.Add(run)
    steps[#steps + 1] = run
    if not hooked then
        hooked = true
        hooksecurefunc("LFGListUtil_SortApplicants", Run)
    end
end

function Pipeline.Refresh()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
    if viewer and viewer:IsVisible() and not Data.Locked() then
        C_LFGList.RefreshApplicants()
    end
end

ns.ApplicantPipeline = Pipeline
