local addonName, fPB = ...

local unpack = unpack

local Fonts = fPB.Fonts
local StyleRegions = fPB.StyleRegions

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

local function applyDurationBackground(background, style)
  local outside = style.durationPosition == "BOTTOM" or style.durationPosition == "TOP"
  background:SetColorTexture(unpack(style.durationBackgroundColor))
  background:SetShown(style.duration and outside)
  return background
end

local function applyDurationText(text, button, style)
  text:SetTextColor(unpack(style.durationTextColor))
  placeText(text, button, style.durationPosition, style.durationX, style.durationY)
  text:SetShown(style.duration)
  return text
end

local function assembleDurationStyle(button, style)
  if not button.Duration then
    return
  end

  applyDurationBackground(button.DurationBackground, style)
  applyDurationText(button.Duration, button, style)
end

local function applyStackText(text, button, style, group)
  text:SetTextColor(unpack(style.stackColor))
  placeText(text, button, style.stackPosition, style.stackX, style.stackY)
  text:SetHeight(group.stackSize + 4)
  text:SetShown(true)
  return text
end

local function assembleStackStyle(button, style, group)
  local outside = style.stackPosition == "BOTTOM" or style.stackPosition == "TOP"
  button.StackBackground:SetShown(outside)
  applyStackText(button.Stacks, button, style, group)
end

local function applyCooldownText(text, cooldown, style)
  text:SetTextColor(unpack(style.cooldownTextColor))
  text:ClearAllPoints()
  text:SetPoint("CENTER", cooldown, "CENTER", style.cooldownX, style.cooldownY)
  return text
end

local function assembleCooldownStyle(button, style)
  if not button.Cooldown then
    return
  end

  button.Cooldown:SetDrawSwipe(style.swipe)
  button.Cooldown:SetHideCountdownNumbers(not style.cooldownNumbers)
  button.Cooldown:SetShown(style.swipe or style.cooldownNumbers)
  applyCooldownText(button.Cooldown:GetCountdownFontString(), button.Cooldown, style)
end

local function applyBorderStyle(border, style)
  if not border then
    return
  end

  if style.border == "none" then
    border:Hide()
  end
  border:SetTexture(style.border == "square" and borderTexture or "Interface\\Buttons\\UI-Debuff-Overlays")
  if style.border == "square" then
    border:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
  end
  return border
end

local function bindDuration(button, style, resources)
  if style.duration then
    button:SetDurationText(button.Duration, resources.duration)
  else
    button:ClearDurationText()
    if button.Duration then
      button.Duration:Hide()
    end
  end
end

local function bindCooldown(button, style)
  if style.swipe or style.cooldownNumbers then
    button:SetDurationCooldown(button.Cooldown)
  else
    button:ClearDurationCooldown()
    if button.Cooldown then
      button.Cooldown:Hide()
    end
  end
end

local function bindBorder(button, resources, helpful)
  button:ClearDispelTypeTextures()
  if resources.borders then
    button:AddDispelTypeTexture(button.Border, resources.borders[helpful and 2 or 1])
  end
end

local function bindElements(button)
  button:SetIcon(button.Icon)
  button:SetApplicationCount(button.Stacks, {})
  button:SetMouseClickEnabled(false)
  button:SetTooltipAnchorPoint("ANCHOR_RIGHT")
end

function Style:Create(button, profile)
  StyleRegions:Create(button, profile and profile.style or { duration = true, swipe = true, border = "square" })
end

function Style:ApplyFonts(button, profile, group)
  local style = profile.style
  local durationOutside = style.durationPosition == "BOTTOM" or style.durationPosition == "TOP"
  local stackOutside = style.stackPosition == "BOTTOM" or style.stackPosition == "TOP"
  if button.Duration then
    button.Duration:SetFont(Fonts:GetPath(style.durationFont), group.durationSize, durationOutside and "" or "OUTLINE")
  end
  button.Stacks:SetFont(Fonts:GetPath(style.stackFont), group.stackSize, stackOutside and "" or "OUTLINE")
  if button.Cooldown then
    button.Cooldown:GetCountdownFontString():SetFont(Fonts:GetPath(style.cooldownFont), style.cooldownSize, "OUTLINE")
  end
end

function Style:ApplyAppearance(button, profile, group)
  local style = profile.style
  StyleRegions:Ensure(button, style)
  button:SetSize(style.width * group.scale, style.height * group.scale)
  button.Icon:SetTexCoord(texCoords(style.width, style.height, style.crop))
  Style:ApplyFonts(button, profile, group)

  assembleDurationStyle(button, style)
  assembleStackStyle(button, style, group)
  assembleCooldownStyle(button, style)
  applyBorderStyle(button.Border, style)
end

function Style:Apply(button, profile, group, resources, helpful)
  Style:ApplyAppearance(button, profile, group)
  bindDuration(button, profile.style, resources)
  bindCooldown(button, profile.style)
  bindBorder(button, resources, helpful)

  button:SetMouseMotionEnabled(profile.tooltip)
  button:SetHideTooltipInCombat(not profile.tooltipInCombat)
end

function Style:Initialize(button, profile, group, resources, helpful)
  Style:Create(button, profile)
  Style:Apply(button, profile, group, resources, helpful)
  bindElements(button)
end
