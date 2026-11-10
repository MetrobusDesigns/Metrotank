--[[
  Bulwark - Options.lua
  ---------------------
  The options window with a search bar.

  Every option is ONE entry in the OPTIONS list below. To add a new option,
  copy a line, change the label and the "path" (where it's saved), and it
  automatically appears in the window AND becomes searchable.
]]

local _, ns = ...

---------------------------------------------------------------------------
-- Look & feel
---------------------------------------------------------------------------
local C = {
  bg     = { 0.055, 0.063, 0.082, 0.97 },
  panel  = { 0.086, 0.098, 0.125, 1 },
  panel2 = { 0.114, 0.129, 0.161, 1 },
  line   = { 0.165, 0.184, 0.227, 1 },
  accent = { 0.31, 0.70, 1.00, 1 },
  accent2= { 0.17, 0.44, 0.66, 1 },
  muted  = { 0.55, 0.58, 0.65, 1 },
}
local ACCENT_HEX = "|cff4fb3ff"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Skin(frame, bg, border)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  frame:SetBackdropColor(unpack(bg or C.panel))
  frame:SetBackdropBorderColor(unpack(border or C.line))
end

local function Text(parent, template, size, r, g, b)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  if size then
    local font = fs:GetFont()
    fs:SetFont(font, size, "")
  end
  if r then fs:SetTextColor(r, g, b) end
  fs:SetJustifyH("LEFT")
  return fs
end

---------------------------------------------------------------------------
-- Sections (left menu) and options
---------------------------------------------------------------------------
local SECTIONS = {
  { key = "general",  label = "General",        color = { 0.55, 0.58, 0.65 } },
  { key = "threat",   label = "Threat",         color = { 1.00, 0.30, 0.30 } },
  { key = "cc",       label = "Crowd Control",  color = { 0.78, 0.42, 1.00 } },
  { key = "plates",   label = "Nameplates",     color = { 0.24, 0.81, 0.43 } },
  { key = "sounds",   label = "Sounds",         color = { 0.95, 0.76, 0.19 } },
  { key = "taunt",    label = "Taunt Cooldown", color = { 0.31, 0.70, 1.00 } },
  { key = "profiles", label = "Profiles",       color = { 0.35, 0.35, 0.35 } },
}
local SECTION_LABEL = {}
for _, s in ipairs(SECTIONS) do SECTION_LABEL[s.key] = s.label end

local TANK_MODES = {
  { key = "auto",   label = "Auto (group role / class)" },
  { key = "always", label = "Always on" },
  { key = "off",    label = "Off" },
}
local CHANNELS = {
  { key = "Master", label = "Master" }, { key = "SFX", label = "Sound effects" },
  { key = "Dialog", label = "Dialog" }, { key = "Ambience", label = "Ambience" },
  { key = "Music",  label = "Music" },
}

-- type: header | toggle | choice | sound | slider | colors | text | button
local OPTIONS = {
  -- General
  { s = "general", type = "header", label = "Basics" },
  { s = "general", type = "toggle", label = "Enable Bulwark", desc = "Turn every alert on or off", path = { "general", "enabled" }, keys = "on off disable" },
  { s = "general", type = "choice", label = "Tank mode", desc = "When should tank alerts run?", path = { "general", "tankMode" }, choices = TANK_MODES, keys = "role spec auto" },
  { s = "general", type = "toggle", label = "Debug messages", desc = "Print what the addon sees to chat (for testing)", path = { "general", "debug" }, keys = "test print chat" },

  -- Threat
  { s = "threat", type = "header", label = "Threat alerts" },
  { s = "threat", type = "toggle", label = "Alert when I lose threat", desc = "Banner + sound when a mob turns away from you", path = { "threat", "alertLost" }, keys = "aggro warning banner" },
  { s = "threat", type = "toggle", label = "Warn when threat is slipping", desc = "Someone is close to pulling the mob off you", path = { "threat", "alertSlipping" }, keys = "aggro close" },
  { s = "threat", type = "toggle", label = "Show threat banner", desc = "Big center-screen message", path = { "threat", "showBanner" }, keys = "text screen" },
  { s = "threat", type = "toggle", label = "Only in a group", desc = "Stay quiet while soloing", path = { "threat", "onlyInGroup" }, keys = "solo party" },
  { s = "threat", type = "sound",  label = "Lost-threat sound", desc = "Plays once per mob, then waits for the cooldown", path = { "threat", "lostSound" }, keys = "audio noise" },
  { s = "threat", type = "sound",  label = "Slipping sound", desc = "Optional softer warning", path = { "threat", "slipSound" }, keys = "audio noise" },
  { s = "threat", type = "header", label = "Colors" },
  { s = "threat", type = "colors", label = "Threat colors", colors = { { "hold", "Holding" }, { "slip", "Slipping" }, { "lost", "Lost" }, { "other", "Other tank" } }, keys = "color colour" },

  -- Crowd control
  { s = "cc", type = "header", label = "Crowd control" },
  { s = "cc", type = "toggle", label = "Watch crowd control", desc = "Sheep, sap, shackle, trap, hibernate...", path = { "cc", "enabled" }, keys = "cc polymorph sap" },
  { s = "cc", type = "toggle", label = "Alert even when unsure", desc = "In dungeons we can't tell 'broke' from 'ran out'", path = { "cc", "alertWhenUnknown" }, keys = "cc ended expired" },
  { s = "cc", type = "toggle", label = "Show CC banner", desc = "Center-screen 'CC BROKEN' message", path = { "cc", "showBanner" }, keys = "cc text" },
  { s = "cc", type = "sound",  label = "CC-broken ping sound", desc = "Played when CC ends early", path = { "cc", "breakSound" }, keys = "cc audio ping" },
  { s = "cc", type = "slider", label = "Number of pings", desc = "How many times the ping plays", path = { "cc", "pingCount" }, min = 1, max = 3, step = 1, fmt = "%d", keys = "cc repeat" },
  { s = "cc", type = "slider", label = "Highlight time", desc = "Seconds the plate stays orange", path = { "cc", "flashSeconds" }, min = 1, max = 10, step = 1, fmt = "%d s", keys = "cc flash duration" },
  { s = "cc", type = "colors", label = "CC colors", colors = { { "cc", "CC'd" }, { "broken", "Broken" } }, keys = "cc color colour" },

  -- Nameplates
  { s = "plates", type = "header", label = "Nameplate look" },
  { s = "plates", type = "toggle", label = "Colored border", desc = "Works with Plater, Platynator and EllesmereUI", path = { "plates", "border" }, keys = "outline glow" },
  { s = "plates", type = "toggle", label = "Recolor health bar", desc = "Blizzard nameplates only", path = { "plates", "recolorBar" }, keys = "color colour bar" },
  { s = "plates", type = "toggle", label = "Show state label", desc = "Small text under the plate: LOST, CC'D...", path = { "plates", "showTag" }, keys = "text tag" },
  { s = "plates", type = "toggle", label = "Show icon", desc = "Small icon beside the plate", path = { "plates", "showIcon" }, keys = "icon" },
  { s = "plates", type = "toggle", label = "Pulse when lost / broken", desc = "Border blinks to catch your eye", path = { "plates", "pulseOnLost" }, keys = "flash blink animation" },

  -- Sounds
  { s = "sounds", type = "header", label = "Sound settings" },
  { s = "sounds", type = "choice", label = "Sound channel", desc = "'Master' still plays when effects are muted", path = { "sounds", "channel" }, choices = CHANNELS, keys = "audio volume" },
  { s = "sounds", type = "slider", label = "Sound cooldown", desc = "Seconds before the same sound can play again", path = { "sounds", "cooldown" }, min = 0, max = 5, step = 0.5, fmt = "%.1f s", keys = "audio spam" },

  -- Taunt
  { s = "taunt", type = "header", label = "Taunt cooldown" },
  { s = "taunt", type = "toggle", label = "Show taunt on threat banner", desc = "Icon with cooldown swipe", path = { "taunt", "showOnBanner" }, keys = "taunt growl cooldown" },
  { s = "taunt", type = "text",   label = "Taunt spell (name or ID)", desc = "Leave empty to pick automatically", path = { "taunt", "spell" }, keys = "taunt growl spell" },

  -- Profiles
  { s = "profiles", type = "header", label = "Profiles" },
  { s = "profiles", type = "button", label = "Move alert banners", desc = "Unlock / lock the banners so you can drag them", button = "Unlock", run = function() ns:Fire("TOGGLE_BANNER_LOCK") end, keys = "position move drag" },
  { s = "profiles", type = "button", label = "Reset everything", desc = "Put every setting back to default", button = "Reset", run = function() SlashCmdList.BULWARK("reset") end, keys = "default" },
}

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local ROW_W, ROW_H, HEADER_H = 470, 52, 26

local function MakeToggle(row, opt)
  local b = CreateFrame("Button", nil, row)
  b:SetSize(38, 20)
  b:SetPoint("RIGHT", -12, 0)
  b.track = b:CreateTexture(nil, "BACKGROUND"); b.track:SetAllPoints(); b.track:SetColorTexture(1, 1, 1, 1)
  b.knob = b:CreateTexture(nil, "ARTWORK"); b.knob:SetSize(14, 14); b.knob:SetColorTexture(1, 1, 1, 1)
  b:SetScript("OnClick", function() ns.Set(opt.path, not ns.Get(opt.path)) end)
  row.Refresh = function()
    local on = ns.Get(opt.path)
    b.knob:ClearAllPoints()
    if on then
      b.track:SetVertexColor(unpack(C.accent2)); b.knob:SetVertexColor(1, 1, 1)
      b.knob:SetPoint("RIGHT", -3, 0)
    else
      b.track:SetVertexColor(0.21, 0.23, 0.28); b.knob:SetVertexColor(0.67, 0.69, 0.75)
      b.knob:SetPoint("LEFT", 3, 0)
    end
  end
end

local function LabelFor(list, key)
  for _, c in ipairs(list) do if c.key == key then return c.label end end
  return key
end

-- A dropdown-style button. Uses Blizzard's modern menu when available.
local function MakeDropdown(row, opt, list, rightOffset)
  local b = CreateFrame("Button", nil, row, "BackdropTemplate")
  b:SetSize(150, 26)
  b:SetPoint("RIGHT", -(rightOffset or 12), 0)
  Skin(b, C.panel2)
  b.text = Text(b, "GameFontHighlightSmall"); b.text:SetPoint("LEFT", 9, 0)
  b.arrow = Text(b, "GameFontHighlightSmall"); b.arrow:SetPoint("RIGHT", -8, 0); b.arrow:SetText("v")

  b:SetScript("OnClick", function(self)
    if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(self, function(_, root)
        for _, item in ipairs(list) do
          root:CreateRadio(item.label,
            function() return ns.Get(opt.path) == item.key end,
            function() ns.Set(opt.path, item.key) end)
        end
      end)
    else
      -- fallback: click to cycle
      local cur, nextIndex = ns.Get(opt.path), 1
      for i, item in ipairs(list) do if item.key == cur then nextIndex = (i % #list) + 1 end end
      ns.Set(opt.path, list[nextIndex].key)
    end
  end)
  row.Refresh = function() b.text:SetText(LabelFor(list, ns.Get(opt.path))) end
  return b
end

local function MakeSound(row, opt)
  local list = {}
  for _, s in ipairs(ns.Sounds) do table.insert(list, { key = s.key, label = s.label }) end
  local play = CreateFrame("Button", nil, row, "BackdropTemplate")
  play:SetSize(26, 26)
  play:SetPoint("RIGHT", -12, 0)
  Skin(play, { 0.14, 0.20, 0.28, 1 }, C.accent2)
  local t = Text(play, "GameFontHighlight"); t:SetPoint("CENTER", 1, 0); t:SetText(ACCENT_HEX .. ">|r")
  play:SetScript("OnClick", function() ns.PlayAlertSound(ns.Get(opt.path), true) end)
  MakeDropdown(row, opt, list, 44)
end

local function MakeSlider(row, opt)
  local s = CreateFrame("Slider", nil, row)
  s:SetSize(140, 16)
  s:SetPoint("RIGHT", -56, 0)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(opt.min, opt.max)
  s:SetValueStep(opt.step)
  s:SetObeyStepOnDrag(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.18, 0.20, 0.25, 1); track:SetHeight(5)
  track:SetPoint("LEFT"); track:SetPoint("RIGHT")
  s:SetThumbTexture(WHITE)
  local thumb = s:GetThumbTexture(); thumb:SetSize(12, 12); thumb:SetVertexColor(1, 1, 1)
  local val = Text(row, "GameFontHighlightSmall", nil, unpack(C.muted))
  val:SetPoint("RIGHT", -12, 0); val:SetWidth(40); val:SetJustifyH("RIGHT")

  s:SetScript("OnValueChanged", function(_, v, userInput)
    val:SetText(string.format(opt.fmt, v))
    if userInput then ns.Set(opt.path, v) end
  end)
  row.Refresh = function()
    local v = ns.Get(opt.path)
    s:SetValue(v)
    val:SetText(string.format(opt.fmt, v))
  end
end

local function OpenColorPicker(colorKey)
  local c = ns.db.colors[colorKey]
  local old = { r = c.r, g = c.g, b = c.b }
  local function apply(r, g, b)
    c.r, c.g, c.b = r, g, b
    ns:Fire("SETTING_CHANGED", { "colors", colorKey }, c)
  end
  if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = c.r, g = c.g, b = c.b, hasOpacity = false,
      swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
      cancelFunc = function() apply(old.r, old.g, old.b) end,
    })
  end
end

local function MakeColors(row, opt)
  local swatches = {}
  local x = -12
  for i = #opt.colors, 1, -1 do
    local key, label = opt.colors[i][1], opt.colors[i][2]
    local sw = CreateFrame("Button", nil, row, "BackdropTemplate")
    sw:SetSize(24, 18)
    sw:SetPoint("RIGHT", x, 0)
    Skin(sw, { 1, 1, 1, 1 }, { 0, 0, 0, 1 })
    sw:SetScript("OnClick", function() OpenColorPicker(key) end)
    local l = Text(row, "GameFontHighlightSmall", nil, unpack(C.muted))
    l:SetPoint("RIGHT", sw, "LEFT", -6, 0)
    l:SetText(label)
    swatches[key] = sw
    x = x - 30 - l:GetStringWidth() - 14
  end
  row.Refresh = function()
    for key, sw in pairs(swatches) do
      local c = ns.db.colors[key]
      sw:SetBackdropColor(c.r, c.g, c.b, 1)
    end
  end
end

local function MakeTextInput(row, opt)
  local e = CreateFrame("EditBox", nil, row, "BackdropTemplate")
  e:SetSize(150, 26)
  e:SetPoint("RIGHT", -12, 0)
  Skin(e, C.panel2)
  e:SetFontObject("GameFontHighlightSmall")
  e:SetTextInsets(8, 8, 0, 0)
  e:SetAutoFocus(false)
  e:SetScript("OnEnterPressed", function(self) ns.Set(opt.path, self:GetText()); self:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row.Refresh() end)
  row.Refresh = function() e:SetText(ns.Get(opt.path) or "") end
end

local function MakeButton(parent, label, width, onClick, primary)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width or 110, 26)
  Skin(b, primary and C.accent2 or C.panel2, primary and C.accent or C.line)
  b.text = Text(b, "GameFontHighlightSmall"); b.text:SetPoint("CENTER"); b.text:SetText(label)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(primary and C.accent or C.line)) end)
  return b
end

---------------------------------------------------------------------------
-- Build one row
---------------------------------------------------------------------------
local function CreateRow(parent, opt)
  local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  row.opt = opt
  row.Refresh = function() end

  if opt.type == "header" then
    row:SetSize(ROW_W, HEADER_H)
    row.label = Text(row, "GameFontNormalSmall", 10, unpack(C.muted))
    row.label:SetPoint("BOTTOMLEFT", 2, 6)
    row.label:SetText(opt.label:upper())
    return row
  end

  row:SetSize(ROW_W, ROW_H)
  Skin(row, C.panel)
  row.crumb = Text(row, "GameFontNormalSmall", 9); row.crumb:SetTextColor(unpack(C.accent))
  row.label = Text(row, "GameFontHighlight", 13)
  row.desc  = Text(row, "GameFontHighlightSmall", 11, unpack(C.muted))

  if opt.type == "toggle" then MakeToggle(row, opt)
  elseif opt.type == "choice" then MakeDropdown(row, opt, opt.choices)
  elseif opt.type == "sound" then MakeSound(row, opt)
  elseif opt.type == "slider" then MakeSlider(row, opt)
  elseif opt.type == "colors" then MakeColors(row, opt)
  elseif opt.type == "text" then MakeTextInput(row, opt)
  elseif opt.type == "button" then
    local b = MakeButton(row, opt.button, 90, opt.run)
    b:SetPoint("RIGHT", -12, 0)
  end
  return row
end

-- Position the text inside a row depending on search mode
local function LayoutRowText(row, query)
  local opt = row.opt
  local label = opt.label
  if query ~= "" then
    local s, e = label:lower():find(query, 1, true)
    if s then
      label = label:sub(1, s - 1) .. ACCENT_HEX .. label:sub(s, e) .. "|r" .. label:sub(e + 1)
    end
    row.crumb:SetText(SECTION_LABEL[opt.s]:upper())
    row.crumb:ClearAllPoints(); row.crumb:SetPoint("TOPLEFT", 12, -9)
    row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", row.crumb, "BOTTOMLEFT", 0, -3)
    row.crumb:Show(); row.desc:Hide()
  else
    row.label:ClearAllPoints()
    if opt.desc then
      row.label:SetPoint("TOPLEFT", 12, -10)
      row.desc:ClearAllPoints(); row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
      row.desc:SetText(opt.desc); row.desc:Show()
    else
      row.label:SetPoint("LEFT", 12, 0)
      row.desc:Hide()
    end
    row.crumb:Hide()
  end
  row.label:SetText(label)
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------
local win, rows, navButtons = nil, {}, {}
local currentSection, query = "threat", ""

local function Matches(opt, q)
  if opt.type == "header" then return false end
  local hay = (opt.label .. " " .. (opt.desc or "") .. " " .. (opt.keys or "") .. " " .. SECTION_LABEL[opt.s]):lower()
  return hay:find(q, 1, true) ~= nil
end

local function RefreshList()
  if not win then return end
  local y, counts, total = -4, {}, 0

  for _, row in ipairs(rows) do
    local opt, show = row.opt, false
    if query ~= "" then
      show = Matches(opt, query)
      if show then counts[opt.s] = (counts[opt.s] or 0) + 1; total = total + 1 end
    else
      show = (opt.s == currentSection)
    end

    if show then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
      if opt.type ~= "header" then LayoutRowText(row, query) end
      row.Refresh()
      row:Show()
      y = y - row:GetHeight() - 8
    else
      row:Hide()
    end
  end
  win.content:SetHeight(math.max(-y, 10))

  -- left menu highlight + result counts
  for key, nb in pairs(navButtons) do
    local active = (query == "" and key == currentSection) or (query ~= "" and counts[key])
    nb.bar:SetShown(active and true or false)
    nb:SetBackdropColor(unpack(active and { 0.137, 0.161, 0.216, 1 } or { 0, 0, 0, 0 }))
    nb.label:SetTextColor(unpack(active and { 0.9, 0.91, 0.93 } or C.muted))
    if query ~= "" and counts[key] then nb.count:SetText(counts[key]); nb.count:Show() else nb.count:Hide() end
  end

  win.results:SetText(query ~= "" and (total .. " results") or "")
  win.placeholder:SetShown(query == "" and not win.search:HasFocus())
  win.modeBtn.text:SetText("Tank mode: " .. LabelFor(TANK_MODES, ns.db.general.tankMode):gsub(" %(.*%)", ""))
end

local function BuildWindow()
  win = CreateFrame("Frame", "BulwarkOptions", UIParent, "BackdropTemplate")
  win:SetSize(720, 540)
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetClampedToScreen(true)
  Skin(win, C.bg)
  win:SetMovable(true); win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  table.insert(UISpecialFrames, "BulwarkOptions") -- Esc closes it

  -- Title bar
  local title = CreateFrame("Frame", nil, win, "BackdropTemplate")
  title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT"); title:SetHeight(44)
  Skin(title, C.panel)
  local icon = title:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24); icon:SetPoint("LEFT", 14, 0)
  icon:SetTexture("Interface\\Icons\\Ability_Warrior_DefensiveStance")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local t = Text(title, "GameFontNormalLarge", 16, 1, 1, 1); t:SetPoint("LEFT", icon, "RIGHT", 10, 0); t:SetText("Bulwark")
  local v = Text(title, "GameFontHighlightSmall", 11, unpack(C.muted)); v:SetPoint("LEFT", t, "RIGHT", 8, -1)
  v:SetText("Tank Alerts  v" .. ns.version)
  local close = CreateFrame("Button", nil, title, "UIPanelCloseButton")
  close:SetPoint("RIGHT", -6, 0)

  -- Search bar
  local sb = CreateFrame("EditBox", nil, win, "BackdropTemplate")
  sb:SetPoint("TOPLEFT", 16, -56); sb:SetSize(450, 32)
  Skin(sb, C.panel2)
  sb:SetFontObject("GameFontHighlight")
  sb:SetTextInsets(30, 70, 0, 0)
  sb:SetAutoFocus(false)
  local mag = sb:CreateTexture(nil, "OVERLAY")
  mag:SetSize(14, 14); mag:SetPoint("LEFT", 10, 0)
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  win.placeholder = Text(sb, "GameFontHighlight", 13, unpack(C.muted))
  win.placeholder:SetPoint("LEFT", 30, 0)
  win.placeholder:SetText("Search options... (try \"sound\", \"color\", \"cc\")")
  win.results = Text(sb, "GameFontHighlightSmall", 11, unpack(C.muted))
  win.results:SetPoint("RIGHT", -10, 0)
  sb:SetScript("OnTextChanged", function(self)
    query = (self:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    RefreshList()
  end)
  sb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)); win.placeholder:Hide() end)
  sb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.line)); RefreshList() end)
  sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  win.search = sb

  -- Pills
  win.modeBtn = MakeButton(win, "Tank mode", 130, function()
    local cur, nextIndex = ns.db.general.tankMode, 1
    for i, m in ipairs(TANK_MODES) do if m.key == cur then nextIndex = (i % #TANK_MODES) + 1 end end
    ns.Set({ "general", "tankMode" }, TANK_MODES[nextIndex].key)
  end, true)
  win.modeBtn:SetPoint("LEFT", sb, "RIGHT", 10, 0); win.modeBtn:SetHeight(32)
  local testBtn = MakeButton(win, "Test alerts", 100, function()
    ns:Fire("TEST_THREAT")
    C_Timer.After(1.2, function() ns:Fire("TEST_CC") end)
  end)
  testBtn:SetPoint("LEFT", win.modeBtn, "RIGHT", 8, 0); testBtn:SetHeight(32)

  -- Left menu
  local side = CreateFrame("Frame", nil, win, "BackdropTemplate")
  side:SetPoint("TOPLEFT", 0, -100); side:SetPoint("BOTTOMLEFT", 0, 50); side:SetWidth(180)
  Skin(side, C.panel)
  for i, s in ipairs(SECTIONS) do
    local nb = CreateFrame("Button", nil, side, "BackdropTemplate")
    nb:SetSize(164, 30); nb:SetPoint("TOPLEFT", 8, -10 - (i - 1) * 33)
    nb:SetBackdrop({ bgFile = WHITE })
    nb.bar = nb:CreateTexture(nil, "OVERLAY"); nb.bar:SetColorTexture(unpack(C.accent))
    nb.bar:SetPoint("TOPLEFT"); nb.bar:SetPoint("BOTTOMLEFT"); nb.bar:SetWidth(3)
    local dot = nb:CreateTexture(nil, "ARTWORK"); dot:SetSize(7, 7); dot:SetPoint("LEFT", 12, 0)
    dot:SetColorTexture(s.color[1], s.color[2], s.color[3], 1)
    nb.label = Text(nb, "GameFontHighlight", 13); nb.label:SetPoint("LEFT", dot, "RIGHT", 10, 0); nb.label:SetText(s.label)
    nb.count = Text(nb, "GameFontHighlightSmall", 10, 1, 1, 1); nb.count:SetPoint("RIGHT", -10, 0)
    nb:SetScript("OnClick", function()
      currentSection = s.key
      win.search:SetText("")  -- clicking a section clears the search
      win.search:ClearFocus()
      RefreshList()
    end)
    navButtons[s.key] = nb
  end

  -- Scrolling content area
  local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", side, "TOPRIGHT", 18, -10)
  scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 58)
  win.content = CreateFrame("Frame", nil, scroll)
  win.content:SetSize(ROW_W, 10)
  scroll:SetScrollChild(win.content)

  for _, opt in ipairs(OPTIONS) do
    table.insert(rows, CreateRow(win.content, opt))
  end

  -- Footer
  local foot = CreateFrame("Frame", nil, win, "BackdropTemplate")
  foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT"); foot:SetHeight(50)
  Skin(foot, C.panel)
  local reset = MakeButton(foot, "Reset section", 110, function()
    if query == "" then ns.ResetSection(currentSection); RefreshList() end
  end)
  reset:SetPoint("LEFT", 16, 0)
  local tThreat = MakeButton(foot, "Test threat lost", 120, function() ns:Fire("TEST_THREAT") end)
  tThreat:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  local tCC = MakeButton(foot, "Test CC broken", 120, function() ns:Fire("TEST_CC") end)
  tCC:SetPoint("LEFT", tThreat, "RIGHT", 8, 0)
  local hint = Text(foot, "GameFontHighlightSmall", 11, unpack(C.muted))
  hint:SetPoint("RIGHT", -16, 0); hint:SetText("Changes save automatically")

  win:Hide()
end

local function Toggle()
  if not win then BuildWindow() end
  if win:IsShown() then win:Hide() else win:Show(); RefreshList() end
end
ns.ToggleOptions = Toggle

ns:Listen("TOGGLE_OPTIONS", Toggle)
ns:Listen("SETTING_CHANGED", function() if win and win:IsShown() then RefreshList() end end)

---------------------------------------------------------------------------
-- Small page in Esc > Options > AddOns that opens our window
---------------------------------------------------------------------------
ns:Listen("LOGIN", function()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame")
  local h = Text(panel, "GameFontNormalLarge"); h:SetPoint("TOPLEFT", 16, -16); h:SetText("Bulwark - Tank Alerts")
  local d = Text(panel, "GameFontHighlight"); d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
  d:SetText("All options live in Bulwark's own window (with search). You can also type /bulwark.")
  local b = MakeButton(panel, "Open Bulwark options", 180, function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if not win or not win:IsShown() then Toggle() end
  end, true)
  b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  local category = Settings.RegisterCanvasLayoutCategory(panel, "Bulwark")
  Settings.RegisterAddOnCategory(category)
end)
