--[[
  Metrotank - Threat.lua
  --------------------
  Checks your threat on every enemy nameplate a few times per second while
  you're in combat.

  UnitThreatSituation("player", mob) returns:
    nil = you're not on its threat list
    0   = not tanking, below the tank
    1   = not tanking, but above the tank (about to pull)
    2   = tanking, but someone else is higher  -> "slipping"
    3   = tanking securely                     -> "holding"

  Two paths:
    READABLE (open world, or your target): we can compare the number, so we
      color the plate AND play sounds / show the banner when you lose a mob.
    SECRET (inside dungeons/raids): the number is hidden. We hand it to a
      Color Curve, which lets the game color the plate for us. Colors still
      work, but sounds can't — we're not allowed to know the value.
]]

local _, ns = ...

local UPDATE_EVERY = 0.25
local ticker

---------------------------------------------------------------------------
-- Color curve for the secret path: maps status 0..3 to a color
---------------------------------------------------------------------------
local curve

local function BuildCurve()
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
  curve = C_CurveUtil.CreateColorCurve()
  if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
    curve:SetType(Enum.LuaCurveType.Linear)
  end
  local c = ns.db.colors
  curve:AddPoint(0, CreateColor(c.lost.r, c.lost.g, c.lost.b))
  curve:AddPoint(1, CreateColor(c.lost.r, c.lost.g, c.lost.b))
  curve:AddPoint(2, CreateColor(c.slip.r, c.slip.g, c.slip.b))
  curve:AddPoint(3, CreateColor(c.hold.r, c.hold.g, c.hold.b))
end

---------------------------------------------------------------------------
-- Is the mob's target another tank (or your own pet)?
---------------------------------------------------------------------------
local function IsOtherTank(who)
  if not UnitExists(who) then return false end
  local isMe = UnitIsUnit(who, "player")
  if ns.IsSecret(isMe) or isMe then return false end

  local isPet = UnitIsUnit(who, "pet")
  if not ns.IsSecret(isPet) and isPet then return true end

  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(who)
  if not ns.IsSecret(role) and role == "TANK" then return true end

  local mt = GetPartyAssignment and GetPartyAssignment("MAINTANK", who)
  if not ns.IsSecret(mt) and mt then return true end
  return false
end

-- Turn a readable status number into one of our state names
local function Classify(status, token)
  if status == nil then return nil end
  if status == 3 then return "hold" end
  if status == 2 then return "slip" end
  if IsOtherTank(token .. "target") then return "other" end
  return "lost"
end

---------------------------------------------------------------------------
-- Update one plate
---------------------------------------------------------------------------
local function UpdateUnit(unit, o)
  if not ns.db.general.enabled or not ns.IsTank()
     or (ns.db.threat.onlyInGroup and not IsInGroup()) then
    o.threat, o.secretColor, o.lastThreat = nil, nil, nil
    return
  end

  local canAttack = UnitCanAttack("player", unit)
  -- (if the answer is secret we keep going and let the secret path handle it)
  if not ns.IsSecret(canAttack) and not canAttack then
    o.threat, o.secretColor = nil, nil
    return
  end

  -- Your target can sometimes be read even when nameplate tokens are secret
  local token = unit
  local status = UnitThreatSituation("player", unit)
  if ns.IsSecret(status) and C_NamePlate.GetNamePlateForUnit("target") == o.plate then
    token = "target"
    status = UnitThreatSituation("player", "target")
  end

  if ns.IsSecret(status) then
    -- SECRET path: color only
    o.threat = nil
    o.secretColor = curve and ns.Try(curve.Evaluate, curve, status) or nil
    return
  end

  -- READABLE path
  o.secretColor = nil
  local state = Classify(status, token)
  local before = o.lastThreat

  if state == "lost" and (before == "hold" or before == "slip") then
    if ns.db.threat.alertLost then
      ns.PlayAlertSound(ns.db.threat.lostSound)
      ns.ShowThreatBanner(UnitName(token), UnitName(token .. "target"))
    end
    ns.Debug("threat LOST on", unit)
  elseif state == "slip" and before == "hold" and ns.db.threat.alertSlipping then
    ns.PlayAlertSound(ns.db.threat.slipSound)
  end

  o.threat = state
  o.lastThreat = state
end

local function UpdateAll()
  for unit, o in pairs(ns.overlays) do
    UpdateUnit(unit, o)
    ns.RenderOverlay(o)
  end
end
ns.UpdateAllThreat = UpdateAll

---------------------------------------------------------------------------
-- Only run while you're in combat
---------------------------------------------------------------------------
ns:On("PLAYER_REGEN_DISABLED", function()
  if not ticker then ticker = C_Timer.NewTicker(UPDATE_EVERY, UpdateAll) end
end)

ns:On("PLAYER_REGEN_ENABLED", function()
  if ticker then ticker:Cancel(); ticker = nil end
  for _, o in pairs(ns.overlays) do
    o.threat, o.secretColor, o.lastThreat = nil, nil, nil
    ns.RenderOverlay(o)
  end
end)

-- React instantly when the game says threat changed on a plate
ns:On("UNIT_THREAT_LIST_UPDATE", function(_, unit)
  local o = unit and ns.overlays[unit]
  if o and InCombatLockdown() then
    UpdateUnit(unit, o)
    ns.RenderOverlay(o)
  end
end)

-- Nameplate frames get recycled: the overlay that was on mob A is reused for
-- mob B later. Forget what we knew about the old mob, otherwise "you were
-- holding A" + "B is on someone else" looks like you just LOST a mob.
-- (PLATE_ADDED is fired by Nameplates.lua every time a plate appears.)
ns:Listen("PLATE_ADDED", function(_, o)
  o.lastThreat = nil
end)

ns:Listen("DB_READY", BuildCurve)
ns:Listen("SETTING_CHANGED", function(path)
  if path and (path[1] == "colors" or #path == 0) then BuildCurve() end
end)
