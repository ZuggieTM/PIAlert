local ADDON_NAME, NS = ...

local Detector = {}
NS.Detector = Detector

local AURA_FILTER = "HELPFUL"

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

local function AddPIIcon(frame, size)
    size = math.floor(Clamp(size, 12, 96, 22) + 0.5)
    frame:SetSize(size, size)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.02, 0.03, 0.04, 0.96)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture(NS:GetSpellIcon(NS.PI_SPELL_ID))

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
    -- AuraContainer construction and aura-sound registration are restricted.
    -- Coalesce every combat-time request into one clean out-of-combat refresh.
    if self.pendingAuraRefresh or (self:IsPIReady() and self:AllowsSource("SPELL")) then
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
    -- Existing secure slots are restyled in place. A new container is created
    -- only when its unit, frame, or exact aura-ID signature actually changes.
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

function Detector:OnWhisper(message, sender)
    if not NS.db or not self:AllowsSource("WHISPER") then return end
    if not self:MatchesWhisper(message) then return end

    local allowed, unit = self:IsRequesterAllowed(nil, sender)
    if not allowed then
        NS:Debug("Whisper matched phrase but requester was not allowed: " .. tostring(sender))
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

function Detector:RegisterAuraSounds(state)
    if not state or not NS.db.alerts.sound then return end
    if not NS.Media or not NS.Media.RegisterAuraSound then return end
    if IsInCombatLockdown() then
        self.pendingAuraRefresh = true
        return
    end

    local soundKey = NS.db.alerts.soundKey
    if state.auraSoundKey ~= soundKey then
        self:UnregisterAuraSounds(state)
        state.auraSoundKey = soundKey
    end
    if state.auraSoundsRegistered then return end

    state.auraSoundIDs = state.auraSoundIDs or {}
    state.auraSoundSpells = state.auraSoundSpells or {}

    local expected, registered = 0, 0
    for spellID in pairs(state.auraMap or {}) do
        expected = expected + 1

        -- Keep successful registrations and retry only the ones Blizzard did
        -- not accept. Previously one successful spell made the whole unit look
        -- registered, permanently hiding failures for its other tracked buffs.
        if state.auraSoundSpells[spellID] then
            registered = registered + 1
        else
            local auraSoundID = NS.Media:RegisterAuraSound(state.unit, spellID, soundKey)
            if auraSoundID then
                state.auraSoundIDs[#state.auraSoundIDs + 1] = auraSoundID
                state.auraSoundSpells[spellID] = true
                registered = registered + 1
            end
        end
    end

    state.auraSoundsRegistered = expected > 0 and registered == expected
    if not state.auraSoundsRegistered then
        NS:Debug(string.format(
            "Allied aura sounds only partially registered for %s (%s): %d/%d. Will retry.",
            tostring(UnitName(state.unit) or state.unit), tostring(state.unit), registered, expected
        ))
    end
end

function Detector:UnregisterAuraSounds(state)
    if not state then return end
    if IsInCombatLockdown() then
        state.pendingSoundUnregister = true
        self.pendingAuraRefresh = true
        return false
    end
    if NS.Media and NS.Media.UnregisterAuraSound then
        for _, auraSoundID in ipairs(state.auraSoundIDs or {}) do
            NS.Media:UnregisterAuraSound(auraSoundID)
        end
    end
    state.auraSoundIDs = {}
    state.auraSoundSpells = {}
    state.auraSoundsRegistered = false
    state.auraSoundKey = nil
    state.pendingSoundUnregister = false
    return true
end

function Detector:SetAuraStateEnabled(state, enabled)
    if not state then return end
    enabled = enabled and true or false
    if state.enabled == enabled then
        if enabled then
            if NS.db.alerts.sound and not state.auraSoundsRegistered then
                self:RegisterAuraSounds(state)
            elseif not NS.db.alerts.sound and state.auraSoundsRegistered then
                self:UnregisterAuraSounds(state)
            end
        elseif state.pendingSoundUnregister or #(state.auraSoundIDs or {}) > 0 then
            self:UnregisterAuraSounds(state)
        end
        return
    end

    state.enabled = enabled
    if enabled then
        if state.container then
            pcall(state.container.Show, state.container)
            if state.container.SetEnabled then pcall(state.container.SetEnabled, state.container, true) end
            if state.container.UpdateAllAuras then pcall(state.container.UpdateAllAuras, state.container) end
        end
        self:RegisterAuraSounds(state)
    else
        self:UnregisterAuraSounds(state)
        if state.container then
            if state.container.SetEnabled then pcall(state.container.SetEnabled, state.container, false) end
            pcall(state.container.Hide, state.container)
        end
    end
end

function Detector:ApplySecureVisualSettings(state)
    if not state or IsInCombatLockdown() then return false end
    local alerts = NS.db.alerts or {}

    if state.glowButton then
        state.glowButton:SetAlpha(alerts.glow and 1 or 0)
        UpdateStaticBorder(
            state.glowBorder,
            self:GetSecureGlowColor(state.unit),
            alerts.glowPixelThickness
        )
    end
    if state.frameIconButton then
        state.frameIconButton:SetAlpha(alerts.frameIcon and 1 or 0)
    end
    if state.auraIconButton then
        state.auraIconButton:SetAlpha(alerts.auraIcon and 1 or 0)
        local size = (NS.db.auraIcon and NS.db.auraIcon.size) or 52
        state.auraIconButton:SetSize(size, size)
    end

    if state.enabled then
        if alerts.sound then self:RegisterAuraSounds(state) else self:UnregisterAuraSounds(state) end
    end
    return true
end

function Detector:CreateSecureAuraState(unit, classToken, target, auraMap)
    if IsInCombatLockdown() then
        self.pendingAuraRefresh = true
        return nil
    end
    if not self:EnsureAuraEngine() then return nil end
    if not target then return nil end

    local signature = self:AuraMapSignature(auraMap)
    local cacheKey = tostring(unit) .. "|" .. tostring(classToken) .. "|" .. signature
    local cache = self.auraStateCache[target]
    local cached = cache and cache[cacheKey]
    if cached then
        cached.guid = UnitGUID(unit)
        cached.auraMap = auraMap
        self:ApplySecureVisualSettings(cached)
        self:SetAuraStateEnabled(cached, true)
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
        cacheKey = cacheKey,
        container = container,
        enabled = true,
    }

    -- All three slots are created once. Visual settings can then be changed in
    -- place without continually orphaning restricted AuraContainer frames.
    state.glowButton = self:AddSecureAuraSlot(container, "pip_secure_glow", auraMap, function(button)
        button:EnableMouse(false)
        button:SetAllPoints(target)
        button:SetFrameStrata("HIGH")
        button:SetFrameLevel((target:GetFrameLevel() or 1) + 15)
        state.glowBorder = CreateStaticBorder(button)
    end)

    state.frameIconButton = self:AddSecureAuraSlot(container, "pip_secure_frame_icon", auraMap, function(button)
        button:EnableMouse(false)
        button:SetPoint("CENTER", target, "CENTER", 0, 0)
        button:SetFrameStrata("HIGH")
        button:SetFrameLevel(1001)
        AddPIIcon(button, 22)
    end)

    if NS.FrameAlerts and NS.FrameAlerts.auraIcon then
        local auraAnchor = NS.FrameAlerts.auraIcon
        state.auraIconButton = self:AddSecureAuraSlot(container, "pip_secure_aura_icon", auraMap, function(button)
            button:EnableMouse(false)
            button:SetPoint("CENTER", auraAnchor, "CENTER", 0, 0)
            button:SetFrameStrata("HIGH")
            button:SetFrameLevel(1002)
            AddPIIcon(button, (NS.db.auraIcon and NS.db.auraIcon.size) or 52)
        end)
    end

    -- Enabled LAST so Blizzard wires aura events after the slot topology exists.
    container:SetEnabled(true)
    container:UpdateAllAuras()
    container:Show()
    self:ApplySecureVisualSettings(state)

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

    self:UnregisterAuraSounds(state)
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
    if not unit or unit == "player" or not UnitExists(unit) then return end
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
    if signature == "" then
        if state then self:RetireAuraState(state); self.auraStates[unit] = nil end
        return
    end

    local guid = UnitGUID(unit)
    if state and (state.guid ~= guid or state.classToken ~= classToken or state.signature ~= signature) then
        self:RetireAuraState(state)
        self.auraStates[unit] = nil
        state = nil
    end

    local target = self:ResolveRaidFrameForUnit(unit)
    if not target then
        -- Never leave a previously valid token glowing on a frame we can no
        -- longer confirm. A resolver callback will enable it again later.
        if state then self:SetAuraStateEnabled(state, false) end
        NS:Debug("Secure ally tracker is waiting for a raid/party frame for " .. tostring(UnitName(unit) or unit))
        return
    end

    local needsRebuild = not state or state.target ~= target

    if not needsRebuild then
        self:ApplySecureVisualSettings(state)
        if self:IsPIReady() then self:SetAuraStateEnabled(state, true) end
        return
    end

    if state then self:RetireAuraState(state) end
    self.auraStates[unit] = self:CreateSecureAuraState(unit, classToken, target, auraMap)
end

function Detector:RefreshAuraDetectors()
    if not NS.db or not NS:IsActive() then return end

    if IsInCombatLockdown() then
        self.pendingAuraRefresh = true
        self.lastPIReady = self:IsPIReady()
        if not self.lastPIReady then
            for _, state in pairs(self.auraStates or {}) do
                self:SetAuraStateEnabled(state, false)
            end
        end
        return
    end
    self.pendingAuraRefresh = false

    if not self:AllowsSource("SPELL") then
        self:ClearAuraStates()
        return
    end

    self.lastPIReady = self:IsPIReady()
    if not self.lastPIReady then
        for _, state in pairs(self.auraStates or {}) do
            self:SetAuraStateEnabled(state, false)
        end
        return
    end

    local present = {}
    NS:ForEachGroupUnit(function(unit)
        if not UnitIsUnit(unit, "player") then
            present[unit] = true
            self:RefreshAuraState(unit)
        end
    end, false)

    for unit, state in pairs(self.auraStates or {}) do
        if not present[unit] then
            self:RetireAuraState(state)
            self.auraStates[unit] = nil
        end
    end

end

function Detector:SuppressSecureVisuals()
    self.lastPIReady = false
    for _, state in pairs(self.auraStates or {}) do
        self:SetAuraStateEnabled(state, false)
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
        "Spell trackers: %d enabled spell(s), %d active secure tracker(s), PI ready=%s, combat=%s.",
        enabledSpells, activeTrackers, tostring(self:IsPIReady()), tostring(IsInCombatLockdown())
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

    -- The player's own spell ID remains public. We use it to clear everything
    -- immediately after PI and to keep convenient self-tests such as Fade.
    if not NS:IsSecretValue(unit) and unit == "player" and not NS:IsSecretValue(spellID) then
        local publicSpellID = tonumber(spellID)
        if publicSpellID == NS.PI_SPELL_ID then
            self.piCooldownLatched = true
            NS.RequestManager:ClearAll("Power Infusion cast")
            self:SuppressSecureVisuals()
            return
        end

        if self:AllowsSource("SPELL") and self:IsSpellTracked(publicSpellID) then
            local allowed, groupUnit = self:IsRequesterAllowed("player", UnitName("player"))
            if allowed and groupUnit then
                local spellName = NS:GetSpellName(publicSpellID)
                NS:Debug(string.format("Tracked self cast: %s (%d)", tostring(spellName), publicSpellID or 0))
                NS.RequestManager:Receive(UnitGUID(groupUnit), UnitName(groupUnit), groupUnit, "SPELL", publicSpellID, nil)
            end
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
