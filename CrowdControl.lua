--[[
  Bulwark - CrowdControl.lua
  --------------------------
  Watches enemy nameplates for crowd control (Polymorph, Sap, Shackle,
  Freezing Trap, Hibernate...) and pings when it ends early.

  How it works:
    The modern client has an aura filter "HARMFUL|CROWD_CONTROL" that returns
    only CC effects. Every time a mob's auras change (UNIT_AURA) we list its
    CC auras by auraInstanceID (an ID addons are still allowed to read) and
    compare with the last list. If one disappeared, the CC ended.

  Broken or just ran out?
    In the open world we can read when the CC was supposed to expire, so we
    know if it broke early. Inside dungeons that time is secret, so we can
    only say "CC ENDED". The option "Alert even when unsure" controls whether
    you still get a ping in that case (on by default).

  NOTE: the old way (COMBAT_LOG_EVENT_UNFILTERED / SPELL_AURA_BROKEN) is no
  longer available to addons on WoW Forever, which is why we use auras.
]]

local _, ns = ...

local CC_FILTER = "HARMFUL|CROWD_CONTROL"
local EARLY_MARGIN = 0.5 -- seconds: ending this much before expiry counts as "broken"

-- Returns a table: { [auraInstanceID] = expirationTime or false }
local function ScanCC(unit)
  local found = {}
  for i = 1, 40 do
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, CC_FILTER)
    if not aura then break end
    local id = aura.auraInstanceID
    if id and not ns.IsSecret(id) then
      local exp = aura.expirationTime
      if ns.IsSecret(exp) or not exp or exp == 0 then exp = false end
      found[id] = exp
    end
  end
  return found
end

local function HasAny(t)
  return next(t) ~= nil
end

local function CheckUnit(unit)
  local o = ns.overlays[unit]
  if not o or not ns.db.general.enabled or not ns.db.cc.enabled then return end

  local now = GetTime()
  local current = ns.Try(ScanCC, unit) or {}
  local previous = o.ccList or {}

  -- Did any CC disappear?
  for id, exp in pairs(previous) do
    if current[id] == nil then
      local dead = UnitIsDead(unit)
      if ns.IsSecret(dead) then dead = false end

      if not dead then
        local certain = (exp ~= false)            -- we know when it should have ended
        local brokeEarly = certain and now < (exp - EARLY_MARGIN)

        if brokeEarly or (not certain and ns.db.cc.alertWhenUnknown) then
          o.brokenUntil = now + ns.db.cc.flashSeconds
          ns.PlayPing()
          ns.ShowCCBanner(UnitName(unit), brokeEarly)
          ns.Debug("CC ended on", unit, brokeEarly and "(broken early)" or "(unknown)")
          C_Timer.After(ns.db.cc.flashSeconds + 0.05, function() ns.RenderOverlay(o) end)
        end
      end
    end
  end

  o.ccList = current
  o.ccActive = HasAny(current)
  ns.RenderOverlay(o)
end

ns:On("UNIT_AURA", function(_, unit)
  if unit and ns.overlays[unit] then CheckUnit(unit) end
end)

-- New plate: remember current CC quietly (no alert).
-- When a plate disappears (mob died / out of range) its state is simply
-- wiped the next time the plate is reused, so no alert fires for that.
ns:Listen("PLATE_ADDED", function(unit, o)
  o.ccList = ns.Try(ScanCC, unit) or {}
  o.ccActive = HasAny(o.ccList)
end)
