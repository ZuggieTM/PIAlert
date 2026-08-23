local ADDON_NAME, ns = ...

local SLOT_KEY = "piPriority"
local FILTER = "HELPFUL"
local CENTER_SIZE = 72
local RAID_ICON_SIZE = 22

ns.centerStates = {}
ns.raidAlertStates = setmetatable({}, { __mode = "k" })
ns.raidFramesByUnit = {}
ns.roster = {}
ns.rosterByUnit = {}
ns.fallbackMode = "NONE"
ns.piReady = false
ns.auraEngineAvailable = false
ns.lastEngineError = nil
ns.pendingFrameRescan = false

local function SafeBool(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function SetTextureColor(tex, r, g, b, a)
    tex:SetColorTexture(r, g, b, a)
end

local function MakeBorder(parent, thickness)
    local border = CreateFrame("Frame", nil, parent)
    border:SetAllPoints(parent)
    border:EnableMouse(false)
    border:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)

    local edges = {}
    for i = 1, 4 do
        edges[i] = border:CreateTexture(nil, "OVERLAY")
        SetTextureColor(edges[i], 1, 0.82, 0.12, 1)
    end

    thickness = thickness or 2
    edges[1]:SetPoint("TOPLEFT", -2, 2)
    edges[1]:SetPoint("TOPRIGHT", 2, 2)
    edges[1]:SetHeight(thickness)
    edges[2]:SetPoint("BOTTOMLEFT", -2, -2)
    edges[2]:SetPoint("BOTTOMRIGHT", 2, -2)
    edges[2]:SetHeight(thickness)
    edges[3]:SetPoint("TOPLEFT", -2, 2)
    edges[3]:SetPoint("BOTTOMLEFT", -2, -2)
    edges[3]:SetWidth(thickness)
    edges[4]:SetPoint("TOPRIGHT", 2, 2)
    edges[4]:SetPoint("BOTTOMRIGHT", 2, -2)
    edges[4]:SetWidth(thickness)

    return border
end

local function MakeGlowArt(button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.EnableMouse, button, false)

    local host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    host:EnableMouse(false)
    host:SetFrameLevel((button:GetFrameLevel() or 1) + 5)

    local thickness = 3
    local top = host:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", host, "TOPLEFT", -2, 2)
    top:SetPoint("TOPRIGHT", host, "TOPRIGHT", 2, 2)
    top:SetHeight(thickness)
    SetTextureColor(top, 1, 0.82, 0.12, 1)

    local bottom = host:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -2, -2)
    bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 2, -2)
    bottom:SetHeight(thickness)
    SetTextureColor(bottom, 1, 0.82, 0.12, 1)

    local left = host:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", host, "TOPLEFT", -2, 2)
    left:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -2, -2)
    left:SetWidth(thickness)
    SetTextureColor(left, 1, 0.82, 0.12, 1)

    local right = host:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", host, "TOPRIGHT", 2, 2)
    right:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 2, -2)
    right:SetWidth(thickness)
    SetTextureColor(right, 1, 0.82, 0.12, 1)

    local pulse = host:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.3)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.4)
    alpha:SetSmoothing("IN_OUT")
    pulse:Play()

    return host
end

function ns:EnsureAuraEngine()
    if self.auraEngineAvailable then return true end
    if not C_AddOns or not C_AddOns.LoadAddOn then
        self.lastEngineError = "C_AddOns is unavailable"
        return false
    end

    local ok, loadedOrReason = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    if not ok then
        self.lastEngineError = tostring(loadedOrReason)
        return false
    end

    if C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        self.lastEngineError = tostring(loadedOrReason or "Blizzard_AuraContainer did not load")
        return false
    end

    self.auraEngineAvailable = true
    return true
end

function ns:IsPIReady()
    if not C_Spell or not C_Spell.GetSpellCooldown then return false end
    local cd = C_Spell.GetSpellCooldown(self.PI_SPELL_ID)
    if not cd or cd.isEnabled == false then return false end

    local duration = tonumber(cd.duration) or 0
    if duration <= 0 then return true end

    local gcd = C_Spell.GetSpellCooldown(self.GCD_SPELL_ID)
    if gcd then
        local gcdDuration = tonumber(gcd.duration) or 0
        local cdStart = tonumber(cd.startTime) or 0
        local gcdStart = tonumber(gcd.startTime) or 0
        if gcdDuration > 0
            and math.abs(duration - gcdDuration) < 0.08
            and math.abs(cdStart - gcdStart) < 0.08 then
            return true
        end
    end

    return false
end

local function UnitFullName(unit)
    local name, realm = UnitName(unit)
    if not name then return nil, nil end
    if realm and realm ~= "" then
        return name, name .. "-" .. realm
    end
    return name, name
end

function ns:NamePreferenceRank(unit, nameLookup)
    local short, full = UnitFullName(unit)
    if not short then return nil end
    local fullRank = nameLookup[full:lower()]
    if fullRank then return fullRank end
    return nameLookup[short:lower()]
end

function ns:BuildRoster()
    wipe(self.roster)
    wipe(self.rosterByUnit)

    local function Add(unit, index)
        if not UnitExists(unit) then return end
        local _, class = UnitClass(unit)
        if not class then return end
        local short, full = UnitFullName(unit)
        local record = {
            unit = unit,
            index = index,
            class = class,
            shortName = short or unit,
            fullName = full or short or unit,
        }
        self.roster[#self.roster + 1] = record
        self.rosterByUnit[unit] = record
    end

    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do Add("raid" .. i, i) end
    elseif IsInGroup() then
        Add("player", 0)
        local n = GetNumSubgroupMembers()
        for i = 1, n do Add("party" .. i, i) end
    else
        Add("player", 0)
    end
end

function ns:DetermineFallbackMode()
    local _, nameLookup = self:ParsePreferredNames()
    local hasNames = next(nameLookup) ~= nil
    local grouped = IsInGroup() or IsInRaid()

    local hasPreferredClasses = false
    for _, class in ipairs(self.CLASS_ORDER) do
        if self.db.classes[class] == true then
            hasPreferredClasses = true
            break
        end
    end

    -- Self is intentionally ignored when choosing the fallback LEVEL while grouped.
    -- includeSelf exists mainly for self-testing and should not force a party/raid
    -- into NAME or CLASS mode just because the priest itself matches a preference.
    local function CountsForFallback(rec)
        if not grouped then return true end
        return not UnitIsUnit(rec.unit, "player")
    end

    local namedPlayerPresent = false
    if hasNames then
        for _, rec in ipairs(self.roster) do
            if CountsForFallback(rec) and self:NamePreferenceRank(rec.unit, nameLookup) then
                namedPlayerPresent = true
                break
            end
        end
    end

    local preferredClassPresent = false
    if hasPreferredClasses then
        for _, rec in ipairs(self.roster) do
            if CountsForFallback(rec) and self.db.classes[rec.class] == true then
                preferredClassPresent = true
                break
            end
        end
    end

    -- Priority semantics:
    --   * Configured + present names always win.
    --   * If no names are configured, preferred classes are the primary filter;
    --     the "fall back to preferred classes" checkbox is irrelevant in that case.
    --   * If names ARE configured but absent, classFallback decides whether the
    --     chain is allowed to continue to preferred classes.
    --   * anyFallback is only considered after the class stage has legitimately
    --     been reached and no preferred class is present.
    if hasNames then
        if namedPlayerPresent then
            self.fallbackMode = "NAME"
            return
        end

        if not self.db.classFallback then
            self.fallbackMode = "NONE"
            return
        end

        if hasPreferredClasses and preferredClassPresent then
            self.fallbackMode = "CLASS"
            return
        end

        self.fallbackMode = self.db.anyFallback and "ANY" or "NONE"
        return
    end

    if hasPreferredClasses then
        if preferredClassPresent then
            self.fallbackMode = "CLASS"
            return
        end

        self.fallbackMode = self.db.anyFallback and "ANY" or "NONE"
        return
    end

    -- No names and no preferred classes means there is nothing more specific
    -- to choose. In that situation, "fallback to anyone" intentionally becomes
    -- the master switch for whether any tracked class may be suggested.
    self.fallbackMode = self.db.anyFallback and "ANY" or "NONE"
end

function ns:IsUnitPriorityEligible(rec)
    if not rec then return false, nil end
    if not self.db.enabled then return false, nil end
    if not self.db.includeSelf and UnitIsUnit(rec.unit, "player") then return false, nil end

    local _, nameLookup = self:ParsePreferredNames()
    if self.fallbackMode == "NAME" then
        local rank = self:NamePreferenceRank(rec.unit, nameLookup)
        return rank ~= nil, rank
    elseif self.fallbackMode == "CLASS" then
        return self.db.classes[rec.class] == true, rec.index
    elseif self.fallbackMode == "ANY" then
        return true, rec.index
    end
    return false, nil
end

function ns:IsUnitSafeForSpellFiltering(unit)
    if not UnitExists(unit) then return false end
    if not self.db.includeSelf and UnitIsUnit(unit, "player") then return false end

    if UnitCanAssist then
        local ok, assist = pcall(UnitCanAssist, "player", unit)
        assist = ok and SafeBool(assist) or nil
        if assist ~= true then return false end
    end

    if UnitIsConnected then
        local ok, connected = pcall(UnitIsConnected, unit)
        connected = ok and SafeBool(connected) or nil
        if connected == false then return false end
    end

    if UnitIsDeadOrGhost then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        dead = ok and SafeBool(dead) or nil
        if dead == true then return false end
    end

    return true
end

function ns:ShouldEnableForRecord(rec)
    local eligible, rank = self:IsUnitPriorityEligible(rec)
    if not eligible then return false, rank, nil, 0 end

    -- Do NOT preflight allied units with UnitCanAssist / UnitIsConnected /
    -- UnitIsDeadOrGhost here. In 12.1 restricted aura contexts some unit-query
    -- results can be secret. Treating an unreadable result as "not safe" silently
    -- disabled every detector for that ally. AuraContainer already owns the
    -- secret-safe decision of whether a matching helpful aura exists.
    local map, count, signature = self:GetCandidateSpellMap(rec.class)
    if count == 0 then return false, rank, map, count, signature end
    return self.piReady == true, rank, map, count, signature
end

local function PlayAlertSound()
    if not ns.db or not ns.db.sound or not ns.piReady then return end
    if PlaySoundFile then
        pcall(PlaySoundFile, ns.SOUND_FILE, "Master")
    end
end

function ns:CreateCenterState(rec, candidateMap)
    if not self:EnsureAuraEngine() then return nil end

    local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 55)
    container:SetSize(CENTER_SIZE, CENTER_SIZE)
    container:SetFrameStrata("HIGH")

    local state = { container = container, unit = rec.unit, rec = rec, candidateSignature = nil }
    local buttonData

    local function Init(button)
        pcall(button.SetMouseClickEnabled, button, false)
        pcall(button.EnableMouse, button, false)
        button:SetAllPoints(container)

        -- The AuraContainer still receives an icon texture so it can update the
        -- aura normally, but that texture is hidden. The visible center icon is
        -- deliberately always Power Infusion.
        local internalIcon = button:CreateTexture(nil, "ARTWORK")
        internalIcon:SetAllPoints(button)
        internalIcon:SetAlpha(0)
        button:SetIcon(internalIcon)

        local visual = CreateFrame("Frame", nil, button)
        visual:SetAllPoints(button)
        visual:EnableMouse(false)
        visual:SetFrameLevel((button:GetFrameLevel() or 1) + 2)

        local icon = visual:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(visual)
        icon:SetTexture(ns:GetSpellIcon(ns.PI_SPELL_ID))
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        MakeBorder(visual, 2)

        local title = visual:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("BOTTOM", button, "TOP", 0, 8)
        title:SetText("POWER INFUSION")

        local name = visual:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        name:SetPoint("TOP", button, "BOTTOM", 0, -7)
        name:SetText(rec.shortName or rec.unit)

        button:HookScript("OnShow", PlayAlertSound)
        button:HookScript("OnShow", function()
            if ns.Debug then ns:Debug("center detector SHOW " .. tostring(rec.unit) .. " " .. tostring(rec.shortName) .. " ids=" .. tostring(state.candidateSignature or "pending")) end
        end)
        button:HookScript("OnHide", function()
            if ns.Debug then ns:Debug("center detector HIDE " .. tostring(rec.unit) .. " " .. tostring(rec.shortName)) end
        end)
        buttonData = { name = name, visual = visual, icon = icon }
    end

    container:AddAuraSlot(SLOT_KEY, FILTER, {
        candidateFilters = { includeSpellIDs = candidateMap },
        initializeFrame = Init,
    })
    container:SetUnit(rec.unit)
    container:SetEnabled(false)
    container:Hide()
    container:UpdateAllAuras()

    state.buttonData = buttonData
    local _, _, signature = self:GetCandidateSpellMap(rec.class)
    state.candidateSignature = signature
    self.centerStates[rec.unit] = state
    return state
end

function ns:UpdateCenterState(rec)
    local enabled, rank, map, count, signature = self:ShouldEnableForRecord(rec)
    local state = self.centerStates[rec.unit]

    if not state and count > 0 then
        state = self:CreateCenterState(rec, map)
    end
    if not state then return end

    state.rec = rec
    if state.unit ~= rec.unit then
        state.unit = rec.unit
        pcall(state.container.SetUnit, state.container, rec.unit)
    end
    if state.buttonData then
        if state.buttonData.name then
            state.buttonData.name:SetText(rec.shortName or rec.unit)
        end
        if state.buttonData.visual then
            state.buttonData.visual:SetShown(self.db.centerIcon == true and enabled == true and count > 0)
        end
        if state.buttonData.icon then
            state.buttonData.icon:SetTexture(self:GetSpellIcon(self.PI_SPELL_ID))
        end
    end

    if count > 0 and state.candidateSignature ~= signature then
        pcall(state.container.SetAuraSlotCandidateFilters, state.container, SLOT_KEY, { includeSpellIDs = map })
        state.candidateSignature = signature
    end

    local levelRank = tonumber(rank) or tonumber(rec.index) or 99
    state.container:SetFrameLevel(900 - math.min(levelRank, 100))

    -- Keep the detector alive for sound even when the center visual is disabled.
    -- IMPORTANT: an ineligible detector is HIDDEN as well as disabled. Disabling
    -- AuraContainer schedules its aura cleanup on a dirty pass; hiding it gives us
    -- an immediate, deterministic visual clear when fallback settings change.
    local wantsDetection = self.db.centerIcon or self.db.sound
    local shouldRun = wantsDetection and enabled and count > 0
    if shouldRun then
        state.container:Show()
        state.container:SetEnabled(true)
    else
        state.container:SetEnabled(false)
        state.container:Hide()
    end
end

local function GetSecureUnitToken(frame)
    if not frame or not frame.GetAttribute then return nil end
    local ok, unit = pcall(frame.GetAttribute, frame, "unit")
    if ok and type(unit) == "string" and unit ~= "" then
        return unit
    end
    return nil
end

local function IsGroupUnitToken(unit)
    if type(unit) ~= "string" then return false end
    if unit:match("^raid%d+$") or unit:match("^party%d+$") then return true end
    if unit == "player" and ns.db and ns.db.includeSelf then return true end
    return false
end

local function HasSameUnitAncestor(frame, unit)
    local parent = frame and frame.GetParent and frame:GetParent() or nil
    local depth = 0
    while parent and depth < 12 do
        depth = depth + 1
        if GetSecureUnitToken(parent) == unit then
            return true
        end
        parent = parent.GetParent and parent:GetParent() or nil
    end
    return false
end

local function FrameLooksLikeRaidFrame(frame)
    if not frame or not frame.GetWidth or not frame.GetHeight then return false end

    if frame.GetObjectType then
        local okType, objectType = pcall(frame.GetObjectType, frame)
        if okType and objectType ~= "Button" then return false end
    end

    local okW, w = pcall(frame.GetWidth, frame)
    local okH, h = pcall(frame.GetHeight, frame)
    if not okW or not okH or type(w) ~= "number" or type(h) ~= "number" then return false end
    return w >= 35 and h >= 16 and w <= 500 and h <= 180
end

local function FrameCandidateScore(frame)
    local score = 0
    local name = frame.GetName and frame:GetName() or nil
    local lower = name and name:lower() or ""

    if lower:find("compactraidframe", 1, true) or lower:find("compactpartyframe", 1, true) then
        score = score + 500
    elseif lower:find("raidframe", 1, true) or lower:find("partyframe", 1, true) then
        score = score + 350
    elseif lower:find("raid", 1, true) or lower:find("party", 1, true) or lower:find("group", 1, true) then
        score = score + 150
    end

    if lower:find("buff", 1, true)
        or lower:find("debuff", 1, true)
        or lower:find("aura", 1, true)
        or lower:find("indicator", 1, true)
        or lower:find("icon", 1, true)
        or lower:find("cooldown", 1, true) then
        score = score - 1000
    end

    if frame.IsProtected then
        local ok, protected = pcall(frame.IsProtected, frame)
        if ok and protected then score = score + 75 end
    end

    local okW, w = pcall(frame.GetWidth, frame)
    local okH, h = pcall(frame.GetHeight, frame)
    if okW and okH and type(w) == "number" and type(h) == "number" then
        if w >= h then score = score + 15 end
        score = score + math.min((w * h) / 1000, 25)
    end

    return score
end

function ns:ScanRaidFrames()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingFrameRescan = true
        return false
    end

    self.pendingFrameRescan = false

    local best = {}
    local frame = EnumerateFrames()
    local safety = 0
    while frame do
        safety = safety + 1
        if safety > 25000 then break end

        local unit = GetSecureUnitToken(frame)
        local rec = unit and self.rosterByUnit[unit]
        if rec and IsGroupUnitToken(unit) and FrameLooksLikeRaidFrame(frame) and not HasSameUnitAncestor(frame, unit) then
            local shown = true
            if frame.IsShown then
                local ok, value = pcall(frame.IsShown, frame)
                shown = ok and value == true
            end

            if shown then
                local score = FrameCandidateScore(frame)
                if not best[unit] or score > best[unit].score then
                    best[unit] = { frame = frame, score = score }
                end
            end
        end

        frame = EnumerateFrames(frame)
    end

    wipe(self.raidFramesByUnit)
    for unit, candidate in pairs(best) do
        self.raidFramesByUnit[unit] = candidate.frame
    end

    return true
end

function ns:CreateRaidAlertState(frame, rec, candidateMap)
    if not self:EnsureAuraEngine() then return nil end

    local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    container:SetAllPoints(frame)
    container:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)

    local state = { frame = frame, container = container, unit = rec.unit, rec = rec, candidateSignature = nil }
    local buttonData

    local function Init(button)
        pcall(button.SetMouseClickEnabled, button, false)
        pcall(button.EnableMouse, button, false)
        button:SetAllPoints(container)

        local internalIcon = button:CreateTexture(nil, "ARTWORK")
        internalIcon:SetAllPoints(button)
        internalIcon:SetAlpha(0)
        button:SetIcon(internalIcon)

        local glow = MakeGlowArt(button)
        -- Start hidden. The aura button itself is engine-driven, but our child
        -- regions must also be explicitly cleared when settings/eligibility change.
        glow:Hide()

        local iconHost = CreateFrame("Frame", nil, button)
        iconHost:SetSize(RAID_ICON_SIZE, RAID_ICON_SIZE)
        iconHost:SetPoint("CENTER", button, "CENTER", 0, 0)
        iconHost:EnableMouse(false)
        iconHost:SetFrameLevel((button:GetFrameLevel() or 1) + 7)
        iconHost:Hide()

        local icon = iconHost:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconHost)
        icon:SetTexture(ns:GetSpellIcon(ns.PI_SPELL_ID))
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        MakeBorder(iconHost, 1)

        button:HookScript("OnShow", function()
            if ns.Debug then ns:Debug("raid detector SHOW " .. tostring(rec.unit) .. " " .. tostring(rec.shortName) .. " ids=" .. tostring(state.candidateSignature or "pending")) end
        end)
        button:HookScript("OnHide", function()
            if ns.Debug then ns:Debug("raid detector HIDE " .. tostring(rec.unit) .. " " .. tostring(rec.shortName)) end
        end)
        buttonData = { glow = glow, iconHost = iconHost, icon = icon }
    end

    container:AddAuraSlot(SLOT_KEY, FILTER, {
        candidateFilters = { includeSpellIDs = candidateMap },
        initializeFrame = Init,
    })
    container:SetUnit(rec.unit)
    container:SetEnabled(false)
    container:Hide()
    container:UpdateAllAuras()

    state.buttonData = buttonData
    local _, _, signature = self:GetCandidateSpellMap(rec.class)
    state.candidateSignature = signature
    self.raidAlertStates[frame] = state
    return state
end

function ns:UpdateRaidAlertState(frame, rec)
    local enabled, _, map, count, signature = self:ShouldEnableForRecord(rec)
    local state = self.raidAlertStates[frame]

    if not state and count > 0 then
        state = self:CreateRaidAlertState(frame, rec, map)
    end
    if not state then return end

    state.seen = true
    state.rec = rec

    if state.unit ~= rec.unit then
        state.unit = rec.unit
        pcall(state.container.SetUnit, state.container, rec.unit)
    end

    if count > 0 and state.candidateSignature ~= signature then
        pcall(state.container.SetAuraSlotCandidateFilters, state.container, SLOT_KEY, { includeSpellIDs = map })
        state.candidateSignature = signature
    end

    if state.buttonData then
        if state.buttonData.glow then
            state.buttonData.glow:SetShown(self.db.raidGlow == true and enabled == true and count > 0)
        end
        if state.buttonData.iconHost then
            state.buttonData.iconHost:SetShown(self.db.raidIcon == true and enabled == true and count > 0)
        end
        if state.buttonData.icon then
            state.buttonData.icon:SetTexture(self:GetSpellIcon(self.PI_SPELL_ID))
        end
    end

    local wantsRaidAlert = self.db.raidGlow or self.db.raidIcon
    local shouldRun = wantsRaidAlert and enabled and count > 0
    if shouldRun then
        state.container:Show()
        state.container:SetEnabled(true)
    else
        state.container:SetEnabled(false)
        state.container:Hide()
    end
end

function ns:RefreshRaidFrameAlerts(rescan)
    for _, state in pairs(self.raidAlertStates) do
        state.seen = false
        -- Do not wait for Blizzard_AuraContainer's deferred dirty pass to clear
        -- the aura button. Settings changes must remove our overlay immediately.
        if state.buttonData then
            if state.buttonData.glow then state.buttonData.glow:Hide() end
            if state.buttonData.iconHost then state.buttonData.iconHost:Hide() end
        end
        state.container:SetEnabled(false)
        state.container:Hide()
    end

    if rescan then
        self:ScanRaidFrames()
    end

    if not self.db.enabled or not self.piReady or (not self.db.raidGlow and not self.db.raidIcon) then
        return
    end

    for unit, frame in pairs(self.raidFramesByUnit) do
        local rec = self.rosterByUnit[unit]
        if rec and frame then
            self:UpdateRaidAlertState(frame, rec)
        end
    end
end

function ns:RequestRaidFrameRescan(delay)
    delay = tonumber(delay) or 0
    C_Timer.After(delay, function()
        if not ns.db or not ns.db.enabled then return end
        ns:BuildRoster()
        ns:DetermineFallbackMode()
        ns:RefreshRaidFrameAlerts(true)
    end)
end

function ns:ApplyPIGate()
    for unit, state in pairs(self.centerStates) do
        local rec = self.rosterByUnit[unit]
        if rec then
            self:UpdateCenterState(rec)
        else
            if state.buttonData and state.buttonData.visual then state.buttonData.visual:Hide() end
            state.container:SetEnabled(false)
            state.container:Hide()
        end
    end

    self:RefreshRaidFrameAlerts(false)
end


function ns:ClearAllAlerts()
    -- Hard visual/detector reset. AuraContainer normally clears assignments on
    -- its deferred dirty pass; configuration priority changes must not inherit a
    -- previously visible secret-driven aura button from the old eligibility mode.
    for _, state in pairs(self.centerStates or {}) do
        if state.buttonData and state.buttonData.visual then
            state.buttonData.visual:Hide()
        end
        if state.container then
            state.container:SetEnabled(false)
            state.container:Hide()
        end
    end

    for _, state in pairs(self.raidAlertStates or {}) do
        if state.buttonData then
            if state.buttonData.glow then state.buttonData.glow:Hide() end
            if state.buttonData.iconHost then state.buttonData.iconHost:Hide() end
        end
        if state.container then
            state.container:SetEnabled(false)
            state.container:Hide()
        end
    end
end

function ns:RefreshAll(reason, rescanFrames)
    local previousFallbackMode = self.fallbackMode

    self:BuildRoster()
    self:DetermineFallbackMode()
    self.piReady = self:IsPIReady()

    -- Changing NAME/CLASS/ANY/NONE can leave the same unit eligible across both
    -- modes (for example ANY -> CLASS for a Demon Hunter). Force a clean detector
    -- rebind on mode transitions so no previous aura assignment can leak forward.
    if previousFallbackMode ~= self.fallbackMode then
        self:ClearAllAlerts()
    end

    local active = {}
    for _, rec in ipairs(self.roster) do
        active[rec.unit] = true
        self:UpdateCenterState(rec)
    end
    for unit, state in pairs(self.centerStates) do
        if not active[unit] then
            if state.buttonData and state.buttonData.visual then state.buttonData.visual:Hide() end
            state.container:SetEnabled(false)
            state.container:Hide()
        end
    end

    self:RefreshRaidFrameAlerts(rescanFrames == true)
end

function ns:RefreshPIState()
    local ready = self:IsPIReady()
    if ready == self.piReady then return end
    self.piReady = ready
    self:ApplyPIGate()
    if self.optionsFrame and self.optionsFrame:IsShown() and self.UpdateOptionsStatus then
        self:UpdateOptionsStatus()
    end
end
