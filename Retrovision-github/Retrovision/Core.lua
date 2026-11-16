-- Retrovision: a CRT look built from plain UI textures drawn over the game.
local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\Retrovision\\media\\"
ns.MEDIA = MEDIA

---------------------------------------------------------------- settings

ns.defaults = {
    enabled = true,
    layer = "world",        -- "world" = under the UI, "all" = over everything
    -- look
    scan = true,  scanStrength = 0.35, scanPeriod = 2,
    mask = false, maskLevel = 1, maskType = "stripe", maskSize = 1,
    interlace = false, refresh = 0,
    vignette = true, vignetteStrength = 0.6,
    flicker = false, flickerStrength = 0.3,
    roll = false, rollStrength = 0.3, rollSpeed = 8,
    tint = "none", tintStrength = 0.3,
    grain = false, grainStrength = 0.3,
    bezel = false, bezelThickness = 12, bezelRadius = 48, bezelShadow = 0.5,
    tracking = false, trackingRate = 0.35,
    noiseStrip = false,
    osd = "none", osdCorner = "tl",
    -- monitor
    aspect = "full", bezelStyle = "plain", monitorSize = 1,
    glare = false, glareStrength = 0.4,
    brightness = 1, blackLevel = 0,
    viewAngle = false, backlightBleed = false,
    -- behaviour
    powerFx = true, channelFx = false,
    lowHealth = false, lowHealthStrength = 0.6, hitFx = false,
    safe = false,           -- flashing safety: no flicker/strobe/shake effects
    intensity = 1,          -- overall strength: scales every effect strength at once (not part of a look)
    dbVersion = 3,
    auto = { combat = "none", raid = "none", dungeon = "none", pvp = "none", resting = "none" },
    presets = {},
    minimap = { hide = false, minimapPos = 200 },
}

-- Keys a preset / share string carries (the "look").
ns.LOOK_KEYS = {
    "scan", "scanStrength", "scanPeriod", "mask", "maskLevel", "vignette", "vignetteStrength",
    "flicker", "flickerStrength", "roll", "rollStrength", "rollSpeed", "tint", "tintStrength",
    "grain", "grainStrength", "bezel", "bezelThickness", "bezelRadius", "bezelShadow",
    "tracking", "trackingRate", "noiseStrip", "osd", "osdCorner",
    "maskType", "maskSize", "interlace", "refresh", "aspect", "bezelStyle", "monitorSize",
    "glare", "glareStrength", "brightness", "blackLevel", "viewAngle", "backlightBleed",
}
ns.STRENGTH_KEYS = { "scanStrength", "vignetteStrength", "flickerStrength", "rollStrength",
    "tintStrength", "grainStrength", "bezelShadow", "glareStrength", "blackLevel" }

ns.ranges = {
    intensity = { 0.25, 1.5 },
    scanStrength = { 0.05, 1 }, scanPeriod = { 2, 6 }, maskLevel = { 1, 3 },
    vignetteStrength = { 0.05, 1 }, flickerStrength = { 0.05, 1 }, rollStrength = { 0.05, 1 },
    rollSpeed = { 2, 20 }, tintStrength = { 0.05, 1 }, grainStrength = { 0.05, 1 },
    bezelThickness = { 0, 80 }, bezelRadius = { 0, 160 }, bezelShadow = { 0, 1 },
    trackingRate = { 0.05, 1 }, lowHealthStrength = { 0.05, 1 },
    maskSize = { 1, 2 }, refresh = { 0, 85 }, monitorSize = { 0.5, 1.6 },
    glareStrength = { 0.05, 1 }, brightness = { 0.4, 1 }, blackLevel = { 0, 1 },
}
ns.enums = {
    tint = { "none", "amber", "green", "warm", "cool", "lcd" },
    maskType = { "stripe", "dot", "lcd", "grid" },
    aspect = { "full", "4:3" },
    bezelStyle = { "plain", "beige", "black" },
    osd = { "none", "play", "rec", "clock" },
    osdCorner = { "tl", "tr", "bl" },
    layer = { "world", "all" },
}

ns.tints = {
    none  = { 1, 1, 1 },
    amber = { 1.0, 0.78, 0.45 },
    green = { 0.55, 1.0, 0.6 },
    warm  = { 1.0, 0.9, 0.78 },
    cool  = { 0.8, 0.9, 1.0 },
    lcd   = { 0.70, 0.80, 0.26 },   -- old handheld green screen
}

-- Built-in looks. Anything not listed falls back to "off"/defaults via ns.PresetBase.
ns.PresetBase = {
    scan = false, mask = false, vignette = false, flicker = false, roll = false, tint = "none",
    grain = false, bezel = false, tracking = false, noiseStrip = false, osd = "none",
    maskType = "stripe", maskSize = 1, interlace = false, refresh = 0, aspect = "full", bezelStyle = "plain",
    monitorSize = 1, glare = false, brightness = 1, blackLevel = 0, viewAngle = false, backlightBleed = false,
}
ns.builtinPresets = {
    { name = "Subtle", desc = "Light scanlines and soft dark edges", v = { scan = true, scanStrength = 0.2, scanPeriod = 2, vignette = true, vignetteStrength = 0.4 } },
    { name = "80s TV", desc = "Warm living-room set with a hum bar", v = { scan = true, scanStrength = 0.4, scanPeriod = 2, mask = true, maskLevel = 1,
        vignette = true, vignetteStrength = 0.7, flicker = true, flickerStrength = 0.3,
        roll = true, rollStrength = 0.25, rollSpeed = 10, tint = "warm", tintStrength = 0.3,
        grain = true, grainStrength = 0.2, bezel = true, bezelThickness = 22, bezelRadius = 70, bezelShadow = 0.6 } },
    { name = "Arcade", desc = "Thick lines, strong mask, rounded glass", v = { scan = true, scanStrength = 0.55, scanPeriod = 4, mask = true, maskLevel = 2,
        vignette = true, vignetteStrength = 0.5, bezel = true, bezelThickness = 0, bezelRadius = 30, bezelShadow = 0.4 } },
    { name = "Studio CRT", desc = "Sharp, cool broadcast monitor", v = { scan = true, scanStrength = 0.25, scanPeriod = 2, mask = true, maskLevel = 3,
        vignette = true, vignetteStrength = 0.3, tint = "cool", tintStrength = 0.2,
        bezel = true, bezelThickness = 0, bezelRadius = 20, bezelShadow = 0.3 } },
    { name = "Amber", desc = "Glowing amber terminal", v = { scan = true, scanStrength = 0.5, scanPeriod = 2, vignette = true, vignetteStrength = 0.7,
        flicker = true, flickerStrength = 0.4, tint = "amber", tintStrength = 0.9,
        grain = true, grainStrength = 0.15, bezel = true, bezelThickness = 10, bezelRadius = 50, bezelShadow = 0.5 } },
    { name = "Green", desc = "Glowing green-screen terminal", v = { scan = true, scanStrength = 0.5, scanPeriod = 2, vignette = true, vignetteStrength = 0.7,
        flicker = true, flickerStrength = 0.4, tint = "green", tintStrength = 0.9,
        grain = true, grainStrength = 0.15, bezel = true, bezelThickness = 10, bezelRadius = 50, bezelShadow = 0.5 } },
    { name = "VHS", desc = "Worn tape: grain, glitches, PLAY", v = { scan = true, scanStrength = 0.3, scanPeriod = 2, vignette = true, vignetteStrength = 0.5,
        roll = true, rollStrength = 0.2, rollSpeed = 7, tint = "warm", tintStrength = 0.25,
        grain = true, grainStrength = 0.5, tracking = true, trackingRate = 0.5, noiseStrip = true, osd = "play" } },
    { name = "2004 CRT", desc = "Beige PC monitor, 4:3, 75 Hz", v = { aspect = "4:3", bezel = true, bezelStyle = "beige", monitorSize = 1, bezelShadow = 0.5,
        scan = true, scanStrength = 0.18, scanPeriod = 2, mask = true, maskType = "dot", maskSize = 1, maskLevel = 2,
        refresh = 75, glare = true, glareStrength = 0.35, vignette = true, vignetteStrength = 0.45,
        tint = "cool", tintStrength = 0.2, brightness = 1, blackLevel = 0.2 } },
    { name = "Gaming CRT", desc = "Black gaming monitor, 85 Hz", v = { aspect = "4:3", bezel = true, bezelStyle = "black", monitorSize = 0.85, bezelShadow = 0.4,
        scan = true, scanStrength = 0.22, scanPeriod = 2, mask = true, maskType = "stripe", maskSize = 1, maskLevel = 2,
        refresh = 85, glare = true, glareStrength = 0.25, vignette = true, vignetteStrength = 0.35, blackLevel = 0.12 } },
    { name = "Early LCD", desc = "First flat panel, washed-out blacks", v = { aspect = "4:3", bezel = true, bezelStyle = "black", monitorSize = 0.7, bezelShadow = 0.15,
        mask = true, maskType = "lcd", maskSize = 1, maskLevel = 1, viewAngle = true, backlightBleed = true,
        blackLevel = 0.5, brightness = 1, tint = "cool", tintStrength = 0.12 } },
    { name = "Handheld", desc = "Pocket console with a pixel grid", v = { aspect = "4:3", bezel = true, bezelStyle = "plain", bezelThickness = 34, bezelRadius = 14,
        bezelShadow = 0.7, mask = true, maskType = "grid", maskSize = 2, maskLevel = 3, tint = "lcd", tintStrength = 1,
        blackLevel = 0.7, brightness = 0.9, vignette = true, vignetteStrength = 0.25 } },
}

-- Scanline periods we have textures for: period -> tile height (scanN.tga).
ns.SCAN_H = { [2] = 8, [3] = 3, [4] = 8, [6] = 6 }
-- Nearest allowed period (for imports / old saves).
function ns.SnapPeriod(v)
    v = tonumber(v) or 2
    local best, bd = 2, math.huge
    for _, p in ipairs({ 2, 3, 4, 6 }) do
        if math.abs(v - p) < bd then best, bd = p, math.abs(v - p) end
    end
    return best
end

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}; for k, v in pairs(t) do c[k] = copy(v) end; return c
end
ns.copy = copy

function ns.FillDefaults()
    for k, v in pairs(ns.defaults) do
        if RetrovisionDB[k] == nil then RetrovisionDB[k] = copy(v)
        elseif type(v) == "table" and type(RetrovisionDB[k]) == "table" and k ~= "presets" then
            for a, b in pairs(v) do if RetrovisionDB[k][a] == nil then RetrovisionDB[k][a] = b end end
        end
    end
end

-- Find a preset by name: custom ones first, then built-in.
function ns.GetPreset(name)
    if not name then return end
    local custom = RetrovisionDB.presets[name]
    if custom then return custom, true end
    for _, p in ipairs(ns.builtinPresets) do if p.name == name then return p.v, false end end
end

-- "Everything off" look: defaults with ns.PresetBase on top.
function ns.LookBaseline()
    local out = {}
    for _, k in ipairs(ns.LOOK_KEYS) do out[k] = ns.defaults[k] end
    for k, val in pairs(ns.PresetBase) do out[k] = val end
    return out
end

-- Full look table for a preset. Built-ins only list what they turn on, and
-- presets saved by older versions miss newer keys, so both start from the baseline.
function ns.PresetValues(name)
    local v = ns.GetPreset(name)
    if not v then return end
    local out = ns.LookBaseline()
    for _, k in ipairs(ns.LOOK_KEYS) do if v[k] ~= nil then out[k] = v[k] end end
    return out
end

function ns.ApplyPreset(name)
    local v = ns.PresetValues(name)
    if not v then return false end
    for _, k in ipairs(ns.LOOK_KEYS) do if v[k] ~= nil then RetrovisionDB[k] = v[k] end end
    RetrovisionDB.activePreset = name
    ns.Apply(); if ns.Refresh then ns.Refresh() end
    return true
end

-- Returns true, or false + a short reason.
function ns.SavePreset(name)
    name = name and name:match("^%s*(.-)%s*$")
    if not name or name == "" then return false, "type a name first" end
    for _, p in ipairs(ns.builtinPresets) do
        if p.name:lower() == name:lower() then return false, "that name belongs to a built-in look" end
    end
    local v = {}
    for _, k in ipairs(ns.LOOK_KEYS) do v[k] = RetrovisionDB[k] end
    RetrovisionDB.presets[name] = v
    RetrovisionDB.activePreset = name
    return true
end

function ns.DeletePreset(name)
    if RetrovisionDB.presets[name] then
        RetrovisionDB.presets[name] = nil
        if RetrovisionDB.activePreset == name then RetrovisionDB.activePreset = nil end
        for ctx, rule in pairs(RetrovisionDB.auto) do
            if rule == "preset:" .. name then RetrovisionDB.auto[ctx] = "none" end
        end
        return true
    end
end

-- All preset names in display order (built-in, then custom A-Z).
function ns.PresetNames()
    local out = {}
    for _, p in ipairs(ns.builtinPresets) do out[#out + 1] = p.name end
    local builtin, custom = {}, {}
    for _, p in ipairs(ns.builtinPresets) do builtin[p.name] = true end
    for n in pairs(RetrovisionDB.presets) do if not builtin[n] then custom[#custom + 1] = n end end
    table.sort(custom)
    for _, n in ipairs(custom) do out[#out + 1] = n end
    return out
end

-- Called when the user edits any look setting by hand.
function ns.Touched() RetrovisionDB.activePreset = nil end

---------------------------------------------------------------- effective settings (auto rules on top)

-- S = what's actually drawn: base settings, then the active auto rule.
function ns.Resolve()
    local db = RetrovisionDB
    local S = setmetatable({}, { __index = db })
    local rule, ctx = "none", nil
    if ns.ActiveRule then rule, ctx = ns.ActiveRule() end
    if rule == "off" then
        S.enabled = false
    elseif rule == "dim" then
        for _, k in ipairs(ns.STRENGTH_KEYS) do S[k] = db[k] * 0.5 end
    elseif type(rule) == "string" and rule:sub(1, 7) == "preset:" then
        local v = ns.PresetValues(rule:sub(8))
        if v then for _, k in ipairs(ns.LOOK_KEYS) do if v[k] ~= nil then S[k] = v[k] end end end
    end
    -- overall strength on top of whatever look is showing
    local k = tonumber(db.intensity) or 1
    if math.abs(k - 1) > 0.001 then
        for _, key in ipairs(ns.STRENGTH_KEYS) do S[key] = math.max(0, math.min(1, (S[key] or 0) * k)) end
    end
    if db.safe then
        -- flashing safety: drop everything that strobes, flashes or shakes
        S.flicker, S.refresh, S.interlace, S.tracking = false, 0, false, false
        S.hitFx, S.lowHealth, S.channelFx, S.roll = false, false, false, false
    end
    ns.ruleNow, ns.ctxNow = rule, ctx
    ns.S = S
    return S
end

---------------------------------------------------------------- overlay

local f = CreateFrame("Frame", "RetrovisionOverlay", WorldFrame)
f:SetAllPoints(WorldFrame)
f:EnableMouse(false)
f:Hide()
ns.frame = f

-- The visible "picture": whole window, or a centred 4:3 area (pillarbox).
local scr = CreateFrame("Frame", nil, f)
scr:SetPoint("CENTER")
scr:SetAllPoints(f)
ns.scr = scr
-- Above the picture: pillarbox bars + monitor frame live on this.
local cover = CreateFrame("Frame", nil, f)
cover:SetAllPoints(f)
cover:SetIgnoreParentAlpha(true)   -- side bars / monitor stay put during a SoftApply dip
ns.cover = cover

local function tex(layer, sub)
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetAllPoints(f)
    return t
end

local tint  = tex("BACKGROUND", 0)
local mask  = tex("BACKGROUND", 1)
local scan  = tex("ARTWORK", 0)
local band  = f:CreateTexture(nil, "ARTWORK", nil, 1)
local vig   = tex("OVERLAY", 0)
vig:ClearAllPoints(); vig:SetAllPoints(scr)   -- first anchor only; FX.lua re-anchors it to the glass
ns.vig = vig
local dimmer = tex("ARTWORK", 2)      -- brightness (black, alpha)
local lift   = tex("ARTWORK", 3)      -- black level (ADD grey)
dimmer:SetColorTexture(0, 0, 0, 1)
lift:SetColorTexture(1, 1, 1, 1); lift:SetBlendMode("ADD")
local refreshTex = tex("OVERLAY", 1)  -- low refresh-rate shimmer
refreshTex:SetColorTexture(0, 0, 0, 1)
local flick = tex("OVERLAY", 1)

tint:SetColorTexture(1, 1, 1, 1); tint:SetBlendMode("MOD")
mask:SetBlendMode("MOD")
vig:SetTexture(MEDIA .. "vignette")
flick:SetColorTexture(0, 0, 0, 1)
band:SetTexture(MEDIA .. "band")
band:SetBlendMode("ADD")
band:SetPoint("LEFT", f, "LEFT"); band:SetPoint("RIGHT", f, "RIGHT")

function ns.ScreenPixels()
    local w, h = GetPhysicalScreenSize()
    if not w or w <= 0 or not h or h <= 0 then w, h = 1920, 1080 end
    return w, h
end

-- UI units per physical pixel on the overlay frame.
function ns.Unit()
    local _, ph = ns.ScreenPixels()
    local h = f:GetHeight()
    if not h or h <= 0 then h = 768 end
    return h / ph
end

-- One texel per screen pixel (times px), so patterns stay sharp with no moire.
-- size = tile width in texels, sizeH = tile height (defaults to size).
function ns.Tile(t, file, size, px, yoff, sizeH)
    local w, h = ns.ScreenPixels()
    px = px or 1; sizeH = sizeH or size
    local oy = (yoff or 0) / (sizeH * px)
    if file then t:SetTexture(MEDIA .. file, "REPEAT", "REPEAT", "NEAREST") end
    t:SetTexCoord(0, w / (size * px), oy, oy + h / (sizeH * px))
end

---------------------------------------------------------------- per-frame driver

local tickers = {}
function ns.OnTick(fn) tickers[#tickers + 1] = fn end
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    local S = ns.S
    if not S then return end
    for i = 1, #tickers do tickers[i](dt, S) end
end)

local elapsed, bandPos = 0, 0
local field, fieldT, shake = 0, 0, 0
local flickV, flickTarget, flickT = 0.5, 0.5, 0
local REFRESH_AMP = { [60] = 0.055, [75] = 0.025, [85] = 0.012 }

local function scanPeriod(S) return ns.SCAN_H[S.scanPeriod] and S.scanPeriod or 2 end
-- The one place the scanline y-offset comes from: interlace field + degauss shake.
local function tileScan(S, setFile)
    local p = scanPeriod(S)
    local off = (S.interlace and field * math.floor(p / 2) or 0) + shake
    ns.Tile(scan, setFile and ("scan" .. p) or nil, 8, 1, off, ns.SCAN_H[p])
end

ns.OnTick(function(dt, S)
    if not (S.enabled and f:IsShown()) then return end
    elapsed = elapsed + dt
    if S.interlace and S.scan then
        -- swap the odd/even field 60 times a second (keep the leftover time)
        fieldT = fieldT + math.min(dt, 0.1)
        if fieldT >= 1 / 60 then
            fieldT = fieldT - 1 / 60
            if fieldT >= 1 / 60 then fieldT = 0 end   -- slow frame: don't try to catch up
            field = 1 - field
            tileScan(S)
            scan:SetAlpha(S.scanStrength * (0.85 + 0.15 * field))
        end
    end
    local amp = REFRESH_AMP[S.refresh]
    if amp then
        -- the eye sees low refresh as a fast, uneven shimmer, strongest on bright screens
        refreshTex:SetAlpha(amp * (0.45 + 0.55 * math.random()) * (0.8 + 0.2 * math.sin(elapsed * 7.3)))
    end
    if S.flicker then
        -- slow random drift: new target 12-20 times a second, eased toward, plus a little per-frame noise
        flickT = flickT - dt
        if flickT <= 0 then flickT = 0.05 + 0.033 * math.random(); flickTarget = 0.2 + 0.8 * math.random() end
        flickV = flickV + (flickTarget - flickV) * math.min(1, dt * 30)
        flick:SetAlpha(S.flickerStrength * 0.08 * (0.85 * flickV + 0.15 * math.random()))
    end
    if S.roll then
        local h = f:GetHeight()
        local bh = h * 0.12
        bandPos = (bandPos + dt / math.max(1, S.rollSpeed)) % 1
        band:SetHeight(bh)
        band:ClearAllPoints()
        band:SetPoint("LEFT", f, "LEFT"); band:SetPoint("RIGHT", f, "RIGHT")
        band:SetPoint("TOP", f, "TOP", 0, -bandPos * (h + bh) + bh)
    end
end)

-- Nudge the scanlines by n pixels (degauss wobble). 0 = back to normal.
function ns.ShakeScan(n)
    shake = n or 0
    local S = ns.S
    if not (S and S.scan) then return end
    tileScan(S)
end

function ns.Apply()
    if not RetrovisionDB then return end
    local S = ns.Resolve()
    -- picture area: full window or centred 4:3
    scr:ClearAllPoints()
    if S.aspect == "4:3" then
        local h = f:GetHeight()
        scr:SetPoint("CENTER", f, "CENTER"); scr:SetSize(math.min(f:GetWidth(), h * 4 / 3), h)
    else
        scr:SetAllPoints(f)
    end
    if ns.ApplyFX then ns.ApplyFX(S) end
    if not S.enabled then f:Hide(); return end

    -- WoW draws everything parented to WorldFrame underneath the whole UI, whatever its strata.
    -- So "everything" needs the overlay on UIParent (hidden by Alt+Z like any UI), "world" on WorldFrame.
    if S.layer == "all" then
        if f:GetParent() ~= UIParent then f:SetParent(UIParent); f:ClearAllPoints(); f:SetAllPoints(WorldFrame) end
        f:SetFrameStrata("TOOLTIP"); f:SetFrameLevel(9000)
    else
        if f:GetParent() ~= WorldFrame then f:SetParent(WorldFrame); f:ClearAllPoints(); f:SetAllPoints(WorldFrame) end
        f:SetFrameStrata("BACKGROUND"); f:SetFrameLevel(0)
    end

    scan:SetShown(S.scan)
    if S.scan then
        tileScan(S, true)
        scan:SetAlpha(S.scanStrength)
    end

    mask:SetShown(S.mask)
    if S.mask then
        local lvl = math.max(1, math.min(3, math.floor(S.maskLevel + 0.5)))
        local file = ({ stripe = "mask", dot = "dot", lcd = "lcd", grid = "grid" })[S.maskType] or "mask"
        ns.Tile(mask, file .. lvl, 8, S.maskSize == 2 and 2 or 1)
    end


    dimmer:SetShown(S.brightness < 0.999); dimmer:SetAlpha(1 - S.brightness)
    lift:SetShown(S.blackLevel > 0.001)
    if S.tint == "lcd" then lift:SetVertexColor(0.16, 0.22, 0.05) else lift:SetVertexColor(0.09, 0.09, 0.10) end
    lift:SetAlpha(S.blackLevel * 0.6)
    refreshTex:SetShown(REFRESH_AMP[S.refresh] ~= nil)

    vig:SetShown(S.vignette)
    vig:SetAlpha(S.vignetteStrength)

    local c = ns.tints[S.tint] or ns.tints.none
    local s = S.tintStrength
    tint:SetShown(S.tint ~= "none")
    tint:SetVertexColor(1 - s * (1 - c[1]), 1 - s * (1 - c[2]), 1 - s * (1 - c[3]))

    flick:SetShown(S.flicker)
    band:SetShown(S.roll)
    band:SetAlpha(S.rollStrength * 0.15)

    cover:SetFrameLevel(f:GetFrameLevel() + 5)
    f:Show()
end

-- Turn the overlay on/off, with the TV power animation when wanted.
-- Returns false if ignored because the power animation is still running.
function ns.SetEnabled(on, animate)
    local db = RetrovisionDB
    if on == db.enabled then return end
    if ns.PowerBusy and ns.PowerBusy() then return false end
    if animate and db.powerFx and ns.PowerAnim then
        if on then
            db.enabled = true; ns.Apply(); ns.PowerAnim(true)
        else
            ns.PowerAnim(false, function() db.enabled = false; ns.Apply(); if ns.Refresh then ns.Refresh() end end)
            return
        end
    else
        db.enabled = on; ns.Apply()
    end
    if ns.Refresh then ns.Refresh() end
end

-- Apply with a quick dip (fade out, swap, fade in) instead of a hard snap.
-- Used when an auto rule changes. Turning on/off just applies directly.
local dipDir, dipA = nil, 1   -- -1 fading out, 1 fading in, nil idle
local DIP_OUT, DIP_IN = 0.12, 0.2
function ns.SoftApply()
    if not RetrovisionDB then return end
    local S = ns.S
    local wasOn = S and S.enabled and f:IsShown()
    local rule = ns.ActiveRule and ns.ActiveRule() or "none"
    local willOn = RetrovisionDB.enabled and rule ~= "off"
    if not (wasOn and willOn) or (ns.PowerBusy and ns.PowerBusy()) then
        dipDir, dipA = nil, 1; f:SetAlpha(1)
        ns.Apply(); if ns.Refresh then ns.Refresh() end
        return
    end
    dipDir = -1   -- if already fading in, turn around from the current alpha
end

ns.OnTick(function(dt)
    if not dipDir then return end
    dt = math.min(dt, 0.05)
    if dipDir < 0 then
        dipA = dipA - dt / DIP_OUT
        if dipA <= 0 then
            dipA, dipDir = 0, 1
            ns.Apply(); if ns.Refresh then ns.Refresh() end
            if not f:IsShown() then dipA, dipDir = 1, nil end
        end
    else
        dipA = dipA + dt / DIP_IN
        if dipA >= 1 then dipA, dipDir = 1, nil end
    end
    f:SetAlpha(dipA)
end)

---------------------------------------------------------------- minimap button

local ICON = MEDIA .. "icon"
local broker
function ns.SetupMinimap()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (LDB and DBI) or broker then return ns.UpdateMinimap() end
    broker = LDB:NewDataObject("Retrovision", {
        type = "launcher", text = "Retrovision", icon = ICON,
        OnClick = function(_, btn)
            if btn == "RightButton" then ns.SetEnabled(not RetrovisionDB.enabled, true)
            else ns.ToggleOptions() end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("|cffff2fa8Retrovision|r  |cff2ee6ffCRT overlay|r")
            tt:AddLine(RetrovisionDB.enabled and "|cff2ee6ffOn|r" or "|cff7e6a9aOff|r")
            if RetrovisionDB.activePreset then tt:AddLine("Preset: " .. RetrovisionDB.activePreset, 1, 0.31, 0.85) end
            if ns.ctxNow and ns.ruleNow ~= "none" then tt:AddLine("Auto: " .. ns.RuleLabel(ns.ruleNow) .. " (" .. ns.ctxNow .. ")", 0.18, 0.9, 1) end
            tt:AddLine(" ")
            tt:AddLine("Left-click: settings", 0.73, 0.65, 0.83)
            tt:AddLine("Right-click: overlay on/off", 0.73, 0.65, 0.83)
            tt:AddLine("Mouse wheel: next / previous preset", 0.73, 0.65, 0.83)
        end,
    })
    DBI:Register("Retrovision", broker, RetrovisionDB.minimap)
    local btn = DBI.GetMinimapButton and DBI:GetMinimapButton("Retrovision")
    if btn then
        btn:EnableMouseWheel(true)
        btn:SetScript("OnMouseWheel", function(_, d) ns.CyclePreset(d > 0 and -1 or 1) end)
    end
    ns.UpdateMinimap()
end

function ns.UpdateMinimap()
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (DBI and broker) then return end
    if RetrovisionDB.minimap.hide then DBI:Hide("Retrovision") else DBI:Show("Retrovision") end
end

function ns.CyclePreset(dir)
    local names = ns.PresetNames()
    local cur = 0
    for i, n in ipairs(names) do if n == RetrovisionDB.activePreset then cur = i end end
    local nxt = cur + dir
    if nxt < 1 then nxt = #names elseif nxt > #names then nxt = 1 end
    ns.ApplyPreset(names[nxt])
    if ns.Toast then ns.Toast(names[nxt]) end
end

-- Globals for the addon compartment and key bindings.
function Retrovision_OnCompartmentClick() ns.ToggleOptions() end
function Retrovision_Toggle() ns.SetEnabled(not RetrovisionDB.enabled, true) end
function Retrovision_Options() ns.ToggleOptions() end
function Retrovision_NextPreset() ns.CyclePreset(1) end
function Retrovision_PrevPreset() ns.CyclePreset(-1) end
BINDING_HEADER_RETROVISION = "Retrovision"
BINDING_NAME_RETROVISION_TOGGLE = "Overlay on / off"
BINDING_NAME_RETROVISION_OPTIONS = "Open settings"
BINDING_NAME_RETROVISION_NEXTPRESET = "Next preset"
BINDING_NAME_RETROVISION_PREVPRESET = "Previous preset"

---------------------------------------------------------------- events + slash

-- Fix up settings from older versions (safe to run every load).
function ns.Migrate()
    local db = RetrovisionDB
    for _, k in ipairs({ "auto", "presets", "minimap" }) do
        if type(db[k]) ~= "table" then db[k] = copy(ns.defaults[k]) end
    end
    for k, v in pairs(ns.defaults.auto) do if type(db.auto[k]) ~= "string" then db.auto[k] = v end end
    if db.minimap.hide == nil then db.minimap.hide = false end
    if db.minimap.minimapPos == nil then db.minimap.minimapPos = ns.defaults.minimap.minimapPos end
    db.scanPeriod = ns.SnapPeriod(db.scanPeriod)
    for _, p in pairs(db.presets) do
        if type(p) == "table" and p.scanPeriod ~= nil then p.scanPeriod = ns.SnapPeriod(p.scanPeriod) end
    end
    if type(db.safe) ~= "boolean" then db.safe = false end
    db.fitUI = nil   -- "fit UI to screen" was removed
    if type(db.intensity) ~= "number" then db.intensity = 1 end
    db.dbVersion = 3
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, e, arg)
    if e == "ADDON_LOADED" then
        if arg ~= ADDON then return end
        RetrovisionDB = RetrovisionDB or {}
        ns.FillDefaults()
        ns.Migrate()
        ns.SetupMinimap()
    end
    if RetrovisionDB then ns.Apply() end
end)

local function say(msg) print("|cffff2fa8Retrovision|r " .. msg) end
ns.say = say

SLASH_RETROVISION1 = "/crt"
SLASH_RETROVISION2 = "/retro"
SLASH_RETROVISION3 = "/retrovision"
SlashCmdList.RETROVISION = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "on" or cmd == "off" or cmd == "toggle" then
        local want = cmd == "on" or (cmd == "toggle" and not RetrovisionDB.enabled)
        if ns.SetEnabled(want, true) == false then say("busy, try again in a moment")
        else say(want and "on" or "off") end
    elseif cmd == "safe" then
        RetrovisionDB.safe = not RetrovisionDB.safe
        ns.Apply(); if ns.Refresh then ns.Refresh() end
        say(RetrovisionDB.safe and "flashing safety ON (no flicker, strobe, rolling or glitch effects)" or "flashing safety off")
    elseif cmd == "preset" then
        if rest == "" then say("presets: " .. table.concat(ns.PresetNames(), ", "))
        else
            local found
            for _, n in ipairs(ns.PresetNames()) do if n:lower() == rest:lower() then found = n end end
            if found and ns.ApplyPreset(found) then say("preset " .. found) else say("no preset called " .. rest) end
        end
    elseif cmd == "next" then ns.CyclePreset(1)
    elseif cmd == "prev" then ns.CyclePreset(-1)
    elseif cmd == "minimap" then
        RetrovisionDB.minimap.hide = not RetrovisionDB.minimap.hide
        ns.UpdateMinimap(); if ns.Refresh then ns.Refresh() end
        say(RetrovisionDB.minimap.hide and "minimap button hidden (/crt minimap to show)" or "minimap button shown")
    elseif cmd == "reset" then
        local keep = { minimap = RetrovisionDB.minimap, presets = RetrovisionDB.presets, window = RetrovisionDB.window }
        wipe(RetrovisionDB)
        for k, v in pairs(keep) do RetrovisionDB[k] = v end   -- keep button spot, window spot + saved presets
        ns.FillDefaults(); ns.Migrate()
        ns.Apply(); if ns.Refresh then ns.Refresh() end
        say("settings reset (saved presets kept)")
    elseif cmd == "help" then
        say("/crt  settings   /crt on|off   /crt preset <name>   /crt next|prev   /crt minimap   /crt safe (flashing safety)   /crt reset")
    else
        ns.ToggleOptions()
    end
end
