-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local _, ns = ...

local MenuModel = {}

local function HasChild(modules, key)
    for _, row in ipairs(modules) do
        if row.parent == key then return true end
    end
    return false
end

function MenuModel.Build(modules, extras, isOn, hasPage)
    local groups, byTitle = {}, {}
    for _, row in ipairs(modules) do
        if not row.parent then
            local group = byTitle[row.group]
            if not group then
                group = { title = row.group, entries = {}, switches = {} }
                byTitle[row.group] = group
                groups[#groups + 1] = group
            end
            local own = HasChild(modules, row.key) or not hasPage or hasPage(row.key)
            for _, extra in ipairs(extras) do
                if extra.after == row.key then own = true end
            end
            if own then
                group.entries[#group.entries + 1] = { key = row.key, label = row.label, on = isOn(row.key) == true }
                for _, extra in ipairs(extras) do
                    if extra.after == row.key then
                        group.entries[#group.entries + 1] = { key = extra.key, label = extra.label, on = isOn(extra.key) == true }
                    end
                end
            else
                group.switches[#group.switches + 1] = row.key
            end
        end
    end
    for _, group in ipairs(groups) do
        group.page = #group.switches > 0 and MenuModel.GroupKey(group.title) or nil
    end
    return groups
end

function MenuModel.GroupKey(title)
    return "group:" .. title
end

if ns then ns.MenuModel = MenuModel end
return MenuModel
