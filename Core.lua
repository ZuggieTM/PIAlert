local ADDON_NAME, NS = ...

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do
        out[DeepCopy(k)] = DeepCopy(v)
    end
    return out
end
NS.DeepCopy = DeepCopy

local function MergeDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            -- Non-empty arrays are user-owned values, not configuration maps.
            -- In particular, an intentionally empty phrase list must remain
            -- empty instead of having the default phrase merged back into it.
            if #v > 0 then
                if type(target[k]) ~= "table" then target[k] = DeepCopy(v) end
            else
                if type(target[k]) ~= "table" then target[k] = {} end
                MergeDefaults(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end
NS.MergeDefaults = MergeDefaults

function NS:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff35e6b2PI Alert:|r " .. tostring(message))
end

function NS:Debug(message)
    if self.db and self.db.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff71d9ffPI Alert DEBUG:|r " .. tostring(message))
    end
end

function NS:IsSecretValue(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret == true
    end
    return false
end

function NS:NormalizeName(name)
    if type(name) ~= "string" then return nil end
    name = strtrim(name)
    if name == "" then return nil end
    local base = name:match("^([^%-]+)") or name
    return base:lower()
end

function NS:DisplayBaseName(name)
    if type(name) ~= "string" then return "Unknown" end
    return name:match("^([^%-]+)") or name
end

function NS:GetSpecificRequesterIndex(name)
    if not self.db or not self.db.requesters then return nil end
    local normalized = self:NormalizeName(name)
    if not normalized then return nil end

    for index, existing in ipairs(self.db.requesters.players or {}) do
        if self:NormalizeName(existing) == normalized then
            return index
        end
    end
    return nil
end

function NS:IsSpecificRequester(name)
    return self:GetSpecificRequesterIndex(name) ~= nil
end

function NS:NotifyRequesterListChanged()
    if self.Detector then self.Detector:OnSettingsChanged() end
    if self.UI and self.UI.RefreshPlayerRows then self.UI:RefreshPlayerRows() end
end

function NS:AddSpecificRequester(name)
    if not self.db or not self.db.requesters then return false end
    local base = self:DisplayBaseName(name)
    local normalized = self:NormalizeName(base)
    if not normalized or self:IsSpecificRequester(base) then return false end

    local players = self.db.requesters.players
    players[#players + 1] = base
    table.sort(players, function(a, b) return a:lower() < b:lower() end)
    self:NotifyRequesterListChanged()
    return true
end

function NS:RemoveSpecificRequester(name)
    if not self.db or not self.db.requesters then return false end
    local index = self:GetSpecificRequesterIndex(name)
    if not index then return false end

    table.remove(self.db.requesters.players, index)
    self:NotifyRequesterListChanged()
    return true
end

function NS:IsPriest()
    local _, classToken = UnitClass("player")
    return classToken == "PRIEST"
end

function NS:HasPowerInfusion()
    if not self:IsPriest() then return false end
    if not C_SpellBook or type(C_SpellBook.FindSpellBookSlotForSpell) ~= "function" then
        return false
    end

    -- Look only in the player's learned, active-spec spellbook. Hidden entries
    -- are included so this remains robust if Blizzard hides/replaces the visible
    -- spellbook entry, while future and off-spec spells are explicitly excluded.
    local ok, slot = pcall(
        C_SpellBook.FindSpellBookSlotForSpell,
        self.PI_SPELL_ID,
        true,  -- includeHidden
        true,  -- includeFlyouts
        false, -- includeFutureSpells
        false  -- includeOffSpec
    )
    return ok and slot ~= nil
end

function NS:IsActive()
    return self.active == true
end

function NS:GetUnitFullName(unit)
    if not unit or not UnitExists(unit) then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function NS:IsGroupUnit(unit)
    if not unit or not UnitExists(unit) then return false end
    if unit == "player" then return true end
    if unit:match("^party%d+$") or unit:match("^raid%d+$") then return true end
    return false
end

function NS:ForEachGroupUnit(callback, includePlayer)
    if IsInRaid() then
        local count = GetNumGroupMembers()
        for i = 1, count do
            local unit = "raid" .. i
            if UnitExists(unit) and (includePlayer or not UnitIsUnit(unit, "player")) then
                callback(unit)
            end
        end
    elseif IsInGroup() then
        if includePlayer then callback("player") end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then callback(unit) end
        end
    elseif includePlayer then
        callback("player")
    end
end

function NS:FindGroupUnitByGUID(guid)
    if self:IsSecretValue(guid) or not guid then return nil end
    local found
    self:ForEachGroupUnit(function(unit)
        if found then return end
        local unitGUID = UnitGUID(unit)
        if not self:IsSecretValue(unitGUID) and unitGUID and unitGUID == guid then
            found = unit
        end
    end, true)
    return found
end

function NS:FindGroupUnitByName(name)
    local normalized = self:NormalizeName(name)
    if not normalized then return nil end

    local nativeName = name
    if type(Ambiguate) == "function" then
        local ok, value = pcall(Ambiguate, name, "none")
        if ok and type(value) == "string" and value ~= "" then nativeName = value end
    end

    local found
    self:ForEachGroupUnit(function(unit)
        if found then return end

        -- Let Blizzard compare the sender's native full-name form first. This
        -- handles connected-realm and cross-realm names without parsing them.
        local ok, sameUnit = pcall(UnitIsUnit, unit, nativeName)
        if ok and not self:IsSecretValue(sameUnit) and sameUnit == true then
            found = unit
            return
        end

        local unitName = UnitName(unit)
        if not self:IsSecretValue(unitName) and unitName
            and self:NormalizeName(unitName) == normalized
        then
            found = unit
        end
    end, true)
    return found
end

function NS:GetSpellName(spellID, fallback)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name and name ~= "" then return name end
    end
    return fallback or ("Spell " .. tostring(spellID))
end

function NS:GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local icon = C_Spell.GetSpellTexture(spellID)
        if icon then return icon end
    end
    return 136048
end

function NS:ResetDatabase()
    PIPriorityV2DB = DeepCopy(self.DEFAULTS)
    self.db = PIPriorityV2DB
    if self.RequestManager then self.RequestManager:ClearAll("reset") end
    if self.Detector then self.Detector:OnSettingsChanged() end
    if self.FrameAlerts then self.FrameAlerts:OnSettingsChanged(true) end
    if self.UI then
        if self.UI.ApplyPosition then self.UI:ApplyPosition() end
        self.UI:Refresh()
    end
    self:Print("Settings reset to defaults.")
end

function NS:InitializeDatabase()
    if type(PIPriorityV2DB) ~= "table" or PIPriorityV2DB.schema ~= self.DB_SCHEMA then
        PIPriorityV2DB = DeepCopy(self.DEFAULTS)
    else
        MergeDefaults(PIPriorityV2DB, self.DEFAULTS)

        -- 1.0.5: update the original glow defaults without resetting the rest
        -- of an existing configuration. Values are migrated only when they
        -- still match the old shipped defaults.
        local revision = tonumber(PIPriorityV2DB.settingsRevision) or 1
        if revision < 2 then
            local alerts = PIPriorityV2DB.alerts or {}
            if tonumber(alerts.glowPixelLines) == 8 then
                alerts.glowPixelLines = 12
            end
            local c = alerts.glowColor
            if type(c) == "table"
                and math.abs((tonumber(c[1]) or 0) - 0.72) < 0.001
                and math.abs((tonumber(c[2]) or 0) - 0.38) < 0.001
                and math.abs((tonumber(c[3]) or 0) - 1.00) < 0.001 then
                alerts.glowColor = { 1.00, 0.82, 0.20, tonumber(c[4]) or 1.00 }
            end
            PIPriorityV2DB.settingsRevision = 2
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 3 then
            PIPriorityV2DB.settingsRevision = 3
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 4 then
            PIPriorityV2DB.settingsRevision = 4
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 5 then
            -- 1.0.22: Grace Period was removed because numeric spell cooldown
            -- values can become secret during combat in Midnight.
            if PIPriorityV2DB.requests then
                PIPriorityV2DB.requests.gracePeriod = nil
            end
            PIPriorityV2DB.settingsRevision = 5
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 6 then
            if PIPriorityV2DB.alerts then
                PIPriorityV2DB.alerts.glowAutoCastParticles = nil
            end
            PIPriorityV2DB.settingsRevision = 6
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 7 then
            -- 1.0.29: Existing users start in the recommended mode. Secure spell
            -- visuals stay active while PI is unavailable, but sounds do not.
            PIPriorityV2DB.alerts = PIPriorityV2DB.alerts or {}
            PIPriorityV2DB.alerts.spellAlertTiming = "ALWAYS_TRACK"
            PIPriorityV2DB.settingsRevision = 7
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 8 then
            -- 1.0.30: PI Ready Only is the safer default. Casting PI now hides
            -- secure allied-buff visuals instead of tracking them through PI's CD.
            PIPriorityV2DB.alerts = PIPriorityV2DB.alerts or {}
            PIPriorityV2DB.alerts.spellAlertTiming = "PI_READY"
            PIPriorityV2DB.settingsRevision = 8
        end
        if (tonumber(PIPriorityV2DB.settingsRevision) or 1) < 9 then
            -- Alert cards gained explicit raidframe icon and whisper cooldown
            -- behavior. MergeDefaults supplies the compatibility-preserving
            -- values for existing users.
            PIPriorityV2DB.settingsRevision = 9
        end
    end
    self.db = PIPriorityV2DB
end

function NS:InitializeModules()
    if self.modulesInitialized then return end
    self.modulesInitialized = true
    if self.Media and self.Media.Init then self.Media:Init() end
    if self.UnitMenu and self.UnitMenu.Init then self.UnitMenu:Init() end
    if self.RequestManager and self.RequestManager.Init then self.RequestManager:Init() end
    if self.Detector and self.Detector.Init then self.Detector:Init() end
    if self.FrameAlerts and self.FrameAlerts.Init then self.FrameAlerts:Init() end
    if self.UI and self.UI.Init then self.UI:Init() end
end

function NS:RegisterSlashCommands()
    if self.slashRegistered then return end
    self.slashRegistered = true

    SLASH_PIALERT1 = "/pia"
    SLASH_PIALERT2 = "/pialert"
    SLASH_PIALERT3 = "/pip" -- Legacy alias from PI Priority.
    SlashCmdList.PIALERT = function(input)
        input = strtrim(input or "")
        local command, rest = input:match("^(%S+)%s*(.-)$")
        command = command and command:lower() or ""

        if command == "" or command == "config" or command == "options" then
            NS:InitializeModules()
            if NS.UI then NS.UI:Toggle() end
        elseif command == "reset" then
            NS:ResetDatabase()
        elseif command == "debug" then
            NS.db.debug = not NS.db.debug
            NS:Print("Debug logging " .. (NS.db.debug and "enabled" or "disabled") .. ".")
        elseif command == "frames" then
            if not NS:IsActive() then NS:Print("Power Infusion must be talented to inspect active alert frames."); return end
            if NS.FrameAlerts then NS.FrameAlerts:PrintFrameCache() end
        elseif command == "status" then
            if not NS:IsActive() then NS:Print("Power Infusion must be talented to inspect spell trackers."); return end
            if NS.Detector then NS.Detector:PrintTrackerStatus() end
        elseif command == "test" then
            if not NS:IsActive() then NS:Print("Power Infusion must be talented to test an alert."); return end
            if NS.RequestManager then NS.RequestManager:TestRequest() end
        elseif command == "clear" then
            if not NS:IsActive() then NS:Print("Power Infusion must be talented to clear active alerts."); return end
            if NS.RequestManager then NS.RequestManager:ClearAll("slash") end
        else
            NS:Print("Commands: /pia, /pia test, /pia status, /pia debug, /pia frames, /pia clear, /pia reset")
        end
    end
end

function NS:Deactivate()
    if not self.active then return end
    self.active = false

    if self.UI and self.UI.frame then self.UI.frame:Hide() end
    if self.RequestManager and self.RequestManager.ClearAll then
        self.RequestManager:ClearAll("Power Infusion not talented")
    end
    if self.Detector and self.Detector.ClearAuraStates then
        self.Detector:ClearAuraStates()
    end
    if self.FrameAlerts and self.FrameAlerts.ClearAll then
        self.FrameAlerts:ClearAll()
    end
end

function NS:Activate()
    if self.active then return end
    self:InitializeModules()
    self.active = true
    self:RegisterSlashCommands()

    if self.FrameAlerts then self.FrameAlerts:ScheduleFrameScan(0.15) end
    if self.RequestManager then self.RequestManager:ReconcileRoster() end
    if self.Detector then self.Detector:ScheduleAuraRefresh(0.10) end
end

function NS:RefreshEligibility()
    if not self:IsPriest() then
        self:Deactivate()
        return false
    end

    if self:HasPowerInfusion() then
        self:Activate()
        return true
    end

    self:Deactivate()
    return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        -- Non-Priests go completely dormant after the addon's files are loaded:
        -- no database, modules, slash commands, frame resolver, or request events.
        if not NS:IsPriest() then
            NS.active = false
            eventFrame:UnregisterAllEvents()
            return
        end

        NS:InitializeDatabase()
        NS:RegisterSlashCommands()
        return
    end

    if not NS.db then return end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
        or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        local active = NS:RefreshEligibility()

        -- Spellbook/talent state can settle shortly after login or a loadout swap.
        -- A cheap delayed re-check makes activation reliable without polling.
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
            or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            C_Timer.After(0.35, function()
                if NS.db then NS:RefreshEligibility() end
            end)
        end

        if not active then return end

        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            if NS.FrameAlerts then NS.FrameAlerts:ScheduleFrameScan(0.5) end
            if NS.RequestManager then NS.RequestManager:ReconcileRoster() end
            if NS.Detector then C_Timer.After(0.35, function() if NS:IsActive() then NS.Detector:RefreshAuraDetectors() end end) end
        elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            if NS.Detector then NS.Detector:ScheduleAuraRefresh(0.10) end
        end
        return
    end

    if not NS:IsActive() then return end

    if event == "GROUP_ROSTER_UPDATE" then
        if NS.FrameAlerts then NS.FrameAlerts:ScheduleFrameScan(0.35) end
        if NS.RequestManager then NS.RequestManager:ReconcileRoster() end
        if NS.Detector then C_Timer.After(0.15, function() if NS:IsActive() then NS.Detector:RefreshAuraDetectors() end end) end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if NS.Detector then NS.Detector:RefreshRequesterState() end
    end
end)
