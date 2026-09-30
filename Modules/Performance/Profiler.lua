local _, ns = ...

local Profiler = {}

local TOP = 5

local REPORTS = {
    { metric = "SessionAverageTime", heading = "Average per frame since login", unit = "%.2f ms" },
    { metric = "PeakTime", heading = "Slowest single frame", unit = "%.0f ms" },
    { metric = "CountTimeOver50Ms", heading = "Frames over 50 ms (hitches)", unit = "%d" },
}

local function PrintReport(report)
    local lines = {}
    for _, result in ipairs(C_AddOnProfiler.GetTopKAddOnsForMetric(Enum.AddOnProfilerMetric[report.metric], TOP)) do
        if result.metricValue > 0 then
            lines[#lines + 1] = ("%s " .. report.unit):format(result.addOnName, result.metricValue)
        end
    end
    ns.Print(report.heading .. ": " .. (#lines > 0 and table.concat(lines, ", ") or "none"))
end

local function ShowAddOnCPU()
    if not C_AddOnProfiler.IsEnabled() then
        ns.Print("the game's addon profiler is switched off, there is nothing to show")
        return
    end
    for _, report in ipairs(REPORTS) do
        PrintReport(report)
    end
end

function Profiler.Pages(page)
    ns.AddHeader(page, "Addons")
    local button = CreateSettingsButtonInitializer("Show addon CPU", "Show addon CPU", ShowAddOnCPU,
        "Prints the game's own measurements of every addon since login: the five that cost the most time per frame on average, the five with the slowest single frame, and the ones that took over 50 ms in a frame, which shows as a hitch, with how many times.", true)
    page.layout:AddInitializer(button)
    ns.AddToPage(page, button)
end

Profiler.key = "performance"
ns.RegisterModule("Profiler", Profiler)
