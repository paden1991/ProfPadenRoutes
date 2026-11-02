local _,R=...
local P=ProfPaden
local floor,min=math.floor,math.min
-- Personal successful loot visits, not community popularity or spawn rates.
-- Imported observation fields are deliberately not used as harvest counts.
local function public(v) return not issecretvalue or not issecretvalue(v) end
local harvestObjects
local function harvestObject(id)
    if not harvestObjects then
        harvestObjects={}
        for _,prof in ipairs({'Mining','Herbalism'}) do
            for _,entry in ipairs(P.GatherAtlas[prof] or {}) do
                for _,source in ipairs(entry.sources or {}) do
                    if source.kind=='object' and source.id and (source.method=='Mine' or source.method=='Herb') then harvestObjects[source.id]=true end
                end
            end
        end
    end
    return harvestObjects[id]
end
function R:CaptureHarvestLoot()
    if self.harvestLoot or not GetLootSourceInfo or not GetNumLootItems or not C_Map then return end
    local map=C_Map.GetBestMapForUnit('player');local pos=map and self:PlayerPosition(map)
    if not pos then return end
    local slots={}
    for slot=1,GetNumLootItems() do
        local sources={GetLootSourceInfo(slot)}
        for i=1,#sources,2 do
            local guid=sources[i]
            if public(guid) and type(guid)=='string' then
                local id=tonumber(guid:match('^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
                if id and harvestObject(id) then
                    local typ='object:'..id
                    slots[slot]=slots[slot] or {};slots[slot][#slots[slot]+1]={guid=guid,typ=typ,map=map,x=pos.x,y=pos.y}
                end
            end
        end
    end
    if next(slots) then self.harvestLoot=slots end
end
function R:HarvestSlotCleared(slot)
    local rows=self.harvestLoot and self.harvestLoot[slot]
    if not rows or not P.char then return end
    local now=time();self.harvestSeen=self.harvestSeen or {}
    for guid,stamp in pairs(self.harvestSeen) do if now-stamp>300 then self.harvestSeen[guid]=nil end end
    for _,p in ipairs(rows) do
        -- One visit per object, including multi-tap Classic veins and multiple loot slots.
        if not self.harvestSeen[p.guid] then
            self.harvestSeen[p.guid]=now
            P.char.walkingHarvests=P.char.walkingHarvests or {};local history=P.char.walkingHarvests
            local key=p.map..':'..p.typ..':'..floor(p.x*1000)..':'..floor(p.y*1000)
            local n=history[key] or {map=p.map,typ=p.typ,x=p.x,y=p.y,count=0}
            n.count=min(1000,n.count+1);n.last=now;history[key]=n
            local count,oldest,stamp=0,nil,math.huge
            for k,v in pairs(history) do count=count+1;if (v.last or 0)<stamp then oldest,stamp=k,v.last or 0 end end
            if count>2000 then history[oldest]=nil end
        end
    end
    self.harvestLoot[slot]=nil
end
function R:HarvestIndex(map,w,h)
    local index={}
    for _,n in pairs(P.char and P.char.walkingHarvests or {}) do
        if n.map==map then
            local key=n.typ..':'..floor(n.x*w/25)..':'..floor(n.y*h/25)
            index[key]=index[key] or {};index[key][#index[key]+1]=n
        end
    end
    return index
end
function R:HarvestWeight(area,n,w,h,index)
    if area.sourceKind~='object' or not area.sourceID or not index then return 1 end
    local types={'object:'..area.sourceID}
    -- Preserve earlier personal history keyed by GatherMate's node IDs when
    -- that optional integration is present. New visits use game object IDs.
    local legacy=P.GatherMateObjectTypes and P.GatherMateObjectTypes[area.sourceID]
    if legacy and #legacy==1 then types[#types+1]=legacy[1] end
    local x,y=n.x/100,n.y/100;local bx,by=floor(x*w/25),floor(y*h/25);local count=0
    for _,typ in ipairs(types) do for dx=-1,1 do for dy=-1,1 do
        for _,v in ipairs(index[typ..':'..(bx+dx)..':'..(by+dy)] or {}) do
            if ((x-v.x)*w)^2+((y-v.y)*h)^2<=625 then count=count+v.count end
        end
    end end end
    -- Bounded preference; distance, unique-site density and exclusions still dominate.
    return 1+min(.5,math.log(1+count)*.15)
end
local frame=CreateFrame('Frame');R.harvestEvents=frame
for _,event in ipairs({'LOOT_READY','LOOT_OPENED','LOOT_SLOT_CLEARED','LOOT_CLOSED'}) do frame:RegisterEvent(event) end
frame:SetScript('OnEvent',function(_,event,slot)
    if event=='LOOT_CLOSED' then R.harvestLoot=nil
    elseif event=='LOOT_SLOT_CLEARED' then if public(slot) then R:HarvestSlotCleared(slot) end
    else R:CaptureHarvestLoot() end
end)
