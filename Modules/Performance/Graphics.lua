local _, ns = ...

local Preset = ns.GraphicsPreset

local Graphics = {}

local LOW_TO_ULTRA_HIGH = { [0] = VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_FAIR, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH, VIDEO_OPTIONS_ULTRA, VIDEO_OPTIONS_ULTRA_HIGH }
local LOW_TO_HIGH = { [0] = VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_FAIR, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH }
local OFF_TO_ULTRA_FAIR = { [0] = VIDEO_OPTIONS_DISABLED, VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_FAIR, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH, VIDEO_OPTIONS_ULTRA }
local OFF_TO_ULTRA = { [0] = VIDEO_OPTIONS_DISABLED, VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH, VIDEO_OPTIONS_ULTRA }
local OFF_TO_HIGH = { [0] = VIDEO_OPTIONS_DISABLED, VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH }
local OFF_ON = { [0] = VIDEO_OPTIONS_DISABLED, VIDEO_OPTIONS_ENABLED }

local TARGETS = {
    { cvar = "graphicsShadowQuality", value = "1", label = SHADOW_QUALITY, names = LOW_TO_ULTRA_HIGH },
    { cvar = "graphicsLiquidDetail", value = "0", label = LIQUID_DETAIL, names = LOW_TO_HIGH },
    { cvar = "graphicsParticleDensity", value = "5", label = PARTICLE_DENSITY, names = OFF_TO_ULTRA_FAIR },
    { cvar = "graphicsSSAO", value = "0", label = SSAO_LABEL, names = OFF_TO_ULTRA },
    { cvar = "graphicsDepthEffects", value = "0", label = DEPTH_EFFECTS, names = OFF_TO_HIGH },
    { cvar = "graphicsComputeEffects", value = "0", label = COMPUTE_EFFECTS, names = OFF_TO_ULTRA },
    { cvar = "graphicsOutlineMode", value = "0", label = OUTLINE_MODE, names = { [0] = VIDEO_OPTIONS_DISABLED, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH } },
    { cvar = "graphicsTextureResolution", value = "2", label = TEXTURE_DETAIL, names = { [0] = VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_FAIR, VIDEO_OPTIONS_HIGH } },
    { cvar = "graphicsSpellDensity", value = "0", label = SPELL_DENSITY, names = { [0] = VIDEO_OPTIONS_SFX_DENSITY_MIN, VIDEO_OPTIONS_SFX_DENSITY_REDUCED, VIDEO_OPTIONS_SFX_DENSITY_FULL } },
    { cvar = "graphicsProjectedTextures", value = "1", label = PROJECTED_TEXTURES, names = OFF_ON },
    { cvar = "graphicsViewDistance", value = "0", label = FARCLIP, slider = true },
    { cvar = "graphicsEnvironmentDetail", value = "0", label = ENVIRONMENT_DETAIL, slider = true },
    { cvar = "graphicsGroundClutter", value = "0", label = GROUND_CLUTTER, slider = true },
    { cvar = "RAIDsettingsEnabled", value = "0", label = "Separate raid and battleground settings", names = OFF_ON },
    { cvar = "ResampleAlwaysSharpen", value = "1", label = "Always sharpen the image", names = OFF_ON },
}

local byCvar = {}
for _, target in ipairs(TARGETS) do
    byCvar[target.cvar] = target
end

local function Name(target, value)
    local number = tonumber(value)
    if target.slider and number then
        return tostring(number + 1)
    end
    return target.names and number and target.names[number] or value
end

local function Describe(heading, changes)
    local lines = { heading, "" }
    for _, change in ipairs(changes) do
        local target = byCvar[change.cvar]
        lines[#lines + 1] = ("%s: %s > %s"):format(target.label, Name(target, change.from), Name(target, change.to))
    end
    return table.concat(lines, "\n")
end

local function Apply(changes)
    local refused = {}
    for _, change in ipairs(changes) do
        if not C_CVar.SetCVar(change.cvar, change.to) then
            refused[#refused + 1] = byCvar[change.cvar].label
        end
    end
    if #refused > 0 then
        ns.Print("the game refused to change: " .. table.concat(refused, ", "))
    end
end

StaticPopupDialogs["LITTLETHINGS_GRAPHICS"] = {
    text = "%s",
    button1 = "Apply",
    button2 = CANCEL,
    OnAccept = function(_, apply)
        if InCombatLockdown() then
            ns.Print("graphics settings cannot be changed in combat")
            return
        end
        apply()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Confirm(heading, changes, apply)
    if InCombatLockdown() then
        ns.Print("graphics settings cannot be changed in combat")
        return
    end
    StaticPopup_Show("LITTLETHINGS_GRAPHICS", Describe(heading, changes), nil, apply)
end

local function Optimize()
    local changes = Preset.Changes(TARGETS, C_CVar.GetCVar)
    if #changes == 0 then
        ns.Print("graphics settings are already optimized")
        return
    end
    Confirm("LittleThings will change:", changes, function()
        ns.db.graphicsBackup = Preset.Remember(ns.db.graphicsBackup, TARGETS, C_CVar.GetCVar)
        Apply(changes)
    end)
end

local function Restore()
    local changes = Preset.Restores(ns.db.graphicsBackup, TARGETS, C_CVar.GetCVar)
    if #changes == 0 then
        ns.db.graphicsBackup = nil
        ns.Print("nothing to restore")
        return
    end
    Confirm("LittleThings will restore your settings:", changes, function()
        Apply(changes)
        ns.db.graphicsBackup = nil
    end)
end

local function AddButton(page, name, text, onClick, tooltip)
    local initializer = CreateSettingsButtonInitializer(name, text, onClick, tooltip, true)
    page.layout:AddInitializer(initializer)
    ns.AddToPage(page, initializer)
end

function Graphics.Pages(page)
    ns.AddHeader(page, "Graphics")
    AddButton(page, "Optimize graphics", "Optimize my FPS", Optimize,
        "Lowers the settings that cost the most frames and matter least in combat: shadows, ambient occlusion, depth and compute effects, view distance, environment detail and ground clutter. Textures stay high and particles stay at Ultra so spell effects remain readable. A window lists every change before it is made.")
    AddButton(page, "Restore graphics", "Restore my settings", Restore,
        "Puts back the values these settings had before the first Optimize, after showing what will change.")
end

Graphics.key = "performance"
ns.RegisterModule("Graphics", Graphics)
