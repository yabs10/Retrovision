-- Offline harness: fake WoW API, loads the addon like the client, fires events,
-- runs OnUpdate ticks, and clicks every button/switch in the settings window.
local all, scripts = {}, {}
local Obj = {}
-- Real WoW widget methods that may stay no-ops here. Anything not in Obj or this list is a typo -> error.
local NOOP = {}
for m in ([[SetPoint ClearAllPoints SetAllPoints SetTexture SetColorTexture SetVertexColor SetBlendMode
  SetTextureSliceMargins SetTextureSliceMode SetFrameStrata SetIgnoreParentAlpha SetIgnoreParentScale
  EnableMouse EnableMouseWheel SetMovable StartMoving StopMovingOrSizing RegisterForClicks RegisterForDrag
  SetEnabled SetHitRectInsets SetClampedToScreen SetToplevel SetTextColor SetShadowColor SetShadowOffset
  SetJustifyH SetJustifyV SetWordWrap SetOrientation SetMinMaxValues SetValueStep SetObeyStepOnDrag
  SetThumbTexture SetAutoFocus SetCursorPosition HighlightText ClearFocus SetFocus SetMaxLetters
  SetOwner AddLine AddDoubleLine SetDrawLayer SetDesaturated SetRotation SetSnapToPixelGrid SetTexelSnappingBias
  UnregisterEvent UnregisterAllEvents Raise Lower SetParent SetMouseClickEnabled SetMouseMotionEnabled
  SetPropagateMouseClicks SetPropagateMouseMotion SetClipsChildren SetHorizTile SetVertTile]]):gmatch("%S+") do NOOP[m] = true end
local function noop() end
Obj.__index = function(t, k)
  local v = rawget(Obj, k); if v then return v end
  if NOOP[k] then return noop end
  if type(k) ~= "string" or not k:match("^%u") then return nil end   -- plain data fields (b.txt, o.parent...)
  error("harness: unknown widget method " .. tostring(k), 2)
end
local function new(kind, parent)
  local o = setmetatable({ kind = kind, parent = parent, shown = true, alpha = 1, text = "", h = 0, w = 0, scripts = {}, events = {} }, Obj)
  all[#all + 1] = o; return o
end
function Obj:CreateTexture() return new("Texture", self) end
function Obj:CreateFontString() return new("FontString", self) end
function Obj:SetScript(n, fn) self.scripts[n] = fn end
function Obj:HookScript(n, fn) local old = self.scripts[n]; self.scripts[n] = function(...) if old then old(...) end fn(...) end end
function Obj:GetScript(n) return self.scripts[n] end
function Obj:RegisterEvent(e) self.events[e] = true end
function Obj:RegisterUnitEvent(e) self.events[e] = true end
function Obj:GetHeight() return 768 end
function Obj:GetWidth() return 1436 end
function Obj:GetSize() return 1436, 768 end
function Obj:GetEffectiveScale() return 1 end
function Obj:SetFrameLevel(l) self.level = l end
function Obj:SetFrameStrata(s) self.strata = s end
function Obj:GetFrameStrata() return self.strata or "MEDIUM" end
function Obj:SetScale(k) self.scale = k end
function Obj:GetScale() return self.scale or 1 end
function Obj:IsObjectType(t) if t == "Frame" then return self.kind ~= "Texture" and self.kind ~= "FontString" end return self.kind == t end
function Obj:GetObjectType() return self.kind end
function Obj:IsMouseEnabled() return true end
function Obj:IsEnabled() return true end
function Obj:GetParent() return self.parent end
function Obj:SetParent(p) self.parent = p end
function Obj:GetName() return self.name end
function Obj:GetChildren() return end
-- anchors are recorded so UIParent moves and window positions can be checked
function Obj:SetPoint(pt, a, b, c, d)
  self.points = self.points or {}
  local rel, rp, x, y = a, b, c, d
  if type(a) == "number" or a == nil then rel, rp, x, y = self.parent, pt, a or 0, b or 0 end
  if type(rel) == "string" then rel = _G[rel] end
  self.points[#self.points + 1] = { pt, rel, rp or pt, x or 0, y or 0 }
end
function Obj:ClearAllPoints() self.points = {}; self.allPoints = nil end
function Obj:SetAllPoints(rel) self.points = {}; self.allPoints = rel or self.parent or true end
function Obj:GetNumPoints() return self.points and #self.points or 0 end
function Obj:GetPoint(i) local p = self.points and self.points[i or 1]; if p then return unpack(p) end end
function Obj:GetFrameLevel() return self.level or 1 end
function Obj:GetFont() return "font", self.fsize or 12 end
function Obj:SetFont(_, s) self.fsize = s; return true end
function Obj:Show() self.shown = true end
function Obj:Hide() self.shown = false end
function Obj:SetShown(v) self.shown = not not v end
function Obj:IsShown() return self.shown end
function Obj:SetAlpha(a) assert(type(a) == "number" and a == a, "bad alpha") self.alpha = a end
function Obj:GetAlpha() return self.alpha end
function Obj:SetText(t) self.text = t end
function Obj:GetText() return self.text end
function Obj:SetValue(v) assert(type(v) == "number", "slider value not a number"); self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v, false) end end
function Obj:GetValue() return self.value or 0 end
function Obj:HasFocus() return false end
function Obj:IsMouseOver() return false end
function Obj:SetHeight(h) assert(h == h and h >= 0, "bad height " .. tostring(h)) end
function Obj:SetWidth(w) assert(w == w and w >= 0, "bad width " .. tostring(w)) end
function Obj:SetSize(w, h) assert(w == w and h == h, "bad size") end
function Obj:SetTexCoord(...) for _, v in ipairs({...}) do assert(v == v, "NaN texcoord") end end
function Obj:SetGradient(o, a, b) assert(a and b, "gradient needs colors") end

CreateFrame = function(kind, name, parent) local o = new(kind, parent); o.name = name; if name then _G[name] = o end; return o end
WorldFrame, UIParent, GameTooltip = new("Frame"), new("Frame"), new("Frame")
UIParent:SetAllPoints()
GetPhysicalScreenSize = function() return 2552, 1364 end
CreateColor = function(r, g, b, a) return { r, g, b, a } end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
C_AddOns = { DoesAddOnExist = function() return true end }
C_Timer = { After = function(_, fn) fn() end }
Enum = { UITextureSliceMode = { Stretched = 0 } }
UISpecialFrames, SlashCmdList = {}, {}
tinsert = table.insert; wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
local now = 100; GetTime = function() return now end
local inst, resting, hp = "none", false, 1000
IsInInstance = function() return inst ~= "none", inst end
IsResting = function() return resting end
UnitAffectingCombat = function() return false end
local combat = false
InCombatLockdown = function() return combat end
UnitHealth = function() return hp end
UnitHealthMax = function() return 1000 end
UnitIsDeadOrGhost = function() return false end
GetRealZoneText = function() return "Elwynn Forest" end
local out = {}
print = function(...) out[#out + 1] = table.concat({...}, " ") end

local MAY_BE_NIL = { RetrovisionDB = true, RetrovisionOptions = true, issecretvalue = true, LibStub = true }
setmetatable(_G, { __index = function(_, k)
  if MAY_BE_NIL[k] then return nil end
  error("harness: unknown global " .. tostring(k), 2)
end })

-- LibStub-free load (libs need the real client); minimap code must cope.
local ns = {}
for _, f in ipairs{ "Core.lua", "Auto.lua", "FX.lua", "Options.lua" } do assert(loadfile("Retrovision/" .. f))("Retrovision", ns) end

local function fire(e, ...)
  for _, o in ipairs(all) do if o.events[e] and o.scripts.OnEvent then o.scripts.OnEvent(o, e, ...) end end
end
local function tick(n, dt)
  for _ = 1, n do now = now + (dt or 0.016); for _, o in ipairs(all) do if o.scripts.OnUpdate then o.scripts.OnUpdate(o, dt or 0.016) end end end
end

fire("ADDON_LOADED", "Retrovision")
fire("PLAYER_ENTERING_WORLD", true, false)
tick(80)
assert(RetrovisionDB.enabled and RetrovisionOverlay.shown, "overlay should be on")

-- every preset applies and draws
for _, n in ipairs(ns.PresetNames()) do assert(ns.ApplyPreset(n), n); tick(10) end
assert(RetrovisionDB.activePreset == "Handheld" and RetrovisionDB.maskType == "grid" and RetrovisionDB.tint == "lcd")
ns.ApplyPreset("VHS"); assert(RetrovisionDB.tracking and RetrovisionDB.osd == "play" and RetrovisionDB.aspect == "full")
-- monitor pack: every skin x aspect x mask type x refresh, degauss, monitor menu
for _, st in ipairs{ "plain", "beige", "black" } do
  for _, asp in ipairs{ "full", "4:3" } do
    for _, mt in ipairs{ "stripe", "dot", "lcd", "grid" } do
      RetrovisionDB.bezel, RetrovisionDB.bezelStyle, RetrovisionDB.aspect, RetrovisionDB.maskType = true, st, asp, mt
      RetrovisionDB.mask, RetrovisionDB.maskSize, RetrovisionDB.interlace, RetrovisionDB.refresh = true, 2, true, 60
      RetrovisionDB.glare, RetrovisionDB.viewAngle, RetrovisionDB.backlightBleed, RetrovisionDB.brightness, RetrovisionDB.blackLevel = true, true, true, 0.7, 0.5
      ns.Apply(); tick(5)
    end
  end
end
assert(ns.inset.b > ns.inset.t, "monitor chin thicker than top")
ns.Degauss(); tick(200); ns.MonitorOSD("Brightness", 0.7, "70"); tick(150)
ns.ApplyPreset("2004 CRT"); tick(10)

-- save / delete custom preset
assert(ns.SavePreset("Mine")); assert(RetrovisionDB.presets.Mine)
local names = ns.PresetNames(); assert(names[#names] == "Mine")

-- share round trip
ns.ApplyPreset("80s TV")
local s = ns.Export()
ns.ApplyPreset("Subtle")
assert(s:sub(1, 4) == "RV1:", "new share format")
assert(ns.Import(s) > 10); assert(RetrovisionDB.bezel and RetrovisionDB.tint == "warm", "import restored look")
assert(ns.Export() == s, "export stable")
assert(not ns.Import("garbage")); assert(not ns.Import("SCL1:foo=1"))
ns.Import("SCL1:scanStrength=99;tint=pizza;bezel=1")
assert(RetrovisionDB.scanStrength == 1 and RetrovisionDB.tint == "warm", "import clamps / rejects")

-- auto rules
RetrovisionDB.auto.combat = "off"; RetrovisionDB.auto.raid = "preset:Amber"; RetrovisionDB.auto.resting = "dim"
fire("PLAYER_REGEN_DISABLED"); assert(ns.ruleNow == "off" and not RetrovisionOverlay.shown, "combat off")
fire("PLAYER_REGEN_ENABLED"); assert(ns.ruleNow == "none" and RetrovisionOverlay.shown)
inst = "raid"; fire("ZONE_CHANGED_NEW_AREA"); tick(30); assert(RetrovisionOverlay.alpha == nil or RetrovisionOverlay.alpha == 1, "dip ends at full alpha"); assert(ns.S.tint == "amber" and RetrovisionDB.tint == "warm", "raid preset w/o touching db")
inst = "none"; resting = true; fire("PLAYER_UPDATE_RESTING"); tick(30); assert(math.abs(ns.S.scanStrength - RetrovisionDB.scanStrength * 0.5) < 1e-9)
resting = false; fire("PLAYER_UPDATE_RESTING"); tick(30)
ns.DeletePreset("Mine")

-- low health + hit
RetrovisionDB.lowHealth, RetrovisionDB.hitFx = true, true; ns.Apply()
hp = 900; fire("UNIT_HEALTH", "player"); hp = 150; fire("UNIT_HEALTH", "player")
assert(ns.hitBurst == 1, "big hit registered"); tick(60)
issecretvalue = function() return true end; fire("UNIT_HEALTH", "player"); issecretvalue = nil

-- power anim off/on, channel flash
ns.SetEnabled(false, true); assert(ns.PowerBusy(), "anim running"); Retrovision_Toggle(); Retrovision_Toggle(); tick(90, 0.016); assert(not RetrovisionDB.enabled and not RetrovisionOverlay.shown, "anim turned it off")
ns.SetEnabled(true, true); tick(60); assert(RetrovisionDB.enabled)
RetrovisionDB.channelFx = true; fire("ZONE_CHANGED_NEW_AREA"); tick(200)

-- settings window: open, click everything on every tab, both mouse buttons, wheel sliders
SlashCmdList.RETROVISION("")
assert(RetrovisionOptions and RetrovisionOptions.shown)
for round = 1, 2 do
  for i = 1, #all do
    local o = all[i]
    if o.scripts.OnClick and o.kind ~= "CheckButton" then o.scripts.OnClick(o, round == 1 and "LeftButton" or "RightButton") end
    if o.scripts.OnEnter then o.scripts.OnEnter(o) end
    if o.scripts.OnLeave then o.scripts.OnLeave(o) end
    if o.kind == "Slider" and o.scripts.OnMouseWheel then o.scripts.OnMouseWheel(o, 1); o.scripts.OnValueChanged(o, o.value or 0.5, true) end
    tick(1)
  end
end
tick(120)
for _, c in ipairs{ "help", "preset", "preset vhs", "next", "prev", "minimap", "minimap", "off", "on", "reset" } do SlashCmdList.RETROVISION(c); tick(70) end
assert(RetrovisionDB.presets and RetrovisionDB.minimap, "reset keeps presets + minimap")
assert(RetrovisionDB.window == nil or type(RetrovisionDB.window) == "table")

---------------------------------------------------------------- v3.1 checks
local LOOK = ns.LOOK_KEYS
local function snap() local t = {} for _, k in ipairs(LOOK) do t[k] = RetrovisionDB[k] end return t end
local function same(a, b, what) for _, k in ipairs(LOOK) do
  local x, y = a[k], b[k]
  if type(x) == "number" then assert(math.abs(x - y) < 0.006, what .. ": " .. k) else assert(x == y, what .. ": " .. k .. " " .. tostring(x) .. " vs " .. tostring(y)) end
end end

-- scanline spacing 2/3/4/6 (+ interlace, degauss shake), bad values snap
for _, sp in ipairs{ 2, 3, 4, 6 } do RetrovisionDB.scan, RetrovisionDB.scanPeriod, RetrovisionDB.interlace = true, sp, true; ns.Apply(); tick(20) end
ns.Degauss(); tick(150)
assert(ns.Import("RV1:sc=1;sp=5") and RetrovisionDB.scanPeriod ~= 5, "scanPeriod snaps")

-- share strings: every built-in fits in chat and round-trips; layer never imported
for _, n in ipairs(ns.PresetNames()) do
  ns.ApplyPreset(n); local want = snap(); local str = ns.Export()
  assert(#str < 255, n .. " export too long: " .. #str)
  RetrovisionDB.layer = "all"; ns.ApplyPreset("Handheld" == n and "VHS" or "Handheld")
  assert(ns.Import(str) ~= nil or str == "RV1:", n .. " import failed")
  same(want, snap(), "round trip " .. n)
  assert(RetrovisionDB.layer == "all", "import left layer alone")
end
RetrovisionDB.layer = "world"
assert(ns.Import("SCL1:scan=1;layer=all") and RetrovisionDB.layer == "world", "SCL1 layer ignored")

-- old custom preset missing newer keys still sets the whole look
RetrovisionDB.presets.Old = { scan = true, scanStrength = 0.5 }
RetrovisionDB.aspect, RetrovisionDB.bezelStyle, RetrovisionDB.glare = "4:3", "beige", true
ns.ApplyPreset("Old")
assert(RetrovisionDB.aspect == "full" and RetrovisionDB.bezelStyle == "plain" and not RetrovisionDB.glare and RetrovisionDB.scanStrength == 0.5, "old preset fills gaps")
ns.DeletePreset("Old")

-- built-in names can't be overwritten; empty names refused
local ok, why = ns.SavePreset("subtle"); assert(not ok and why, "built-in name refused")
ok, why = ns.SavePreset("   "); assert(not ok and why, "empty name refused")

-- flashing safety
ns.ApplyPreset("VHS"); RetrovisionDB.flicker, RetrovisionDB.refresh, RetrovisionDB.channelFx = true, 60, true
SlashCmdList.RETROVISION("safe"); tick(5)
assert(RetrovisionDB.safe and not ns.S.flicker and ns.S.refresh == 0 and not ns.S.tracking and not ns.S.roll and not ns.S.channelFx, "safe overrides")
assert(RetrovisionDB.flicker and RetrovisionDB.refresh == 60, "safe keeps saved settings")
ns.ChannelFlash(true); assert(ns.staticBurst == 0, "no static flash in safe mode"); tick(200)
ns.SetEnabled(false, true); tick(90); ns.SetEnabled(true, true); tick(90); assert(RetrovisionDB.enabled and not ns.PowerBusy())
SlashCmdList.RETROVISION("safe"); tick(5); assert(not RetrovisionDB.safe and ns.S.flicker)

-- 30 custom presets: grid pages, nothing lost
for i = 1, 30 do assert(ns.SavePreset(string.format("Look %02d", i))) end
ns.Refresh()
local pager
for _, o in ipairs(all) do if o.kind == "FontString" and o.text == "1 / 4" then pager = o end end
assert(pager and pager.shown, "pager shows 1 / 4")
for _, o in ipairs(all) do if o.kind == "Button" and o.scripts.OnClick and o.parent == pager.parent then end end
for i = 1, 30 do ns.DeletePreset(string.format("Look %02d", i)) end
ns.Refresh(); assert(not pager.shown, "pager hides with one page")

-- window position saved on drag, kept by reset; window rises above overlay in "everything" mode
local win = RetrovisionOptions
win:ClearAllPoints(); win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
win.scripts.OnDragStop(win)
assert(RetrovisionDB.window and RetrovisionDB.window[1] == "TOPLEFT" and RetrovisionDB.window[3] == 120, "window spot saved")
SlashCmdList.RETROVISION("reset"); tick(10); assert(RetrovisionDB.window and RetrovisionDB.window[3] == 120, "reset keeps window spot")
RetrovisionDB.layer = "all"; ns.Apply(); ns.Refresh(); assert(win.level > 9000, "window above overlay")
assert(RetrovisionOverlay.parent == UIParent and RetrovisionOverlay.strata == "TOOLTIP", "everything = on UIParent, top strata")
assert(RetrovisionOSD.parent == UIParent, "VCR text follows to UIParent")
RetrovisionDB.layer = "world"; ns.Apply(); ns.Refresh()
assert(RetrovisionOverlay.parent == WorldFrame and RetrovisionOverlay.strata == "BACKGROUND", "game world = on WorldFrame")
assert(RetrovisionOSD.parent == WorldFrame, "VCR text back on WorldFrame")

-- dimmed controls are blocked: a switched-off effect gets an invisible mouse catcher
RetrovisionDB.roll = false; ns.Refresh()
local blockers = 0
for _, o in ipairs(all) do if o.kind == "Frame" and o.scripts.OnMouseWheel and o.shown and o.parent and o.parent.kind ~= "Frame" then blockers = blockers + 1 end end
assert(blockers > 0, "dimmed controls blocked")

-- every settings page fits the window
for _, r in ipairs(ns.layoutReport) do
  assert(r.used <= r.avail, string.format("page %s too tall: %d of %d", r.name, r.used, r.avail))
  io.write(string.format("  page %-11s %3d / %d px\n", r.name, r.used, r.avail))
end
-- overall strength scales effects without touching the look
ns.ApplyPreset("80s TV"); RetrovisionDB.intensity = 0.5; ns.Apply()
assert(math.abs(ns.S.scanStrength - RetrovisionDB.scanStrength * 0.5) < 1e-9 and RetrovisionDB.activePreset == "80s TV", "intensity")
RetrovisionDB.intensity = 1; ns.Apply()

print("ALL OK")
io.write(table.concat(out, "\n"), "\n")
