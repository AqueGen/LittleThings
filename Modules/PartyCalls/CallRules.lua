-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local _, ns = ...

local Rules = {}

Rules.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
Rules.MAX_BYTES = 255
Rules.GLOBAL_COOLDOWN = 3
Rules.CALL_COOLDOWN = 5
Rules.CUSTOM_SLOTS = 6

local ALL = { TANK = true, HEALER = true, DAMAGER = true }
local FIELDS = { "enabled", "label", "message", "icon", "mark", "combat", "content", "desaturate" }

local function Call(id, label, message, icon, mark, roles, combat, content)
    return { id = id, enabled = true, label = label, message = message, icon = icon, mark = mark,
        roles = roles or ALL, combat = combat or "any", content = content or "dungeon" }
end

Rules.BUILTIN = {
    Call("lust", "Lust", "LUST NOW", 2825, 7),
    Call("lustNext", "Lust next", "Lust on NEXT pack, hold CDs", 2825, 2),
    Call("save", "Save me", "I need an external NOW", 6940, 6, { TANK = true, HEALER = false, DAMAGER = true }),
    Call("oom", "OOM", "OOM, wait for mana before next pull", "Interface\\Icons\\INV_Drink_07", 5,
        { TANK = false, HEALER = true, DAMAGER = false }),
    Call("holdCds", "Hold CDs", "Hold CDs for the boss", "Interface\\Icons\\Spell_Holy_BorrowedTime", 3),
    Call("skip", "Skip", "Skip next pack, don't pull", 114018, 4, nil, "out", "mplus"),
    Call("wipe", "Wipe", "Wipe it, save CDs", "Interface\\Icons\\Ability_Creature_Cursed_02", 8, nil, "in"),
    Call("brb", "BRB", "BRB 1 min", "Interface\\Icons\\INV_Misc_PocketWatch_01", 1, nil, "out", "group"),
}
Rules.BUILTIN[2].desaturate = true

local defaults = {}
local order = {}
for _, call in ipairs(Rules.BUILTIN) do
    defaults[call.id] = call
    order[#order + 1] = call.id
end
for n = 1, Rules.CUSTOM_SLOTS do
    local id = "custom" .. n
    defaults[id] = Call(id, "", "", "", 0, nil, "any", "group")
    defaults[id].enabled = false
    order[#order + 1] = id
end

function Rules.Order()
    return order
end

function Rules.IsBuiltin(id)
    return not id:find("^custom")
end

local function FillOne(call, default)
    for _, key in ipairs(FIELDS) do
        if call[key] == nil then
            call[key] = default[key]
        end
    end
    call.id = default.id
    call.roles = call.roles or {}
    for role, on in pairs(default.roles) do
        if call.roles[role] == nil then
            call.roles[role] = on
        end
    end
    return call
end

function Rules.Fill(calls)
    for _, id in ipairs(order) do
        calls[id] = FillOne(calls[id] or {}, defaults[id])
    end
    return calls
end

function Rules.Reset(calls, id)
    calls[id] = FillOne({}, defaults[id])
end

local function Cut(text)
    if #text <= Rules.MAX_BYTES then
        return text
    end
    text = text:sub(1, Rules.MAX_BYTES)
    local i = #text
    while i > 0 and text:byte(i) >= 0x80 and text:byte(i) < 0xC0 do
        i = i - 1
    end
    local lead = text:byte(i)
    if lead and lead >= 0xC0 then
        local size = lead >= 0xF0 and 4 or lead >= 0xE0 and 3 or 2
        if #text - i + 1 < size then
            text = text:sub(1, i - 1)
        end
    end
    return text
end

function Rules.Text(call)
    local message = (call.message or ""):match("^%s*(.-)%s*$")
    if message == "" then
        return nil
    end
    local mark = tonumber(call.mark) or 0
    if mark >= 1 and mark <= 8 then
        message = "{rt" .. mark .. "} " .. message
    end
    return Cut(message)
end

function Rules.Role(specRole)
    if specRole == "TANK" or specRole == "HEALER" then
        return specRole
    end
    return "DAMAGER"
end

function Rules.Visible(call, state)
    if not call.enabled or not Rules.Text(call) or not call.roles[state.role] then
        return false
    end
    if call.combat == "in" and not state.combat or call.combat == "out" and state.combat then
        return false
    end
    if call.content == "dungeon" and not state.dungeon or call.content == "mplus" and not state.mplus then
        return false
    end
    return true
end

function Rules.PanelShown(state)
    return state.preview or (state.party and not state.raid and state.anyVisible) or false
end

function Rules.Remaining(now, lastAny, lastById, id)
    local left = 0
    if lastAny then
        left = math.max(left, Rules.GLOBAL_COOLDOWN - (now - lastAny))
    end
    if lastById[id] then
        left = math.max(left, Rules.CALL_COOLDOWN - (now - lastById[id]))
    end
    return left
end

function Rules.ClickPath(mode, inCombat)
    if mode == "chat" or mode == "chatInCombat" and inCombat then
        return "chat"
    end
    return "send"
end

function Rules.Texture(icon, spellTexture)
    local id = type(icon) == "number" and icon or type(icon) == "string" and icon:match("^%s*(%d+)%s*$")
    if id then
        return spellTexture(tonumber(id)) or Rules.QUESTION
    end
    if type(icon) == "string" and icon:find("[\\/]") then
        return icon
    end
    return Rules.QUESTION
end

if ns then ns.CallRules = Rules end
return Rules
