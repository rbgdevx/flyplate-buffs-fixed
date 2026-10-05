local addonName, fPB = ...

local ipairs = ipairs
local pairs = pairs
local unpack = unpack

local CreateColor = CreateColor
local CreateFrame = CreateFrame
local Enum = Enum

local CreateColorCurve = C_CurveUtil.CreateColorCurve
local CreateNumericRuleFormatter = C_StringUtil.CreateNumericRuleFormatter

local Fonts = fPB.Fonts

local Style = {}
fPB.Style = Style

local borderTexture = "Interface\\AddOns\\" .. addonName .. "\\texture\\border.tga"

local function texCoords(width, height, crop)
  if crop and width > height then
    local inset = (width - height) / (2 * width)
    return 0, 1, inset, 1 - inset
  elseif crop and height > width then
    local inset = (height - width) / (2 * height)
    return inset, 1 - inset, 0, 1
  end

  return 0, 1, 0, 1
end

local function durationFormatter(decimals)
  local formatter = CreateNumericRuleFormatter()
  formatter:AddBreakpoint({ threshold = 0, format = decimals and "%.1f" or "", step = decimals and 0.1 or nil })
  formatter:AddBreakpoint({ threshold = decimals and 10 or 0.5, format = "%.0f", step = 1 })
  formatter:AddBreakpoint({ threshold = 59.5, format = "%dm", components = { { div = 60, step = 1 } } })
  formatter:AddBreakpoint({ threshold = 3570, format = "%dh", components = { { div = 3600, step = 1 } } })
  formatter:AddBreakpoint({ threshold = 84600, format = "%dd", components = { { div = 86400, step = 1 } } })

  return formatter
end

local function placeText(text, button, position, offsetX, offsetY)
  text:ClearAllPoints()
  if position == "BOTTOM" then
    text:SetPoint("TOP", button, "BOTTOM", offsetX, offsetY - 1)
  elseif position == "TOP" then
    text:SetPoint("BOTTOM", button, "TOP", offsetX, offsetY + 1)
  else
    text:SetPoint(
      position,
      button,
      position,
      offsetX + (position == "BOTTOMRIGHT" and -1 or 0),
      offsetY + (position == "BOTTOMRIGHT" and 3 or 0)
    )
  end
end

local function createCooldown(button)
  button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.Cooldown:SetAllPoints()
  button.Cooldown:SetDrawEdge(false)
  button.Cooldown:SetReverse(true)
  button.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
  button.Cooldown:SetHideCountdownNumbers(true)
end

local function createText(button)
  button.TextLayer = CreateFrame("Frame", nil, button)
  button.TextLayer:SetAllPoints()
  button.TextLayer:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)

  button.Duration = button.TextLayer:CreateFontString(nil, "OVERLAY")
  button.Stacks = button.TextLayer:CreateFontString(nil, "OVERLAY")

  button.DurationBackground = button.TextLayer:CreateTexture(nil, "BACKGROUND")
  button.DurationBackground:SetAllPoints(button.Duration)

  button.StackBackground = button.TextLayer:CreateTexture(nil, "BACKGROUND")
  button.StackBackground:SetAllPoints(button.Stacks)
  button.StackBackground:SetColorTexture(0, 0, 0, 0.75)
end

local function createBorders(button)
  button.Border = button:CreateTexture(nil, "OVERLAY")
  button.Border:SetAllPoints()

  button.BuffBorder = button:CreateTexture(nil, "OVERLAY")
  button.BuffBorder:SetAllPoints(button.Border)
end

local function applyDuration(button, style)
  local durationOutside = style.durationPosition == "BOTTOM" or style.durationPosition == "TOP"
  button.DurationBackground:SetColorTexture(unpack(style.durationBackgroundColor))
  button.DurationBackground:SetShown(style.duration and durationOutside)
  button.Duration:SetTextColor(unpack(style.durationTextColor))
  placeText(button.Duration, button, style.durationPosition, style.durationX, style.durationY)
  button.Duration:SetShown(style.duration)
end

local function applyStacks(button, style, group)
  local stackOutside = style.stackPosition == "BOTTOM" or style.stackPosition == "TOP"
  button.StackBackground:SetShown(style.stacks and stackOutside)
  button.Stacks:SetTextColor(unpack(style.stackColor))
  placeText(button.Stacks, button, style.stackPosition, style.stackX, style.stackY)
  button.Stacks:SetHeight(group.stackSize + 4)
  button.Stacks:SetShown(style.stacks)
end

local function applyCooldown(button, style)
  button.Cooldown:SetDrawSwipe(style.swipe)
  button.Cooldown:SetHideCountdownNumbers(not style.cooldownNumbers)
  button.Cooldown:SetShown(style.swipe or style.cooldownNumbers)

  local countdown = button.Cooldown:GetCountdownFontString()
  countdown:SetTextColor(unpack(style.cooldownTextColor))
  countdown:ClearAllPoints()
  countdown:SetPoint("CENTER", button.Cooldown, "CENTER", style.cooldownX, style.cooldownY)
end

local function applyBorders(button, style)
  for _, border in ipairs({ button.Border, button.BuffBorder }) do
    border:Hide()
    border:SetTexture(style.border == "square" and borderTexture or "Interface\\Buttons\\UI-Debuff-Overlays")
    if style.border == "square" then
      border:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
      border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    end
  end
end

local function bindDuration(button, style)
  if style.duration then
    local options = { textFormatter = durationFormatter(style.decimals) }
    if style.durationColor then
      local curve = CreateColorCurve()
      curve:AddPoint(0, CreateColor(1, 0, 0))
      curve:AddPoint(0.5, CreateColor(1, 1, 0))
      curve:AddPoint(1, CreateColor(0, 1, 0))
      options.textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingPercent }
    end
    button:SetDurationText(button.Duration, options)
  else
    button:ClearDurationText()
    button.Duration:Hide()
  end
end

local function bindStacks(button, style)
  if style.stacks then
    button:SetApplicationCount(button.Stacks, {})
  else
    button:ClearApplicationCount()
    button.Stacks:Hide()
  end
end

local function bindCooldown(button, style)
  if style.swipe or style.cooldownNumbers then
    button:SetDurationCooldown(button.Cooldown)
  else
    button:ClearDurationCooldown()
    button.Cooldown:Hide()
  end
end

local function harmfulColors(style, colors)
  local harmful = {
    showWhenHarmful = true,
    showWithoutDispelType = true,
    style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
  }
  harmful.customDispelColorMap = {}
  for _, key in ipairs({ "None", "Magic", "Curse", "Disease", "Poison", "Enrage" }) do
    harmful.customDispelColorMap[key] = style.colorByDispel and (colors[key] or colors.None) or colors.None
  end

  return harmful
end

local function bindBorders(button, style)
  button:ClearDispelTypeTextures()
  if style.border == "none" then
    return
  end

  local colors = {}
  for key, rgb in pairs(style.colors) do
    colors[key] = CreateColor(unpack(rgb))
  end

  button:AddDispelTypeTexture(button.Border, harmfulColors(style, colors))

  local buffColors = {}
  for _, key in ipairs({ "None", "Magic", "Curse", "Disease", "Poison", "Enrage" }) do
    buffColors[key] = colors.Buff
  end

  button:AddDispelTypeTexture(button.BuffBorder, {
    showWhenHarmful = false,
    showWhenHelpful = true,
    showWithoutDispelType = true,
    style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
    customDispelColorMap = buffColors,
  })
end

function Style:Create(button)
  button.Icon = button:CreateTexture(nil, "ARTWORK")
  button.Icon:SetAllPoints()

  createCooldown(button)
  createText(button)
  createBorders(button)
end

function Style:ApplyFonts(button, profile, group)
  local style = profile.style
  local durationOutside = style.durationPosition == "BOTTOM" or style.durationPosition == "TOP"
  local stackOutside = style.stackPosition == "BOTTOM" or style.stackPosition == "TOP"
  button.Duration:SetFont(Fonts:GetPath(style.durationFont), group.durationSize, durationOutside and "" or "OUTLINE")
  button.Stacks:SetFont(Fonts:GetPath(style.stackFont), group.stackSize, stackOutside and "" or "OUTLINE")
  button.Cooldown:GetCountdownFontString():SetFont(Fonts:GetPath(style.cooldownFont), style.cooldownSize, "OUTLINE")
end

function Style:ApplyAppearance(button, profile, group)
  local style = profile.style
  button:SetSize(style.width * group.scale, style.height * group.scale)
  button.Icon:SetTexCoord(texCoords(style.width, style.height, style.crop))
  Style:ApplyFonts(button, profile, group)

  applyDuration(button, style)
  applyStacks(button, style, group)
  applyCooldown(button, style)
  applyBorders(button, style)
end

function Style:Apply(button, profile, group)
  Style:ApplyAppearance(button, profile, group)
  button:SetIcon(button.Icon)
  button:SetMouseClickEnabled(false)
  button:SetMouseMotionEnabled(profile.tooltip)
  button:SetHideTooltipInCombat(not profile.tooltipInCombat)
  button:SetTooltipAnchorPoint("ANCHOR_RIGHT")

  local style = profile.style
  bindDuration(button, style)
  bindStacks(button, style)
  bindCooldown(button, style)
  bindBorders(button, style)
end
