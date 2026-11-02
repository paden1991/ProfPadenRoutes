local _,R=...
-- Classic taxi node ownership. Explicit zones avoid projecting a city flight
-- master onto the outdoor terrain beneath it. Coordinates come from the client
-- first, with the installed OpenMap Classic flight data as an optional fallback.
local zones={
    [1433]={5},[1436]={4},[1437]={7},[1432]={8},[1421]={10},[1431]={12},
    [1424]={13,14},[1417]={16,17},[1434]={18,19,20},[1418]={21},
    [1413]={25,77,80},[1439]={26},[1438]={27},[1440]={28,58,61},
    [1442]={29,33},[1441]={30},[1444]={31,41,42},[1445]={32,55},
    [1443]={37,38},[1446]={39,40},[1425]={43,76},[1447]={44,64},
    [1419]={45},[1448]={48,65},[1450]={49,69},[1452]={52,53},
    [1435]={56},[1422]={66},[1423]={67,68},[1428]={70,71},
    [1451]={72,73},[1427]={74,75},[1449]={79},
}
local zoneFor={};for map,ids in pairs(zones)do for _,id in ipairs(ids)do zoneFor[id]=map end end
-- City interiors, druid-only taxis and conditional EPL tower flights do not
-- make dependable outdoor arrival points for an arbitrary character.
local excluded={[2]=true,[6]=true,[11]=true,[22]=true,[23]=true,[59]=true,[60]=true,[62]=true,[63]=true,[84]=true,[85]=true,[86]=true,[87]=true}
local function valid(x,y)return R.IsNumber(x) and R.IsNumber(y) and x>=0 and x<=1 and y>=0 and y<=1 end
function R:FlightStarts(map,w,h,settings,nodes)
    local faction=UnitFactionGroup and UnitFactionGroup('player')
    if faction~='Alliance' and faction~='Horde' then return {} end
    local wanted=faction=='Alliance' and 2 or 1
    local points,seen={},{}
    local function add(id,name,x,y,known,source)
        if seen[id] or excluded[id] or zoneFor[id] and zoneFor[id]~=map or not valid(x,y) then return end
        local p={x=x,y=y,name=name,id=id,known=known,source=source}
        if self:WaterPoint(p,settings) or self:AvoidedPoint(p,settings) or self:MountainPoint(p,settings.terrainContext) then return end
        p.distance=math.huge
        for _,n in ipairs(nodes)do p.distance=math.min(p.distance,self.Distance(p,n,w,h))end
        seen[id]=true;points[#points+1]=p
    end
    if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        local ok,list=pcall(C_TaxiMap.GetTaxiNodesForMap,map)
        if ok and type(list)=='table' then for _,n in ipairs(list)do
            if n.nodeID and n.position and (n.faction==0 or n.faction==wanted) then
                local x,y=n.position.x,n.position.y
                if n.position.GetXY then x,y=n.position:GetXY() end
                add(n.nodeID,n.name,x,y,n.isUndiscovered==false,'Client flight map')
            end
        end end
    end
    if #points==0 and OpenMap and OpenMap.MapFlights then
        local data=OpenMap.MapFlights.nodes or {};local api=OpenMapAPI;local stitch=OpenMap.MapStitch
        local known=OpenMapCharDB and OpenMapCharDB.worldmap and OpenMapCharDB.worldmap.flightsKnown or {}
        for _,id in ipairs(zones[map] or {})do local n=data[id]
            if n and (n[5]==3 or n[5]==(faction=='Alliance' and 1 or 2)) then
                local x,y
                if stitch and stitch.FromYards and api and api.MapFromWorld then
                    local u,v=stitch.FromYards(n[2],n[3],n[4])
                    if u then x,y=api.MapFromWorld(map,u,v) end
                end
                if not valid(x,y) then
                    local d=self.Heightmaps and self.Heightmaps[map]
                    if d and d.mapId==n[2] then x,y=(d.worldWest-n[4])/d.worldWidth,(d.worldNorth-n[3])/d.worldHeight end
                end
                add(id,n[1],x,y,known[n[1]]==true,'OpenMap flight data')
            end
        end
    end
    table.sort(points,function(a,b)
        if a.known~=b.known then return a.known end
        if a.distance~=b.distance then return a.distance<b.distance end
        return a.id<b.id
    end)
    return points
end
