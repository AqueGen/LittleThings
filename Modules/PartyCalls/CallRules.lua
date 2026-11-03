-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local _, ns = ...

local Rules = {}

Rules.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
Rules.MAX_BYTES = 255
Rules.GLOBAL_COOLDOWN = 3
Rules.CALL_COOLDOWN = 5

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
for _, call in ipairs(Rules.BUILTIN) do
    defaults[call.id] = call
end
local CUSTOM = Call(nil, "", "", "", 0, nil, "any", "group")

function Rules.IsBuiltin(id)
    return defaults[id] ~= nil
end

local function IsCustom(id)
    return type(id) == "string" and id:match("^c%d+$") ~= nil
end

local function FillOne(call, default)
    for _, key in ipairs(FIELDS) do
        if call[key] == nil then
            call[key] = default[key]
        end
    end
    call.roles = call.roles or {}
    for role, on in pairs(default.roles) do
        if call.roles[role] == nil then
            call.roles[role] = on
        end
    end
    return call
end

function Rules.Fill(db)
    local calls = db.calls or {}
    for id in pairs(calls) do
        if not defaults[id] and not IsCustom(id) then
            calls[id] = nil
        end
    end
    for id, default in pairs(defaults) do
        calls[id] = FillOne(calls[id] or {}, default)
        calls[id].id = id
    end
    for id, call in pairs(calls) do
        if IsCustom(id) then
            FillOne(call, CUSTOM).id = id
        end
    end
    local order, seen = {}, {}
    for _, id in ipairs(db.order or {}) do
        if calls[id] and not seen[id] then
            order[#order + 1], seen[id] = id, true
        end
    end
    for _, call in ipairs(Rules.BUILTIN) do
        if not seen[call.id] then
            order[#order + 1], seen[call.id] = call.id, true
        end
    end
    for id in pairs(calls) do
        if not seen[id] then
            order[#order + 1] = id
        end
    end
    db.calls, db.order = calls, order
    return db
end

function Rules.Reset(calls, id)
    calls[id] = FillOne({}, defaults[id])
    calls[id].id = id
end

function Rules.AddCustom(db)
    db.nextCustom = (db.nextCustom or 0) + 1
    local id = "c" .. db.nextCustom
    db.calls[id] = FillOne({}, CUSTOM)
    db.calls[id].id = id
    db.order[#db.order + 1] = id
    return id
end

local function IndexOf(order, id)
    for i, value in ipairs(order) do
        if value == id then
            return i
        end
    end
end

function Rules.Remove(db, id)
    local index = IndexOf(db.order, id)
    if not IsCustom(id) or not index then
        return false
    end
    table.remove(db.order, index)
    db.calls[id] = nil
    return true
end

function Rules.Move(db, id, delta)
    local from = IndexOf(db.order, id)
    local to = from and from + delta
    if not to or to < 1 or to > #db.order then
        return false
    end
    db.order[from], db.order[to] = db.order[to], db.order[from]
    return true
end

local HORIZONTAL = { right = true, left = true }

function Rules.Grid(count, o)
    local grow = o.grow or "right"
    local horizontal = HORIZONTAL[grow] or false
    local wrap = o.wrap
    if horizontal == (HORIZONTAL[wrap] or false) or not wrap then
        wrap = horizontal and "down" or "right"
    end
    local perRow = math.max(1, o.perRow or 1)
    local hDir = horizontal and grow or wrap
    local vDir = horizontal and wrap or grow
    local anchor = (vDir == "up" and "BOTTOM" or "TOP") .. (hDir == "left" and "RIGHT" or "LEFT")
    local xs, ys = hDir == "left" and -1 or 1, vDir == "up" and 1 or -1
    local stepW, stepH = o.cellW + o.gap, o.cellH + o.gap
    local cells = {}
    for i = 0, count - 1 do
        local along, across = i % perRow, math.floor(i / perRow)
        local col, row = along, across
        if not horizontal then
            col, row = across, along
        end
        cells[i + 1] = { x = xs * (o.pad + col * stepW), y = ys * (o.pad + row * stepH) }
    end
    local n = math.max(count, 1)
    local alongN, acrossN = math.min(n, perRow), math.ceil(n / perRow)
    local cols, rows = alongN, acrossN
    if not horizontal then
        cols, rows = acrossN, alongN
    end
    return cells, cols * stepW - o.gap + 2 * o.pad, rows * stepH - o.gap + 2 * o.pad, anchor
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

function Rules.Texture(icon, spellTexture, fileId)
    local id = type(icon) == "number" and icon or type(icon) == "string" and icon:match("^%s*(%d+)%s*$")
    if id then
        return spellTexture(tonumber(id)) or Rules.QUESTION
    end
    if type(icon) == "string" and icon:find("[\\/]") and fileId(icon) then
        return icon
    end
    return Rules.QUESTION
end

if ns then ns.CallRules = Rules end
return Rules
