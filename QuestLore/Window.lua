local _, ns = ...
local Window = {}
ns.Window = Window
Window.MIN_FONT, Window.MAX_FONT, Window.DEFAULT_FONT = 12, 24, 14
Window.HEADER_HEIGHT, Window.EXPANDED_HEIGHT = 26, 310
Window.CONTENT_TOP, Window.FOOTER_HEIGHT = 10, 8

local palette = {
    text = { 1, 1, 1 },
    muted = { 0.72, 0.72, 0.72 },
    gold = { 1, 0.82, 0 },
}

-- Use the same section art as ObjectiveTrackerModuleHeaderTemplate. Lore is a
-- separate, unprotected frame; it never joins the native secure module list.
local function hasAtlas(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    return ok and info ~= nil
end

local function shadow(text)
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, 1) end
    if text.SetShadowOffset then text:SetShadowOffset(1, -1) end
end

local function textButton(parent, name, label, size)
    local button = CreateFrame("Button", name, parent)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetTextColor(unpack(palette.gold))
    shadow(text)
    if button.SetFontString then button:SetFontString(text) end
    if button.SetNormalFontObject then button:SetNormalFontObject(GameFontNormal) end
    if button.SetHighlightFontObject then button:SetHighlightFontObject(GameFontHighlight) end
    if button.SetDisabledFontObject then button:SetDisabledFontObject(GameFontDisable) end
    button.label = text
    button:SetText(label)
    return button
end

local function tooltip(button, text)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(type(text) == "function" and text() or ns.L(text))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function Window:SyncScrollbar()
    local bar = self.scroll.ScrollBar
    if bar then
        if self.needsScroll and not ns.db.minimized then bar:Show() else bar:Hide() end
    end
end

function Window:Layout()
    local viewport = self.expandedHeight - self.HEADER_HEIGHT - self.CONTENT_TOP - self.FOOTER_HEIGHT
    local function measure(width)
        self.content:SetWidth(width)
        self.title:SetWidth(width)
        self.body:SetWidth(width)
        -- Clear the previous text bounds before measuring. A fixed height can
        -- make the client ellipsize the text and report only the clipped height.
        self.title:SetHeight(0)
        self.body:SetHeight(0)
        local titleHeight = math.ceil(self.title:GetStringHeight())
        self.title:SetHeight(titleHeight)
        self.body:ClearAllPoints()
        self.body:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -titleHeight - 8)
        local bodyHeight = math.ceil(self.body:GetStringHeight())
        local height = titleHeight + 8 + bodyHeight + 6
        self.content:SetHeight(height)
        return height
    end
    -- Give readable summaries the full text column. Only reserve the scroll
    -- controls' gutter if the text overflows at full width; this first pass
    -- also keeps wrapping stable around the scrollbar threshold.
    local height = measure(math.max(1, self.frame:GetWidth() - 16))
    self.naturalContentHeight = height
    self.needsScroll = height > viewport + 0.5
    if self.needsScroll then measure(math.max(1, self.frame:GetWidth() - 40)) end
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", 8, -self.HEADER_HEIGHT - self.CONTENT_TOP)
    self.scroll:SetPoint("BOTTOMRIGHT", self.needsScroll and -32 or -8, self.FOOTER_HEIGHT)
    if self.scroll.UpdateScrollChildRect then self.scroll:UpdateScrollChildRect() end
    if not self.needsScroll then self.scroll:SetVerticalScroll(0) end
    self.scroll:SetVerticalScroll(math.min(self.scroll:GetVerticalScroll(), self.scroll:GetVerticalScrollRange()))
    self:SyncScrollbar()
    if not self.applyingAttachedLayout and ns.Tracker and ns.Tracker.Changed then ns.Tracker:Changed() end
end

function Window:FinishResize()
    if not self.resizing then return end
    self.frame:StopMovingOrSizing()
    self.resizing = false
    if not ns.db.minimized and not self.attachedLayout then
        self.expandedHeight = self.frame:GetHeight()
        ns.db.size = { width = self.frame:GetWidth(), height = self.expandedHeight }
    end
    self:SavePosition()
    self:Layout()
end

function Window:SetFontSize(value)
    value = tonumber(value) or self.DEFAULT_FONT
    if value ~= value then value = self.DEFAULT_FONT end
    value = math.max(self.MIN_FONT, math.min(self.MAX_FONT, math.floor(value + 0.5)))
    local range = self.scroll:GetVerticalScrollRange()
    local fraction = range > 0 and self.scroll:GetVerticalScroll() / range or 0
    ns.db.fontSize = value
    self.title:SetFont(self.fontName, value + 2, "")
    self.body:SetFont(self.fontName, value, "")
    self.body:SetSpacing(math.max(2, math.floor(value / 4)))
    self:Layout()
    if self.needsScroll then
        self.scroll:SetVerticalScroll(math.max(0, math.min(1, fraction)) * self.scroll:GetVerticalScrollRange())
    end
    if ns.Options then ns.Options:Sync() end
end

function Window:Scroll(direction)
    if not self.frame or not self.frame:IsShown() or ns.db.minimized then return end
    local nextValue = self.scroll:GetVerticalScroll() + direction * 54
    self.scroll:SetVerticalScroll(math.max(0, math.min(self.scroll:GetVerticalScrollRange(), nextValue)))
end

function Window:SavePosition()
    if self.attachedLayout then return end
    local left, top = self.frame:GetLeft(), self.frame:GetTop()
    if left and top then ns.db.position = { point = "TOPLEFT", x = left, y = top } end
end

function Window:ResetPosition()
    ns.db.position = nil
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", UIParent:GetWidth() * 0.23, 0)
end

function Window:SetMinimized(value, initial)
    self:FinishResize()
    local left, top
    if not initial then left, top = self.frame:GetLeft(), self.frame:GetTop() end
    ns.db.minimized = value == true
    self.applyingSize = true
    self.frame:SetResizeBounds(self.attachedLayout and 1 or self.minWidth,
        (ns.db.minimized or self.attachedLayout) and self.HEADER_HEIGHT or self.minHeight,
        self.maxWidth, self.maxHeight)
    self.frame:SetHeight(ns.db.minimized and self.HEADER_HEIGHT or self.expandedHeight)
    self.applyingSize = false
    if left and top and not self.attachedLayout then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        self:SavePosition()
    end
    if ns.db.minimized then
        self.scroll:Hide()
        self.grip:Hide()
        self:UpdateMinimizeButton()
    else
        self.scroll:Show()
        if not self.attachedLayout then self.grip:Show() end
        self:UpdateMinimizeButton()
    end
    self:Layout()
    if not initial and ns.ready then ns.QueueRefresh() end
end

function Window:UpdateMinimizeButton()
    if self.nativeMinimize then
        local state = ns.db.minimized and "expand" or "collapse"
        self.minimizeNormal:SetAtlas("ui-questtrackerbutton-secondary-" .. state)
        self.minimizePushed:SetAtlas("ui-questtrackerbutton-secondary-" .. state .. "-pressed")
        self.minimize:SetText("")
    else
        self.minimize:SetText(ns.db.minimized and "+" or "-")
    end
end

function Window:GetDesiredAttachedHeight()
    if ns.db.minimized then return self.HEADER_HEIGHT end
    return self.HEADER_HEIGHT + self.CONTENT_TOP + (self.naturalContentHeight or self.content:GetHeight()) + self.FOOTER_HEIGHT
end

function Window:SetAttachedLayout(width, height)
    self:FinishResize()
    self.attachedLayout, self.applyingAttachedLayout, self.applyingSize = true, true, true
    self.frame:SetResizeBounds(1, self.HEADER_HEIGHT, self.maxWidth, self.maxHeight)
    self.expandedHeight = math.max(self.HEADER_HEIGHT, height)
    self.frame:SetSize(width, ns.db.minimized and self.HEADER_HEIGHT or self.expandedHeight)
    self.applyingSize = false
    self.grip:Hide()
    self:Layout()
    self.applyingAttachedLayout = false
end

function Window:RestoreDetachedLayout()
    self.attachedLayout, self.applyingAttachedLayout, self.applyingSize = false, true, true
    if self.frame.SetParent then self.frame:SetParent(UIParent) end
    local size = ns.db.size
    self.expandedHeight = size.height
    self.frame:SetResizeBounds(self.minWidth, ns.db.minimized and self.HEADER_HEIGHT or self.minHeight,
        self.maxWidth, self.maxHeight)
    self.frame:SetSize(size.width, ns.db.minimized and self.HEADER_HEIGHT or self.expandedHeight)
    self.frame:ClearAllPoints()
    local position = ns.db.position
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        self.frame:SetPoint(position.point == "TOPLEFT" and "TOPLEFT" or "CENTER", UIParent,
            position.point == "TOPLEFT" and "BOTTOMLEFT" or "CENTER", position.x, position.y)
    else self:ResetPosition() end
    self.applyingSize = false
    if not ns.db.minimized then self.grip:Show() end
    self:Layout()
    self.applyingAttachedLayout = false
end

function Window:Create()
    if ns.db.fontDefaultsVersion ~= 2 then
        ns.db.fontSize = math.max(self.MIN_FONT, math.min(self.MAX_FONT, (tonumber(ns.db.fontSize) or 16) - 2))
        ns.db.fontDefaultsVersion = 2
    end
    local frame = CreateFrame("Frame", "QuestLoreWindow", UIParent, "BackdropTemplate")
    frame:Hide()
    self.maxWidth, self.maxHeight = math.max(160, UIParent:GetWidth() - 20), math.max(100, UIParent:GetHeight() - 20)
    self.minWidth, self.minHeight = math.min(320, self.maxWidth), math.min(180, self.maxHeight)
    local function dimension(value, fallback, low, high)
        value = tonumber(value) or fallback
        if value ~= value then value = fallback end
        return math.max(low, math.min(high, value))
    end
    local saved = type(ns.db.size) == "table" and ns.db.size or {}
    local width = dimension(saved.width, 380, self.minWidth, self.maxWidth)
    self.expandedHeight = dimension(saved.height, self.EXPANDED_HEIGHT, self.minHeight, self.maxHeight)
    ns.db.size = { width = width, height = self.expandedHeight }
    frame:SetSize(width, self.expandedHeight)
    frame:SetResizable(true)
    frame:SetResizeBounds(self.minWidth, self.minHeight, self.maxWidth, self.maxHeight)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    -- No filled background or outer border: the world remains visible behind
    -- the title and narrative, just as it does behind tracked objectives.
    self.frame = frame
    local position = ns.db.position
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint(position.point == "TOPLEFT" and "TOPLEFT" or "CENTER", UIParent,
            position.point == "TOPLEFT" and "BOTTOMLEFT" or "CENTER", position.x, position.y)
    else self:ResetPosition() end

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0); header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(self.HEADER_HEIGHT)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not self.attachedLayout then frame:StartMoving() end end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); self:SavePosition() end)
    self.header = header
    self.fontName = GameFontNormal:GetFont()
    if hasAtlas("UI-QuestTracker-Secondary-Objective-Header") then
        local art = header:CreateTexture(nil, "BACKGROUND")
        -- Native quest headers centre this atlas at its original size. Its
        -- decorative rule extends beyond the module's text column on both
        -- sides; stretching it inside the column incorrectly adds margins.
        art:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", true)
        art:SetPoint("CENTER", header, "CENTER", 0, 0)
        self.headerArt = art
    else
        local divider = header:CreateTexture(nil, "BORDER")
        divider:SetColorTexture(0.65, 0.46, 0.12, 0.75)
        divider:SetHeight(1)
        divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
        divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
        self.divider = divider
    end
    local headerLabel = header:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerHeaderFont")
    headerLabel:SetPoint("LEFT", 7, 0); headerLabel:SetPoint("RIGHT", -26, 0)
    headerLabel:SetJustifyH("LEFT"); headerLabel:SetTextColor(unpack(palette.gold))
    headerLabel:SetText("Lore"); shadow(headerLabel)
    self.headerLabel = headerLabel
    self.minimize = textButton(header, "QuestLoreMinimizeButton", "-", 16)
    self.minimize:SetSize(24, 24); self.minimize:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    self.minimize:SetScript("OnClick", function() self:SetMinimized(not ns.db.minimized) end)
    tooltip(self.minimize, function() return ns.L(ns.db.minimized and "Restaurar ventana" or "Minimizar ventana") end)
    if hasAtlas("ui-questtrackerbutton-secondary-collapse") then
        self.nativeMinimize = true
        self.minimizeNormal = self.minimize:CreateTexture(nil, "ARTWORK")
        self.minimizePushed = self.minimize:CreateTexture(nil, "ARTWORK")
        self.minimizeHighlight = self.minimize:CreateTexture(nil, "HIGHLIGHT")
        for _, texture in ipairs({self.minimizeNormal, self.minimizePushed, self.minimizeHighlight}) do
            texture:SetPoint("CENTER", self.minimize, "CENTER", 0, 0)
            texture:SetSize(16, 16)
        end
        self.minimizeHighlight:SetAtlas("ui-questtrackerbutton-yellow-highlight")
        self.minimize:SetNormalTexture(self.minimizeNormal)
        self.minimize:SetPushedTexture(self.minimizePushed)
        self.minimize:SetHighlightTexture(self.minimizeHighlight, "ADD")
    end
    local scroll = CreateFrame("ScrollFrame", "QuestLoreScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -self.HEADER_HEIGHT - self.CONTENT_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -32, self.FOOTER_HEIGHT)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) self:Scroll(-delta) end)
    scroll:HookScript("OnScrollRangeChanged", function() self:SyncScrollbar() end)
    self.scroll = scroll
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(frame:GetWidth() - 40, 1); scroll:SetScrollChild(content)
    self.content = content
    local title = content:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerLineFont")
    title:SetPoint("TOPLEFT", 0, 0); title:SetWidth(content:GetWidth())
    title:SetJustifyH("LEFT"); title:SetJustifyV("TOP"); title:SetWordWrap(true)
    title:SetTextColor(unpack(palette.gold)); shadow(title)
    self.title = title
    local body = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOPLEFT", 0, 0); body:SetWidth(content:GetWidth())
    body:SetTextColor(unpack(palette.text)); body:SetJustifyH("LEFT"); body:SetJustifyV("TOP"); body:SetWordWrap(true)
    shadow(body)
    self.body = body

    local grip = CreateFrame("Button", "QuestLoreResizeGrip", frame)
    grip:SetSize(20, 20); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    tooltip(grip, "Arrastra para cambiar el tamaño")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or ns.db.minimized or self.attachedLayout then return end
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        self.resizing = true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function() self:FinishResize() end)
    grip:SetScript("OnHide", function() self:FinishResize() end)
    self.grip = grip
    frame:SetScript("OnSizeChanged", function(_, _, height)
        if self.applyingSize then return end
        if not ns.db.minimized then self.expandedHeight = height end
        self:Layout()
    end)
    frame:SetScript("OnShow", function() if ns.ready then ns.QueueRefresh() end end)
    frame:SetScript("OnHide", function() self:FinishResize() end)
    self:SetFontSize(ns.db.fontSize)
    self:SetMinimized(ns.db.minimized, true)
end

function Window:Render(model)
    local changedQuest = self.currentKey ~= model.key
    self.currentID, self.currentKey, self.currentTitle = model.id, model.key, model.title
    self.title:SetText(model.title); self.body:SetText(model.body)
    self:Layout()
    if changedQuest then self.scroll:SetVerticalScroll(0) end
end

function Window:Localize()
    -- The tracker always follows the live quest; history lives in Options.
end
