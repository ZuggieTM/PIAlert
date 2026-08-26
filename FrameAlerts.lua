local ADDON_NAME, NS = ...

local FA = {}
NS.FrameAlerts = FA

local function SafeMethod(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
    return nil
end

local function SafeUnitFromFrame(frame)
    if not frame then return nil end

    -- SecureButton_GetUnit is the canonical way to ask a secure unit button what
    -- it represents. In Midnight the result may be secret, so never compare it
    -- unless Blizzard exposes a normal string.
    if type(SecureButton_GetUnit) == "function" then
        local ok, unit = pcall(SecureButton_GetUnit, frame)
        if ok and not NS:IsSecretValue(unit) and type(unit) == "string" and unit ~= "" then
            return unit
        end
    end

    local unit = SafeMethod(frame, "GetAttribute", "unit")
    if not NS:IsSecretValue(unit) and type(unit) == "string" and unit ~= "" then
        return unit
    end

    local ok, value = pcall(function() return frame.unit end)
    if ok and not NS:IsSecretValue(value) and type(value) == "string" and value ~= "" then
        return value
    end

    return nil
end

local function UnitMatches(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not UnitExists(a) or not UnitExists(b) then return false end
    local ok, same = pcall(UnitIsUnit, a, b)
    return ok and not NS:IsSecretValue(same) and same == true
end

function FA:Init()
    self.frameVisuals = setmetatable({}, { __mode = "k" })
    self.visuals = {}
    self.lastSoundAt = -1000
    self.auraUnlocked = false
    self.lgf = nil
    self.glowKey = "PIPriority"
    self.lgfInitialized = false
    self.lgfRefreshRegistered = false
    self.lgfOptions = {
        -- We want party/raid frames only. This is particularly important for
        -- the player unit, otherwise a normal player frame could win instead of
        -- the raid/party frame the healer is looking at.
        ignorePlayerFrame = true,
        ignoreTargetFrame = true,
        ignoreTargettargetFrame = true,
        ignorePartyFrame = false,
        ignorePartyTargetFrame = true,
        ignoreFocusFrame = true,
        ignoreRaidFrame = false,
        ignoreBossFrame = true,
        returnAll = false,
    }

    self:CreateAuraIcon()

    -- Let the rest of the UI finish loading first. LibGetFrame performs its
    -- discovery incrementally, so this never runs a large scan on the request
    -- hot path.
    C_Timer.After(1.0, function()
        if NS:IsActive() then FA:EnsureFrameResolver() end
    end)
end

function FA:EnsureFrameResolver()
    if self.lgf then return self.lgf end
    if not _G.LibStub or type(_G.LibStub.GetLibrary) ~= "function" then return nil end

    local ok, lib = pcall(_G.LibStub.GetLibrary, _G.LibStub, "LibGetFrame-1.0", true)
    if not ok or not lib then return nil end
    self.lgf = lib

    if not self.lgfRefreshRegistered and type(lib.RegisterCallback) == "function" then
        self.lgfRefreshRegistered = true
        -- CallbackHandler's embedded API deliberately accepts an arbitrary
        -- owner token as the first argument; this keeps us independent of the
        -- library object's own method syntax.
        pcall(lib.RegisterCallback, ADDON_NAME, "GETFRAME_REFRESH", function()
            if not NS:IsActive() then return end
            if NS.FrameAlerts then NS.FrameAlerts:RefreshAllActive() end
            if NS.Detector and NS.Detector.ScheduleAuraRefresh then
                NS.Detector:ScheduleAuraRefresh(0.05)
            end
        end)
    end

    if not self.lgfInitialized and type(lib.GetUnitFrame) == "function" then
        self.lgfInitialized = true
        -- GetUnitFrame initializes LibGetFrame's cache/listeners. It is safe for
        -- this to return nil while its incremental discovery is still running;
        -- GETFRAME_REFRESH will reapply any active request afterward.
        pcall(lib.GetUnitFrame, "player", self.lgfOptions)
    end

    return lib
end

local function Clamp(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback or minValue
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    return value
end

function FA:GetGlowColor(request)
    local cfg = NS.db.alerts
    if cfg.glowColorMode == "CLASS" then
        local unit = self:ResolveRequestUnit(request)
        if unit and UnitExists(unit) then
            local ok, _, classToken = pcall(UnitClass, unit)
            if ok and type(classToken) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                local c = RAID_CLASS_COLORS[classToken]
                return { c.r or 1, c.g or 1, c.b or 1, 1 }
            end
        end
    end

    local color = type(cfg.glowColor) == "table" and cfg.glowColor or { 1.00, 0.82, 0.20, 1 }
    return {
        Clamp(color[1], 0, 1, 1.00),
        Clamp(color[2], 0, 1, 0.82),
        Clamp(color[3], 0, 1, 0.20),
        Clamp(color[4], 0, 1, 1.00),
    }
end

function FA:StopGlow(visual)
    if not visual or not visual.glowAnchor then return end
    if NS.Glow and NS.Glow.Stop then
        pcall(NS.Glow.Stop, NS.Glow, visual.glowAnchor)
    end
    visual.glowAnchor:Hide()
    visual.glowStyle = nil
end

local function GetReadableFrameSize(frame)
    if not frame or type(frame.GetSize) ~= "function" then return nil, nil end
    local ok, width, height = pcall(frame.GetSize, frame)
    if not ok then return nil, nil end
    if type(issecretvalue) == "function" and (issecretvalue(width) or issecretvalue(height)) then
        return nil, nil
    end
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        return nil, nil
    end
    return width, height
end

function FA:StartGlow(visual, request)
    if not visual or not visual.glowAnchor or not NS.Glow or not NS.Glow.Start then
        return false
    end

    self:StopGlow(visual)

    local cfg = NS.db.alerts
    local color = self:GetGlowColor(request)
    local width, height = GetReadableFrameSize(visual.target)
    if not width or not height then width, height = 100, 40 end

    visual.glowAnchor:Show()
    local ok, result = pcall(NS.Glow.Start, NS.Glow, visual.glowAnchor, width, height, color, cfg)
    if ok and result == true then
        visual.glowStyle = cfg.glowStyle or "PIXEL"
        return true
    end

    visual.glowAnchor:Hide()
    NS:Debug("PI Alert's native glow engine could not start the selected raidframe glow.")
    return false
end

function FA:CreateAuraIcon()
    local frame = CreateFrame("Frame", "PIPriorityAuraIcon", UIParent, "BackdropTemplate")
    self.auraIcon = frame
    frame:SetSize(NS.db.auraIcon.size or 52, NS.db.auraIcon.size or 52)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.035, 0.055, 0.075, 0.94)
    frame:SetBackdropBorderColor(0.20, 0.90, 0.70, 0.95)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(NS:GetSpellIcon(NS.PI_SPELL_ID))
    frame.icon = icon

    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(1, 1, 1, 1)
    count:Hide()
    frame.count = count

    local dragLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragLabel:SetPoint("TOP", frame, "BOTTOM", 0, -5)
    dragLabel:SetText("Drag PI icon")
    dragLabel:SetTextColor(0.75, 0.85, 0.90, 1)
    dragLabel:Hide()
    frame.dragLabel = dragLabel

    frame:SetScript("OnDragStart", function(self)
        if FA.auraUnlocked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        NS.db.auraIcon.point = point or "CENTER"
        NS.db.auraIcon.relativePoint = relativePoint or "CENTER"
        NS.db.auraIcon.x = x or 0
        NS.db.auraIcon.y = y or 0
    end)

    self:ApplyAuraIconPosition()
    frame:Hide()
end

function FA:ApplyAuraIconPosition()
    if not self.auraIcon then return end
    local cfg = NS.db.auraIcon
    self.auraIcon:ClearAllPoints()
    self.auraIcon:SetPoint(cfg.point or "CENTER", UIParent, cfg.relativePoint or "CENTER", cfg.x or 0, cfg.y or -120)
    local size = tonumber(cfg.size) or 52
    self.auraIcon:SetSize(size, size)
end

function FA:ResetAuraIconPosition()
    NS.db.auraIcon.point = "CENTER"
    NS.db.auraIcon.relativePoint = "CENTER"
    NS.db.auraIcon.x = 0
    NS.db.auraIcon.y = -120
    self:ApplyAuraIconPosition()
end

function FA:ToggleAuraUnlock(force)
    if force == nil then
        self.auraUnlocked = not self.auraUnlocked
    else
        self.auraUnlocked = force and true or false
    end

    local frame = self.auraIcon
    if not frame then return end
    frame:EnableMouse(self.auraUnlocked)
    if self.auraUnlocked then
        frame.dragLabel:Show()
        frame:Show()
    else
        frame.dragLabel:Hide()
        self:UpdateAuraIcon(NS.RequestManager and NS.RequestManager:GetActiveCount() or 0)
    end

    if NS.UI then NS.UI:RefreshAlertsPage() end
end

function FA:UpdateAuraIcon(count)
    local frame = self.auraIcon
    if not frame then return end
    count = tonumber(count) or 0

    if count > 1 then
        frame.count:SetText(count)
        frame.count:Show()
    else
        frame.count:Hide()
    end

    if self.auraUnlocked then
        frame:Show()
    elseif NS.db.alerts.auraIcon and count > 0 then
        frame:Show()
    else
        frame:Hide()
    end
end

function FA:ResolveRequestUnit(request)
    if not request then return nil end

    if request.unit and UnitExists(request.unit) then
        if not request.guid then return request.unit end
        local guid = UnitGUID(request.unit)
        if not NS:IsSecretValue(guid) and guid == request.guid then
            return request.unit
        end
    end

    local unit
    if request.guid then unit = NS:FindGroupUnitByGUID(request.guid) end
    if not unit and request.name then unit = NS:FindGroupUnitByName(request.name) end
    if unit then request.unit = unit end
    return unit
end

-- Cheap provider-specific fallbacks. LibGetFrame is the primary resolver, but
-- these let us attach immediately while its cache is still warming up.
function FA:ResolveKnownProvider(unit)
    if not unit then return nil end

    local eui = _G.EllesmereUI
    local registry = eui and eui._ModuleNS
    if type(registry) == "table" then
        for _, moduleNS in pairs(registry) do
            if type(moduleNS) == "table" and type(moduleNS._CollectTrackerFrames) == "function" then
                local ok, frames = pcall(moduleNS._CollectTrackerFrames)
                if ok and type(frames) == "table" then
                    for _, frame in ipairs(frames) do
                        local frameUnit = SafeUnitFromFrame(frame)
                        if UnitMatches(frameUnit, unit) then return frame end
                    end
                end
            end
        end
    end

    local function check(frame)
        if frame and UnitMatches(SafeUnitFromFrame(frame), unit) then return frame end
    end

    for i = 1, 40 do
        local frame = check(_G["CompactRaidFrame" .. i])
        if frame then return frame end
    end
    for i = 1, 5 do
        local frame = check(_G["CompactPartyFrameMember" .. i])
        if frame then return frame end
    end

    return nil
end

function FA:ResolveFrame(request)
    local unit = self:ResolveRequestUnit(request)
    if not unit then return nil end

    local lgf = self:EnsureFrameResolver()
    if lgf and type(lgf.GetUnitFrame) == "function" then
        -- LibGetFrame maps the unit token (party2/raid6/player) to the actual
        -- party/raid frame from Blizzard, Grid/Grid2, EllesmereUI, Cell, ElvUI,
        -- VuhDo and many other frame addons.
        local ok, frame = pcall(lgf.GetUnitFrame, unit, self.lgfOptions)
        if ok and frame then return frame end
    end

    return self:ResolveKnownProvider(unit)
end

function FA:EnsureFrameVisual(target)
    if not target then return nil end

    local visual = self.frameVisuals[target]
    if visual then return visual end

    local ok, result = pcall(function()
        -- Keep all ordinary request visuals on our own non-interactive child.
        -- Secure allied-aura buttons use their separate static border path.
        local host = CreateFrame("Frame", nil, target)
        host:SetAllPoints(target)
        host:SetFrameStrata("HIGH")
        host:SetFrameLevel(1000)
        host:EnableMouse(false)
        host:Hide()

        local glowAnchor = CreateFrame("Frame", nil, host)
        glowAnchor:SetAllPoints(host)
        glowAnchor:SetFrameLevel(1001)
        glowAnchor:EnableMouse(false)
        glowAnchor:Hide()

        local iconFrame = CreateFrame("Frame", nil, host, "BackdropTemplate")
        iconFrame:SetFrameLevel(1002)
        iconFrame:SetSize(22, 22)
        iconFrame:SetPoint("CENTER")
        iconFrame:EnableMouse(false)
        iconFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        iconFrame:SetBackdropColor(0.02, 0.03, 0.04, 0.94)
        iconFrame:SetBackdropBorderColor(0.12, 0.95, 0.72, 1)
        iconFrame:Hide()

        local icon = iconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(NS:GetSpellIcon(NS.PI_SPELL_ID))

        return {
            host = host,
            glowAnchor = glowAnchor,
            iconFrame = iconFrame,
            icon = icon,
            requestKey = nil,
            target = target,
            glowStyle = nil,
        }
    end)

    if not ok or not result then
        NS:Debug("Could not create visual host for a raid frame.")
        return nil
    end

    self.frameVisuals[target] = result
    return result
end

function FA:HideFrameVisual(visual)
    if not visual then return end
    self:StopGlow(visual)
    if visual.iconFrame then visual.iconFrame:Hide() end
    if visual.host then visual.host:Hide() end
    visual.requestKey = nil
end

function FA:HideAllFrameVisuals()
    for _, visual in pairs(self.frameVisuals) do
        self:HideFrameVisual(visual)
    end
    wipe(self.visuals)
end

function FA:ApplyRequestVisual(request)
    if not request then return end

    local needFrame = NS.db.alerts.glow or NS.db.alerts.frameIcon
    if not needFrame then
        local old = self.visuals[request.key]
        if old and old.requestKey == request.key then self:HideFrameVisual(old) end
        self.visuals[request.key] = nil
        return
    end

    local target = self:ResolveFrame(request)
    if not target then
        NS:Debug("No raid/party frame resolved yet for " .. tostring(request.name) .. " (" .. tostring(request.unit) .. ")")
        return
    end

    local visual = self:EnsureFrameVisual(target)
    if not visual then return end

    local old = self.visuals[request.key]
    if old and old ~= visual and old.requestKey == request.key then
        self:HideFrameVisual(old)
    end

    visual.requestKey = request.key
    self.visuals[request.key] = visual
    visual.host:Show()

    if NS.db.alerts.glow then
        self:StartGlow(visual, request)
    else
        self:StopGlow(visual)
    end

    if NS.db.alerts.frameIcon then
        local iconSpellID = NS.PI_SPELL_ID
        if NS.db.alerts.frameIconType == "SPELL" and request.source == "SPELL" and request.spellID then
            iconSpellID = request.spellID
        end
        visual.icon:SetTexture(NS:GetSpellIcon(iconSpellID))
        visual.iconFrame:Show()
    else
        visual.iconFrame:Hide()
    end
end

function FA:ActivateRequest(request, wasActive)
    self:ApplyRequestVisual(request)
    self:UpdateAuraIcon(NS.RequestManager:GetActiveCount())

    local playsWhisperSound = request and (request.source == "WHISPER" or request.source == "TEST")
    if playsWhisperSound and not wasActive and NS.db.alerts.sound then
        local now = GetTime()
        local throttle = tonumber(NS.db.alerts.soundCooldown) or 2
        if now - (self.lastSoundAt or -1000) >= throttle then
            if NS.Media then NS.Media:Play(NS.db.alerts.soundKey) end
            self.lastSoundAt = now
        end
    end
end

function FA:RefreshRequest(request)
    self:ApplyRequestVisual(request)
    self:UpdateAuraIcon(NS.RequestManager:GetActiveCount())
end

function FA:DeactivateRequest(request)
    local visual = request and self.visuals[request.key]
    if visual and visual.requestKey == request.key then
        self:HideFrameVisual(visual)
    end
    if request then self.visuals[request.key] = nil end

    C_Timer.After(0, function()
        if NS.RequestManager then FA:UpdateAuraIcon(NS.RequestManager:GetActiveCount()) end
    end)
end

function FA:ClearAll()
    self:HideAllFrameVisuals()
    self:UpdateAuraIcon(0)
end

function FA:RefreshAllActive()
    if not NS:IsActive() or not NS.RequestManager then return end

    self:HideAllFrameVisuals()
    for _, request in pairs(NS.RequestManager:GetActiveRequests() or {}) do
        self:ApplyRequestVisual(request)
    end
    self:UpdateAuraIcon(NS.RequestManager:GetActiveCount())
end

function FA:OnSettingsChanged(rescan)
    if rescan then self:EnsureFrameResolver() end
    self:ApplyAuraIconPosition()
    self:RefreshAllActive()
end

-- Core.lua still calls this on login/roster changes. LibGetFrame already watches
-- the same events itself, so we only schedule a cheap visual refresh here.
function FA:ScheduleFrameScan(delay)
    C_Timer.After(delay or 0, function()
        if not NS:IsActive() then return end
        FA:EnsureFrameResolver()
        FA:RefreshAllActive()
    end)
end

function FA:PrintFrameCache()
    self:EnsureFrameResolver()
    local entries = {}
    NS:ForEachGroupUnit(function(unit)
        local fake = { unit = unit, guid = UnitGUID(unit), name = UnitName(unit) }
        local frame = self:ResolveFrame(fake)
        if frame then
            local name = SafeMethod(frame, "GetName")
            if NS:IsSecretValue(name) or type(name) ~= "string" or name == "" then name = "<unnamed>" end
            entries[#entries + 1] = string.format("%s -> %s", unit, name)
        else
            entries[#entries + 1] = string.format("%s -> <not resolved yet>", unit)
        end
    end, true)
    table.sort(entries)

    if #entries == 0 then
        NS:Print("No group units are available right now.")
    else
        NS:Print("Raidframe resolver:")
        for _, line in ipairs(entries) do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
    end
end
