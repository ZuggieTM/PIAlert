local ADDON_NAME, NS = ...

local Glow = {}
NS.Glow = Glow

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local DASH_H = MEDIA .. "secure-dash-h.tga"
local DASH_V = MEDIA .. "secure-dash-v.tga"
local MASK_TEX = "Interface\\Buttons\\WHITE8X8"

local Clamp = NS.Clamp

local function StopPixel(frame)
    local d = frame and frame._pipSecurePixel
    if not d then return end
    for i = 1, 4 do
        if d.groups[i] then d.groups[i]:Stop() end
        if d.strips[i] then d.strips[i]:Hide() end
    end
end

local function StopFlipbook(frame)
    local d = frame and frame._pipSecureFlipbook
    if not d then return end
    if d.group then d.group:Stop() end
    if d.texture then d.texture:Hide() end
end

function Glow:Stop(frame)
    if not frame then return end
    pcall(StopPixel, frame)
    pcall(StopFlipbook, frame)
end

-- Animated glow engine for ordinary self-test request frames. Restricted
-- 12.1 aura buttons use Detector's initialization-frozen native animations.
function Glow:StartPixel(frame, width, height, color, cfg)
    if not frame then return false end

    local lines = math.floor(Clamp(cfg.glowPixelLines, 1, 20, 12) + 0.5)
    local thickness = Clamp(cfg.glowPixelThickness, 1, 8, 2)
    local speed = Clamp(cfg.glowSpeed, 0.25, 3.0, 1.0)
    local period = 4 / speed

    width = tonumber(width) or 100
    height = tonumber(height) or 40
    if width < 1 then width = 100 end
    if height < 1 then height = 40 end

    local perimeter = 2 * (width + height)
    local cycle = perimeter / lines
    if cycle < 1 then cycle = 1 end
    local stepDuration = period / lines

    local r, g, b, a = color[1] or 1, color[2] or 0.82, color[3] or 0.20, color[4] or 1

    local d = frame._pipSecurePixel
    if not d then
        d = { masks = {}, strips = {}, groups = {}, translations = {} }
        frame._pipSecurePixel = d

        for i = 1, 4 do
            local mask = frame:CreateMaskTexture()
            mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

            local strip = frame:CreateTexture(nil, "OVERLAY", nil, 7)
            strip:SetBlendMode("ADD")
            strip:AddMaskTexture(mask)

            local group = strip:CreateAnimationGroup()
            group:SetLooping("REPEAT")
            local translation = group:CreateAnimation("Translation")
            translation:SetSmoothing("NONE")

            d.masks[i] = mask
            d.strips[i] = strip
            d.groups[i] = group
            d.translations[i] = translation
        end
    end

    local edges = {
        { texture = DASH_H, length = width,  dx = cycle,  dy = 0,      vertical = false, phase = 0 },
        { texture = DASH_V, length = height, dx = 0,      dy = -cycle, vertical = true,  phase = width / cycle },
        { texture = DASH_H, length = width,  dx = -cycle, dy = 0,      vertical = false, phase = (width + height) / cycle },
        { texture = DASH_V, length = height, dx = 0,      dy = cycle,  vertical = true,  phase = (width + height + width) / cycle },
    }

    for i = 1, 4 do
        local edge = edges[i]
        local mask = d.masks[i]
        local strip = d.strips[i]
        local group = d.groups[i]
        local translation = d.translations[i]

        group:Stop()
        strip:SetTexture(edge.texture, "REPEAT", "REPEAT")
        strip:SetVertexColor(r, g, b, a)
        mask:ClearAllPoints()
        strip:ClearAllPoints()

        local texCycles = (edge.length + cycle) / cycle
        if not edge.vertical then
            mask:SetSize(edge.length, thickness)
            strip:SetSize(edge.length + cycle, thickness)
            if i == 1 then
                mask:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                strip:SetPoint("TOPLEFT", frame, "TOPLEFT", -cycle, 0)
            else
                mask:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                strip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            end
            strip:SetTexCoord(edge.phase, edge.phase + texCycles, 0, 1)
        else
            mask:SetSize(thickness, edge.length)
            strip:SetSize(thickness, edge.length + cycle)
            if i == 2 then
                mask:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
                strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, cycle)
            else
                mask:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                strip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -cycle)
            end
            strip:SetTexCoord(0, 1, edge.phase, edge.phase + texCycles)
        end

        strip:Show()
        translation:SetOffset(edge.dx, edge.dy)
        translation:SetDuration(stepDuration)
        group:Play()
    end

    frame:Show()
    return true
end

local function StartFlipbook(frame, width, height, color, speed, kind, cfg)
    if not frame then return false end

    local d = frame._pipSecureFlipbook
    if not d then
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        texture:SetBlendMode("ADD")

        local group = texture:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local animation = group:CreateAnimation("FlipBook")

        d = { texture = texture, group = group, animation = animation }
        frame._pipSecureFlipbook = d
    end

    local r, g, b = color[1] or 1, color[2] or 0.82, color[3] or 0.20
    local alpha = color[4] or 1
    local animation = d.animation

    if kind == "BUTTON" then
        d.texture:SetTexture("Interface\\SpellActivationOverlay\\IconAlertAnts")
        d.texture:SetSize(width * 1.25, height * 1.25)
        animation:SetFlipBookRows(5)
        animation:SetFlipBookColumns(5)
        animation:SetFlipBookFrames(22)
        animation:SetFlipBookFrameWidth(48)
        animation:SetFlipBookFrameHeight(48)
        animation:SetDuration(0.30 / speed)
    else
        local scale = Clamp(cfg and cfg.glowAutoCastScale, 0.5, 3.0, 1.0)
        d.texture:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
        d.texture:SetSize(width * 1.40 * scale, height * 1.40 * scale)
        animation:SetFlipBookRows(6)
        animation:SetFlipBookColumns(5)
        animation:SetFlipBookFrames(30)
        animation:SetFlipBookFrameWidth(0)
        animation:SetFlipBookFrameHeight(0)
        animation:SetDuration(1.0 / speed)
    end

    d.texture:SetDesaturated(true)
    d.texture:SetVertexColor(r, g, b, alpha)
    d.texture:Show()

    if d.group:IsPlaying() then d.group:Stop() end
    d.group:Play()
    frame:Show()
    return true
end

function Glow:Start(frame, width, height, color, cfg)
    cfg = cfg or {}
    color = color or { 1, 0.82, 0.20, 1 }
    width = tonumber(width) or 100
    height = tonumber(height) or 40
    local speed = Clamp(cfg.glowSpeed, 0.25, 3.0, 1.0)

    self:Stop(frame)

    local style = cfg.glowStyle or "PIXEL"
    if style == "BUTTON" then
        return StartFlipbook(frame, width, height, color, speed, "BUTTON", cfg)
    elseif style == "AUTOCAST" then
        -- AutoCast uses the native proc flipbook on ordinary request frames.
        return StartFlipbook(frame, width, height, color, speed, "AUTOCAST", cfg)
    end

    return self:StartPixel(frame, width, height, color, cfg)
end
