local assert = assert
local dofile = dofile
local error = error
local ipairs = ipairs
local loadfile = loadfile
local next = next
local print = print
local setmetatable = setmetatable

local H = dofile("tests/helpers.lua")
GenerateClosure = H.environment(16001).env.GenerateClosure

-- Static-template contract checks with frame doubles, not client rendering/taint proof.
local function forbidden()
  error("The static preview must not bind a unit, read live health, or enter the shared driver")
end

NamePlateDriverFrame = setmetatable({}, { __index = forbidden })
CompactUnitFrame_SetUnit = forbidden
CompactUnitFrame_SetUpFrame = forbidden
CompactUnitFrame_UpdateAll = forbidden
UnitHealth = forbidden
UnitHealthMax = forbidden
UnitLevel = forbidden

local methods = {}
local function frame(parent)
  return setmetatable({ parent = parent, shown = true, scripts = {}, events = { CVAR_UPDATE = true } }, {
    __index = methods,
  })
end

function methods:SetPoint(...)
  self.point = { ... }
end

function methods:SetAllPoints(parent)
  self.allPoints = parent
end

function methods:EnableMouse(enabled)
  self.mouse = enabled
end

function methods:SetSize(width, height)
  self.width, self.height = width, height
end

function methods:SetNamePlateFrame(plate)
  self.namePlateFrame = plate
end

function methods:UnregisterAllEvents()
  self.events = {}
end

function methods:SetScript(name, callback)
  self.scripts[name] = callback
end

function methods:Hide()
  self.shown = false
end

function methods:Show()
  self.shown = true
  if self.scripts.OnShow then
    self.scripts.OnShow(self)
  end
end

function methods:SetShown(shown)
  self.shown = shown
end

function methods:IsVisible()
  return self.shown and (not self.parent or self.parent:IsVisible())
end

function methods:SetText(text)
  self.text = text
end

function methods:SetVertexColor(...)
  self.color = { ... }
end
methods.SetStatusBarColor = methods.SetVertexColor
function methods:SetMinMaxValues(minimum, maximum)
  self.minimum, self.maximum = minimum, maximum
end

function methods:SetValue(value)
  self.value = value
end

function methods:SetIsTarget(target)
  self.isTarget = target
end
methods.SetUnit = forbidden
methods.OnUnitSet = forbidden
local layoutCount = 0
function methods:ApplyFrameOptions(setup, options)
  assert(self.unit == nil and self.displayedUnit == nil, "Native layout must remain unbound")
  assert(self.namePlateFrame and self.allPoints == self.namePlateFrame)
  assert(setup == NamePlateSetupOptions and options == NamePlateEnemyFrameOptions)
  self.appliedStyle = setup.style
  if self.PlayerLevelDiffFrame.ShouldDisplay then
    assert(self.PlayerLevelDiffFrame:ShouldDisplay(nil), "Forever layout needs its static NPC badge")
  end
  -- Blizzard's SetOptionTable schedules deferred CompactUnitFrame work.
  self:SetScript("OnUpdate", forbidden)
  layoutCount = layoutCount + 1
end

local created, forever = 0, true
CreateFrame = function(kind, _, parent, template)
  local object = frame(parent)
  object.template = template
  if template == "NamePlateUnitFrameTemplate" then
    assert(kind == "Button")
    created = created + 1
    parent.UnitFrame = object -- The template declares this parentKey.
    for _, key in ipairs({
      "healthBar",
      "name",
      "AurasFrame",
      "CastBarsContainer",
      "ClassificationFrame",
      "RaidTargetFrame",
      "SoftTargetFrame",
      "behindCameraIcon",
      "LevelFrame",
      "myHealPrediction",
      "otherHealPrediction",
      "totalAbsorb",
      "totalAbsorbOverlay",
      "overAbsorbGlow",
      "myHealAbsorb",
      "myHealAbsorbLeftShadow",
      "myHealAbsorbRightShadow",
      "overHealAbsorbGlow",
    }) do
      object[key] = frame(object)
    end
    object.CastBarsContainer.castBar = frame(object.CastBarsContainer)
    object.CastBarsContainer.castBar:SetScript("OnUpdate", forbidden)
    object.LevelFrame.LevelText = frame(object.LevelFrame)
    object.aggroHighlightTextures = { frame(object), frame(object), frame(object) }
    object:SetScript("OnEvent", forbidden)
    object:SetScript("OnUpdate", forbidden)
    local badge = frame(object)
    object.PlayerLevelDiffFrame = badge
    badge:Hide()
    badge.playerLevelDiffText, badge.playerLevelDiffIcon = frame(badge), frame(badge)
    if forever then
      badge.highLevelTexture = frame(badge)
      badge.ShouldDisplay = function()
        return false
      end
    end
  else
    assert(kind == "Frame" and template == "NamePlateScriptBaseTemplate")
  end
  return object
end

local width, height = 190, 68
C_NamePlate = {
  GetNamePlateSize = function()
    return width, height
  end,
}
NamePlateSetupOptions = { style = "classic" }
NamePlateEnemyFrameOptions = { showLevel = true, colorNameBySelection = false }
local NS = {}
assert(loadfile("interface/preview-nameplate.lua"))("flyPlateBuffsFixed", NS)
for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local isForever = interface == 16001
  forever = isForever
  local scene = frame()
  scene:Hide()
  local plate = NS.PreviewNameplate:Create(scene)
  local unit = plate.UnitFrame
  local examples = frame(plate)
  examples.selection = "stacks"
  local count = created
  assert(plate.width == width and plate.height == height)
  assert(unit.healthBar.value == 75 and unit.healthBar.maximum == 100 and unit.healthBar.minimum == 0)
  assert(unit.name.text == "Example nameplate" and unit.LevelFrame.LevelText.text == "60")
  assert(not unit.AurasFrame.shown and not unit.CastBarsContainer.shown)
  assert(next(unit.events) == nil and unit.scripts.OnEvent == nil and unit.scripts.OnUpdate == nil)
  assert(next(unit.CastBarsContainer.castBar.events) == nil and unit.CastBarsContainer.castBar.scripts.OnUpdate == nil)
  if isForever then
    assert(unit.PlayerLevelDiffFrame.shown and unit.PlayerLevelDiffFrame.playerLevelDiffText.text == "60")
    assert(not unit.PlayerLevelDiffFrame.highLevelTexture.shown)
  else
    assert(not unit.PlayerLevelDiffFrame.shown and unit.PlayerLevelDiffFrame.ShouldDisplay == nil)
  end
  for _, style in ipairs({ "classic", "legacy", "block", "cast-focus", "classic" }) do
    width, height = width + 1, height + 1
    NamePlateSetupOptions.style = style
    NamePlateEnemyFrameOptions.showLevel = style == "classic"
    NamePlateEnemyFrameOptions.colorNameBySelection = style == "legacy"
    plate:Refresh()
    assert(plate.width == width and plate.height == height and unit.appliedStyle == style)
    assert(unit.LevelFrame.shown == (style == "classic"))
    assert(unit.name.color[2] == (style == "legacy" and 0 or 1))
    assert(unit.scripts.OnUpdate == nil, "Refresh must cancel native deferred unit work")
  end
  scene:Show()
  plate:Show()
  assert(examples:IsVisible())
  scene:Hide()
  assert(not examples:IsVisible())
  plate:Refresh()
  scene:Show()
  plate:Show()
  assert(created == count and plate.UnitFrame == unit, "Reopen must reuse the private visual")
  assert(examples.selection == "stacks" and examples:IsVisible())
  assert(unit.unit == nil and unit.displayedUnit == nil and unit.scripts.OnUpdate == nil)
end
assert(layoutCount > 2)
print(
  "Passed unbound native preview, static values, Classic/Retail/Forever levels, style refresh, deferred-work isolation, and reopen checks."
)
