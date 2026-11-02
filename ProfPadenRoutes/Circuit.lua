local _,R=...
local floor,max=math.floor,math.max
-- Unlimited refers to following time, not unlimited CPU work. Build once,
-- retain a bounded terrain graph, and follow the completed circuit every lap.
local function treeJoin(g,from,to)
    local ancestors,out={},{};local id=from
    while id do ancestors[id]=true;id=g.parent[id] end
    local tail={};id=to
    while id and not ancestors[id] do tail[#tail+1]=id;id=g.parent[id] end
    if not id then return end
    local common=id;id=from
    while id~=common do out[#out+1]=id;id=g.parent[id] end
    out[#out+1]=common
    for i=#tail,1,-1 do out[#out+1]=tail[i] end
    return out
end
function R:CircuitTargets(g,nodes,w,h,settings)
    local grid,targets,reachable={},{},{}
    local side=100;local radius=max(1,settings.radius-6)
    for i,n in ipairs(nodes) do
        local key=floor(n.x*w/side)..':'..floor(n.y*h/side)
        grid[key]=grid[key] or {};grid[key][#grid[key]+1]=i
    end
    local ids={};for id in pairs(g.visited) do ids[#ids+1]=id end;table.sort(ids)
    local reach=math.ceil(radius/side)
    for _,id in ipairs(ids) do
        local p=g.points[id];local cover={};local gain=0
        local cx,cy=floor(p.x*w/side),floor(p.y*h/side)
        for x=cx-reach,cx+reach do for y=cy-reach,cy+reach do
            for _,i in ipairs(grid[x..':'..y] or {}) do
                local n=nodes[i]
                if self.Distance(p,n,w,h)<=max(0,radius-(n.spread or 0)) then
                    cover[#cover+1]=i;gain=gain+(n.weight or n.count or 1);reachable[i]=true
                end
            end
        end end
        if gain>0 then targets[#targets+1]={id=id,cover=cover,gain=gain} end
    end
    local chosen,covered={g.root},{}
    for step=1,64 do
        local best,score
        for _,t in ipairs(targets) do
            local gain=0
            for _,i in ipairs(t.cover) do if not covered[i] then gain=gain+(nodes[i].weight or nodes[i].count or 1) end end
            -- Coverage first; gentle travel cost breaks density ties.
            local value=gain/(1+g.cost[t.id]/20000)
            if gain>0 and (not score or value>score) then best,score=t,value end
        end
        if not best then break end
        if best.id~=g.root then chosen[#chosen+1]=best.id end
        for _,i in ipairs(best.cover) do covered[i]=true end
    end
    local count=0;for i in pairs(reachable) do count=count+(nodes[i].count or 1) end
    return chosen,count
end
function R:UnlimitedCircuit(nodes,w,h,settings,start)
    if #nodes==0 then return end
    local seeds=start and {start} or self:ContourPreviewSeeds({},nodes,w,h,settings)
    local graph,targets,reachable
    for i,seed in ipairs(seeds) do
        if i>4 then break end
        local g=self:ContourGraph(w,h,settings,seed)
        if g then
            local chosen,count=self:CircuitTargets(g,nodes,w,h,settings)
            if #chosen>2 and (not reachable or count>reachable) then graph,targets,reachable=g,chosen,count end
        end
    end
    if not graph then return end
    local g=graph
    -- Order the harvest targets cheaply first. Actual connections below always
    -- follow terrain edges, including the final return to the starting point.
    local order={table.remove(targets,1)}
    while #targets>0 do
        local best,distance
        for i,id in ipairs(targets) do
            local d=self.Distance(g.points[order[#order]],g.points[id],w,h)
            if not distance or d<distance then best,distance=i,d end
        end
        order[#order+1]=table.remove(targets,best)
    end
    order[#order+1]=order[1]
    for pass=1,4 do
        local changed=false
        for i=2,#order-2 do for j=i+1,#order-1 do
            local a,b,c,d=g.points[order[i-1]],g.points[order[i]],g.points[order[j]],g.points[order[j+1]]
            if self.Distance(a,c,w,h)+self.Distance(b,d,w,h)+1<self.Distance(a,b,w,h)+self.Distance(c,d,w,h) then
                local left,right=i,j
                while left<right do order[left],order[right]=order[right],order[left];left=left+1;right=right-1 end
                changed=true
            end
        end end
        if not changed then break end
    end
    local points,avoid={},{};local fallbacks=0
    for i=2,#order do
        local path=self:ContourJoin(g,order[i-1],order[i],w,h,avoid)
        if not path then path=treeJoin(g,order[i-1],order[i]);fallbacks=fallbacks+1 end
        if not path then return end
        local raw={}
        for _,id in ipairs(path) do
            local p=g.points[id];raw[#raw+1]=p
            -- A mild 60-yard preference for a fresh corridor, never a barrier.
            local reach=math.ceil(60/g.cell)
            for dx=-reach,reach do for dy=-reach,reach do if (dx*dx+dy*dy)*g.cell*g.cell<=3600 then
                local k=(p.gx+dx+g.offset)*g.stride+p.gy+dy+g.offset;avoid[k]=.18
            end end end
        end
        -- Pull each leg independently so a harvest target cannot be erased by
        -- a shortcut across an inward detour. Reserve 6 yd for display smoothing.
        local leg=self:ContourPull(raw,w,h,settings)
        for j,p in ipairs(leg) do if #points==0 or j>1 then points[#points+1]=p end end
    end
    if #points<4 or self:Length(points,w,h)<150 then return end
    return points,{expanded=g.expanded,edgeTests=g.edgeTests,cell=g.cell,reachable=reachable,targets=#order-1,fallbacks=fallbacks}
end
