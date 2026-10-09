local _, ns = ...

local Memory = {}

local TOP_ADDONS = 5
local PAUSE, STEP_MULTIPLIER = 110, 200
local CLEANUP_INTERVAL, CLEANUP_STEP, CLEANUP_SECONDS = 40, 128, 2

local original
local ticker, cleaningUntil, loading, loadingEvents

local function ApplyCollection()
    local wanted = ns.IsOn("performance") and ns.db.smoothGarbageCollection
    if wanted and not original then
        original = {
            pause = collectgarbage("setpause", PAUSE),
            stepMultiplier = collectgarbage("setstepmul", STEP_MULTIPLIER),
        }
    elseif not wanted and original then
        collectgarbage("setpause", original.pause)
        collectgarbage("setstepmul", original.stepMultiplier)
        original = nil
    end
end

local function CanClean()
    return not loading and not InCombatLockdown() and not IsInInstance()
end

local function CleanStep()
    if not cleaningUntil then
        return
    end
    if not CanClean() or GetTime() > cleaningUntil or collectgarbage("step", CLEANUP_STEP) then
        cleaningUntil = nil
        return
    end
    RunNextFrame(CleanStep)
end

local function StartCleanup()
    if cleaningUntil or not CanClean() then
        return
    end
    cleaningUntil = GetTime() + CLEANUP_SECONDS
    CleanStep()
end

local function ApplyCleanup()
    local wanted = ns.IsOn("performance") and ns.db.openWorldCleanup
    if wanted and not ticker then
        if not loadingEvents then
            loadingEvents = CreateFrame("Frame")
            loadingEvents:RegisterEvent("LOADING_SCREEN_ENABLED")
            loadingEvents:RegisterEvent("LOADING_SCREEN_DISABLED")
            loadingEvents:SetScript("OnEvent", function(_, event)
                loading = event == "LOADING_SCREEN_ENABLED"
            end)
        end
        ticker = C_Timer.NewTicker(CLEANUP_INTERVAL, StartCleanup)
    elseif not wanted and ticker then
        ticker:Cancel()
        ticker, cleaningUntil = nil, nil
    end
end

local function Apply()
    ApplyCollection()
    ApplyCleanup()
end

local function Megabytes(kilobytes)
    return ("%.1f MB"):format(kilobytes / 1024)
end

local function PrintTopAddOns()
    UpdateAddOnMemoryUsage()
    local usage = {}
    for index = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(index) then
            usage[#usage + 1] = { name = C_AddOns.GetAddOnInfo(index), kilobytes = GetAddOnMemoryUsage(index) }
        end
    end
    table.sort(usage, function(a, b) return a.kilobytes > b.kilobytes end)
    for rank = 1, math.min(TOP_ADDONS, #usage) do
        ns.Print(("%d. %s - %s"):format(rank, usage[rank].name, Megabytes(usage[rank].kilobytes)))
    end
end

local function CollectGarbage()
    if InCombatLockdown() then
        ns.Print("garbage is not collected in combat, the game would stall mid-fight")
        return
    end
    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    ns.Print(("Lua memory %s > %s, freed %s. Largest addons now:"):format(
        Megabytes(before), Megabytes(after), Megabytes(before - after)))
    PrintTopAddOns()
end

function Memory.Pages(page)
    local group = page:Group("Memory")
    group:Check({ label = "Smoother garbage collection",
        tooltip = "The game frees addon memory in one large pass after it has doubled, which shows as a hitch. This starts a pass after 10% growth instead, so the work is spread over many small steps. Off returns the game's own values.",
        get = function() return ns.db.smoothGarbageCollection end,
        set = function(value)
            ns.db.smoothGarbageCollection = value
            ApplyCollection()
        end })
    group:Check({ label = "Clean up in the open world",
        tooltip = ("Every %d seconds, frees thrown-away memory in small steps over up to %d seconds, so less is left for the game to collect later. Only outside instances, never in combat or on a loading screen."):format(CLEANUP_INTERVAL, CLEANUP_SECONDS),
        get = function() return ns.db.openWorldCleanup end,
        set = function(value)
            ns.db.openWorldCleanup = value
            ApplyCleanup()
        end })
    group:Button({ label = "Collect garbage", text = "Collect garbage", combatLocked = true, onClick = CollectGarbage,
        tooltip = "Frees the memory addons have thrown away and prints how much that was, and the five addons holding the most after it. The game stalls for a moment while it runs and gains no frames: most of what an addon shows before a collection is garbage the game frees on its own." })
end

Memory.Enable = Apply
Memory.OnSwitch = Apply

Memory.key = "performance"
ns.RegisterModule("Memory", Memory)
