local ADDON_NAME, ns = ...

local ROW_H = 25
local LABEL_WIDTH = 440

local function ClassName(class)
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] then
        return LOCALIZED_CLASS_NAMES_MALE[class]
    end
    return class
end

local function MakeCheck(parent, x, y, label, getter, setter, indent)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (indent or 0), y)
    cb:SetSize(24, 24)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetWidth(LABEL_WIDTH - (indent or 0))
    cb.text:SetJustifyH("LEFT")
    cb.text:SetText(label)
    cb.getter = getter
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() == true)
        ns:OnConfigurationChanged()
    end)
    parent.controls[#parent.controls + 1] = cb
    return cb
end

local function MakeEdit(parent, x, y, label, getter, setter, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)
    text:SetText(label)

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetSize(width or 360, 24)
    edit:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 4, -5)
    edit:SetText(getter() or "")
    edit.getter = getter
    edit.setter = setter
    edit:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        self:ClearFocus()
        ns:OnConfigurationChanged()
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        if self:GetText() ~= tostring(getter() or "") then
            setter(self:GetText())
            ns:OnConfigurationChanged()
        end
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:SetText(getter() or "")
        self:ClearFocus()
    end)
    parent.controls[#parent.controls + 1] = edit
    return edit, 52
end

local function MakeHeader(parent, y, text, large)
    local fs = parent:CreateFontString(nil, "OVERLAY", large and "GameFontNormalLarge" or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
    fs:SetText(text)
    return fs
end

local function ClassGetter(class)
    return function() return ns.db.classes[class] == true end
end

local function ClassSetter(class)
    return function(v) ns.db.classes[class] = v end
end

local function SpellGetter(class, spellID)
    return function() return ns.db.spells[class][spellID] == true end
end

local function SpellSetter(class, spellID)
    return function(v) ns.db.spells[class][spellID] = v end
end

local function CustomGetter(class)
    return function() return ns.db.customSpells[class] or "" end
end

local function CustomSetter(class)
    return function(v) ns.db.customSpells[class] = v end
end

function ns:UpdateOptionsStatus()
    if not self.optionsFrame or not self.optionsFrame.status then return end
    self.optionsFrame.status:SetText(
        "Current fallback: |cffffffff" .. tostring(self.fallbackMode) .. "|r   " ..
        "Power Infusion: " .. (self.piReady and "|cff33ff66READY|r" or "|cffff6666cooldown|r")
    )
end

function ns:RefreshOptions()
    local frame = self.optionsFrame
    if not frame then return end
    for _, control in ipairs(frame.content.controls or {}) do
        if control.getter and control.SetChecked then
            control:SetChecked(control.getter())
        elseif control.getter and control.SetText then
            control:SetText(control.getter() or "")
        end
    end
    self:UpdateOptionsStatus()
end

function ns:CreateOptions()
    if self.optionsFrame then return self.optionsFrame end

    local frame = CreateFrame("Frame", "PIPriorityOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 720)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 28,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetText("PI Priority")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Names  >  preferred classes  >  any tracked class")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.status:SetPoint("TOPRIGHT", -45, -26)
    frame.status:SetJustifyH("RIGHT")

    local test = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    test:SetSize(90, 24)
    test:SetPoint("BOTTOMLEFT", 20, 18)
    test:SetText("Test alert")
    test:SetScript("OnClick", function() ns:ShowTestAlert() end)

    local rescan = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    rescan:SetSize(90, 24)
    rescan:SetPoint("LEFT", test, "RIGHT", 8, 0)
    rescan:SetText("Rescan")
    rescan:SetScript("OnClick", function() ns:RefreshAll("options-rescan"); ns:UpdateOptionsStatus() end)

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(90, 24)
    reset:SetPoint("BOTTOMRIGHT", -20, 18)
    reset:SetText("Reset")
    reset:SetScript("OnClick", function()
        ns:ResetDatabase()
        ns:OnConfigurationChanged()
        ns:RefreshOptions()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -72)
    scroll:SetPoint("BOTTOMRIGHT", -38, 52)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(645)
    content:SetHeight(2200)
    content.controls = {}
    scroll:SetScrollChild(content)
    frame.content = content

    local y = -8
    MakeHeader(content, y, "Alerts", true); y = y - 32
    MakeCheck(content, 10, y, "Enable PI Priority", function() return ns.db.enabled end,
        function(v) ns.db.enabled = v end); y = y - ROW_H
    MakeCheck(content, 10, y, "Center-screen Power Infusion icon", function() return ns.db.centerIcon end,
        function(v) ns.db.centerIcon = v end); y = y - ROW_H
    MakeCheck(content, 10, y, "Sound", function() return ns.db.sound end,
        function(v) ns.db.sound = v end); y = y - ROW_H
    MakeCheck(content, 10, y, "Glow matching raid/party frame", function() return ns.db.raidGlow end,
        function(v) ns.db.raidGlow = v end); y = y - ROW_H
    MakeCheck(content, 10, y, "Show Power Infusion icon on matching raid/party frame", function() return ns.db.raidIcon end,
        function(v) ns.db.raidIcon = v end); y = y - ROW_H
    MakeCheck(content, 10, y, "Allow yourself as a PI target", function() return ns.db.includeSelf end,
        function(v) ns.db.includeSelf = v end); y = y - 34

    local readyNote = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    readyNote:SetPoint("TOPLEFT", 18, y)
    readyNote:SetWidth(600)
    readyNote:SetJustifyH("LEFT")
    readyNote:SetText("Alerts are always gated by Power Infusion's own cooldown. The global cooldown is ignored.")
    y = y - 36

    MakeHeader(content, y, "Target priority", true); y = y - 32
    local _, used = MakeEdit(content, 14, y, "Preferred player names (comma separated)",
        function() return ns.db.names end,
        function(v) ns.db.names = v end, 510)
    y = y - used - 4
    MakeCheck(content, 10, y, "If none of those names are in the group, fall back to preferred classes",
        function() return ns.db.classFallback end,
        function(v) ns.db.classFallback = v end); y = y - ROW_H
    MakeCheck(content, 10, y, "If none of the preferred classes are in the group, fall back to anyone",
        function() return ns.db.anyFallback end,
        function(v) ns.db.anyFallback = v end); y = y - 40

    local logic = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    logic:SetPoint("TOPLEFT", 18, y)
    logic:SetWidth(600)
    logic:SetJustifyH("LEFT")
    logic:SetText("Fallback is decided from the group roster, not from who has used a cooldown. Spell filters still apply at every level.")
    y = y - 44

    MakeHeader(content, y, "Classes and cooldowns", true); y = y - 34

    for _, class in ipairs(ns.CLASS_ORDER) do
        local classLabel = ClassName(class)
        MakeCheck(content, 10, y, classLabel .. "  |cffffd100(preferred class)|r",
            ClassGetter(class), ClassSetter(class))
        y = y - ROW_H

        for _, spell in ipairs(ns.SPELLS[class] or {}) do
            local id = spell.id
            local name = ns:GetSpellName(id)
            MakeCheck(content, 10, y, name .. "  |cff888888(" .. id .. ")|r",
                SpellGetter(class, id), SpellSetter(class, id), 24)
            y = y - ROW_H
        end

        local _, editUsed = MakeEdit(content, 38, y, "Custom aura spell IDs for " .. classLabel .. " (comma separated)",
            CustomGetter(class), CustomSetter(class), 430)
        y = y - editUsed - 14
    end

    content:SetHeight(math.max(620, -y + 20))
    frame:SetScript("OnShow", function() ns:RefreshOptions() end)
    frame:Hide()

    self.optionsFrame = frame
    self:UpdateOptionsStatus()
    return frame
end

function ns:ToggleOptions()
    local frame = self:CreateOptions()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
