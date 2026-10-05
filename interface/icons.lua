local addonName, fPB = ...

local unpack = unpack

local CreateFrame = CreateFrame
local GetTime = GetTime

local mfloor = math.floor
local mmax = math.max
local mmin = math.min
local sformat = string.format

local Fonts = fPB.Fonts

local Icons = {}
fPB.Icons = Icons

local borderTexture = "Interface\\AddOns\\" .. addonName .. "\\texture\\border.tga"

local function positionText(text, background, button, position)
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
  background:SetAllPoints(text)
end

local function updateDuration(button, elapsed)
  button.elapsed = (button.elapsed or 0) + (elapsed or 0.05)
  if button.elapsed < 0.05 then
    return
  end
  button.elapsed = 0
  local aura, profile = button.aura, button.profile
  local remaining = mmax(0, aura.expirationTime - GetTime())
  if profile.showDuration then
    button.Duration:SetText(Icons:FormatTime(remaining, profile.showDecimals))
    if profile.colorTransition then
      local fraction = remaining / aura.duration
      button.Duration:SetTextColor(mmin(1, 2 - 2 * fraction), mmin(1, 2 * fraction), 0)
    end
  end
  if remaining < 60 and remaining / aura.duration < profile.blinkTimeleft then
    local phase = GetTime() % 1
    button:SetAlpha(mmin(1, (phase > 0.5 and 1 - phase or phase) * 3))
  else
    button:SetAlpha(1)
  end
end

function Icons:FormatTime(seconds, decimals)
  if seconds < 10 and decimals then
    return sformat("%.1f", seconds)
  elseif seconds < 59.5 then
    return sformat("%d", mfloor(seconds + 0.5))
  elseif seconds < 3570 then
    return sformat("%dm", mfloor(seconds / 60 + 0.5))
  elseif seconds < 84600 then
    return sformat("%dh", mfloor(seconds / 3600 + 0.5))
  end
  return sformat("%dd", mfloor(seconds / 86400 + 0.5))
end

function Icons:Create(parent)
  local button = CreateFrame("Frame", nil, parent)
  button.Icon = button:CreateTexture(nil, "ARTWORK")
  button.Icon:SetAllPoints()
  button.Border = button:CreateTexture(nil, "OVERLAY")
  button.Border:SetAllPoints()
  button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.Cooldown:SetAllPoints()
  button.Cooldown:SetDrawEdge(false)
  button.Cooldown:SetReverse(true)
  button.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
  button.TextLayer = CreateFrame("Frame", nil, button)
  button.TextLayer:SetAllPoints()
  button.TextLayer:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)
  button.Duration = button.TextLayer:CreateFontString(nil, "OVERLAY")
  button.Stacks = button.TextLayer:CreateFontString(nil, "OVERLAY")
  button.DurationBackground = button.TextLayer:CreateTexture(nil, "BACKGROUND")
  button.StackBackground = button.TextLayer:CreateTexture(nil, "BACKGROUND")
  button.DurationBackground:SetColorTexture(0, 0, 0, 0.75)
  button.StackBackground:SetColorTexture(0, 0, 0, 0.75)
  return button
end

function Icons:Apply(button, profile, appearance, style, aura)
  button.profile, button.aura = profile, aura
  button:SetSize(appearance.width * style.scale, appearance.height * style.scale)
  button.Icon:SetTexture(aura.icon)
  local width, height = appearance.width, appearance.height
  if appearance.crop and width > height then
    local inset = (width - height) / (2 * width)
    button.Icon:SetTexCoord(0, 1, inset, 1 - inset)
  elseif appearance.crop and height > width then
    local inset = (height - width) / (2 * height)
    button.Icon:SetTexCoord(inset, 1 - inset, 0, 1)
  else
    button.Icon:SetTexCoord(0, 1, 0, 1)
  end
  local durationOutside = appearance.durationPosition ~= "CENTER"
  local stackOutside = appearance.stackPosition ~= "BOTTOMRIGHT"
  button.Duration:SetFont(Fonts:GetPath(profile.font), style.durationSize, durationOutside and "" or "OUTLINE")
  button.Stacks:SetFont(Fonts:GetPath(profile.stackFont), style.stackSize, stackOutside and "" or "OUTLINE")
  positionText(button.Duration, button.DurationBackground, button, appearance.durationPosition)
  positionText(button.Stacks, button.StackBackground, button, appearance.stackPosition)
  button.Duration:SetTextColor(unpack(profile.colorSingle))
  button.Stacks:SetTextColor(unpack(profile.stackColor))
  button.Duration:SetShown(profile.showDuration and aura.duration > 0)
  button.DurationBackground:SetShown(profile.showDuration and aura.duration > 0 and durationOutside)
  button.Stacks:SetText(aura.applications > 1 and aura.applications or "")
  button.StackBackground:SetShown(aura.applications > 1 and stackOutside)
  button.Border:SetShown(profile.borderStyle ~= 3)
  button.Border:SetTexture(profile.borderStyle == 1 and borderTexture or "Interface\\Buttons\\UI-Debuff-Overlays")
  if profile.borderStyle == 1 then
    button.Border:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    button.Border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
  end
  local color = aura.isHelpful and profile.colorTypes.Buff
    or (profile.colorizeBorder and profile.colorTypes[aura.dispelName])
    or profile.colorTypes.none
  button.Border:SetVertexColor(unpack(color))
  button.Cooldown:SetDrawSwipe(profile.showStdSwipe)
  button.Cooldown:SetHideCountdownNumbers(not profile.showStdCooldown)
  button.Cooldown:SetShown(aura.duration > 0 and (profile.showStdSwipe or profile.showStdCooldown))
  if aura.duration > 0 then
    button.Cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
  else
    button.Cooldown:Clear()
  end
  button:SetAlpha(1)
  local timed = aura.duration > 0 and (profile.showDuration or profile.blinkTimeleft > 0)
  button:SetScript("OnUpdate", timed and updateDuration or nil)
  if timed then
    updateDuration(button)
  end
  button:Show()
end

function Icons:Release(button)
  button:Hide()
  button:SetScript("OnUpdate", nil)
  button.aura, button.profile, button.unit = nil, nil, nil
end
