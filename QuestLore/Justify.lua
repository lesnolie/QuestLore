local _, ns = ...
local Justify = {}
Justify.__index = Justify
ns.Justify = Justify

-- WoW FontStrings expose left/center/right alignment, not full justification.
-- Keep a reusable word pool and distribute inter-word space on wrapped lines.
function Justify.New(parent, font)
    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measure:Hide()
    return setmetatable({parent=parent,font=font,measure=measure,words={},lines={}},Justify)
end

function Justify:Hide()
    for _, word in ipairs(self.words) do word:Hide() end
end

function Justify:Layout(text, width, size, spacing)
    width = math.max(1,width)
    if self.text==text and self.width==width and self.size==size and self.spacing==spacing then
        for i,word in ipairs(self.words) do if i<=self.used then word:Show() else word:Hide() end end
        return self.height
    end
    self.text,self.width,self.size,self.spacing = text,width,size,spacing
    self.used,self.lines = 0,{}
    local measure = self.measure
    measure:SetFont(self.font,size,"");measure:SetHeight(0);measure:SetWidth(width)
    measure:SetWordWrap(false);measure:SetSpacing(0)
    measure:SetText("Ag")
    local lineHeight=math.ceil(measure:GetStringHeight())
    local function wordWidth(value)
        measure:SetWidth(0);measure:SetText(value)
        if measure.GetUnboundedStringWidth then return measure:GetUnboundedStringWidth() end
        return measure:GetStringWidth()
    end
    local space=math.max(1,wordWidth("x x")-wordWidth("xx"))
    local y=0
    local function place(value,x,atY,wordWidth,wrap)
        self.used=self.used+1
        local region=self.words[self.used]
        if not region then
            region=self.parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
            region:SetTextColor(1,1,1);region:SetJustifyH("LEFT");region:SetJustifyV("TOP")
            if region.SetMaxLines then region:SetMaxLines(0) end
            if region.SetNonSpaceWrap then region:SetNonSpaceWrap(true) end
            if region.SetShadowColor then region:SetShadowColor(0,0,0,1);region:SetShadowOffset(1,-1) end
            self.words[self.used]=region
        end
        region:SetFont(self.font,size,"");region:SetSpacing(spacing)
        region:SetWordWrap(wrap);region:SetHeight(0);region:SetWidth(wordWidth)
        region:ClearAllPoints();region:SetPoint("TOPLEFT",self.parent,"TOPLEFT",x,-atY)
        region:SetText(value);region:Show()
    end
    for paragraph in (text:gsub("\r\n","\n"):gsub("\r","\n").."\n"):gmatch("(.-)\n") do
        local line,total={},0
        local function flush(justified)
            if #line==0 then return end
            local gap=(justified and #line>1) and (width-total)/(#line-1) or space
            local x=0
            local first=self.used+1
            for _,word in ipairs(line) do
                place(word.text,x,y,word.width,false)
                x=x+word.width+gap
            end
            self.lines[#self.lines+1]={first=first,last=self.used,y=y,height=lineHeight,justified=justified and #line>1 or false}
            y=y+lineHeight+spacing;line,total={},0
        end
        local any=false
        for value in paragraph:gmatch("%S+") do
            any=true
            local w=math.ceil(wordWidth(value))
            if w>width then
                flush(true)
                -- An unusually long token wraps naturally on its own line,
                -- preserving every UTF-8 character without manual splitting.
                measure:SetWordWrap(true);measure:SetWidth(width);measure:SetText(value)
                if measure.SetNonSpaceWrap then measure:SetNonSpaceWrap(true) end
                measure:SetSpacing(spacing)
                local h=math.ceil(measure:GetStringHeight())
                measure:SetWordWrap(false);measure:SetSpacing(0)
                place(value,0,y,width,true)
                self.lines[#self.lines+1]={first=self.used,last=self.used,y=y,height=h,justified=false}
                y=y+h+spacing
            else
                if #line>0 and total+#line*space+w>width then flush(true) end
                line[#line+1]={text=value,width=w};total=total+w
            end
        end
        flush(false)
        if not any then y=y+lineHeight+spacing end
    end
    self.height=math.max(0,y-spacing)
    for i=self.used+1,#self.words do self.words[i]:Hide() end
    return self.height
end
