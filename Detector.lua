local ADDON_NAME, NS = ...

local Detector = {}
NS.Detector = Detector

local AURA_FILTER = "HELPFUL"
local SECURE_MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local SECURE_DASH_H = SECURE_MEDIA .. "secure-dash-h.tga"
local SECURE_DASH_V = SECURE_MEDIA .. "secure-dash-v.tga"

local function IsWordChar(ch)
    return ch and ch ~= "" and ch:match("[%w]") ~= nil
end

local function ContainsPhrase(message, phrase)
    if message == "" or phrase == "" then return false end
    local searchFrom = 1
    while true do
        local first, last = message:find(phrase, searchFrom, true)
        if not first then return false end

        local phraseFirst = phrase:sub(1, 1)
        local phraseLast = phrase:sub(-1)
        local before = first > 1 and message:sub(first - 1, first - 1) or nil
        local after = last < #message and message:sub(last + 1, last + 1) or nil

        local beforeOkay = not IsWordChar(phraseFirst) or not IsWordChar(before)
        local afterOkay = not IsWordChar(phraseLast) or not IsWordChar(after)
        if beforeOkay and afterOkay then return true end

        searchFrom = first + 1
    end
end

local function SafeDisableContainer(container)
    if not container then return end
    if container.SetEnabled then pcall(container.SetEnabled, container, false) end
    pcall(container.Hide, container)
end

local function IsInCombatLockdown()
    return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true
end

local function Clamp(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback or minValue
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    return value
end

local function CreateStaticBorder(frame)
    local border = { inner = {}, outer = {} }

    local function MakeEdge(layer, isOuter)
        local top = frame:CreateTexture(nil, layer)
        local bottom = frame:CreateTexture(nil, layer)
        local left = frame:CreateTexture(nil, layer)
        local right = frame:CreateTexture(nil, layer)
        local pad = isOuter and 2 or 0

        top:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", pad, pad)

        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -pad, -pad)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)

        left:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -pad, -pad)

        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", pad, pad)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)

        return { top, bottom, left, right }
    end

    border.outer = MakeEdge("OVERLAY", true)
    border.inner = MakeEdge("OVERLAY", false)
    return border
end

local function UpdateStaticBorder(border, color, thickness)
    if not border then return end
    thickness = math.floor(Clamp(thickness, 1, 8, 2) + 0.5)
    color = color or { 1.00, 0.82, 0.20, 1.00 }

    local r, g, b, a = color[1] or 1, color[2] or 0.82, color[3] or 0.20, color[4] or 1
    local outerSize = math.max(2, thickness + 2)

    for index, texture in ipairs(border.outer or {}) do
        texture:SetColorTexture(r, g, b, math.min(1, a * 0.28))
        if index <= 2 then texture:SetHeight(outerSize) else texture:SetWidth(outerSize) end
    end
    for index, texture in ipairs(border.inner or {}) do
        texture:SetColorTexture(r, g, b, math.min(1, a))
        if index <= 2 then texture:SetHeight(thickness) else texture:SetWidth(thickness) end
    end
end

local function GetSecureTargetSize(target)
    local width, height = 100, 40
    if target and type(target.GetSize) == "function" then
        local ok, targetWidth, targetHeight = pcall(target.GetSize, target)
        if ok and not NS:IsSecretValue(targetWidth) and not NS:IsSecretValue(targetHeight)
            and type(targetWidth) == "number" and type(targetHeight) == "number"
            and targetWidth > 0 and targetHeight > 0
        then
            width, height = targetWidth, targetHeight
        end
    end
    return width, height
end

local function CreateStaticPixelGlow(frame, target, color, thickness, lineCount)
    thickness = math.floor(Clamp(thickness, 1, 8, 2) + 0.5)
    lineCount = math.floor(Clamp(lineCount, 1, 20, 12) + 0.5)
    color = color or { 1.00, 0.82, 0.20, 1.00 }

    local width, height = GetSecureTargetSize(target)
    local perimeter = math.max(1, 2 * (width + height))
    local horizontalRepeats = math.max(1, lineCount * width / perimeter)
    local verticalRepeats = math.max(1, lineCount * height / perimeter)
    local r, g, b, a = color[1] or 1, color[2] or 0.82, color[3] or 0.20, color[4] or 1

    local function MakeEdge(texturePath)
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetTexture(texturePath, "REPEAT", "REPEAT")
        texture:SetBlendMode("ADD")
        texture:SetVertexColor(r, g, b, a)
        return texture
    end

    local top = MakeEdge(SECURE_DASH_H)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(thickness)
    top:SetTexCoord(0, horizontalRepeats, 0, 1)

    local bottom = MakeEdge(SECURE_DASH_H)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(thickness)
    bottom:SetTexCoord(horizontalRepeats, 0, 0, 1)

    local left = MakeEdge(SECURE_DASH_V)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(thickness)
    left:SetTexCoord(0, 1, verticalRepeats, 0)

    local right = MakeEdge(SECURE_DASH_V)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(thickness)
    right:SetTexCoord(0, 1, 0, verticalRepeats)

end

local function StartSecurePulse(frame, speed)
    -- AuraButton descendants reject tainted per-frame writes after initialization.
    -- A native Alpha AnimationGroup started here runs entirely C-side and remains
    -- active after Blizzard seals the button.
    local cycle = 1 / Clamp(speed, 0.25, 3.0, 1.0)
    local group = frame:CreateAnimationGroup()
    group:SetLooping("REPEAT")

    local fadeOut = group:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.30)
    fadeOut:SetDuration(cycle / 2)
    fadeOut:SetOrder(1)

    local fadeIn = group:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.30)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(cycle / 2)
    fadeIn:SetOrder(2)

    group:Play()
end

local function CreateSecureGlowArt(frame, target, visual)
    local style = visual.glowStyle or "PIXEL"
    local color = visual.glowColor or { 1.00, 0.82, 0.20, 1.00 }
    local thickness = visual.glowPixelThickness or 2

    if style == "PIXEL" then
        local width, height = GetSecureTargetSize(target)
        if NS.SecureGlow and NS.SecureGlow.StartPixel then
            local ok, started = pcall(
                NS.SecureGlow.StartPixel,
                NS.SecureGlow,
                frame,
                width,
                height,
                color,
                visual
            )
            if ok and started then return end
        end

        -- If a client rejects the native Translation animation, retain a visible
        -- static Pixel border and the proven native alpha pulse as a fallback.
        CreateStaticPixelGlow(frame, target, color, thickness, visual.glowPixelLines)
    else
        local border = CreateStaticBorder(frame)
        if style == "AUTOCAST" then
            local scale = Clamp(visual.glowAutoCastScale, 0.5, 3.0, 1.0)
            UpdateStaticBorder(border, color, math.max(2, thickness * scale + 1))
        else
            UpdateStaticBorder(border, color, thickness)
        end
    end

    StartSecurePulse(frame, visual.glowSpeed)
end

local function AddRaidframeIcon(frame, size, showDurationSwipe, iconType)
    size = math.floor(Clamp(size, 12, 96, 22) + 0.5)
    frame:SetSize(size, size)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.02, 0.03, 0.04, 0.96)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    local usesAuraIcon = iconType == "SPELL" and type(frame.SetIcon) == "function"
    if usesAuraIcon then
        local ok = pcall(frame.SetIcon, frame, icon)
        if not ok then
            icon:SetTexture(NS:GetSpellIcon(NS.PI_SPELL_ID))
        end
    else
        icon:SetTexture(NS:GetSpellIcon(NS.PI_SPELL_ID))
    end

    if showDurationSwipe and frame.SetDurationCooldown then
        local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cooldown:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        cooldown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        cooldown:SetFrameLevel(frame:GetFrameLevel() + 1)
        cooldown:EnableMouse(false)
        cooldown:SetReverse(true)
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(true)
        end
        cooldown:Show()

        -- Blizzard binds the matched aura's protected Duration object directly
        -- to this swipe. No remaining-time value is read by addon Lua.
        frame:SetDurationCooldown(cooldown)
    end

    local borderColor = { 1.00, 0.82, 0.20, 1.00 }
    local top = frame:CreateTexture(nil, "OVERLAY")
    local bottom = frame:CreateTexture(nil, "OVERLAY")
    local left = frame:CreateTexture(nil, "OVERLAY")
    local right = frame:CreateTexture(nil, "OVERLAY")
    for _, texture in ipairs({ top, bottom, left, right }) do
        texture:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)
end

function Detector:Init()
    self.auraStates = {}
    self.auraStateCache = setmetatable({}, { __mode = "k" })
    self.cooldownAuraCache = {}
    self.auraEngineAvailable = false
    self.lastSecretDebugAt = 0
    self.refreshSerial = 0
    self.pendingAuraRefresh = false
    self.pendingClearAuraStates = false
    self.piCooldownLatched = false
    self.lastPIReady = nil
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_WHISPER")
    self.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_ENABLED" then
            Detector:OnPlayerRegenEnabled()
            return
        end
        if not NS:IsActive() then return end
        if event == "CHAT_MSG_WHISPER" then
            Detector:OnWhisper(...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            Detector:OnSpellcast(...)
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            Detector:OnPICooldownChanged(true)
        end
    end)

    self.lastPIReady = self:QueryPIReady(false)

    C_Timer.After(0.5, function()
        if NS.db and NS:IsActive() then Detector:RefreshAuraDetectors() end
    end)
end

function Detector:OnPlayerRegenEnabled()
    if self.pendingClearAuraStates then
        self.pendingClearAuraStates = false
        self:ClearAuraStates()
    end

    if not NS:IsActive() then
        self.pendingAuraRefresh = false
        return
    end

    self:OnPICooldownChanged(false)
    -- AuraContainer construction is restricted.
    -- Coalesce every combat-time request into one clean out-of-combat refresh.
    if self.pendingAuraRefresh or (self:ShouldEnableSpellVisuals() and self:AllowsSource("SPELL")) then
        self.pendingAuraRefresh = false
        self:ScheduleAuraRefresh(0.05)
    end
end

function Detector:EnsureAuraEngine()
    if self.auraEngineAvailable then return true end
    if not C_AddOns or not C_AddOns.LoadAddOn then return false end

    if C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        if not ok then return false end
    end

    if C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        return false
    end

    self.auraEngineAvailable = true
    return true
end


function Detector:QueryPIReady(fromCooldownEvent)
    -- In Midnight, the numeric cooldown fields (startTime, duration, modRate) can
    -- become secret in combat. SpellCooldownInfo.isActive and isOnGCD are marked
    -- NeverSecret by Blizzard, so readiness uses only those public booleans.
    if not C_Spell or type(C_Spell.GetSpellCooldown) ~= "function" then
        return true
    end

    local ok, info = pcall(C_Spell.GetSpellCooldown, NS.PI_SPELL_ID)
    if not ok or not info then
        return true
    end

    if info.isActive == false then
        self.piCooldownLatched = false
        return true
    end

    -- Once we actually cast PI, keep it unavailable until Blizzard reports that
    -- its cooldown is no longer active. This prevents the simultaneous GCD from
    -- briefly making PI look ready again.
    if self.piCooldownLatched then
        return false
    end

    -- Blizzard documents isOnGCD as trustworthy while handling
    -- SPELL_UPDATE_COOLDOWN. If the only active cooldown reported for PI is the
    -- global cooldown, PI itself is still available.
    if fromCooldownEvent and info.isOnGCD == true then
        return true
    end

    return false
end

function Detector:IsPIReady()
    if self.lastPIReady == nil then
        self.lastPIReady = self:QueryPIReady(false)
    end
    return self.lastPIReady == true
end

function Detector:GetSpellAlertTiming()
    local timing = NS.db and NS.db.alerts and NS.db.alerts.spellAlertTiming
    if timing == "ALWAYS_TRACK" then return "ALWAYS_TRACK" end
    return "PI_READY"
end

function Detector:ShouldEnableSpellVisuals()
    return self:GetSpellAlertTiming() == "ALWAYS_TRACK" or self:IsPIReady()
end

function Detector:OnPICooldownChanged(fromCooldownEvent)
    if not NS.db then return end
    local ready = self:QueryPIReady(fromCooldownEvent == true)
    if ready ~= self.lastPIReady then
        self.lastPIReady = ready
        if self:AllowsSource("SPELL") then
            self:ScheduleAuraRefresh(0.02)
        end
    end
end

function Detector:ScheduleAuraRefresh(delay)
    self.refreshSerial = (self.refreshSerial or 0) + 1
    local serial = self.refreshSerial
    C_Timer.After(delay or 0.05, function()
        if serial ~= Detector.refreshSerial or not NS.db or not NS:IsActive() then return end
        Detector:RefreshAuraDetectors()
    end)
end

function Detector:RefreshRequesterState()
    self:ScheduleAuraRefresh(0.05)
end

function Detector:OnSettingsChanged()
    -- Restricted aura buttons are immutable after their initialization callback.
    -- RefreshAuraState rebuilds only when the frozen visual signature changed.
    self:ScheduleAuraRefresh(0.08)
end

function Detector:AllowsSource(source)
    local mode = NS.db.requests.mode
    if mode == "BOTH" then return true end
    if source == "WHISPER" then return mode == "WHISPER" end
    if source == "SPELL" then return mode == "SPELL" end
    return false
end

function Detector:MatchesWhisper(message)
    local msg = strtrim(message or ""):lower()
    if msg == "" then return false end

    for _, phrase in ipairs(NS.db.requests.phrases or {}) do
        local text = strtrim(phrase.text or ""):lower()
        if text ~= "" then
            if phrase.match == "EXACT" then
                if msg == text then return true end
            else
                if ContainsPhrase(msg, text) then return true end
            end
        end
    end
    return false
end

function Detector:GetSpecificPlayerSet()
    local set = {}
    for _, name in ipairs(NS.db.requesters.players or {}) do
        local normalized = NS:NormalizeName(name)
        if normalized then set[normalized] = true end
    end
    return set
end

function Detector:HasSpecificRequesterInGroup(specificSet)
    local set = specificSet or self:GetSpecificPlayerSet()
    local found = false

    NS:ForEachGroupUnit(function(unit)
        if found then return end
        local unitName = UnitName(unit)
        local normalized = unitName and NS:NormalizeName(unitName)
        if normalized and set[normalized] then
            found = true
        end
    end, true)

    return found
end

function Detector:IsRequesterAllowed(unit, suppliedName)
    local groupUnit = unit
    if not groupUnit or not NS:IsGroupUnit(groupUnit) then
        groupUnit = NS:FindGroupUnitByName(suppliedName)
    end
    if not groupUnit or not UnitExists(groupUnit) then return false, nil end

    local mode = NS.db.requesters.mode
    local isPlayer = UnitIsUnit(groupUnit, "player")

    if mode == "EVERYONE" then
        return not isPlayer, groupUnit
    elseif mode == "FOCUS" then
        if UnitExists("focus") and UnitIsUnit(groupUnit, "focus") then
            return true, groupUnit
        end
        return false, groupUnit
    elseif mode == "SPECIFIC" then
        local set = self:GetSpecificPlayerSet()
        local unitName = UnitName(groupUnit)
        local normalized = unitName and NS:NormalizeName(unitName)

        -- Listed players always win while at least one configured player is
        -- currently present. The fallback is only activated when none of the
        -- configured names are available in the current party/raid.
        if normalized and set[normalized] then
            return true, groupUnit
        end

        if self:HasSpecificRequesterInGroup(set) then
            return false, groupUnit
        end

        local fallback = NS.db.requesters.fallback or "NONE"
        if fallback == "EVERYONE" then
            return not isPlayer, groupUnit
        elseif fallback == "FOCUS" then
            if UnitExists("focus") and UnitIsUnit(groupUnit, "focus") then
                return true, groupUnit
            end
        end
        return false, groupUnit
    end

    return false, groupUnit
end

function Detector:IsSpellTracked(spellID)
    return NS.db.spells and NS.db.spells[tonumber(spellID)] == true
end

function Detector:OnWhisper(message, sender, ...)
    if not NS.db or not self:AllowsSource("WHISPER") then return end
    if not self:MatchesWhisper(message) then return end

    -- CHAT_MSG_WHISPER argument 12 is the sender GUID. Ten arguments remain
    -- after message and sender, so prefer that exact identity over display-name
    -- parsing and retain the name lookup for compatibility/fallback.
    local senderGUID = select(10, ...)
    local groupUnit = NS:FindGroupUnitByGUID(senderGUID)
    if not groupUnit and not NS:IsSecretValue(senderGUID) and senderGUID ~= nil
        and type(UnitTokenFromGUID) == "function"
    then
        local ok, token = pcall(UnitTokenFromGUID, senderGUID)
        if ok and not NS:IsSecretValue(token) and NS:IsGroupUnit(token) then
            groupUnit = token
        end
    end

    local allowed, unit = self:IsRequesterAllowed(groupUnit, sender)
    if not allowed then
        local guidText = NS:IsSecretValue(senderGUID) and "<secret>" or tostring(senderGUID)
        NS:Debug(string.format(
            "Whisper matched but requester was not allowed: sender=%s, guid=%s, resolved=%s, mode=%s.",
            tostring(sender), guidText, tostring(groupUnit),
            tostring(NS.db.requesters and NS.db.requesters.mode)
        ))
        return
    end

    local name = UnitName(unit) or sender
    NS:Debug("Whisper request from " .. tostring(name) .. ": " .. tostring(message))
    NS.RequestManager:Receive(UnitGUID(unit), name, unit, "WHISPER", nil, message)
end

-- -----------------------------------------------------------------------------
-- Patch 12.1 secure ally-buff visuals
--
-- Blizzard now permits exact spell-ID filtering for HELPFUL auras on assistable
-- units through CustomAuraContainer. The aura's presence remains secret to normal
-- addon Lua, so PI Alert does NOT try to turn it into a Lua request event.
-- Instead, the secure aura button itself is the visual: Blizzard shows/hides it
-- when one of the configured cooldown buffs is present.
-- -----------------------------------------------------------------------------

function Detector:GetAuraIDsForSpell(spell)
    if type(spell.auraIds) == "table" and #spell.auraIds > 0 then
        return spell.auraIds
    end

    local logicalID = tonumber(spell.id)
    if not logicalID then return {} end
    if self.cooldownAuraCache and self.cooldownAuraCache[logicalID] then
        return self.cooldownAuraCache[logicalID]
    end

    -- Blizzard's lookup can return nil for cooldowns outside the player's own
    -- spellbook. Always retain the entered/cast ID, then add Blizzard's resolved
    -- aura ID when available. Curated auraIds above handle known split IDs.
    local ids = { logicalID }
    if C_UnitAuras and type(C_UnitAuras.GetCooldownAuraBySpellID) == "function" then
        local ok, auraID = pcall(C_UnitAuras.GetCooldownAuraBySpellID, logicalID)
        if ok and not NS:IsSecretValue(auraID) then
            auraID = tonumber(auraID)
            if auraID and auraID > 0 and auraID ~= logicalID then
                ids[#ids + 1] = auraID
            end
        end
    end

    self.cooldownAuraCache = self.cooldownAuraCache or {}
    self.cooldownAuraCache[logicalID] = ids
    return ids
end

function Detector:BuildAuraMapForClass(classToken)
    local map = {}

    for _, spell in ipairs(NS.PRESET_SPELLS[classToken] or {}) do
        local logicalID = tonumber(spell.id)
        if logicalID and NS.db.spells and NS.db.spells[logicalID] == true then
            for _, auraID in ipairs(self:GetAuraIDsForSpell(spell)) do
                auraID = tonumber(auraID)
                if auraID and auraID > 0 then map[auraID] = true end
            end
        end
    end

    -- Custom spells are treated as aura IDs for allied secure tracking. This is
    -- intentionally class-agnostic; it also keeps self-testing via normal public
    -- UNIT_SPELLCAST_SUCCEEDED working for custom IDs such as Fade.
    for _, spell in ipairs(NS.db.customSpells or {}) do
        local logicalID = tonumber(spell.id)
        if logicalID and NS.db.spells and NS.db.spells[logicalID] == true then
            for _, auraID in ipairs(self:GetAuraIDsForSpell(spell)) do
                auraID = tonumber(auraID)
                if auraID and auraID > 0 then map[auraID] = true end
            end
        end
    end

    return map
end

function Detector:AuraMapSignature(map)
    local ids = {}
    for id in pairs(map or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for i, id in ipairs(ids) do ids[i] = tostring(id) end
    return table.concat(ids, ",")
end


function Detector:GetSecureGlowColor(unit)
    if NS.FrameAlerts and NS.FrameAlerts.GetGlowColor then
        local request = {
            unit = unit,
            guid = UnitGUID(unit),
            name = UnitName(unit),
        }
        local ok, color = pcall(NS.FrameAlerts.GetGlowColor, NS.FrameAlerts, request)
        if ok and type(color) == "table" then return color end
    end
    return { 1.00, 0.82, 0.20, 1.00 }
end

function Detector:GetSecureVisualConfig(unit)
    local alerts = NS.db.alerts or {}
    local auraIcon = NS.db.auraIcon or {}
    local auraIconDefaults = NS.DEFAULTS.auraIcon
    local sourceColor = self:GetSecureGlowColor(unit)
    local color = {
        Clamp(sourceColor[1], 0, 1, 1.00),
        Clamp(sourceColor[2], 0, 1, 0.82),
        Clamp(sourceColor[3], 0, 1, 0.20),
        Clamp(sourceColor[4], 0, 1, 1.00),
    }
    local visual = {
        glow = alerts.glow == true,
        frameIcon = alerts.frameIcon == true,
        frameIconType = alerts.frameIconType == "SPELL" and "SPELL" or "PI",
        frameIconCooldownSwipe = alerts.frameIconCooldownSwipe ~= false,
        auraIcon = alerts.auraIcon == true,
        glowStyle = alerts.glowStyle or "PIXEL",
        glowColor = color,
        glowPixelLines = math.floor(Clamp(alerts.glowPixelLines, 1, 20, 12) + 0.5),
        glowPixelThickness = Clamp(alerts.glowPixelThickness, 1, 8, 2),
        glowAutoCastScale = Clamp(alerts.glowAutoCastScale, 0.5, 3.0, 1.0),
        glowSpeed = Clamp(alerts.glowSpeed, 0.25, 3.0, 1.0),
        auraIconSize = math.floor(Clamp(auraIcon.size, 12, 96, auraIconDefaults.size) + 0.5),
    }
    local signatureParts = {
        visual.glow and "1" or "0",
        visual.frameIcon and "1" or "0",
        visual.auraIcon and "1" or "0",
    }
    if visual.glow then
        signatureParts[#signatureParts + 1] = visual.glowStyle
        signatureParts[#signatureParts + 1] = string.format(
            "%.4f,%.4f,%.4f,%.4f", color[1], color[2], color[3], color[4]
        )
        signatureParts[#signatureParts + 1] = string.format("%.2f", visual.glowPixelThickness)
        signatureParts[#signatureParts + 1] = string.format("%.2f", visual.glowSpeed)
        if visual.glowStyle == "PIXEL" then
            signatureParts[#signatureParts + 1] = tostring(visual.glowPixelLines)
        elseif visual.glowStyle == "AUTOCAST" then
            signatureParts[#signatureParts + 1] = string.format("%.2f", visual.glowAutoCastScale)
        end
    end
    if visual.frameIcon then
        signatureParts[#signatureParts + 1] = visual.frameIconType
        signatureParts[#signatureParts + 1] = visual.frameIconCooldownSwipe and "1" or "0"
    end
    if visual.auraIcon then
        signatureParts[#signatureParts + 1] = tostring(visual.auraIconSize)
    end
    visual.signature = table.concat(signatureParts, ":")
    return visual
end

function Detector:AddSecureAuraSlot(container, key, auraMap, initializeFrame)
    local ok, button = pcall(container.AddAuraSlot, container, key, AURA_FILTER, {
        candidateFilters = { includeSpellIDs = auraMap },
        initializeFrame = initializeFrame,
    })
    if not ok then
        NS:Debug("Could not create secure aura slot '" .. tostring(key) .. "': " .. tostring(button))
        return nil
    end
    return button
end

function Detector:SetAuraStateEnabled(state, enabled)
    if not state then return end
    enabled = enabled and true or false
    if state.enabled == enabled then
        return
    end

    state.enabled = enabled
    if enabled then
        if state.container then
            pcall(state.container.Show, state.container)
            if state.container.SetEnabled then
                local ok = pcall(state.container.SetEnabled, state.container, true)
                if not ok then
                    state.enabled = false
                    self.pendingAuraRefresh = true
                end
            end
            if state.container.UpdateAllAuras then pcall(state.container.UpdateAllAuras, state.container) end
        end
    else
        if state.container then
            if state.container.SetEnabled then pcall(state.container.SetEnabled, state.container, false) end
            pcall(state.container.Hide, state.container)
        end
    end
end

function Detector:CreateSecureAuraState(unit, classToken, target, auraMap, visual)
    if IsInCombatLockdown() then
        self.pendingAuraRefresh = true
        return nil
    end
    if not self:EnsureAuraEngine() then return nil end
    if not target then return nil end

    local signature = self:AuraMapSignature(auraMap)
    visual = visual or self:GetSecureVisualConfig(unit)
    local cacheKey = tostring(unit) .. "|" .. tostring(classToken) .. "|" .. signature .. "|" .. visual.signature
    local cache = self.auraStateCache[target]
    local cached = cache and cache[cacheKey]
    if cached then
        cached.guid = UnitGUID(unit)
        cached.auraMap = auraMap
        self:SetAuraStateEnabled(cached, self:ShouldEnableSpellVisuals())
        return cached
    end

    local container = CreateFrame("AuraContainer", nil, target, "CustomAuraContainerTemplate")
    container:SetAllPoints(target)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(false)
    -- Retail 12.1 initialization order is strict: assign the unit before slots,
    -- then enable the container only after every slot has been registered.
    container:SetUnit(unit)

    local state = {
        unit = unit,
        guid = UnitGUID(unit),
        classToken = classToken,
        target = target,
        auraMap = auraMap,
        signature = signature,
        visualSignature = visual.signature,
        cacheKey = cacheKey,
        container = container,
        enabled = true,
    }

    -- Every property of an AuraButton must be finalized inside initializeFrame.
    -- Once Blizzard applies its restricted aura state, even out-of-combat Lua
    -- calls such as SetAlpha can be rejected as forbidden-object access.
    if visual.glow then
        state.glowButton = self:AddSecureAuraSlot(container, "pip_secure_glow", auraMap, function(button)
            local targetLevel = 1
            local ok, level = pcall(target.GetFrameLevel, target)
            if ok and not NS:IsSecretValue(level) and type(level) == "number" then
                targetLevel = level
            end
            button:EnableMouse(false)
            button:SetAllPoints(target)
            button:SetFrameStrata("HIGH")
            button:SetFrameLevel(targetLevel + 15)
            -- Build and start the native pulse before Blizzard seals the AuraButton.
            -- Its parent button still controls whether the glow is visible.
            local visualHost = CreateFrame("Frame", nil, button)
            visualHost:SetAllPoints(button)
            CreateSecureGlowArt(visualHost, target, visual)
        end)
    end

    if visual.frameIcon then
        state.frameIconButton = self:AddSecureAuraSlot(container, "pip_secure_frame_icon", auraMap, function(button)
            button:EnableMouse(false)
            button:SetPoint("CENTER", target, "CENTER", 0, 0)
            button:SetFrameStrata("HIGH")
            button:SetFrameLevel(1001)
            AddRaidframeIcon(button, 22, visual.frameIconCooldownSwipe, visual.frameIconType)
        end)
    end

    if visual.auraIcon and NS.FrameAlerts and NS.FrameAlerts.auraIcon then
        local auraAnchor = NS.FrameAlerts.auraIcon
        state.auraIconButton = self:AddSecureAuraSlot(container, "pip_secure_aura_icon", auraMap, function(button)
            button:EnableMouse(false)
            button:SetPoint("CENTER", auraAnchor, "CENTER", 0, 0)
            button:SetFrameStrata("HIGH")
            button:SetFrameLevel(1002)
            AddRaidframeIcon(button, visual.auraIconSize, false, "PI")
        end)
    end

    -- Enabled LAST so Blizzard wires aura events after the slot topology exists.
    container:SetEnabled(true)
    container:UpdateAllAuras()
    container:Show()

    if not cache then
        cache = {}
        self.auraStateCache[target] = cache
    end
    cache[cacheKey] = state

    NS:Debug(string.format(
        "Secure ally tracker ready: %s (%s) -> [%s]",
        tostring(UnitName(unit) or unit), tostring(unit), state.signature
    ))

    return state
end

function Detector:RetireAuraState(state)
    if not state then return end

    if IsInCombatLockdown() then
        self.pendingAuraRefresh = true
        self:SetAuraStateEnabled(state, false)
        return false
    end

    SafeDisableContainer(state.container)
    state.enabled = false
    return true
end

function Detector:ClearAuraStates()
    if IsInCombatLockdown() then
        self.pendingClearAuraStates = true
        for _, state in pairs(self.auraStates or {}) do
            self:SetAuraStateEnabled(state, false)
        end
        return
    end
    for _, state in pairs(self.auraStates or {}) do
        self:RetireAuraState(state)
    end
    wipe(self.auraStates)
end

function Detector:ResolveRaidFrameForUnit(unit)
    if not NS.FrameAlerts or not NS.FrameAlerts.ResolveFrame then return nil end
    local request = {
        unit = unit,
        guid = UnitGUID(unit),
        name = UnitName(unit),
    }
    local ok, frame = pcall(NS.FrameAlerts.ResolveFrame, NS.FrameAlerts, request)
    if ok then return frame end
    return nil
end

function Detector:RefreshAuraState(unit)
    if not unit or not UnitExists(unit) then return end
    local state = self.auraStates[unit]

    if not self:AllowsSource("SPELL") then
        if state then self:RetireAuraState(state); self.auraStates[unit] = nil end
        return
    end

    local allowed = self:IsRequesterAllowed(unit, UnitName(unit))
    if not allowed then
        if state then self:RetireAuraState(state); self.auraStates[unit] = nil end
        return
    end

    -- Blizzard deliberately does not apply helpful-aura identity filters to
    -- units the player cannot assist. Skipping them prevents the filter from
    -- failing open and matching an unrelated helpful aura.
    local assistOK, canAssist = pcall(UnitCanAssist, "player", unit)
    if not assistOK or NS:IsSecretValue(canAssist) or canAssist ~= true then
        if state then self:RetireAuraState(state); self.auraStates[unit] = nil end
        return
    end

    local _, classToken = UnitClass(unit)
    if not classToken then return end

    local auraMap = self:BuildAuraMapForClass(classToken)
    local signature = self:AuraMapSignature(auraMap)
    local visual = self:GetSecureVisualConfig(unit)
    if signature == "" then
        if state then self:RetireAuraState(state); self.auraStates[unit] = nil end
        return
    end

    local guid = UnitGUID(unit)
    if state and (state.guid ~= guid or state.classToken ~= classToken or state.signature ~= signature
        or state.visualSignature ~= visual.signature)
    then
        self:RetireAuraState(state)
        self.auraStates[unit] = nil
        state = nil
    end

    local target = self:ResolveRaidFrameForUnit(unit)
    if not target then
        -- Never leave a previously valid token glowing on a frame we can no
        -- longer confirm. A resolver callback will enable it again later.
        if state then self:SetAuraStateEnabled(state, false) end
        NS:Debug("Secure aura tracker is waiting for a raid/party frame for " .. tostring(UnitName(unit) or unit))
        return
    end

    local needsRebuild = not state or state.target ~= target

    if not needsRebuild then
        self:SetAuraStateEnabled(state, self:ShouldEnableSpellVisuals())
        return
    end

    if state then self:RetireAuraState(state) end
    state = self:CreateSecureAuraState(unit, classToken, target, auraMap, visual)
    self.auraStates[unit] = state
    if state then
        self:SetAuraStateEnabled(state, self:ShouldEnableSpellVisuals())
    end
end

function Detector:RefreshAuraDetectors()
    if not NS.db or not NS:IsActive() then return end

    if IsInCombatLockdown() then
        self.pendingAuraRefresh = true
        self.lastPIReady = self:IsPIReady()
        -- Existing containers are already structurally complete. SetEnabled is
        -- safe to attempt in combat and is the only way to restore alerts when
        -- PI finishes its cooldown during a long encounter.
        local visualsEnabled = self:ShouldEnableSpellVisuals()
        for _, state in pairs(self.auraStates or {}) do
            self:SetAuraStateEnabled(state, visualsEnabled)
        end
        return
    end
    self.pendingAuraRefresh = false

    if not self:AllowsSource("SPELL") then
        self:ClearAuraStates()
        return
    end

    self.lastPIReady = self:IsPIReady()
    if not self:ShouldEnableSpellVisuals() then
        for _, state in pairs(self.auraStates or {}) do
            self:SetAuraStateEnabled(state, false)
        end
    end

    local present = {}
    NS:ForEachGroupUnit(function(unit)
        present[unit] = true
        self:RefreshAuraState(unit)
    end, true)

    for unit, state in pairs(self.auraStates or {}) do
        if not present[unit] then
            self:RetireAuraState(state)
            self.auraStates[unit] = nil
        end
    end

end

function Detector:ApplyPICooldownAlertPolicy()
    self.lastPIReady = false
    local visualsEnabled = self:ShouldEnableSpellVisuals()
    for _, state in pairs(self.auraStates or {}) do
        self:SetAuraStateEnabled(state, visualsEnabled)
    end
end

function Detector:PrintTrackerStatus()
    local enabledSpells = 0
    for _, enabled in pairs((NS.db and NS.db.spells) or {}) do
        if enabled == true then enabledSpells = enabledSpells + 1 end
    end

    local activeTrackers = 0
    for _ in pairs(self.auraStates or {}) do activeTrackers = activeTrackers + 1 end
    NS:Print(string.format(
        "Spell trackers: %d enabled spell(s), %d active secure tracker(s), timing=%s, PI ready=%s, combat=%s.",
        enabledSpells, activeTrackers, self:GetSpellAlertTiming(), tostring(self:IsPIReady()), tostring(IsInCombatLockdown())
    ))

    for _, configuredName in ipairs((NS.db.requesters and NS.db.requesters.players) or {}) do
        local unit = NS:FindGroupUnitByName(configuredName)
        if not unit then
            NS:Print(tostring(configuredName) .. " -> not found in the current group.")
        else
            local _, classToken = UnitClass(unit)
            local assistOK, canAssist = pcall(UnitCanAssist, "player", unit)
            if not assistOK or NS:IsSecretValue(canAssist) then canAssist = "unknown" end
            local state = self.auraStates and self.auraStates[unit]
            local signature = state and state.signature or "none"
            if not state and not IsInCombatLockdown() and classToken then
                signature = self:AuraMapSignature(self:BuildAuraMapForClass(classToken))
                if signature == "" then signature = "none" end
            end
            NS:Print(string.format(
                "%s -> %s (%s), assistable=%s, aura IDs=[%s], tracker=%s.",
                tostring(configuredName), tostring(unit), tostring(classToken or "UNKNOWN"),
                tostring(canAssist), tostring(signature), state and "active" or "missing"
            ))
        end
    end
end

function Detector:OnSpellcast(unit, castGUID, spellID, castBarID)
    if not NS.db or not NS:IsActive() then return end

    -- The player's own spell ID remains public. PI still needs an immediate
    -- readiness update; every other tracked self aura is handled by the same
    -- secure CustomAuraContainer path used for party and raid members.
    if not NS:IsSecretValue(unit) and unit == "player" and not NS:IsSecretValue(spellID) then
        local publicSpellID = tonumber(spellID)
        if publicSpellID == NS.PI_SPELL_ID then
            self.piCooldownLatched = true
            NS.RequestManager:ClearAll("Power Infusion cast")
            self:ApplyPICooldownAlertPolicy()
            return
        end
        return
    end

    if not self:AllowsSource("SPELL") then return end

    -- Allied spell IDs can be secret in Midnight. That's expected now; the
    -- secure CustomAuraContainer above handles allied buff matching visually.
    if NS:IsSecretValue(unit) or NS:IsSecretValue(spellID) then
        if NS.db.debug and GetTime() - (self.lastSecretDebugAt or 0) > 2 then
            self.lastSecretDebugAt = GetTime()
            NS:Debug("Allied cast details are secret; secure 12.1 ally-buff visuals are handling tracked cooldowns instead.")
        end
        return
    end

    -- Do not create a second normal Lua request for allied public casts. A
    -- matching helpful cooldown aura will be represented by the secure tracker,
    -- keeping the spell path consistent for public and secret casts.
end
