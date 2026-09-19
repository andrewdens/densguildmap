local _, addon = ...
local PREFIX, TTL = "DensGuildMap1", 45
local peers, pool, roster = {}, {}, {}
local pins, ready, lastError, lastGuild
local frame = CreateFrame("Frame")
local function say(text) print("|cff65d69eDensGuildMap:|r " .. text) end
local function normalize(name)
    if not name then return end
    if name:find("-", 1, true) then return name end
    return name .. "-" .. GetNormalizedRealmName()
end
local function remove(name)
    local peer = peers[name]
    if not peer then return end
    for _, icon in ipairs(peer.icons) do
        if addon.worldMapLocations then addon.worldMapLocations[icon] = nil end
        pins:RemoveWorldMapIcon(addon, icon)
        pins:RemoveMinimapIcon(addon, icon)
        icon:Hide()
        pool[#pool + 1] = icon
    end
    peers[name] = nil
end
local function clear()
    for name in pairs(peers) do remove(name) end
end
local function updateRoster()
    local guild = GetGuildInfo("player")
    if guild ~= lastGuild then clear(); lastGuild = guild end
    wipe(roster)
    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if name and online then roster[normalize(name)] = true end
        end
    end
    for name in pairs(peers) do if not roster[name] then remove(name) end end
end
local function iconFor(name)
    local icon = table.remove(pool) or CreateFrame("Frame", nil, UIParent)
    icon:SetSize(DensGuildMapDB.size, DensGuildMapDB.size)
    if not icon.dot then
        icon.dot = icon:CreateTexture(nil, "OVERLAY")
        icon.dot:SetAllPoints()
        icon.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function(self)
            local peer = peers[self.member]
            if not peer then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.member)
            GameTooltip:AddLine("Level " .. peer.level .. " " .. peer.class, 1, 1, 1)
            GameTooltip:AddLine("Last update: " .. math.floor(GetTime() - peer.seen) .. "s ago")
            GameTooltip:AddLine("Location does not confirm the same layer.", .8, .8, .8)
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    icon.member = name
    return icon
end
local function receive(message, sender)
    sender = normalize(sender)
    if not roster[sender] or sender == normalize(UnitName("player")) then return end
    if message == "0" then remove(sender); return end
    local data = addon.Decode(message)
    if not data then return end
    local old = peers[sender]
    data.icons = old and old.icons or {iconFor(sender), iconFor(sender)}
    data.seen = GetTime()
    peers[sender] = data
    local color = RAID_CLASS_COLORS[data.class]
    for _, icon in ipairs(data.icons) do icon.dot:SetVertexColor(color.r, color.g, color.b) end
    if DensGuildMapDB.show then
        addon.worldMapLocations[data.icons[1]] = {map = data.map, x = data.x, y = data.y}
        pins:AddWorldMapIconMap(addon, data.icons[1], data.map, data.x, data.y, 3)
        pins:AddMinimapIconMap(addon, data.icons[2], data.map, data.x, data.y, true, false)
    end
end
local function send()
    if not IsInGuild() or not DensGuildMapDB.sharing then return end
    -- Do not access or transmit restricted combat positions.
    if InCombatLockdown() then return end
    local map = C_Map.GetBestMapForUnit("player")
    local position = map and C_Map.GetPlayerMapPosition(map, "player")
    if not position then C_ChatInfo.SendAddonMessage(PREFIX, "0", "GUILD"); return end
    local x, y = position:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
    local _, class = UnitClass("player")
    C_ChatInfo.SendAddonMessage(PREFIX, string.format("1;%d;%d;%d;%s;%d", map,
        math.floor(x * 10000 + .5), math.floor(y * 10000 + .5), class, UnitLevel("player")), "GUILD")
end
local function guarded(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then lastError = tostring(err) end
end
local settingsPanel, settingsCategory
local function refreshSettings()
    if settingsPanel then
        settingsPanel.sharing:SetChecked(DensGuildMapDB.sharing)
        settingsPanel.showPins:SetChecked(DensGuildMapDB.show)
    end
end
local function setSharing(enabled)
    DensGuildMapDB.sharing = not not enabled
    if ready and IsInGuild() and not enabled then
        guarded(C_ChatInfo.SendAddonMessage, PREFIX, "0", "GUILD")
    end
    refreshSettings()
end
local function setShowPins(enabled)
    DensGuildMapDB.show = not not enabled
    if ready then clear() end
    refreshSettings()
end
local function createSettings()
    local panel = CreateFrame("Frame")
    panel.name = "DensGuildMap"
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", 16, -12)
    icon:SetTexture("Interface\\AddOns\\DensGuildMap\\Media\\Icon")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 68, -16)
    title:SetText("DensGuildMap")
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    description:SetText("Share locations with guildmates who also use DensGuildMap.")
    local function checkbox(label, help, offset, callback)
        local button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", 16, offset)
        button.Text:SetText(label)
        button:SetScript("OnClick", function(self) callback(self:GetChecked()) end)
        local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 6, -2)
        hint:SetText(help)
        return button
    end
    panel.sharing = checkbox("Share my location with my guild",
        "Send your location every 5 seconds outside combat. Turning this off removes your dot for others.",
        -80, setSharing)
    panel.showPins = checkbox("Show guild member dots",
        "Show received locations on the world map and minimap. Your sharing setting is independent.",
        -150, setShowPins)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 22, -230)
    note:SetJustifyH("LEFT")
    note:SetText("Peers are guildmates who recently sent a location; you do not count yourself.\nLocations expire after 45 seconds without an update. Use /dgm status for diagnostics.\n\nChanges are saved automatically. Dots appear as new location updates arrive.")
    settingsPanel = panel
    panel:SetScript("OnShow", refreshSettings)
    refreshSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        DensGuildMapDB = DensGuildMapDB or {}
        local db = DensGuildMapDB
        if db.sharing == nil then db.sharing = true end
        if db.show == nil then db.show = true end
        db.size = math.min(32, math.max(8, tonumber(db.size) or 14))
        guarded(createSettings)
        pins = LibStub("HereBeDragons-Pins-2.0", true)
        ready = pins and C_Map and C_Map.GetPlayerMapPosition and C_ChatInfo and C_ChatInfo.SendAddonMessage
        if not ready then say("Required APIs unavailable. Use /dgm status."); return end
        addon.InstallMapProjection(pins)
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        guarded(updateRoster)
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        C_Timer.NewTicker(5, function()
            guarded(send)
            for name, peer in pairs(peers) do
                if GetTime() - peer.seen > TTL then guarded(remove, name) end
            end
        end)
        say("Beta loaded. Guild location sharing is " .. (db.sharing and "on" or "off") .. ". /dgm for options.")
    elseif ready then
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            if prefix == PREFIX and channel == "GUILD" then guarded(receive, message, sender) end
        else guarded(updateRoster) end
    end
end)
SLASH_DENSGUILDMAP1 = "/dgm"
SlashCmdList.DENSGUILDMAP = function(input)
    local command = input:lower():match("^%s*(.-)%s*$")
    local db = DensGuildMapDB
    if not db then return end
    if command == "off" or command == "on" then
        setSharing(command == "on")
        say("Location sharing " .. command .. ".")
    elseif command == "hide" or command == "show" then
        setShowPins(command == "show")
        say(db.show and "Pins will appear as updates arrive." or "Pins hidden; sharing setting unchanged.")
    elseif command == "settings" then
        if settingsCategory and Settings.OpenToCategory then
            Settings.OpenToCategory(settingsCategory:GetID())
        elseif settingsPanel and InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(settingsPanel)
        else
            say("Settings page unavailable. Use /dgm on | off | show | hide.")
        end
    elseif command == "map" then
        guarded(addon.PrintMapDiagnostics, say)
    elseif command == "status" then
        local version, build, _, interface = GetBuildInfo()
        local count = 0
        for _ in pairs(peers) do count = count + 1 end
        say(string.format("Client %s (%s), interface %s; APIs %s; sharing %s; peers %d.",
            version, build, interface, ready and "present" or "missing", tostring(db.sharing), count))
        say("Last error: " .. (lastError or "none"))
    else
        say("/dgm settings: options; on | off: share location; show | hide: map dots; status: diagnostics; map: position diagnostics.")
    end
end
