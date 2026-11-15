-- Geometry invariants across real size/font transitions. The native range is
-- derived independently from recorded scroll anchors and commits later, rather
-- than returning the old harness's arbitrary 600px value.
return function(env)
    local oldHost=ForeverTrackerHost
    local host=env.object(UIParent)
    local width,cap=300,700
    local module,queued
    local layouts=0
    function host:MarkDirty()
        if queued then return end
        queued=true
        C_Timer.After(0,function()
            queued=false;layouts=layouts+1
            module:SetWidth(width);module:Update(cap)
        end)
    end
    ForeverTrackerHost={Attach=function(proxy)
        module=proxy;proxy.parentContainer=host;proxy:SetParent(host);host:MarkDirty()
    end}
    env.setQuest()
    local ns=env.login({attachToTracker=true,followPolestar=false})
    env.tick(0.3)
    -- Feed controlled text through actual Render/Font/Tracker methods; game
    -- context selection is tested separately by the integration suite.
    ns.Refresh=function() end
    local window=ns.Window
    local scroll=window.scroll
    local function viewport()
        local top=assert(scroll.points.TOPLEFT)
        local bottom=assert(scroll.points.BOTTOMRIGHT)
        return math.max(0,window.frame:GetHeight()+top[3]-bottom[3])
    end
    local rectQueued=false
    scroll.UpdateScrollChildRect=function(self)
        if rectQueued then return end
        rectQueued=true
        C_Timer.After(0,function()
            rectQueued=false
            self.range=math.max(0,self.child:GetHeight()-viewport())
            self:SetVerticalScroll(math.min(self:GetVerticalScroll(),self.range))
            if self.scripts.OnScrollRangeChanged then self.scripts.OnScrollRangeChanged(self,0,self.range) end
        end)
    end
    local scenarios={
        {title="Paciencia",body="Los informes deben llegar a su destino."},
        {title="Una nueva Peste",body=ns.Narratives[367].es},
        {title="A New Plague",body=ns.Narratives[367].en},
        {title=string.rep("Un informe pendiente ",5),body=string.rep("Primera parte de la investigación. ",10).."\n\n"..string.rep("La última línea también debe poder leerse. ",12)},
        {title="Un nombre extenso",body=string.rep("Unapalabraextremadamentelarga",20)},
    }
    local checks=0
    local function verify(label)
        checks=checks+1
        local visible=viewport()
        local bodyAnchor=assert(window.body.points.TOPLEFT)
        local textBottom=-bodyAnchor[5]+window.body:GetStringHeight()
        assert(window.body.height==0,label..": body has no clipping height")
        assert(window.content:GetHeight()>=textBottom,label..": content includes the last line")
        local actual=math.max(0,window.content:GetHeight()-visible)
        assert(math.abs(window.scrollRange-actual)<0.011,label..": logical range matches native geometry")
        assert(math.abs(scroll:GetVerticalScrollRange()-actual)<0.011,label..": deferred native range converges")
        assert(window.needsScroll==(actual>0.01),label..": scrollbar follows real overflow")
        assert(scroll.ScrollBar:IsShown()==window.needsScroll,label..": bar visibility follows overflow")
        window:Scroll(100000)
        assert(scroll:GetVerticalScroll()+visible>=textBottom,label..": scrolling reaches the last line")
        window:Scroll(-100000)
        assert(scroll:GetVerticalScroll()==0,label..": start remains reachable")
        assert(not ns.Tracker.reflowQueued and not window.layoutQueued,label..": layout converges")
    end
    for _,w in ipairs({220,300,420}) do
        width=w
        for font=12,24 do
            window:SetFontSize(font)
            for _,room in ipairs({120,240,900}) do
                cap=room
                for index,story in ipairs(scenarios) do
                    window:Render({key="matrix:"..index,title=story.title,body=story.body,kind="story",source=""})
                    host:MarkDirty();env.tick(0.2)
                    verify(w.."/"..font.."/"..room.."/"..index)
                end
            end
        end
    end
    -- The host may assign a different final height after font changes. Keep
    -- reading position through that second pass and a delayed native range.
    cap=180;width=260
    window:Render({key="fraction",title=scenarios[4].title,body=scenarios[4].body,kind="story",source=""})
    host:MarkDirty();env.tick(0.2)
    scroll.range=0
    window:Render({key="instant",title=scenarios[4].title,body=scenarios[4].body,kind="story",source=""})
    window:Scroll(100000)
    local bottom=-window.body.points.TOPLEFT[5]+window.body:GetStringHeight()
    assert(scroll:GetVerticalScroll()+viewport()>=bottom,"last line is reachable before the native range cache updates")
    env.tick(0.2)
    scroll:SetVerticalScroll(window.scrollRange/2)
    scroll.range=0 -- simulate a stale native range during font reflow
    window:SetFontSize(13);env.tick(0.2)
    assert(window.scrollRange>0 and math.abs(scroll:GetVerticalScroll()/window.scrollRange-0.5)<0.001,"font changes preserve reading fraction through deferred native geometry")
    verify("deferred fraction")
    window:SetMinimized(true);env.tick(0.2)
    assert(window.frame:GetHeight()==window.HEADER_HEIGHT and not scroll:IsVisible() and not scroll.ScrollBar:IsShown(),"minimized Lore exposes no text or scrollbar")
    cap=900;host:MarkDirty();env.tick(0.2)
    window:SetFontSize(24);window:SetMinimized(false);env.tick(0.2)
    verify("restore with new font and space")
    ns.Tracker:SetAttached(false);env.tick(0.2)
    for _,height in ipairs({180,320,650}) do
        window.frame:SetSize(400,height)
        window.frame.scripts.OnSizeChanged(window.frame,400,height)
        env.tick(0.2);verify("detached "..height)
    end
    -- A native OnShow must not revive a stale scrollbar on fitting text.
    window:Render({key="fit",title="Paciencia",body="Un relato breve.",kind="story",source=""});env.tick(0.2)
    scroll.ScrollBar:Show();scroll.ScrollBar.scripts.OnShow(scroll.ScrollBar)
    assert(not scroll.ScrollBar:IsShown(),"native show cannot revive unnecessary scrollbar")
    local count=layouts;env.tick(2)
    assert(layouts==count,"idle time adds no tracker layout passes")
    ForeverTrackerHost=oldHost
    print("PASS: "..checks.." layout cases; all font sizes 12-24, three widths/height budgets, ES/EN/paragraphs/long tokens, last-line reachability, delayed native range, minimized restore, detached resize and idle convergence")
end
