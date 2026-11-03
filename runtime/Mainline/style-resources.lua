local _, fPB = ...

local pairs = pairs
local tCompare = tCompare
local unpack = unpack
local CopyTable = CopyTable
local CreateColor = CreateColor
local Enum = Enum
local GetAuraBorderColor = AuraUtil.GetAuraBorderColor
local CreateColorCurve = C_CurveUtil.CreateColorCurve
local CreateNumericRuleFormatter = C_StringUtil.CreateNumericRuleFormatter

local StyleResources = {}
fPB.StyleResources = StyleResources

local formatters = {}
local durationColor
local borderColors, colorByDispel, borderOptions
local customTypes = { [0] = "None", [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison", [9] = "Enrage" }

local function createDurationFormatter(decimals)
  local formatter = CreateNumericRuleFormatter()
  formatter:AddBreakpoint({ threshold = 0, format = decimals and "%.1f" or "", step = decimals and 0.1 or nil })
  formatter:AddBreakpoint({ threshold = decimals and 10 or 0.5, format = "%.0f", step = 1 })
  formatter:AddBreakpoint({ threshold = 59.5, format = "%dm", components = { { div = 60, step = 1 } } })
  formatter:AddBreakpoint({ threshold = 3570, format = "%dh", components = { { div = 3600, step = 1 } } })
  formatter:AddBreakpoint({ threshold = 84600, format = "%dd", components = { { div = 86400, step = 1 } } })
  return formatter
end

local function durationFormatter(decimals)
  local key = decimals and 1 or 2
  if not formatters[key] then
    formatters[key] = createDurationFormatter(decimals)
  end
  return formatters[key]
end

local function durationColorCurve()
  if not durationColor then
    durationColor = CreateColorCurve()
    durationColor:AddPoint(0, CreateColor(1, 0, 0))
    durationColor:AddPoint(0.5, CreateColor(1, 1, 0))
    durationColor:AddPoint(1, CreateColor(0, 1, 0))
  end
  return durationColor
end

local function durationOptions(style)
  local options = { textFormatter = durationFormatter(style.decimals) }
  if style.durationColor then
    options.textColor = { curve = durationColorCurve(), property = Enum.DurationTextBindingProperty.RemainingPercent }
  end
  return options
end

local function borderCurve(style, helpful)
  local curve = CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  for id, kind in pairs(customTypes) do
    local rgb = helpful and style.colors.Buff or style.colorByDispel and style.colors[kind] or style.colors.None
    curve:AddPoint(id, CreateColor(unpack(rgb or style.colors.None)))
  end

  local untyped = GetAuraBorderColor("None")
  curve:AddPoint(5, untyped)
  curve:AddPoint(10, untyped)
  curve:AddPoint(11, GetAuraBorderColor("Bleed"))
  curve:AddPoint(12, untyped)
  return curve
end

local function createBorderOptions(style, helpful)
  return {
    showWhenHarmful = not helpful,
    showWhenHelpful = helpful,
    showWithoutDispelType = true,
    style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
    customDispelColorCurve = borderCurve(style, helpful),
  }
end

local function borders(style)
  if not borderOptions or colorByDispel ~= style.colorByDispel or not tCompare(borderColors, style.colors, 3) then
    borderColors, colorByDispel = CopyTable(style.colors), style.colorByDispel
    borderOptions = { createBorderOptions(style, false), createBorderOptions(style, true) }
  end
  return borderOptions
end

function StyleResources:Build(style)
  return {
    duration = style.duration and durationOptions(style) or nil,
    borders = style.border ~= "none" and borders(style) or nil,
  }
end
