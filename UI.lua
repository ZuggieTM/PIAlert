local ADDON_NAME, NS = ...

local UI = {}
NS.UI = UI

local C = {
    bg = {0.025, 0.037, 0.052, 0.98},
    panel = {0.045, 0.062, 0.082, 0.98},
    panel2 = {0.058, 0.078, 0.100, 0.98},
    border = {0.16, 0.22, 0.27, 0.95},
    borderSoft = {0.12, 0.17, 0.21, 0.80},
    accent = {0.12, 0.90, 0.68, 1},
    accentDim = {0.08, 0.55, 0.43, 1},
    text = {0.92, 0.96, 0.98, 1},
    muted = {0.58, 0.67, 0.72, 1},
    danger = {0.95, 0.35, 0.35, 1},
    warning = {0.95, 0.72, 0.26, 1},
}

local function SetBackdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(bg or C.panel))
    frame:SetBackdropBorderColor(unpack(border or C.border))
end

local function CreateLabel(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 13, "")
    fs:SetText(text or "")
    fs:SetTextColor(unpack(color or C.text))
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    return fs
end

local function CreateButton(parent, text, width, height, accent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 32)
    SetBackdrop(btn, accent and {0.07, 0.30, 0.25, 1} or C.panel2, accent and C.accentDim or C.border)

    local label = CreateLabel(btn, text, 12, C.text)
    label:SetPoint("CENTER")
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
        if accent then self:SetBackdropColor(0.08, 0.38, 0.30, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(accent and C.accentDim or C.border))
        if accent then self:SetBackdropColor(0.07, 0.30, 0.25, 1) end
    end)

    function btn:SetLabel(value)
        self.label:SetText(value or "")
    end

    return btn
end

local function CreateEditBox(parent, width, height, placeholder)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width or 220, height or 34)
    SetBackdrop(box, {0.025, 0.037, 0.050, 1}, C.border)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextColor(unpack(C.text))
    box:SetTextInsets(10, 10, 0, 0)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accentDim)) end)
    box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)

    local hint = CreateLabel(box, placeholder or "", 12, C.muted)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetAlpha(0.65)
    box.placeholder = hint

    local oldChanged
    box:SetScript("OnTextChanged", function(self, userInput)
        hint:SetShown(self:GetText() == "")
        if oldChanged then oldChanged(self, userInput) end
    end)

    function box:SetChangeHandler(fn)
        oldChanged = fn
    end

    return box
end

local function CreateCheckbox(parent, labelText, getValue, setValue)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(28)

    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(19, 19)
    box:SetPoint("LEFT", 0, 0)
    SetBackdrop(box, {0.025, 0.037, 0.050, 1}, C.border)
    row.box = box

    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    check:SetSize(9, 9)
    check:SetPoint("CENTER")
    row.check = check

    local label = CreateLabel(row, labelText or "", 13, C.text)
    label:SetPoint("LEFT", box, "RIGHT", 9, 0)
    row.label = label

    function row:Refresh()
        local enabled = getValue() and true or false
        check:SetShown(enabled)
        box:SetBackdropBorderColor(unpack(enabled and C.accentDim or C.border))
    end

    row:SetScript("OnClick", function(self)
        setValue(not getValue())
        self:Refresh()
    end)
    row:SetScript("OnEnter", function() label:SetTextColor(unpack(C.accent)) end)
    row:SetScript("OnLeave", function() label:SetTextColor(unpack(C.text)) end)
    row:Refresh()

    return row
end

local function CreateCard(parent, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    SetBackdrop(card, C.panel, C.borderSoft)
    return card
end

local function CreatePageHeading(parent, title, description)
    local titleText = CreateLabel(parent, title, 23, C.text)
    titleText:SetPoint("TOPLEFT", 0, 0)

    local desc = CreateLabel(parent, description, 12, C.muted)
    desc:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -7)
    desc:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    desc:SetJustifyV("TOP")
    desc:SetWordWrap(true)

    return titleText, desc
end

function UI:ClosePopups(except)
    if not self.openPopups then return end
    local toHide = {}
    for popup in pairs(self.openPopups) do
        if popup ~= except then toHide[#toHide + 1] = popup end
    end
    for _, popup in ipairs(toHide) do popup:Hide() end
end

function UI:RegisterPopup(popup, anchor)
    self.openPopups = self.openPopups or {}
    self.openPopups[popup] = true
    popup.anchor = anchor

    -- One reusable transparent full-screen button sits behind whichever popup
    -- is open and above the options window. Clicking anywhere outside closes it.
    if not self.popupDismissLayer then
        local dismiss = CreateFrame("Button", nil, UIParent)
        dismiss:SetAllPoints(UIParent)
        dismiss:SetFrameStrata("TOOLTIP")
        dismiss:SetFrameLevel(900)
        dismiss:EnableMouse(true)
        dismiss:SetScript("OnClick", function() UI:ClosePopups() end)
        dismiss:SetScript("OnMouseDown", function() UI:ClosePopups() end)
        dismiss:Hide()
        self.popupDismissLayer = dismiss
    end
    self.popupDismissLayer:Show()

    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(910)
    popup:HookScript("OnHide", function(p)
        UI.openPopups[p] = nil
        if p.anchor and p.anchor._piPopup == p then p.anchor._piPopup = nil end
        if not next(UI.openPopups) and UI.popupDismissLayer then UI.popupDismissLayer:Hide() end
    end)
end

function UI:CreateDropdown(parent, width, options, getValue, setValue)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 240, 34)
    SetBackdrop(button, {0.025, 0.037, 0.050, 1}, C.border)

    local valueText = CreateLabel(button, "", 12, C.text)
    valueText:SetPoint("LEFT", 10, 0)
    valueText:SetPoint("RIGHT", -32, 0)
    button.valueText = valueText

    local arrow = CreateLabel(button, "v", 13, C.muted)
    arrow:SetPoint("RIGHT", -10, 1)
    arrow:SetJustifyH("RIGHT")

    local optionMap = {}
    for _, option in ipairs(options) do optionMap[option.value] = option.label end

    function button:Refresh()
        valueText:SetText(optionMap[getValue()] or tostring(getValue() or ""))
    end

    button:SetScript("OnClick", function(self)
        -- Clicking the same dropdown again closes it instead of recreating it.
        if self._piPopup and self._piPopup:IsShown() then
            self._piPopup:Hide()
            return
        end

        UI:ClosePopups()
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(width or 240, #options * 32 + 8)
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
        SetBackdrop(popup, {0.025, 0.037, 0.050, 1}, C.border)
        self._piPopup = popup
        UI:RegisterPopup(popup, self)

        for i, option in ipairs(options) do
            local row = CreateFrame("Button", nil, popup)
            row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 32)
            row:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 32)
            row:SetHeight(30)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0)

            local text = CreateLabel(row, option.label, 12, option.value == getValue() and C.accent or C.text)
            text:SetPoint("LEFT", 8, 0)
            row:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, 0.055) end)
            row:SetScript("OnLeave", function() bg:SetColorTexture(1, 1, 1, 0) end)
            row:SetScript("OnClick", function()
                setValue(option.value)
                popup:Hide()
                button:Refresh()
            end)
        end
    end)
    button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accentDim)) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    button:Refresh()
    return button
end

function UI:CreateMainFrame()
    local frame = CreateFrame("Frame", "PIPriorityOptions", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(850, 700)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    SetBackdrop(frame, C.bg, C.border)

    self:ApplyPosition()

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        NS.db.ui.point = point or "CENTER"
        NS.db.ui.relativePoint = relativePoint or "CENTER"
        NS.db.ui.x = x or 0
        NS.db.ui.y = y or 0
    end)
    frame:SetScript("OnHide", function()
        UI:ClosePopups()
        if NS.FrameAlerts and NS.FrameAlerts.auraUnlocked then NS.FrameAlerts:ToggleAuraUnlock(false) end
    end)

    local top = CreateFrame("Frame", nil, frame)
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", 0, 0)
    top:SetHeight(62)

    local accent = top:CreateTexture(nil, "BACKGROUND")
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", 0, 0)
    accent:SetHeight(2)
    accent:SetColorTexture(unpack(C.accentDim))

    local title = CreateLabel(top, "PI Alert", 20, C.text)
    title:SetPoint("LEFT", 22, 7)
    local subtitle = CreateLabel(top, "Power Infusion request assistant", 10, C.muted)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

    local close = CreateButton(top, "x", 34, 30, false)
    close:SetPoint("RIGHT", -16, 4)
    close:SetScript("OnClick", function() frame:Hide() end)

    local reset = CreateButton(top, "Reset", 72, 30, false)
    reset:SetPoint("RIGHT", close, "LEFT", -8, 0)
    reset:SetScript("OnClick", function() UI:ShowResetConfirmation() end)

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 0, -62)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(170)
    SetBackdrop(sidebar, {0.032, 0.047, 0.064, 1}, {0.032, 0.047, 0.064, 1})
    self.sidebar = sidebar

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 24, -20)
    content:SetPoint("BOTTOMRIGHT", -20, 18)
    self.content = content

    self.pages = {}
    self.navButtons = {}
    local navItems = { "Requests", "Alerts", "Spells" }
    for i, name in ipairs(navItems) do
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetPoint("TOPLEFT", 10, -18 - (i - 1) * 48)
        btn:SetPoint("TOPRIGHT", -10, -18 - (i - 1) * 48)
        btn:SetHeight(38)

        local selection = btn:CreateTexture(nil, "BACKGROUND")
        selection:SetAllPoints()
        selection:SetColorTexture(0.10, 0.80, 0.62, 0)
        btn.selection = selection

        local marker = btn:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("LEFT", 0, 0)
        marker:SetSize(3, 24)
        marker:SetColorTexture(unpack(C.accent))
        marker:Hide()
        btn.marker = marker

        local label = CreateLabel(btn, name, 13, C.muted)
        label:SetPoint("LEFT", 14, 0)
        btn.label = label

        btn:SetScript("OnClick", function() UI:SelectPage(name) end)
        btn:SetScript("OnEnter", function(self)
            if NS.db.ui.page ~= name then self.label:SetTextColor(unpack(C.text)) end
        end)
        btn:SetScript("OnLeave", function(self)
            if NS.db.ui.page ~= name then self.label:SetTextColor(unpack(C.muted)) end
        end)
        self.navButtons[name] = btn
    end

    self:BuildRequestsPage()
    self:BuildSpellsPage()
    self:BuildAlertsPage()

    table.insert(UISpecialFrames, "PIPriorityOptions")
    self:SelectPage(NS.db.ui.page or "Requests")
    frame:Hide()
end

function UI:ApplyPosition()
    if not self.frame or not NS.db or not NS.db.ui then return end
    local cfg = NS.db.ui
    self.frame:ClearAllPoints()
    self.frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.relativePoint or "CENTER", cfg.x or 0, cfg.y or 0)
end

function UI:SelectPage(name)
    if not self.pages or not self.pages[name] then name = "Requests" end
    NS.db.ui.page = name
    for pageName, page in pairs(self.pages) do page:SetShown(pageName == name) end
    for navName, btn in pairs(self.navButtons) do
        local active = navName == name
        btn.selection:SetColorTexture(0.10, 0.80, 0.62, active and 0.11 or 0)
        btn.marker:SetShown(active)
        btn.label:SetTextColor(unpack(active and C.accent or C.muted))
    end
    self:ClosePopups()
    self:RefreshPage(name)
end

function UI:Init()
    self:CreateMainFrame()
end

function UI:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Refresh() end
end

function UI:Refresh()
    if not self.frame then return end
    self:RefreshRequestsPage()
    self:RefreshSpellsPage()
    self:RefreshAlertsPage()
end

function UI:RefreshPage(name)
    if name == "Requests" then self:RefreshRequestsPage()
    elseif name == "Spells" then self:RefreshSpellsPage()
    elseif name == "Alerts" then self:RefreshAlertsPage()
    end
end

-- -----------------------------------------------------------------------------
-- Requests page
-- -----------------------------------------------------------------------------

function UI:BuildRequestsPage()
    local page = CreateFrame("Frame", nil, self.content)
    page:SetAllPoints()
    self.pages.Requests = page
    CreatePageHeading(page, "Requests", "Choose how requests are accepted, who can make them, and which whisper phrases are recognized.")

    local sourceCard = CreateCard(page, 632, 220)
    sourceCard:SetPoint("TOPLEFT", 0, -72)
    self.requestSourceCard = sourceCard

    local title = CreateLabel(sourceCard, "Request handling", 15, C.text)
    title:SetPoint("TOPLEFT", 16, -14)
    local sub = CreateLabel(sourceCard, "Accept whispers, tracked allied cooldown buffs, or both.", 10, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local howLabel = CreateLabel(sourceCard, "How to accept requests", 11, C.text)
    howLabel:SetPoint("TOPLEFT", 16, -66)
    local howDesc = CreateLabel(sourceCard, "Spell Cast follows the tracked buff and only shows while PI is ready.", 10, C.muted)
    howDesc:SetPoint("TOPLEFT", 16, -84)
    howDesc:SetWidth(300)

    self.requestModeDropdown = self:CreateDropdown(sourceCard, 270, {
        { value = "BOTH", label = "Whispers & Spell Cast" },
        { value = "WHISPER", label = "Whispers" },
        { value = "SPELL", label = "Spell Cast" },
    }, function() return NS.db.requests.mode end, function(value)
        NS.db.requests.mode = value
        if NS.Detector then NS.Detector:OnSettingsChanged() end
        UI:RefreshRequestsPage()
    end)
    self.requestModeDropdown:SetPoint("TOPLEFT", 346, -68)

    local whoLabel = CreateLabel(sourceCard, "Who can request?", 11, C.text)
    whoLabel:SetPoint("TOPLEFT", 16, -120)
    self.requesterModeDescription = CreateLabel(sourceCard, "", 10, C.muted)
    self.requesterModeDescription:SetPoint("TOPLEFT", 16, -138)
    self.requesterModeDescription:SetWidth(300)

    self.requesterDropdown = self:CreateDropdown(sourceCard, 270, {
        { value = "EVERYONE", label = "Everyone in Group" },
        { value = "FOCUS", label = "Focus" },
        { value = "SPECIFIC", label = "Specific Players" },
    }, function() return NS.db.requesters.mode end, function(value)
        NS.db.requesters.mode = value
        if NS.Detector then NS.Detector:OnSettingsChanged() end
        UI:RefreshRequestsPage()
    end)
    self.requesterDropdown:SetPoint("TOPLEFT", 346, -122)

    self.requesterFallbackLabel = CreateLabel(sourceCard, "Fallback if none available", 11, C.text)
    self.requesterFallbackLabel:SetPoint("TOPLEFT", 16, -174)
    self.requesterFallbackDescription = CreateLabel(sourceCard, "Used only when none of the listed players are in your group.", 10, C.muted)
    self.requesterFallbackDescription:SetPoint("TOPLEFT", 16, -192)
    self.requesterFallbackDescription:SetWidth(300)

    self.requesterFallbackDropdown = self:CreateDropdown(sourceCard, 270, {
        { value = "NONE", label = "No fallback" },
        { value = "FOCUS", label = "Focus" },
        { value = "EVERYONE", label = "Everyone in Group" },
    }, function() return NS.db.requesters.fallback or "NONE" end, function(value)
        NS.db.requesters.fallback = value
        if NS.Detector then NS.Detector:OnSettingsChanged() end
    end)
    self.requesterFallbackDropdown:SetPoint("TOPLEFT", 346, -176)

    local phraseCard = CreateCard(page, 632, 282)
    phraseCard:SetPoint("TOPLEFT", sourceCard, "BOTTOMLEFT", 0, -14)
    self.phraseCard = phraseCard

    local ptitle = CreateLabel(phraseCard, "Whisper phrases", 15, C.text)
    ptitle:SetPoint("TOPLEFT", 16, -14)
    local pdesc = CreateLabel(phraseCard, "Contains matches whole words or phrases.", 10, C.muted)
    pdesc:SetPoint("TOPLEFT", 16, -52)
    pdesc:SetPoint("RIGHT", -14, 0)
    pdesc:SetWordWrap(true)
    self.phraseDescription = pdesc

    local add = CreateButton(phraseCard, "+ Add phrase", 112, 30, true)
    add:SetPoint("TOPRIGHT", -14, -14)
    add:SetScript("OnClick", function() UI:ShowPhraseDialog() end)
    self.phraseAddButton = add

    local scroll = CreateFrame("ScrollFrame", nil, phraseCard)
    scroll:SetPoint("TOPLEFT", 14, -78)
    scroll:SetPoint("BOTTOMRIGHT", -14, 14)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(590)
    child:SetHeight(1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 44)))
    end)
    self.phraseScroll = scroll
    self.phraseChild = child
    self.phraseRows = {}

    local playerCard = CreateCard(page, 632, 282)
    playerCard:SetPoint("TOPLEFT", sourceCard, "BOTTOMLEFT", 0, -14)
    self.playerCard = playerCard

    local playerTitle = CreateLabel(playerCard, "Specific players", 15, C.text)
    playerTitle:SetPoint("TOPLEFT", 16, -14)
    local playerDesc = CreateLabel(playerCard, "Names are case- and realm-insensitive.", 10, C.muted)
    playerDesc:SetPoint("TOPLEFT", playerTitle, "BOTTOMLEFT", 0, -4)
    playerDesc:SetPoint("RIGHT", -14, 0)
    self.playerDescription = playerDesc

    self.playerInput = CreateEditBox(playerCard, 330, 34, "Player name")
    self.playerInput:SetPoint("TOPLEFT", 16, -62)
    self.playerInput:SetScript("OnEnterPressed", function() UI:AddSpecificPlayer() end)
    self.playerAddButton = CreateButton(playerCard, "Add player", 90, 34, true)
    self.playerAddButton:SetPoint("LEFT", self.playerInput, "RIGHT", 8, 0)
    self.playerAddButton:SetScript("OnClick", function() UI:AddSpecificPlayer() end)

    local listScroll = CreateFrame("ScrollFrame", nil, playerCard)
    listScroll:SetPoint("TOPLEFT", 14, -108)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 14)
    listScroll:EnableMouseWheel(true)
    local playerChild = CreateFrame("Frame", nil, listScroll)
    playerChild:SetWidth(590)
    playerChild:SetHeight(1)
    listScroll:SetScrollChild(playerChild)
    listScroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, playerChild:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 42)))
    end)
    self.playerListScroll = listScroll
    self.playerListChild = playerChild
    self.playerRows = {}
end

function UI:LayoutRequestDetailCards(whispersEnabled, specific)
    local both = whispersEnabled and specific
    local width = both and 309 or 632
    local height = specific and 282 or 336

    self.phraseCard:ClearAllPoints()
    self.playerCard:ClearAllPoints()
    self.phraseCard:SetShown(whispersEnabled)
    self.playerCard:SetShown(specific)

    if whispersEnabled then
        self.phraseCard:SetSize(width, height)
        self.phraseCard:SetPoint("TOPLEFT", self.requestSourceCard, "BOTTOMLEFT", 0, -14)
    end
    if specific then
        self.playerCard:SetSize(width, height)
        if both then
            self.playerCard:SetPoint("TOPLEFT", self.phraseCard, "TOPRIGHT", 14, 0)
        else
            self.playerCard:SetPoint("TOPLEFT", self.requestSourceCard, "BOTTOMLEFT", 0, -14)
        end
    end

    if whispersEnabled then
        local rowWidth = width - 42
        self.phraseListWidth = rowWidth
        self.phraseChild:SetWidth(rowWidth)
        for _, row in ipairs(self.phraseRows) do row:SetWidth(rowWidth) end
        if self.phraseEmptyRow then self.phraseEmptyRow:SetWidth(rowWidth) end
    end

    if specific then
        local rowWidth = width - 42
        self.playerListWidth = rowWidth
        self.playerListChild:SetWidth(rowWidth)
        self.playerInput:SetWidth(math.max(120, width - 138))
        for _, row in ipairs(self.playerRows) do row:SetWidth(rowWidth) end
        if self.playerEmptyRow then self.playerEmptyRow:SetWidth(rowWidth) end
    end
end

function UI:RefreshPhraseRows()
    if not self.phraseChild then return end
    for _, row in ipairs(self.phraseRows) do row:Hide() end

    local rowWidth = self.phraseListWidth or 590
    local phrases = NS.db.requests.phrases or {}
    if #phrases == 0 then
        if not self.phraseEmptyRow then
            local row = CreateFrame("Frame", nil, self.phraseChild)
            row:SetSize(rowWidth, 44)
            local text = CreateLabel(row, "No phrases yet. Add one to accept whisper requests.", 12, C.muted)
            text:SetPoint("LEFT", 12, 0)
            row.emptyText = text
            self.phraseEmptyRow = row
        end
        self.phraseEmptyRow:SetWidth(rowWidth)
        self.phraseEmptyRow:ClearAllPoints()
        self.phraseEmptyRow:SetPoint("TOPLEFT", 0, 0)
        self.phraseEmptyRow:Show()
        self.phraseChild:SetHeight(44)
        return
    elseif self.phraseEmptyRow then
        self.phraseEmptyRow:Hide()
    end

    local y = 0
    for i, phrase in ipairs(phrases) do
        local row = self.phraseRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.phraseChild, "BackdropTemplate")
            row:SetSize(rowWidth, 44)
            SetBackdrop(row, C.panel2, C.borderSoft)

            local text = CreateLabel(row, "", 12, C.text)
            text:SetPoint("LEFT", 12, 0)
            text:SetPoint("RIGHT", -158, 0)
            row.text = text

            row.mode = self:CreateDropdown(row, 96, {
                { value = "CONTAINS", label = "Contains" },
                { value = "EXACT", label = "Exact" },
            }, function() return row.data and row.data.match or "CONTAINS" end, function(value)
                if row.data then row.data.match = value end
            end)
            row.mode:SetPoint("RIGHT", -48, 0)

            local remove = CreateButton(row, "x", 30, 28, false)
            remove:SetPoint("RIGHT", -8, 0)
            remove:SetScript("OnClick", function()
                if not row.index then return end
                table.remove(NS.db.requests.phrases, row.index)
                UI:RefreshPhraseRows()
            end)
            row.remove = remove
            self.phraseRows[i] = row
        end

        row:SetWidth(rowWidth)
        row.data = phrase
        row.index = i
        row.text:SetText(phrase.text)
        row.mode:Refresh()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + 50
    end
    self.phraseChild:SetHeight(math.max(1, y))
end

function UI:RefreshRequestsPage()
    if not self.requestModeDropdown or not self.requesterDropdown then return end
    self.requestModeDropdown:Refresh()
    self.requesterDropdown:Refresh()

    local mode = NS.db.requests.mode or "BOTH"
    local whispersEnabled = mode == "BOTH" or mode == "WHISPER"
    local requesterMode = NS.db.requesters.mode or "EVERYONE"
    local specific = requesterMode == "SPECIFIC"

    if requesterMode == "SPECIFIC" then
        self.requesterModeDescription:SetText("Listed players have priority while any are in your group.")
    elseif requesterMode == "FOCUS" then
        self.requesterModeDescription:SetText("Only your current focus while they are in your group.")
    else
        self.requesterModeDescription:SetText("Anyone currently in your party or raid.")
    end

    self.requesterFallbackLabel:SetShown(specific)
    self.requesterFallbackDescription:SetShown(specific)
    self.requesterFallbackDropdown:SetShown(specific)
    self.requestSourceCard:SetHeight(specific and 220 or 166)
    self:LayoutRequestDetailCards(whispersEnabled, specific)

    if whispersEnabled then
        self:RefreshPhraseRows()
    end
    if specific then
        self.requesterFallbackDropdown:Refresh()
        self:RefreshPlayerRows()
    end
end

function UI:AddSpecificPlayer()
    local raw = strtrim(self.playerInput:GetText() or "")
    if raw == "" then return end
    local base = NS:DisplayBaseName(raw)
    if not NS:NormalizeName(base) then return end

    NS:AddSpecificRequester(base)
    self.playerInput:SetText("")
    self.playerInput:ClearFocus()
end

function UI:RefreshPlayerRows()
    if not self.playerListChild then return end
    for _, row in ipairs(self.playerRows) do row:Hide() end
    local rowWidth = self.playerListWidth or 590
    local players = NS.db.requesters.players or {}
    local y = 0

    if #players == 0 then
        if not self.playerEmptyRow then
            local row = CreateFrame("Frame", nil, self.playerListChild)
            row:SetSize(rowWidth, 42)
            local text = CreateLabel(row, "No players added yet.", 12, C.muted)
            text:SetPoint("LEFT", 10, 0)
            row.emptyText = text
            self.playerEmptyRow = row
        end
        self.playerEmptyRow:SetWidth(rowWidth)
        self.playerEmptyRow:ClearAllPoints()
        self.playerEmptyRow:SetPoint("TOPLEFT", 0, 0)
        self.playerEmptyRow:Show()
        self.playerListChild:SetHeight(42)
        return
    elseif self.playerEmptyRow then
        self.playerEmptyRow:Hide()
    end

    for i, playerName in ipairs(players) do
        local row = self.playerRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.playerListChild, "BackdropTemplate")
            row:SetSize(rowWidth, 40)
            SetBackdrop(row, C.panel2, C.borderSoft)
            local name = CreateLabel(row, "", 12, C.text)
            name:SetPoint("LEFT", 12, 0)
            row.name = name
            local remove = CreateButton(row, "Remove", 70, 26, false)
            remove:SetPoint("RIGHT", -8, 0)
            remove:SetScript("OnClick", function()
                if row.index then
                    local playerName = NS.db.requesters.players[row.index]
                    if playerName then NS:RemoveSpecificRequester(playerName) end
                end
            end)
            self.playerRows[i] = row
        end
        row:SetWidth(rowWidth)
        row.index = i
        row.name:SetText(playerName)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + 46
    end
    self.playerListChild:SetHeight(math.max(1, y))
end

-- -----------------------------------------------------------------------------
-- Spells page
-- -----------------------------------------------------------------------------

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local function GetClassHeaderColor(classToken)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[classToken]
    if color then return color.r, color.g, color.b end
    return C.accent[1], C.accent[2], C.accent[3]
end

local function SetClassIcon(texture, classToken)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        texture:SetTexture(CLASS_ICON_TEXTURE)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function ApplySpellRowBackground(row, hovered)
    local entry = row.entry
    if not entry then return end

    if entry.type == "header" and entry.class then
        local r, g, b = GetClassHeaderColor(entry.class)
        row.bg:SetColorTexture(r, g, b, hovered and 0.18 or 0.11)
    elseif entry.type == "customHeader" then
        row.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], hovered and 0.11 or 0.055)
    elseif entry.type == "spell" then
        row.bg:SetColorTexture(1, 1, 1, hovered and 0.045 or 0)
    end
end

function UI:GetClassSpellState(classToken)
    local total, enabled = 0, 0
    for _, spell in ipairs(NS.PRESET_SPELLS[classToken] or {}) do
        total = total + 1
        if NS.db.spells[spell.id] == true then enabled = enabled + 1 end
    end

    if total > 0 and enabled == total then return "ALL" end
    if enabled > 0 then return "PARTIAL" end
    return "NONE"
end

function UI:SetClassSpellsEnabled(classToken, enabled)
    for _, spell in ipairs(NS.PRESET_SPELLS[classToken] or {}) do
        NS.db.spells[spell.id] = enabled and true or false
    end
    if NS.Detector then NS.Detector:OnSettingsChanged() end
    self:RefreshSpellList()
end

function UI:IsClassCollapsed(classToken)
    NS.db.ui.spellCollapsed = NS.db.ui.spellCollapsed or {}
    return NS.db.ui.spellCollapsed[classToken] == true
end

function UI:ToggleClassCollapsed(classToken)
    NS.db.ui.spellCollapsed = NS.db.ui.spellCollapsed or {}
    NS.db.ui.spellCollapsed[classToken] = not NS.db.ui.spellCollapsed[classToken]
    self:RefreshSpellList()
end

function UI:BuildSpellsPage()
    local page = CreateFrame("Frame", nil, self.content)
    page:SetAllPoints()
    self.pages.Spells = page
    CreatePageHeading(page, "Spells", "Choose which major DPS cooldown activations should count as a Power Infusion request.")

    self.spellSearch = CreateEditBox(page, 340, 34, "Search spells, classes, or spell ID...")
    self.spellSearch:SetPoint("TOPLEFT", 0, -72)
    self.spellSearch:SetChangeHandler(function() UI.spellOffset = 1; UI:RefreshSpellList() end)

    local add = CreateButton(page, "+ Custom spell", 126, 34, true)
    add:SetPoint("TOPRIGHT", -2, -72)
    add:SetScript("OnClick", function() UI:ShowCustomSpellDialog() end)

    local list = CreateCard(page, 632, 456)
    list:SetPoint("TOPLEFT", 0, -120)
    self.spellList = list

    self.spellRows = {}
    self.spellVisibleRows = 12
    self.spellOffset = 1
    for i = 1, self.spellVisibleRows do
        local row = CreateFrame("Button", nil, list)
        row:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 36)
        row:SetPoint("TOPRIGHT", -28, -8 - (i - 1) * 36)
        row:SetHeight(34)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, 0)
        row.bg = bg

        local headerAccent = row:CreateTexture(nil, "BORDER")
        headerAccent:SetPoint("TOPLEFT", 0, 0)
        headerAccent:SetPoint("BOTTOMLEFT", 0, 0)
        headerAccent:SetWidth(3)
        headerAccent:Hide()
        row.headerAccent = headerAccent

        -- A simple +/- affordance reads more cleanly than a glyph chevron and
        -- stays aligned at the far-right edge of every class header.
        local collapse = CreateLabel(row, "-", 18, C.muted)
        collapse:SetPoint("RIGHT", -10, 1)
        collapse:SetWidth(22)
        collapse:SetJustifyH("CENTER")
        row.collapse = collapse

        local headerBox = CreateFrame("Button", nil, row, "BackdropTemplate")
        headerBox:SetSize(18, 18)
        headerBox:SetPoint("LEFT", 10, 0)
        SetBackdrop(headerBox, {0.025, 0.037, 0.050, 1}, C.border)
        row.headerBox = headerBox

        local headerCheck = headerBox:CreateTexture(nil, "OVERLAY")
        headerCheck:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        headerCheck:SetSize(9, 9)
        headerCheck:SetPoint("CENTER")
        row.headerCheck = headerCheck

        -- Partial class selection uses a thicker accent bar instead of a glyph,
        -- matching the filled-square style used by checked boxes.
        local headerMinus = headerBox:CreateTexture(nil, "OVERLAY")
        headerMinus:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        headerMinus:SetSize(10, 3)
        headerMinus:SetPoint("CENTER")
        row.headerMinus = headerMinus

        local classText = CreateLabel(row, "", 13, C.accent)
        classText:SetPoint("LEFT", headerBox, "RIGHT", 9, 0)
        row.classText = classText

        local classIcon = row:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(20, 20)
        classIcon:SetPoint("LEFT", classText, "RIGHT", 8, 0)
        row.classIcon = classIcon

        local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
        box:SetSize(18, 18)
        box:SetPoint("LEFT", 6, 0)
        SetBackdrop(box, {0.025, 0.037, 0.050, 1}, C.border)
        row.box = box
        local check = box:CreateTexture(nil, "OVERLAY")
        check:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        check:SetSize(9, 9)
        check:SetPoint("CENTER")
        row.check = check

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", box, "RIGHT", 9, 0)
        row.icon = icon

        local name = CreateLabel(row, "", 12, C.text)
        name:SetPoint("LEFT", icon, "RIGHT", 9, 0)
        name:SetPoint("RIGHT", -150, 0)
        row.name = name

        local id = CreateLabel(row, "", 10, C.muted)
        id:SetPoint("RIGHT", -46, 0)
        id:SetJustifyH("RIGHT")
        row.id = id

        local remove = CreateButton(row, "x", 28, 26, false)
        remove:SetPoint("RIGHT", -4, 0)
        row.remove = remove
        remove:SetScript("OnClick", function()
            local entry = row.entry
            if entry and entry.customIndex then
                local idToRemove = entry.id
                table.remove(NS.db.customSpells, entry.customIndex)
                NS.db.spells[idToRemove] = nil
                if NS.Detector then NS.Detector:OnSettingsChanged() end
                UI:RefreshSpellList()
            end
        end)

        headerBox:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(C.accent))
        end)
        headerBox:SetScript("OnLeave", function(self)
            local entry = row.entry
            if not entry or entry.type ~= "header" then return end
            local state = UI:GetClassSpellState(entry.class)
            self:SetBackdropBorderColor(unpack(state == "NONE" and C.border or C.accentDim))
        end)
        headerBox:SetScript("OnClick", function()
            local entry = row.entry
            if not entry or entry.type ~= "header" or not entry.class then return end
            local state = UI:GetClassSpellState(entry.class)
            -- Standard tri-state behavior: a partial selection becomes fully selected.
            UI:SetClassSpellsEnabled(entry.class, state ~= "ALL")
        end)

        row:SetScript("OnEnter", function(self)
            ApplySpellRowBackground(self, true)
            local entry = self.entry
            if entry and entry.type == "spell" and entry.id then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(entry.id)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            ApplySpellRowBackground(self, false)
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end)
        row:SetScript("OnClick", function(self)
            local entry = self.entry
            if not entry then return end
            if entry.type == "header" and entry.class then
                UI:ToggleClassCollapsed(entry.class)
                return
            end
            if entry.type ~= "spell" then return end
            NS.db.spells[entry.id] = not NS.db.spells[entry.id]
            if NS.Detector then NS.Detector:OnSettingsChanged() end
            UI:RefreshSpellList()
        end)

        self.spellRows[i] = row
    end

    -- Visible scroll position. The list remains mouse-wheel friendly, while
    -- the slider makes it obvious that more rows are available and also
    -- supports click/drag scrolling.
    local scrollbar = CreateFrame("Slider", nil, list, "BackdropTemplate")
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetPoint("TOPRIGHT", -8, -10)
    scrollbar:SetPoint("BOTTOMRIGHT", -8, 10)
    scrollbar:SetWidth(10)
    SetBackdrop(scrollbar, {0.020, 0.030, 0.042, 1}, C.borderSoft)
    scrollbar:SetMinMaxValues(1, 1)
    scrollbar:SetValueStep(1)
    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollbar:GetThumbTexture()
    if thumb then
        thumb:SetSize(8, 50)
        thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.72)
    end
    scrollbar:SetScript("OnEnter", function(self)
        local t = self:GetThumbTexture()
        if t then t:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1) end
    end)
    scrollbar:SetScript("OnLeave", function(self)
        local t = self:GetThumbTexture()
        if t then t:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.72) end
    end)
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if UI._syncingSpellScrollbar then return end
        local total = #(UI.spellEntries or {})
        local maxOffset = math.max(1, total - UI.spellVisibleRows + 1)
        -- Map the thumb position directly to the list offset so dragging the
        -- scrollbar downward moves forward/down through the spell list.
        local offset = math.floor((tonumber(value) or 1) + 0.5)
        offset = math.max(1, math.min(maxOffset, offset))
        if offset ~= UI.spellOffset then
            UI.spellOffset = offset
            UI:RenderSpellRows()
        end
    end)
    self.spellScrollbar = scrollbar

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local total = #(UI.spellEntries or {})
        local maxOffset = math.max(1, total - UI.spellVisibleRows + 1)
        UI.spellOffset = math.max(1, math.min(maxOffset, (UI.spellOffset or 1) - delta * 3))
        UI:RenderSpellRows()
        UI:SyncSpellScrollbar()
    end)
end

function UI:IsPresetSpellID(spellID)
    for _, classToken in ipairs(NS.CLASS_ORDER) do
        for _, spell in ipairs(NS.PRESET_SPELLS[classToken] or {}) do
            if spell.id == spellID then return true end
        end
    end
    return false
end

function UI:BuildSpellEntries()
    local query = strtrim(self.spellSearch and self.spellSearch:GetText() or ""):lower()
    local entries = {}
    local searching = query ~= ""

    for _, classToken in ipairs(NS.CLASS_ORDER) do
        local className = NS.CLASS_NAMES[classToken] or classToken
        local matches = {}
        for _, spell in ipairs(NS.PRESET_SPELLS[classToken] or {}) do
            local liveName = NS:GetSpellName(spell.id, spell.label)
            local haystack = (className .. " " .. liveName .. " " .. tostring(spell.id)):lower()
            if query == "" or haystack:find(query, 1, true) then
                matches[#matches + 1] = { type = "spell", id = spell.id, label = liveName, class = classToken }
            end
        end
        if #matches > 0 then
            -- Search results temporarily expand matching classes without changing
            -- the user's saved collapsed/expanded state.
            local collapsed = not searching and self:IsClassCollapsed(classToken)
            entries[#entries + 1] = {
                type = "header",
                label = className,
                class = classToken,
                collapsed = collapsed,
            }
            if not collapsed then
                for _, entry in ipairs(matches) do entries[#entries + 1] = entry end
            end
        end
    end

    local customMatches = {}
    for i, spell in ipairs(NS.db.customSpells or {}) do
        local liveName = NS:GetSpellName(spell.id, spell.label)
        local haystack = ("Custom " .. liveName .. " " .. tostring(spell.id)):lower()
        if query == "" or haystack:find(query, 1, true) then
            customMatches[#customMatches + 1] = { type = "spell", id = spell.id, label = liveName, customIndex = i }
        end
    end
    if #customMatches > 0 then
        entries[#entries + 1] = { type = "customHeader", label = "Custom" }
        for _, entry in ipairs(customMatches) do entries[#entries + 1] = entry end
    end

    self.spellEntries = entries
end

function UI:RenderSpellRows()
    local entries = self.spellEntries or {}
    local offset = self.spellOffset or 1
    for i, row in ipairs(self.spellRows or {}) do
        local entry = entries[offset + i - 1]
        row.entry = entry
        if not entry then
            row:Hide()
        elseif entry.type == "header" then
            row:Show()
            row.headerAccent:Show()
            row.collapse:Show()
            row.headerBox:Show()
            row.classText:ClearAllPoints()
            row.classText:SetPoint("LEFT", row.headerBox, "RIGHT", 9, 0)
            row.classText:Show()
            row.classIcon:Show()
            row.box:Hide()
            row.icon:Hide()
            row.name:Hide()
            row.id:Hide()
            row.remove:Hide()

            local r, g, b = GetClassHeaderColor(entry.class)
            row.headerAccent:SetColorTexture(r, g, b, 0.95)
            row.classText:SetText(entry.label)
            row.classText:SetTextColor(r, g, b, 1)
            SetClassIcon(row.classIcon, entry.class)
            row.collapse:SetText(entry.collapsed and "+" or "-")
            row.collapse:SetTextColor(r, g, b, 1)

            local state = self:GetClassSpellState(entry.class)
            row.headerCheck:SetShown(state == "ALL")
            row.headerMinus:SetShown(state == "PARTIAL")
            row.headerBox:SetBackdropBorderColor(unpack(state == "NONE" and C.border or C.accentDim))
            ApplySpellRowBackground(row, false)
        elseif entry.type == "customHeader" then
            row:Show()
            row.headerAccent:Show()
            row.headerAccent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.75)
            row.collapse:Hide()
            row.headerBox:Hide()
            row.classText:SetText(entry.label)
            row.classText:ClearAllPoints()
            row.classText:SetPoint("LEFT", 12, 0)
            row.classText:SetTextColor(unpack(C.accent))
            row.classText:Show()
            row.classIcon:Hide()
            row.box:Hide()
            row.icon:Hide()
            row.name:Hide()
            row.id:Hide()
            row.remove:Hide()
            ApplySpellRowBackground(row, false)
        else
            row:Show()
            row.headerAccent:Hide()
            row.collapse:Hide()
            row.headerBox:Hide()
            row.classText:ClearAllPoints()
            row.classText:SetPoint("LEFT", row.headerBox, "RIGHT", 9, 0)
            row.classText:Hide()
            row.classIcon:Hide()
            row.box:Show()
            row.icon:Show()
            row.name:Show()
            row.id:Show()
            row.remove:SetShown(entry.customIndex ~= nil)
            row.icon:SetTexture(NS:GetSpellIcon(entry.id))
            row.icon:SetTexCoord(0, 1, 0, 1)
            row.name:SetText(entry.label)
            row.id:SetText(tostring(entry.id))
            local enabled = NS.db.spells[entry.id] == true
            row.check:SetShown(enabled)
            row.box:SetBackdropBorderColor(unpack(enabled and C.accentDim or C.border))
            ApplySpellRowBackground(row, false)
        end
    end
end

function UI:SyncSpellScrollbar()
    local scrollbar = self.spellScrollbar
    if not scrollbar then return end

    local total = #(self.spellEntries or {})
    local maxOffset = math.max(1, total - (self.spellVisibleRows or 1) + 1)
    local offset = math.max(1, math.min(maxOffset, self.spellOffset or 1))

    self._syncingSpellScrollbar = true
    scrollbar:SetMinMaxValues(1, maxOffset)
    scrollbar:SetValue(offset)
    self._syncingSpellScrollbar = false

    local thumb = scrollbar:GetThumbTexture()
    if maxOffset <= 1 then
        scrollbar:SetAlpha(0.28)
        scrollbar:EnableMouse(false)
        if thumb then thumb:SetHeight(80) end
    else
        scrollbar:SetAlpha(1)
        scrollbar:EnableMouse(true)
        -- Make the thumb subtly reflect how much of the list is visible.
        local trackHeight = scrollbar:GetHeight() or 420
        local ratio = math.min(1, (self.spellVisibleRows or 1) / math.max(total, 1))
        local thumbHeight = math.max(34, math.min(96, trackHeight * ratio))
        if thumb then thumb:SetHeight(thumbHeight) end
    end
end

function UI:RefreshSpellList()
    if not self.spellRows then return end
    self:BuildSpellEntries()
    local maxOffset = math.max(1, #self.spellEntries - self.spellVisibleRows + 1)
    self.spellOffset = math.max(1, math.min(maxOffset, self.spellOffset or 1))
    self:RenderSpellRows()
    self:SyncSpellScrollbar()
end

function UI:RefreshSpellsPage()
    self:RefreshSpellList()
end

-- -----------------------------------------------------------------------------
-- Alerts page
-- -----------------------------------------------------------------------------

function UI:ScheduleGlowRefresh()
    self.glowRefreshSerial = (self.glowRefreshSerial or 0) + 1
    local serial = self.glowRefreshSerial
    C_Timer.After(0.05, function()
        if UI.glowRefreshSerial ~= serial then return end
        if NS.FrameAlerts then NS.FrameAlerts:OnSettingsChanged(false) end
        if NS.Detector then NS.Detector:OnSettingsChanged() end
    end)
end

function UI:CreateCompactNumberField(parent, labelText, getValue, setValue, minValue, maxValue, width, precision)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 80, 52)

    local label = CreateLabel(container, labelText, 10, C.muted)
    label:SetPoint("TOPLEFT", 0, 0)

    local box = CreateEditBox(container, width or 80, 30, "")
    box:SetPoint("TOPLEFT", 0, -18)
    box:SetJustifyH("CENTER")
    container.box = box

    precision = precision or 0
    local factor = 10 ^ precision
    local function normalize(value)
        value = tonumber(value) or tonumber(getValue()) or minValue
        value = math.max(minValue, math.min(maxValue, value))
        return math.floor(value * factor + 0.5) / factor
    end
    local function display(value)
        value = normalize(value)
        if precision <= 0 then return tostring(math.floor(value + 0.5)) end
        return string.format("%." .. precision .. "f", value):gsub("0+$", ""):gsub("%.$", "")
    end
    local function commit()
        local value = normalize(box:GetText())
        setValue(value)
        box:SetText(display(value))
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", commit)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(C.border))
        local value = normalize(self:GetText())
        setValue(value)
        self:SetText(display(value))
    end)

    function container:Refresh()
        box:SetText(display(getValue()))
    end
    container:Refresh()
    return container
end

function UI:CreateGlowColorSwatch(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(58, 34)
    SetBackdrop(button, {0.025, 0.037, 0.050, 1}, C.border)

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 5, -5)
    swatch:SetPoint("BOTTOMRIGHT", -5, 5)
    button.swatch = swatch

    function button:Refresh()
        local color = NS.db.alerts.glowColor or {1.00, 0.82, 0.20, 1}
        swatch:SetColorTexture(tonumber(color[1]) or 1.00, tonumber(color[2]) or 0.82, tonumber(color[3]) or 0.20, 1)
        local custom = NS.db.alerts.glowColorMode == "CUSTOM"
        self:SetAlpha(custom and 1 or 0.35)
        self:EnableMouse(custom)
    end

    button:SetScript("OnClick", function(self) UI:OpenGlowColorPicker(self) end)
    button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accentDim)) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    button:Refresh()
    return button
end

function UI:OpenGlowColorPicker(swatch)
    if NS.db.alerts.glowColorMode ~= "CUSTOM" or not ColorPickerFrame then return end
    local color = NS.db.alerts.glowColor or {1.00, 0.82, 0.20, 1}
    local before = { tonumber(color[1]) or 1.00, tonumber(color[2]) or 0.82, tonumber(color[3]) or 0.20, tonumber(color[4]) or 1 }

    local function apply(r, g, b)
        NS.db.alerts.glowColor = { r, g, b, before[4] }
        if swatch and swatch.Refresh then swatch:Refresh() end
        UI:ScheduleGlowRefresh()
    end
    local function changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply(r, g, b)
    end
    local function cancelled()
        NS.db.alerts.glowColor = { before[1], before[2], before[3], before[4] }
        if swatch and swatch.Refresh then swatch:Refresh() end
        UI:ScheduleGlowRefresh()
    end

    -- Retail's color picker uses SetupColorPickerAndShow (10.2.5+).
    -- Keep the legacy path only as a fallback for older clients.
    if type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = before[1],
            g = before[2],
            b = before[3],
            hasOpacity = false,
            swatchFunc = changed,
            opacityFunc = changed,
            cancelFunc = cancelled,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacity = nil
        ColorPickerFrame.previousValues = before
        ColorPickerFrame.func = changed
        ColorPickerFrame.opacityFunc = changed
        ColorPickerFrame.cancelFunc = cancelled
        ColorPickerFrame:SetColorRGB(before[1], before[2], before[3])
        ColorPickerFrame:Show()
    end
end

function UI:BuildAlertsPage()
    local page = CreateFrame("Frame", nil, self.content)
    page:SetAllPoints()
    self.pages.Alerts = page
    CreatePageHeading(page, "Alerts", "Configure raidframes, the movable aura icon, and whisper-only sound behavior.")

    self.alertControls = {}

    local function setVisualOption(key, value, refreshDetector)
        NS.db.alerts[key] = value and true or false
        if NS.FrameAlerts then NS.FrameAlerts:OnSettingsChanged(false) end
        if refreshDetector and NS.Detector then NS.Detector:OnSettingsChanged() end
        UI:RefreshAlertsPage()
    end

    -- Raidframe settings ------------------------------------------------------
    local raidCard = CreateCard(page, 382, 526)
    raidCard:SetPoint("TOPLEFT", 0, -62)
    self.raidframeSettingsCard = raidCard

    local raidTitle = CreateLabel(raidCard, "Raidframe settings", 15, C.text)
    raidTitle:SetPoint("TOPLEFT", 16, -14)
    local raidDesc = CreateLabel(raidCard, "Glow and centered icon options for accepted requests.", 10, C.muted)
    raidDesc:SetPoint("TOPLEFT", raidTitle, "BOTTOMLEFT", 0, -4)

    self.alertControls.glow = CreateCheckbox(raidCard, "Enable glow on raidframes",
        function() return NS.db.alerts.glow end,
        function(value) setVisualOption("glow", value, true) end)
    self.alertControls.glow:SetPoint("TOPLEFT", 16, -50)
    self.alertControls.glow:SetPoint("RIGHT", -16, 0)

    local styleLabel = CreateLabel(raidCard, "Glow style", 10, C.muted)
    styleLabel:SetPoint("TOPLEFT", 16, -88)
    self.glowStyleDropdown = self:CreateDropdown(raidCard, 350, {
        { value = "PIXEL", label = "Pixel Glow" },
        { value = "AUTOCAST", label = "AutoCast Glow" },
        { value = "BUTTON", label = "Button Glow" },
    }, function() return NS.db.alerts.glowStyle end, function(value)
        NS.db.alerts.glowStyle = value
        UI:ScheduleGlowRefresh()
        UI:RefreshGlowSettings()
    end)
    self.glowStyleDropdown:SetPoint("TOPLEFT", 16, -104)

    local colorLabel = CreateLabel(raidCard, "Color", 10, C.muted)
    colorLabel:SetPoint("TOPLEFT", 16, -148)
    self.glowColorModeDropdown = self:CreateDropdown(raidCard, 280, {
        { value = "CUSTOM", label = "Custom color" },
        { value = "CLASS", label = "Requester class color" },
    }, function() return NS.db.alerts.glowColorMode end, function(value)
        NS.db.alerts.glowColorMode = value
        UI:ScheduleGlowRefresh()
        UI:RefreshGlowSettings()
    end)
    self.glowColorModeDropdown:SetPoint("TOPLEFT", 16, -164)

    self.glowColorSwatch = self:CreateGlowColorSwatch(raidCard)
    self.glowColorSwatch:SetSize(62, 34)
    self.glowColorSwatch:SetPoint("TOPLEFT", 304, -164)

    local function glowSetter(key, value)
        NS.db.alerts[key] = value
        UI:ScheduleGlowRefresh()
    end

    self.glowSpeedField = self:CreateCompactNumberField(raidCard, "Speed (x)",
        function() return NS.db.alerts.glowSpeed end,
        function(v) glowSetter("glowSpeed", v) end, 0.25, 3, 96, 2)
    self.glowSpeedField:SetPoint("TOPLEFT", 16, -211)

    self.glowPixelLinesField = self:CreateCompactNumberField(raidCard, "Lines",
        function() return NS.db.alerts.glowPixelLines end,
        function(v) glowSetter("glowPixelLines", v) end, 1, 20, 96, 0)
    self.glowPixelLinesField:SetPoint("TOPLEFT", 126, -211)

    self.glowPixelThicknessField = self:CreateCompactNumberField(raidCard, "Thickness",
        function() return NS.db.alerts.glowPixelThickness end,
        function(v) glowSetter("glowPixelThickness", v) end, 1, 8, 96, 1)
    self.glowPixelThicknessField:SetPoint("TOPLEFT", 236, -211)

    self.glowAutoScaleField = self:CreateCompactNumberField(raidCard, "Scale",
        function() return NS.db.alerts.glowAutoCastScale end,
        function(v) glowSetter("glowAutoCastScale", v) end, 0.5, 3, 96, 1)
    self.glowAutoScaleField:SetPoint("TOPLEFT", 126, -211)

    self.alertControls.frameIcon = CreateCheckbox(raidCard, "Show an icon on raidframes",
        function() return NS.db.alerts.frameIcon end,
        function(value) setVisualOption("frameIcon", value, true) end)
    self.alertControls.frameIcon:SetPoint("TOPLEFT", 16, -272)
    self.alertControls.frameIcon:SetPoint("RIGHT", -16, 0)

    self.alertControls.frameIconCooldownSwipe = CreateCheckbox(raidCard, "Show icon cooldown swipe",
        function() return NS.db.alerts.frameIconCooldownSwipe ~= false end,
        function(value) setVisualOption("frameIconCooldownSwipe", value, true) end)
    self.alertControls.frameIconCooldownSwipe:SetPoint("TOPLEFT", 16, -310)
    self.alertControls.frameIconCooldownSwipe:SetPoint("RIGHT", -16, 0)

    local frameIconTypeLabel = CreateLabel(raidCard, "Raidframe icon", 10, C.muted)
    frameIconTypeLabel:SetPoint("TOPLEFT", 16, -348)
    self.frameIconTypeDropdown = self:CreateDropdown(raidCard, 350, {
        { value = "PI", label = "Power Infusion icon" },
        { value = "SPELL", label = "Requester's tracked spell icon" },
    }, function() return NS.db.alerts.frameIconType or "PI" end, function(value)
        NS.db.alerts.frameIconType = value
        if NS.FrameAlerts then NS.FrameAlerts:OnSettingsChanged(false) end
        if NS.Detector then NS.Detector:OnSettingsChanged() end
        UI:RefreshAlertsPage()
    end)
    self.frameIconTypeDropdown:SetPoint("TOPLEFT", 16, -364)

    local timingLabel = CreateLabel(raidCard, "Tracked spell alerts", 10, C.muted)
    timingLabel:SetPoint("TOPLEFT", 16, -408)
    self.spellAlertTimingDropdown = self:CreateDropdown(raidCard, 350, {
        { value = "PI_READY", label = "PI ready only" },
        { value = "ALWAYS_TRACK", label = "Always track" },
    }, function() return NS.db.alerts.spellAlertTiming or "PI_READY" end, function(value)
        NS.db.alerts.spellAlertTiming = value
        if NS.Detector then NS.Detector:OnSettingsChanged() end
        UI:RefreshAlertsPage()
    end)
    self.spellAlertTimingDropdown:SetPoint("TOPLEFT", 16, -424)

    local raidHelp = CreateLabel(raidCard, "Alerts triggered by whispers fall back to the PI icon.", 10, C.muted)
    raidHelp:SetPoint("TOPLEFT", 16, -467)
    raidHelp:SetPoint("RIGHT", -130, 0)
    raidHelp:SetHeight(32)
    raidHelp:SetJustifyV("TOP")
    raidHelp:SetWordWrap(true)

    local test = CreateButton(raidCard, "Test alert", 100, 30, false)
    test:SetPoint("BOTTOMRIGHT", -16, 14)
    test:SetScript("OnClick", function() if NS.RequestManager then NS.RequestManager:TestRequest() end end)

    -- Aura icon settings ------------------------------------------------------
    local auraCard = CreateCard(page, 236, 240)
    auraCard:SetPoint("TOPLEFT", raidCard, "TOPRIGHT", 14, 0)
    self.auraSettingsCard = auraCard
    local auraTitle = CreateLabel(auraCard, "Aura icon settings", 15, C.text)
    auraTitle:SetPoint("TOPLEFT", 16, -14)
    local auraDesc = CreateLabel(auraCard, "Configure the movable PI alert icon.", 10, C.muted)
    auraDesc:SetPoint("TOPLEFT", auraTitle, "BOTTOMLEFT", 0, -4)

    self.alertControls.auraIcon = CreateCheckbox(auraCard, "Enable aura icon",
        function() return NS.db.alerts.auraIcon end,
        function(value) setVisualOption("auraIcon", value, true) end)
    self.alertControls.auraIcon:SetPoint("TOPLEFT", 16, -54)
    self.alertControls.auraIcon:SetPoint("RIGHT", -16, 0)

    self.auraIconSizeField = self:CreateCompactNumberField(auraCard, "Icon size",
        function() return NS.db.auraIcon.size end,
        function(value)
            NS.db.auraIcon.size = value
            if NS.FrameAlerts then NS.FrameAlerts:ApplyAuraIconPosition() end
            if NS.Detector then NS.Detector:OnSettingsChanged() end
        end, 12, 96, 90, 0)
    self.auraIconSizeField:SetPoint("TOPLEFT", 16, -94)

    local auraMoveHelp = CreateLabel(auraCard, "Unlock the icon, drag it into place, then lock it again.", 10, C.muted)
    auraMoveHelp:SetPoint("TOPLEFT", 16, -151)
    auraMoveHelp:SetPoint("RIGHT", -16, 0)
    auraMoveHelp:SetHeight(32)
    auraMoveHelp:SetJustifyV("TOP")
    auraMoveHelp:SetWordWrap(true)

    self.moveAuraButton = CreateButton(auraCard, "Move icon", 110, 30, true)
    self.moveAuraButton:SetPoint("BOTTOMLEFT", 16, 14)
    self.moveAuraButton:SetScript("OnClick", function()
        if NS.FrameAlerts then NS.FrameAlerts:ToggleAuraUnlock() end
    end)
    local resetPos = CreateButton(auraCard, "Reset", 86, 30, false)
    resetPos:SetPoint("LEFT", self.moveAuraButton, "RIGHT", 8, 0)
    resetPos:SetScript("OnClick", function()
        if NS.FrameAlerts then NS.FrameAlerts:ResetAuraIconPosition() end
    end)

    -- Whisper settings --------------------------------------------------------
    local whisperCard = CreateCard(page, 236, 274)
    whisperCard:SetPoint("TOPLEFT", auraCard, "BOTTOMLEFT", 0, -12)
    self.whisperSettingsCard = whisperCard
    local whisperTitle = CreateLabel(whisperCard, "Whisper settings", 15, C.text)
    whisperTitle:SetPoint("TOPLEFT", 16, -14)
    local whisperDesc = CreateLabel(whisperCard, "Sound and PI cooldown behavior for accepted whispers.", 10, C.muted)
    whisperDesc:SetPoint("TOPLEFT", whisperTitle, "BOTTOMLEFT", 0, -4)
    whisperDesc:SetPoint("RIGHT", -16, 0)
    whisperDesc:SetWordWrap(true)

    self.alertControls.sound = CreateCheckbox(whisperCard, "Enable whisper sound",
        function() return NS.db.alerts.sound end,
        function(value) setVisualOption("sound", value, false) end)
    self.alertControls.sound:SetPoint("TOPLEFT", 16, -58)
    self.alertControls.sound:SetPoint("RIGHT", -16, 0)

    local soundLabel = CreateLabel(whisperCard, "Sound file", 10, C.muted)
    soundLabel:SetPoint("TOPLEFT", 16, -92)
    self.soundPicker = self:CreateSoundPicker(whisperCard, 204)
    self.soundPicker:SetPoint("TOPLEFT", 16, -108)

    self.whisperDurationField = self:CreateCompactNumberField(whisperCard, "Alert duration (sec)",
        function() return NS.db.requests.duration end,
        function(v) NS.db.requests.duration = v end, 1, 30, 112, 0)
    self.whisperDurationField:SetPoint("TOPLEFT", 16, -150)

    self.alertControls.whisperOnPICooldown = CreateCheckbox(whisperCard, "Alert during PI cooldown",
        function() return NS.db.alerts.whisperOnPICooldown == true end,
        function(value) NS.db.alerts.whisperOnPICooldown = value and true or false end)
    self.alertControls.whisperOnPICooldown:SetPoint("TOPLEFT", 16, -202)
    self.alertControls.whisperOnPICooldown:SetPoint("RIGHT", -16, 0)

    local whisperCooldownHelp = CreateLabel(whisperCard, "Accept matching whispers and trigger their visual and sound alerts while PI is unavailable.", 10, C.muted)
    whisperCooldownHelp:SetPoint("TOPLEFT", 16, -232)
    whisperCooldownHelp:SetPoint("RIGHT", -16, 0)
    whisperCooldownHelp:SetHeight(38)
    whisperCooldownHelp:SetJustifyV("TOP")
    whisperCooldownHelp:SetWordWrap(true)
end

function UI:RefreshGlowSettings()
    if self.glowStyleDropdown then self.glowStyleDropdown:Refresh() end
    if self.glowColorModeDropdown then self.glowColorModeDropdown:Refresh() end
    if self.glowColorSwatch then self.glowColorSwatch:Refresh() end
    if self.glowSpeedField then self.glowSpeedField:Refresh() end

    local style = NS.db.alerts.glowStyle or "PIXEL"
    local pixel = style == "PIXEL"
    local autocast = style == "AUTOCAST"

    if self.glowPixelLinesField then self.glowPixelLinesField:SetShown(pixel); self.glowPixelLinesField:Refresh() end
    if self.glowPixelThicknessField then self.glowPixelThicknessField:SetShown(pixel); self.glowPixelThicknessField:Refresh() end
    if self.glowAutoScaleField then self.glowAutoScaleField:SetShown(autocast); self.glowAutoScaleField:Refresh() end
end

function UI:CreateSoundPicker(parent, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 350, 34)
    SetBackdrop(button, {0.025, 0.037, 0.050, 1}, C.border)

    local text = CreateLabel(button, "", 12, C.text)
    text:SetPoint("LEFT", 10, 0)
    text:SetPoint("RIGHT", -62, 0)
    button.valueText = text

    local preview = CreateButton(button, ">", 30, 26, false)
    preview:SetPoint("RIGHT", -6, 0)
    preview:SetScript("OnClick", function()
        if NS.Media then NS.Media:Play(NS.db.alerts.soundKey) end
    end)
    button.preview = preview

    function button:Refresh()
        text:SetText(NS.Media and NS.Media:GetSoundDisplayName(NS.db.alerts.soundKey) or "Blizzard - Raid Warning")
    end

    button:SetScript("OnClick", function(self)
        if self._piPopup and self._piPopup:IsShown() then
            self._piPopup:Hide()
            return
        end
        UI:ShowSoundPopup(self)
    end)
    button:Refresh()
    return button
end

function UI:ShowSoundPopup(anchor)
    self:ClosePopups()
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(420, 390)
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    SetBackdrop(popup, {0.025, 0.037, 0.050, 1}, C.border)
    anchor._piPopup = popup
    self:RegisterPopup(popup, anchor)

    local search = CreateEditBox(popup, 392, 34, "Search sounds...")
    search:SetPoint("TOPLEFT", 14, -14)

    popup.rows = {}
    popup.offset = 1
    popup.filtered = {}
    local visibleRows = 9
    for i = 1, visibleRows do
        local row = CreateFrame("Button", nil, popup)
        row:SetPoint("TOPLEFT", 14, -58 - (i - 1) * 33)
        row:SetPoint("TOPRIGHT", -14, -58 - (i - 1) * 33)
        row:SetHeight(31)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, 0)
        row.bg = bg
        local name = CreateLabel(row, "", 11, C.text)
        name:SetPoint("LEFT", 8, 0)
        name:SetPoint("RIGHT", -44, 0)
        row.name = name
        local play = CreateButton(row, ">", 28, 24, false)
        play:SetPoint("RIGHT", -3, 0)
        row.play = play
        row:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, 0.05) end)
        row:SetScript("OnLeave", function() bg:SetColorTexture(1, 1, 1, 0) end)
        popup.rows[i] = row
    end

    local footer = CreateLabel(popup, "", 10, C.muted)
    footer:SetPoint("BOTTOMLEFT", 14, 12)
    popup.footer = footer

    local function refresh()
        popup.filtered = NS.Media and NS.Media:GetSounds(search:GetText()) or {}
        local maxOffset = math.max(1, #popup.filtered - visibleRows + 1)
        popup.offset = math.max(1, math.min(maxOffset, popup.offset or 1))
        for i, row in ipairs(popup.rows) do
            local entry = popup.filtered[popup.offset + i - 1]
            row.entry = entry
            if entry then
                row:Show()
                row.name:SetText(entry.name)
                row.name:SetTextColor(unpack(entry.key == NS.db.alerts.soundKey and C.accent or C.text))
                row:SetScript("OnClick", function()
                    NS.db.alerts.soundKey = entry.key
                    anchor:Refresh()
                    popup:Hide()
                end)
                row.play:SetScript("OnClick", function()
                    if NS.Media then NS.Media:Play(entry.key) end
                end)
            else
                row:Hide()
            end
        end
        if #popup.filtered == 0 then
            footer:SetText("No sounds found")
        else
            local last = math.min(#popup.filtered, popup.offset + visibleRows - 1)
            footer:SetText(string.format("%d-%d of %d  |  Mouse wheel to scroll", popup.offset, last, #popup.filtered))
        end
    end

    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(1, #popup.filtered - visibleRows + 1)
        popup.offset = math.max(1, math.min(maxOffset, popup.offset - delta * 3))
        refresh()
    end)
    search:SetChangeHandler(function() popup.offset = 1; refresh() end)
    refresh()
end

function UI:RefreshAlertsPage()
    if not self.alertControls then return end
    for _, control in pairs(self.alertControls) do control:Refresh() end
    if self.soundPicker then self.soundPicker:Refresh() end
    if self.whisperDurationField then self.whisperDurationField:Refresh() end
    if self.spellAlertTimingDropdown then self.spellAlertTimingDropdown:Refresh() end
    if self.frameIconTypeDropdown then self.frameIconTypeDropdown:Refresh() end
    if self.auraIconSizeField then self.auraIconSizeField:Refresh() end
    self:RefreshGlowSettings()
    if self.moveAuraButton then
        local unlocked = NS.FrameAlerts and NS.FrameAlerts.auraUnlocked
        self.moveAuraButton:SetLabel(unlocked and "Lock icon" or "Move icon")
    end
end

-- -----------------------------------------------------------------------------
-- Modals
-- -----------------------------------------------------------------------------

function UI:ShowModal(titleText, width, height)
    self:ClosePopups()
    if self.modalOverlay then self.modalOverlay:Hide() end

    local overlay = CreateFrame("Frame", nil, self.frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(self.frame:GetFrameLevel() + 80)
    overlay:EnableMouse(true)
    local shade = overlay:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.55)

    local panel = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    panel:SetSize(width or 430, height or 230)
    panel:SetPoint("CENTER")
    SetBackdrop(panel, {0.035, 0.052, 0.070, 1}, C.border)

    local title = CreateLabel(panel, titleText, 17, C.text)
    title:SetPoint("TOPLEFT", 18, -16)

    self.modalOverlay = overlay
    overlay.panel = panel
    overlay:SetScript("OnHide", function() if UI.modalOverlay == overlay then UI.modalOverlay = nil end end)
    return overlay, panel
end

function UI:ShowPhraseDialog()
    local overlay, panel = self:ShowModal("Add whisper phrase", 440, 230)

    local label = CreateLabel(panel, "Phrase", 11, C.muted)
    label:SetPoint("TOPLEFT", 18, -58)
    local modeLabel = CreateLabel(panel, "Match", 11, C.muted)
    modeLabel:SetPoint("TOPLEFT", 288, -58)

    -- Explicit shared Y coordinate keeps EditBox and dropdown pixel-aligned.
    local input = CreateEditBox(panel, 258, 34, "e.g. PI")
    input:SetPoint("TOPLEFT", 18, -82)

    local mode = "CONTAINS"
    local dropdown = self:CreateDropdown(panel, 134, {
        { value = "CONTAINS", label = "Contains" },
        { value = "EXACT", label = "Exact" },
    }, function() return mode end, function(value) mode = value end)
    dropdown:SetPoint("TOPLEFT", 288, -82)

    local cancel = CreateButton(panel, "Cancel", 88, 32, false)
    cancel:SetPoint("BOTTOMRIGHT", -18, 16)
    cancel:SetScript("OnClick", function() overlay:Hide() end)
    local add = CreateButton(panel, "Add phrase", 100, 32, true)
    add:SetPoint("RIGHT", cancel, "LEFT", -8, 0)

    local function commit()
        local text = strtrim(input:GetText() or "")
        if text == "" then return end
        for _, phrase in ipairs(NS.db.requests.phrases) do
            if (phrase.text or ""):lower() == text:lower() and phrase.match == mode then
                overlay:Hide(); return
            end
        end
        NS.db.requests.phrases[#NS.db.requests.phrases + 1] = { text = text, match = mode }
        overlay:Hide()
        UI:RefreshPhraseRows()
    end
    add:SetScript("OnClick", commit)
    input:SetScript("OnEnterPressed", commit)
    C_Timer.After(0, function() input:SetFocus() end)
end

function UI:ShowCustomSpellDialog()
    local overlay, panel = self:ShowModal("Add custom spell", 440, 260)
    local idLabel = CreateLabel(panel, "Spell ID", 11, C.muted)
    idLabel:SetPoint("TOPLEFT", 18, -54)
    local idInput = CreateEditBox(panel, 160, 34, "123456")
    idInput:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -6)
    idInput:SetNumeric(true)

    local nameLabel = CreateLabel(panel, "Name (optional)", 11, C.muted)
    nameLabel:SetPoint("TOPLEFT", 18, -118)
    local nameInput = CreateEditBox(panel, 300, 34, "Detected automatically when possible")
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -6)

    local errorText = CreateLabel(panel, "", 10, C.danger)
    errorText:SetPoint("BOTTOMLEFT", 18, 22)

    local cancel = CreateButton(panel, "Cancel", 88, 32, false)
    cancel:SetPoint("BOTTOMRIGHT", -18, 16)
    cancel:SetScript("OnClick", function() overlay:Hide() end)
    local add = CreateButton(panel, "Add spell", 96, 32, true)
    add:SetPoint("RIGHT", cancel, "LEFT", -8, 0)

    local function commit()
        local id = tonumber(idInput:GetText())
        if not id or id <= 0 then errorText:SetText("Enter a valid spell ID."); return end
        if UI:IsPresetSpellID(id) then errorText:SetText("That spell is already in the preset list."); return end
        for _, spell in ipairs(NS.db.customSpells) do
            if spell.id == id then errorText:SetText("That custom spell is already added."); return end
        end
        local label = strtrim(nameInput:GetText() or "")
        if label == "" then label = NS:GetSpellName(id, "Spell " .. id) end
        NS.db.customSpells[#NS.db.customSpells + 1] = { id = id, label = label }
        NS.db.spells[id] = true
        if NS.Detector then NS.Detector:OnSettingsChanged() end
        overlay:Hide()
        UI:RefreshSpellList()
    end
    add:SetScript("OnClick", commit)
    idInput:SetScript("OnEnterPressed", function() nameInput:SetFocus() end)
    nameInput:SetScript("OnEnterPressed", commit)
    C_Timer.After(0, function() idInput:SetFocus() end)
end

function UI:ShowResetConfirmation()
    local overlay, panel = self:ShowModal("Reset PI Alert?", 400, 190)
    local text = CreateLabel(panel, "This restores every setting, phrase, player, spell and alert option to its default.", 12, C.muted)
    text:SetPoint("TOPLEFT", 18, -58)
    text:SetPoint("RIGHT", -18, 0)
    text:SetWordWrap(true)
    text:SetJustifyV("TOP")

    local cancel = CreateButton(panel, "Cancel", 88, 32, false)
    cancel:SetPoint("BOTTOMRIGHT", -18, 16)
    cancel:SetScript("OnClick", function() overlay:Hide() end)
    local reset = CreateButton(panel, "Reset", 88, 32, true)
    reset:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    reset:SetScript("OnClick", function()
        overlay:Hide()
        NS:ResetDatabase()
    end)
end
