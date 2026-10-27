local _, ns = ...

local Rules = {}

function Rules.Grid(count, columns, cellWidth, rowHeight)
    local cells = {}
    for i = 1, count do
        cells[i] = { x = ((i - 1) % columns) * cellWidth, y = math.floor((i - 1) / columns) * rowHeight }
    end
    return cells, math.ceil(count / columns) * rowHeight
end

function Rules.Stack(items, gap)
    local offsets, y, any = {}, 0, false
    for index, item in ipairs(items) do
        if item.shown ~= false then
            offsets[index] = y
            y = y + item.height + gap
            any = true
        end
    end
    return offsets, any and (y - gap) or 0
end

function Rules.Known(options, value, default)
    for _, option in ipairs(options) do
        if option.value == value then
            return value
        end
    end
    return default
end

function Rules.Size(savedW, savedH, minW, minH, defaultW, defaultH)
    return math.max(savedW or defaultW, minW), math.max(savedH or defaultH, minH)
end

if ns then ns.WidgetRules = Rules end
return Rules
