local _, ns = ...

local Memory = {}

local TOP_ADDONS = 5
local PAUSE, STEP_MULTIPLIER = 110, 200

local original

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
    local category = page.category

    ns.AddHeader(page, "Memory")

    local smooth = Settings.RegisterProxySetting(category, "LT_smoothGarbageCollection", Settings.VarType.Boolean,
        "Smoother garbage collection", true,
        function() return ns.db.smoothGarbageCollection end,
        function(value)
            ns.db.smoothGarbageCollection = value
            ApplyCollection()
        end)
    ns.AddToPage(page, Settings.CreateCheckbox(category, smooth,
        "The game frees addon memory in one large pass after it has doubled, which shows as a hitch. This starts a pass after 10% growth instead, so the work is spread over many small steps. Off returns the game's own values."))

    local button = CreateSettingsButtonInitializer("Collect garbage", "Collect garbage", CollectGarbage,
        "Frees the memory addons have thrown away and prints how much that was, and the five addons holding the most after it. The game stalls for a moment while it runs and gains no frames: most of what an addon shows before a collection is garbage the game frees on its own.", true)
    page.layout:AddInitializer(button)
    ns.AddToPage(page, button)
end

function Memory.Enable()
    ApplyCollection()
end

function Memory.OnSwitch()
    ApplyCollection()
end

Memory.key = "performance"
ns.RegisterModule("Memory", Memory)
