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
-- "group" is the submenu the sound appears under in the options dropdown.
-- A sound with no group (like "None") sits at the top of the menu.
---------------------------------------------------------------------------
ns.Sounds = {
  { key = "NONE",         label = "None" },
  { key = "RAID_WARNING", label = "Raid Warning", kit = "RAID_WARNING", id = 8959, group = "Warnings" },
  { key = "MAP_PING",     label = "Map Ping",     kit = "MAP_PING",     id = 3175, group = "Pings & Chat" },
  { key = "READY_CHECK",  label = "Ready Check",  kit = "READY_CHECK",  id = 8960, group = "Group & Queue" },
  { key = "ALARM",        label = "Alarm Clock",  kit = "ALARM_CLOCK_WARNING_3", id = 12889, group = "Warnings" },
  { key = "WHISPER",      label = "Whisper",      kit = "TELL_MESSAGE", id = 3081, group = "Pings & Chat" },
}

-- Adds one built-in game sound to the list above.
-- The SOUNDKIT name doubles as the saved key, so only write it once.
local function AddSound(group, label, kit, id)
  table.insert(ns.Sounds, { key = kit, label = label, kit = kit, id = id, group = group })
end

-- 75 more sounds from the game. Names and numbers are copied from Blizzard's
-- SoundKitConstants.lua. If a sound doesn't exist on this client it simply
-- plays nothing (no error), so it's safe to leave it in the list.
AddSound("Warnings", "Boss Emote",       "RAID_BOSS_EMOTE_WARNING",              12197)
AddSound("Warnings", "Boss Whisper",     "UI_RAID_BOSS_WHISPER_WARNING",         37666)
AddSound("Warnings", "Loss of Control",  "UI_LOSS_OF_CONTROL_START",             34468)
AddSound("Warnings", "GM Warning",       "GM_CHAT_WARNING",                      15273)
AddSound("Warnings", "Alarm Clock 1",    "ALARM_CLOCK_WARNING_1",                18871)
AddSound("Warnings", "Alarm Clock 2",    "ALARM_CLOCK_WARNING_2",                12867)
AddSound("Warnings", "Invasion Alert",   "UI_GARRISON_TOAST_INVASION_ALERT",     44292)
AddSound("Warnings", "Notice Warning",   "BEHAVIORAL_NOTIFICATION_WARNING",      188250)
AddSound("Warnings", "Abandon Vote",     "UI_INSTANCE_ABANDON_VOTE",             297918)
AddSound("Warnings", "Lost Target",      "INTERFACE_SOUND_LOST_TARGET_UNIT",     684)
AddSound("Warnings", "Aggro Select",     "IG_CREATURE_AGGRO_SELECT",             873)
AddSound("Warnings", "Threat Countered", "UI_GARRISON_MISSION_THREAT_COUNTERED", 43505)

AddSound("Group & Queue", "Role Check",        "LFG_ROLE_CHECK",                      17317)
AddSound("Group & Queue", "Dungeon Rewards",   "LFG_REWARDS",                         17316)
AddSound("Group & Queue", "LFG Denied",        "LFG_DENIED",                          17341)
AddSound("Group & Queue", "Group Application", "UI_GROUP_FINDER_RECEIVE_APPLICATION", 47615)
AddSound("Group & Queue", "PvP Queue Joined",  "PVP_ENTER_QUEUE",                     8458)
AddSound("Group & Queue", "PvP Queue Ready",   "PVP_THROUGH_QUEUE",                   8459)
AddSound("Group & Queue", "Pet Queue Ready",   "UI_PET_BATTLES_PVP_THROUGH_QUEUE",    36609)
AddSound("Group & Queue", "PvP Update",        "IG_PVP_UPDATE",                       4574)
AddSound("Group & Queue", "War Mode On",       "UI_WARMODE_ACTIVATE",                 118563)
AddSound("Group & Queue", "War Mode Off",      "UI_WARMODE_DECTIVATE",                118564) -- (Blizzard's spelling)
AddSound("Group & Queue", "Group Invite",      "IG_PLAYER_INVITE",                    880)

AddSound("Countdowns", "Countdown Tick",    "UI_COUNTDOWN_TIMER",                  158565)
AddSound("Countdowns", "Countdown Done",    "UI_COUNTDOWN_FINISHED",               158566)
AddSound("Countdowns", "Timer Bar Start",   "UI_COUNTDOWN_BAR_STATE_STARTS",       158958)
AddSound("Countdowns", "Timer Bar Done",    "UI_COUNTDOWN_BAR_STATE_FINISHED",     158959)
AddSound("Countdowns", "Big Number Done",   "UI_COUNTDOWN_MEDIUM_NUMBER_FINISHED", 158960)
AddSound("Countdowns", "BG Countdown Tick", "UI_BATTLEGROUND_COUNTDOWN_TIMER",     25477)
AddSound("Countdowns", "BG Countdown Go",   "UI_BATTLEGROUND_COUNTDOWN_FINISHED",  25478)

AddSound("Pings & Chat", "Battle.net Toast",   "UI_BNET_TOAST",                  18019)
AddSound("Pings & Chat", "Social Queue Toast", "UI_71_SOCIAL_QUEUEING_TOAST",    79739)
AddSound("Pings & Chat", "Event Chime",        "UI_EVENT_SCHEDULER_CHIME",       278769)
AddSound("Pings & Chat", "Waypoint Track",     "UI_MAP_WAYPOINT_SUPER_TRACK_ON", 170270)
AddSound("Pings & Chat", "Waypoint Place",     "UI_MAP_WAYPOINT_CLICK_TO_PLACE", 170269)
AddSound("Pings & Chat", "Waypoint Remove",    "UI_MAP_WAYPOINT_REMOVE",         170273)
AddSound("Pings & Chat", "Voice Join",         "UI_VOICECHAT_JOINCHANNEL",       110981)
AddSound("Pings & Chat", "Voice Leave",        "UI_VOICECHAT_LEAVECHANNEL",      110982)
AddSound("Pings & Chat", "Voice Talk Start",   "UI_VOICECHAT_TALKSTART",         110983)

AddSound("Loot & Money", "Epic Loot",        "UI_EPICLOOT_TOAST",                  31578)
AddSound("Loot & Money", "Legendary Loot",   "UI_LEGENDARY_LOOT_TOAST",            63971)
AddSound("Loot & Money", "Personal Loot",    "UI_PERSONAL_LOOT_BANNER",            50893)
AddSound("Loot & Money", "Lesser Item Won",  "UI_RAID_LOOT_TOAST_LESSER_ITEM_WON", 51402)
AddSound("Loot & Money", "Warforged Loot",   "UI_WARFORGED_ITEM_LOOT_TOAST",       51561)
AddSound("Loot & Money", "Bonus Roll Start", "UI_BONUS_LOOT_ROLL_START",           31579)
AddSound("Loot & Money", "Bonus Roll End",   "UI_BONUS_LOOT_ROLL_END",             31581)
AddSound("Loot & Money", "Roll Won",         "UI_NEED_ROLL_POSITIVE",              229319)
AddSound("Loot & Money", "Roll Lost",        "UI_NEED_ROLL_NEGATIVE",              229321)
AddSound("Loot & Money", "Rolled 100",       "UI_NEED_ROLL_ONE_HUNDRED",           230489)
AddSound("Loot & Money", "Coins",            "LOOT_WINDOW_COIN_SOUND",             120)
AddSound("Loot & Money", "Item Repair",      "ITEM_REPAIR",                        7994)

AddSound("Victory & Defeat", "Boss Defeated",      "UI_RAID_BOSS_DEFEATED",                             50111)
AddSound("Victory & Defeat", "Challenge Record",   "UI_CHALLENGES_NEW_RECORD",                          33338)
AddSound("Victory & Defeat", "Mythic+ Record",     "UI_70_CHALLENGE_MODE_NEW_RECORD",                   74438)
AddSound("Victory & Defeat", "Keystone Upgrade",   "UI_70_CHALLENGE_MODE_KEYSTONE_UPGRADE",             74437)
AddSound("Victory & Defeat", "Mythic+ Complete",   "UI_70_CHALLENGE_MODE_COMPLETE_NO_UPGRADE",          74526)
AddSound("Victory & Defeat", "Scenario Ending",    "UI_SCENARIO_ENDING",                                31754)
AddSound("Victory & Defeat", "Scenario Stage End", "UI_SCENARIO_STAGE_END",                             31757)
AddSound("Victory & Defeat", "Mission Cheers",     "UI_MISSION_SUCCESS_CHEERS",                         74702)
AddSound("Victory & Defeat", "Mission Complete",   "UI_GARRISON_TOAST_MISSION_COMPLETE",                44294)
AddSound("Victory & Defeat", "Mission Failed",     "UI_GARRISON_MISSION_COMPLETE_MISSION_FAIL_STINGER", 43503)
AddSound("Victory & Defeat", "Encounter Failed",   "UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL",       43501)
AddSound("Victory & Defeat", "Prestige Rank Up",   "UI_PVP_HONOR_PRESTIGE_RANK_UP",                     77003)

AddSound("Quests & Toasts", "Auto Quest Complete", "UI_AUTO_QUEST_COMPLETE",       23404)
AddSound("Quests & Toasts", "Quest Complete",      "IG_QUEST_LIST_COMPLETE",       878)
AddSound("Quests & Toasts", "Quest Abandoned",     "IG_QUEST_LOG_ABANDON_QUEST",   846)
AddSound("Quests & Toasts", "World Quest Start",   "UI_WORLDQUEST_START",          73275)
AddSound("Quests & Toasts", "World Quest Done",    "UI_WORLDQUEST_COMPLETE",       73277)
AddSound("Quests & Toasts", "Dig Site Complete",   "UI_DIG_SITE_COMPLETION_TOAST", 38326)
AddSound("Quests & Toasts", "Talents Unlocked",    "UI_HERO_TALENTS_UNLOCKED",     283863)

AddSound("Interface", "Pet Battle Start", "UI_PET_BATTLE_START",     31584)
AddSound("Interface", "Tutorial Popup",   "TUTORIAL_POPUP",          7355)
AddSound("Interface", "NPC Select",       "IG_CHARACTER_NPC_SELECT", 867)
AddSound("Interface", "Page Turn",        "IG_ABILITY_PAGE_TURN",    836)
AddSound("Interface", "Auction Open",     "AUCTION_WINDOW_OPEN",     5274)

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
local MIN_SCALE, MAX_SCALE = 0.5, 2.0 -- keep in sync with the size sliders in Options.lua

function ns.BannersLocked() return locked end

-- The banner's size setting, e.g. ns.db.banners.threatScale (1 = normal size).
local function GetScale(key)
  local s = tonumber(ns.db.banners[key .. "Scale"]) or 1
  return math.min(MAX_SCALE, math.max(MIN_SCALE, s))
end

-- Saves where the banner's CENTER is, in UIParent units. Storing it this way
-- (not in the banner's own scaled units) means changing the size later
-- grows/shrinks the banner in place instead of making it jump around.
local function SavePosition(f, key)
  local cx, cy = f:GetCenter()
  if not cx then return end
  local s = f:GetScale()
  ns.db.banners[key] = { cx = cx * s, cy = cy * s }
end

-- Applies the saved size and position (or the default spot) to one banner.
-- Anchor offsets are in the banner's own scaled units, hence the "/ s".
local function ApplyLayout(f)
  local key, s = f.key, GetScale(f.key)
  local pos = ns.db.banners[key]
  f:SetScale(s)
  f:ClearAllPoints()
  if type(pos) == "table" and pos.cx then
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.cx / s, pos.cy / s)
  elseif type(pos) == "table" and pos.point then
    -- position saved by an older version (before banners could be scaled)
    f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x / s, pos.y / s)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, f.defaultY / s)
  end
end

local function CreateBanner(key, yOffset, borderColor, big)
  local f = CreateFrame("Frame", "MetrotankBanner_" .. key, UIParent, "BackdropTemplate")
  f.key, f.defaultY = key, yOffset
  f:SetSize(big and 420 or 380, big and 64 or 40)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  f:SetBackdropColor(0.06, 0.03, 0.03, 0.82)
  f:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1)

  -- restore saved size + position, otherwise use the default spot
  ApplyLayout(f)

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

  -- dragging + mouse-wheel resizing (only when unlocked with /metrotank unlock
  -- or the "Move alert banners" button in the options)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not locked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false) -- we save the position ourselves
    SavePosition(self, key)
    ApplyLayout(self)
  end)
  f:SetScript("OnMouseWheel", function(_, delta)
    if locked then return end
    local s = math.floor((GetScale(key) + delta * 0.1) * 10 + 0.5) / 10
    ns.Set({ "banners", key .. "Scale" }, math.min(MAX_SCALE, math.max(MIN_SCALE, s)))
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

-- Re-apply size/position when a banner setting changes, the Alert Banners
-- page is reset, or everything is reset (path is empty then).
ns:Listen("SETTING_CHANGED", function(path)
  if path and path[1] ~= nil and path[1] ~= "banners" then return end
  for _, f in pairs(banners) do ApplyLayout(f) end
end)

-- Forget the dragged positions (sizes are kept).
function ns.ResetBannerPositions()
  ns.db.banners.threat, ns.db.banners.cc = nil, nil
  ns:Fire("SETTING_CHANGED", { "banners" }, nil)
end

ns:Listen("TOGGLE_BANNER_LOCK", function()
  locked = not locked
  for _, f in pairs(banners) do
    f:EnableMouse(not locked)
    f:EnableMouseWheel(not locked)
    -- while unlocked, sit above the options window so they can be dragged
    f:SetFrameStrata(locked and "HIGH" or "FULLSCREEN_DIALOG")
    if locked then f:Hide() else f.anim:Stop(); f:SetAlpha(1); f:Show() end
  end
  if not locked then
    banners.threat.title:SetText("THREAT LOST")
    banners.threat.sub:SetText("Drag to move, mouse wheel to resize")
    banners.cc.title:SetText("CC BROKEN - drag / scroll me")
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
