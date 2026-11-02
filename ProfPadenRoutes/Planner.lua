local _,R=...
_G.ProfPadenRoutes=R
R.version='0.20.16-rc1'
local sqrt,floor=math.sqrt,math.floor
local function distance(a,b,w,h)return sqrt(((a.x-b.x)*w)^2+((a.y-b.y)*h)^2)end
R.Distance=distance
function R:Length(points,w,h)
    local n=0;for i=2,#points do n=n+distance(points[i-1],points[i],w,h) end;return n
end
function R:Smooth(points,w,h)
    -- A visual fillet of at most six yards; navigation retains original turns.
    -- No unconstrained spline overshoot and no large terrain-cutting shortcuts.
    if #points<3 then return points end
    local out={points[1]}
    for i=2,#points-1 do
        local a,b,c=points[i-1],points[i],points[i+1]
        local ab,bc=distance(a,b,w,h),distance(b,c,w,h)
        if ab>1 and bc>1 then
            local cut=math.min(6,ab*.15,bc*.15)
            local q={x=b.x+(a.x-b.x)*cut/ab,y=b.y+(a.y-b.y)*cut/ab}
            local t={x=b.x+(c.x-b.x)*cut/bc,y=b.y+(c.y-b.y)*cut/bc}
            out[#out+1]=q
            for k=1,4 do local v=k/4;out[#out+1]={x=(1-v)^2*q.x+2*(1-v)*v*b.x+v^2*t.x,y=(1-v)^2*q.y+2*(1-v)*v*b.y+v^2*t.y} end
        else out[#out+1]=b end
    end
    out[#out+1]=points[#points];return out
end
