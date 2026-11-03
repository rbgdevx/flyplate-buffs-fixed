local _, fPB = ...

local CreateFrame = CreateFrame

local StyleRegions = {}
fPB.StyleRegions = StyleRegions

local function createIcon(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  return icon
end

local function createCooldown(button)
  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints()
  cooldown:SetDrawEdge(false)
  cooldown:SetReverse(true)
  cooldown:SetSwipeColor(0, 0, 0, 0.6)
  cooldown:SetHideCountdownNumbers(true)
  return cooldown
end

local function createTextLayer(button)
  local layer = CreateFrame("Frame", nil, button)
  layer:SetAllPoints()
  layer:SetFrameLevel((button.Cooldown or button):GetFrameLevel() + 1)
  return layer
end

local function createStackBackground(layer, text)
  local background = layer:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(text)
  background:SetColorTexture(0, 0, 0, 0.75)
  return background
end

local function assembleTextRegions(button)
  button.TextLayer = createTextLayer(button)
  button.Stacks = button.TextLayer:CreateFontString(nil, "OVERLAY")
  button.StackBackground = createStackBackground(button.TextLayer, button.Stacks)
end

local function createDurationBackground(layer, text)
  local background = layer:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(text)
  return background
end

local function createBorder(button)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetAllPoints()
  border:Hide()
  return border
end

function StyleRegions:Ensure(button, style)
  if (style.swipe or style.cooldownNumbers) and not button.Cooldown then
    button.Cooldown = createCooldown(button)
    button.TextLayer:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)
  end

  if style.duration and not button.Duration then
    button.Duration = button.TextLayer:CreateFontString(nil, "OVERLAY")
    button.DurationBackground = createDurationBackground(button.TextLayer, button.Duration)
  end

  if style.border ~= "none" and not button.Border then
    button.Border = createBorder(button)
  end
end

function StyleRegions:Create(button, style)
  button:SetFlattensRenderLayers(true)
  button.Icon = createIcon(button)
  assembleTextRegions(button)
  StyleRegions:Ensure(button, style)
end
