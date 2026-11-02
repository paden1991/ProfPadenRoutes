local _,R=...
local floor,ceil,min,max,abs=math.floor,math.ceil,math.min,math.max,math.abs
-- Existing mapped bridge corridor: the ADT below it is lakebed/bank, not
-- the deck. Treat its elevation as unknown; water/cave checks still apply.
-- Half-width in yards. This is not a general road or water exemption.
R.ElevationDecks={[1433]={{a={x=.326,y=.48},b={x=.326,y=.59},halfWidth=9,name='Lakeshire bridge'}}}
function R:ElevationContext(map,w,h)
    local d=self.Heightmaps and self.Heightmaps[map]
    if not d or not w or not h or w<=0 or h<=0 then return end
    -- A UI map rectangle must match the exported yard scale. Never stretch a
    -- heightmap onto a differently sized map (including instance variants).
    if abs(d.worldWidth-w)>max(2,w*.02) or abs(d.worldHeight-h)>max(2,h*.02) then return end
    return {map=map,data=d,w=w,h=h,cell=min(w/d.width,h/d.height),values={},edges={}}
end
local function cell(ctx,x,y)
    local d=ctx.data;local key=y*d.width+x
    local v=ctx.values[key]
    if v~=nil then return v~=false and v or nil end
    local row=d.rows[y+1];local q=row and tonumber(row:sub(x*4+1,x*4+4),16)
    v=q and q>0 and (d.min+(q-1)*(d.max-d.min)/65534) or false
    ctx.values[key]=v;return v~=false and v or nil
end
function R:ElevationAt(ctx,x,y)
    if not ctx or x~=x or y~=y or x<0 or x>1 or y<0 or y>1 then return end
    local d=ctx.data
    -- Bilinear interpolation between cell centers avoids artificial stairs.
    -- Every contributing cell must be valid; unknown terrain is never zero.
    local u,v=max(0,min(d.width-1,x*d.width-.5)),max(0,min(d.height-1,y*d.height-.5))
    local x0,y0=floor(u),floor(v);local x1,y1=min(d.width-1,x0+1),min(d.height-1,y0+1)
    local a,b,c,e=cell(ctx,x0,y0),cell(ctx,x1,y0),cell(ctx,x0,y1),cell(ctx,x1,y1)
    if not a or not b or not c or not e then return end
    local fx,fy=u-x0,v-y0
    return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+e*fx)*fy
end
function R:ElevationFloor(ctx,x,y)
    for _,deck in ipairs(ctx and self.ElevationDecks[ctx.map] or {}) do
        local dx,dy=(deck.b.x-deck.a.x)*ctx.w,(deck.b.y-deck.a.y)*ctx.h
        local px,py=(x-deck.a.x)*ctx.w,(y-deck.a.y)*ctx.h
        local t=(px*dx+py*dy)/(dx*dx+dy*dy)
        if t>=0 and t<=1 and (px-t*dx)^2+(py-t*dy)^2<=deck.halfWidth^2 then return end
    end
    return self:ElevationAt(ctx,x,y)
end
function R:ElevationEdge(a,b,w,h,settings)
    local ctx=settings and settings.terrainContext and settings.terrainContext.elevation
    if not ctx then return 0 end
    local cached=ctx.edges[a] and ctx.edges[a][b];if cached then return cached.cost,cached end
    local distance=self.Distance(a,b,w,h)
    if distance<.001 then return 0 end
    local steps=max(1,ceil(distance/(ctx.cell*.5)));local stride=distance/steps
    local previous=self:ElevationFloor(ctx,a.x,a.y)
    local cost,change,grade,unknown,known=0,0,0,0,0
    for i=1,steps do
        local t=i/steps;local z=self:ElevationFloor(ctx,a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t)
        if z and previous then
            local rise=abs(z-previous);local slope=rise/stride
            change=change+rise;grade=max(grade,slope);known=known+stride
            -- Symmetric: a dangerous descent is not a free shortcut. Large
            -- local slopes are blocked even if the endpoints share a height.
            if slope>.85 then cost=math.huge end
            cost=cost+rise*1.5+stride*max(0,slope-.12)^2*12
        else unknown=unknown+stride end
        previous=z
    end
    -- Missing terrain carries a modest cost; it is not a measured cliff.
    cost=cost+unknown*.35
    if settings.terrain=='strong' then cost=cost*1.5 end
    local record={cost=cost,change=change,maxGrade=grade,knownYards=known,unknownYards=unknown}
    ctx.edges[a]=ctx.edges[a] or {};ctx.edges[a][b]=record
    ctx.edges[b]=ctx.edges[b] or {};ctx.edges[b][a]=record
    return cost,record
end
function R:ElevationCandidates(cells,w,h,settings)
    if not (settings.terrainContext and settings.terrainContext.elevation) then return cells end
    local out={};local offset=min(48,max(12,(settings.radius-36)*.7))
    for _,c in ipairs(cells) do
        out[#out+1]=c
        if self:InPlanningArea(c,w,h,settings) then
            -- Nodes often sit against a steep hillside. The player only needs
            -- to enter the tracking corridor, not stand on the recorded ore.
            -- These are navigation candidates, never new recorded spawns.
            for dx=-1,1 do for dy=-1,1 do if dx~=0 or dy~=0 then
                local p={x=c.x+dx*offset/w,y=c.y+dy*offset/h,id=c.id,offsetAnchor=true,anchorOrder=#out+1}
                if p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 then
                    p.cx,p.cy=floor(p.x*w/20),floor(p.y*h/20);out[#out+1]=p
                end
            end end end
        end
    end
    return out
end
