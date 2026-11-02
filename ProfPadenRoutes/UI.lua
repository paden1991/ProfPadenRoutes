local addon,R=...
local P=ProfPaden
local function button(parent,label,x,y,w,action)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,24);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',action);return b
end
function R:RefreshPanel()
    if self.button then self.button.icon:SetDesaturated(not self.enabled) end
    if not self.panel then return end
    local r=self.route
    local stopCount=r and select(2,self:RouteShape(r)) or 0
    local settings=self:Settings(r and r.profession or P.selectedProf)
    local summary=r and (r.name..' - '..(r.zone or '')..'\n'..r.kind..'\n'..(r.coveredNodes and string.format('%d / %d recorded sites in %d yd corridor',r.coveredNodes,r.totalNodes,r.settings.radius) or r.coveredClusters..' farming areas / '..r.totalNodes..' recorded points')..'\n'..string.format('%.1f km / stop %d of %d',r.length*.0009144,math.min(r.index,stopCount),stopCount)..(r.travelSeconds and string.format(' / ~%d:%02d travel',math.floor(r.travelSeconds/60),math.floor(r.travelSeconds%60)) or '')..(r.settings and r.settings.unlimited and ' per lap' or '')) or 'Select a material and an area in the guide\'s Gather tab, then choose Use selected.'
    if r and r.sourceSummary then summary=summary..'\n'..r.sourceSummary end
    if r then summary=summary..'\n'..(r.positionUsed and string.format('Approach: ~%d yd%s',math.floor(r.approach+.5),r.nearbyRadius and (' / area: '..math.floor(r.nearbyRadius)..' yd') or '') or r.previewStart and ('Preview from flight path: '..r.previewStart.name) or 'Zone preview - no suitable flight path; best farming area') end
    self.panel.summary:SetText(summary)
    self.panel.status:SetText(self.status or 'Choose a material in Gather')
    self.panel.note:SetText(settings.unlimited and 'Whole-zone circuit repeats until Pause or Clear. Covers reachable recorded sites, not live spawns. Elevation, caves, water and ridges remain checked with Terrain enabled. Travel is per lap and excludes gathering/combat.' or 'Contour loops follow gentler terrain when coverage improves. Caves, water and mapped ridges stay excluded. Use selected rebuilds near you. Heights are not collision data; travel excludes gathering/combat.')
    self.panel.travel:SetText('Travel: '..settings.label)
    self.panel.radius:SetText('Ore / herb scan: '..settings.nodeRadius..' yd')
    local ctx=r and r.settings and r.settings.terrainContext
    self.panel.terrain:SetText('Terrain: '..(settings.terrain=='off' and 'Off' or settings.terrain=='strong' and 'Strong' or 'Open')..(settings.terrain~='off' and (ctx and ctx.elevation and ' - elevation + terrain' or ctx and ctx.mini and ' - minimap + ridges' or ctx and ' - mapped ridges' or ' - no local data') or ''))
    self.panel.trip:SetText(settings.unlimited and 'Trip: Unlimited' or 'Trip: '..settings.minutes..' min')
    self.panel.scope:SetEnabled(not settings.unlimited)
    self.panel.scope:SetText('Area: '..(settings.scope=='zone' and 'Whole zone' or 'Near me'))
    self.panel.toggle:SetText(self.enabled and 'Pause' or 'Start / resume')
    for _,b in ipairs(self.panel.routeButtons) do b:SetEnabled(r~=nil) end
    local prof=r and r.profession or P.selectedProf;local skill=P.skills[prof]
    local nextRank=skill and P:NextProfessionRank(prof,skill.cap)
    self.panel.train:SetText(nextRank and ('Train at '..nextRank[1]) or 'Training')
    self.panel.train:SetEnabled(nextRank and skill.rank>=nextRank[1] and UnitLevel('player')>=nextRank[4] or false)
end
function R:ShowPanel()
    if not self.panel then
        local f=CreateFrame('Frame','ProfPadenRoutesPanel',UIParent,'BackdropTemplate');self.panel=f
        f:SetSize(410,500);f:SetPoint('CENTER',UIParent,'CENTER',280,0);f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
        f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing)
        f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
        local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');f.title=title;title:SetPoint('TOPLEFT',18,-18);title:SetText('ProfPaden - Farming routes')
        local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-3,-3);close:SetScript('OnClick',function()f:Hide()end)
        f.summary=f:CreateFontString(nil,'OVERLAY','GameFontHighlight');f.summary:SetPoint('TOPLEFT',18,-52);f.summary:SetWidth(372);f.summary:SetJustifyH('LEFT')
        f.travel=button(f,'Travel',18,-169,225,function()
            local options={};for _,key in ipairs({'foot','walk','mount60','mount100'}) do options[#options+1]={label=R.TravelModes[key].label,value=key} end
            P:ToggleDropdown(f.travel,options,R:Settings().mode,function(v)R:ChangeSetting('mode',v)end)
        end)
        f.trip=button(f,'Trip',252,-169,139,function()
            P:ToggleDropdown(f.trip,{{label='5 minutes travel',value=5},{label='10 minutes travel',value=10},{label='20 minutes travel',value=20},{label='Unlimited circuit',value='unlimited'}},R:Settings().unlimited and 'unlimited' or R:Settings().minutes,function(v)R:ChangeSetting('minutes',v)end)
        end)
        f.radius=button(f,'Ore / herb scan',18,-201,225,function()
            P:ToggleDropdown(f.radius,{{label='60 yards (narrow)',value=60},{label='100 yards (default)',value=100},{label='150 yards (wide)',value=150}},R:Settings().nodeRadius,function(v)R:ChangeSetting('radius',v)end)
        end)
        local radiusNote=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f.radiusNote=radiusNote;radiusNote:SetPoint('TOPLEFT',252,-206);radiusNote:SetWidth(139);radiusNote:SetJustifyH('LEFT');radiusNote:SetText('Mobs / pools: 40 yd')
        f.terrain=button(f,'Mountains',18,-233,373,function()
            P:ToggleDropdown(f.terrain,{{label='Open terrain / avoid cliffs, caves and ridges (default)',value='open'},{label='Stronger rough-ground / water avoidance',value='strong'},{label='Terrain hints off (caves still excluded)',value='off'}},R:Settings().terrain,function(v)R:ChangeSetting('terrain',v)end)
        end)
        f.scope=button(f,'Area',18,-265,373,function()
            P:ToggleDropdown(f.scope,{{label='Near me (default)',value='near'},{label='Whole zone',value='zone'}},R:Settings().scope,function(v)R:ChangeSetting('scope',v)end)
        end)
        for _,control in ipairs({f.travel,f.trip,f.radius,f.terrain,f.scope}) do P:DecorateDropdown(control) end
        f:HookScript('OnHide',function()if P.dropdown and (P.dropdown.owner==f.travel or P.dropdown.owner==f.trip or P.dropdown.owner==f.radius or P.dropdown.owner==f.terrain or P.dropdown.owner==f.scope) then P:CloseDropdown() end end)
        f.status=f:CreateFontString(nil,'OVERLAY','GameFontNormal');f.status:SetPoint('TOPLEFT',18,-303);f.status:SetWidth(372);f.status:SetJustifyH('LEFT')
        f.useSelected=button(f,'Use selected',18,-338,115,function()R:SelectCurrent()end)
        f.toggle=button(f,'Start / resume',142,-338,120,function()R:Toggle()end)
        local map=button(f,'World map',271,-338,120,function()R:ShowMap()end)
        local skip=button(f,'Skip stop',18,-370,86,function()R:Skip()end)
        local reverse=button(f,'Reverse',111,-370,86,function()R:Reverse()end)
        f.train=button(f,'Training',204,-370,96,function()R:Train()end)
        local clear=button(f,'Clear',307,-370,84,function()R:Clear()end)
        f.routeButtons={map,skip,reverse,clear}
        local note=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');note:SetPoint('TOPLEFT',18,-412);note:SetWidth(372);note:SetJustifyH('LEFT')
        f.note=note
        if P.Theme then P.Theme.RouteInitialize(f) end
        tinsert(UISpecialFrames,'ProfPadenRoutesPanel')
    end
    self.panel:Show();self:RefreshPanel()
end
function R:CreateButton()
    if self.button or not Minimap or not P.char then return end
    P:CreateMinimapButtons()
    local angle=P.char.minimapAngles.walking
    if type(angle)~='number' or angle~=angle or math.abs(angle)==math.huge then P.char.minimapAngles.walking=305 end
    local b=CreateFrame('Button','ProfPadenRoutesMinimap',Minimap);self.button=b;P.minimapButtons.walking=b
    b:SetSize(32,32);b:SetFrameStrata('MEDIUM');b:SetFrameLevel(Minimap:GetFrameLevel()+8);b:RegisterForClicks('LeftButtonUp','RightButtonUp');b:RegisterForDrag('LeftButton')
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(20,20);b.icon:SetPoint('CENTER');b.icon:SetTexture('Interface\\Icons\\Ability_Tracking');b.icon:SetDesaturated(true)
    local border=b:CreateTexture(nil,'OVERLAY');border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder');border:SetSize(54,54);border:SetPoint('TOPLEFT')
    b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
    b:SetScript('OnClick',function(_,which)if which=='RightButton' then R:ShowPanel() else R:Toggle();R:RefreshPanel() end end)
    b:SetScript('OnDragStart',function(s)s:SetScript('OnUpdate',function()P:DragMinimapButton('walking')end)end)
    b:SetScript('OnDragStop',function(s)s:SetScript('OnUpdate',nil)end);b:SetScript('OnHide',function(s)s:SetScript('OnUpdate',nil)end)
    b:SetScript('OnEnter',function(s)GameTooltip:SetOwner(s,'ANCHOR_LEFT');GameTooltip:SetText('ProfPaden - Walking routes');GameTooltip:AddLine('Left-click: enable / pause selected route\nRight-click: route controls\nDrag: move button',1,.85,.55,true);GameTooltip:Show()end)
    b:SetScript('OnLeave',function()GameTooltip:Hide()end);P:PositionMinimapButton('walking')
end
local frame=CreateFrame('Frame');R.events=frame
frame:RegisterEvent('PLAYER_LOGIN');frame:RegisterEvent('PLAYER_ENTERING_WORLD');frame:RegisterEvent('SKILL_LINES_CHANGED');frame:RegisterEvent('PLAYER_LOGOUT')
frame:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGOUT' then return end
    R:CreateButton();R:RefreshPanel()
    if event=='SKILL_LINES_CHANGED' and R.active and R.route then
        local skill=P.skills[R.route.profession];local rank=skill and P:NextProfessionRank(R.route.profession,skill.cap)
        local key=R.route.profession..':'..tostring(skill and skill.cap)
        if rank and skill.rank>=rank[1] and UnitLevel('player')>=rank[4] and R.trainingNotice~=key then
            R.trainingNotice=key;P:Print(R.route.profession..': '..rank[3]..' training is available. Right-click the walking button for directions.')
        end
    end
end)
SLASH_PROFPADENROUTES1='/ppwalk'
SlashCmdList.PROFPADENROUTES=function(msg)
    if msg=='stop' then R:Pause() elseif msg=='clear' then R:Clear() elseif msg=='start' then R:Start() else R:ShowPanel() end
end

