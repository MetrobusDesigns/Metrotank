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
  banners = {},          -- saved banner positions (filled when you drag them)
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

function ns.Debug(...)
  if ns.db and ns.db.general.debug then
    print("|cff8b93a5Metrotank debug|r:", ...)
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
  elseif msg == "reset" then
    MetrotankDB = DeepCopy(ns.defaults)
    ns.db = MetrotankDB
    ns:Fire("SETTING_CHANGED", {}, nil)
    ns.Print("all settings reset.")
  else
    ns.Print("commands: /metrotank  |  test  |  test cc  |  unlock  |  debug  |  reset")
  end
end
