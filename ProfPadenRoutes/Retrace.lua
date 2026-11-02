local _,R=...
local min,max,sqrt,abs,ceil=math.min,math.max,math.sqrt,math.abs,math.ceil
-- Route-selection preference only. Never a movement restriction or extra ETA.
R.RetraceWeight=.18
local radius,horizon=60,90
function R:RetraceSeconds(points,w,h,settings,start)
    if (self.RetraceWeight or 0)<=0 or #points<2 then return 0 end
    local segments={};local along=0
    local function add(a,b)
        local ax,ay=a.x*w,a.y*h;local dx,dy=(b.x-a.x)*w,(b.y-a.y)*h
        local length=sqrt(dx*dx+dy*dy)
        if length>.01 then
            segments[#segments+1]={ax=ax,ay=ay,dx=dx,dy=dy,length=length,along=along}
            along=along+length
        end
    end
    if start then add(start,points[1]) end
    for i=2,#points do add(points[i-1],points[i]) end
    local repeated=0;local reach=horizon*settings.speed
    for i=2,#segments do
        local current=segments[i]
        local steps=min(32,max(1,ceil(current.length/20)))
        for k=1,steps do
            local t=(k-.5)/steps;local x,y=current.ax+current.dx*t,current.ay+current.dy*t
            local at=current.along+current.length*t;local best=0
            for j=i-1,1,-1 do
                local old=segments[j]
                if at-(old.along+old.length)>reach then break end
                local alignment=abs(current.dx*old.dx+current.dy*old.dy)/(current.length*old.length)
                if alignment>.75 then
                    local u=((x-old.ax)*old.dx+(y-old.ay)*old.dy)/(old.length*old.length)
                    -- Do not penalize fresh road beyond a shared endpoint.
                    if u>=0 and u<=1 then
                        local dx,dy=x-old.ax-old.dx*u,y-old.ay-old.dy*u
                        local d2=dx*dx+dy*dy;local age=at-(old.along+old.length*u)
                        if d2<radius*radius and age>0 and age<reach then
                            best=max(best,(1-sqrt(d2)/radius)*(1-age/reach)*(alignment-.75)*4)
                        end
                    end
                end
            end
            -- Count a repeated stretch once, even if several earlier legs overlap.
            repeated=repeated+current.length/steps*best
        end
    end
    return repeated*self.RetraceWeight/settings.speed
end
function R:SelectionSeconds(points,w,h,settings,start)
    return self:PlanningSeconds(points,w,h,settings,start)+self:RetraceSeconds(points,w,h,settings,start)
end
function R:ImproveRetracing(points,nodes,w,h,settings,start)
    -- Bounded build-time polish. Every accepted reorder keeps coverage and obeys
    -- the real trip budget and all terrain barriers. Never runs from OnUpdate.
    if #points<5 or (self.RetraceWeight or 0)<=0 then return points end
    local budget=settings.minutes*60;local attempts=0
    local count,_,preferred=self:Coverage(points,nodes,w,h,settings.radius-6)
    for pass=1,2 do
        local penalty=self:RetraceSeconds(points,w,h,settings,start)
        if penalty<.25 then break end
        local score=self:PlanningSeconds(points,w,h,settings,start)+penalty
        local winner,winnerScore
        for i=2,#points-2 do for j=i+1,#points-1 do
            if attempts>=96 then break end
            local before=self:TerrainEdge(points[i-1],points[i],w,h,settings)+self:TerrainEdge(points[j],points[j+1],w,h,settings)
            local after=self:TerrainEdge(points[i-1],points[j],w,h,settings)+self:TerrainEdge(points[i],points[j+1],w,h,settings)
            if after<math.huge and (after-before)/settings.speed<=penalty+settings.turn*2 then
                attempts=attempts+1;local trial={}
                for k,p in ipairs(points) do trial[k]=(k>=i and k<=j) and points[j-(k-i)] or p end
                local planning=self:PlanningSeconds(trial,w,h,settings,start)
                if planning<=budget then
                    local cost=planning+self:RetraceSeconds(trial,w,h,settings,start)
                    if cost+.05<(winnerScore or score) then
                        local covered,_,value=self:Coverage(trial,nodes,w,h,settings.radius-6)
                        if covered>=count and value>=preferred-.001 then winner,winnerScore=trial,cost end
                    end
                end
            end
        end;if attempts>=96 then break end end
        if not winner then break end
        points=winner;count,_,preferred=self:Coverage(points,nodes,w,h,settings.radius-6)
    end
    return points
end
