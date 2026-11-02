local _,R=...
local P=ProfPaden
local owner='ProfPadenRoutes'
P.navigationCompanions[owner]=function()R:Pause('Paused - tracking dismissed')end
function R:ChangeSetting(key,value)
    if InCombatLockdown() then P:Print('Change route settings after combat.');return false end
    P.char.walkingSettings=P.char.walkingSettings or {}
    local old=P.char.walkingSettings[key];P.char.walkingSettings[key]=value
    local r=self.route
    if r then
        local route,err=self:Build({key=r.entryKey,name=r.name},r.map,r.width,r.height,self:PlayerPosition(r.map),r.profession)
        if not route then P.char.walkingSettings[key]=old;P:Print(err);self:RefreshPanel();return false end
        self:Pause();route.zone=r.zone;self.route=route;self.status='Rebuilt - start when ready';self:Draw()
    end
    self:RefreshPanel();return true
end
function R:PlayerPosition(map)
    if not C_Map or C_Map.GetBestMapForUnit('player')~=map then return end
    local pos=C_Map.GetPlayerMapPosition(map,'player')
    if pos then
        local x,y=pos.x or pos:GetX(),pos.y or pos:GetY()
        if self.IsNumber(x) and self.IsNumber(y) then return {x=x,y=y} end
    end
end
function R:SelectCurrent()
    local entry,area=P.selected,P.currentMap
    if not entry or not entry.gatherItem or not area then P:Print('Choose a material and its area in Gather first.');self:ShowPanel();return false end
    local w,h
    if C_Map and C_Map.GetMapWorldSize then w,h=C_Map.GetMapWorldSize(area.mapId) end
    local route,err=self:Build(entry,area.mapId,w,h,self:PlayerPosition(area.mapId),P.selectedProf)
    if not route then P:Print(err);return false end
    self:Pause();self.route=route;route.zone=area.zone
    self.status='Ready';self:RefreshPanel();self:Draw();return true
end
function R:PointToNext()
    local r=self.route;local n=r and r.points[r.index]
    if not n then self:Pause('Circuit complete');return end
    P:TrackPoint({map=r.map,x=n.x,y=n.y,zone=r.zone,arrivalRadius=r.arrivalRadius or 30},r.name..' - stop '..r.index,owner)
end
-- Enabled watches for area entry; active additionally owns the current arrow.
function R:Pause(reason)
    self.enabled=false;self.active=false;self.mapPreview=nil;self.status=reason or 'Paused'
    if self.ticker then self.ticker:Hide() end
    self:HideMinimap()
    if P.navTarget and P.navTarget.owner==owner then P:ClearNavigation() end
    self:RefreshPanel();self:Draw()
end
function R:WaitForArea(reason)
    local changed=self.active or self.status~=reason
    self.active=false;self.status=reason
    if P.navTarget and P.navTarget.owner==owner then P:ClearNavigation() end
    if changed then self:RefreshPanel() end
end
function R:Join(index)
    local r=self.route;local closed,count=self:RouteShape(r)
    r.index=index;r.remaining=closed and count or count-index+1
    self.active=true;self.status=r.settings and r.settings.unlimited and ('Following circuit - lap '..(r.lap or 1)) or 'Following from nearest section';self:PointToNext();self:RefreshPanel()
end
function R:Start()
    if not P:IsNavigationEnabled() then self:Pause('Tracking off - enable it in ProfPaden');P:Print('Enable Tracking in ProfPaden or use /pp tracking on.');return false end
    if InCombatLockdown() then P:Print('Resume the walking route after combat.');return false end
    if not self.route and not self:SelectCurrent() then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost('player') or UnitOnTaxi and UnitOnTaxi('player') then
        self:Pause('Resume when back on foot');return false
    end
    local r=self.route;self.enabled=true
    local pos=self:PlayerPosition(r.map)
    local inside,index
    if pos then inside,index=self:InRouteArea(r,pos) end
    -- Only explicit Start may replace an existing destination.
    if inside then self:Join(index)
    else self:WaitForArea(pos and 'Waiting - enter the gold route outline' or 'Waiting - travel to '..(r.zone or 'the route zone')) end
    if not self.ticker then
        self.ticker=CreateFrame('Frame');local elapsed,mini=0,0
        self.ticker:SetScript('OnUpdate',function(_,dt)
            elapsed=elapsed+dt;mini=mini+dt
            if elapsed>=.5 then elapsed=0;R:Tick() end
            if mini>=.1 then mini=0;R:UpdateMinimap() end
        end)
    end
    self.ticker:Show();self:RefreshPanel();self:AttachMap();self:Draw();self:UpdateMinimap();return true
end
function R:Toggle()
    if self.enabled then self:Pause();return end
    if P.tab=='Gather' and P.selected and P.currentMap and (not self.route or self.route.entryKey~=P.selected.key or self.route.map~=P.currentMap.mapId) then
        if not self:SelectCurrent() then return end
    end
    self:Start()
end
function R:Tick()
    if not self.enabled or not self.route then return end
    if not P:IsNavigationEnabled() then self:Pause("Tracking off");return end
    if (P.navTarget and P.navTarget.owner~=owner) or (self.active and not P.navTarget) then
        self:Pause('Paused - another destination or arrow dismissed');return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost('player') then self:Pause('Paused while dead');return end
    if UnitOnTaxi and UnitOnTaxi('player') then self:Pause('Paused during flight');return end
    if InCombatLockdown() then return end
    local r=self.route;local pos=self:PlayerPosition(r.map)
    if not pos then self:WaitForArea('Waiting - travel to '..(r.zone or 'the route zone'));self:HideMinimap();return end
    -- The arrow samples more frequently. Keep its arrival result even if the
    -- player has already walked past the stop before this slower tick runs.
    if self.active and P.navTarget and P.navTarget.arrived then self:Skip();return end
    -- A wider exit margin prevents rapid start/stop at the edge of a corridor.
    local inside,index=self:InRouteArea(r,pos,self.active and 80 or 40)
    if not inside then self:WaitForArea('Waiting - enter the gold route outline');return end
    if not self.active then self:Join(index) end
    local n=r.points[r.index]
    if n and self.Distance(pos,n,r.width,r.height)<=(r.arrivalRadius or 30) then self:Skip() end
end
function R:Skip()
    local r=self.route;if not r or not self.active then return end
    local closed,count=self:RouteShape(r)
    r.remaining=(r.remaining or (count-r.index+1))-1
    if r.remaining<=0 then
        if r.settings and r.settings.unlimited and closed and count>1 then
            r.remaining=count;r.lap=(r.lap or 1)+1;self.status='Following circuit - lap '..r.lap
        else self:Pause('Circuit complete');return end
    end
    r.index=r.index+1;if closed and r.index>count then r.index=1 end
    self:PointToNext();self:RefreshPanel()
end
function R:Reverse()
    if not self.route then return end
    self:Pause();local r=self.route;local a,b=1,#r.points
    while a<b do r.points[a],r.points[b]=r.points[b],r.points[a];a=a+1;b=b-1 end
    r.index=1;r.lap=1;r.display=self:RouteDisplay(r.points,r.width,r.height,r.settings);self.status='Reversed - ready';self:RefreshPanel();self:Draw()
    if r.settings then local pos=self:PlayerPosition(r.map);r.travelSeconds,r.approach=self:TravelSeconds(r.points,r.width,r.height,r.settings,pos);r.planningSeconds=self:PlanningSeconds(r.points,r.width,r.height,r.settings,pos);r.mountainYards=self:MountainLength(r.points,r.width,r.height,r.settings,pos);self:RefreshPanel() end
end
function R:Clear()
    self:Pause();self.route=nil;self.status='Choose a material in Gather';self:Draw();self:RefreshPanel()
end
function R:Train()
    local prof=self.route and self.route.profession or P.selectedProf
    local before=P.selectedProf;P.selectedProf=prof;local stop=P:RouteRankStop((P.skills[prof] or {}).rank or 0);P.selectedProf=before
    if not stop then P:Print('The next '..prof..' rank is not due yet.');return end
    if not stop.target then P:Print(stop.note..' - see Quests for the unlock.');return end
    if UnitLevel('player')<(stop.minLevel or 1) then P:Print(stop.note);return end
    self:Pause('Paused for training')
    P:TrackNPC(stop.target.npc.id,nil,P:NPCNavigationGoal(stop,stop.target.npc.id,prof))
end
function R:DrawLines(layer,points)
    layer.lines=layer.lines or {};local w,h=layer:GetWidth(),layer:GetHeight()
    for _,line in ipairs(layer.lines) do line:Hide() end
    for i=1,#points-1 do
        local line=layer.lines[i]
        if not line then line=layer:CreateLine(nil,'OVERLAY');layer.lines[i]=line;line:SetThickness(2);line:SetColorTexture(1,.8,.18,.95) end
        line:SetStartPoint('TOPLEFT',layer,points[i].x*w,-points[i].y*h)
        line:SetEndPoint('TOPLEFT',layer,points[i+1].x*w,-points[i+1].y*h);line:Show()
    end
end
function R:Draw()
    if not self.worldLayer then return end
    local r=self.route;local mapped=r and self.OpenMapPoints and self:OpenMapPoints(r)
    local show=r and (self.enabled or self.mapPreview) and WorldMapFrame and (mapped or mapped==nil and WorldMapFrame:GetMapID()==r.map)
    self.worldLayer:SetShown(show and true or false)
    if show then
        if P.MapOverlayLevel then P:MapOverlayLevel(self.worldLayer,2) end
        self:DrawLines(self.worldLayer,mapped or r.display)
    end
end
function R:AttachMap()
    if InCombatLockdown() then return end
    if not WorldMapFrame then local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn;if load then pcall(load,'Blizzard_WorldMap') end end
    if not WorldMapFrame or not WorldMapFrame.GetCanvas then return end
    if not self.worldLayer then
        local canvas=WorldMapFrame:GetCanvas();local f=CreateFrame('Frame',nil,canvas);self.worldLayer=f;f.lines={};f:SetAllPoints(canvas);f:EnableMouse(false);f:SetFrameLevel((canvas:GetFrameLevel() or 0)+2)
        f:SetScript('OnSizeChanged',function()R:Draw()end)
        WorldMapFrame:HookScript('OnShow',function()R:Draw()end)
        if hooksecurefunc then hooksecurefunc(WorldMapFrame,'SetMapID',function()R:Draw()end) end
    end
end
function R:ShowMap()
    if not self.route or InCombatLockdown() then return end
    self:AttachMap();if not self.worldLayer then return end
    self.mapPreview=true;ShowUIPanel(WorldMapFrame);WorldMapFrame:SetMapID(self.route.map);self:Draw()
end
