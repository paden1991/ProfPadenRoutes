local _,R=...
local floor,min,max=math.floor,math.min,math.max
function R:WaterContext(map,w,h,terrain)
    local grid=self.WaterMaps and self.WaterMaps[map]
    local mini=terrain and terrain.mini or self:MiniContext(map,w,h)
    local polygons={}
    for _,points in ipairs(self.SurfaceWaterMaps and self.SurfaceWaterMaps[map] or {}) do
        local p={points=points,left=1,right=0,top=1,bottom=0}
        for _,v in ipairs(points)do p.left=min(p.left,v[1]);p.right=max(p.right,v[1]);p.top=min(p.top,v[2]);p.bottom=max(p.bottom,v[2])end
        polygons[#polygons+1]=p
    end
    if grid or mini or #polygons>0 then return {grid=grid,mini=mini,polygons={polygons=polygons},cache={}} end
end
function R:WaterPoint(p,settings)
    local ctx=settings and settings.waterContext;if not ctx then return false end
    if ctx.polygons and self:MountainPoint(p,ctx.polygons) then return true end
    if ctx.grid then
        local n=ctx.grid.size;local x,y=floor(p.x*n),floor(p.y*n)
        local row=ctx.grid.rows[y+1]
        return row and x>=0 and x<n and row:sub(x+1,x+1)=='1' or false
    end
    return ctx.mini and self:MiniValue(ctx.mini,p.x,p.y)==4 or false
end
function R:WaterSegment(a,b,w,h,settings)
    local ctx=settings and settings.waterContext;if not ctx then return false end
    local cache=ctx.cache
    if cache and cache[a] and cache[a][b]~=nil then return cache[a][b] end
    local wet=ctx.polygons and self:MountainDistance(a,b,w,h,ctx.polygons)>.001 or false
    if not wet and ctx.grid then
        -- Supercover grid traversal: no thin-water gaps between sample points.
        local n=ctx.grid.size;local x,y=floor(a.x*n),floor(a.y*n)
        local ex,ey=floor(b.x*n),floor(b.y*n);local dx,dy=(b.x-a.x)*n,(b.y-a.y)*n
        local sx,sy=dx>=0 and 1 or -1,dy>=0 and 1 or -1
        local tx=dx==0 and math.huge or ((sx>0 and x+1 or x)-a.x*n)/dx
        local ty=dy==0 and math.huge or ((sy>0 and y+1 or y)-a.y*n)/dy
        local ix,iy=dx==0 and math.huge or math.abs(1/dx),dy==0 and math.huge or math.abs(1/dy)
        local function water(xx,yy)local row=ctx.grid.rows[yy+1];return row and xx>=0 and xx<n and row:sub(xx+1,xx+1)=='1' end
        for step=1,2*n+4 do
            if water(x,y) then wet=true;break end
            if x==ex and y==ey then break end
            if math.abs(tx-ty)<1e-10 then
                if water(x+sx,y) or water(x,y+sy) then wet=true;break end
                x,y,tx,ty=x+sx,y+sy,tx+ix,ty+iy
            elseif tx<ty then x,tx=x+sx,tx+ix else y,ty=y+sy,ty+iy end
        end
    elseif not wet and ctx.mini then
        local steps=max(1,math.ceil(self.Distance(a,b,w,h)/(ctx.mini.data.cell*.4)))
        for i=0,steps do local t=i/steps
            if self:MiniValue(ctx.mini,a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t)==4 then wet=true;break end
        end
    end
    if cache then cache[a]=cache[a] or {};cache[a][b]=wet;cache[b]=cache[b] or {};cache[b][a]=wet end
    return wet
end
