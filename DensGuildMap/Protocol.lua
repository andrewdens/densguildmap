local _, addon = ...
function addon.Decode(message)
    if type(message) ~= "string" or #message > 100 then return end
    local map, x, y, class, level = message:match("^1;(%d+);(%d+);(%d+);([A-Z]+);(%d+)$")
    map, x, y, level = tonumber(map), tonumber(x), tonumber(y), tonumber(level)
    if not map or map < 1 or map > 100000 or x > 10000 or y > 10000 or level > 1000 then return end
    if not RAID_CLASS_COLORS[class] then return end
    return {map = map, x = x / 10000, y = y / 10000, class = class, level = level}
end
