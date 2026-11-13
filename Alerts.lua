--[[
  Metrotank - Alerts.lua
  --------------------
  Sounds (with a cooldown so they don't spam) and the two center-screen
  banners: "THREAT LOST" and "CC BROKEN".
]]

local _, ns = ...

---------------------------------------------------------------------------
-- Sound list. "kit" names come from Blizzard's SOUNDKIT table; the number is
-- a fallback in case the name is missing on this client.
-- To add your own .ogg file: put it in Metrotank\Media\ and add an entry with
--   file = "Interface\\AddOns\\Metrotank\\Media\\myfile.ogg"
---------------------------------------------------------------------------
ns.Sounds = {
  { key = "NONE",         label = "None" },
  { key = "RAID_WARNING", label = "Raid Warning", kit = "RAID_WARNING", id = 8959 },
  { key = "MAP_PING",     label = "Map Ping",     kit = "MAP_PING",     id = 3175 },
  { key = "READY_CHECK",  label = "Ready Check",  kit = "READY_CHECK",  id = 8960 },
  { key = "ALARM",        label = "Alarm Clock",  kit = "ALARM_CLOCK_WARNING_3", id = 12889 },
  { key = "WHISPER",      label = "Whisper",      kit = "TELL_MESSAGE", id = 3081 },
}
-- this function loops through ns.Sounds with ipairs and returns a sound  with s.key
 function ns.GetSound(key)
  for _, s in ipairs(ns.Sounds) do
    if s.key == key then return s end
  end
  return ns.Sounds[1]
end
-- table to record when each sound was last played. 
local lastPlayed = {}

-- force = true skips the cooldown (used by the "play" preview buttons)
function ns.PlayAlertSound(key, force)
  local sound = ns.GetSound(key)
  if sound.key == "NONE" then return end

  local now = GetTime()
  if not force and lastPlayed[key] and (now - lastPlayed[key]) < ns.db.sounds.cooldown then
    return
  end
  lastPlayed[key] = now

  local channel = ns.db.sounds.channel or "Master"
  if sound.file then
    PlaySoundFile(sound.file, channel)
  else
    local id = (SOUNDKIT and SOUNDKIT[sound.kit]) or sound.id
    PlaySound(id, channel)
  end
end

-- Plays the CC ping one or more times, slightly spaced out.
local lastPing = 0
function ns.PlayPing(force)
  local now = GetTime()
  if not force and (now - lastPing) < ns.db.sounds.cooldown then return end
  lastPing = now
  local count = ns.db.cc.pingCount or 1
  for i = 0, count - 1 do
    C_Timer.After(i * 0.18, function() ns.PlayAlertSound(ns.db.cc.breakSound, true) end)
  end
end

---------------------------------------------------------------------------
-- Taunt spell (for the cooldown icon on the threat banner)
-- Spell IDs are from classic WoW. WoW Forever reworked Paladin tanking, so
-- the Paladin entry may need updating — you can type your taunt's name in
-- the options to override this.
---------------------------------------------------------------------------
local TAUNTS = {
  WARRIOR = { 355 },          -- Taunt
  DRUID   = { 6795 },         -- Growl
  PALADIN = { 62124, 31789 }, -- Hand of Reckoning / Righteous Defense (TODO: guess on this — verify in game)
}

function ns.GetTauntSpell()
  local custom = ns.db.taunt.spell
  if custom and custom ~= "" then
    local info = C_Spell and C_Spell.GetSpellInfo and ns.Try(C_Spell.GetSpellInfo, tonumber(custom) or custom)
    if info then return info.spellID, info.iconID end
  end

  local _, class = UnitClass("player")
  for _, id in ipairs(TAUNTS[class] or {}) do
    local known = IsPlayerSpell and IsPlayerSpell(id)
    if known then
      local info = C_Spell.GetSpellInfo(id)
      if info then return info.spellID, info.iconID end
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- Banner frames
---------------------------------------------------------------------------
local banners = {}
local locked = true

local function CreateBanner(key, yOffset, borderColor, big)
  local f = CreateFrame("Frame", "MetrotankBanner_" .. key, UIParent, "BackdropTemplate")
  f:SetSize(big and 420 or 380, big and 64 or 40)
  f:SetFrameStrata("HIGH")
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  f:SetBackdropColor(0.06, 0.03, 0.03, 0.82)
  f:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1)

  -- restore saved position, otherwise use the default spot
  local pos = ns.db.banners[key]
  if pos then
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, yOffset)
  end

  f.title = f:CreateFontString(nil, "OVERLAY", big and "GameFontNormalHuge" or "GameFontNormalLarge")
  f.title:SetTextColor(1, 1, 1)
  f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.sub:SetTextColor(1, 0.85, 0.85)

  if big then
    -- taunt icon with cooldown swipe on the left
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(44, 44)
    f.icon:SetPoint("LEFT", 12, 0)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.icon)
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, -2)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  else
    f.title:SetPoint("CENTER")
  end

  -- fade out after showing
  f.anim = f:CreateAnimationGroup()
  local hold = f.anim:CreateAnimation("Alpha")
  hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(2.0); hold:SetOrder(1)
  local fade = f.anim:CreateAnimation("Alpha")
  fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(0.6); fade:SetOrder(2)
  f.anim:SetScript("OnFinished", function() if locked then f:Hide() end end)

  -- dragging (only when unlocked with /metrotank unlock)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not locked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.banners[key] = { point = point, relPoint = relPoint, x = x, y = y }
  end)

  f:Hide()
  banners[key] = f
  return f
end

local function Flash(f)
  f.anim:Stop()
  f:SetAlpha(1)
  f:Show()
  if locked then f.anim:Play() end
end

-- mobName / victimName may be secret values: SetFormattedText is allowed to
-- display them, so we never join them with ".." ourselves.
function ns.ShowThreatBanner(mobName, victimName)
  if not ns.db.threat.showBanner then return end
  local f = banners.threat
  f.title:SetText("THREAT LOST")
  if mobName and victimName then
    f.sub:SetFormattedText("%s is attacking %s", mobName, victimName)
  elseif mobName then
    f.sub:SetFormattedText("%s turned away from you", mobName)
  else
    f.sub:SetText("A mob turned away from you")
  end

  local spellID, icon = nil, nil
  if ns.db.taunt.showOnBanner then spellID, icon = ns.GetTauntSpell() end
  if spellID then
    f.icon:SetTexture(icon)
    f.icon:Show()
    local cd = C_Spell.GetSpellCooldown and ns.Try(C_Spell.GetSpellCooldown, spellID)
    if cd then
      -- start/duration may be secret; Cooldown frames are allowed to show them.
      ns.Try(f.cd.SetCooldown, f.cd, cd.startTime, cd.duration)
    end
  else
    f.icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    f.cd:Clear()
  end
  Flash(f)
end

function ns.ShowCCBanner(mobName, certain)
  if not ns.db.cc.showBanner then return end
  local f = banners.cc
  local word = certain and "CC BROKEN" or "CC ENDED"
  if mobName then
    f.title:SetFormattedText("%s - %s is loose", word, mobName)
  else
    f.title:SetText(word)
  end
  Flash(f)
end

ns:Listen("DB_READY", function()
  CreateBanner("threat", -140, ns.db.colors.lost, true)
  CreateBanner("cc", -215, ns.db.colors.broken, false)
end)

ns:Listen("TOGGLE_BANNER_LOCK", function()
  locked = not locked
  for _, f in pairs(banners) do
    f:EnableMouse(not locked)
    if locked then f:Hide() else f.anim:Stop(); f:SetAlpha(1); f:Show() end
  end
  if not locked then
    banners.threat.title:SetText("THREAT LOST")
    banners.threat.sub:SetText("Drag me, then type /metrotank lock")
    banners.cc.title:SetText("CC BROKEN - drag me")
  end
  ns.Print(locked and "banners locked." or "banners unlocked - drag them where you like.")
end)

-- Test buttons / slash commands
ns:Listen("TEST_THREAT", function()
  ns.ShowThreatBanner("Defias Pillager", "Mage")
  ns.PlayAlertSound(ns.db.threat.lostSound, true)
  ns:Fire("TEST_PLATES", "lost")
end)

ns:Listen("TEST_CC", function()
  ns.ShowCCBanner("Defias Conjurer", true)
  ns.PlayPing(true)
  ns:Fire("TEST_PLATES", "broken")
end)
