local _, fPB = ...

local unpack = unpack
local CreateFrame = CreateFrame
local GetTime = GetTime
local mfloor = math.floor
local mmax = math.max
local mmin = math.min
local sformat = string.format

local IconStyle = fPB.IconStyle
local IconTimers = fPB.IconTimers

local Icons = {}
fPB.Icons = Icons

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

local function updateDurationText(button, profile, aura, remaining)
  if profile.showDuration then
    local text = Icons:FormatTime(remaining, profile.showDecimals)
    if text ~= button.durationText then
      button.Duration:SetText(text)
      button.durationText = text
    end

    if profile.colorTransition then
      local fraction = remaining / aura.duration
      button.Duration:SetTextColor(mmin(1, 2 - 2 * fraction), mmin(1, 2 * fraction), 0)
    end
  end
end

local function updateBlink(button, profile, aura, remaining, now)
  local alpha = 1
  if remaining < 60 and remaining / aura.duration < profile.blinkTimeleft then
    local phase = now % 1
    alpha = mmin(1, (phase > 0.5 and 1 - phase or phase) * 3)
  end
  if alpha ~= button.durationAlpha then
    button:SetAlpha(alpha)
    button.durationAlpha = alpha
  end
end

local function updateDuration(button, now)
  local aura, profile = button.aura, button.profile
  local remaining = mmax(0, aura.expirationTime - now)
  updateDurationText(button, profile, aura, remaining)
  updateBlink(button, profile, aura, remaining, now)
end

local function shown(button)
  IconTimers:Set(button, button.durationUpdate)
end

local function hidden(button)
  IconTimers:Set(button, nil)
end

function Icons:Create(parent)
  local button = CreateFrame("Frame", nil, parent)
  button:SetFlattensRenderLayers(true)
  button:SetScript("OnShow", shown)
  button:SetScript("OnHide", hidden)

  IconStyle:Create(button)
  return button
end

local function applyIcon(button, aura)
  if button.icon ~= aura.icon then
    button.Icon:SetTexture(aura.icon)
    button.icon = aura.icon
  end
end

local function applyStacks(button, aura)
  if button.applications ~= aura.applications then
    button.Stacks:SetText(aura.applications > 1 and aura.applications or "")
    button.applications = aura.applications
  end
  return button.Stacks
end

local function applyBorder(button, profile, aura, manualTiming)
  local color = aura.isHelpful and profile.colorTypes.Buff
    or (profile.colorizeBorder and profile.colorTypes[aura.dispelName])
    or profile.colorTypes.none
  if manualTiming or button.borderColor ~= color then
    button.Border:SetVertexColor(unpack(color))
    button.borderColor = color
  end
end

local function applyCooldown(button, profile, aura)
  button.Cooldown:SetDrawSwipe(profile.showStdSwipe)
  button.Cooldown:SetHideCountdownNumbers(not profile.showStdCooldown)
  button.Cooldown:SetShown(aura.duration > 0 and (profile.showStdSwipe or profile.showStdCooldown))

  local cooldown = aura.duration > 0 and (profile.showStdSwipe or profile.showStdCooldown)
  local start = aura.expirationTime - aura.duration
  if cooldown then
    if not button.cooldownActive or button.cooldownStart ~= start or button.cooldownDuration ~= aura.duration then
      button.Cooldown:SetCooldown(start, aura.duration)
    end
  elseif button.cooldownActive then
    button.Cooldown:Clear()
  end
  button.cooldownActive, button.cooldownStart, button.cooldownDuration = cooldown, start, aura.duration
end

local function applyTiming(button, profile, aura, manualTiming)
  local timed = not manualTiming and aura.duration > 0 and (profile.showDuration or profile.blinkTimeleft > 0)
  button.durationUpdate = timed and updateDuration or nil
  if timed then
    updateDuration(button, GetTime())
  elseif button.durationAlpha ~= 1 then
    button:SetAlpha(1)
    button.durationAlpha = 1
  end
end

function Icons:Apply(button, profile, appearance, style, aura, manualTiming)
  button.profile, button.aura = profile, aura
  IconStyle:Apply(button, profile, appearance, style, manualTiming)

  applyIcon(button, aura)
  button.Duration:SetShown(profile.showDuration and aura.duration > 0)
  button.DurationBackground:SetShown(
    profile.showDuration and aura.duration > 0 and appearance.durationPosition ~= "CENTER"
  )

  applyStacks(button, aura)
  button.StackBackground:SetShown(aura.applications > 1 and appearance.stackPosition ~= "BOTTOMRIGHT")

  applyBorder(button, profile, aura, manualTiming)
  applyCooldown(button, profile, aura)
  applyTiming(button, profile, aura, manualTiming)

  button:Show()
  IconTimers:Set(button, button.durationUpdate)
end

function Icons:Release(button)
  button:Hide()
  IconTimers:Set(button, nil)
  button.durationUpdate, button.record = nil, nil
  button.aura, button.profile, button.unit = nil, nil, nil
end
