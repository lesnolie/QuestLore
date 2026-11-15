local _, ns = ...
local API = {}
ns.API = API
local log = C_QuestLog or {}
local super = C_SuperTrack or {}

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    -- Never compare or persist a secret value from the modern client.
    if issecretvalue and (issecretvalue(a) or issecretvalue(b)) then return nil end
    return a, b
end
API.Call = call

local function id(value)
    if type(value) == "number" and value > 0 then return value end
    return nil
end

function API.isActive(questID)
    if not id(questID) then return false end
    local index = call(log.GetLogIndexForQuestID, questID)
    return type(index) == "number" and index > 0
end

function API.isLogVisible()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    return details and details:IsVisible() or false
end

function API.selected()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    return id(details and details.questID) or id(call(log.GetSelectedQuest))
end

function API.superTracked()
    return id(call(super.GetSuperTrackedQuestID))
end

function API.watched()
    local result = {}
    local count = call(log.GetNumQuestWatches) or 0
    for index = 1, math.min(count, 200) do
        local questID = id(call(log.GetQuestIDForQuestWatchIndex, index))
        if questID then result[#result + 1] = questID end
    end
    return result
end

function API.Read(questID)
    local index = call(log.GetLogIndexForQuestID, questID)
    if not index or index <= 0 then return nil end
    local info = call(log.GetInfo, index)
    local title = type(info) == "table" and info.title or call(log.GetTitleForQuestID, questID)
    local description = call(GetQuestLogQuestText, index)
    return { id = questID, title = title, description = description }
end

function API.Request(questID)
    call(log.RequestLoadQuestByID, questID)
end

function API.HasQuests()
    local rows, count = call(log.GetNumQuestLogEntries)
    if type(count) == "number" then return count > 0 end
    if type(rows) ~= "number" then return nil end
    for index = 1, math.min(rows, 500) do
        local info = call(log.GetInfo, index)
        if type(info) == "table" and not info.isHeader and id(info.questID) then return true end
    end
    return false
end

function API.Profile()
    local raceName, race = call(UnitRace, "player")
    local className, class = call(UnitClass, "player")
    local faction = call(UnitFactionGroup, "player")
    return { raceName = raceName, race = race, className = className, class = class, faction = faction, level = call(UnitLevel, "player") }
end
