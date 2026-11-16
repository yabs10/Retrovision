-- Retrovision: extra effects. Bezel, grain, VHS (tracking, noise strip, OSD),
-- TV power on/off, channel change, low-health static, hit flicker, preset toast.
local ADDON, ns = ...
local MEDIA = ns.MEDIA
local f = ns.frame
local scr, cover = ns.scr, ns.cover
local rand = math.random

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

---------------------------------------------------------------- bezel (on the overlay, so it follows the layer setting)

local bez = { edges = {}, corners = {}, shadows = {} }
for i = 1, 4 do
    local e = f:CreateTexture(nil, "OVERLAY", nil, 5); e:SetColorTexture(0, 0, 0, 1); bez.edges[i] = e
    local c = f:CreateTexture(nil, "OVERLAY", nil, 6); c:SetTexture(MEDIA .. "corner"); bez.corners[i] = c
    local s = f:CreateTexture(nil, "OVERLAY", nil, 4); s:SetColorTexture(1, 1, 1, 1); bez.shadows[i] = s
end
-- corner texcoords: TL, TR, BL, BR
local CORNER_TC = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }
local CORNER_PT = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local CORNER_OFF = { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } }

-- Monitor skins: one sliced frame image + a button strip with a glowing LED.
local mon = CreateFrame("Frame", nil, cover)
local monTex = mon:CreateTexture(nil, "ARTWORK")
monTex:SetAllPoints()
local STRETCHED = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
local monButtons = mon:CreateTexture(nil, "ARTWORK", nil, 1)
monButtons:SetSize(256, 64)
monButtons:SetPoint("BOTTOMRIGHT", mon, "BOTTOMRIGHT", -64, 20)
local led = mon:CreateTexture(nil, "ARTWORK", nil, 2)
led:SetTexture(MEDIA .. "glowdot"); led:SetBlendMode("ADD"); led:SetSize(26, 26)
led:SetPoint("CENTER", monButtons, "TOPLEFT", 228, -32)
local anim -- power animation { t, on, done, fired, safe }
-- LED: amber while the tube warms up, green once the picture is up
local function ledColor()
    if anim and anim.on then led:SetVertexColor(1, 0.62, 0.12) else led:SetVertexColor(0.3, 1, 0.4) end
end
ledColor()
local ART_SIDE, ART_TOP, ART_BOT = 68, 68, 116     -- plastic + glass ring, in art pixels

-- pillarbox bars for 4:3 + faint screen light spilling on the "wall"
local barL = cover:CreateTexture(nil, "BACKGROUND"); barL:SetColorTexture(0.035, 0.03, 0.045, 1)
local barR = cover:CreateTexture(nil, "BACKGROUND"); barR:SetColorTexture(0.035, 0.03, 0.045, 1)
barL:SetPoint("TOPLEFT", f, "TOPLEFT"); barL:SetPoint("BOTTOMRIGHT", scr, "BOTTOMLEFT")
barR:SetPoint("TOPRIGHT", f, "TOPRIGHT"); barR:SetPoint("BOTTOMLEFT", scr, "BOTTOMRIGHT")
local spill = cover:CreateTexture(nil, "BORDER"); spill:SetTexture(MEDIA .. "glowdot"); spill:SetBlendMode("ADD")
spill:SetPoint("CENTER", scr, "CENTER"); spill:SetVertexColor(0.55, 0.65, 0.9)

ns.inset = { l = 0, r = 0, t = 0, b = 0 }   -- how much of the picture the frame covers (f units)

-- The visible glass = scr minus the frame. Size in f units and in physical pixels.
local function glassSize()
    local ins = ns.inset
    return math.max(1, scr:GetWidth() - ins.l - ins.r), math.max(1, scr:GetHeight() - ins.t - ins.b)
end
local function glassPixels()
    local w, h = glassSize()
    local u = ns.Unit()
    return w / u, h / u
end
local function toGlass(t)
    local ins = ns.inset
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", scr, "TOPLEFT", ins.l, -ins.t)
    t:SetPoint("BOTTOMRIGHT", scr, "BOTTOMRIGHT", -ins.r, ins.b)
end
-- full-width strip inside the glass, y down from the glass top
local function glassRow(t, y)
    local ins = ns.inset
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", scr, "TOPLEFT", ins.l, -ins.t - y)
    t:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -ins.r, -ins.t - y)
end

local function layoutBezel(S)
    local u = ns.Unit()
    local plain = S.bezel and S.bezelStyle == "plain"
    local skin = S.bezel and (S.bezelStyle == "beige" or S.bezelStyle == "black")
    local pillar = S.aspect == "4:3"
    barL:SetShown(pillar); barR:SetShown(pillar)
    spill:SetShown(pillar); spill:SetAlpha(0.07)
    spill:SetSize(scr:GetWidth() * 1.5, scr:GetHeight() * 1.25)

    for i = 1, 4 do bez.edges[i]:SetShown(plain); bez.corners[i]:SetShown(plain); bez.shadows[i]:SetShown(S.bezel) end
    mon:SetShown(skin)
    local ins = ns.inset
    ins.l, ins.r, ins.t, ins.b = 0, 0, 0, 0
    if not S.bezel then return end

    local T, R
    local SW = (24 + 60 * S.bezelShadow) * u
    local a = S.bezelShadow * 0.75
    if skin then
        local k = S.monitorSize * f:GetHeight() / 1100
        mon:SetScale(k)
        mon:ClearAllPoints(); mon:SetPoint("CENTER", scr, "CENTER")
        mon:SetSize(scr:GetWidth() / k, scr:GetHeight() / k)
        monTex:SetTexture(MEDIA .. "frame_" .. S.bezelStyle)
        monTex:SetTextureSliceMargins(96, 96, 96, 144)
        monTex:SetTextureSliceMode(STRETCHED)
        monButtons:SetTexture(MEDIA .. "buttons_" .. S.bezelStyle)
        led:SetAlpha(S.bezelStyle == "black" and 0.8 or 0.6)
        ledColor()
        ins.l, ins.r, ins.t, ins.b = ART_SIDE * k, ART_SIDE * k, ART_TOP * k, ART_BOT * k
    else
        T = S.bezelThickness * u
        R = S.bezelRadius * u
        ins.l, ins.r, ins.t, ins.b = T, T, T, T
        local top, bot, left, right = bez.edges[1], bez.edges[2], bez.edges[3], bez.edges[4]
        top:ClearAllPoints(); top:SetPoint("TOPLEFT", scr); top:SetPoint("TOPRIGHT", scr); top:SetHeight(math.max(T, 0.01))
        bot:ClearAllPoints(); bot:SetPoint("BOTTOMLEFT", scr); bot:SetPoint("BOTTOMRIGHT", scr); bot:SetHeight(math.max(T, 0.01))
        left:ClearAllPoints(); left:SetPoint("TOPLEFT", scr); left:SetPoint("BOTTOMLEFT", scr); left:SetWidth(math.max(T, 0.01))
        right:ClearAllPoints(); right:SetPoint("TOPRIGHT", scr); right:SetPoint("BOTTOMRIGHT", scr); right:SetWidth(math.max(T, 0.01))
        for i = 1, 4 do bez.edges[i]:SetShown(T > 0.5 * u) end
        for i = 1, 4 do
            local c = bez.corners[i]
            c:ClearAllPoints()
            c:SetPoint(CORNER_PT[i], scr, CORNER_PT[i], CORNER_OFF[i][1] * T, CORNER_OFF[i][2] * T)
            c:SetSize(math.max(R, 0.01), math.max(R, 0.01))
            c:SetTexCoord(unpack(CORNER_TC[i]))
            c:SetShown(R > 0.5 * u)
        end
    end

    -- inner shadow just inside whatever frame is showing (glass is recessed)
    local clear, dark = CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, a)
    local st, sb, sl, sr = bez.shadows[1], bez.shadows[2], bez.shadows[3], bez.shadows[4]
    st:ClearAllPoints(); st:SetPoint("TOPLEFT", scr, "TOPLEFT", ins.l, -ins.t); st:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -ins.r, -ins.t); st:SetHeight(SW)
    st:SetGradient("VERTICAL", clear, dark)
    sb:ClearAllPoints(); sb:SetPoint("BOTTOMLEFT", scr, "BOTTOMLEFT", ins.l, ins.b); sb:SetPoint("BOTTOMRIGHT", scr, "BOTTOMRIGHT", -ins.r, ins.b); sb:SetHeight(SW)
    sb:SetGradient("VERTICAL", dark, clear)
    sl:ClearAllPoints(); sl:SetPoint("TOPLEFT", scr, "TOPLEFT", ins.l, -ins.t); sl:SetPoint("BOTTOMLEFT", scr, "BOTTOMLEFT", ins.l, ins.b); sl:SetWidth(SW)
    sl:SetGradient("HORIZONTAL", dark, clear)
    sr:ClearAllPoints(); sr:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -ins.r, -ins.t); sr:SetPoint("BOTTOMRIGHT", scr, "BOTTOMRIGHT", -ins.r, ins.b); sr:SetWidth(SW)
    sr:SetGradient("HORIZONTAL", clear, dark)
    for i = 1, 4 do bez.shadows[i]:SetShown(a > 0.01) end
end

---------------------------------------------------------------- glass glare, LCD viewing angle + backlight bleed, degauss

local glare = f:CreateTexture(nil, "OVERLAY", nil, 3)
glare:SetTexture(MEDIA .. "glare"); glare:SetBlendMode("ADD")
local angle = f:CreateTexture(nil, "ARTWORK", nil, 4); angle:SetColorTexture(1, 1, 1, 1)
local bleed = {}
for i = 1, 5 do
    local t = f:CreateTexture(nil, "ARTWORK", nil, 5)
    t:SetTexture(MEDIA .. "glowdot"); t:SetBlendMode("ADD"); t:SetVertexColor(0.75, 0.82, 1)
    bleed[i] = t
end
-- bleed spots along the panel edges: {anchor, x frac, y frac, w frac, h frac}
local BLEED = { { "TOPLEFT", 0.10, 0.0, 0.35, 0.10 }, { "TOPRIGHT", -0.18, 0.0, 0.30, 0.08 },
    { "BOTTOMLEFT", 0.22, 0.0, 0.40, 0.12 }, { "BOTTOMRIGHT", -0.06, 0.0, 0.25, 0.10 }, { "LEFT", 0.0, 0.1, 0.06, 0.4 } }

local rainbow = {}
for i = 1, 3 do
    local t = f:CreateTexture(nil, "OVERLAY", nil, 2)
    t:SetTexture(MEDIA .. "rainbow", "REPEAT", "REPEAT"); t:SetBlendMode("ADD"); t:Hide()
    rainbow[i] = t
end
local degaussT

function ns.Degauss()
    if not (ns.S and ns.S.enabled) then return end
    degaussT = 0
end

local function layoutPicture(S)
    local ins = ns.inset
    local inner = toGlass
    if ns.vig then inner(ns.vig) end
    glare:SetShown(S.glare); inner(glare); glare:SetAlpha(S.glareStrength * 0.22)
    angle:SetShown(S.viewAngle)
    if S.viewAngle then
        angle:ClearAllPoints()
        angle:SetPoint("TOPLEFT", scr, "TOPLEFT", ins.l, -ins.t); angle:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -ins.r, -ins.t)
        angle:SetHeight((scr:GetHeight() - ins.t - ins.b) * 0.45)
        angle:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0.02, 0.02, 0.05, 0.28))
    end
    local w, h = glassSize()
    for i, t in ipairs(bleed) do
        local b = BLEED[i]
        t:SetShown(S.backlightBleed)
        t:ClearAllPoints()
        local sx = b[1]:find("RIGHT") and -ins.r or ins.l
        local sy = b[1]:find("TOP") and -ins.t or (b[1]:find("BOTTOM") and ins.b or 0)
        t:SetPoint("CENTER", scr, b[1], sx + b[2] * w, sy + b[3] * h)
        t:SetSize(b[4] * w, b[5] * h * 2)
        t:SetAlpha(0.07)
    end
    for _, t in ipairs(rainbow) do inner(t) end
end

---------------------------------------------------------------- grain + low-health static (overlay)

local grain = f:CreateTexture(nil, "OVERLAY", nil, 2)
local lhStatic = f:CreateTexture(nil, "OVERLAY", nil, 3)

-- random noise offset, px screen pixels per texel (sized to the glass, or the whole screen)
local function noiseShift(t, px, full)
    local w, h
    if full then w, h = ns.ScreenPixels() else w, h = glassPixels() end
    local ox, oy = rand(), rand()
    t:SetTexCoord(ox, ox + w / (128 * px), oy, oy + h / (128 * px))
end
grain:SetTexture(MEDIA .. "noise", "REPEAT", "REPEAT", "NEAREST")      -- sparse, neutral grain
lhStatic:SetTexture(MEDIA .. "static", "REPEAT", "REPEAT", "NEAREST") -- dense snow

---------------------------------------------------------------- VHS: tracking bars + bottom noise strip (overlay)

local bars = {}
for i = 1, 5 do
    local b = f:CreateTexture(nil, "OVERLAY", nil, 1)
    b:SetTexture(MEDIA .. "static", "REPEAT", "REPEAT", "NEAREST")
    b:Hide()
    bars[i] = { tex = b, life = 0, y = 0, h = 0 }
end
local tear = f:CreateTexture(nil, "OVERLAY", nil, 1)
tear:SetColorTexture(1, 1, 1, 1); tear:Hide()
local tearLife = 0

local strip = f:CreateTexture(nil, "OVERLAY", nil, 1)
strip:SetTexture(MEDIA .. "static", "REPEAT", "REPEAT", "NEAREST")
local stripLine = f:CreateTexture(nil, "OVERLAY", nil, 1)
stripLine:SetColorTexture(1, 1, 1, 1)
stripLine:SetPoint("BOTTOMLEFT", strip, "TOPLEFT"); stripLine:SetPoint("BOTTOMRIGHT", strip, "TOPRIGHT")

-- noise texcoords for a bar: 2 screen pixels per texel across the glass
local function barCoords(t)
    local w = glassPixels()
    local ox, oy = rand(), rand()
    t:SetTexCoord(ox, ox + w / 256, oy, oy + 0.05)
end

local function spawnBar()
    for _, b in ipairs(bars) do
        if b.life <= 0 then
            local _, gh = glassSize()
            local u = ns.Unit()
            b.life = 0.06 + rand() * 0.2
            b.h = (2 + rand() * 12) * u
            b.y = rand() * math.max(0, gh - b.h)
            b.speed = (rand() - 0.3) * gh * 0.4
            b.tex:SetHeight(b.h)
            b.tex:SetAlpha(0.2 + rand() * 0.4)
            glassRow(b.tex, b.y)
            barCoords(b.tex)
            b.tex:Show()
            return
        end
    end
end

---------------------------------------------------------------- top layer: power + channel effects (over everything)

-- On UIParent: anything on WorldFrame is drawn under the UI, and the power animation must cover it all.
local top = CreateFrame("Frame", "RetrovisionFX", UIParent)
top:SetAllPoints(WorldFrame)
top:SetFrameStrata("FULLSCREEN_DIALOG"); top:SetFrameLevel(9500)
top:EnableMouse(false)
top:SetIgnoreParentAlpha(true)

local black = top:CreateTexture(nil, "BACKGROUND"); black:SetAllPoints(); black:SetColorTexture(0, 0, 0, 1)
local curtT = top:CreateTexture(nil, "BACKGROUND", nil, 1); curtT:SetColorTexture(0, 0, 0, 1)
curtT:SetPoint("TOPLEFT", scr); curtT:SetPoint("TOPRIGHT", scr)
local curtB = top:CreateTexture(nil, "BACKGROUND", nil, 1); curtB:SetColorTexture(0, 0, 0, 1)
curtB:SetPoint("BOTTOMLEFT", scr); curtB:SetPoint("BOTTOMRIGHT", scr)
local white = top:CreateTexture(nil, "ARTWORK"); white:SetColorTexture(0.92, 0.97, 1, 1); white:SetPoint("CENTER", scr)
local glow = top:CreateTexture(nil, "OVERLAY"); glow:SetTexture(MEDIA .. "glowdot"); glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", scr); glow:SetVertexColor(0.75, 0.9, 1)
-- picture size in the top frame's units
local function scrSize()
    local k = scr:GetEffectiveScale() / top:GetEffectiveScale()
    return scr:GetWidth() * k, scr:GetHeight() * k, ns.Unit() * f:GetEffectiveScale() / top:GetEffectiveScale()
end
local topStatic = top:CreateTexture(nil, "BORDER"); topStatic:SetAllPoints()
topStatic:SetTexture(MEDIA .. "static", "REPEAT", "REPEAT", "NEAREST")

local function hideTop()
    black:Hide(); curtT:Hide(); curtB:Hide(); white:Hide(); glow:Hide(); topStatic:Hide()
end
hideTop()

-- Screen squeezed to a horizontal gap (frac of height), gap washed toward white.
local function drawGap(frac, whiteA)
    local w, h, u = scrSize()
    local gap = math.max(2 * u, h * frac)
    local cur = (h - gap) / 2
    black:Hide()
    curtT:SetHeight(math.max(cur, 0.01)); curtB:SetHeight(math.max(cur, 0.01))
    curtT:SetShown(cur > 0.5); curtB:SetShown(cur > 0.5)
    white:SetSize(w, gap); white:SetAlpha(whiteA); white:Show()
    glow:Hide()
end
-- Black screen with a bright line of width frac, plus a glowing dot.
local function drawLine(frac, glowA)
    local w, _, u = scrSize()
    curtT:Hide(); curtB:Hide(); black:Show()
    white:SetSize(math.max(1 * u, w * frac), 2 * u); white:SetAlpha(1); white:SetShown(frac > 0.002)
    glow:SetSize(60 * u + w * frac * 0.3, 40 * u); glow:SetAlpha(glowA); glow:Show()
end

-- run the pending "done" callback once
local function fireDone(a)
    if a and a.done and not a.fired then a.fired = true; a.done() end
end
local function endAnim()
    local a = anim
    black:SetAlpha(1); hideTop(); anim = nil
    ledColor()
    fireDone(a)
end

function ns.PowerAnim(on, done)
    -- a new animation never drops the old one's callback (e.g. "now turn the overlay off")
    while anim and anim.done and not anim.fired do fireDone(anim) end
    anim = { t = 0, on = on, done = done, safe = ns.S and ns.S.safe }
    ledColor()
    top:Show()
end

function ns.PowerBusy() return anim ~= nil end

local function stepPower(dt)
    if not anim then return end
    anim.t = anim.t + dt
    local t = anim.t
    if anim.safe then
        -- flashing safety: plain fade through black, no white line or dot
        curtT:Hide(); curtB:Hide(); white:Hide(); glow:Hide(); black:Show()
        if anim.on then
            if t < 0.9 then black:SetAlpha(1 - t / 0.9) else endAnim() end
        else
            if t < 0.4 then black:SetAlpha(t / 0.4)
            elseif t < 0.8 then fireDone(anim); black:SetAlpha(1 - (t - 0.4) / 0.4)
            else endAnim() end
        end
        return
    end
    if anim.on then
        if t < 0.10 then drawLine(0, t / 0.10)
        elseif t < 0.22 then drawLine((t - 0.10) / 0.12, 1)
        elseif t < 0.50 then local p = (t - 0.22) / 0.28; drawGap(p * p, 1 - p)
        elseif t < 1.40 then
            -- tube warming up: picture starts dim and comes up to full brightness
            curtT:Hide(); curtB:Hide(); white:Hide(); glow:Hide()
            black:Show(); black:SetAlpha(0.6 * (1 - (t - 0.50) / 0.90) ^ 1.5)
        else endAnim() end
    else
        if t < 0.16 then local p = t / 0.16; drawGap(1 - p * (2 - p), p)
        elseif t < 0.32 then drawLine(1 - (t - 0.16) / 0.16, 1)
        elseif t < 1.00 then
            -- the bright dot lingers and fades slowly, like phosphor afterglow
            local p = (t - 0.32) / 0.68
            drawLine(0, (1 - p) ^ 2)
            local _, _, u = scrSize()
            glow:SetSize((60 - 40 * p) * u, (40 - 25 * p) * u)
        elseif t < 1.30 then
            fireDone(anim)
            black:Show(); black:SetAlpha(1 - (t - 1.00) / 0.30); white:Hide(); glow:Hide()
        else endAnim() end   -- also fires done if a long frame skipped the step above
    end
end

---------------------------------------------------------------- monitor-style on-screen menu (brightness bars etc.)

local mo = CreateFrame("Frame", nil, UIParent)
mo:SetFrameStrata("FULLSCREEN"); mo:SetSize(380, 74); mo:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
mo:EnableMouse(false); mo:Hide()
local moBg = mo:CreateTexture(nil, "BACKGROUND"); moBg:SetAllPoints(); moBg:SetColorTexture(0.06, 0.07, 0.22, 0.88)
local moEdge = mo:CreateTexture(nil, "BORDER"); moEdge:SetPoint("TOPLEFT", 3, -3); moEdge:SetPoint("BOTTOMRIGHT", -3, 3)
moEdge:SetColorTexture(0.55, 0.6, 0.9, 0.25)
local moIn = mo:CreateTexture(nil, "BORDER", nil, 1); moIn:SetPoint("TOPLEFT", 4, -4); moIn:SetPoint("BOTTOMRIGHT", -4, 4)
moIn:SetColorTexture(0.06, 0.07, 0.22, 1)
local moLabel = mo:CreateFontString(nil, "OVERLAY"); moLabel:SetFont(STANDARD_TEXT_FONT, 15, "")
moLabel:SetPoint("TOPLEFT", 16, -12); moLabel:SetTextColor(0.92, 0.94, 1)
local moVal = mo:CreateFontString(nil, "OVERLAY"); moVal:SetFont(STANDARD_TEXT_FONT, 15, "")
moVal:SetPoint("TOPRIGHT", -16, -12); moVal:SetTextColor(0.92, 0.94, 1)
local moSeg = {}
for i = 1, 24 do
    local t = mo:CreateTexture(nil, "ARTWORK")
    t:SetSize(11, 18); t:SetPoint("BOTTOMLEFT", 16 + (i - 1) * 14.5, 14)
    moSeg[i] = t
end
local moLife = 0

function ns.MonitorOSD(label, frac, valueText)
    local font = ns.FONT or STANDARD_TEXT_FONT
    moLabel:SetFont(font, 15, ""); moVal:SetFont(font, 15, "")
    moLabel:SetText(label:upper()); moVal:SetText(valueText or "")
    local n = math.floor(frac * #moSeg + 0.5)
    for i, t in ipairs(moSeg) do
        if i <= n then t:SetColorTexture(0.85, 0.9, 1, 1) else t:SetColorTexture(0.25, 0.28, 0.5, 0.6) end
    end
    mo:Show(); mo:SetAlpha(1); moLife = 1.8
end

local function stepMonOSD(dt)
    if moLife <= 0 then return end
    moLife = moLife - dt
    mo:SetAlpha(math.min(1, moLife / 0.4))
    if moLife <= 0 then mo:Hide() end
end

---------------------------------------------------------------- OSD (VCR text) + channel number + preset toast

-- VCR text: on WorldFrame in "game world" mode (under the UI, survives Alt+Z),
-- on UIParent in "everything" mode so it shows over the UI like the overlay (see ns.ApplyFX).
local osd = CreateFrame("Frame", "RetrovisionOSD", WorldFrame)
osd:SetAllPoints(WorldFrame)
osd:SetFrameStrata("HIGH"); osd:SetFrameLevel(1)
osd:EnableMouse(false)
-- the preset toast is UI feedback, so it stays on UIParent
local toastFrame = CreateFrame("Frame", nil, UIParent)
toastFrame:SetAllPoints(UIParent)
toastFrame:SetFrameStrata("HIGH"); toastFrame:SetFrameLevel(1)
toastFrame:EnableMouse(false)

local function osdText(size, r, g, b, parent)
    local fs = (parent or osd):CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.FONT or STANDARD_TEXT_FONT, size, "")
    fs:SetTextColor(r, g, b, 1)
    fs:SetShadowColor(0, 0, 0, 0.9); fs:SetShadowOffset(2, -2)
    return fs
end

local osdMain = osdText(26, 0.95, 0.97, 1)
local osdIcon = osd:CreateTexture(nil, "OVERLAY")
local osdClock = osdText(18, 0.95, 0.97, 1)
local chText = osdText(40, 0.35, 1, 0.45)
local toast = osdText(22, 1, 0.31, 0.85, toastFrame)
toast:SetPoint("TOP", toastFrame, "TOP", 0, -120)
toast:SetShadowColor(1, 0.18, 0.66, 0.6); toast:SetShadowOffset(0, 0)
chText:Hide(); toast:Hide()
local chLife, toastLife = 0, 0

-- Corner offsets inside the visible picture (past any frame), in OSD units.
local function osdOffsets()
    local k = f:GetEffectiveScale() / osd:GetEffectiveScale()
    local ins = ns.inset
    local padX, padY = scr:GetWidth() * 0.045, scr:GetHeight() * 0.06
    return (ins.l + padX) * k, (ins.r + padX) * k, (ins.t + padY) * k, (ins.b + padY) * k
end
ns.osdOffsets = osdOffsets

local function placeOSD(S)
    local l, r, t, b = osdOffsets()
    osdMain:ClearAllPoints(); osdClock:ClearAllPoints(); osdIcon:ClearAllPoints(); chText:ClearAllPoints()
    if S.osdCorner == "tr" then
        osdMain:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -r - 34, -t)
        osdClock:SetPoint("TOPRIGHT", osdMain, "BOTTOMRIGHT", 34, -6)
        chText:SetPoint("TOPLEFT", scr, "TOPLEFT", l, -t)
    elseif S.osdCorner == "bl" then
        osdMain:SetPoint("BOTTOMLEFT", scr, "BOTTOMLEFT", l, b + 30)
        osdClock:SetPoint("TOPLEFT", osdMain, "BOTTOMLEFT", 0, -6)
        chText:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -r, -t)
    else
        osdMain:SetPoint("TOPLEFT", scr, "TOPLEFT", l, -t)
        osdClock:SetPoint("TOPLEFT", osdMain, "BOTTOMLEFT", 0, -6)
        chText:SetPoint("TOPRIGHT", scr, "TOPRIGHT", -r, -t)
    end
    osdIcon:SetPoint("LEFT", osdMain, "RIGHT", 8, 0)
end

local function clockText()
    return date("%p %I:%M:%S"):gsub(" 0", " ") .. "   " .. date("%b. %d %Y"):upper()
end

local function updateOSD(S, blink)
    local mode = S.enabled and S.osd or "none"
    osdMain:SetShown(mode == "play" or mode == "rec")
    osdIcon:SetShown(mode == "play" or mode == "rec")
    osdClock:SetShown(mode == "rec" or mode == "clock")
    if mode == "play" then
        osdMain:SetText("PLAY")
        osdIcon:SetTexture(MEDIA .. "play"); osdIcon:SetVertexColor(0.95, 0.97, 1); osdIcon:SetSize(24, 24)
        osdIcon:SetAlpha(1)
    elseif mode == "rec" then
        osdMain:SetText("REC")
        osdIcon:SetTexture(MEDIA .. "dot"); osdIcon:SetVertexColor(1, 0.15, 0.2); osdIcon:SetSize(18, 18)
        osdIcon:SetAlpha(blink and 1 or 0)
    end
    if mode == "clock" then
        osdClock:ClearAllPoints()
        local l, r, t, b = osdOffsets()
        local pt = S.osdCorner == "tr" and "TOPRIGHT" or S.osdCorner == "bl" and "BOTTOMLEFT" or "TOPLEFT"
        local x = pt == "TOPRIGHT" and -r or l
        local y = pt == "BOTTOMLEFT" and b or -t
        osdClock:SetPoint(pt, scr, pt, x, y)
    end
    if osdClock:IsShown() then osdClock:SetText(clockText()) end
end

function ns.Toast(msg)
    toast:SetText(msg); toast:Show(); toast:SetAlpha(1); toastLife = 1.6
end

local lastZone, lastCh = nil, 0
local function channelChange(force)
    local S = ns.S
    if not force and not (S and S.enabled and S.channelFx) then return end
    if not force and InCombatLockdown and InCombatLockdown() then return end
    local zone = GetRealZoneText and GetRealZoneText() or ""
    if not force and zone == lastZone and GetTime() - lastCh < 3 then return end
    lastZone, lastCh = zone, GetTime()
    local n = 0
    for i = 1, #zone do n = (n * 31 + zone:byte(i)) % 98 end
    chText:SetText(string.format("CH %02d", n + 2))
    chText:Show(); chText:SetAlpha(1); chLife = 2.5
    if not (S and S.safe) then ns.staticBurst = 1 end   -- no full-screen flash in safe mode
end

ns.ChannelFlash = channelChange

---------------------------------------------------------------- low health + hit flicker

local hpLevel, lastHp = 0, nil
ns.hitBurst, ns.staticBurst = 0, 0

local function readHealth()
    local ok, cur, max = pcall(function()
        local c, m = UnitHealth("player"), UnitHealthMax("player")
        if issecretvalue and (issecretvalue(c) or issecretvalue(m)) then return nil end
        return c + 0, m + 0
    end)
    if ok and cur and max and max > 0 then return cur, max end
end

local function onHealth()
    local S = ns.S
    if not S then return end
    local cur, max = readHealth()
    if not cur or UnitIsDeadOrGhost("player") then hpLevel = 0; lastHp = nil; return end
    local ratio = cur / max
    hpLevel = S.lowHealth and clamp((0.5 - ratio) / 0.4, 0, 1) * S.lowHealthStrength or 0
    if S.hitFx and lastHp and (lastHp - cur) / max >= 0.08 then
        ns.hitBurst = 1
        spawnBar(); spawnBar()
    end
    lastHp = cur
end

---------------------------------------------------------------- apply + tick

local grainClock, osdClockT, blink = 0, 0, true

function ns.ApplyFX(S)
    ns.FONT = ns.FONT or STANDARD_TEXT_FONT
    -- keep WorldFrame-parented text/effects the same size as UI-parented ones
    local ws = WorldFrame:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale() / ((ws and ws > 0) and ws or 1)
    local osdParent = S.layer == "all" and UIParent or WorldFrame
    if osd:GetParent() ~= osdParent then
        osd:SetParent(osdParent); osd:ClearAllPoints(); osd:SetAllPoints(WorldFrame)
        osd:SetFrameStrata("HIGH"); osd:SetFrameLevel(1)
    end
    osd:SetScale(osdParent == UIParent and 1 or us)
    layoutBezel(S)
    layoutPicture(S)
    toGlass(grain); toGlass(lhStatic)
    grain:SetShown(S.grain)
    if S.grain then noiseShift(grain, 2); grain:SetAlpha(S.grainStrength * 0.14) end
    strip:SetShown(S.noiseStrip); stripLine:SetShown(S.noiseStrip)
    local ins = ns.inset
    strip:ClearAllPoints()
    strip:SetPoint("BOTTOMLEFT", scr, "BOTTOMLEFT", ins.l, ins.b); strip:SetPoint("BOTTOMRIGHT", scr, "BOTTOMRIGHT", -ins.r, ins.b)
    if S.noiseStrip then
        strip:SetAlpha(0.55); stripLine:SetAlpha(0.18)
        stripLine:SetHeight(2 * ns.Unit())
    end
    if not S.tracking then for _, b in ipairs(bars) do b.life = 0; b.tex:Hide() end; tear:Hide() end
    for _, fs in ipairs({ osdMain, osdClock, chText, toast }) do
        local _, size = fs:GetFont(); fs:SetFont(ns.FONT, size or 20, "")
    end
    placeOSD(S)
    updateOSD(S, true)
    onHealth()
end

ns.OnTick(function(dt, S)
    stepPower(dt)
    stepMonOSD(dt)

    if degaussT then
        degaussT = degaussT + dt
        local t = degaussT
        local env = math.exp(-2.6 * t) * math.abs(math.sin(t * 14))
        for i, r in ipairs(rainbow) do
            r:Show()
            local ph = t * (0.9 + i * 0.35) + i * 0.33
            local sx = 0.6 + 0.4 * math.sin(t * 9 + i)
            r:SetTexCoord(ph, ph + sx, 0, 1)
            r:SetAlpha(env * 0.22)
        end
        if S.scan and f:IsShown() then ns.ShakeScan(math.floor(env * 3 * math.sin(t * 40) + 0.5)) end
        if t > 2.2 then degaussT = nil; for _, r in ipairs(rainbow) do r:Hide() end; ns.ShakeScan(0) end
    end

    -- top-layer static (channel change)
    if S.safe then ns.staticBurst, ns.hitBurst = 0, 0; topStatic:Hide() end   -- no flashes in safe mode
    if ns.staticBurst > 0 then
        ns.staticBurst = math.max(0, ns.staticBurst - dt / 0.4)
        top:Show(); topStatic:Show(); noiseShift(topStatic, 2, true)
        topStatic:SetAlpha(ns.staticBurst * 0.9)
        if ns.staticBurst == 0 then topStatic:Hide() end
    end
    if chLife > 0 then
        chLife = chLife - dt
        chText:SetAlpha(clamp(chLife / 0.6, 0, 1))
        if chLife <= 0 then chText:Hide() end
    end
    if toastLife > 0 then
        toastLife = toastLife - dt
        toast:SetAlpha(clamp(toastLife / 0.5, 0, 1))
        if toastLife <= 0 then toast:Hide() end
    end

    osdClockT = osdClockT + dt
    if osdClockT >= 0.5 then osdClockT = 0; blink = not blink; updateOSD(S, blink) end

    if not (S.enabled and f:IsShown()) then return end

    grainClock = grainClock + dt
    local step = grainClock >= 1 / 24
    if step then grainClock = 0 end

    if S.grain and step then noiseShift(grain, 2) end

    if S.noiseStrip and step then
        local _, gh = glassSize()
        strip:SetHeight(gh * (0.022 + rand() * 0.008))
        local w = glassPixels()
        local ox, oy = rand(), rand()
        strip:SetTexCoord(ox, ox + w / 256, oy, oy + 0.15)
    end

    -- tracking glitches (also driven by low health)
    local rate = (S.tracking and S.trackingRate * 3 or 0) + hpLevel * 4
    if rate > 0 and rand() < rate * dt then spawnBar() end
    if rate > 0 and tearLife <= 0 and rand() < rate * 0.3 * dt then
        tearLife = 0.05 + rand() * 0.08
        tear:SetHeight((1 + rand()) * ns.Unit()); tear:SetAlpha(0.15 + rand() * 0.25)
        local _, gh = glassSize()
        glassRow(tear, rand() * gh); tear:Show()
    end
    if tearLife > 0 then tearLife = tearLife - dt; if tearLife <= 0 then tear:Hide() end end
    for _, b in ipairs(bars) do
        if b.life > 0 then
            b.life = b.life - dt
            local _, gh = glassSize()
            b.y = clamp(b.y + b.speed * dt, 0, math.max(0, gh - b.h))   -- stays on the glass
            glassRow(b.tex, b.y)
            if step then barCoords(b.tex) end
            if b.life <= 0 then b.tex:Hide() end
        end
    end

    -- low-health static + hit flicker
    if ns.hitBurst > 0 then ns.hitBurst = math.max(0, ns.hitBurst - dt / 0.22) end
    local lh = math.max(hpLevel * (0.10 + 0.08 * rand()), ns.hitBurst * 0.45)
    lhStatic:SetShown(lh > 0.005)
    if lh > 0.005 then lhStatic:SetAlpha(lh); if step then noiseShift(lhStatic, 2) end end
end)

---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterUnitEvent("UNIT_HEALTH", "player")
ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
ev:SetScript("OnEvent", function(_, e, a1, a2)
    if not RetrovisionDB then return end
    if e == "UNIT_HEALTH" or e == "UNIT_MAXHEALTH" then onHealth(); return end
    if e == "PLAYER_ENTERING_WORLD" then
        lastHp = nil
        if a1 and RetrovisionDB.enabled and RetrovisionDB.powerFx and ns.S and ns.S.enabled then
            ns.PowerAnim(true)            -- fresh login: TV switching on
        else
            channelChange()
        end
    else
        channelChange()
    end
end)
