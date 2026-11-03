local addonName, fPB = ...

local unpack = unpack
local CreateFrame = CreateFrame

local Fonts = fPB.Fonts

local IconStyle = {}
fPB.IconStyle = IconStyle

local borderTexture = "Interface\\AddOns\\" .. addonName .. "\\texture\\border.tga"

local function createIcon(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  return icon
end

local function createBorder(button)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetAllPoints()
  return border
end

local function createCooldown(button)
  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints()
  cooldown:SetDrawEdge(false)
  cooldown:SetReverse(true)
  cooldown:SetSwipeColor(0, 0, 0, 0.6)
  return cooldown
end

local function createTextLayer(button)
  local layer = CreateFrame("Frame", nil, button)
  layer:SetAllPoints()
  layer:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)
  return layer
end

local function createTextBackground(layer)
  local background = layer:CreateTexture(nil, "BACKGROUND")
  background:SetColorTexture(0, 0, 0, 0.75)
  return background
end

local function positionText(text, button, position)
  text:ClearAllPoints()
  if position == "BOTTOM" then
    text:SetPoint("TOP", button, "BOTTOM", 0, -1)
  elseif position == "TOP" then
    text:SetPoint("BOTTOM", button, "TOP", 0, 1)
  elseif position == "CENTER" then
    text:SetPoint("CENTER")
  else
    text:SetPoint("BOTTOMRIGHT", -1, 3)
  end
  return text
end

local function applyIconCrop(icon, appearance)
  local width, height = appearance.width, appearance.height
  if appearance.crop and width > height then
    local inset = (width - height) / (2 * width)
    icon:SetTexCoord(0, 1, inset, 1 - inset)
  elseif appearance.crop and height > width then
    local inset = (height - width) / (2 * height)
    icon:SetTexCoord(inset, 1 - inset, 0, 1)
  else
    icon:SetTexCoord(0, 1, 0, 1)
  end
  return icon
end

local function applyDurationText(button, profile, appearance, style)
  local outside = appearance.durationPosition ~= "CENTER"
  local text = button.Duration
  text:SetFont(Fonts:GetPath(profile.font), style.durationSize, outside and "" or "OUTLINE")
  positionText(text, button, appearance.durationPosition)
  text:SetTextColor(unpack(profile.colorSingle))
  return text
end

local function applyStackText(button, profile, appearance, style)
  local outside = appearance.stackPosition ~= "BOTTOMRIGHT"
  local text = button.Stacks
  text:SetFont(Fonts:GetPath(profile.stackFont), style.stackSize, outside and "" or "OUTLINE")
  positionText(text, button, appearance.stackPosition)
  text:SetTextColor(unpack(profile.stackColor))
  return text
end

local function applyBorderStyle(button, profile)
  button.Border:SetShown(profile.borderStyle ~= 3)
  button.Border:SetTexture(profile.borderStyle == 1 and borderTexture or "Interface\\Buttons\\UI-Debuff-Overlays")
  if profile.borderStyle == 1 then
    button.Border:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    button.Border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
  end
end

local function assembleTextRegions(button)
  button.TextLayer = createTextLayer(button)
  button.Duration = button.TextLayer:CreateFontString(nil, "OVERLAY")
  button.Stacks = button.TextLayer:CreateFontString(nil, "OVERLAY")
  button.DurationBackground = createTextBackground(button.TextLayer)
  button.StackBackground = createTextBackground(button.TextLayer)
end

function IconStyle:Create(button)
  button.Icon = createIcon(button)
  button.Border = createBorder(button)
  button.Cooldown = createCooldown(button)
  assembleTextRegions(button)
end

function IconStyle:Apply(button, profile, appearance, style, manualTiming)
  local previous = button.appearance
  if
    not manualTiming
    and previous
    and previous.profile == profile
    and previous.scale == style.scale
    and previous.durationSize == style.durationSize
    and previous.stackSize == style.stackSize
  then
    return
  end

  button:SetSize(appearance.width * style.scale, appearance.height * style.scale)
  applyIconCrop(button.Icon, appearance)

  local duration = applyDurationText(button, profile, appearance, style)
  button.DurationBackground:SetAllPoints(duration)

  local stacks = applyStackText(button, profile, appearance, style)
  button.StackBackground:SetAllPoints(stacks)

  applyBorderStyle(button, profile)

  button.appearance =
    { profile = profile, scale = style.scale, durationSize = style.durationSize, stackSize = style.stackSize }
end
