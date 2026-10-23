local _, ns = ...

local Rules = {}

function Rules.Visible(s)
    if s.preview then return true end
    if not s.inGroup then return s.showSolo == true end
    if s.inRaid then return s.raidWithoutRank == true or s.leader == true or s.assistant == true end
    return not s.partyLeaderOnly or s.leader == true
end

function Rules.CanMark(s)
    return (s.inGroup and (s.leader or (s.inRaid and s.assistant))) == true
end

function Rules.GroupActionBlock(s, action)
    if not s.inGroup then return "Not in a group" end
    if not Rules.CanMark(s) then return "Leader or assistant only" end
    if s.combat then return "Not in combat" end
    if s.lockdown then return "Blocked while the game restricts chat (combat, encounter or active key)" end
    if action == "role" and s.lfg then return "Not in a Group Finder group" end
    return nil
end

function Rules.PullSeconds(db, button)
    local left = button == "LeftButton"
    local value
    if left then value = db.pullLeft else value = db.pullRight end
    if type(value) ~= "number" then return left and 10 or 5 end
    return math.min(60, math.max(3, math.floor(value)))
end

function Rules.ReadyTally(statuses, finished)
    local ready, total, notReady, waiting = 0, 0, false, false
    for _, status in ipairs(statuses) do
        if status ~= "unknown" then
            total = total + 1
            if status == "ready" then ready = ready + 1
            elseif status == "notready" then notReady = true
            elseif status == "waiting" then waiting = true end
        end
    end
    local state = "waiting"
    if notReady or (finished and waiting) then state = "notready"
    elseif total > 0 and ready == total then state = "ready" end
    return state, ready, total
end

function Rules.ReadyLabel(ready, total)
    if total == 0 then return "Ready" end
    return "Ready " .. ready .. "/" .. total
end

function Rules.TipSide(left, bottom, right, top, screenW, screenH, vertical)
    if vertical then
        return screenW - right >= left and "right" or "left"
    end
    return bottom >= screenH - top and "below" or "above"
end

function Rules.Cycle(order)
    local cycle = {}
    for i = 1, 8 do
        local marker = order[i]
        if type(marker) == "number" and marker >= 1 and marker <= 8 and marker % 1 == 0 then
            cycle[#cycle + 1] = marker
        end
    end
    return cycle
end

if ns then ns.MarkerRules = Rules end
return Rules
