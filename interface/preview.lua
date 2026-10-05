local _, fPB = ...

local ipairs = ipairs
local setmetatable = setmetatable
local unpack = unpack
local CreateFrame = CreateFrame
local GenerateClosure = GenerateClosure
local GetTime = GetTime
local LibStub = LibStub
local UIParent = UIParent
local mmax = math.max
local After = C_Timer.After

local Client = fPB.Client
local Options = fPB.Options
local PreviewScene = fPB.PreviewScene
local PreviewViewport = fPB.PreviewViewport

local Preview = {}
fPB.Preview = Preview

local AceGUI = LibStub("AceGUI-3.0")
local dock, owner, scene, ownerState, requested
local animate, more, detached = false, false, false
local hookedOwners = setmetatable({}, { __mode = "k" })
local backdrop = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 },
}
local nameplateCVars =
  { nameplateStyle = true, nameplateSize = true, nameplateAuraScale = true, nameplateDebuffPadding = true }

local function restoreOwner()
  owner.frame:SetClampRectInsets(unpack(ownerState.insets))
  owner.frame:SetClampedToScreen(ownerState.clamped)
  owner.frame:SetResizeBounds(unpack(ownerState.bounds, 1, 4))
end

local function fitDock(visible)
  local height = Client.modern and 225 or 175
  if not detached then
    dock:SetHeight(height)
  end
  if not visible or detached then
    restoreOwner()
    return
  end
  local extension = height - 8
  local maximum = mmax(320, UIParent:GetHeight() - extension - 32)
  owner.frame:SetResizeBounds(640, 320, nil, maximum)
  if owner.frame:GetHeight() > maximum then
    owner:SetHeight(maximum)
    owner.status.height = maximum
  end
  owner.frame:SetClampRectInsets(0, 0, extension, 0)
  owner.frame:SetClampedToScreen(true)
end

local function updateAnimation(_, elapsed)
  PreviewScene:Animate(scene, elapsed)
end

local function shown()
  scene.started, scene.elapsed = GetTime(), 0
  dock:SetScript("OnUpdate", animate and updateAnimation or nil)
end

local function hidden()
  dock:StopMovingOrSizing()
  dock:SetScript("OnUpdate", nil)
  scene.viewport:SetScript("OnUpdate", nil)
  AceGUI:ClearFocus()
end

local function toggleAnimate(_, _, value)
  animate = value
  shown()
  Preview:Refresh()
end

local function toggleMore(_, _, value)
  more = value
  Preview:Refresh()
end

local function openElement(kind)
  Options:Open(kind == "auras" and "position" or "style")
end

local function changed(_, event, name)
  if dock:IsVisible() and (event == "DISPLAY_SIZE_CHANGED" or nameplateCVars[name]) then
    After(0, GenerateClosure(Preview.Refresh, Preview))
  end
end

local function check(label, width, callback)
  local control = AceGUI:Create("CheckBox")
  control.frame:SetParent(dock)
  control:SetLabel(label)
  control:SetWidth(width)
  control:SetValue(false)
  control:SetCallback("OnValueChanged", callback)
  control.frame:Show()
  return control
end

local function attachDock()
  detached = false
  dock:StopMovingOrSizing()
  dock:SetMovable(false)
  dock:SetResizable(false)
  dock.resize:Hide()
  dock:SetClampedToScreen(false)
  dock:SetFrameStrata(owner.frame:GetFrameStrata())
  dock:SetFrameLevel(owner.frame:GetFrameLevel() - 1)
  dock:ClearAllPoints()
  dock:SetPoint("BOTTOMLEFT", owner.frame, "TOPLEFT", 0, -8)
  dock:SetPoint("BOTTOMRIGHT", owner.frame, "TOPRIGHT", 0, -8)
  dock.title:Hide()
  dock.attachment:SetText("Detach")
  PreviewViewport:SetMovingFrame(scene.viewport, nil)
end

local function toggleAttachment()
  if detached then
    attachDock()
  else
    local width = dock:GetWidth()
    detached = true
    dock:ClearAllPoints()
    dock:SetWidth(width)
    dock:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dock:SetFrameStrata("TOOLTIP")
    dock:SetFrameLevel(owner.frame:GetFrameLevel() + 1)
    dock:SetMovable(true)
    dock:SetResizable(true)
    dock:SetClampedToScreen(true)
    dock.title:Show()
    dock.attachment:SetText("Attach")
    PreviewViewport:SetMovingFrame(scene.viewport, dock)
    local viewport = scene.viewport
    local footerWidth = 18
      + viewport.zoomLabel:GetStringWidth()
      + 12
      + viewport.instructions:GetStringWidth()
      + 8
      + viewport.reset.frame:GetWidth()
      + 12
      + dock.animate.frame:GetWidth()
      + 12
      + dock.more.frame:GetWidth()
      + 18
    dock:SetResizeBounds(mmax(640, footerWidth), 120)
    dock.resize:Show()
  end
  Preview:Refresh()
end

local function createTitle(frameLevel)
  local title = CreateFrame("Frame", nil, dock)
  title:SetPoint("TOP", 0, 12)
  title:SetSize(160, 40)
  title:SetFrameLevel(frameLevel)
  PreviewViewport:Bind(scene.viewport, title)

  local middle = title:CreateTexture(nil, "BACKGROUND")
  middle:SetTexture(131080)
  middle:SetTexCoord(0.31, 0.67, 0, 0.63)
  middle:SetPoint("TOP")
  middle:SetSize(100, 40)
  local left = title:CreateTexture(nil, "BACKGROUND")
  left:SetTexture(131080)
  left:SetTexCoord(0.21, 0.31, 0, 0.63)
  left:SetPoint("RIGHT", middle, "LEFT")
  left:SetSize(30, 40)
  local right = title:CreateTexture(nil, "BACKGROUND")
  right:SetTexture(131080)
  right:SetTexCoord(0.67, 0.77, 0, 0.63)
  right:SetPoint("LEFT", middle, "RIGHT")
  right:SetSize(30, 40)
  title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title.text:SetPoint("TOP", 0, -14)
  title.text:SetText("Preview")
  title:Hide()
  return title
end

local function startSizing(direction, _, button)
  if button == "LeftButton" then
    AceGUI:ClearFocus()
    dock:StartSizing(direction)
  end
end

local function stopSizing()
  dock:StopMovingOrSizing()
end

local function createResizeHandle(parent, direction)
  local handle = CreateFrame("Frame", nil, parent)
  handle:EnableMouse(true)
  handle:SetScript("OnMouseDown", GenerateClosure(startSizing, direction))
  handle:SetScript("OnMouseUp", stopSizing)
  return handle
end

local function createResizeHandles(frameLevel)
  local handles = CreateFrame("Frame", nil, dock)
  handles:SetAllPoints(dock)
  handles:SetFrameLevel(frameLevel)
  handles:Hide()

  handles.corner = createResizeHandle(handles, "BOTTOMRIGHT")
  handles.corner:SetPoint("BOTTOMRIGHT")
  handles.corner:SetSize(18, 18)
  for _, size in ipairs({ 14, 8 }) do
    local line = handles.corner:CreateTexture(nil, "BACKGROUND")
    local offset = 0.1 * size / 17
    line:SetSize(size, size)
    line:SetPoint("BOTTOMRIGHT", -2, 2)
    line:SetTexture(137057)
    line:SetTexCoord(0.05 - offset, 0.5, 0.05, 0.5 + offset, 0.05, 0.5 - offset, 0.5 + offset, 0.5)
  end
  handles.bottom = createResizeHandle(handles, "BOTTOM")
  handles.bottom:SetPoint("BOTTOMLEFT")
  handles.bottom:SetPoint("BOTTOMRIGHT", -18, 0)
  handles.bottom:SetHeight(8)
  handles.right = createResizeHandle(handles, "RIGHT")
  handles.right:SetPoint("TOPRIGHT")
  handles.right:SetPoint("BOTTOMRIGHT", 0, 18)
  handles.right:SetWidth(8)
  return handles
end

local function createDock()
  dock = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  dock:Hide()
  dock:SetBackdrop(backdrop)
  dock:SetBackdropColor(0, 0, 0, 1)
  dock:SetClampRectInsets(0, 0, 12, 0)
  scene = PreviewScene:Create(dock)
  scene.onSelect = openElement
  PreviewViewport:Bind(scene.viewport, dock)
  -- Stay above aura cooldown/text layers and their mouse hit regions.
  local frameLevel = scene.block:GetFrameLevel() + 5
  dock.title = createTitle(frameLevel)
  dock.resize = createResizeHandles(frameLevel)
  dock.attachment = AceGUI:Create("Button")
  dock.attachment.frame:SetParent(dock)
  dock.attachment.frame:SetFrameLevel(frameLevel)
  dock.attachment.frame:SetPoint("TOPRIGHT", -18, -12)
  dock.attachment:SetWidth(80)
  dock.attachment:SetText("Detach")
  dock.attachment:SetCallback("OnClick", toggleAttachment)
  dock.attachment.frame:Show()
  dock.more = check("Show more spells", 155, toggleMore)
  dock.more.frame:SetPoint("BOTTOMRIGHT", -18, 13)
  dock.animate = check("Animate", 85, toggleAnimate)
  dock:SetScript("OnShow", shown)
  dock:SetScript("OnHide", hidden)
  dock:SetScript("OnEvent", changed)
  dock:RegisterEvent("CVAR_UPDATE")
  dock:RegisterEvent("DISPLAY_SIZE_CHANGED")
end

local function ownerHidden(frame)
  if owner and owner.frame == frame then
    dock:Hide()
    dock:SetParent(UIParent)
    restoreOwner()
    owner, ownerState = nil, nil
    requested = nil
  end
end

function Preview:Refresh()
  if not owner then
    return
  end
  local selected = Options.selectedPage == "spells" and Options.selectedSpell or nil
  local visible = requested
  if visible == nil then
    visible = Options.selectedPage == "style" or selected ~= nil
  end
  fitDock(visible)
  dock:SetShown(visible)
  if not dock:IsVisible() then
    return
  end
  dock.more.frame:SetShown(not selected)
  dock.animate.frame:ClearAllPoints()
  if selected then
    dock.animate.frame:SetPoint("BOTTOMRIGHT", -18, 13)
  else
    dock.animate.frame:SetPoint("RIGHT", dock.more.frame, "LEFT", -12, 0)
  end
  PreviewScene:Refresh(scene, fPB.db.profile, selected, more, animate)
end

function Preview:ContextChanged()
  if requested == false then
    requested = nil
  end
  Preview:Refresh()
end

function Preview:IsShown()
  return dock and dock:IsShown() or false
end

function Preview:Attach(widget)
  if not dock then
    createDock()
  end
  if owner ~= widget then
    owner = widget
    local frame = owner.frame
    ownerState = {
      insets = { frame:GetClampRectInsets() },
      bounds = { frame:GetResizeBounds() },
      clamped = frame:IsClampedToScreen(),
    }
    dock:SetParent(frame)
    attachDock()
    if not hookedOwners[frame] then
      frame:HookScript("OnHide", ownerHidden)
      hookedOwners[frame] = true
    end
  end
  Preview:Refresh()
end

function Preview:Toggle()
  if not owner then
    requested = true
    Options:Open()
    return
  end
  requested = not dock:IsShown()
  Preview:Refresh()
end
