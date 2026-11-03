local _, fPB = ...

local ipairs = ipairs
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local WorldFrame = WorldFrame
local mmin = math.min

local Icons = fPB.Icons
local Layout = fPB.Layout

local ClassicDisplay = {}
fPB.ClassicDisplay = ClassicDisplay

local positionKeys =
  { "buffPerLine", "numLines", "xInterval", "yInterval", "buffAnchorPoint", "plateAnchorPoint", "xOffset", "yOffset" }

local function hideTooltip(button)
  if GameTooltip:IsOwned(button) then
    GameTooltip:Hide()
  end
end

local function showTooltip(button)
  if not button.profile.tooltipInCombat and InCombatLockdown() then
    return
  end

  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetUnitAuraByAuraInstanceID(button.unit, button.aura.auraInstanceID)
  if button.profile.showSpellID then
    GameTooltip:AddLine("Spell ID: " .. button.aura.spellId)
  end
  GameTooltip:Show()
end

local function updateTooltip(button, profile)
  local tooltip = profile.showTooltip and (profile.tooltipInCombat or not InCombatLockdown())
  if button.tooltip ~= tooltip then
    button:EnableMouse(tooltip)
    button.tooltip = tooltip
  end
  if not tooltip then
    hideTooltip(button)
  end
end

local function createButton(parent)
  local button = Icons:Create(parent)
  button:SetScript("OnEnter", showTooltip)
  button:SetScript("OnLeave", hideTooltip)
  return button
end

local function acquireButton(state, index)
  local button = state.buttons[index]
  if button then
    return button, false
  end

  button = createButton(state.frame)
  state.buttons[index] = button
  return button, true
end

local function applyRecord(button, record, profile, appearance, layout)
  if button.record ~= record or button.profile ~= profile then
    local width, height = button:GetWidth(), button:GetHeight()
    Icons:Apply(button, profile, appearance.style, record.style, record.aura)
    button.record = record
    return layout or width ~= button:GetWidth() or height ~= button:GetHeight()
  end
  return layout
end

local function updateButton(state, index, profile, appearance, layout)
  local button, created = acquireButton(state, index)
  button.unit = state.unit
  updateTooltip(button, profile)
  return applyRecord(button, state.visible[index], profile, appearance, created or layout)
end

local function updateButtons(state, count, profile, appearance, layout)
  for index = 1, count do
    layout = updateButton(state, index, profile, appearance, layout)
  end
  return layout
end

local function releaseButtons(buttons, first, last)
  for index = first, last do
    hideTooltip(buttons[index])
    Icons:Release(buttons[index])
  end
end

local function layoutChanged(state, count, profile)
  if not state.layout or state.count ~= count then
    return true
  end
  for _, key in ipairs(positionKeys) do
    if state.layout[key] ~= profile[key] then
      return true
    end
  end
  return false
end

local function parentDisplay(state, profile)
  local parent = profile.parentWorldFrame and WorldFrame or state.plate
  if state.frame:GetParent() ~= parent then
    state.frame:SetParent(parent)
  end
end

function ClassicDisplay:Create(plate)
  local frame = CreateFrame("Frame", nil, plate)
  frame:SetFrameStrata("HIGH")
  frame:SetFlattensRenderLayers(true)
  frame:Hide()
  return frame
end

function ClassicDisplay:Clear(state)
  releaseButtons(state.buttons, 1, #state.buttons)
  state.frame:Hide()
end

function ClassicDisplay:Render(state, profile, appearance)
  local count = mmin(#state.visible, profile.buffPerLine * profile.numLines)
  local layout = layoutChanged(state, count, profile)
  parentDisplay(state, profile)

  layout = updateButtons(state, count, profile, appearance, layout)
  releaseButtons(state.buttons, count + 1, state.count or 0)

  if layout then
    Layout:Arrange(state.frame, state.buttons, count, profile, state.plate.UnitFrame or state.plate)
    state.layout = profile
  end
  state.count = count
  state.frame:SetShown(count > 0)
end
