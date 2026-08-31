local ADDON_NAME, NS = ...

local RM = {}
NS.RequestManager = RM

local max = math.max
local TEST_ALERT_DURATION = 5

function RM:Init()
    self.active = {}
    self.serial = 0
end

function RM:NextSerial()
    self.serial = (self.serial or 0) + 1
    return self.serial
end

function RM:MakeKey(guid, name)
    return guid or ("name:" .. (NS:NormalizeName(name) or tostring(name)))
end

function RM:ScheduleExpiry(request)
    request.expirySerial = self:NextSerial()
    local serial = request.expirySerial
    local delay = max(0.05, (request.expiresAt or GetTime()) - GetTime())
    C_Timer.After(delay, function()
        local current = RM.active[request.key]
        if current and current.expirySerial == serial and GetTime() >= (current.expiresAt or 0) - 0.02 then
            RM:Expire(request.key, "duration")
        end
    end)
end

function RM:Activate(request)
    local now = GetTime()
    local key = request.key
    local wasActive = self.active[key] ~= nil
    request.requestedAt = now
    request.expiresAt = now + TEST_ALERT_DURATION
    self.active[key] = request
    self:ScheduleExpiry(request)

    if NS.FrameAlerts then NS.FrameAlerts:ActivateRequest(request, wasActive) end
    NS:Debug("Activated PI request from " .. tostring(request.name))
end

function RM:Expire(key, reason)
    local request = self.active[key]
    if not request then return end
    self.active[key] = nil
    if NS.FrameAlerts then NS.FrameAlerts:DeactivateRequest(request) end
    NS:Debug("Expired PI request from " .. tostring(request.name) .. " (" .. tostring(reason or "timeout") .. ")")
end

function RM:ClearAll(reason)
    if not self.active then return end
    for key, request in pairs(self.active) do
        self.active[key] = nil
        if NS.FrameAlerts then NS.FrameAlerts:DeactivateRequest(request) end
    end
    if NS.FrameAlerts then NS.FrameAlerts:ClearAll() end
    NS:Debug("Cleared all requests: " .. tostring(reason or "unknown"))
end

function RM:GetActiveCount()
    local count = 0
    for _ in pairs(self.active or {}) do count = count + 1 end
    return count
end

function RM:GetActiveRequests()
    return self.active
end

function RM:ReconcileRoster()
    if not self.active then return end
    local removeActive = {}
    for key, request in pairs(self.active) do
        local unit = request.guid and NS:FindGroupUnitByGUID(request.guid) or NS:FindGroupUnitByName(request.name)
        if unit then
            request.unit = unit
        else
            removeActive[#removeActive + 1] = key
        end
    end
    for _, key in ipairs(removeActive) do self:Expire(key, "left group") end

end

function RM:TestRequest()
    local unit
    NS:ForEachGroupUnit(function(candidate)
        if not unit and not UnitIsUnit(candidate, "player") then unit = candidate end
    end, false)
    unit = unit or "player"

    local name = UnitName(unit) or "Test Player"
    local guid = UnitGUID(unit) or "PIAlert-Test"
    local request = {
        key = self:MakeKey(guid, name),
        guid = guid,
        name = NS:DisplayBaseName(name),
        unit = unit,
        source = "TEST",
        requestedAt = GetTime(),
    }
    self:Activate(request)
    NS:Print("Test request shown for " .. request.name .. ".")
end
