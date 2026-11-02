local _,R=...
local function number(v)
    return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v==v and math.abs(v)<math.huge
end
R.IsNumber=number
function R:HideMinimap()
    if self.minimapLayer then self.minimapLayer:Hide() end
    self.minimapState=nil
end
function R:UpdateMinimap()
    local r=self.route
    if not self.enabled or not r or not Minimap or not Minimap:IsVisible() then self:HideMinimap();return end
    local pos=self:PlayerPosition(r.map)
    local radius=C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
    if not pos or not number(radius) or radius<=0 then self:HideMinimap();return end
    local get=C_CVar and C_CVar.GetCVar or GetCVar
    local rotating=get and get('rotateMinimap')=='1'
    local facing=0
    if rotating then facing=GetPlayerFacing and GetPlayerFacing() end
    if not number(facing) then self:HideMinimap();return end
    local w,h=Minimap:GetWidth(),Minimap:GetHeight()
    if not number(w) or not number(h) or w<=0 or h<=0 then self:HideMinimap();return end
    local square=GetMinimapShape and GetMinimapShape()=='SQUARE' or false
    local last=self.minimapState
    if last and last.route==r and last.x==pos.x and last.y==pos.y and last.facing==facing and last.radius==radius and last.w==w and last.h==h and last.square==square then return end
    if not self.minimapLayer then
        local f=CreateFrame('Frame',nil,Minimap);self.minimapLayer=f;f.lines={}
        f:SetAllPoints(Minimap);f:SetFrameLevel(Minimap:GetFrameLevel()+1);f:EnableMouse(false)
    end
    local layer=self.minimapLayer;local lines=layer.lines
    -- Keep the two-pixel line inside the rim, including at the clipping edge.
    local segments=self:MinimapSegments(r,pos,radius,w-4,h-4,facing,square)
    for i,xy in ipairs(segments) do
        local line=lines[i]
        if not line then line=layer:CreateLine(nil,'OVERLAY');lines[i]=line;line:SetThickness(2);line:SetColorTexture(1,.8,.18,.95) end
        line:SetStartPoint('CENTER',layer,xy[1],xy[2]);line:SetEndPoint('CENTER',layer,xy[3],xy[4]);line:Show()
    end
    for i=#segments+1,#lines do lines[i]:Hide() end
    layer:SetShown(#segments>0)
    self.minimapState={route=r,x=pos.x,y=pos.y,facing=facing,radius=radius,w=w,h=h,square=square}
    self.minimapDraws=(self.minimapDraws or 0)+1
end
