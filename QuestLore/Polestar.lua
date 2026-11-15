local _, ns = ...
local Bridge = {}
ns.PolestarBridge = Bridge

local function available()
    local addon = _G.Polestar
    if type(addon) == "table" and type(addon.Nav) == "table"
        and type(addon.Nav.GetTarget) == "function"
        and type(addon.On) == "function" and type(addon.Off) == "function" then
        return addon
    end
end

local function field(target, key)
    local value = ns.API.Call(function() return target[key] end)
    if type(value) == "string" or type(value) == "number" then return value end
    return nil
end

local function targetState(addon)
    local target = ns.API.Call(addon.Nav.GetTarget)
    if type(target) ~= "table" then return "none" end
    local quest = tonumber(field(target, "quest"))
    if not quest or quest <= 0 or quest > 2147483647 or quest ~= math.floor(quest) then quest = nil end
    local kind = field(target, "kind")
    -- Identity follows the quest/guide goal, not temporary travel labels or
    -- moving spawn coordinates. Re-announcing the same goal is not a click.
    local signature = table.concat({tostring(quest), tostring(kind),
        tostring(field(target, "stepIndex")), tostring(field(target, "goalIndex"))}, ":")
    if kind == "manual" or kind == "accept" then quest = nil end
    return signature, quest
end

function Bridge:IsAvailable()
    return available() ~= nil
end

function Bridge:ReadTarget()
    if not self.owner or self.owner ~= available() then return end
    local signature, quest = targetState(self.owner)
    if signature ~= self.signature then
        self.signature, self.manualSelection = signature, false
        if ns.ClearSelectionContext then ns.ClearSelectionContext() end
    end
    self.quest = quest
end

function Bridge:Disconnect()
    local owner, handle = self.owner, self.handle
    -- Invalidate first: a stale callback can never restore the old context.
    self.owner, self.handle, self.quest, self.signature, self.manualSelection, self.callbackToken = nil, nil, nil, nil, nil, nil
    if owner and handle then ns.API.Call(owner.Off, handle) end
end

function Bridge:Sync()
    local addon = ns.db.followPolestar and available() or nil
    if self.owner ~= addon then self:Disconnect() end
    if addon and not self.owner then
        self.owner = addon
        local token = {}
        self.callbackToken = token
        local handle = ns.API.Call(addon.On, "WAYPOINT_CHANGED", function()
            if self.owner ~= addon or self.callbackToken ~= token or not ns.db.followPolestar then return end
            -- Read the getter rather than trusting a possibly stale event payload.
            self:ReadTarget()
            ns.QueueRefresh()
        end)
        if handle then self.handle = handle else self:Disconnect() end
    end
    self:ReadTarget()
    if ns.Options then ns.Options:Sync() end
    ns.QueueRefresh()
end

function Bridge:SetEnabled(value)
    ns.db.followPolestar = value == true
    self:Sync()
end

function Bridge:QuestID()
    if not ns.db.followPolestar or not self.owner or self.owner ~= available() then return end
    self:ReadTarget()
    if not self.manualSelection and ns.API.isActive(self.quest) then return self.quest end
end

function Bridge:SelectQuest(questID)
    local current = self:QuestID()
    if current and questID ~= current then self.manualSelection = true end
end
