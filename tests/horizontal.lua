return function(env)
    local previousHost=ForeverTrackerHost
    local host=env.object(UIParent)
    local module,queued
    function host:MarkDirty()
        if queued then return end
        queued=true
        C_Timer.After(0,function()
            queued=false
            if module then module:SetWidth(300);module:Update(700) end
        end)
    end
    ForeverTrackerHost={Attach=function(proxy)
        module=proxy;proxy.parentContainer=host;proxy:SetParent(host);host:MarkDirty()
    end}
    local ns=env.login({attachToTracker=false,followPolestar=false});env.tick(0.2)
    ns.Refresh=function() end
    local w=ns.Window
    local texts={ns.Narratives[367].es,ns.Narratives[367].en,
        "Una primera línea con varias palabras para distribuir.\n\nUn segundo párrafo conserva todas sus palabras y termina a la izquierda.",
        string.rep("PalabrasinEspaciosÁéñ",35)}
    local cases=0
    for size=12,24 do
        w:SetFontSize(size)
        for _,dimension in ipairs({{960,80},{1400,96},{320,321},{321,320},{4000,100},{320,320}}) do
            for index,text in ipairs(texts) do
                local width,height=dimension[1],dimension[2]
                w.frame:SetSize(width,height);w.frame.scripts.OnSizeChanged(w.frame,width,height)
                w:Render({key="horizontal:"..index,title="En guerra con la Cruzada Escarlata",body=text,kind="story",source=""})
                env.tick(0.2);cases=cases+1
                local wide=width>height
                assert(w.wideLayout==wide,"layout uses expanded aspect ratio")
                assert(w.frame.resizeBounds[3]==nil,"horizontal resizing has no addon maximum")
                assert(w.headerLabel.fontTemplate=="ObjectiveTrackerHeaderFont","quest heading keeps native Lore typography")
                if wide then
                    assert(w.headerLabel.text==w.currentTitle and w.headerLabel.justifyH=="CENTER","wide title replaces Lore and is centered")
                    assert(not w.title:IsShown() and not w.body:IsShown(),"wide mode never repeats title or overlays native body")
                    local words,bottom={},0
                    for i=1,w.justified.used do
                        local word=w.justified.words[i]
                        assert(word:IsShown(),"each justified word is visible")
                        words[#words+1]=word:GetText()
                        bottom=math.max(bottom,-word.point[5]+word:GetStringHeight())
                        assert(word.textColor[1]==1 and word.textColor[2]==1 and word.textColor[3]==1,"justified narrative stays white")
                    end
                    assert(table.concat(words):gsub("%s+","")==text:gsub("%s+",""),"no character disappears or repeats during justification")
                    for _,line in ipairs(w.justified.lines) do
                        local first,last=w.justified.words[line.first],w.justified.words[line.last]
                        assert(first.point[4]==0,"line begins at left margin")
                        if line.justified then
                            assert(math.abs(last.point[4]+last:GetWidth()-w.justified.width)<0.01,"wrapped line reaches right margin")
                        end
                    end
                    assert(not w.justified.lines[#w.justified.lines].justified,"last paragraph line is left aligned")
                    assert(w.content:GetHeight()>=bottom,"content includes every justified line")
                    w:Scroll(100000)
                    assert(w.scroll:GetVerticalScroll()+w.viewportHeight>=bottom,"last justified line is reachable in a short banner")
                    w:Scroll(-100000)
                else
                    assert(w.headerLabel.text=="Lore" and w.headerLabel.justifyH=="LEFT","portrait restores original header")
                    assert(w.title:IsShown() and w.body:IsShown(),"portrait restores the ordinary text")
                    for _,word in ipairs(w.justified.words) do assert(not word:IsShown(),"pooled words hide in portrait mode") end
                end
            end
        end
    end
    w.frame:SetSize(1200,80);w.frame.scripts.OnSizeChanged(w.frame,1200,80)
    w:Render({key="persist",title="Una nueva Peste",body=texts[1],kind="story",source=""});env.tick(0.2)
    -- Use the actual resize gesture to persist the expanded dimensions.
    w.grip.scripts.OnMouseDown(w.grip,"LeftButton");w.grip.scripts.OnMouseUp();env.tick(0.2)
    local height=w.expandedHeight
    w:SetMinimized(true);env.tick(0.2)
    assert(w.wideLayout and w.headerLabel.text=="Una nueva Peste","minimizing preserves horizontal identity")
    assert(w.frame:GetHeight()==w:GetHeaderHeight() and not w.scroll:IsShown(),"minimized banner is just its title bar")
    w:SetMinimized(false);env.tick(0.2)
    assert(w.frame:GetHeight()==height and w.wideLayout,"restore preserves banner dimensions")
    local restored=env.login(ns.db);env.tick(0.2)
    assert(restored.Window.frame:GetWidth()==1200 and restored.Window.wideLayout,"per-character banner width survives reload")
    ns.Tracker:SetAttached(true);env.tick(0.2)
    assert(not w.wideLayout and w.headerLabel.text=="Lore","attachment always restores native tracker design")
    ns.Tracker:SetAttached(false);env.tick(0.2)
    assert(w.wideLayout and w.frame:GetWidth()==1200,"detaching restores horizontal design and width")
    local pool=#w.justified.words
    for i=1,30 do w:Layout() end
    assert(#w.justified.words==pool,"repeated layouts reuse the word pool")
    assert(not w.layoutQueued,"steady horizontal layout queues no continuous updates")
    ForeverTrackerHost=previousHost
    print("PASS: "..cases.." horizontal cases; native centered title, justification with complete text, all fonts, short/unbounded widths, aspect boundary, portrait/attachment transitions, saved geometry and pool reuse")
end
