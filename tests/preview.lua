-- Exercise owned preview behavior with simulated frames; native template geometry is not emulated.
local H = dofile("tests/helpers.lua")

for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local state = H.environment(interface)
  local env = state.env
  local methods = getmetatable(env.UIParent).__index
  for _, name in ipairs({
    "SetBackdrop",
    "SetBackdropColor",
    "SetBackdropBorderColor",
    "SetClipsChildren",
    "EnableMouseWheel",
    "RegisterForDrag",
    "DisableButton",
    "SetJustifyH",
    "SetWordWrap",
  }) do
    methods[name] = function() end
  end
  function methods:GetSize()
    return self.width, self.height
  end
  function methods:SetPoint(...)
    self.point = { ... }
  end
  function methods:SetScale(scale)
    self.scale = scale
  end
  function methods:GetEffectiveScale()
    return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
  end
  function methods:SetLabel(label)
    self.label = label
  end
  function methods:SetDisabled(value)
    self.disabled = value
  end
  function methods:HasFocus()
    return self.focus or false
  end
  function methods:ClearFocus()
    self.focus = false
  end
  function methods:IsVisible()
    return self.visible and (not self.parent or self.parent:IsVisible())
  end
  function methods:Show()
    local changed = not self.visible
    self.visible = true
    if changed and self.scripts.OnShow then
      self.scripts.OnShow(self)
    end
  end
  function methods:Hide()
    local changed = self.visible
    self.visible = false
    if changed and self.scripts.OnHide then
      self.scripts.OnHide(self)
    end
  end
  function methods:SetShown(value)
    if value then
      self:Show()
    else
      self:Hide()
    end
  end
  function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...)
      if previous then
        previous(...)
      end
      callback(...)
    end
  end
  function methods:SetClampRectInsets(...)
    self.insets = { ... }
  end
  function methods:GetClampRectInsets()
    return table.unpack(self.insets or { 0, 0, 0, 0 })
  end
  function methods:SetClampedToScreen(value)
    self.clamped = value
  end
  function methods:IsClampedToScreen()
    return self.clamped or false
  end
  function methods:SetResizeBounds(...)
    self.bounds = { ... }
  end
  function methods:GetResizeBounds()
    return table.unpack(self.bounds or { 400, 200 }, 1, 4)
  end
  env.UIParent:SetSize(1920, 1080)
  env.GetCursorPosition = function()
    return state.cursorX or 0, state.cursorY or 0
  end
  env.AnchorUtil.CreateFlowLayout = function()
    return {
      SetAnchorPoint = function() end,
      SetGrowthDirection = function() end,
      SetMaximumLineSize = function(_, value)
        state.previewLineSize = value
      end,
      Apply = function(_, block, groups)
        local width, height = 0, 0
        for _, group in ipairs(groups) do
          for _, button in ipairs(group.elements) do
            width, height = width + button:GetWidth(), math.max(height, button:GetHeight())
          end
        end
        block:SetSize(width, height)
      end,
    }
  end
  local gui = env.LibStub("AceGUI-3.0")
  gui.ClearFocus = function() end
  local create = gui.Create
  function gui:Create(kind)
    local widget = create(self)
    widget.type = kind
    widget.editbox = env.CreateFrame("EditBox", nil, widget.frame)
    widget.frame:Hide() -- AceGUI constructors start hidden until a container shows them.
    return widget
  end
  local load = state.load
  state.load = function(path)
    if path:match("preview%-nameplate%.lua$") then
      state.ns.PreviewNameplate = {
        Create = function(_, parent)
          local plate = env.CreateFrame("Frame", nil, parent)
          plate.Refresh = function(self)
            self:SetSize(110, 12)
          end
          plate:Refresh()
          return plate
        end,
      }
    else
      load(path)
    end
  end
  H.loadAddon(state)
  local ns = state.ns
  local owner = gui:Create("Frame")
  owner.frame:SetSize(900, 650)
  owner.frame:Show()
  owner.status = { height = 650 }
  function owner:SetHeight(value)
    self.frame:SetHeight(value)
  end
  local dialog = env.LibStub("AceConfigDialog-3.0")
  local previewButton = gui:Create("Button")
  function previewButton:GetUserDataTable()
    return { path = { "preview" } }
  end
  owner.children = { previewButton }
  dialog.OpenFrames.flyPlateBuffsFixed = owner
  local function showPage(page, key)
    local options = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
    if key then
      dialog:FeedGroup("flyPlateBuffsFixed", options, nil, nil, { "spells", "number:" .. key })
    end
    dialog:FeedGroup("flyPlateBuffsFixed", options, { children = {} }, nil, { page })
  end
  showPage("display")
  ns.Preview:Attach(owner)
  local dock
  for _, frame in ipairs(state.created) do
    if frame.more and frame.animate then
      dock = frame
    end
  end
  assert(dock and dock:GetParent() == owner.frame)
  assert(not dock:IsShown(), "opening settings on Display does not open the preview")
  H.equal(previewButton:GetText(), "Preview")
  showPage("style")
  assert(dock:IsVisible())
  H.equal(previewButton:GetText(), "Stop preview", "automatic visibility updates the existing button")
  assert(dock.animate.frame:IsVisible() and dock.more.frame:IsVisible())
  H.equal(dock.animate.frame.point[2], dock.more.frame, "Animate is beside Show more spells")
  H.equal(dock.animate.frame.point[3], "LEFT")
  local height = ns.Client.modern and 225 or 175
  H.equal(owner.frame.insets[3], height - 8, "clamping includes the attached preview")
  H.equal(dock:GetHeight(), height)
  ns.Options:TogglePreview()
  assert(not dock:IsShown(), "Stop preview also stops an automatically shown preview")
  H.equal(previewButton:GetText(), "Preview")
  ns.Options:Refresh()
  showPage("style")
  assert(not dock:IsShown(), "redraws and setting edits do not undo Stop preview")
  showPage("position")
  assert(not dock:IsShown(), "leaving Style hides an automatically shown preview")
  showPage("spells")
  assert(not dock:IsShown(), "the Spells tab needs a selected spell")
  showPage("style")
  local function visibleButtons()
    local buttons = {}
    for _, frame in ipairs(state.created) do
      if frame.sample and frame:IsShown() then
        buttons[#buttons + 1] = frame
      end
    end
    return buttons
  end
  H.equal(#visibleButtons(), 6, "general preview starts with six samples")
  if ns.Client.modern then
    local profile = ns.db.profile
    local width, gap, count = profile.baseWidth, profile.xInterval, profile.buffPerLine
    for _, case in ipairs({
      { 5, -10, 2, 5 },
      { 5, -10, 3, 5 },
      { 5, -2, 3, 11 },
      { 24, 2, 3, 76 },
    }) do
      profile.baseWidth, profile.xInterval, profile.buffPerLine = case[1], case[2], case[3]
      ns.Preview:Refresh()
      H.equal(state.previewLineSize, case[4], "preview uses the same bounded row width as live icons")
    end
    profile.baseWidth, profile.xInterval, profile.buffPerLine = width, gap, count
    ns.Preview:Refresh()
  end
  local expected = { [118] = 1, [642] = 1, [853] = 1, [339] = 1, [1044] = 1, [2094] = 1 }
  local function sampleCounts()
    local counts = {}
    for _, sampleButton in ipairs(visibleButtons()) do
      local id = sampleButton.sample.id
      counts[id] = (counts[id] or 0) + 1
    end
    return counts
  end
  local counts = sampleCounts()
  for id, count in pairs(expected) do
    H.equal(counts[id], count, "default sample spells match NPA")
  end
  assert(not dock.scripts.OnUpdate, "static preview does not run animation")
  local button = visibleButtons()[1]
  local staticText = button.Duration:GetText()
  state.time = state.time + 1
  ns.Preview:Refresh()
  H.equal(button.Duration:GetText(), staticText, "static sample time does not drain on refresh")
  dock.more.scripts.OnValueChanged(nil, nil, true)
  H.equal(#visibleButtons(), 12)
  counts = sampleCounts()
  for id in pairs(expected) do
    H.equal(counts[id], 2, "Show more uses the same paired spells as NPA")
  end
  ns.SpellRules:Add(ns.db.profile, "589")
  showPage("spells", 589)
  H.equal(#visibleButtons(), 1, "selected spell stays alone even with more samples enabled")
  H.equal(visibleButtons()[1].sample.id, 589)
  ns.db.profile.Spells[589].scale = 1.6
  ns.Preview:Refresh()
  H.equal(visibleButtons()[1]:GetWidth(), ns.db.profile.baseWidth * 1.6, "selected spell previews its own styling")
  assert(not dock.more.frame:IsShown())
  H.equal(dock.animate.frame.point[1], "BOTTOMRIGHT", "Animate remains visible for an individual spell")
  ns.Options.selectedSpell = nil -- Search/removal can leave the Spells tab without a selection.
  ns.Preview:Refresh()
  assert(not dock:IsShown())
  showPage("style")
  dock.animate.scripts.OnValueChanged(nil, nil, true)
  assert(dock.scripts.OnUpdate)
  state.time = state.time + 1
  dock.scripts.OnUpdate(dock, 0.1)
  button = visibleButtons()[1]
  assert(button.remaining < button.sample.time)
  local viewport
  for _, frame in ipairs(state.created) do
    if frame.instructions and frame.scene then
      viewport = frame
    end
  end
  H.equal(viewport.zoomLabel.point[1], "BOTTOMLEFT")
  H.equal(viewport.instructions.point[2], viewport.zoomLabel)
  H.equal(viewport.reset.frame.point[2], viewport.instructions)
  assert(not viewport.zoomInput and not viewport.zoomIn and not viewport.zoomOut)
  assert(not viewport.reset.frame:IsShown())
  viewport.scripts.OnMouseWheel(viewport, 1)
  H.equal(viewport.zoom, 125)
  assert(viewport.reset.frame:IsVisible(), "Reset is shown even though AceGUI created it hidden")
  viewport.scripts.OnDragStart(viewport)
  state.cursorX = 125
  viewport.scripts.OnUpdate(viewport)
  H.equal(viewport.panX, 100)
  viewport.scripts.OnDragStop(viewport)
  assert(not viewport.scripts.OnUpdate)
  viewport.reset.scripts.OnClick()
  H.equal(viewport.zoom, 100)
  H.equal(viewport.panX, 0)
  showPage("display")
  assert(not dock:IsShown() and not dock.scripts.OnUpdate)
  H.equal(owner.frame.insets[3], 0, "hiding the dock restores the settings frame immediately")
  H.equal(owner.frame.bounds[1], 400)
  assert(not owner.frame.clamped)
  ns.Options:TogglePreview()
  H.equal(previewButton:GetText(), "Stop preview")
  H.equal(owner.frame.insets[3], height - 8)
  assert(dock.scripts.OnUpdate)
  showPage("sorting")
  assert(dock:IsVisible(), "a manually opened preview stays visible across tabs")
  ns.Options:TogglePreview()
  assert(not dock:IsShown())
  H.equal(previewButton:GetText(), "Preview")
  ns.Options:TogglePreview()
  owner.frame:Hide()
  assert(not dock:IsShown() and not dock.scripts.OnUpdate and not viewport.scripts.OnUpdate)
  assert(dock:GetParent() == env.UIParent, "detach before AceGUI reuses the settings frame")
  H.equal(owner.frame.insets[3], 0)
  H.equal(owner.frame.bounds[1], 400)
  assert(not owner.frame.clamped)
  owner.frame:Show()
  ns.Preview:Attach(owner)
  assert(not dock:IsShown(), "closing settings clears manual preview visibility")
  showPage("style")
  assert(dock.scripts.OnUpdate, "animation preference survives closing the settings window")
  print("Simulated dock, preview controls, selection and animation:", interface)
end
