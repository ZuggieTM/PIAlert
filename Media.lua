local ADDON_NAME, NS = ...

local Media = {}
NS.Media = Media

Media.builtinSounds = {
    { key = "builtin:Blizzard - Raid Warning", name = "Blizzard - Raid Warning", kit = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, fileID = 567397 },
    { key = "builtin:Blizzard - Ready Check", name = "Blizzard - Ready Check", kit = 8960, fileID = 567478 },
    { key = "builtin:Blizzard - Tell Message", name = "Blizzard - Tell Message", kit = 3081, fileID = 567421 },
}

function Media:Init()
    self.lastLSM = nil
    self.soundCache = nil
end

function Media:GetLSM()
    if _G.LibStub and type(_G.LibStub.GetLibrary) == "function" then
        local ok, lib = pcall(_G.LibStub.GetLibrary, _G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lib then
            if self.lastLSM ~= lib then
                self.lastLSM = lib
                self.soundCache = nil
            end
            return lib
        end
    end
    return self.lastLSM
end

function Media:BuildSoundCache()
    local results = {}
    local seen = {}

    local function add(entry)
        if not entry or not entry.key or not entry.name or seen[entry.key] then return end
        seen[entry.key] = true
        results[#results + 1] = entry
    end

    for _, entry in ipairs(self.builtinSounds) do add(entry) end

    local lsm = self:GetLSM()
    if lsm and lsm.List then
        local ok, list = pcall(lsm.List, lsm, "sound")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                add({ key = "lsm:" .. name, name = name, lsmName = name })
            end
        end
    end

    table.sort(results, function(a, b)
        local al, bl = a.name:lower(), b.name:lower()
        if al == bl then return a.key < b.key end
        return al < bl
    end)

    self.soundCache = results
    return results
end

function Media:GetSounds(search)
    -- Calling GetLSM first also notices a library that loaded after PI Alert.
    self:GetLSM()
    local source = self.soundCache or self:BuildSoundCache()
    local query = search and strtrim(search):lower() or ""
    if query == "" then return source end

    local filtered = {}
    for _, entry in ipairs(source) do
        if entry.name:lower():find(query, 1, true) then filtered[#filtered + 1] = entry end
    end
    return filtered
end

function Media:GetSoundDisplayName(key)
    if type(key) ~= "string" then return "Blizzard - Raid Warning" end
    if key:sub(1, 8) == "builtin:" then
        return key:sub(9)
    elseif key:sub(1, 4) == "lsm:" then
        return key:sub(5)
    end
    return key
end

function Media:Play(key)
    key = key or "builtin:Blizzard - Raid Warning"

    if key:sub(1, 8) == "builtin:" then
        for _, entry in ipairs(self.builtinSounds) do
            if entry.key == key then
                PlaySound(entry.kit, "Master")
                return true
            end
        end
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
        return true
    end

    if key:sub(1, 4) == "lsm:" then
        local name = key:sub(5)
        local lsm = self:GetLSM()
        if lsm and lsm.Fetch then
            local ok, path = pcall(lsm.Fetch, lsm, "sound", name, true)
            if ok and path then
                PlaySoundFile(path, "Master")
                return true
            end
        end
    end

    PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    return false
end


function Media:GetAuraSoundInfo(key, unit, spellID)
    key = key or "builtin:Blizzard - Raid Warning"
    local info = {
        unitToken = unit,
        spellID = tonumber(spellID),
        outputChannel = "Master",
    }

    if key:sub(1, 8) == "builtin:" then
        for _, entry in ipairs(self.builtinSounds) do
            if entry.key == key and entry.fileID then
                info.soundFileID = entry.fileID
                return info
            end
        end
        info.soundFileID = 567397
        return info
    end

    if key:sub(1, 4) == "lsm:" then
        local name = key:sub(5)
        local lsm = self:GetLSM()
        if lsm and lsm.Fetch then
            local ok, sound = pcall(lsm.Fetch, lsm, "sound", name, true)
            if ok and sound then
                if type(sound) == "number" then
                    info.soundFileID = sound
                elseif type(sound) == "string" and sound ~= "" then
                    info.soundFileName = sound
                end
                if info.soundFileID or info.soundFileName then return info end
            end
        end
    end

    info.soundFileID = 567397
    return info
end

local function AuraSoundChangesRestricted()
    if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true then
        return true
    end

    if C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function" then
        local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and restricted == true then return true end
    end

    return false
end

function Media:RegisterAuraSound(unit, spellID, key)
    if not C_UnitAuras or type(C_UnitAuras.AddAuraSound) ~= "function" then
        NS:Debug("Blizzard's allied aura sound API is unavailable on this client.")
        return nil
    end
    if type(unit) ~= "string" or not tonumber(spellID) then return nil end
    if AuraSoundChangesRestricted() then
        NS:Debug("Deferred allied aura sound registration while aura changes are restricted.")
        return nil
    end

    local info = self:GetAuraSoundInfo(key, unit, spellID)
    local trigger = 0
    if Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added ~= nil then
        trigger = Enum.UnitAuraSoundTrigger.Added
    end

    -- Patch 12.1 renamed AddAuraAppliedSound to AddAuraSound. Unlike the normal
    -- PlaySound/PlaySoundFile path used by manual/whisper alerts, the protected
    -- aura API uses the standard sound-channel token.
    local ok, auraSoundID = pcall(C_UnitAuras.AddAuraSound, trigger, info)
    if ok and auraSoundID ~= nil then
        NS:Debug("Registered allied aura sound for " .. tostring(unit) .. " / " .. tostring(spellID) .. " (ID " .. tostring(auraSoundID) .. ").")
        return auraSoundID
    end

    NS:Debug("Aura sound registration failed for " .. tostring(unit) .. " / " .. tostring(spellID) .. ": " .. tostring(auraSoundID))
    return nil
end

function Media:UnregisterAuraSound(handle)
    if not handle then return true end
    if not C_UnitAuras or type(C_UnitAuras.RemoveAuraSound) ~= "function" then return false end
    if AuraSoundChangesRestricted() then
        NS:Debug("Deferred allied aura sound removal while aura changes are restricted.")
        return false
    end

    -- Accept the table-shaped handles from 1.0.23 as well as current raw IDs so
    -- a /reload during development cannot strand an old registration.
    local auraSoundID = type(handle) == "table" and handle.id or handle
    if auraSoundID then
        local ok, err = pcall(C_UnitAuras.RemoveAuraSound, auraSoundID)
        if not ok then
            NS:Debug("Aura sound removal failed for ID " .. tostring(auraSoundID) .. ": " .. tostring(err))
        end
        return ok
    end
    return true
end
