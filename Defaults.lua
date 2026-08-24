local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.PI_SPELL_ID = 10060
NS.DB_SCHEMA = 1
NS.SETTINGS_REVISION = 6

NS.CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
    "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

NS.CLASS_NAMES = {
    DEATHKNIGHT = "Death Knight",
    DEMONHUNTER = "Demon Hunter",
    DRUID = "Druid",
    EVOKER = "Evoker",
    HUNTER = "Hunter",
    MAGE = "Mage",
    MONK = "Monk",
    PALADIN = "Paladin",
    PRIEST = "Priest",
    ROGUE = "Rogue",
    SHAMAN = "Shaman",
    WARLOCK = "Warlock",
    WARRIOR = "Warrior",
}

-- This is intentionally a curated starter list rather than a spec tree. The UI resolves
-- the live spell name/icon by ID where possible, and users can add any missing spell ID.
NS.PRESET_SPELLS = {
    DEATHKNIGHT = {
        { id = 51271,  label = "Pillar of Frost" },
        { id = 47568,  label = "Empower Rune Weapon" },
        { id = 42650,  label = "Army of the Dead" },
        { id = 275699, label = "Apocalypse" },
        { id = 49206,  label = "Summon Gargoyle" },
    },
    DEMONHUNTER = {
        { id = 191427,  label = "Metamorphosis", auraIds = { 162264 } },
        { id = 1217605, label = "Void Metamorphosis", auraIds = { 1217607 } },
    },
    DRUID = {
        { id = 194223, label = "Celestial Alignment" },
        { id = 102560, label = "Incarnation: Chosen of Elune" },
        { id = 106951, label = "Berserk" },
        { id = 102543, label = "Incarnation: Avatar of Ashamane" },
        { id = 391528, label = "Convoke the Spirits" },
    },
    EVOKER = {
        { id = 375087, label = "Dragonrage" },
    },
    HUNTER = {
        { id = 19574,  label = "Bestial Wrath" },
        { id = 359844, label = "Call of the Wild" },
        { id = 266779, label = "Coordinated Assault" },
        { id = 288613, label = "Trueshot" },
    },
    MAGE = {
        -- The cast is 365350; the player buff is 365362.
        { id = 365350, label = "Arcane Surge", auraIds = { 365350, 365362 } },
        { id = 190319, label = "Combustion" },
        { id = 12472,  label = "Icy Veins" },
    },
    MONK = {
        { id = 123904, label = "Invoke Xuen, the White Tiger" },
        { id = 152173, label = "Serenity" },
    },
    PALADIN = {
        { id = 31884,  label = "Avenging Wrath" },
        { id = 231895, label = "Crusade" },
    },
    PRIEST = {
        { id = 228260, label = "Void Eruption / Voidform", auraIds = { 194249 } },
        { id = 391109, label = "Dark Ascension" },
    },
    ROGUE = {
        { id = 13750,  label = "Adrenaline Rush" },
        { id = 360194, label = "Deathmark" },
        { id = 121471, label = "Shadow Blades", auraIds = { 121471 } },
    },
    SHAMAN = {
        -- Ascendance has separate cast/aura IDs by specialization in 12.1.
        { id = 114050, label = "Ascendance", auraIds = { 114050, 114051, 114052, 1219480 } },
        { id = 114051, label = "Ascendance (Enhancement)", auraIds = { 114050, 114051, 114052, 1219480 } },
        { id = 198067, label = "Fire Elemental" },
        { id = 192249, label = "Storm Elemental" },
        { id = 51533,  label = "Feral Spirit" },
        { id = 384352, label = "Doom Winds" },
    },
    WARLOCK = {
        { id = 205180, label = "Summon Darkglare" },
        { id = 1122,   label = "Summon Infernal" },
        { id = 265187, label = "Summon Demonic Tyrant" },
    },
    WARRIOR = {
        { id = 107574, label = "Avatar" },
        { id = 1719,   label = "Recklessness" },
    },
}

local enabledSpells = {}
for _, classToken in ipairs(NS.CLASS_ORDER) do
    for _, spell in ipairs(NS.PRESET_SPELLS[classToken] or {}) do
        enabledSpells[spell.id] = true
    end
end

NS.DEFAULTS = {
    schema = NS.DB_SCHEMA,
    settingsRevision = NS.SETTINGS_REVISION,

    requests = {
        mode = "BOTH", -- BOTH, WHISPER, SPELL
        duration = 5,
        phrases = {
            { text = "PI", match = "CONTAINS" },
        },
    },

    requesters = {
        mode = "EVERYONE", -- EVERYONE, FOCUS, SPECIFIC
        fallback = "NONE", -- NONE, FOCUS, EVERYONE; used only when SPECIFIC has no listed players present
        players = {},
    },

    spells = enabledSpells,
    customSpells = {},

    alerts = {
        glow = true,
        frameIcon = true,
        auraIcon = true,
        sound = true,
        soundKey = "builtin:Blizzard - Raid Warning",
        soundCooldown = 2,

        -- Whisper alerts use AnimationGroups. Secure allied spell alerts use an
        -- unrestricted external driver for their restricted visual textures.
        glowStyle = "PIXEL", -- PIXEL, AUTOCAST, BUTTON
        glowColorMode = "CUSTOM", -- CUSTOM, CLASS
        glowColor = { 1.00, 0.82, 0.20, 1.00 },
        glowSpeed = 1.0,
        glowPixelLines = 12,
        glowPixelThickness = 2,
        glowAutoCastScale = 1.0,
    },

    auraIcon = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -120,
        size = 52,
    },

    ui = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        page = "Requests",
        spellCollapsed = {},
    },

    debug = false,
}
