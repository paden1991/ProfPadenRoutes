local _,R=...
local floor,ceil,min,max,sqrt=math.floor,math.ceil,math.min,math.max,math.sqrt
function R:MiniContext(map,w,h)
    local data=self.MiniTerrain
    if not data or not w or not h then return end
    local P=ProfPaden
    local c,x0,y0=P:WorldPoint({map=map,x=0,y=0})
    local c1,x1,y1=P:WorldPoint({map=map,x=1,y=0})
    local c2,x2,y2=P:WorldPoint({map=map,x=0,y=1})
    if not x0 or not x1 or not x2 or c~=c1 or c~=c2 or not data.continents[c] then return end
    -- The client has used both vector axis orders; determine east/west from
    -- the map's horizontal basis, never from a hard-coded zone offset.
    local swapped=math.abs(y1-y0)>math.abs(x1-x0)
    local east,north=swapped and y0 or x0,swapped and x0 or y0
    local ew=swapped and y1-y0 or x1-x0
    local ns=swapped and x2-x0 or y2-y0
    -- Unsupported transforms fail open to the existing polygon planner.
    if math.abs(ew+w)>max(2,w*.02) or math.abs(ns+h)>max(2,h*.02) then return end
    return {data=data,pieces=data.continents[c],east=east,north=north,ew=ew,ns=ns,values={},continent=c}
end
function R:MiniValue(ctx,x,y)
    if not ctx then return 9 end
    local d=ctx.data
    local gx=floor((d.origin-ctx.east-x*ctx.ew)/d.cell)
    local gy=floor((d.origin-ctx.north-y*ctx.ns)/d.cell)
    local key=gx*4096+gy
    if ctx.values[key]~=nil then return ctx.values[key] end
    local col,row=floor(gx/64),floor(gy/64)
    local s=ctx.pieces[col*64+row]
    local code=s and string.byte(s,(gy-row*64)*64+(gx-col*64)+1)
    local value=code and code-48 or 9
    ctx.values[key]=value;return value
end
local weights={[0]=0,[1]=.4,[2]=.9,[3]=1.8,[4]=4,[9]=0}
local openWeights={[0]=0,[1]=.6,[2]=1.8,[3]=6,[4]=8,[9]=.5}
function R:MiniPenalty(a,b,w,h,settings)
    local ctx=settings and settings.terrainContext
    if not ctx or not ctx.mini then return 0 end
    local cache=ctx.miniCache
    if cache and cache[a] and cache[a][b] then return cache[a][b] end
    local distance=self.Distance(a,b,w,h);local steps=min(512,max(1,ceil(distance/(ctx.mini.data.cell*.5))))
    local risk=0;local mounted=settings.mode=='mount60' or settings.mode=='mount100'
    for i=1,steps do
        local t=(i-.5)/steps;local v=self:MiniValue(ctx.mini,a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t)
        local costs=ctx.blockRidges and openWeights or weights
        risk=risk+(costs[v] or 0)*(v==4 and mounted and 1.6 or 1)
    end
    risk=distance*risk/steps*(settings.terrain=='strong' and 2 or 1)
    if cache then cache[a]=cache[a] or {};cache[a][b]=risk;cache[b]=cache[b] or {};cache[b][a]=risk end
    return risk
end
-- Bounded A* supplies detours for the selected circuit only. Candidate scoring
-- uses cached straight-edge penalties, avoiding thousands of path searches.
function R:TerrainDetour(a,b,w,h,settings)
    local ctx=settings.terrainContext
    if not ctx or not (ctx.mini or ctx.elevation) or (ctx.searchLeft or 0)<=0 then return {a,b} end
    local straight=self:TerrainEdge(a,b,w,h,settings)
    if straight<self.Distance(a,b,w,h)*1.12 then return {a,b} end
    local cell=ctx.elevation and ctx.elevation.cell or ctx.mini.data.cell
    local cols,rows=ceil(w/cell),ceil(h/cell)
    local function loc(p)return min(cols-1,max(0,floor(p.x*w/cell))),min(rows-1,max(0,floor(p.y*h/cell)))end
    local ax,ay=loc(a);local bx,by=loc(b)
    local first,last=ay*cols+ax,by*cols+bx
    if first==last then return {a,b} end
    local pad=16;local left,right=max(0,min(ax,bx)-pad),min(cols-1,max(ax,bx)+pad)
    local top,bottom=max(0,min(ay,by)-pad),min(rows-1,max(ay,by)+pad)
    local positions={[first]=a,[last]=b}
    local function point(id)
        if not positions[id] then positions[id]={x=min(1,(id%cols+.5)*cell/w),y=min(1,(floor(id/cols)+.5)*cell/h)} end
        return positions[id]
    end
    local heap={};local function push(id,f,g)
        local n={id=id,f=f,g=g};local i=#heap+1
        while i>1 do local p=floor(i/2);if heap[p].f<=f then break end;heap[i]=heap[p];i=p end;heap[i]=n
    end
    local function pop()
        local root=heap[1];local tail=table.remove(heap)
        if #heap>0 then local i=1
            while i*2<=#heap do local j=i*2;if j<#heap and heap[j+1].f<heap[j].f then j=j+1 end
                if tail.f<=heap[j].f then break end;heap[i]=heap[j];i=j end
            heap[i]=tail
        end
        return root
    end
    local costs={[first]=0};local parent={};push(first,self.Distance(a,b,w,h),0)
    local visited=0;local found=false
    while #heap>0 and visited<4000 and ctx.searchLeft>0 do
        local n=pop();local id=n.id
        if n.g==costs[id] then
            if id==last then found=true;break end
            visited=visited+1;ctx.searchLeft=ctx.searchLeft-1
            local x,y=id%cols,floor(id/cols);local from=point(id)
            for dx=-1,1 do for dy=-1,1 do if dx~=0 or dy~=0 then
                local xx,yy=x+dx,y+dy
                if xx>=left and xx<=right and yy>=top and yy<=bottom then
                    local nextID=yy*cols+xx;local dest=point(nextID)
                    local g=n.g+self:TerrainEdge(from,dest,w,h,settings)
                    if g<straight and (not costs[nextID] or g<costs[nextID]) then
                        costs[nextID]=g;parent[nextID]=id;push(nextID,g+self.Distance(dest,b,w,h),g)
                    end
                end
            end end end
        end
    end
    if not found then return {a,b} end
    local raw={};local id=last
    while id do table.insert(raw,1,point(id));id=parent[id] end
    -- String-pull the grid stairs. Only accept shortcuts with no added risk.
    local sums={0};for i=2,#raw do sums[i]=sums[i-1]+self:TerrainEdge(raw[i-1],raw[i],w,h,settings) end
    local out={raw[1]};local i=1
    while i<#raw do
        local nextIndex=i+1
        for j=#raw,i+2,-1 do
            if self:TerrainEdge(raw[i],raw[j],w,h,settings)<=sums[j]-sums[i]+.01 then nextIndex=j;break end
        end
        out[#out+1]=raw[nextIndex];i=nextIndex
    end
    return out
end
function R:RefineTerrain(points,w,h,settings,start)
    local ctx=settings.terrainContext
    if not ctx or not (ctx.mini or ctx.elevation) then return points end
    ctx.searchLeft=16000
    -- Spend the search budget on the player's immediate approach first.
    local approach
    if start and points[1] and self.Distance(start,points[1],w,h)>30 then
        approach=self:TerrainDetour(start,points[1],w,h,settings)
    end
    local out={points[1]}
    for i=2,#points do
        local path=self:TerrainDetour(points[i-1],points[i],w,h,settings)
        for j=2,#path do out[#out+1]=path[j] end
    end
    -- Route the initial approach too; it is followed, not merely drawn.
    if approach then
        if #approach>2 then
            local joined={};for i=2,#approach-1 do joined[#joined+1]=approach[i] end
            for _,p in ipairs(out) do joined[#joined+1]=p end
            out=joined
        end
    end
    return out
end
