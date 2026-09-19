local _, addon = ...

-- Map artwork can place zones differently from their world-space bounds.
-- Follow client rectangles all the way through continent -> Azeroth. HBD's
-- Azeroth conversion uses hard-coded layouts from other client versions.
function addon.ProjectToOverview(source, x, y, target)
    local targetInfo = C_Map.GetMapInfo(target)
    if not targetInfo or (targetInfo.mapType ~= Enum.UIMapType.Continent
        and targetInfo.mapType ~= Enum.UIMapType.World
        and targetInfo.mapType ~= Enum.UIMapType.Zone)
        or not C_Map.GetMapRectOnMap then return end
    local visited = {}
    while source ~= target do
        if visited[source] then return end
        visited[source] = true
        local info = C_Map.GetMapInfo(source)
        local parent = info and info.parentMapID
        if not parent or parent == 0 then return end
        local left, right, top, bottom = C_Map.GetMapRectOnMap(source, parent)
        if not left or not right or not top or not bottom
            or right <= left or bottom <= top then return end
        x = left + x * (right - left)
        y = top + y * (bottom - top)
        source = parent
    end
    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

function addon.InstallMapProjection(pins)
    local provider = pins.worldmapProvider
    local original = provider.HandlePin
    local locations = setmetatable({}, {__mode = "k"})
    addon.worldMapLocations = locations
    -- Scope the correction to our icons even when another addon supplies HBD.
    provider.HandlePin = function(self, icon, data)
        local location = locations[icon]
        local target = self:GetMap():GetMapID()
        local info = target and C_Map.GetMapInfo(target)
        local requiredFlag = info and info.mapType == Enum.UIMapType.World and 3
            or (info and info.mapType == Enum.UIMapType.Zone and 1 or 2)
        if location and target and target ~= location.map and data.worldMapShowFlag >= requiredFlag then
            local x, y = addon.ProjectToOverview(location.map, location.x, location.y, target)
            -- Capitals can be siblings of their surrounding zone in the map
            -- hierarchy. HBD's visibility filter rejects siblings even when
            -- their world position falls inside the displayed zone.
            if not x and info and info.mapType == Enum.UIMapType.Zone then
                local hbd = LibStub("HereBeDragons-2.0")
                x, y = hbd:TranslateZoneCoordinates(location.x, location.y, location.map, target)
            end
            if x and y then
                self:GetMap():AcquirePin("HereBeDragonsPinsTemplate", icon, x, y, data.frameLevelType)
                return
            end
        end
        return original(self, icon, data)
    end
end

-- Compare the live client's own position with both conversion paths. This is
-- deliberately on demand: it needs the affected map open and no combat.
function addon.PrintMapDiagnostics(say)
    if InCombatLockdown() then say("Run /dgm map outside combat with the affected map open."); return end
    local target = WorldMapFrame:GetMapID()
    local source = C_Map.GetBestMapForUnit("player")
    local info = target and C_Map.GetMapInfo(target)
    say(string.format("Map %s (%s), source %s, project %s.", tostring(target),
        info and info.name or "unknown", tostring(source), tostring(WOW_PROJECT_ID)))
    if not target or not source then return end
    local function position(label, x, y)
        if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then
            say(label .. ": restricted"); return
        end
        say(label .. ": " .. (x and y and string.format("%.2f, %.2f", x * 100, y * 100) or "unavailable"))
    end
    local direct = C_Map.GetPlayerMapPosition(target, "player")
    if direct then position("Client", direct:GetXY()) else position("Client") end
    local localPos = C_Map.GetPlayerMapPosition(source, "player")
    if not localPos then return end
    local x, y = localPos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
    position("Zone", x, y)
    position("Rectangles", addon.ProjectToOverview(source, x, y, target))
    local hbd = LibStub("HereBeDragons-2.0")
    position("Library", hbd:TranslateZoneCoordinates(x, y, source, target))
end
