local _, ns = ...
local Tracker = {}
ns.Tracker = Tracker

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

function Tracker:IsAvailable()
    return type(ForeverTrackerHost) == "table" and type(ForeverTrackerHost.Attach) == "function"
end

function Tracker:IsAttached()
    return self.active == true
end

function Tracker:Dirty()
    local container = self.proxy and self.proxy.parentContainer
    if container and type(container.MarkDirty) == "function" then container:MarkDirty() end
end

function Tracker:UpdateProxy(proxy, availableHeight)
    -- The host also freezes its layout in combat. Keep the last applied layout
    -- if a consumer invokes the proxy directly during that freeze.
    if inCombat() then self.pending = true; return end
    local window = ns.Window
    local frame = window.frame
    local cap = math.max(0, tonumber(availableHeight) or 0)
    local minimum = window.HEADER_HEIGHT
    if not ns.db.minimized then
        -- Keep room for both title and narrative under the header and above
        -- navigation. Less space would overlap controls and expose no story.
        minimum = minimum + window.CONTENT_TOP + window.FOOTER_HEIGHT
            + 2 * ((tonumber(ns.db.fontSize) or window.DEFAULT_FONT) + 8)
    end
    self.updating = true
    proxy.contentsHeight, proxy.truncated = 0, false
    if not self.active or ns.db.visible == false or not frame:IsShown() or cap < minimum then
        proxy:SetHeight(1)
        proxy:Hide()
    else
        local width = math.max(1, proxy:GetWidth())
        -- Measure text at the width supplied by LayoutModules, then use only
        -- the room this section needs, bounded by the host's remaining space.
        window:SetAttachedLayout(width, cap)
        local desired = math.max(window.HEADER_HEIGHT, window:GetDesiredAttachedHeight())
        local height = math.min(cap, desired)
        if height ~= cap then window:SetAttachedLayout(width, height) end
        proxy.contentsHeight, proxy.truncated = height, desired > height + 0.5
        proxy:SetHeight(height)
        proxy:Show()
    end
    self.updating = false
end

function Tracker:CreateProxy()
    if self.proxy then return end
    local proxy = CreateFrame("Frame", "QuestLoreTrackerModule", UIParent)
    proxy:SetSize(1, 1)
    proxy:Hide()
    proxy.uiOrder = 1000
    proxy.Update = function(frame, availableHeight) self:UpdateProxy(frame, availableHeight) end
    proxy.GetContentsHeight = function(frame) return frame.contentsHeight or 0 end
    proxy.IsTruncated = function(frame) return frame.truncated == true end
    proxy:HookScript("OnShow", function()
        if ns.ready and ns.Window.frame:IsVisible() then ns.QueueRefresh() end
    end)
    self.proxy = proxy
end

function Tracker:Changed()
    if not self.events or self.updating or not ns.db or not ns.Window.frame then return end
    local wanted = ns.db.attachToTracker == true and self:IsAvailable()
    if inCombat() then
        -- Do not reparent under the shared column, or move any of its frames,
        -- until PLAYER_REGEN_ENABLED. Keep the user's saved choice meanwhile.
        self.pending = wanted or self.active == true
        return
    end
    self.pending = false
    self.updating = true
    if wanted and not self.active then
        self:CreateProxy()
        if not self.registered then
            -- Attach once to ForeverCore's private column. Its mixin preserves
            -- this hand-built frame's Update/GetContentsHeight implementations.
            ForeverTrackerHost.Attach(self.proxy)
            self.registered = true
        end
        local window = ns.Window
        window:FinishResize()
        window.frame:StopMovingOrSizing()
        self.active = true
        window.attachedLayout = true
        window.frame:SetParent(self.proxy)
        window.frame:ClearAllPoints()
        window.frame:SetPoint("TOPLEFT", self.proxy, "TOPLEFT", 0, 0)
        window.grip:Hide()
    elseif not wanted and self.active then
        self.active = false
        ns.Window.frame:SetParent(UIParent)
        ns.Window:RestoreDetachedLayout()
        self.proxy.contentsHeight, self.proxy.truncated = 0, false
        self.proxy:Hide()
    end
    self.updating = false
    self:Dirty()
    if ns.Options and ns.Options.Sync then ns.Options:Sync() end
end

function Tracker:Refresh()
    self:Changed()
end

function Tracker:SetAttached(enabled)
    ns.db.attachToTracker = enabled == true
    self:Changed()
    if ns.Options and ns.Options.Sync then ns.Options:Sync() end
end

function Tracker:Create()
    if self.events then return end
    local events = CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() self:Changed() end)
    self:Changed()
end
