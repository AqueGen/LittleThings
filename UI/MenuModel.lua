local _, ns = ...

local MenuModel = {}

function MenuModel.Build(modules, extras, isOn)
    local groups, byTitle = {}, {}
    for _, row in ipairs(modules) do
        if not row.parent then
            local group = byTitle[row.group]
            if not group then
                group = { title = row.group, entries = {} }
                byTitle[row.group] = group
                groups[#groups + 1] = group
            end
            group.entries[#group.entries + 1] = { key = row.key, label = row.label, on = isOn(row.key) == true }
            for _, extra in ipairs(extras) do
                if extra.after == row.key then
                    group.entries[#group.entries + 1] = { key = extra.key, label = extra.label, on = isOn(extra.key) == true }
                end
            end
        end
    end
    return groups
end

if ns then ns.MenuModel = MenuModel end
return MenuModel
