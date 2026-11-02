local _,R=...
local sqrt,min,max=math.sqrt,math.min,math.max
function R:RouteShape(r)
    local p=r.points;local n=#p
    local closed=n>2 and self.Distance(p[1],p[n],r.width,r.height)<.01
    return closed,closed and n-1 or n
end
-- Return the next stop on the nearest ordered segment, its distance in yards,
-- and whether the position is within a closed route outline. Do not mutate it.
function R:Locate(r,pos)
    local p=r.points;local closed,count=self:RouteShape(r)
    if count==0 then return end
    local best,index=math.huge,1
    if count==1 then return 1,self.Distance(pos,p[1],r.width,r.height),false end
    for i=1,#p-1 do
        local a,b=p[i],p[i+1]
        local dx,dy=(b.x-a.x)*r.width,(b.y-a.y)*r.height
        local x,y=(pos.x-a.x)*r.width,(pos.y-a.y)*r.height
        local len=dx*dx+dy*dy
        local t=len>0 and max(0,min(1,(x*dx+y*dy)/len)) or 0
        local d=(x-t*dx)^2+(y-t*dy)^2
        if d<best then best=d;index=t<=.000001 and i or i+1 end
    end
    if closed and index>count then index=1 end
    local inside=false
    if closed then
        local j=count
        for i=1,count do
            local a,b=p[i],p[j]
            if (a.y>pos.y)~=(b.y>pos.y) and pos.x<(b.x-a.x)*(pos.y-a.y)/(b.y-a.y)+a.x then inside=not inside end
            j=i
        end
    end
    return index,sqrt(best),inside
end
function R:InRouteArea(r,pos,margin)
    if self.AvoidedPoint and self:AvoidedPoint(pos,r.settings) or self.WaterPoint and self:WaterPoint(pos,r.settings) then return false end
    local ctx=r.settings and r.settings.terrainContext
    if ctx and ctx.blockRidges and self:MountainPoint(pos,ctx) then return false end
    local index,distance,inside=self:Locate(r,pos)
    return index and (inside or distance<=(margin or 40)),index,distance
end

-- Clip a segment in normalized minimap coordinates to the round or square
-- viewport. Crossings remain visible even when both endpoints are off-screen.
function R:ClipMinimap(ax,ay,bx,by,square)
    local dx,dy=bx-ax,by-ay;local lo,hi=0,1
    if square then
        for _,v in ipairs({{ax,dx},{ay,dy}}) do
            local a,d=v[1],v[2]
            if math.abs(d)<1e-12 then if math.abs(a)>1 then return end
            else local t1,t2=(-1-a)/d,(1-a)/d;if t1>t2 then t1,t2=t2,t1 end;lo=max(lo,t1);hi=min(hi,t2) end
        end
    else
        local a=dx*dx+dy*dy
        if a<1e-12 then return end
        local b=2*(ax*dx+ay*dy);local c=ax*ax+ay*ay-1
        local disc=b*b-4*a*c;if disc<0 then return end
        local root=sqrt(max(0,disc));lo=max(lo,(-b-root)/(2*a));hi=min(hi,(-b+root)/(2*a))
    end
    if hi<=lo then return end
    return ax+lo*dx,ay+lo*dy,ax+hi*dx,ay+hi*dy
end
-- Pixel coordinates are relative to the center, positive y pointing north.
function R:MinimapSegments(r,pos,radius,width,height,facing,square)
    local result={};local c,s=math.cos(facing or 0),math.sin(facing or 0)
    local function project(p)
        local east,north=(p.x-pos.x)*r.width/radius,(pos.y-p.y)*r.height/radius
        return east*c+north*s,north*c-east*s
    end
    local points=r.display or r.points
    for i=1,#points-1 do
        local ax,ay=project(points[i]);local bx,by=project(points[i+1])
        -- Cheap reject before exact clipping.
        if not (min(ax,bx)>1 or max(ax,bx)<-1 or min(ay,by)>1 or max(ay,by)<-1) then
            ax,ay,bx,by=self:ClipMinimap(ax,ay,bx,by,square)
            if ax then result[#result+1]={ax*width/2,ay*height/2,bx*width/2,by*height/2} end
        end
    end
    return result
end
