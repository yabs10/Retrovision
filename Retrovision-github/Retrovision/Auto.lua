-- Retrovision: auto rules (per situation) and share strings.
local ADDON, ns = ...

---------------------------------------------------------------- auto rules

-- Highest priority first; the first situation that applies AND has a rule wins.
ns.CONTEXTS = {
    { key = "combat",  label = "In combat" },
    { key = "raid",    label = "Raids" },
    { key = "dungeon", label = "Dungeons" },
    { key = "pvp",     label = "Battlegrounds / arena" },
    { key = "resting", label = "Cities / resting" },
}

local inCombat = false

local function applies(key)
    if key == "combat" then return inCombat end
    local _, itype = IsInInstance()
    if key == "raid" then return itype == "raid" end
    if key == "dungeon" then return itype == "party" or itype == "scenario" end
    if key == "pvp" then return itype == "pvp" or itype == "arena" end
    if key == "resting" then return IsResting() and true or false end
end

function ns.ActiveRule()
    local auto = RetrovisionDB.auto
    for _, c in ipairs(ns.CONTEXTS) do
        local rule = auto[c.key] or "none"
        if rule ~= "none" and applies(c.key) then return rule, c.label end
    end
    return "none", nil
end

-- Choices offered for every situation.
function ns.RuleChoices()
    local out = { "none", "off", "dim" }
    for _, n in ipairs(ns.PresetNames()) do out[#out + 1] = "preset:" .. n end
    return out
end

function ns.RuleLabel(rule)
    if rule == "none" then return "No change" end
    if rule == "off" then return "Turn off" end
    if rule == "dim" then return "Half strength" end
    if rule:sub(1, 7) == "preset:" then return rule:sub(8) end
    return rule
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, e)
    if not RetrovisionDB then return end
    if e == "PLAYER_REGEN_DISABLED" then inCombat = true
    elseif e == "PLAYER_REGEN_ENABLED" then inCombat = false
    elseif e == "PLAYER_ENTERING_WORLD" then inCombat = UnitAffectingCombat("player") and true or false end
    local before = ns.ruleNow
    local after = ns.ActiveRule()
    if after ~= before then
        if ns.SoftApply then ns.SoftApply()   -- quick dip instead of a hard snap
        else ns.Apply(); if ns.Refresh then ns.Refresh() end end
    end
end)

---------------------------------------------------------------- share strings

--[[ Share string formats.
RV1 (written now, same as the old SCL2):  RV1:al=value;al=value
  Only look keys whose value differs from the baseline are written. Baseline =
  ns.LookBaseline() (ns.defaults with ns.PresetBase on top, i.e. everything off).
  Keys use the fixed 2-letter aliases below (full key names are also accepted on import).
  Booleans are 1/0, numbers have at most 2 decimals with trailing zeros and a leading
  "0" dropped (".35"), strings are written as-is. Import resets every look key to the
  baseline first, then applies the listed keys. An empty body ("SCL2:") = everything off.
  Never change an existing alias; new keys get a new alias.
SCL1 (old, import only): SCL1:key=value;key=value  full key names, every key listed,
  only the listed keys change. A "layer" key in old strings is ignored.
]]
local ALIAS = {
    scan = "sc", scanStrength = "ss", scanPeriod = "sp", mask = "mk", maskLevel = "ml",
    maskType = "mt", maskSize = "mz", interlace = "il", refresh = "rf", vignette = "vg",
    vignetteStrength = "vs", flicker = "fl", flickerStrength = "fs", roll = "ro", rollStrength = "rs",
    rollSpeed = "rv", tint = "tn", tintStrength = "ts", grain = "gr", grainStrength = "gs",
    bezel = "bz", bezelThickness = "bt", bezelRadius = "br", bezelShadow = "bs", tracking = "tr",
    trackingRate = "tk", noiseStrip = "ns", osd = "os", osdCorner = "oc", aspect = "as",
    bezelStyle = "by", monitorSize = "mo", glare = "gl", glareStrength = "gg", brightness = "bn",
    blackLevel = "bl", viewAngle = "va", backlightBleed = "bb",
}
local LOOK, FROM_ALIAS = {}, {}
for _, k in ipairs(ns.LOOK_KEYS) do
    LOOK[k] = true; FROM_ALIAS[k] = k
    if ALIAS[k] then FROM_ALIAS[ALIAS[k]] = k end
end

local function enc(v)
    if type(v) == "boolean" then return v and "1" or "0" end
    if type(v) == "number" then
        local s = string.format("%.2f", v):gsub("%.?0+$", "")
        s = s:gsub("^0%.", "."):gsub("^%-0%.", "-.")
        if s == "" or s == "-" then s = "0" end
        return s
    end
    return tostring(v)
end

function ns.Export()
    local base = ns.LookBaseline()
    local parts = {}
    for _, k in ipairs(ns.LOOK_KEYS) do
        local v = enc(RetrovisionDB[k])
        if v ~= enc(base[k]) then parts[#parts + 1] = (ALIAS[k] or k) .. "=" .. v end
    end
    return "RV1:" .. table.concat(parts, ";")
end

local function inEnum(list, v) for _, x in ipairs(list) do if x == v then return true end end end

-- One value checked against the key's type, range and allowed words. nil = rejected.
local function parse(k, v)
    local def = ns.defaults[k]
    if type(def) == "boolean" then
        if v == "1" or v == "0" then return v == "1" end
    elseif type(def) == "number" then
        local n = tonumber(v)
        if not n or n ~= n then return end
        if k == "scanPeriod" then return ns.SnapPeriod(n) end
        local r = ns.ranges[k]
        if r then n = math.max(r[1], math.min(r[2], n)) end
        return n
    elseif type(def) == "string" then
        local list = ns.enums[k]
        if not list or inEnum(list, v) then return v end
    end
end

-- Returns number of settings applied, or nil + reason.
function ns.Import(str)
    str = (str or ""):gsub("%s", "")
    local ver, body = str:match("^SCL([12]):(.*)$")
    if not ver then body = str:match("^RV1:(.*)$"); if body then ver = "2" end end   -- RV1 = SCL2 format, new name
    if not ver then return nil, "not a Retrovision string" end
    local got, count = {}, 0
    for k, v in body:gmatch("([%w]+)=([^;]*)") do
        if ver == "1" then k = LOOK[k] and k or nil else k = FROM_ALIAS[k] end   -- "layer" is never a look key
        local val = k and parse(k, v)
        if val ~= nil then
            if got[k] == nil then count = count + 1 end
            got[k] = val
        end
    end
    if count == 0 and not (ver == "2" and body == "") then return nil, "nothing usable in that string" end
    if ver == "2" then
        local base = ns.LookBaseline()
        for _, k in ipairs(ns.LOOK_KEYS) do RetrovisionDB[k] = base[k] end
    end
    for k, v in pairs(got) do RetrovisionDB[k] = v end
    RetrovisionDB.activePreset = nil
    ns.Apply(); if ns.Refresh then ns.Refresh() end
    return count
end
