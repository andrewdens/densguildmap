from pathlib import Path
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
addon = lua.table()
lua.execute('''
Enum = {UIMapType = {World = 1, Continent = 2, Zone = 3}}
local maps = {
    [947] = {mapType = 1, parentMapID = 0},
    [10] = {mapType = 2, parentMapID = 947},
    [20] = {mapType = 2, parentMapID = 947},
    [11] = {mapType = 3, parentMapID = 10},
    [12] = {mapType = 3, parentMapID = 11},
    [13] = {mapType = 3, parentMapID = 10}, -- capital is a sibling of zone 11
    [21] = {mapType = 3, parentMapID = 20},
    [30] = {mapType = 3, parentMapID = 30},
    [31] = {mapType = 3, parentMapID = 10},
}
C_Map = {
    GetMapInfo = function(id) return maps[id] end,
    GetMapRectOnMap = function(id, parent)
        if id == 10 and parent == 947 then return .05, .45, .1, .9 end
        if id == 20 and parent == 947 then return .55, .95, .2, .8 end
        if id == 11 and parent == 10 then return .2, .6, .3, .5 end
        if id == 12 and parent == 11 then return .1, .3, .4, .8 end
        if id == 21 and parent == 20 then return .5, .9, .1, .7 end
        if id == 30 then return 0, 1, 0, 1 end
        if id == 31 then return 0, 0, 0, 0 end
    end,
}
LibStub = function()
    return {TranslateZoneCoordinates = function(_, x, y, source, target)
        -- Model a city geographically inside its sibling zone. Other pairs
        -- are outside the displayed bounds or in another world instance.
        if source == 13 and target == 11 then return .7 + x * .1, .2 + y * .2 end
    end}
end
''')
lua.execute((root / 'DensGuildMap/MapProjection.lua').read_text(), 'DensGuildMap', addon)
lua.globals().addon = addon
lua.execute('''
local function near(actual, expected) assert(math.abs(actual - expected) < 1e-9) end
local x, y = addon.ProjectToOverview(11, .25, .75, 10)
near(x, .3); near(y, .45)
x, y = addon.ProjectToOverview(21, .25, .75, 20)
near(x, .6); near(y, .55)
x, y = addon.ProjectToOverview(12, .5, .5, 10)
near(x, .28); near(y, .42)
x, y = addon.ProjectToOverview(11, .25, .75, 947)
near(x, .17); near(y, .46)
x, y = addon.ProjectToOverview(21, .25, .75, 947)
near(x, .79); near(y, .53)
x, y = addon.ProjectToOverview(12, .5, .5, 947)
near(x, .162); near(y, .436)
assert(addon.ProjectToOverview(11, .5, .5, 20) == nil)
assert(addon.ProjectToOverview(30, .5, .5, 10) == nil)
assert(addon.ProjectToOverview(31, .5, .5, 10) == nil)
assert(addon.ProjectToOverview(99, .5, .5, 10) == nil)
local target, fallback, acquired = 10, 0, nil
local map = {
    GetMapID = function() return target end,
    AcquirePin = function(_, template, icon, px, py) acquired = {px, py} end,
}
local provider = {
    GetMap = function() return map end,
    HandlePin = function() fallback = fallback + 1 end,
}
addon.InstallMapProjection({worldmapProvider = provider})
local icon, data = {}, {worldMapShowFlag = 3}
addon.worldMapLocations[icon] = {map = 11, x = .25, y = .75}
provider:HandlePin(icon, data)
near(acquired[1], .3); near(acquired[2], .45); assert(fallback == 0)
target = 11 -- zoom into the zone: retain the library's normal behavior
provider:HandlePin(icon, data); assert(fallback == 1)
target = 10 -- zoom out without receiving a new update
provider:HandlePin(icon, data); assert(fallback == 1)
target = 947 -- fully zoom out: bypass the hard-coded world-map layout
provider:HandlePin(icon, data); assert(fallback == 1)
near(acquired[1], .17); near(acquired[2], .46)
target = 11
addon.worldMapLocations[icon] = {map = 12, x = .5, y = .5}
provider:HandlePin(icon, data); assert(fallback == 1)
near(acquired[1], .2); near(acquired[2], .6) -- city with a zone parent
addon.worldMapLocations[icon] = {map = 13, x = .5, y = .5}
provider:HandlePin(icon, data); assert(fallback == 1)
near(acquired[1], .75); near(acquired[2], .3) -- sibling capital
target = 21 -- unrelated zone: no pin acquired by the correction
acquired = nil
provider:HandlePin(icon, data); assert(acquired == nil and fallback == 2)
fallback = 1
addon.worldMapLocations[icon] = {map = 11, x = .25, y = .75}
target = 10
provider:HandlePin({}, data); assert(fallback == 2) -- another addon's icon
addon.worldMapLocations[icon] = nil -- removed/recycled icon
provider:HandlePin(icon, data); assert(fallback == 3)
addon.worldMapLocations[icon] = {map = 11, x = .25, y = .75}
C_Map.GetMapRectOnMap = nil
provider:HandlePin(icon, data); assert(fallback == 4)
''')
print('Continent and Azeroth projection, nested maps, zoom transitions, isolation and fallback checks passed.')
