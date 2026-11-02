local _,R=...
local min,max,floor,sqrt,abs=math.min,math.max,math.floor,math.sqrt,math.abs
local function heapPush(heap,id,f,g)
    local n={id=id,f=f,g=g};local i=#heap+1
    while i>1 do local p=floor(i/2);if heap[p].f<=f then break end;heap[i]=heap[p];i=p end;heap[i]=n
end
local function heapPop(heap)
    local root=heap[1];local tail=table.remove(heap)
    if #heap>0 then local i=1
        while i*2<=#heap do local j=i*2;if j<#heap and heap[j+1].f<heap[j].f then j=j+1 end
            if tail.f<=heap[j].f then break end;heap[i]=heap[j];i=j end
        heap[i]=tail
    end
    return root
end
function R:ContourArea(points,w,h)
    if #points<3 or self.Distance(points[1],points[#points],w,h)>.01 then return 0 end
    local area=0
    for i=2,#points do local a,b=points[i-1],points[i];area=area+(a.x*b.y-b.x*a.y)*w*h end
    if #points>2 then local a,b=points[#points],points[1];area=area+(a.x*b.y-b.x*a.y)*w*h end
    return abs(area)*.5
end
-- Build-time only. Finite trips search locally; unlimited circuits search the
-- zone. Neighboring terrain patches let paths bend around measured cliffs.
function R:ContourGraph(w,h,settings,start)
    local ctx=settings.terrainContext
    if not start or not settings.unlimited and (not ctx or not ctx.elevation) then return end
    local cell=32;local radius=min(1800,max(250,settings.speed*settings.minutes*60*.25))
    if settings.unlimited then
        cell=max(32,math.ceil(sqrt(w*h/20000)/8)*8);radius=sqrt(w*w+h*h)
    end
    if settings.nearbyArea then radius=min(radius,settings.nearbyArea.radius) end
    local g={points={},adj={},cost={},parent={},visited={},cell=cell,radius=radius,expanded=0,edgeTests=0}
    g.offset=settings.unlimited and 256 or 128;g.stride=g.offset*2
    g.joinLimit=settings.unlimited and 22000 or 1600
    local function key(x,y)return (x+g.offset)*g.stride+y+g.offset end
    local function point(x,y)
        if abs(x)>=g.offset or abs(y)>=g.offset then return end
        local id=key(x,y);if g.points[id] then return id end
        local p={x=start.x+x*cell/w,y=start.y+y*cell/h,gx=x,gy=y}
        if p.x<0 or p.x>1 or p.y<0 or p.y>1 or x*x+y*y>(radius/cell)^2 then return end
        if not self:InPlanningArea(p,w,h,settings) then return end
        -- Like the existing detour search, intermediate path points use the
        -- full edge checks. Minimap roughness stays a cost, while mapped
        -- mountains, water, caves and measured cliffs remain hard barriers.
        g.points[id]=p;return id
    end
    local root=point(0,0);if not root then return end
    g.root=root;g.cost[root]=0
    local heap={};heapPush(heap,root,0,0);local limit=settings.speed*settings.minutes*60*.46
    while #heap>0 and g.expanded<(settings.unlimited and 22000 or 2400) do
        local n=heapPop(heap);local id=n.id
        if not g.visited[id] and n.g==g.cost[id] then
            g.visited[id]=true;g.expanded=g.expanded+1
            local p=g.points[id];g.adj[id]=g.adj[id] or {}
            for dx=-1,1 do for dy=-1,1 do if dx~=0 or dy~=0 then
                local nextID=point(p.gx+dx,p.gy+dy)
                if nextID then
                    local edges=g.adj[id];local cost=edges[nextID]
                    if cost==nil then
                        cost=self:TerrainEdge(p,g.points[nextID],w,h,settings);g.edgeTests=g.edgeTests+1
                        edges[nextID]=cost;g.adj[nextID]=g.adj[nextID] or {};g.adj[nextID][id]=cost
                    end
                    local total=n.g+cost
                    if cost<math.huge and total<=limit and (not g.cost[nextID] or total<g.cost[nextID]) then
                        g.cost[nextID]=total;g.parent[nextID]=id;heapPush(heap,nextID,total,total)
                    end
                end
            end end end
        end
    end
    return g
end
local function rootPath(g,id)
    local path={}
    while id do table.insert(path,1,id);id=g.parent[id] end
    return path
end
function R:ContourJoin(g,from,to,w,h,avoid)
    local heap={};local costs={[from]=0};local parent={};local visited=0
    heapPush(heap,from,self.Distance(g.points[from],g.points[to],w,h),0)
    while #heap>0 and visited<(g.joinLimit or 1600) do
        local n=heapPop(heap);local id=n.id
        if n.g==costs[id] then
            if id==to then local out={};while id do table.insert(out,1,id);id=parent[id] end;return out end
            visited=visited+1
            -- Stable neighbor order avoids hash-table-dependent routes.
            local p=g.points[id]
            for dx=-1,1 do for dy=-1,1 do if dx~=0 or dy~=0 then
                local nextID=(p.gx+dx+g.offset)*g.stride+p.gy+dy+g.offset
                local edge=g.adj[id] and g.adj[id][nextID]
                if edge and edge<math.huge and g.visited[nextID] then
                    local cost=n.g+edge*(1+(avoid[nextID] or 0))
                    if not costs[nextID] or cost<costs[nextID] then
                        costs[nextID]=cost;parent[nextID]=id
                        heapPush(heap,nextID,cost+self.Distance(g.points[nextID],g.points[to],w,h),cost)
                    end
                end
            end end end
        end
    end
end
function R:ContourPull(points,w,h,settings)
    local sums={0};for i=2,#points do sums[i]=sums[i-1]+self:TerrainEdge(points[i-1],points[i],w,h,settings) end
    local out={points[1]};local i=1
    while i<#points do
        local nextIndex=i+1
        for j=min(#points,i+20),i+2,-1 do
            if self:TerrainEdge(points[i],points[j],w,h,settings)<=sums[j]-sums[i]+.01 then nextIndex=j;break end
        end
        out[#out+1]=points[nextIndex];i=nextIndex
    end
    return out
end
function R:ContourLoopFrom(original,nodes,w,h,settings,start,playerStart)
    if not (settings.terrainContext and settings.terrainContext.elevation) then return end
    start=start or original[1];local g=self:ContourGraph(w,h,settings,start)
    if not g then return end
    local stats={expanded=g.expanded,edgeTests=g.edgeTests,candidates=0,selected=false}
    local grid={};local side=100
    for _,n in ipairs(nodes) do local key=floor(n.x*w/side)..':'..floor(n.y*h/side);grid[key]=grid[key] or {};grid[key][#grid[key]+1]=n end
    local sectors={};local reach=math.ceil(settings.radius/side);local radius=max(1,settings.radius-6)
    for id in pairs(g.visited) do
        local p=g.points[id];local distance=self.Distance(start,p,w,h)
        if distance>150 then
            local gain=0;local cx,cy=floor(p.x*w/side),floor(p.y*h/side)
            for x=cx-reach,cx+reach do for y=cy-reach,cy+reach do
                for _,n in ipairs(grid[x..':'..y] or {}) do if self.Distance(p,n,w,h)<=radius then gain=gain+(n.weight or 1) end end
            end end
            if gain>0 then
                local angle=math.atan2(p.gy,p.gx);local sector=floor((angle+math.pi)/(math.pi/4))%8+1
                local score=sqrt(gain)*distance/sqrt(max(1,g.cost[id]))
                local old=sectors[sector]
                if not old or score>old.score or score==old.score and id<old.id then sectors[sector]={id=id,score=score} end
            end
        end
    end
    local oldCount,_,oldValue=self:Coverage(self:RouteDisplay(original,w,h,settings),nodes,w,h,settings.radius)
    local function quality(path)
        local display=self:RouteDisplay(path,w,h,settings)
        local count,_,value=self:Coverage(display,nodes,w,h,settings.radius)
        local area=self:ContourArea(path,w,h)
        local seconds=max(self:PlanningSeconds(path,w,h,settings,playerStart),self:PlanningSeconds(display,w,h,settings,playerStart))
        local repeatCost=self:RetraceSeconds(path,w,h,settings,playerStart)
        return value*(1+.15*min(1,sqrt(area)/600))/(1+repeatCost/max(60,seconds)),count,value,area,seconds
    end
    local bestScore=quality(original);local best
    local tried={}
    for i=1,8 do for _,offset in ipairs({2,3,4}) do
        local j=(i+offset-1)%8+1;local a,b=sectors[i],sectors[j]
        local pair=min(i,j)..':'..max(i,j)
        if a and b and not tried[pair] then
            tried[pair]=true
            local outward,back=rootPath(g,a.id),rootPath(g,b.id);local avoid={}
            -- Prefer joining the outer arms of the loop, away from its approach.
            for _,path in ipairs({outward,back}) do for _,id in ipairs(path) do
                local p=g.points[id]
                for dx=-1,1 do for dy=-1,1 do
                    local k=(p.gx+dx+128)*256+p.gy+dy+128
                    avoid[k]=max(avoid[k] or 0,(dx==0 and dy==0) and 3 or .7)
                end end
            end end
            avoid[a.id]=0;avoid[b.id]=0
            local join=self:ContourJoin(g,a.id,b.id,w,h,avoid)
            if join then
                local raw={};for _,id in ipairs(outward)do raw[#raw+1]=g.points[id] end
                for k=2,#join do raw[#raw+1]=g.points[join[k]] end
                for k=#back-1,1,-1 do raw[#raw+1]=g.points[back[k]] end
                local path=self:ContourPull(raw,w,h,settings);stats.candidates=stats.candidates+1
                local score,count,value,area,seconds=quality(path)
                if seconds<=settings.minutes*60 and area>=10000 and count>=oldCount and value>=oldValue-.001 and score>bestScore+.001 then
                    best,bestScore=path,score;stats.covered=count;stats.area=area;stats.planningSeconds=seconds;stats.selected=true
                end
            end
        end
    end end
    return best,stats
end
-- An out-of-zone preview has no player approach. Do not let the first dense
-- pocket choose the only connected component searched for the whole zone.
-- Test a small, spatially distributed set of accessible scan-corridor roots.
function R:ContourPreviewSeeds(original,nodes,w,h,settings)
    local candidates,seen={},{}
    local offset=min(64,settings.radius*.6)
    local offsets={{0,0},{offset,0},{-offset,0},{0,offset},{0,-offset}}
    local function consider(n,dx,dy)
        local p={x=n.x+dx/w,y=n.y+dy/h}
        if p.x<0 or p.x>1 or p.y<0 or p.y>1 then return end
        local key=floor(p.x*w/32)..':'..floor(p.y*h/32)
        if seen[key] then return end;seen[key]=true
        if not self:InPlanningArea(p,w,h,settings) or not self:OpenAnchor(p,settings) then return end
        local open=0
        for x=-1,1 do for y=-1,1 do if x~=0 or y~=0 then
            local q={x=p.x+x*32/w,y=p.y+y*32/h}
            if q.x>=0 and q.x<=1 and q.y>=0 and q.y<=1 and self:TerrainEdge(p,q,w,h,settings)<math.huge then open=open+1 end
        end end end
        if open<3 then return end
        local gain=0
        for _,site in ipairs(nodes)do if self.Distance(p,site,w,h)<=settings.radius then gain=gain+(site.weight or 1) end end
        if gain==0 then return end
        p.score=sqrt(gain)*(open/8)^2;candidates[#candidates+1]=p
    end
    for _,p in ipairs(original)do consider(p,0,0)end
    for _,n in ipairs(nodes)do for _,o in ipairs(offsets)do consider(n,o[1],o[2])end end
    table.sort(candidates,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        if a.x~=b.x then return a.x<b.x end;return a.y<b.y
    end)
    local seeds={};local separation=min(500,max(200,settings.speed*settings.minutes*60*.125))
    for _,p in ipairs(candidates)do
        local separate=true
        for _,seed in ipairs(seeds)do if self.Distance(seed,p,w,h)<separation then separate=false;break end end
        if separate then seeds[#seeds+1]=p;if #seeds==4 then break end end
    end
    return seeds
end
function R:ContourLoop(original,nodes,w,h,settings,start)
    if not (settings.terrainContext and settings.terrainContext.elevation) then return end
    if start then return self:ContourLoopFrom(original,nodes,w,h,settings,start,start) end
    local best=original;local chosen
    local stats={expanded=0,edgeTests=0,candidates=0,seeds=0,selected=false}
    for _,seed in ipairs(self:ContourPreviewSeeds(original,nodes,w,h,settings))do
        local path,trial=self:ContourLoopFrom(best,nodes,w,h,settings,seed,nil)
        stats.seeds=stats.seeds+1
        if trial then
            stats.expanded=stats.expanded+trial.expanded;stats.edgeTests=stats.edgeTests+trial.edgeTests
            stats.candidates=stats.candidates+trial.candidates
            if path then
                best=path;chosen=path;stats.selected=true
                stats.covered=trial.covered;stats.area=trial.area;stats.planningSeconds=trial.planningSeconds
            end
        end
    end
    return chosen,stats
end
