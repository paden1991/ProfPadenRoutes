local _,R=...
local min,max=math.min,math.max
function R:AvoidanceContext(map,w,h,terrain)
    local boxes={}
    local function add(name,left,top,right,bottom)
        -- A 35-yard margin exceeds the normal 30-yard arrival tolerance.
        boxes[#boxes+1]={name=name,left=left-35/w,right=right+35/w,top=top-35/h,bottom=bottom+35/h}
    end
    if map==1433 then add('Rethban Caverns',.09,.09,.225,.30) end
    local mini=terrain and terrain.mini or self:MiniContext(map,w,h)
    if mini then for _,c in ipairs(self.CaveWorldBounds or {}) do if c.continent==mini.continent then
        local x1,x2=(c.eastMin-mini.east)/mini.ew,(c.eastMax-mini.east)/mini.ew
        local y1,y2=(c.northMin-mini.north)/mini.ns,(c.northMax-mini.north)/mini.ns
        local left,right,top,bottom=min(x1,x2),max(x1,x2),min(y1,y2),max(y1,y2)
        if right>0 and left<1 and bottom>0 and top<1 and right-left<.5 and bottom-top<.5 then add(c.name,left,top,right,bottom) end
    end end end
    return boxes
end
function R:AvoidedPoint(p,settings)
    for _,b in ipairs(settings and settings.avoidance or {}) do
        if p.x>=b.left and p.x<=b.right and p.y>=b.top and p.y<=b.bottom then return b.name end
    end
end
function R:AvoidedSegment(a,b,settings)
    for _,box in ipairs(settings and settings.avoidance or {}) do
        local lo,hi=0,1
        for _,v in ipairs({{a.x,b.x-a.x,box.left,box.right},{a.y,b.y-a.y,box.top,box.bottom}}) do
            local origin,delta,left,right=unpack(v)
            if math.abs(delta)<1e-12 then if origin<left or origin>right then hi=-1;break end
            else
                local t,u=(left-origin)/delta,(right-origin)/delta;if t>u then t,u=u,t end
                lo=max(lo,t);hi=min(hi,u)
            end
        end
        if hi>=lo and hi>=0 and lo<=1 then return box.name end
    end
end
function R:OutdoorNodeSets(sets,settings)
    if #settings.avoidance==0 then return sets,0 end
    local result,skipped={},0
    for _,area in ipairs(sets) do
        local nodes={}
        for _,n in ipairs(area.nodes) do
            if self:AvoidedPoint({x=n.x/100,y=n.y/100},settings) then skipped=skipped+1 else nodes[#nodes+1]=n end
        end
        if #nodes>0 then local a={};for k,v in pairs(area) do a[k]=v end;a.nodes=nodes;result[#result+1]=a end
    end
    return result,skipped
end
function R:OpenAnchor(p,settings)
    if self:AvoidedPoint(p,settings) or self:WaterPoint(p,settings) then return false end
    local ctx=settings.terrainContext
    if ctx and ctx.blockRidges and self:MountainPoint(p,ctx) then return false end
    if ctx and ctx.blockRidges and ctx.mini then
        local code=self:MiniValue(ctx.mini,p.x,p.y)
        if code==3 or code==4 then return false end
    end
    return true
end
