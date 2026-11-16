--[[
  Metrotank - Nameplates.lua
  ------------------------
  Puts a colored border, a small icon and a short label ("LOST", "CC'D"...)
  on each enemy nameplate. Works on top of Blizzard plates, Plater, Platynator
  or EllesmereUI because we only ADD our own frame — we never replace theirs.

  Each nameplate gets one "overlay" table that remembers:
    overlay.threat      -> "hold", "slip", "lost", "other" or nil
    overlay.ccActive    -> true while the mob is crowd-controlled
    overlay.brokenUntil -> GetTime() value; show "CC BROKEN" until then
    overlay.secretColor -> a color we can show but not read (dungeons)
    overlay.lastThreat  -> the threat state from the previous check, so
                           Threat.lua can spot a change ("hold" -> "lost").
                           Owned by Threat.lua, which clears it on PLATE_ADDED.
]]

local _, ns = ...

ns.overlays = {}      -- unit token ("nameplate3") -> overlay

local LABELS = {
  hold   = "ON YOU",
  slip   = "SLIPPING",
  lost   = "LOST",
  other  = "OFF-TANK",
  cc     = "CC'D",
  broken = "CC BROKEN",
}

local ICONS = {
  lost   = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
  cc     = "Interface\\Icons\\Spell_Nature_Polymorph",
  broken = "Interface\\Icons\\Spell_Nature_LightningShield",
}

---------------------------------------------------------------------------
-- Find the health bar of whatever nameplate addon is in use
---------------------------------------------------------------------------
local function FindHealthBar(plate)
  -- Plater keeps its frame in plate.unitFrame (lower-case u)
  if plate.unitFrame and plate.unitFrame.healthBar then
    return plate.unitFrame.healthBar, "plater"
  end
  -- Blizzard default nameplates
  local uf = plate.UnitFrame
  if uf then
    if uf.healthBar then return uf.healthBar, "blizzard" end
    if uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar then
      return uf.HealthBarsContainer.healthBar, "blizzard"
    end
  end
  -- Unknown addon: anchor to the plate itself
  return plate, "unknown"
end

---------------------------------------------------------------------------
-- Build the overlay frame for one plate
---------------------------------------------------------------------------
local function CreateOverlay(plate)
  local o = CreateFrame("Frame", nil, plate)
  o:SetFrameLevel(plate:GetFrameLevel() + 20)

  -- 4 thin textures make a border (textures can safely show secret colors)
  o.edges = {}
  local size = 2
  for i = 1, 4 do
    local t = o:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 1, 1, 1)
    o.edges[i] = t
  end
  o.edges[1]:SetPoint("TOPLEFT", -size, size);     o.edges[1]:SetPoint("TOPRIGHT", size, size);     o.edges[1]:SetHeight(size)
  o.edges[2]:SetPoint("BOTTOMLEFT", -size, -size); o.edges[2]:SetPoint("BOTTOMRIGHT", size, -size); o.edges[2]:SetHeight(size)
  o.edges[3]:SetPoint("TOPLEFT", -size, size);     o.edges[3]:SetPoint("BOTTOMLEFT", -size, -size); o.edges[3]:SetWidth(size)
  o.edges[4]:SetPoint("TOPRIGHT", size, size);     o.edges[4]:SetPoint("BOTTOMRIGHT", size, -size); o.edges[4]:SetWidth(size)

  o.icon = o:CreateTexture(nil, "OVERLAY")
  o.icon:SetSize(18, 18)
  o.icon:SetPoint("LEFT", o, "RIGHT", 6, 0)
  o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  o.tag = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  o.tag:SetPoint("TOP", o, "BOTTOM", 0, -3)
  local font, fsize = o.tag:GetFont()
  o.tag:SetFont(font, fsize, "OUTLINE")

  -- gentle pulse used for "lost" and "broken"
  o.pulse = o:CreateAnimationGroup()
  o.pulse:SetLooping("BOUNCE")
  local a = o.pulse:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.35)

  return o
end

local function ColorOf(key)
  local c = ns.db.colors[key]
  return c.r, c.g, c.b
end

local function SetEdgeColor(o, r, g, b)
  for i = 1, 4 do o.edges[i]:SetVertexColor(r, g, b) end
end

---------------------------------------------------------------------------
-- Draw an overlay based on its current state
---------------------------------------------------------------------------
function ns.RenderOverlay(o)
  if not o or not o.unit then return end
  local db = ns.db.plates

  -- Work out which state wins: broken > cc > threat
  local state = o.threat
  if o.ccActive then state = "cc" end
  if o.brokenUntil and GetTime() < o.brokenUntil then state = "broken" end
  if o.testState then state = o.testState end

  if not ns.db.general.enabled or (not state and not o.secretColor) then
    o:Hide()
    o.pulse:Stop()
    ns.RestoreBarColor(o)
    return
  end
  o:Show()

  -- Pick the color. In dungeons the threat color may be a secret Color object.
  local r, g, b
  local useSecret = (state == nil and o.secretColor ~= nil)
  if useSecret then
    r, g, b = o.secretColor:GetRGB()
  else
    r, g, b = ColorOf(state)
  end

  -- border
  for i = 1, 4 do o.edges[i]:SetShown(db.border) end
  SetEdgeColor(o, r, g, b)

  -- health bar recolor (Blizzard plates only, so we don't fight Plater)
  if db.recolorBar and o.kind == "blizzard" and o.bar.SetStatusBarColor then
    if not o.recolored then
      -- remember Blizzard's color so we can put it back later
      o.origR, o.origG, o.origB = o.bar:GetStatusBarColor()
    end
    ns.Try(o.bar.SetStatusBarColor, o.bar, r, g, b)
    o.recolored = true
  end

  -- label + icon (only when we actually know the state)
  if state and db.showTag then
    o.tag:SetText(LABELS[state] or "")
    o.tag:SetTextColor(r, g, b)
    o.tag:Show()
  else
    o.tag:Hide()
  end

  local iconPath = state and ICONS[state]
  if iconPath and db.showIcon then
    o.icon:SetTexture(iconPath)
    o.icon:Show()
  else
    o.icon:Hide()
  end

  if db.pulseOnLost and (state == "lost" or state == "broken") then
    if not o.pulse:IsPlaying() then o.pulse:Play() end
  else
    o.pulse:Stop()
  end
end

-- Give the bar back to Blizzard's own coloring
function ns.RestoreBarColor(o)
  if o.recolored and o.kind == "blizzard" then
    o.recolored = nil
    if o.origR then
      ns.Try(o.bar.SetStatusBarColor, o.bar, o.origR, o.origG, o.origB)
    end
  end
end

---------------------------------------------------------------------------
-- Track plates appearing / disappearing
---------------------------------------------------------------------------
local overlayByPlate = {}

ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit)
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end

  local o = overlayByPlate[plate]
  if not o then
    o = CreateOverlay(plate)
    overlayByPlate[plate] = o
  end

  -- plates get recycled, so wipe old state every time
  o.plate, o.unit = plate, unit
  o.threat, o.ccActive, o.brokenUntil, o.secretColor, o.testState = nil, nil, nil, nil, nil
  o.bar, o.kind = FindHealthBar(plate)
  o:ClearAllPoints()
  o:SetAllPoints(o.bar)

  ns.overlays[unit] = o
  ns:Fire("PLATE_ADDED", unit, o)
  ns.RenderOverlay(o)
end)

ns:On("NAME_PLATE_UNIT_REMOVED", function(_, unit)
  local o = ns.overlays[unit]
  if o then
    o.pulse:Stop()
    ns.RestoreBarColor(o)
    o:Hide()
    o.unit = nil
  end
  ns.overlays[unit] = nil
  ns:Fire("PLATE_REMOVED", unit)
end)

-- Blizzard re-colors its bars often; put our color back right after.
ns:Listen("LOGIN", function()
  if type(CompactUnitFrame_UpdateHealthColor) == "function" then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
      local unit = frame and frame.unit
      if type(unit) ~= "string" or not unit:find("^nameplate") then return end
      local o = ns.overlays[unit]
      if o and o:IsShown() and ns.db.plates.recolorBar then ns.RenderOverlay(o) end
    end)
  end
end)

ns:Listen("SETTING_CHANGED", function()
  for _, o in pairs(ns.overlays) do ns.RenderOverlay(o) end
end)

-- /metrotank test: show a state on your current target's plate for 4 seconds
ns:Listen("TEST_PLATES", function(state)
  local plate = C_NamePlate.GetNamePlateForUnit("target")
  local o = plate and overlayByPlate[plate]
  if not o then
    ns.Print("target an enemy with a visible nameplate to preview plate colors.")
    return
  end
  o.testState = state
  ns.RenderOverlay(o)
  C_Timer.After(4, function() o.testState = nil; ns.RenderOverlay(o) end)
end)
