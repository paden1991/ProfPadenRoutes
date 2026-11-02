local _,R=...
function R:RoadContext(map,w,h,settings)
    local roads=self.RoadMaps and self.RoadMaps[map]
    local clearings=self.OpenGroundMaps and self.OpenGroundMaps[map]
    local ground=self.OpenGroundGrids and self.OpenGroundGrids[map]
    if not roads and not clearings and not ground then return end
    local segments={clearings={},ground=ground,settings=settings}
    for _,road in ipairs(roads or {}) do for i=2,#road.points do
        local a,b=road.points[i-1],road.points[i];local ax,ay,bx,by=a[1]*w,a[2]*h,b[1]*w,b[2]*h
        segments[#segments+1]={ax=ax,ay=ay,dx=bx-ax,dy=by-ay,length2=(bx-ax)^2+(by-ay)^2,left=math.min(ax,bx)-50,right=math.max(ax,bx)+50,top=math.min(ay,by)-50,bottom=math.max(ay,by)+50}
    end end
    -- Prepare polygon bounds once per build, never in the arrow update loop.
    for _,area in ipairs(clearings or {}) do
        local p={points=area.points,left=1,right=0,top=1,bottom=0}
        for _,v in ipairs(area.points) do
            p.left=math.min(p.left,v[1]);p.right=math.max(p.right,v[1])
            p.top=math.min(p.top,v[2]);p.bottom=math.max(p.bottom,v[2])
        end
        segments.clearings[#segments.clearings+1]=p
    end
    return segments
end
function R:RoadWeight(n,w,h,segments)
    if not segments then return 1 end
    local x,y=n.x*w/100,n.y*h/100;local best=2500
    for _,s in ipairs(segments) do
        if x>=s.left and x<=s.right and y>=s.top and y<=s.bottom then
            local dx,dy=x-s.ax,y-s.ay
            local t=s.length2>0 and math.max(0,math.min(1,(dx*s.dx+dy*s.dy)/s.length2)) or 0
            best=math.min(best,(dx-t*s.dx)^2+(dy-t*s.dy)^2)
        end
    end
    local bonus=.25*(1-math.sqrt(best)/50)
    if segments.settings and not self:OpenAnchor({x=n.x/100,y=n.y/100},segments.settings) then return 1 end
    if bonus<.1 and segments.ground then
        local g=segments.ground;local x,y=math.floor(n.x/100*g.size),math.floor(n.y/100*g.size)
        local row=g.rows[y+1]
        if row and x>=0 and x<g.size and row:sub(x+1,x+1)=='1' then bonus=.1 end
    elseif bonus<.1 then
        local nx,ny=n.x/100,n.y/100
        for _,p in ipairs(segments.clearings or {}) do
            if nx>=p.left and nx<=p.right and ny>=p.top and ny<=p.bottom then
                local inside=false;local j=#p.points
                for i=1,#p.points do
                    local a,b=p.points[i],p.points[j]
                    if (a[2]>ny)~=(b[2]>ny) and nx<(b[1]-a[1])*(ny-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
                    j=i
                end
                if inside then bonus=.1;break end
            end
        end
    end
    -- Preferences affect node value only. They cannot lower terrain barriers.
    return 1+bonus
end
