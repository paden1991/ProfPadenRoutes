local _,R=...
local sqrt,floor,min,max=math.sqrt,math.floor,math.min,math.max
-- Planning assumptions, not live detection or changes to player movement.
R.TravelModes={foot={label='On foot',speed=7,turn=3},walk={label='Slow walk',speed=2.5,turn=3},mount60={label='Mounted +60%',speed=11.2,turn=6},mount100={label='Mounted +100%',speed=14,turn=7}}
function R:Settings(prof)
    local saved=ProfPaden.char and ProfPaden.char.walkingSettings or {}
    local mode=self.TravelModes[saved.mode] and saved.mode or 'foot'
    local radius=(saved.radius==60 or saved.radius==150) and saved.radius or 100
    local terrain=(saved.terrain=='off' or saved.terrain=='strong') and saved.terrain or 'open'
    local scope=saved.scope=='zone' and 'zone' or 'near'
    local unlimited=saved.minutes=='unlimited'
    if unlimited then scope='zone' end
    local nodeRadius=radius
    if prof and prof~='Mining' and prof~='Herbalism' then radius=40 end
    local minutes=(saved.minutes==5 or saved.minutes==20) and saved.minutes or 10
    if unlimited then minutes=math.huge end
    return {unlimited=unlimited,scope=scope,mode=mode,terrain=terrain,radius=radius,nodeRadius=nodeRadius,minutes=minutes,speed=self.TravelModes[mode].speed,turn=self.TravelModes[mode].turn,label=self.TravelModes[mode].label}
end
local function segment(p,a,b,w,h)
    local dx,dy=(b.x-a.x)*w,(b.y-a.y)*h
    local x,y=(p.x-a.x)*w,(p.y-a.y)*h
    local len=dx*dx+dy*dy;local t=len>0 and max(0,min(1,(x*dx+y*dy)/len)) or 0
    return (x-t*dx)^2+(y-t*dy)^2
end
function R:Coverage(points,nodes,w,h,radius)
    local covered,weight,segments,preference={},0,{},0
    for i=1,max(1,#points-1) do
        local a,b=points[i],points[i+1] or points[i]
        if a then
            local ax,ay,bx,by=a.x*w,a.y*h,b.x*w,b.y*h;local dx,dy=bx-ax,by-ay
            segments[#segments+1]={ax,ay,dx,dy,dx*dx+dy*dy,min(ax,bx),max(ax,bx),min(ay,by),max(ay,by)}
        end
    end
    for i,n in ipairs(nodes) do
        local r=max(0,radius-(n.spread or 0));local limit=r*r;local x,y=n.x*w,n.y*h;local found=false
        for _,s in ipairs(segments) do
            if x>=s[6]-r and x<=s[7]+r and y>=s[8]-r and y<=s[9]+r then
                local px,py=x-s[1],y-s[2];local t=s[5]>0 and max(0,min(1,(px*s[3]+py*s[4])/s[5])) or 0
                if (px-t*s[3])^2+(py-t*s[4])^2<=limit then found=true;break end
            end
        end
        if found then covered[i]=true;weight=weight+(n.count or 1);preference=preference+(n.weight or n.count or 1) end
    end
    return weight,covered,preference
end
function R:SpawnCells(sets,w,h,harvestIndex,roadContext)
    local seen,unique,cells,order={},{},{},{}
    local observations,mergedNearby=0,0
    local supplemental=false
    for _,area in ipairs(sets) do if area.provider=='gathermate-forever' then supplemental=true;break end end
    local nearby={}
    for _,area in ipairs(sets) do for _,n in ipairs(area.nodes) do
        observations=observations+(n.observations or 1)
        -- Repeated coordinates from different source records are not extra spawns.
        local key=(area.sourceKind or '')..string.format('%.3f:%.3f',n.x,n.y)
        local object=supplemental and area.sourceKind=='object'
        local px,py=n.x*w/100,n.y*h/100
        local bx,by=floor(px/15),floor(py/15);local duplicate=seen[key]
        -- GatherMate uses 15 yd cleanup for harvest sites. Deduplicate in a
        -- temporary spatial hash; keep the first actual position, never average.
        -- Do not merge nearby creatures, which may genuinely spawn in groups.
        if object and not duplicate then
            for dx=-1,1 do for dy=-1,1 do
                for _,p in ipairs(nearby[(bx+dx)..':'..(by+dy)] or {}) do
                    if (p[1]-px)^2+(p[2]-py)^2<=225 then duplicate=true;break end
                end
            end end
            if duplicate then mergedNearby=mergedNearby+1 end
        end
        if not duplicate then
            seen[key]=true
            if object then
                local k=bx..':'..by;nearby[k]=nearby[k] or {};nearby[k][#nearby[k]+1]={px,py}
            end
            local p={x=n.x/100,y=n.y/100,id=n.id,weight=self:HarvestWeight(area,n,w,h,harvestIndex)*self:RoadWeight(n,w,h,roadContext)};unique[#unique+1]=p
            local cx,cy=floor(p.x*w/20),floor(p.y*h/20);local k=cx..':'..cy
            local cell=cells[k]
            if not cell then cell={cx=cx,cy=cy,members={},count=0,weight=0,sx=0,sy=0};cells[k]=cell;order[#order+1]=cell end
            cell.members[#cell.members+1]=p;cell.count=cell.count+1;cell.weight=cell.weight+p.weight;cell.sx=cell.sx+p.x;cell.sy=cell.sy+p.y
        end
    end end
    -- Actual observed representative nearest the local mean, never a fabricated center.
    for _,c in ipairs(order) do
        local center={x=c.sx/c.count,y=c.sy/c.count};local representative=c.members[1]
        for _,p in ipairs(c.members) do
            local a,b=self.Distance(p,center,w,h),self.Distance(representative,center,w,h)
            if a<b or a==b and p.id<representative.id then representative=p end
        end
        c.x,c.y,c.id=representative.x,representative.y,representative.id;c.spread=0
        for _,p in ipairs(c.members) do c.spread=max(c.spread,self.Distance(c,p,w,h)) end
    end
    table.sort(order,function(a,b)return a.id<b.id end)
    for i,c in ipairs(order) do c.number=i end
    return order,unique,cells,observations,mergedNearby
end
local function closed(points)
    local out={};for _,p in ipairs(points) do out[#out+1]=p end
    if #out>1 then out[#out+1]=out[1] end;return out
end
function R:TravelSeconds(points,w,h,settings,start)
    local distance=self:Length(points,w,h)
    local approach=start and #points>0 and self.Distance(start,points[1],w,h) or 0
    local turns=0
    for i=2,#points-1 do
        local a,b,c=points[i-1],points[i],points[i+1]
        local ab,bc=self.Distance(a,b,w,h),self.Distance(b,c,w,h)
        if ab>0 and bc>0 then
            local dot=((b.x-a.x)*(c.x-b.x)*w*w+(b.y-a.y)*(c.y-b.y)*h*h)/(ab*bc)
            turns=turns+math.acos(max(-1,min(1,dot)))/math.pi
        end
    end
    return (distance+approach)/settings.speed+turns*settings.turn,approach
end
function R:OptimizeCircuit(points,w,h,settings)
    for pass=1,4 do
        local changed=false
        for i=2,#points-2 do for j=i+1,#points-1 do
            local before=self:TerrainEdge(points[i-1],points[i],w,h,settings)+self:TerrainEdge(points[j],points[j+1],w,h,settings)
            local after=self:TerrainEdge(points[i-1],points[j],w,h,settings)+self:TerrainEdge(points[i],points[j+1],w,h,settings)
            if after+.01<before then
                local a,b=i,j;while a<b do points[a],points[b]=points[b],points[a];a=a+1;b=b-1 end;changed=true
            end
        end end
        if not changed then break end
    end
end
function R:SimplifyCoverage(points,nodes,w,h,settings,start)
    -- Remove needless zigzags only when every previously covered location stays
    -- inside the tracking corridor. Keep the entry anchor and observed turns.
    local radius=max(1,settings.radius-6)^2;local hits={}
    for k,n in ipairs(nodes) do
        local count=0;for j=2,#points do if segment(n,points[j-1],points[j],w,h)<=radius then count=count+1 end end;hits[k]=count
    end
    local selection=self:SelectionSeconds(points,w,h,settings,start)
    for pass=1,2 do
        local changed=false
        for i=#points-1,2,-1 do
            local trial={};for j,p in ipairs(points) do if j~=i then trial[#trial+1]=p end end
            if #trial==2 and trial[1]==trial[2] then table.remove(trial) end
            local a,b,c=points[i-1],points[i],points[i+1];local changes={};local keeps=true
            -- Only two old segments and one replacement change. Rechecking the
            -- whole route for every removal made large spawn sets needlessly slow.
            for key,n in ipairs(nodes) do
                local count=hits[key]-(segment(n,a,b,w,h)<=radius and 1 or 0)-(segment(n,b,c,w,h)<=radius and 1 or 0)+(segment(n,a,c,w,h)<=radius and 1 or 0)
                if hits[key]>0 and count==0 then keeps=false;break end;changes[key]=count
            end
            if keeps and self:PlanningSeconds(trial,w,h,settings,start)<=settings.minutes*60 then
                local cost=self:SelectionSeconds(trial,w,h,settings,start)
                if cost<=selection then points=trial;hits=changes;selection=cost;changed=true end
            end
        end
        if not changed then break end
    end
    return points
end
-- Bound the candidate area before density optimization; source points stay intact.
-- The local radius is a quarter of the trip's straight-line travel allowance.
function R:NearbyArea(cells,w,h,start,settings)
    if settings.scope~='near' or not start then return end
    local radius=min(1600,max(250,settings.speed*settings.minutes*60*.25))
    local nearest,effort,hasLocal
    for _,c in ipairs(cells) do
        local cost=self:TerrainEdge(start,c,w,h,settings)
        if cost/settings.speed<=settings.minutes*60 then
            if not effort or cost<effort or cost==effort and c.id<nearest.id then nearest,effort=c,cost end
            if self.Distance(start,c,w,h)<=radius then hasLocal=true end
        end
    end
    -- If there are no affordable local records, use the nearest affordable area.
    -- The complete approach still counts against the trip budget.
    return {center=hasLocal and start or nearest or start,radius=radius,fallback=not hasLocal}
end
function R:InPlanningArea(point,w,h,settings)
    local area=settings.nearbyArea
    return not area or self.Distance(area.center,point,w,h)<=area.radius
end
function R:NearestEntry(points,w,h,settings,start)
    if not start or #points<2 then return points end
    local loop=self.Distance(points[1],points[#points],w,h)<.01
    local count=loop and #points-1 or #points
    local index=1
    if loop then
        for i=2,count do
            if self:TerrainEdge(start,points[i],w,h,settings)<self:TerrainEdge(start,points[index],w,h,settings) then index=i end
        end
        local out={};for i=0,count-1 do out[#out+1]=points[(index+i-1)%count+1] end
        out=closed(out)
        return self:PlanningSeconds(out,w,h,settings,start)<=settings.minutes*60 and out or points
    elseif self:TerrainEdge(start,points[#points],w,h,settings)<self:TerrainEdge(start,points[1],w,h,settings) then
        local out={};for i=#points,1,-1 do out[#out+1]=points[i] end
        return self:PlanningSeconds(out,w,h,settings,start)<=settings.minutes*60 and out or points
    end
    return points
end
function R:DensityCircuit(cells,grid,w,h,start,settings)
    -- Reserve arrival/fillet slack: turning early must not invalidate coverage.
    local radius=max(30,settings.radius-36);local reach=math.ceil(settings.radius/20)+1
    local candidates={}
    for _,c in ipairs(self:ElevationCandidates(cells,w,h,settings)) do
        c.cover={};c.gain=0
        for x=c.cx-reach,c.cx+reach do for y=c.cy-reach,c.cy+reach do
            local other=grid[x..':'..y]
            if other and self.Distance(c,other,w,h)<=max(0,radius-other.spread) then
                c.cover[#c.cover+1]=other.number;c.gain=c.gain+(other.weight or other.count)
            end
        end end
        -- A wide cell can still anchor its own observed location.
        if c.gain==0 and not c.offsetAnchor then c.cover={c.number};c.gain=c.weight or c.count end
        local approach=start and self:TerrainEdge(start,c,w,h,settings)/settings.speed or 0
        c.priority=c.gain/(20+approach)
        if c.gain>0 and self:InPlanningArea(c,w,h,settings) and self:OpenAnchor(c,settings) then candidates[#candidates+1]=c end
    end
    table.sort(candidates,function(a,b)if a.priority~=b.priority then return a.priority>b.priority end;if a.id~=b.id then return a.id<b.id end;return (a.anchorOrder or 0)<(b.anchorOrder or 0) end)
    -- Keep the best density/travel scores inside the chosen planning area.
    while #candidates>192 do table.remove(candidates) end
    local stops,covered,used={},{},{};local budget=settings.minutes*60
    for step=1,64 do
        local best,bestScore,bestAt
        local current=closed(stops);local currentTime=self:PlanningSeconds(current,w,h,settings,start)
        for _,c in ipairs(candidates) do if not used[c] then
            local gain=0;for _,i in ipairs(c.cover) do if not covered[i] then gain=gain+(cells[i].weight or cells[i].count) end end
            if gain>0 then
                local at,extra=1,0
                if #stops>0 then
                    extra=math.huge
                    for j=1,#stops do
                        local a,b=stops[j],stops[j%#stops+1]
                        local d=self:TerrainEdge(a,c,w,h,settings)+self:TerrainEdge(c,b,w,h,settings)-self:TerrainEdge(a,b,w,h,settings)
                        if d<extra then extra=d;at=j+1 end
                    end
                end
                local estimate=#stops==0 and (start and self:TerrainEdge(start,c,w,h,settings)/settings.speed or 0) or currentTime+extra/settings.speed+settings.turn
                if estimate<=budget then
                    local score=gain/(12+max(0,estimate-currentTime))
                    if not bestScore or score>bestScore or score==bestScore and c.id<best.id then best,bestAt,bestScore=c,at,score end
                end
            end
        end end
        if not best then break end
        table.insert(stops,bestAt,best);used[best]=true
        if self:PlanningSeconds(closed(stops),w,h,settings,start)>budget then table.remove(stops,bestAt) end
        local _,newCovered=self:Coverage(closed(stops),cells,w,h,radius);covered=newCovered
    end
    local points=closed(stops);local original=closed(stops);self:OptimizeCircuit(points,w,h,settings)
    if self:PlanningSeconds(points,w,h,settings,start)>budget then points=original end
    return self:NearestEntry(points,w,h,settings,start)
end
function R:Build(entry,map,w,h,start,prof)
    local P=ProfPaden
    local positionUsed=start~=nil;local previewStart
    if not w or not h or w<=0 or h<=0 then return nil,'Map distance data is unavailable in this zone.' end
    local sets=P:GetGatherNodeSets(entry.key,map);local onlyOpenWater=#sets>0
    for _,area in ipairs(sets) do if area.method~='Open water' then onlyOpenWater=false end end
    if onlyOpenWater then return nil,'These are open-water catch locations, not walking stops. Select a fishing pool.' end
    local settings=self:Settings(prof);settings.terrainContext=self:TerrainContext(map,settings.terrain,w,h)
    settings.avoidance=self:AvoidanceContext(map,w,h,settings.terrainContext)
    settings.waterContext=self:WaterContext(map,w,h,settings.terrainContext)
    if start and self:WaterPoint(start,settings) then return nil,"Move onto dry ground, then rebuild the walking route." end
    local blocked=start and self:AvoidedPoint(start,settings)
    if blocked then return nil,'Move into open terrain outside '..blocked..', then rebuild the route.' end
    local skipped;sets,skipped=self:OutdoorNodeSets(sets,settings)
    local cells,nodes,grid,observations,mergedNearby=self:SpawnCells(sets,w,h,self:HarvestIndex(map,w,h),self:RoadContext(map,w,h,settings))
    local atlas,gatherMate=false,false
    for _,area in ipairs(sets) do
        if area.provider=='gathermate-forever' then gatherMate=true else atlas=true end
    end
    local sourceSummary=gatherMate and (atlas and 'Atlas + GatherMate (Forever)' or 'GatherMate (Forever)') or 'ProfPaden atlas'
    if #nodes==0 then return nil,skipped>0 and 'The recorded sites here are in cave areas. Choose another outdoor area.' or 'This material has no recorded points in this area. Choose another area.' end
    if not start then
        previewStart=self:FlightStarts(map,w,h,settings,nodes)[1]
        if previewStart then start=previewStart end
    end
    local points,kind,source,coverage,seconds,planning
    if settings.unlimited then
        local stats
        points,stats=self:UnlimitedCircuit(nodes,w,h,settings,start)
        if not points then return nil,'No connected outdoor circuit was found from here. Move to open ground or choose another area.' end
        settings.circuitStats=stats;kind='Unlimited farming circuit'
    else
    settings.nearbyArea=self:NearbyArea(cells,w,h,start,settings)
    points=self:DensityCircuit(cells,grid,w,h,start,settings)
    if #points<3 and settings.terrainContext and settings.terrainContext.elevation then
        -- A straight approach may cross a cliff although a curved approach is
        -- possible. Use the existing terrain circuit only as a search seed;
        -- every resulting leg must then pass the full elevation-aware search.
        local ctx=settings.terrainContext;local elevation=ctx.elevation
        ctx.elevation=nil
        local budget=settings.minutes;settings.minutes=budget*.6
        local seed=self:DensityCircuit(cells,grid,w,h,start,settings)
        ctx.elevation=elevation;settings.minutes=budget
        if #seed>0 then
            local detour=self:RefineTerrain(seed,w,h,settings,start)
            if self:PlanningSeconds(detour,w,h,settings,start)<=settings.minutes*60 and
                self:Coverage(detour,nodes,w,h,settings.radius-6)>self:Coverage(points,nodes,w,h,settings.radius-6) then points=detour end
        end
    end
    if #points==0 and start and settings.terrainContext then
        -- Straight-edge scoring can reject every site beside a cliff even
        -- when a safe approach exists. Search a bounded set of real sites
        -- using the same terrain/cave/water rules as the final route.
        local candidates={}
        for _,cell in ipairs(cells) do
            local distance=self.Distance(start,cell,w,h)
            if distance/settings.speed<=settings.minutes*60 and self:InPlanningArea(cell,w,h,settings) then
                candidates[#candidates+1]={point=cell,distance=distance}
            end
        end
        table.sort(candidates,function(a,b)return a.distance<b.distance or a.distance==b.distance and a.point.id<b.point.id end)
        settings.terrainContext.searchLeft=16000
        for i=1,min(8,#candidates) do
            local path=self:TerrainDetour(start,candidates[i].point,w,h,settings)
            local trial={};for j=2,#path do trial[#trial+1]=path[j] end
            if #trial>0 and self:PlanningSeconds(trial,w,h,settings,start)<=settings.minutes*60 then
                points=trial;break
            end
        end
    end
    points=self:SimplifyCoverage(points,nodes,w,h,settings,start)
    kind,source=settings.nearbyArea and (settings.nearbyArea.fallback and 'Closest recorded area' or 'Nearby spawn circuit') or 'Dense spawn circuit',nil
    local preference,unused
    coverage,unused,preference=self:Coverage(points,nodes,w,h,settings.radius-6)
    seconds=self:TravelSeconds(points,w,h,settings,start)
    planning=self:PlanningSeconds(points,w,h,settings,start)
    -- Reference corridors remain candidates, but must cover actual spawn density
    -- within the same radius/time budget. Sample full segments, not just turns.
    local seen={}
    for _,bands in ipairs({P.GatherVisuals[prof] or {},P.GatherVisuals.Mining or {},P.GatherVisuals.Herbalism or {}}) do
        for _,list in ipairs(bands) do for _,guide in ipairs(list) do
            if guide.mapId==map and #(guide.points or {})>2 and not seen[guide] then
                seen[guide]=true;local raw={}
                for _,xy in ipairs(guide.points) do local n={x=xy[1]/100,y=xy[2]/100};if #raw==0 or self.Distance(n,raw[#raw],w,h)>4 then raw[#raw+1]=n end end
                if #raw>2 and self.Distance(raw[1],raw[#raw],w,h)<80 then
                    if self.Distance(raw[1],raw[#raw],w,h)<4 then table.remove(raw) end
                    local closest=1
                    if start then for i=2,#raw do if self.Distance(start,raw[i],w,h)<self.Distance(start,raw[closest],w,h) then closest=i end end end
                    local rotated={};for i=0,#raw-1 do rotated[#rotated+1]=raw[(closest+i-1)%#raw+1] end;raw=closed(rotated)
                elseif start and self.Distance(start,raw[1],w,h)>self.Distance(start,raw[#raw],w,h) then
                    local rev={};for i=#raw,1,-1 do rev[#rev+1]=raw[i] end;raw=rev
                end
                raw=self:NearestEntry(raw,w,h,settings,start)
                local localGuide=true;for _,p in ipairs(raw) do if not self:InPlanningArea(p,w,h,settings) then localGuide=false;break end end
                if #points<3 and localGuide and settings.terrainContext and settings.terrainContext.elevation and
                    self:TravelSeconds(raw,w,h,settings,start)<=settings.minutes*60 then
                    raw=self:RefineTerrain(raw,w,h,settings,start)
                end
                local count,_,preferred=self:Coverage(raw,nodes,w,h,settings.radius-6);local time=self:TravelSeconds(raw,w,h,settings,start)
                local effort=self:PlanningSeconds(raw,w,h,settings,start)
                local score=preferred/(1+(math.max(0,effort-time)+self:RetraceSeconds(raw,w,h,settings,start))/60)
                local bestScore=preference/(1+(math.max(0,planning-seconds)+self:RetraceSeconds(points,w,h,settings,start))/60)
                if localGuide and effort<=settings.minutes*60 and (score>bestScore or score==bestScore and effort<planning) then
                    planning=effort;preference=preferred
                    points,coverage,seconds,kind,source=raw,count,time,settings.nearbyArea and (settings.nearbyArea.fallback and 'Closest recorded guide' or 'Nearby guide circuit') or 'Classic guide circuit',guide.url
                end
            end
        end end
    end
    points=self:ImproveRetracing(points,nodes,w,h,settings,start)
    local refined=self:RefineTerrain(points,w,h,settings,start)
    if self:PlanningSeconds(refined,w,h,settings,start)<=settings.minutes*60 and
        self:SelectionSeconds(refined,w,h,settings,start)<=self:SelectionSeconds(points,w,h,settings,start)+.01 then points=refined end
    points=self:NearestEntry(points,w,h,settings,start)
    local expanded,contour=self:ContourLoop(points,nodes,w,h,settings,start)
    if expanded then points=expanded;kind='Contour farming loop';source=nil end
    settings.contourStats=contour
    end
    if #points==0 then return nil,'No open-terrain route fits this travel budget from here. Move to open ground or increase Trip.' end
    planning=self:PlanningSeconds(points,w,h,settings,start);seconds=self:TravelSeconds(points,w,h,settings,start)
    local display=self:RouteDisplay(points,w,h,settings)
    if planning==math.huge or self:PlanningSeconds(display,w,h,settings,start)==math.huge then
        return nil,'No route around the mapped caves, water or mountain areas was found from here. Move to open ground and rebuild.'
    end
    coverage=self:Coverage(display,nodes,w,h,settings.radius)
    local _,approach=self:TravelSeconds(points,w,h,settings,start)
    local mountainYards=self:MountainLength(points,w,h,settings,start)
    if settings.waterContext then settings.waterContext.cache=nil end
    if settings.terrainContext then settings.terrainContext.cache=nil;settings.terrainContext.miniCache=nil
        if settings.terrainContext.elevation then settings.terrainContext.elevation.edges={} end
    end
    return {entryKey=entry.key,name=entry.name,map=map,profession=prof,points=points,display=display,width=w,height=h,avoidedCaveRecords=skipped,
        kind=kind,source=source,positionUsed=positionUsed,previewStart=previewStart,nearbyRadius=settings.nearbyArea and settings.nearbyArea.radius,nearbyFallback=settings.nearbyArea and settings.nearbyArea.fallback,mountainYards=mountainYards,retraceSeconds=self:RetraceSeconds(points,w,h,settings,start),planningSeconds=planning,sourceSummary=sourceSummary,mergedNearby=mergedNearby,totalNodes=#nodes,sourceObservations=observations,coveredNodes=coverage,coveredClusters=#points-(#points>2 and points[1]==points[#points] and 1 or 0),
        length=self:Length(points,w,h),travelSeconds=seconds,approach=approach,settings=settings,terrainValidated=false,lap=1,index=1,arrivalRadius=prof=='Fishing' and 40 or 30}
end
