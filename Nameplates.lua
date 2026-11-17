--[[
  Metrotank - Nameplates.lua
  ------------------------
  Puts a colored border, a small icon and a short label ("LOST", "CC'D"...)
  on each enemy nameplate. Works on top of Blizzard plates, Plater, Platynator
  or EllesmereUI because we only ADD our own frame — we never replace theirs.
  A mob you LOST threat on also gets a fast-pulsing yellow arrow above it.

  Each nameplate gets one "overlay" table that remembers:
    overlay.threat -> "hold", "slip", "lost", "other" or nil
    overlay.ccActive    -> true while the mob is crowd-controlled (CC)
    overlay.brokenUntil -> GetTime() value; show "CC BROKEN" until then
    overlay.secretColor -> a color we can show but not read (dungeons)
]]------

local _, ns = ...

ns.overlays = {}      -- unit token ("nameplate3") -> overlay

local LABELS = {
  hold   = "",
  slip   = "LOSING THREAT",
  lost   = "LOST THREAT",
  other  = "OFF-TANK",
  cc     = "CC",
  broken = "CC BROKEN",
}

local ICONS = {
  lost   = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
  cc     = "Interface\\Icons\\Spell_Nature_Polymorph",
  broken = "Interface\\Icons\\Spell_Nature_LightningShield",
}

-- Lost-threat arrow: a yellow triangle above the plate, pointing down at it.
-- Change these numbers to tweak how it looks.
local ARROW_COLOR = { 1.00, 1.00, 0.00 } -- solid yellow (red, green, blue)
local ARROW_ROWS  = 8    -- the triangle is 8 stacked bars...
local ARROW_ROW_H = 2    -- ...each is 2 px tall, so 16 px tall and 16 px wide
local ARROW_GAP   = 16   -- px above the health bar (leaves room for the mob's name)
local ARROW_PULSE = 0.15 -- seconds per blink; smaller = faster

---------------------------------------------------------------
--[[ Find the health bar of whatever nameplate addon is in use (currently testing to use in Plater / Playnator and MF Plater)
]]--
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

--[[ This section builds the overlay frame for one plate
---------------------------------------------------------------------------]]
local function CreateOverlay(plate)
  local o = CreateFrame("Frame", nil, plate)
  o:SetFrameLevel(plate:GetFrameLevel() + 20)

  -- 4 thin textures make a border (textures should be able to  safely show secret colors)
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

  -- Lost-threat arrow. Separate small frame so it can pulse by itself,
  -- faster than the border. The triangle is drawn as stacked bars that get
  -- narrower toward the bottom: 16 px wide at the top, 2 px wide at the tip.
  o.arrow = CreateFrame("Frame", nil, o)
  o.arrow:SetSize(ARROW_ROWS * 2, ARROW_ROWS * ARROW_ROW_H)
  o.arrow:SetPoint("BOTTOM", o, "TOP", 0, ARROW_GAP)
  for row = 1, ARROW_ROWS do
    local width = (ARROW_ROWS - row + 1) * 2   -- 16, 14, 12 ... 2
    local y = -(row - 1) * ARROW_ROW_H         -- each bar sits below the last
    -- one solid yellow bar (no outline, so the whole arrow is plain yellow)
    local bar = o.arrow:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(ARROW_COLOR[1], ARROW_COLOR[2], ARROW_COLOR[3], 1)
    bar:SetSize(width, ARROW_ROW_H)
    bar:SetPoint("TOP", 0, y)
  end
  o.arrow:Hide()

  -- Without this the arrow would also fade with the slower border pulse above.
  if o.arrow.SetIgnoreParentAlpha then o.arrow:SetIgnoreParentAlpha(true) end

  -- fast pulse for the arrow: it blinks (alpha) and throbs (scale) together
  o.arrowPulse = o.arrow:CreateAnimationGroup()
  o.arrowPulse:SetLooping("BOUNCE")
  local blink = o.arrowPulse:CreateAnimation("Alpha")
  blink:SetFromAlpha(1); blink:SetToAlpha(0.3); blink:SetDuration(ARROW_PULSE)
  local throb = o.arrowPulse:CreateAnimation("Scale")
  throb:SetDuration(ARROW_PULSE)
  throb:SetOrigin("BOTTOM", 0, 0) -- grow from the tip, so the tip stays put
  -- (the function names differ between game versions; without either one the
  --  arrow simply blinks without changing size)
  if throb.SetScaleFrom then
    throb:SetScaleFrom(1, 1); throb:SetScaleTo(1.3, 1.3)
  elseif throb.SetFromScale then
    throb:SetFromScale(1, 1); throb:SetToScale(1.3, 1.3)
  end

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
    o.arrowPulse:Stop()
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

  -- lost-threat arrow: only on a mob we KNOW we lost
  if db.showArrow and state == "lost" then
    o.arrow:Show()
    if not o.arrowPulse:IsPlaying() then o.arrowPulse:Play() end
  else
    o.arrowPulse:Stop()
    o.arrow:Hide()
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
    o.arrowPulse:Stop()
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
