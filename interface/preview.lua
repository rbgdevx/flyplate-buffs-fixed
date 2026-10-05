local _, fPB = ...

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

local Preview = {}
fPB.Preview = Preview

local AceGUI = LibStub("AceGUI-3.0")
local dock, owner, scene, ownerState, requested
local animate, more = false, false
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
  dock:SetHeight(height)
  if not visible then
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

local function createDock()
  dock = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  dock:Hide()
  dock:SetBackdrop(backdrop)
  dock:SetBackdropColor(0, 0, 0, 1)
  scene = PreviewScene:Create(dock)
  scene.onSelect = openElement
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
    dock:SetFrameLevel(frame:GetFrameLevel() - 1)
    dock:ClearAllPoints()
    dock:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -8)
    dock:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -8)
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
