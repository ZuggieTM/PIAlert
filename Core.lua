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

-- Shared by the glow, swipe and icon code, which all clamp user-entered sizes
-- and speeds into a safe range.
local function Clamp(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback or minValue
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    return value
end
NS.Clamp = Clamp

function NS:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff35e6b2PI Alert:|r " .. tostring(message))
end

function NS:Debug(message)
    if self.db and self.db.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff71d9ffPI Alert DEBUG:|r " .. tostring(message))
    end
end

local PI_MACRO_NAME = "PI Alert"
local PI_MACRO_ICON = 134400 -- INV_Misc_QuestionMark; #showtooltip supplies the live spell icon.
local MAX_MACRO_BODY_LENGTH = 255
local MAX_MACRO_TARGET_LENGTH = 80
local MAX_MACRO_EXTRA_TEXT_LENGTH = 80
NS.PI_MACRO_EXTRA_TEXT_LIMIT = MAX_MACRO_EXTRA_TEXT_LENGTH

function NS:NormalizeMacroTarget(target)
    if type(target) ~= "string" then return nil end
    target = strtrim(target)
    if target == "" or #target > MAX_MACRO_TARGET_LENGTH or target:find("[%[%],/%s]") then return nil end
    return target
end

function NS:GetUnitMacroTarget(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local name, realm
    if type(UnitFullName) == "function" then
        name, realm = UnitFullName(unit)
    else
        name, realm = UnitName(unit)
    end
    if not name or name == "" then return nil end
    if realm and realm ~= "" then name = name .. "-" .. realm end
    return self:NormalizeMacroTarget(name)
end

function NS:GetPIMacroTarget()
    return self:NormalizeMacroTarget(self.db and self.db.macro and self.db.macro.target)
end

function NS:GetPIMacroMode()
    local mode = self.db and self.db.macro and self.db.macro.mode
    if mode == "PLAYER" or mode == "FOCUS" then return mode end
    return "MOUSEOVER"
end

function NS:NormalizePIMacroExtraText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("\r\n?", "\n")
    return text:match("^%s*(.-)%s*$") or ""
end

function NS:GetPIMacroExtraText()
    return self:NormalizePIMacroExtraText(self.db and self.db.macro and self.db.macro.extraText)
end

function NS:SetPIMacroExtraText(text)
    if not self.db then return end
    self.db.macro = self.db.macro or {}
    self.db.macro.extraText = self:NormalizePIMacroExtraText(text)
end

function NS:BuildPIMacroBody()
    local mode = self:GetPIMacroMode()
    local target = mode == "PLAYER" and self:GetPIMacroTarget() or nil
    local targetClause = ""
    if target then
        targetClause = "[@" .. target .. ",help,exists,nodead]"
    elseif mode == "FOCUS" then
        targetClause = "[@focus,help,exists,nodead]"
    end
    local body = "#showtooltip Power Infusion\n/cast " .. targetClause
        .. "[@mouseover,help,exists,nodead] Power Infusion"
    local extraText = self:GetPIMacroExtraText()
    if extraText ~= "" then body = body .. "\n" .. extraText end
    return body
end

function NS:FindGeneralPIMacro()
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then return nil end
    local generalCount = tonumber((GetNumMacros())) or 0
    for index = 1, generalCount do
        local name = GetMacroInfo(index)
        if name == PI_MACRO_NAME then return index end
    end
    return nil
end

function NS:CreateOrUpdatePIMacro()
    if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" then
        self:Print("The macro API is currently unavailable.")
        return false
    end

    local macroBody = self:BuildPIMacroBody()
    if #macroBody > MAX_MACRO_BODY_LENGTH then
        self:Print("The PI Alert macro is " .. #macroBody .. "/" .. MAX_MACRO_BODY_LENGTH
            .. " characters. Shorten the additional macro text and try again.")
        return false
    end

    -- CreateMacro and EditMacro are #nocombat. The saved settings are already
    -- current, so record that the macro body still needs writing and replay it
    -- once combat ends rather than discarding the request.
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        if self.db then
            self.db.macro = self.db.macro or {}
            self.db.macro.pendingUpdate = true
        end
        self:Print("Combat blocks macro edits. PI Alert will update the macro when you leave combat.")
        return false
    end

    -- Past the combat gate this attempt settles the request either way, so the
    -- flag is cleared here instead of only on success.
    if self.db and self.db.macro then self.db.macro.pendingUpdate = false end

    local existingIndex = self:FindGeneralPIMacro()
    local ok, macroIndex
    if existingIndex then
        ok, macroIndex = pcall(EditMacro, existingIndex, PI_MACRO_NAME, PI_MACRO_ICON, macroBody)
    else
        ok, macroIndex = pcall(CreateMacro, PI_MACRO_NAME, PI_MACRO_ICON, macroBody, false)
    end

    if not ok or not macroIndex then
        self:Print("Could not create the PI Alert macro. Check that General Macros has a free slot.")
        return false
    end

    self:Print((existingIndex and "Updated" or "Created") .. " the PI Alert macro under General Macros.")
    return true
end

function NS:SetPIMacroMode(mode, target)
    if not self.db then return false end
    if mode ~= "PLAYER" and mode ~= "FOCUS" and mode ~= "MOUSEOVER" then return false end

    local normalized = mode == "PLAYER" and self:NormalizeMacroTarget(target) or nil
    if mode == "PLAYER" and not normalized then
        self:Print("Enter a valid player name, optionally followed by -Realm.")
        return false
    end

    -- Recording the choice is an ordinary table write and is safe in combat;
    -- only the macro API itself is restricted. Saving first means a selection
    -- made mid-fight is never silently thrown away.
    self.db.macro = self.db.macro or {}
    self.db.macro.mode = mode
    self.db.macro.target = normalized or ""

    -- True means the selection was accepted, not that the macro was written. A
    -- combat-queued write still counts, so callers close their dialog.
    local written = self:CreateOrUpdatePIMacro()
    return written or self.db.macro.pendingUpdate == true
end

-- Replays a macro write that combat blocked. The flag lives in the database so
-- that logging out before combat ends cannot leave the saved settings and the
-- macro permanently disagreeing.
function NS:FlushPendingPIMacro()
    if not self.db or not self.db.macro or not self.db.macro.pendingUpdate then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return end
    self:CreateOrUpdatePIMacro()
end

function NS:SetPIMacroTarget(target)
    if target == nil or target == "" then
        return self:SetPIMacroMode("MOUSEOVER")
    end
    return self:SetPIMacroMode("PLAYER", target)
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

function NS:GetCurrentActivationRole()
    if not self:IsPriest() or type(GetSpecialization) ~= "function" then return nil end

    local specIndex = GetSpecialization()
    if not specIndex then return nil end

    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
        or GetSpecializationInfo
    if type(getInfo) ~= "function" then return nil end

    local specID = getInfo(specIndex)
    if specID == 256 or specID == 257 then return "HEALER" end -- Discipline, Holy
    if specID == 258 then return "DPS" end -- Shadow
    return nil
end

function NS:IsCurrentSpecEnabled()
    local role = self:GetCurrentActivationRole()
    return role ~= nil
        and self.db
        and self.db.activation
        and self.db.activation[role] == true
end

function NS:GetContentSetting(group, item)
    if not self.db or not self.db.content then return false end
    if group == "OPEN_WORLD" then return self.db.content.OPEN_WORLD == true end
    return self.db.content[group] and self.db.content[group][item] == true
end

function NS:SetContentSetting(group, item, enabled)
    if not self.db then return end
    self.db.content = self.db.content or {}
    if group == "OPEN_WORLD" then
        self.db.content.OPEN_WORLD = enabled and true or false
        return
    end
    self.db.content[group] = self.db.content[group] or {}
    self.db.content[group][item] = enabled and true or false
end

local function CallBoolean(fn)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
end

function NS:GetCurrentContent()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local _, instanceType, difficultyID = GetInstanceInfo()
    difficultyID = tonumber(difficultyID) or 0

    if instanceType == "none" then
        return "OPEN_WORLD", "OPEN_WORLD"
    elseif instanceType == "party" then
        local challengeActive = C_ChallengeMode and CallBoolean(C_ChallengeMode.IsChallengeModeActive)
        if challengeActive or difficultyID == 8 then return "DUNGEON", "MYTHIC_PLUS" end
        if difficultyID == 23 then return "DUNGEON", "MYTHIC" end
        if difficultyID == 2 then return "DUNGEON", "HEROIC" end
        if difficultyID == 24 then return "DUNGEON", "TIMEWALKING" end
        if difficultyID == 1 or difficultyID == 205 then return "DUNGEON", "NORMAL" end
    elseif instanceType == "raid" then
        if difficultyID == 17 or difficultyID == 7 then return "RAID", "LFR" end
        if difficultyID == 14 or difficultyID == 3 or difficultyID == 4 or difficultyID == 5 or difficultyID == 9 then return "RAID", "NORMAL" end
        if difficultyID == 15 or difficultyID == 6 then return "RAID", "HEROIC" end
        if difficultyID == 16 or difficultyID == 233 then return "RAID", "MYTHIC" end
        if difficultyID == 33 or difficultyID == 151 then return "RAID", "TIMEWALKING" end
    elseif instanceType == "pvp" then
        local ratedBG = C_PvP and CallBoolean(C_PvP.IsRatedBattleground)
        return "PVP", ratedBG and "RATED_BATTLEGROUND" or "BATTLEGROUND"
    elseif instanceType == "arena" then
        if C_PvP and CallBoolean(C_PvP.IsWargame) then return "PVP", "WAR_GAME" end
        if C_PvP and CallBoolean(C_PvP.IsSoloShuffle) then return "PVP", "SOLO_SHUFFLE" end
        if C_PvP and CallBoolean(C_PvP.IsArenaSkirmish) then return "PVP", "ARENA_SKIRMISH" end
        if C_PvP and CallBoolean(C_PvP.IsRatedArena) then return "PVP", "RATED_ARENA" end
    elseif instanceType == "scenario" then
        return "SCENARIO", difficultyID == 208 and "DELVE" or "OTHER"
    end
    return nil
end

function NS:IsCurrentContentEnabled()
    local group, item = self:GetCurrentContent()
    return group ~= nil and self:GetContentSetting(group, item)
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
    PIAlertDB = DeepCopy(self.DEFAULTS)
    self.db = PIAlertDB
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
    if type(PIAlertDB) ~= "table" or PIAlertDB.schema ~= self.DB_SCHEMA then
        PIAlertDB = DeepCopy(self.DEFAULTS)
    else
        MergeDefaults(PIAlertDB, self.DEFAULTS)

        -- 1.0.5: update the original glow defaults without resetting the rest
        -- of an existing configuration. Values are migrated only when they
        -- still match the old shipped defaults.
        local revision = tonumber(PIAlertDB.settingsRevision) or 1
        if revision < 2 then
            local alerts = PIAlertDB.alerts or {}
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
            PIAlertDB.settingsRevision = 2
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 3 then
            PIAlertDB.settingsRevision = 3
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 4 then
            PIAlertDB.settingsRevision = 4
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 6 then
            if PIAlertDB.alerts then
                PIAlertDB.alerts.glowAutoCastParticles = nil
            end
            PIAlertDB.settingsRevision = 6
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 7 then
            -- 1.0.29: Existing users start in the recommended mode. Secure spell
            -- visuals stay active while PI is unavailable, but sounds do not.
            PIAlertDB.alerts = PIAlertDB.alerts or {}
            PIAlertDB.alerts.spellAlertTiming = "ALWAYS_TRACK"
            PIAlertDB.settingsRevision = 7
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 8 then
            -- 1.0.30: PI Ready Only is the safer default. Casting PI now hides
            -- secure allied-buff visuals instead of tracking them through PI's CD.
            PIAlertDB.alerts = PIAlertDB.alerts or {}
            PIAlertDB.alerts.spellAlertTiming = "PI_READY"
            PIAlertDB.settingsRevision = 8
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 11 then
            -- Store the optional account-wide PI macro target. MergeDefaults
            -- supplies an empty target for existing installations.
            PIAlertDB.settingsRevision = 11
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 12 then
            -- Existing named-target macros retain their target. Everything else
            -- starts as the explicit mouseover macro type.
            PIAlertDB.macro = PIAlertDB.macro or {}
            if self:NormalizeMacroTarget(PIAlertDB.macro.target) then
                PIAlertDB.macro.mode = "PLAYER"
            else
                PIAlertDB.macro.mode = "MOUSEOVER"
            end
            PIAlertDB.settingsRevision = 12
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 13 then
            -- The role defaults are supplied by MergeDefaults. Existing users
            -- therefore start with Healer enabled and Shadow disabled, which
            -- matches PI's usual group-coordination use case.
            PIAlertDB.settingsRevision = 13
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 14 then
            -- Dungeons and raids start enabled; all other content remains
            -- opt-in, as supplied by MergeDefaults.
            PIAlertDB.settingsRevision = 14
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 15 then
            -- Whisper requests cannot be processed reliably in Blizzard's chat
            -- lockdown. PI Alert now uses tracked allied cooldowns exclusively.
            PIAlertDB.requests = nil
            if PIAlertDB.alerts then
                PIAlertDB.alerts.sound = nil
                PIAlertDB.alerts.soundKey = nil
                PIAlertDB.alerts.soundCooldown = nil
                PIAlertDB.alerts.whisperOnPICooldown = nil
            end
            PIAlertDB.settingsRevision = 15
        end
        if (tonumber(PIAlertDB.settingsRevision) or 1) < 16 then
            PIAlertDB.macro = PIAlertDB.macro or {}
            if type(PIAlertDB.macro.extraText) ~= "string" then
                PIAlertDB.macro.extraText = ""
            end
            PIAlertDB.settingsRevision = 16
        end
    end
    self.db = PIAlertDB
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

function NS:PrintSlashHelp()
    local headerColor = CreateColor(0.333, 0.875, 1.000, 1)
    local commandColor = CreateColor(0.208, 0.902, 0.698, 1)
    local separatorColor = CreateColor(0.510, 0.580, 0.620, 1)
    local textColor = CreateColor(0.910, 0.941, 0.953, 1)

    local function Colorize(color, value)
        return color:WrapTextInColorCode(value)
    end

    local function AddLine(commandText, description)
        DEFAULT_CHAT_FRAME:AddMessage(Colorize(commandColor, commandText) .. " "
            .. Colorize(separatorColor, "-") .. " " .. Colorize(textColor, description))
    end

    DEFAULT_CHAT_FRAME:AddMessage(Colorize(headerColor, "PI Alert available commands:"))
    AddLine("/pia", "Open or close settings")
    AddLine("/pia mo or /pia mouseover", "Create the mouseover PI macro")
    AddLine("/pia focus", "Create the focus PI macro with mouseover fallback")
    AddLine("/pia test", "Preview your configured alert")
    AddLine("/pia reset", "Reset PI Alert settings")
    AddLine("/pia help", "Show this command list")
end

function NS:RegisterSlashCommands()
    if self.slashRegistered then return end
    self.slashRegistered = true

    SLASH_PIALERT1 = "/pia"
    SlashCmdList.PIALERT = function(input)
        input = strtrim(input or "")
        local command = input:match("^(%S+)")
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
            if not NS:IsActive() then NS:Print("PI Alert is inactive for your current talent, role, or content type."); return end
            if NS.RequestManager then NS.RequestManager:TestRequest() end
        elseif command == "mo" or command == "mouseover" then
            NS:SetPIMacroMode("MOUSEOVER")
        elseif command == "focus" then
            NS:SetPIMacroMode("FOCUS")
        elseif command == "help" or command == "commands" then
            NS:PrintSlashHelp()
        elseif command == "clear" then
            if not NS:IsActive() then NS:Print("Power Infusion must be talented to clear active alerts."); return end
            if NS.RequestManager then NS.RequestManager:ClearAll("slash") end
        else
            NS:Print("Unknown command '" .. command .. "'.")
            NS:PrintSlashHelp()
        end
    end
end

function NS:Deactivate(reason, keepConfigOpen)
    if not self.active then return end
    self.active = false

    if not keepConfigOpen and self.UI and self.UI.frame then self.UI.frame:Hide() end
    if self.RequestManager and self.RequestManager.ClearAll then
        self.RequestManager:ClearAll(reason or "PI Alert inactive")
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

function NS:RefreshEligibility(keepConfigOpen)
    if not self:IsPriest() then
        self:Deactivate("Not a Priest", keepConfigOpen)
        return false
    end

    local hasPowerInfusion = self:HasPowerInfusion()
    if hasPowerInfusion and self:IsCurrentSpecEnabled() and self:IsCurrentContentEnabled() then
        self:Activate()
        return true
    end

    local reason
    if not hasPowerInfusion then
        reason = "Power Infusion not talented"
    elseif not self:IsCurrentSpecEnabled() then
        reason = "PI Alert is disabled for this specialization"
    else
        reason = "PI Alert is disabled for this content type"
    end
    self:Deactivate(reason, keepConfigOpen)
    return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

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

    -- Macro edits are blocked in combat, so replay a queued write the moment
    -- combat ends, and again at login in case the session ended first.
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD" then
        NS:FlushPendingPIMacro()
        if event == "PLAYER_REGEN_ENABLED" then return end
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        local active = NS:RefreshEligibility()

        -- Spellbook/talent state can settle shortly after login or a loadout swap.
        -- A cheap delayed re-check makes activation reliable without polling.
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
            or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            C_Timer.After(0.35, function()
                if NS.db then NS:RefreshEligibility() end
            end)
        end

        if not active then return end

        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
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
