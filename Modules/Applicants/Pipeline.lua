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
