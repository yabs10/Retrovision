-- Retrovision settings window (/crt): neon synthwave look (Miami palette).
-- Sidebar pages; every setting has a name, a one-line description and its control on one grid.
local ADDON, ns = ...
local MEDIA = ns.MEDIA

local C = {
    bg     = { 0.039, 0.024, 0.071 },  -- #0a0612
    bg2    = { 0.075, 0.039, 0.133 },  -- #130a22
    track  = { 0.141, 0.086, 0.227 },  -- #24163a
    edge   = { 0.231, 0.165, 0.310 },  -- #3b2a4f
    pink   = { 1.000, 0.184, 0.659 },  -- #ff2fa8
    hot    = { 1.000, 0.310, 0.847 },  -- #ff4fd8
    violet = { 0.541, 0.239, 1.000 },  -- #8a3dff
    cyan   = { 0.180, 0.902, 1.000 },  -- #2ee6ff
    text   = { 0.965, 0.925, 1.000 },  -- #f6ecff
    dim    = { 0.725, 0.651, 0.827 },  -- #b9a6d3
    mute   = { 0.494, 0.416, 0.604 },  -- #7e6a9a
    desc   = { 0.610, 0.545, 0.720 },  -- description text
    side   = { 0.028, 0.016, 0.052 },  -- sidebar
}
local TINT_SWATCH = {
    none = { 0.85, 0.85, 0.9 }, amber = { 1, 0.70, 0.28 }, green = { 0.35, 1, 0.45 },
    warm = { 1, 0.80, 0.62 }, cool = { 0.55, 0.78, 1 }, lcd = { 0.62, 0.74, 0.2 },
}

-- window + grid (all pages share it)
local W, H = 780, 700
local SB = 188                 -- sidebar width
local PX = SB + 24             -- page left edge (window coords)
local PW = W - PX - 26         -- page width
local PAGE_TOP = -92           -- page top (window coords)
local AVAIL = H + PAGE_TOP - 22 -- page height
local TX = 46                  -- row title x (switches sit at 0)
local CX = 296                 -- control column x
local CW = PW - CX             -- control column width
local DESC_W = CX - TX - 16    -- description wrap width
local STRETCHED = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0

local win
local refreshers = {}
local function db() return RetrovisionDB end
local function onRefresh(fn) refreshers[#refreshers + 1] = fn end

-- Expressway from EllesmereUI if it's installed, otherwise the game font.
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
do
    local ok, exists = pcall(function() return C_AddOns.DoesAddOnExist("EllesmereUI") end)
    if ok and exists then FONT = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.ttf" end
end
ns.FONT = FONT

local LOOK = {}
for _, k in ipairs(ns.LOOK_KEYS) do LOOK[k] = true end

-- Settings that pop up the old-monitor menu bar when changed.
local MON_OSD = {
    brightness = { "Brightness", 0.4, 1 }, blackLevel = { "Black level", 0, 1 },
    monitorSize = { "Frame size", 0.5, 1.6 }, glareStrength = { "Glare", 0.05, 1 },
    bezelShadow = { "Inner shadow", 0, 1 }, bezelThickness = { "Frame", 0, 80 },
    refresh = { "Refresh rate", 0, 85 },
}

-- Every control writes through here: save, mark preset as edited, redraw.
local function setKey(key, v, full)
    db()[key] = v
    local m = MON_OSD[key]
    if m and ns.MonitorOSD then
        local frac = (v - m[2]) / (m[3] - m[2])
        local label = key == "refresh" and (v == 0 and "OFF" or (v .. " HZ")) or (math.floor(frac * 100 + 0.5) .. "")
        ns.MonitorOSD(m[1], key == "refresh" and (v == 0 and 1 or (v - 50) / 35) or frac, label)
    end
    if LOOK[key] then ns.Touched() end
    ns.Apply()
    if full ~= false then ns.Refresh() end
end

local function rgb(c, a) return c[1], c[2], c[3], a or 1 end

local function text(parent, str, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size or 12, "")
    fs:SetTextColor(rgb(color or C.text))
    fs:SetText(str or "")
    return fs
end

local function sliced(parent, file, margin, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetTexture(MEDIA .. file)
    t:SetTextureSliceMargins(margin, margin, margin, margin)
    t:SetTextureSliceMode(STRETCHED)
    return t
end

local function tooltip(widget, title, body)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if db().layer == "all" then
            -- overlay + window sit high in TOOLTIP strata; lift the tooltip just while we use it
            GameTooltip.retrovisionLevel = GameTooltip.retrovisionLevel or GameTooltip:GetFrameLevel()
            GameTooltip:SetFrameStrata("TOOLTIP"); GameTooltip:SetFrameLevel(9800)
        end
        GameTooltip:AddLine(title, rgb(C.pink))
        if body then GameTooltip:AddLine(body, C.dim[1], C.dim[2], C.dim[3], true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function()
        GameTooltip:Hide()
        if GameTooltip.retrovisionLevel then GameTooltip:SetFrameLevel(GameTooltip.retrovisionLevel); GameTooltip.retrovisionLevel = nil end
    end)
end

---------------------------------------------------------------- widgets

-- Lay an invisible mouse catcher over a control while it's dimmed, so it can't be clicked,
-- dragged or wheeled. Returns a setter: live(true) = usable.
local function lockable(c)
    if not (c.IsObjectType and c:IsObjectType("Frame")) then return function() end end
    local blk = CreateFrame("Frame", nil, c)
    blk:SetPoint("TOPLEFT", -6, 6); blk:SetPoint("BOTTOMRIGHT", 6, -6)
    blk:SetFrameLevel(c:GetFrameLevel() + 20)
    blk:EnableMouse(true); blk:EnableMouseWheel(true)
    blk:SetScript("OnMouseWheel", function() end)
    blk:Hide()
    return function(on) blk:SetShown(not on) end
end

-- Toggle switch: violet track, pink when on, white knob slides across.
local function switch(parent, x, y, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 18)
    b:SetPoint("TOPLEFT", x, y)
    local glow = b:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "glowdot"); glow:SetPoint("CENTER"); glow:SetSize(70, 40)
    glow:SetVertexColor(rgb(C.pink)); glow:SetBlendMode("ADD")
    local track = sliced(b, "pill", 9, "ARTWORK", 0); track:SetAllPoints()
    local knob = b:CreateTexture(nil, "ARTWORK", nil, 2)
    knob:SetTexture(MEDIA .. "dot"); knob:SetSize(14, 14)
    local pos = 0
    local mover = CreateFrame("Frame", nil, b); mover:Hide()
    local function place(p) knob:ClearAllPoints(); knob:SetPoint("LEFT", b, "LEFT", 2 + p * 18, 0) end
    mover:SetScript("OnUpdate", function(self, dt)
        local tgt = get() and 1 or 0
        pos = pos + (tgt > pos and 1 or -1) * dt * 8
        if (tgt == 1 and pos >= 1) or (tgt == 0 and pos <= 0) then pos = tgt; self:Hide() end
        place(pos)
    end)
    local function paint(instant)
        local on = get()
        track:SetVertexColor(rgb(on and C.pink or C.track))
        knob:SetVertexColor(rgb(on and C.text or C.mute))
        if instant then pos = on and 1 or 0; place(pos) else mover:Show() end
        glow:SetAlpha(on and (b:IsMouseOver() and 0.55 or 0.3) or 0)
    end
    b:SetScript("OnClick", function() set(not get()); paint() end)
    b:SetScript("OnEnter", function() glow:SetAlpha(get() and 0.55 or 0.15) end)
    b:SetScript("OnLeave", function() glow:SetAlpha(get() and 0.3 or 0) end)
    onRefresh(function() paint(true) end)
    return b
end

local function keySwitch(parent, x, y, key)
    return switch(parent, x, y, function() return db()[key] end, function(v) setKey(key, v) end)
end

-- Slider: thin track, pink->cyan fill, glowing knob, value readout.
local function slider(parent, x, y, w, key, lo, hi, step, fmt)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(w, 18)
    s:SetPoint("TOPLEFT", x, y)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetHitRectInsets(-4, -4, -6, -6)

    local track = sliced(s, "pill", 9, "BACKGROUND", 0)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
    track:SetVertexColor(rgb(C.track))
    local fill = s:CreateTexture(nil, "BORDER")
    fill:SetColorTexture(1, 1, 1, 1)
    fill:SetPoint("LEFT", track, "LEFT"); fill:SetHeight(2)
    fill:SetGradient("HORIZONTAL", CreateColor(rgb(C.pink)), CreateColor(rgb(C.cyan)))

    local thumb = s:CreateTexture(nil, "OVERLAY", nil, 1)
    thumb:SetTexture(MEDIA .. "dot"); thumb:SetSize(12, 12)
    thumb:SetVertexColor(rgb(C.text))
    s:SetThumbTexture(thumb)
    local halo = s:CreateTexture(nil, "OVERLAY", nil, 0)
    halo:SetTexture(MEDIA .. "glowdot"); halo:SetSize(34, 34); halo:SetBlendMode("ADD")
    halo:SetPoint("CENTER", thumb, "CENTER"); halo:SetVertexColor(rgb(C.hot)); halo:SetAlpha(0.45)

    local val = text(s, "", 12, C.cyan)
    val:SetPoint("LEFT", s, "RIGHT", 12, 0)

    local function show(v)
        val:SetText(fmt and fmt(v) or (math.floor(v * 100 + 0.5) .. "%"))
        fill:SetWidth(math.max(0.01, (w - 2) * (v - lo) / (hi - lo)))
    end
    s:SetScript("OnValueChanged", function(_, v, user)
        show(v)
        if user then setKey(key, v, false) end
    end)
    s:SetScript("OnMouseUp", function() ns.Refresh() end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d)
        local v = math.max(lo, math.min(hi, self:GetValue() + d * step))
        self:SetValue(v); setKey(key, v)
    end)
    s:SetScript("OnEnter", function() halo:SetAlpha(0.85) end)
    s:SetScript("OnLeave", function() halo:SetAlpha(0.45) end)
    onRefresh(function() s:SetValue(db()[key]); show(db()[key]) end)
    return s
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end
local function px(v) return math.floor(v + 0.5) .. " px" end

-- Outlined rounded button; `on` decides the pink fill.
local function pillButton(parent, w, h, label, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h or 22)
    b.bg = sliced(b, "round6", 6, "BACKGROUND"); b.bg:SetAllPoints()
    b.line = sliced(b, "round6line", 6, "BORDER"); b.line:SetAllPoints()
    b.txt = text(b, label, size or 11); b.txt:SetPoint("CENTER", 0, 0)
    b.txt:SetWidth(w - 8); b.txt:SetWordWrap(false)
    function b:Paint(on, hover)
        self.bg:SetVertexColor(rgb(on and C.pink or C.bg2, on and 0.9 or 1))
        self.line:SetVertexColor(rgb((on or hover) and C.hot or C.edge))
        self.txt:SetTextColor(rgb((on or hover) and C.text or C.dim))
    end
    b:Paint(false)
    return b
end

-- Segmented choice: selected one filled pink.
local function segments(parent, x, y, w, key, values, names)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y); holder:SetSize(w, 22)
    local gap = 4
    local bw = (w - gap * (#values - 1)) / #values
    local btns = {}
    for i, v in ipairs(values) do
        local b = pillButton(holder, bw, 22, names[i])
        b:SetPoint("LEFT", (i - 1) * (bw + gap), 0)
        b:SetScript("OnClick", function() setKey(key, v) end)
        b:SetScript("OnEnter", function() b:Paint(db()[key] == v, true) end)
        b:SetScript("OnLeave", function() b:Paint(db()[key] == v) end)
        btns[i] = b
    end
    onRefresh(function() for i, b in ipairs(btns) do b:Paint(db()[key] == values[i]) end end)
    return holder
end

-- Colour chips for the phosphor tint.
local function chips(parent, x, y, key, values, names)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y); holder:SetSize(240, 40)
    local btns = {}
    for i, v in ipairs(values) do
        local b = CreateFrame("Button", nil, holder)
        b:SetSize(38, 40)
        b:SetPoint("TOPLEFT", (i - 1) * 41, 0)
        b.ring = b:CreateTexture(nil, "BACKGROUND"); b.ring:SetTexture(MEDIA .. "glowdot")
        b.ring:SetSize(40, 40); b.ring:SetPoint("TOP", 0, 9); b.ring:SetBlendMode("ADD")
        b.sw = b:CreateTexture(nil, "ARTWORK"); b.sw:SetTexture(MEDIA .. "dot")
        b.sw:SetSize(18, 18); b.sw:SetPoint("TOP", 0, 0)
        b.sw:SetVertexColor(rgb(TINT_SWATCH[v]))
        b.txt = text(b, names[i], 10); b.txt:SetPoint("TOP", b.sw, "BOTTOM", 0, -4)
        b:SetScript("OnClick", function() setKey(key, v) end)
        b:SetScript("OnEnter", function() b.ring:SetAlpha(0.6) end)
        b:SetScript("OnLeave", function() ns.Refresh() end)
        btns[i] = b
    end
    onRefresh(function()
        for i, b in ipairs(btns) do
            local on = db()[key] == values[i]
            b.ring:SetVertexColor(rgb(TINT_SWATCH[values[i]])); b.ring:SetAlpha(on and 0.9 or 0)
            b.sw:SetSize(on and 20 or 16, on and 20 or 16)
            b.txt:SetTextColor(rgb(on and C.text or C.mute))
        end
    end)
    return holder
end

local function button(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 24)
    b.bg = sliced(b, "round6", 6, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetVertexColor(rgb(C.bg2))
    b.line = sliced(b, "round6line", 6, "BORDER"); b.line:SetAllPoints(); b.line:SetVertexColor(rgb(C.pink))
    b.txt = text(b, label, 11, C.pink); b.txt:SetPoint("CENTER")
    b:SetScript("OnEnter", function() b.bg:SetVertexColor(rgb(C.pink)); b.txt:SetTextColor(rgb(C.text)) end)
    b:SetScript("OnLeave", function() b.bg:SetVertexColor(rgb(C.bg2)); b.txt:SetTextColor(rgb(C.pink)) end)
    return b
end

local function editbox(parent, w, h)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h or 24)
    local bg = sliced(holder, "round6", 6, "BACKGROUND"); bg:SetAllPoints(); bg:SetVertexColor(rgb(C.bg))
    local line = sliced(holder, "round6line", 6, "BORDER"); line:SetAllPoints(); line:SetVertexColor(rgb(C.edge))
    local eb = CreateFrame("EditBox", nil, holder)
    eb:SetPoint("TOPLEFT", 8, -2); eb:SetPoint("BOTTOMRIGHT", -8, 2)
    eb:SetFont(FONT, 12, "")
    eb:SetTextColor(rgb(C.text))
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEditFocusGained", function() line:SetVertexColor(rgb(C.cyan)) end)
    eb:SetScript("OnEditFocusLost", function() line:SetVertexColor(rgb(C.edge)) end)
    holder.eb = eb
    return holder
end

---------------------------------------------------------------- layout: one grid for every page

-- A page is filled top to bottom by a cursor. Rows: [switch] Title / description | control.
local Layout = {}
Layout.__index = Layout
ns.layoutReport = {}   -- { name, used, avail } per page, checked by the test harness

local function newLayout(p, name)
    return setmetatable({ p = p, y = 0, name = name }, Layout)
end

function Layout:done()
    ns.layoutReport[#ns.layoutReport + 1] = { name = self.name, used = -self.y, avail = AVAIL }
end

-- Section header: small cyan caps + fading line. Returns the title so a button can sit at its right.
function Layout:section(title)
    if self.y < 0 then self.y = self.y - 12 end
    local p = self.p
    local t = text(p, title, 10, C.cyan)
    t:SetPoint("TOPLEFT", 0, self.y)
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 1); line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 8, 0); line:SetPoint("RIGHT", t, "LEFT", PW, 0)   -- both ends on the title's centre line
    line:SetGradient("HORIZONTAL", CreateColor(rgb(C.cyan, 0.5)), CreateColor(rgb(C.violet, 0)))
    local headerY = self.y
    self.y = self.y - 24
    return t, headerY
end

-- rough line count for a description at DESC_W (Expressway 11 ~ 5.7 px a character)
local function descLines(s)
    local n = 0
    for part in (s .. "\n"):gmatch("(.-)\n") do n = n + math.max(1, math.ceil(#part * 5.7 / DESC_W)) end
    return n
end

-- Main row. opts.key = effect switch (row dims + locks its controls when off), opts.tip = tooltip.
-- Returns the row; row.cy = y for the control, row:Ctl(c) registers a control to dim/lock.
function Layout:row(title, desc, opts)
    opts = opts or {}
    local p, y = self.p, self.y
    local row = { controls = {}, locks = {}, labels = {}, cy = y - 1, layout = self }
    if opts.key then
        local sw = keySwitch(p, 0, y - 1, opts.key)
        if opts.tip then tooltip(sw, title, opts.tip) end
    end
    local t = text(p, title, 13, C.text); t:SetPoint("TOPLEFT", TX, y - 2)
    row.title = t
    local h = 30
    if desc then
        local d = text(p, desc, 11, C.desc)
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4); d:SetWidth(DESC_W)
        d:SetJustifyH("LEFT"); d:SetWordWrap(true)
        row.desc = d
        h = 26 + 14 * descLines(desc)
    end
    if opts.tip and not opts.key then
        local hit = CreateFrame("Frame", nil, p)
        hit:SetPoint("TOPLEFT", t, "TOPLEFT", -2, 2); hit:SetSize(DESC_W, 18)
        hit:EnableMouse(true); tooltip(hit, title, opts.tip)
    end
    self.y = y - h - 4
    function row:Ctl(c)
        self.controls[#self.controls + 1] = c; self.locks[#self.locks + 1] = lockable(c)
        return c
    end
    -- extra setting under this row: small label, control in the control column
    function row:Sub(label, tip)
        local L = self.layout
        local sy = L.y + 2
        local l = text(p, label, 12, C.dim); l:SetPoint("TOPLEFT", TX + 14, sy - 3)
        local dot = text(p, "·", 12, C.mute); dot:SetPoint("RIGHT", l, "LEFT", -5, 0)
        self.labels[#self.labels + 1] = l
        if tip then
            local hit = CreateFrame("Frame", nil, p)
            hit:SetPoint("TOPLEFT", l, "TOPLEFT", -2, 2); hit:SetSize(CX - TX - 20, 18)
            hit:EnableMouse(true); tooltip(hit, label, tip)
        end
        L.y = L.y - 30
        return sy, l
    end
    if opts.key then
        onRefresh(function()
            local on = db()[opts.key]
            t:SetTextColor(rgb(on and C.text or C.mute))
            for i, c in ipairs(row.controls) do c:SetAlpha(on and 1 or 0.35); row.locks[i](on) end
            for _, l in ipairs(row.labels) do l:SetAlpha(on and 1 or 0.45) end
        end)
    end
    return row
end

function Layout:note(str, color)
    local l = text(self.p, str, 11, color or C.desc)
    l:SetPoint("TOPLEFT", TX, self.y); l:SetWidth(PW - TX); l:SetJustifyH("LEFT"); l:SetWordWrap(true)
    local lines = 0
    for part in (str .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#part * 5.7 / (PW - TX))) end
    self.y = self.y - lines * 14 - 8
    return l
end

local SLW = CW - 52   -- slider width (value readout sits to its right)

---------------------------------------------------------------- pop-up choice menu (auto rules)

local menu, menuBtns
local function closeMenu() if menu then menu:Hide() end end
local function openMenu(owner, choices, labelOf, current, pick)
    if not menu then
        menu = CreateFrame("Frame", nil, win)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        local bg = sliced(menu, "round6", 6, "BACKGROUND"); bg:SetAllPoints(); bg:SetVertexColor(rgb(C.bg))
        local line = sliced(menu, "round6line", 6, "BORDER"); line:SetAllPoints(); line:SetVertexColor(rgb(C.pink))
        menuBtns = {}
    end
    if win:GetFrameStrata() == "TOOLTIP" then menu:SetFrameStrata("TOOLTIP"); menu:SetFrameLevel(9700) end
    local PERCOL, BW, BH = 14, 170, 22
    local cols = math.max(1, math.ceil(#choices / PERCOL))
    local rows = math.min(#choices, PERCOL)
    menu:SetSize(cols * (BW + 4) + 8, rows * (BH + 2) + 8)
    menu:ClearAllPoints(); menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
    for i = 1, math.max(#choices, #menuBtns) do
        local b = menuBtns[i]
        if i <= #choices then
            if not b then
                b = pillButton(menu, BW, BH, "", 11)
                b:SetScript("OnEnter", function() b:Paint(b.value == menu.current, true) end)
                b:SetScript("OnLeave", function() b:Paint(b.value == menu.current) end)
                b:SetScript("OnClick", function() menu:Hide(); menu.pick(b.value) end)
                menuBtns[i] = b
            end
            b.value = choices[i]
            b.txt:SetText(labelOf(choices[i]))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 4 + math.floor((i - 1) / PERCOL) * (BW + 4), -4 - ((i - 1) % PERCOL) * (BH + 2))
            b:Paint(choices[i] == current)
            b:Show()
        elseif b then b:Hide() end
    end
    menu.current, menu.pick = current, pick
    menu:Show()
end

---------------------------------------------------------------- pages

local PAGES = {}
local function page(name, hint, title, desc, build) PAGES[#PAGES + 1] = { name = name, hint = hint, title = title, desc = desc, build = build } end

page("Presets", "Ready-made looks", "Presets",
    "Pick a ready-made look, then fine-tune it on the other pages. Save your tweaks as your own preset.",
function(L, p)
    local _, hy = L:section("LOOKS")
    local cols, gap, PER, CH = 3, 8, 12, 46
    local bw = (PW - gap * (cols - 1)) / cols
    local grid = CreateFrame("Frame", nil, p)
    grid:SetPoint("TOPLEFT", 0, L.y); grid:SetSize(PW, 4 * (CH + gap))
    local pool, pg = {}, 1
    -- pager on the header line, only when there's more than one page
    local nextB = pillButton(p, 22, 18, ">", 11); nextB:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, hy + 4)
    local pageL = text(p, "", 10, C.dim); pageL:SetPoint("RIGHT", nextB, "LEFT", -6, 0)
    local prevB = pillButton(p, 22, 18, "<", 11); prevB:SetPoint("RIGHT", pageL, "LEFT", -6, 0)
    for _, pb in ipairs({ prevB, nextB }) do
        pb:SetScript("OnEnter", function() pb:Paint(false, true) end)
        pb:SetScript("OnLeave", function() pb:Paint(false) end)
    end
    prevB:SetScript("OnClick", function() pg = pg - 1; ns.Refresh() end)
    nextB:SetScript("OnClick", function() pg = pg + 1; ns.Refresh() end)
    onRefresh(function()
        local all = ns.PresetNames()
        local pages = math.max(1, math.ceil(#all / PER))
        pg = math.max(1, math.min(pg, pages))
        prevB:SetShown(pages > 1); nextB:SetShown(pages > 1); pageL:SetShown(pages > 1)
        pageL:SetText(pg .. " / " .. pages)
        prevB:SetEnabled(pg > 1); prevB:SetAlpha(pg > 1 and 1 or 0.35)
        nextB:SetEnabled(pg < pages); nextB:SetAlpha(pg < pages and 1 or 0.35)
        for i = 1, math.max(PER, #pool) do
            local n = all[(pg - 1) * PER + i]
            local b = pool[i]
            if n and i <= PER then
                if not b then
                    b = pillButton(grid, bw, CH, "")
                    b:SetPoint("TOPLEFT", ((i - 1) % cols) * (bw + gap), -math.floor((i - 1) / cols) * (CH + gap))
                    b.txt:ClearAllPoints(); b.txt:SetPoint("TOPLEFT", 12, -8); b.txt:SetJustifyH("LEFT")
                    b.txt:SetFont(FONT, 13, "")
                    b.sub = text(b, "", 10, C.desc); b.sub:SetPoint("TOPLEFT", 12, -26)
                    b.sub:SetWidth(bw - 20); b.sub:SetJustifyH("LEFT"); b.sub:SetWordWrap(false)
                    local paint = b.Paint
                    function b:Paint(on, hover)
                        paint(self, on, hover)
                        self.sub:SetTextColor(rgb(on and C.text or C.desc, on and 0.85 or 1))
                    end
                    b:SetScript("OnClick", function() ns.ApplyPreset(b.name); ns.Toast(b.name) end)
                    b:SetScript("OnEnter", function() b:Paint(db().activePreset == b.name, true) end)
                    b:SetScript("OnLeave", function() b:Paint(db().activePreset == b.name) end)
                    pool[i] = b
                end
                b.name = n
                local v, custom = ns.GetPreset(n)
                local desc
                if not custom then for _, bp in ipairs(ns.builtinPresets) do if bp.name == n then desc = bp.desc end end end
                b.txt:SetText(custom and ("|cff2ee6ff*|r " .. n) or n)
                b.sub:SetText(desc or "Your saved look")
                b:Paint(db().activePreset == n)
                b:Show()
            elseif b then b:Hide() end
        end
    end)
    L.y = L.y - 4 * (CH + gap)

    L:section("SAVE YOUR LOOK")
    local box = editbox(p, CX - 8, 26); box:SetPoint("TOPLEFT", 0, L.y)
    local ph = text(box, "Name your look...", 12, C.mute); ph:SetPoint("LEFT", 8, 0)
    box.eb:SetScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == "" and not self:HasFocus()) end)
    box.eb:HookScript("OnEditFocusGained", function() ph:Hide() end)
    box.eb:HookScript("OnEditFocusLost", function(self) ph:SetShown(self:GetText() == "") end)
    local save = button(p, "SAVE", 96); save:SetPoint("TOPLEFT", CX, L.y - 1)
    local del = button(p, "DELETE", 96); del:SetPoint("LEFT", save, "RIGHT", 10, 0)
    tooltip(del, "Delete preset", "Deletes the selected saved preset (marked with a cyan *). Built-in presets can't be deleted.")
    local err = text(p, "", 11, C.pink); err:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -4)
    local function doSave()
        local name = (box.eb:GetText() or ""):match("^%s*(.-)%s*$")
        local existed = db().presets[name] ~= nil
        local ok, why = ns.SavePreset(name)
        if ok then
            err:SetText(""); box.eb:SetText(""); box.eb:ClearFocus()
            ns.Toast((existed and "Updated " or "Saved ") .. name); ns.Refresh()
        else
            err:SetText(why or "couldn't save that"); ns.Toast(why or "couldn't save that")
        end
    end
    save:SetScript("OnClick", doSave)
    box.eb:SetScript("OnEnterPressed", doSave)
    box.eb:HookScript("OnTextChanged", function(_, user) if user then err:SetText("") end end)
    del:SetScript("OnClick", function()
        local n = db().activePreset
        if n and ns.DeletePreset(n) then ns.Toast("Deleted " .. n); ns.Refresh() end
    end)
    onRefresh(function()
        local _, custom = ns.GetPreset(db().activePreset)
        del:SetAlpha(custom and 1 or 0.35); del:SetEnabled(custom and true or false)
    end)
    L.y = L.y - 46
    L:note("Saves everything on the Picture, Screen and Motion pages. Using a saved name updates it.")

    L:section("STRENGTH")
    local r = L:row("Overall strength", "Turns every effect up or down together, without changing your look.")
    slider(p, CX, r.cy - 3, SLW, "intensity", 0.25, 1.5, 0.05)
end)

page("Picture", "Lines, mask, colour", "Picture",
    "How the image itself looks: the lines, the screen's colour pattern, tint and light.",
function(L, p)
    L:section("SCANLINES")
    local r = L:row("Scanlines", "Dark gaps between the lines an old tube draws.", { key = "scan" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "scanStrength", 0.05, 1, 0.05))
    local y = r:Sub("Line spacing", "Screen pixels per line. 2 px is fine and sharp; 3, 4 and 6 px give thicker,\nmore old-TV lines and suit big or high-resolution screens.")
    r:Ctl(segments(p, CX, y, CW, "scanPeriod", { 2, 3, 4, 6 }, { "2 PX", "3 PX", "4 PX", "6 PX" }))
    y = r:Sub("Interlacing", "Odd and even lines swap every frame, giving the fine shimmer of an interlaced TV.")
    r:Ctl(keySwitch(p, CX, y - 1, "interlace"))

    L:section("SCREEN PATTERN")
    r = L:row("Phosphor mask", "The tiny coloured stripes or dots a real screen is made of.", { key = "mask" })
    r:Ctl(segments(p, CX, r.cy, CW, "maskLevel", { 1, 2, 3 }, { "LOW", "MID", "HIGH" }))
    y = r:Sub("Type", "Stripe: aperture-grille tube (sharp, premium CRTs).\nDot: shadow-mask tube (most PC monitors and TVs).\nLCD: flat-panel subpixels with a pixel grid.\nGrid: handheld screen-door grid.")
    r:Ctl(segments(p, CX, y, CW, "maskType", ns.enums.maskType, { "STRIPE", "DOT", "LCD", "GRID" }))
    y = r:Sub("Size", "Coarse doubles the pattern size, easier to see on high-resolution screens.")
    r:Ctl(segments(p, CX, y, CW, "maskSize", { 1, 2 }, { "FINE", "COARSE" }))

    L:section("COLOUR AND LIGHT")
    r = L:row("Tint", "Colours the picture like an old phosphor screen.")
    chips(p, CX, r.cy + 2, "tint", ns.enums.tint, { "NONE", "AMBER", "GREEN", "WARM", "COOL", "LCD" })
    L.y = math.min(L.y, r.cy - 46)
    local sy, sl = r:Sub("Tint strength")
    local ts = slider(p, CX, sy - 3, SLW, "tintStrength", 0.05, 1, 0.05)
    local tsLive = lockable(ts)
    onRefresh(function()
        local on = db().tint ~= "none"
        ts:SetAlpha(on and 1 or 0.35); sl:SetAlpha(on and 1 or 0.45); tsLive(on)
    end)
    r = L:row("Vignette", "Darker edges and corners, like curved glass.", { key = "vignette" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "vignetteStrength", 0.05, 1, 0.05))
    r = L:row("Brightness", "Old screens were dimmer than yours.")
    slider(p, CX, r.cy - 3, SLW, "brightness", 0.4, 1, 0.02)
    r = L:row("Black level", "Lifts dark areas to grey, like a tube in a lit room.")
    slider(p, CX, r.cy - 3, SLW, "blackLevel", 0, 1, 0.05)
end)

page("Screen", "Monitor, 4:3, glass", "Screen",
    "The hardware around the picture: the monitor case, the screen shape and the glass.",
function(L, p)
    L:section("FRAME")
    local r = L:row("Frame", "Draws a TV or monitor case around the picture.", { key = "bezel" })
    r:Ctl(segments(p, CX, r.cy, CW, "bezelStyle", ns.enums.bezelStyle, { "PLAIN", "BEIGE PC", "BLACK PC" }))
    local y, sizeL = r:Sub("Size")
    local sizeS = r:Ctl(slider(p, CX, y - 3, SLW, "monitorSize", 0.5, 1.6, 0.05))
    local thickS = r:Ctl(slider(p, CX, y - 3, SLW, "bezelThickness", 0, 80, 1, px))
    local radY, radL = r:Sub("Corner radius")
    local radS = r:Ctl(slider(p, CX, radY - 3, SLW, "bezelRadius", 0, 160, 2, px))
    y = r:Sub("Inner shadow", "Shadow just inside the frame, so the glass looks set back.")
    r:Ctl(slider(p, CX, y - 3, SLW, "bezelShadow", 0, 1, 0.05))
    onRefresh(function()
        local plain = db().bezelStyle == "plain"
        sizeL:SetText(plain and "Thickness" or "Size")
        sizeS:SetShown(not plain); thickS:SetShown(plain)
        radL:SetShown(plain); radS:SetShown(plain)
    end)

    L:section("SHAPE")
    r = L:row("Screen shape", "4:3 adds side bars like a 2004 monitor. Nothing gets squashed, you just see less.")
    segments(p, CX, r.cy, CW, "aspect", ns.enums.aspect, { "WIDESCREEN", "4:3 CLASSIC" })

    local _, hy = L:section("GLASS")
    local dg = button(p, "DEGAUSS", 96); dg:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, hy + 6)
    tooltip(dg, "Degauss", "The rainbow wobble from the button on old monitors. Just for fun.")
    dg:SetScript("OnClick", function() ns.Degauss() end)
    r = L:row("Glass glare", "A soft window reflection on the screen.", { key = "glare" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "glareStrength", 0.05, 1, 0.05))

    L:section("EARLY LCD")
    L:row("Viewing angle", "Top of the panel a little darker, like an early LCD seen from below.", { key = "viewAngle" })
    L:row("Backlight bleed", "Faint light leaking in at the panel edges.", { key = "backlightBleed" })
end)

page("Motion", "Flicker, grain, glitches", "Motion",
    "Effects that move: tube flicker, tape noise and glitches.",
function(L, p)
    L:section("TUBE")
    local r = L:row("Flicker", "A faint, uneven flutter in brightness.", { key = "flicker" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "flickerStrength", 0.05, 1, 0.05))
    r = L:row("Refresh shimmer", "The fast flicker of a CRT at a low refresh rate. 60 Hz is the most flickery.")
    segments(p, CX, r.cy, CW, "refresh", { 0, 60, 75, 85 }, { "OFF", "60 HZ", "75 HZ", "85 HZ" })
    r = L:row("Rolling band", "A soft hum bar drifting down the screen.", { key = "roll" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "rollStrength", 0.05, 1, 0.05))
    local y = r:Sub("Speed", "Seconds for one pass down the screen.")
    r:Ctl(slider(p, CX, y - 3, SLW, "rollSpeed", 2, 20, 1, function(v) return math.floor(v + 0.5) .. "s" end))

    L:section("TAPE")
    r = L:row("Film grain", "Fine moving noise over the picture.", { key = "grain" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "grainStrength", 0.05, 1, 0.05))
    r = L:row("Tracking glitches", "Random noisy bars and tear lines, like a worn tape. The slider sets how often.", { key = "tracking" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "trackingRate", 0.05, 1, 0.05))
    L:row("Bottom noise strip", "The fuzzy band along the bottom of a VHS picture.", { key = "noiseStrip" })

    local warn = L:note("", C.pink)
    onRefresh(function()
        warn:SetText(db().safe and "Reduce flashing is on (Settings page), so flicker, shimmer, rolling and glitches are paused." or "")
    end)
end)

page("TV moments", "VCR text, power, health", "TV moments",
    "Little touches that react to what happens in the game.",
function(L, p)
    local function test(r, fn)
        local b = button(p, "TEST", 70); b:SetPoint("TOPLEFT", CX, r.cy - 1)
        tooltip(b, "Test", "Plays it once now.")
        b:SetScript("OnClick", fn)
    end
    L:section("ON-SCREEN TEXT")
    local r = L:row("VCR text", "PLAY, REC or a clock in the corner, like a camcorder or video player.")
    segments(p, CX, r.cy, CW, "osd", ns.enums.osd, { "NONE", "PLAY", "REC", "CLOCK" })
    local y = r:Sub("Corner")
    segments(p, CX, y, CW, "osdCorner", ns.enums.osdCorner, { "TOP LEFT", "TOP RIGHT", "BOTTOM LEFT" })

    L:section("TV EVENTS")
    r = L:row("Power on / off", "Old-TV switch-on animation when you log in or turn the overlay on or off.", { key = "powerFx" })
    test(r, function()
        if not db().enabled then ns.SetEnabled(true, true); return end
        ns.PowerAnim(false, function() C_Timer.After(0.35, function() ns.PowerAnim(true) end) end)
    end)
    r = L:row("Channel change", "A static burst and a channel number when you change zone. Skipped in combat.", { key = "channelFx" })
    test(r, function() ns.ChannelFlash(true) end)

    L:section("HEALTH")
    r = L:row("Low health static", "Static and glitches build up below half health.", { key = "lowHealth" })
    r:Ctl(slider(p, CX, r.cy - 3, SLW, "lowHealthStrength", 0.05, 1, 0.05))
    r = L:row("Big-hit flicker", "Signal-loss flicker when one hit takes 8% or more of your health.", { key = "hitFx" })
    test(r, function() ns.hitBurst = 1 end)
end)

local CTX_DESC = {
    combat = "While you're fighting.", raid = "Inside raid instances.", dungeon = "Dungeons, delves and scenarios.",
    pvp = "Battlegrounds and arenas.", resting = "Cities and inns.",
}
page("Auto", "Looks per situation", "Auto",
    "Change the look by situation. The highest row that applies wins. Your saved settings are never changed.",
function(L, p)
    L:section("SITUATIONS")
    for _, c in ipairs(ns.CONTEXTS) do
        local r = L:row(c.label, CTX_DESC[c.key])
        local b = pillButton(p, CW, 24, "", 12)
        b:SetPoint("TOPLEFT", CX, r.cy)
        local arrow = text(b, "v", 11, C.cyan); arrow:SetPoint("RIGHT", -10, 0)
        local function cur() return db().auto[c.key] or "none" end
        b:SetScript("OnClick", function()
            if menu and menu:IsShown() and menu.owner == b then closeMenu(); return end
            openMenu(b, ns.RuleChoices(), ns.RuleLabel, cur(), function(v)
                db().auto[c.key] = v; ns.Apply(); ns.Refresh()
            end)
            menu.owner = b
        end)
        b:SetScript("OnEnter", function() b:Paint(cur() ~= "none", true) end)
        b:SetScript("OnLeave", function() b:Paint(cur() ~= "none") end)
        onRefresh(function()
            b.txt:SetText(ns.RuleLabel(cur()))
            b:Paint(cur() ~= "none")
            r.title:SetTextColor(rgb(cur() ~= "none" and C.text or C.dim))
        end)
    end
    L:section("RIGHT NOW")
    local now = L:note("", C.cyan)
    onRefresh(function()
        if ns.ctxNow and ns.ruleNow ~= "none" then
            now:SetText(ns.ctxNow .. "  >  " .. ns.RuleLabel(ns.ruleNow))
        else
            now:SetText("No rule applies, so you see your normal look.")
        end
    end)
    L:note("Choices: No change, Turn off, Half strength, or any preset.")
end)

page("Settings", "Layer, sharing, keys", "Settings",
    "General options, sharing looks with friends, key bindings and reset.",
function(L, p)
    L:section("GENERAL")
    local r = L:row("Draw over", "Game world keeps your bars and text crisp. Everything also covers the UI.")
    segments(p, CX, r.cy, CW, "layer", { "world", "all" }, { "GAME WORLD", "EVERYTHING" })
    r = L:row("Minimap button", "Left-click opens this window, right-click turns the overlay on or off, wheel flips presets.")
    switch(p, CX, r.cy - 1, function() return not db().minimap.hide end,
        function(v) db().minimap.hide = not v; ns.UpdateMinimap(); ns.Refresh() end)
    L:row("Reduce flashing", "Pauses flicker, shimmer, rolling, glitches and static flashes. Also /crt safe.",
        { key = "safe", tip = "Turns off flicker, refresh shimmer, interlacing, the rolling band, tracking glitches,\nlow-health static, hit flicker and channel static, and makes power on/off a plain fade.\nYour other settings are kept." })

    L:section("SHARE")
    r = L:row("Share your look", "Click the code, press Ctrl+C and send it. It fits in a chat message.")
    local out = editbox(p, CW, 26); out:SetPoint("TOPLEFT", CX, r.cy)
    out.eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    out.eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(ns.Export()); self:HighlightText() end end)
    onRefresh(function() out.eb:SetText(ns.Export()); out.eb:SetCursorPosition(0) end)
    r = L:row("Load a look", "Paste a code from a friend and press LOAD. Your Draw over setting stays as it is.")
    local inp = editbox(p, CW - 80, 26); inp:SetPoint("TOPLEFT", CX, r.cy)
    local go = button(p, "LOAD", 72); go:SetPoint("LEFT", inp, "RIGHT", 8, 0)
    local res = text(p, "", 11, C.cyan); res:SetPoint("TOPLEFT", inp, "BOTTOMLEFT", 4, -4)
    local function doImport()
        local n, err = ns.Import(inp.eb:GetText())
        if n then
            res:SetTextColor(rgb(C.cyan)); res:SetText("Loaded. Save it on the Presets page to keep it.")
            inp.eb:SetText(""); inp.eb:ClearFocus()
        else
            res:SetTextColor(rgb(C.pink)); res:SetText("Didn't work: " .. err)
        end
    end
    go:SetScript("OnClick", doImport)
    inp.eb:SetScript("OnEnterPressed", doImport)
    L.y = L.y - 8

    L:section("KEYS")
    L:note("Bind keys in Game Menu > Options > Keybindings > AddOns > Retrovision: overlay on/off, open settings, next and previous preset. Type /crt help for chat commands.")

    L:section("RESET")
    r = L:row("Reset everything", "Back to the default look. Saved presets, minimap spot and window position are kept.")
    local reset = button(p, "RESET", 96); reset:SetPoint("TOPLEFT", CX, r.cy - 1)
    reset:SetScript("OnClick", function() SlashCmdList.RETROVISION("reset") end)
end)

---------------------------------------------------------------- window

local function build()
    win = CreateFrame("Frame", "RetrovisionOptions", UIParent)
    win:SetSize(W, H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true); win:SetMovable(true); win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, rel, x, y = self:GetPoint(1)
        db().window = { pt, rel, x, y }
    end)
    win:SetScript("OnHide", closeMenu)
    local pos = db().window
    if type(pos) == "table" and pos[1] then
        win:ClearAllPoints(); win:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    end
    tinsert(UISpecialFrames, "RetrovisionOptions")

    -- outer neon halo + body
    local halo = sliced(win, "panelglow", 32, "BACKGROUND", -8)
    halo:SetPoint("TOPLEFT", -24, 24); halo:SetPoint("BOTTOMRIGHT", 24, -24)
    halo:SetVertexColor(rgb(C.pink)); halo:SetAlpha(0.55)
    local body = sliced(win, "round6", 6, "BACKGROUND", -7); body:SetAllPoints()
    body:SetGradient("VERTICAL", CreateColor(rgb(C.bg)), CreateColor(rgb(C.bg2)))
    local border = sliced(win, "round6line", 6, "BACKGROUND", -3); border:SetAllPoints()
    border:SetVertexColor(rgb(C.pink, 0.9))

    -- sidebar panel + divider
    local side = win:CreateTexture(nil, "BACKGROUND", nil, -6)
    side:SetPoint("TOPLEFT", 2, -2); side:SetPoint("BOTTOMLEFT", 2, 2); side:SetWidth(SB - 2)
    side:SetColorTexture(rgb(C.side, 0.9))
    local div = win:CreateTexture(nil, "BACKGROUND", nil, -5)
    div:SetPoint("TOPLEFT", SB, -2); div:SetPoint("BOTTOMLEFT", SB, 2); div:SetWidth(1)
    div:SetColorTexture(1, 1, 1, 1)
    div:SetGradient("VERTICAL", CreateColor(rgb(C.violet, 0.1)), CreateColor(rgb(C.pink, 0.6)))

    -- synthwave grid, faint, under the page
    local grid = win:CreateTexture(nil, "BACKGROUND", nil, -4)
    grid:SetTexture(MEDIA .. "grid")
    grid:SetPoint("BOTTOMLEFT", SB + 1, 2); grid:SetPoint("BOTTOMRIGHT", -2, 2); grid:SetHeight(90)
    grid:SetVertexColor(rgb(C.violet)); grid:SetAlpha(0.22)

    -- brand
    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(MEDIA .. "icon"); logo:SetSize(34, 34)
    logo:SetPoint("TOPLEFT", 16, -18)
    local title = text(win, "RETROVISION", 17, C.pink)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 8, -2)
    title:SetShadowColor(rgb(C.hot, 0.8)); title:SetShadowOffset(0, 0)
    local tglow = win:CreateTexture(nil, "BORDER")
    tglow:SetTexture(MEDIA .. "glowdot"); tglow:SetBlendMode("ADD")
    tglow:SetPoint("CENTER", title, "CENTER"); tglow:SetSize(170, 44)
    tglow:SetVertexColor(rgb(C.pink)); tglow:SetAlpha(0.22)
    local sub = text(win, "CRT  ·  VHS  ·  OLD MONITORS", 8, C.cyan)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)

    -- page header (right side)
    local pTitle = text(win, "", 22, C.pink); pTitle:SetPoint("TOPLEFT", PX, -22)
    pTitle:SetShadowColor(rgb(C.hot, 0.6)); pTitle:SetShadowOffset(0, 0)
    local pDesc = text(win, "", 11, C.desc); pDesc:SetPoint("TOPLEFT", PX, -52)
    pDesc:SetWidth(PW - 30); pDesc:SetJustifyH("LEFT"); pDesc:SetWordWrap(true)

    local close = CreateFrame("Button", nil, win)
    close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -10, -10)
    close.txt = text(close, "×", 22, C.mute); close.txt:SetPoint("CENTER", 0, 1)
    close:SetScript("OnEnter", function() close.txt:SetTextColor(rgb(C.hot)) end)
    close:SetScript("OnLeave", function() close.txt:SetTextColor(rgb(C.mute)) end)
    close:SetScript("OnClick", function() win:Hide() end)

    -- pages + sidebar nav
    local pages, navs = {}, {}
    local function select(i)
        win.tab = i; db().page = i
        closeMenu()
        for n, pg in ipairs(pages) do pg:SetShown(n == i) end
        for n, b in ipairs(navs) do b:Paint(n == i) end
        pTitle:SetText(PAGES[i].title); pDesc:SetText(PAGES[i].desc)
    end
    local NAV_TOP, NAV_H = -78, 46
    for i, pgDef in ipairs(PAGES) do
        local b = CreateFrame("Button", nil, win)
        b:SetSize(SB - 20, NAV_H - 4); b:SetPoint("TOPLEFT", 10, NAV_TOP - (i - 1) * NAV_H)
        local bg = sliced(b, "round6", 6, "BACKGROUND"); bg:SetAllPoints()
        local bar = b:CreateTexture(nil, "ARTWORK"); bar:SetColorTexture(1, 1, 1, 1)
        bar:SetPoint("TOPLEFT", 0, -8); bar:SetPoint("BOTTOMLEFT", 0, 8); bar:SetWidth(3)
        bar:SetGradient("VERTICAL", CreateColor(rgb(C.cyan)), CreateColor(rgb(C.pink)))
        local name = text(b, pgDef.name, 13, C.dim); name:SetPoint("TOPLEFT", 14, -7)
        local hint = text(b, pgDef.hint, 10, C.mute); hint:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        function b:Paint(on, hover)
            bg:SetVertexColor(rgb(on and C.pink or C.bg2, on and 0.16 or (hover and 0.9 or 0)))
            bar:SetShown(on)
            name:SetTextColor(rgb((on or hover) and C.text or C.dim))
            hint:SetTextColor(rgb(on and C.desc or C.mute))
        end
        b:SetScript("OnClick", function() select(i); ns.Refresh() end)
        b:SetScript("OnEnter", function() b:Paint(win.tab == i, true) end)
        b:SetScript("OnLeave", function() b:Paint(win.tab == i) end)
        navs[i] = b

        local pg = CreateFrame("Frame", nil, win)
        pg:SetPoint("TOPLEFT", PX, PAGE_TOP); pg:SetSize(PW, AVAIL)
        local L = newLayout(pg, pgDef.name)
        pgDef.build(L, pg)
        L:done()
        pages[i] = pg
    end

    -- power block at the bottom of the sidebar
    local pwrLabel = text(win, "OVERLAY", 10, C.cyan); pwrLabel:SetPoint("BOTTOMLEFT", 18, 104)
    local psw = switch(win, 18, -(H - 98), function() return db().enabled end, function(v) ns.SetEnabled(v, true) end)
    tooltip(psw, "Overlay", "Turns every effect on or off. Same as right-clicking the minimap button.")
    local pState = text(win, "", 13); pState:SetPoint("LEFT", psw, "RIGHT", 10, 0)
    local look = text(win, "", 10, C.desc); look:SetPoint("TOPLEFT", 18, -(H - 66))
    look:SetWidth(SB - 30); look:SetJustifyH("LEFT"); look:SetWordWrap(false)
    local autoL = text(win, "", 10, C.cyan); autoL:SetPoint("TOPLEFT", look, "BOTTOMLEFT", 0, -4)
    autoL:SetWidth(SB - 30); autoL:SetJustifyH("LEFT"); autoL:SetWordWrap(false)
    local help = text(win, "/crt help", 9, C.mute); help:SetPoint("BOTTOMLEFT", 18, 12)
    onRefresh(function()
        local on = db().enabled
        pState:SetText(on and "ON" or "OFF"); pState:SetTextColor(rgb(on and C.text or C.mute))
        look:SetText("Look: " .. (db().activePreset or "custom"))
        if ns.ruleNow and ns.ruleNow ~= "none" then autoL:SetText("Auto: " .. (ns.ctxNow or "") .. " > " .. ns.RuleLabel(ns.ruleNow))
        else autoL:SetText("") end
        local a = on and 1 or 0.45
        for _, pg in ipairs(pages) do pg:SetAlpha(a) end
    end)

    local start = tonumber(db().page)
    select((start and PAGES[start]) and start or 1)
end

function ns.Refresh()
    if not win then return end
    -- stay above the overlay when it draws over everything (it sits at TOOLTIP level 9000)
    if db().layer == "all" then win:SetFrameStrata("TOOLTIP"); win:SetFrameLevel(9100)
    else win:SetFrameStrata("DIALOG") end
    for _, fn in ipairs(refreshers) do fn() end
end

function ns.ToggleOptions()
    if not win then build(); win:Show()
    elseif win:IsShown() then win:Hide()
    else win:Show() end
    ns.Refresh()
end
