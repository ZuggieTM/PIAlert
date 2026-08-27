local ADDON_NAME, NS = ...

local Media = {}
NS.Media = Media

local MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local DEFAULT_SOUND_KEY = "addon:pi-request"

Media.addonSounds = {
    {
        key = DEFAULT_SOUND_KEY,
        name = "PI Alert - Infusion",
        path = MEDIA_PATH .. "pi-request.wav",
    },
    {
        key = "addon:pi-single-note",
        name = "PI Alert - Single Note",
        path = MEDIA_PATH .. "pi-pulse.wav",
    },
    {
        key = "addon:pi-arcane-spark",
        name = "PI Alert - Arcane Spark",
        path = MEDIA_PATH .. "pi-arcane-spark.wav",
    },
    {
        key = "addon:pi-radiance",
        name = "PI Alert - Radiance",
        path = MEDIA_PATH .. "pi-radiance.wav",
    },
    {
        key = "addon:pi-voice",
        name = "PI Alert - Voice",
        path = MEDIA_PATH .. "pi-voice.wav",
    },
    {
        key = "addon:pi-voice-soft",
        name = "PI Alert - Soft Voice",
        path = MEDIA_PATH .. "pi-voice-soft.wav",
    },
}

Media.builtinSounds = {
    { key = "builtin:Blizzard - Raid Warning", name = "Blizzard - Raid Warning", kit = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959 },
    { key = "builtin:Blizzard - Ready Check", name = "Blizzard - Ready Check", kit = 8960 },
    { key = "builtin:Blizzard - Tell Message", name = "Blizzard - Tell Message", kit = 3081 },
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

    for _, entry in ipairs(self.addonSounds) do add(entry) end
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
    if type(key) ~= "string" then return "PI Alert - Infusion" end
    if key:sub(1, 6) == "addon:" then
        for _, entry in ipairs(self.addonSounds) do
            if entry.key == key then return entry.name end
        end
        return key:sub(7)
    elseif key:sub(1, 8) == "builtin:" then
        return key:sub(9)
    elseif key:sub(1, 4) == "lsm:" then
        return key:sub(5)
    end
    return key
end

function Media:Play(key)
    key = key or DEFAULT_SOUND_KEY

    if key:sub(1, 6) == "addon:" then
        for _, entry in ipairs(self.addonSounds) do
            if entry.key == key then
                local willPlay = PlaySoundFile(entry.path, "Master")
                if willPlay then return true end
                break
            end
        end
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
        return false
    end

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
