local _, ns = ...

local Data = {
    [48792] = { dr = 30, name = "Icebound Fortitude" },
    [194679] = { dr = 20, name = "Rune Tap" },
    [212800] = { dr = 25, name = "Blur" },
    [196555] = { dr = 100, name = "Netherwalk" },
    [22812] = { dr = 20, name = "Barkskin" },
    [102342] = { dr = 20, name = "Ironbark" },
    [200851] = { dr = 20, name = "Rage of the Sleeper" },
    [61336] = { dr = 50, name = "Survival Instincts" },
    [363916] = { dr = 30, name = "Obsidian Scales" },
    [357170] = { dr = 50, name = "Time Dilation" },
    [186265] = { dr = 30, name = "Aspect of the Turtle" },
    [264735] = { dr = 30, name = "Survival of the Fittest" },
    [45438] = { dr = 100, name = "Ice Block" },
    [414658] = { dr = 70, name = "Ice Cold" },
    [122278] = { dr = 20, name = "Dampen Harm" },
    [115176] = { dr = 60, name = "Zen Meditation" },
    [31850] = { dr = 30, name = "Ardent Defender" },
    [6940] = { dr = 30, name = "Blessing of Sacrifice" },
    [498] = { dr = 20, name = "Divine Protection" },
    [403876] = { dr = 20, name = "Divine Protection" },
    [642] = { dr = 100, name = "Divine Shield" },
    [86659] = { dr = 50, name = "Guardian of Ancient Kings" },
    [389539] = { dr = 30, name = "Sentinel", perStack = 2, maxStacks = 15 },
    [47585] = { dr = 75, name = "Dispersion" },
    [33206] = { dr = 40, name = "Pain Suppression" },
    [108271] = { dr = 40, name = "Astral Shift" },
    [104773] = { dr = 25, name = "Unending Resolve" },
    [118038] = { dr = 30, name = "Die by the Sword" },
    [184364] = { dr = 30, name = "Enraged Regeneration" },
    [871] = { dr = 40, name = "Shield Wall" },
}

if ns then ns.SaveData = Data end
return Data
