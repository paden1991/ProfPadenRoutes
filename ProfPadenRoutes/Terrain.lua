local _,R=...
local min,max,abs=math.min,math.max,math.abs
local function inside(p,x,y)
    local yes=false;local j=#p
    for i=1,#p do
        local a,b=p[i],p[j]
        if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then yes=not yes end
        j=i
    end
    return yes
end
function R:TerrainContext(map,mode,w,h)
    if mode=='off' then return end
    if not w and C_Map and C_Map.GetMapWorldSize then w,h=C_Map.GetMapWorldSize(map) end
    local mini=self:MiniContext(map,w,h)
    local elevation=self:ElevationContext(map,w,h)
    if not mini and not elevation and not (self.TerrainMaps and self.TerrainMaps[map]) and not (self.SurfaceObstacleMaps and self.SurfaceObstacleMaps[map]) then return end
    local ctx={map=map,weight=mode=='strong' and 16 or mode=='open' and 12 or 4,blockRidges=mode=='open' or mode=='strong',polygons={},cache={},mini=mini,miniCache={},elevation=elevation}
    for _,polys in ipairs({self.TerrainMaps and self.TerrainMaps[map] or {},self.SurfaceObstacleMaps and self.SurfaceObstacleMaps[map] or {}}) do for _,poly in ipairs(polys) do
        local p={points=poly,left=1,right=0,top=1,bottom=0}
        for _,v in ipairs(poly)do p.left=min(p.left,v[1]);p.right=max(p.right,v[1]);p.top=min(p.top,v[2]);p.bottom=max(p.bottom,v[2])end
        ctx.polygons[#ctx.polygons+1]=p
    end end
    return ctx
end
function R:MountainPoint(point,ctx)
    for _,p in ipairs(ctx and ctx.polygons or {}) do
        if point.x>=p.left and point.x<=p.right and point.y>=p.top and point.y<=p.bottom and inside(p.points,point.x,point.y) then return true end
    end
    return false
end
function R:MountainDistance(a,b,w,h,ctx)
    if not ctx then return 0 end
    local cache=ctx.cache
    if cache and cache[a] and cache[a][b]~=nil then return cache[a][b] end
    local dx,dy=b.x-a.x,b.y-a.y;local length=self.Distance(a,b,w,h)
    if length<.00001 then return 0 end
    local cuts={0,1};local polygons={}
    for _,p in ipairs(ctx.polygons)do
        if max(a.x,b.x)>=p.left and min(a.x,b.x)<=p.right and max(a.y,b.y)>=p.top and min(a.y,b.y)<=p.bottom then
            polygons[#polygons+1]=p.points
            local vertices=p.points;local j=#vertices
            for i=1,#vertices do
                local c,d=vertices[j],vertices[i];local ex,ey=d[1]-c[1],d[2]-c[2]
                local den=dx*ey-dy*ex
                if abs(den)>1e-12 then
                    local qx,qy=c[1]-a.x,c[2]-a.y
                    local t,u=(qx*ey-qy*ex)/den,(qx*dy-qy*dx)/den
                    if t>0 and t<1 and u>=0 and u<=1 then cuts[#cuts+1]=t end
                end
                j=i
            end
        end
    end
    -- Split at every boundary, then integrate the union. Overlapping masks
    -- never multiply the penalty; crossings with both ends outside are caught.
    table.sort(cuts);local fraction=0
    for i=2,#cuts do
        local lo,hi=cuts[i-1],cuts[i]
        if hi-lo>1e-12 then
            local t=(lo+hi)/2;local x,y=a.x+t*dx,a.y+t*dy
            for _,p in ipairs(polygons)do if inside(p,x,y)then fraction=fraction+hi-lo;break end end
        end
    end
    local yards=fraction*length
    if cache then
        cache[a]=cache[a] or {};cache[a][b]=yards
        cache[b]=cache[b] or {};cache[b][a]=yards
    end
    return yards
end
function R:TerrainEdge(a,b,w,h,settings)
    if self.AvoidedSegment and self:AvoidedSegment(a,b,settings) or self.WaterSegment and self:WaterSegment(a,b,w,h,settings) then return math.huge end
    local ctx=settings and settings.terrainContext
    local mountain=ctx and self:MountainDistance(a,b,w,h,ctx) or 0
    if ctx and ctx.blockRidges and mountain>.01 then return math.huge end
    -- Avoid counting the same ridge twice where coarse and detailed evidence overlap.
    return self.Distance(a,b,w,h)+max(ctx and ctx.weight*mountain or 0,self:MiniPenalty(a,b,w,h,settings))+self:ElevationEdge(a,b,w,h,settings)
end
function R:MountainLength(points,w,h,settings,start)
    local ctx=settings and settings.terrainContext
    if not ctx then return 0 end
    local total=0
    for i=2,#points do total=total+self:MountainDistance(points[i-1],points[i],w,h,ctx)end
    if start and points[1]then total=total+self:MountainDistance(start,points[1],w,h,ctx)end
    return total
end
function R:PlanningSeconds(points,w,h,settings,start)
    local seconds=self:TravelSeconds(points,w,h,settings,start)
    return seconds+self:TerrainPenalty(points,w,h,settings,start)/settings.speed
end
function R:TerrainPenalty(points,w,h,settings,start)
    local total=0
    for i=2,#points do total=total+self:TerrainEdge(points[i-1],points[i],w,h,settings)-self.Distance(points[i-1],points[i],w,h) end
    if start and points[1] then total=total+self:TerrainEdge(start,points[1],w,h,settings)-self.Distance(start,points[1],w,h) end
    return total
end
function R:RouteDisplay(points,w,h,settings)
    local display=self:Smooth(points,w,h)
    -- A pretty corner must not cut farther into a ridge than the actual path.
    if self:TerrainPenalty(display,w,h,settings)>self:TerrainPenalty(points,w,h,settings)+.01 then return points end
    return display
end
