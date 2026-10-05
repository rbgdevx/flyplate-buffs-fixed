local _, fPB = ...

local CopyTable = CopyTable

local Appearance = {}
fPB.Appearance = Appearance

local durationPositions = { "BOTTOM", "CENTER", "TOP" }
local stackPositions = { "BOTTOMRIGHT", "BOTTOM", "TOP" }
local borders = { "square", "blizzard", "none" }

function Appearance:Build(profile)
  local colors = CopyTable(profile.colorTypes)
  colors.None = colors.none
  return {
    style = {
      width = profile.baseWidth,
      height = profile.baseHeight,
      crop = profile.cropTexture,
      duration = profile.showDuration,
      decimals = profile.showDecimals,
      durationPosition = durationPositions[profile.durationPosition],
      durationX = 0,
      durationY = 0,
      durationFont = profile.font,
      durationSize = profile.durationSize,
      durationColor = profile.colorTransition,
      durationTextColor = profile.colorSingle,
      durationBackgroundColor = { 0, 0, 0, 0.75 },
      stackPosition = stackPositions[profile.stackPosition],
      stackX = 0,
      stackY = 0,
      stackFont = profile.stackFont,
      stackSize = profile.stackSize,
      stackColor = profile.stackColor,
      swipe = profile.showStdSwipe,
      cooldownNumbers = profile.showStdCooldown,
      cooldownFont = profile.font,
      cooldownSize = profile.durationSize,
      cooldownTextColor = profile.colorSingle,
      cooldownX = 0,
      cooldownY = 0,
      border = borders[profile.borderStyle],
      colorByDispel = profile.colorizeBorder,
      colors = colors,
    },
    tooltip = profile.showTooltip,
    position = {
      anchor = profile.buffAnchorPoint,
      relativeAnchor = profile.plateAnchorPoint,
      x = profile.xOffset,
      y = profile.yOffset,
      perRow = profile.buffPerLine,
      gapX = profile.xInterval,
      gapY = profile.yInterval,
    },
    sorting = {
      method = profile.modernSortMethod or "ExpirationOnly",
      reverse = profile.modernSortReverse or false,
    },
  }
end

function Appearance:Spell(profile, rule, mine)
  return {
    scale = (mine and 1 + profile.myScale or 1) * (rule and rule.scale or 1),
    durationSize = rule and rule.durationSize or profile.durationSize,
    stackSize = rule and rule.stackSize or profile.stackSize,
  }
end
