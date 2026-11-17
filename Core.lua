--[[
  Metrotank - Core.lua
  -------------------
  Sets up the shared "ns" table every file uses, the saved settings,
  the event system, slash commands and a few safe helper functions.

  IMPORTANT (WoW Forever / Midnight rules):
  Some combat values come back as "secret values" inside dungeons and raids.
  Addons may SHOW secret values (hand them to a texture or text) but may NOT
  compare them (if x == 3), do math on them, or use them to decide things.
  Every file checks values with ns.IsSecret() before using them in an "if".
]]

local ADDON_NAME, ns = ...
_G.Metrotank = ns -- handy for /dump Metrotank in game

ns.version = "0.1.0"

---------------------------------------------------------------------------
-- Default settings. Anything the player changes is saved in MetrotankDB.
---------------------------------------------------------------------------
ns.defaults = {
  general = {
    enabled   = true,
    tankMode  = "auto",   -- "auto", "always" or "off"
    debug     = false,
  },
  threat = {
    alertLost     = true,
    alertSlipping = true,
    lostSound     = "RAID_WARNING",
    slipSound     = "NONE",
    showBanner    = true,
    onlyInGroup   = false,
  },
  cc = {
    enabled          = true,
    alertWhenUnknown = true,  -- TODO: inside dungeons we can't tell "broke" from "ran out". 
    breakSound       = "MAP_PING",
    pingCount        = 2,
    showBanner       = true,
    flashSeconds     = 4,
  },
  plates = {
    border      = true,
    recolorBar  = true,   -- only for Blizzard's own nameplates
    showTag     = true,
    showIcon    = true,
    showArrow   = true,   -- yellow arrow above a mob you lost threat on
    pulseOnLost = true,
  },
  colors = {
    hold   = { r = 0.24, g = 0.81, b = 0.43 },
    slip   = { r = 0.95, g = 0.76, b = 0.19 },
    lost   = { r = 1.00, g = 0.30, b = 0.30 },
    other  = { r = 0.56, g = 0.48, b = 1.00 },
    cc     = { r = 0.78, g = 0.42, b = 1.00 },
    broken = { r = 1.00, g = 0.60, b = 0.24 },
  },
  sounds = {
    channel  = "Master",
    cooldown = 1.5,
  },
  taunt = {
    showOnBanner = true,
    spell        = "",   -- empty = pick automatically from your class
  },
  banners = {
    threatScale = 1,     -- size of the THREAT LOST banner (1 = normal)
    ccScale     = 1,     -- size of the CC BROKEN banner
    -- banners.threat / banners.cc hold the dragged positions (added when you drag them)
  },
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- issecretvalue() exists on the modern client. On older clients nothing is secret.
local issecret = _G.issecretvalue or function() return false end

function ns.IsSecret(value)
  return issecret(value) and true or false
end

-- Run a function and swallow errors (used around APIs that may change in beta).
function ns.Try(func, ...)
  local ok, a, b, c, d, e = pcall(func, ...)
  if ok then return a, b, c, d, e end
  ns.Debug("API error:", a)
  return nil
end

function ns.Print(...)
  print("|cff4fb3ffMetrotank|r:", ...)
end

-- Turn any value into text that is safe to join, print and save.
-- Secret values can't be converted or stored, so they become the word SECRET.
local function SafeText(value)
  if ns.IsSecret(value) then return "SECRET" end
  return tostring(value)
end

-- Debug lines are also kept in MetrotankDB.log so a whole test session can be
-- read from the SavedVariables file after a /reload. Oldest lines drop off.
local LOG_MAX = 400

local function SaveLog(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = SafeText((select(i, ...)))
  end
  local log = ns.db.log
  if type(log) ~= "table" then log = {}; ns.db.log = log end
  log[#log + 1] = string.format("%s (%.2f) %s", date("%H:%M:%S"), GetTime(), table.concat(parts, " "))
  while #log > LOG_MAX do table.remove(log, 1) end
end

function ns.Debug(...)
  if ns.db and ns.db.general.debug then
    print("|cff8b93a5Metrotank debug|r:", ...)
    pcall(SaveLog, ...) -- logging must never break the addon
  end
end

-- Copy defaults into the saved table without wiping what the player changed.
local function MergeDefaults(saved, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(saved[key]) ~= "table" then saved[key] = {} end
      MergeDefaults(saved[key], value)
    elseif saved[key] == nil then
      saved[key] = value
    end
  end
end

local function DeepCopy(t)
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = (type(v) == "table") and DeepCopy(v) or v
  end
  return copy
end
ns.DeepCopy = DeepCopy

-- Read/write a setting using a path like {"threat", "alertLost"}.
function ns.Get(path)
  local node = ns.db
  for i = 1, #path do
    if type(node) ~= "table" then return nil end
    node = node[path[i]]
  end
  return node
end

function ns.Set(path, value)
  local node = ns.db
  for i = 1, #path - 1 do node = node[path[i]] end
  node[path[#path]] = value
  ns:Fire("SETTING_CHANGED", path, value)
end

function ns.ResetSection(section)
  if ns.defaults[section] then
    ns.db[section] = DeepCopy(ns.defaults[section])
    ns:Fire("SETTING_CHANGED", { section }, nil)
  end
end

---------------------------------------------------------------------------
-- Tank detection
---------------------------------------------------------------------------
local TANK_CLASSES = { WARRIOR = true, PALADIN = true, DRUID = true }

function ns.IsTank()
  local mode = ns.db.general.tankMode
  if mode == "always" then return true end
  if mode == "off" then return false end

  -- "auto": trust the group role if one is set...
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
  if role == "TANK" then return true end
  if role == "HEALER" or role == "DAMAGER" then return false end

  -- ...otherwise assume a tank-capable class is tanking.
  local _, class = UnitClass("player")
  return TANK_CLASSES[class] or false
end

---------------------------------------------------------------------------
-- Tiny event system
--   ns:On("PLAYER_LOGIN", func)    -> real WoW events
--   ns:Listen("MY_EVENT", func)    -> our own internal messages
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local gameHandlers, msgHandlers = {}, {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = gameHandlers[event]
  if not list then return end
  for i = 1, #list do list[i](event, ...) end
end)

function ns:On(event, func)
  if not gameHandlers[event] then
    gameHandlers[event] = {}
    eventFrame:RegisterEvent(event)
  end
  table.insert(gameHandlers[event], func)
end

function ns:Listen(message, func)
  msgHandlers[message] = msgHandlers[message] or {}
  table.insert(msgHandlers[message], func)
end

function ns:Fire(message, ...)
  local list = msgHandlers[message]
  if not list then return end
  for i = 1, #list do list[i](...) end
end

---------------------------------------------------------------------------
-- Startup  Sequence
---------------------------------------------------------------------------
ns:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON_NAME then return end
  MetrotankDB = MetrotankDB or {}
  MergeDefaults(MetrotankDB, ns.defaults)
  ns.db = MetrotankDB
  ns:Fire("DB_READY")
end)

ns:On("PLAYER_LOGIN", function()
  ns:Fire("LOGIN")
  ns.Print("loaded v" .. ns.version .. ". Type |cffffffff/metrotank|r for options.")
end)

---------------------------------------------------------------------------
-- /metrotank diag
--   Prints what this game client actually lets the addon see (which APIs
--   exist, what is secret, what the CC aura filter returns) and saves the
--   report in MetrotankDB.diag. It only reads events; it changes no behavior.
--   Target an enemy first to get the threat and CC lines.ad
---------------------------------------------------------------------------
local DIAG_MAX = 20
local DIAG_CC_FILTER = "HARMFUL|CROWD_CONTROL" -- same filter CrowdControl.lua uses

-- Call something that may be missing or may error. Returns printable text.
local function Probe(func, ...)
  if type(func) ~= "function" then return "MISSING" end
  local ok, value = pcall(func, ...)
  if not ok then return "ERROR: " .. SafeText(value) end
  return SafeText(value)
end

local function Has(thing)
  return thing and "yes" or "NO"
end

-- Count the auras a filter returns on a unit, and how many hide their ID / end time.
local function AuraSummary(unit, filter)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return "aura API MISSING" end
  local count, secretIDs, secretEnds, names = 0, 0, 0, {}
  for i = 1, 40 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
    if not ok then return "ERROR: " .. SafeText(aura) end
    if ns.IsSecret(aura) then return "the aura data itself is SECRET" end
    if not aura then break end
    count = count + 1
    if ns.IsSecret(aura.auraInstanceID) then secretIDs = secretIDs + 1 end
    if ns.IsSecret(aura.expirationTime) then secretEnds = secretEnds + 1 end
    if #names < 5 then names[#names + 1] = SafeText(aura.name) end
  end
  return string.format("%d found, %d with a secret ID, %d with a secret end time [%s]",
    count, secretIDs, secretEnds, table.concat(names, ", "))
end

-- Does a color curve accept this unit's threat status, and what comes back?
local function CurveSummary(unit)
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return "curve API MISSING" end
  local status = UnitThreatSituation("player", unit)
  if not ns.IsSecret(status) and status == nil then
    return "skipped (you have no threat on this unit)"
  end
  local curve = C_CurveUtil.CreateColorCurve()
  if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
    curve:SetType(Enum.LuaCurveType.Linear)
  end
  curve:AddPoint(0, CreateColor(1, 0, 0))
  curve:AddPoint(3, CreateColor(0, 1, 0))

  local ok, color = pcall(curve.Evaluate, curve, status)
  if not ok then return "Evaluate ERROR: " .. SafeText(color) end
  if ns.IsSecret(color) then return "Evaluate worked, but the result itself is SECRET" end
  if type(color) ~= "table" or type(color.GetRGB) ~= "function" then
    return "Evaluate worked, but returned a " .. type(color)
  end
  local ok2, red = pcall(color.GetRGB, color)
  if not ok2 then return "Evaluate worked, GetRGB ERROR: " .. SafeText(red) end
  return "Evaluate worked, normal Color object, its red value is " .. (ns.IsSecret(red) and "SECRET" or "readable")
end

function ns.RunDiag()
  local lines = {}
  local function add(label, text) lines[#lines + 1] = label .. ": " .. text end

  local version, build, _, interface = GetBuildInfo()
  add("client", SafeText(version) .. " build " .. SafeText(build) .. ", interface " .. SafeText(interface))

  local inInstance, instanceType = IsInInstance()
  add("where", "in instance " .. SafeText(inInstance) .. " (" .. SafeText(instanceType) .. "), in combat " .. SafeText(InCombatLockdown()))

  add("APIs", "issecretvalue " .. Has(_G.issecretvalue)
    .. ", color curve " .. Has(C_CurveUtil and C_CurveUtil.CreateColorCurve)
    .. ", aura by index " .. Has(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex)
    .. ", nameplates " .. Has(C_NamePlate and C_NamePlate.GetNamePlateForUnit))

  add("you", "counted as tank " .. Probe(ns.IsTank) .. ", role " .. Probe(UnitGroupRolesAssigned, "player") .. ", in group " .. Probe(IsInGroup))

  local exists = UnitExists("target")
  if not ns.IsSecret(exists) and not exists then
    add("target", "none - target an enemy and run this again for the threat and CC lines")
  else
    -- Which "nameplateN" token is the target's plate? That token is what the addon really scans.
    local token
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate then
      for unit, o in pairs(ns.overlays) do
        if o.plate == plate then token = unit; break end
      end
    end

    add("target", "attackable " .. Probe(UnitCanAttack, "player", "target")
      .. ", dead " .. Probe(UnitIsDead, "target")
      .. ", is targeting something " .. Probe(UnitExists, "targettarget")
      .. ", plate token " .. (token or "none (no Metrotank overlay on it)"))

    add("threat via target", Probe(UnitThreatSituation, "player", "target"))
    if token then add("threat via " .. token, Probe(UnitThreatSituation, "player", token)) end

    add("CC auras via target", Probe(AuraSummary, "target", DIAG_CC_FILTER))
    add("all harmful auras via target", Probe(AuraSummary, "target", "HARMFUL"))
    if token then
      add("CC auras via " .. token, Probe(AuraSummary, token, DIAG_CC_FILTER))
      add("all harmful auras via " .. token, Probe(AuraSummary, token, "HARMFUL"))
    end

    add("color curve via " .. (token or "target"), Probe(CurveSummary, token or "target"))
  end

  ns.Print("diagnostic report")
  for i = 1, #lines do print("   " .. lines[i]) end

  local saved = ns.db.diag
  if type(saved) ~= "table" then saved = {}; ns.db.diag = saved end
  saved[#saved + 1] = { time = date("%Y-%m-%d %H:%M:%S"), lines = lines }
  while #saved > DIAG_MAX do table.remove(saved, 1) end
  ns.Print("report " .. #saved .. " saved. Type |cffffffff/reload|r to write it to disk.")
end

---------------------------------------------------------------------------
-- Slash commands  (/metrotank or /mtk)
---------------------------------------------------------------------------
SLASH_METROTANK1 = "/metrotank"
SLASH_METROTANK2 = "/mtk"
SlashCmdList.METROTANK = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "" or msg == "options" or msg == "config" then
    ns:Fire("TOGGLE_OPTIONS")
  elseif msg == "test" or msg == "test threat" then
    ns:Fire("TEST_THREAT")
  elseif msg == "test cc" then
    ns:Fire("TEST_CC")
  elseif msg == "unlock" or msg == "lock" then
    ns:Fire("TOGGLE_BANNER_LOCK")
  elseif msg == "debug" then
    ns.db.general.debug = not ns.db.general.debug
    ns.Print("debug is now " .. (ns.db.general.debug and "ON" or "OFF"))
  elseif msg == "diag" then
    local ok, err = pcall(ns.RunDiag)
    if not ok then ns.Print("diag failed: " .. tostring(err)) end
  elseif msg == "reset" then
    MetrotankDB = DeepCopy(ns.defaults)
    ns.db = MetrotankDB
    ns:Fire("SETTING_CHANGED", {}, nil)
    ns.Print("all settings reset.")
  else
    ns.Print("commands: /metrotank  |  test  |  test cc  |  unlock  |  debug  |  diag  |  reset")
  end
end
