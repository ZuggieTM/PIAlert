local ADDON_NAME, NS = ...

local UnitMenu = {}
NS.UnitMenu = UnitMenu

local MENU_TAGS = {
    "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_RAID",
    "MENU_UNIT_PLAYER",
    "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS",
}

local function ResolveGroupPlayer(contextData)
    if type(contextData) ~= "table" then return nil end

    local unit = contextData.unit
    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        local guid = UnitGUID(unit)
        local groupUnit = guid and NS:FindGroupUnitByGUID(guid) or nil
        if groupUnit and UnitExists(groupUnit) and not UnitIsUnit(groupUnit, "player") then
            return groupUnit
        end
    end

    -- Some unit-popup contexts provide a name but no live unit token. Only
    -- expose PI Alert's entry if that name resolves back to the current group.
    local name = contextData.name
    if name and contextData.server and contextData.server ~= "" then
        name = name .. "-" .. contextData.server
    end
    local groupUnit = name and NS:FindGroupUnitByName(name) or nil
    if groupUnit and UnitExists(groupUnit) and UnitIsPlayer(groupUnit)
        and not UnitIsUnit(groupUnit, "player") then
        return groupUnit
    end

    return nil
end

function UnitMenu:AddEntry(rootDescription, contextData)
    if not NS:IsActive() or not NS.db or not NS.db.requesters then return end

    local unit = ResolveGroupPlayer(contextData)
    if not unit then return end

    local name = UnitName(unit)
    local baseName = NS:DisplayBaseName(name)
    if not baseName or baseName == "" then return end

    rootDescription:QueueDivider()

    local entry = rootDescription:CreateCheckbox(
        "PI Alert requester",
        function()
            return NS:IsSpecificRequester(baseName)
        end,
        function()
            local wasListed = NS:IsSpecificRequester(baseName)
            local changed
            if wasListed then
                changed = NS:RemoveSpecificRequester(baseName)
                if changed then
                    NS:Print("Removed " .. baseName .. " from Specific Players.")
                end
            else
                changed = NS:AddSpecificRequester(baseName)
                if changed then
                    local suffix = ""
                    if NS.db.requesters.mode ~= "SPECIFIC" then
                        suffix = " (Specific Players is not currently selected.)"
                    end
                    NS:Print("Added " .. baseName .. " to Specific Players." .. suffix)
                end
            end
        end
    )

    if entry and entry.SetTitleAndTextTooltip then
        entry:SetTitleAndTextTooltip(
            "PI Alert requester",
            "Add or remove this group member from the Specific Players requester list."
        )
    end
end

function UnitMenu:Init()
    if self.initialized then return end
    self.initialized = true

    if not Menu or type(Menu.ModifyMenu) ~= "function" then
        NS:Debug("Player right-click menu integration unavailable: Menu.ModifyMenu missing.")
        return
    end

    for _, tag in ipairs(MENU_TAGS) do
        Menu.ModifyMenu(tag, function(_, rootDescription, contextData)
            UnitMenu:AddEntry(rootDescription, contextData)
        end)
    end
end
