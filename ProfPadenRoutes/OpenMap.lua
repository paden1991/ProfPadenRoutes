local _,R=...
local P=ProfPaden
function R:OpenMapPoints(route)
    local api=OpenMapAPI
    if not api or api.major~=1 or not api.IsStitched or not api.IsStitched() then return end
    local host=WorldMapFrame and WorldMapFrame:GetMapID()
    if not host or not api.WorldFromMap or not api.MapFromWorld then return false end
    local points={}
    for _,p in ipairs(route.display) do
        local u,v=api.WorldFromMap(route.map,p.x,p.y)
        if not u then return false end
        local x,y=api.MapFromWorld(host,u,v)
        if not self.IsNumber(x) or not self.IsNumber(y) then return false end
        points[#points+1]={x=x,y=y}
    end
    return points
end
function R:SetupOpenMap()
    local api=OpenMapAPI
    if not api or api.major~=1 or not api.RegisterMenuToggle or self.openMapAPI==api then return end
    self.openMapAPI=api
    local function add(id,label,get,set)
        api.RegisterMenuToggle('ProfPaden',{id=id,label=label,section='ProfPaden',get=get,set=set})
    end
    add('guide','Profession guide',function()return P.window and P.window:IsShown()end,function(v)
        if not P.char then return end
        if not P.window then P:CreateUI() end
        if v then P:Refresh();P.window:Show() else P.window:Hide() end
    end)
    add('controls','Farming route controls',function()return R.panel and R.panel:IsShown()end,function(v)
        if not P.char then return end
        if v then R:ShowPanel() elseif R.panel then R.panel:Hide() end
    end)
    add('tracking','Waypoint tracking',function()return P:IsNavigationEnabled()end,function(v)P:SetNavigationEnabled(v)end)
    add('follow','Follow farming route',function()return R.enabled==true end,function(v)
        if not P.char then return end
        if v then R:Start() else R:Pause() end
    end)
    if api.RegisterCallback then
        api.RegisterCallback(R,'OpenMap_StitchedChanged',function()R:Draw()end)
        api.RegisterCallback(R,'OpenMap_ViewChanged',function()if R.worldLayer and WorldMapFrame:IsShown() then R:Draw() end end)
    end
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function(_,event,name)if event=='PLAYER_LOGIN' or name=='OpenMap' then R:SetupOpenMap() end end)
R:SetupOpenMap()
