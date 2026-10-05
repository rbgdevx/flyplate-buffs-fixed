local _, fPB = ...

local Client = fPB.Client
local Controls = fPB.Controls
local L = fPB.L

local PositionOptions = {}
fPB.PositionOptions = PositionOptions

local anchors = {
  TOPLEFT = "Top left",
  TOP = "Top",
  TOPRIGHT = "Top right",
  LEFT = "Left",
  CENTER = "Center",
  RIGHT = "Right",
  BOTTOMLEFT = "Bottom left",
  BOTTOM = "Bottom",
  BOTTOMRIGHT = "Bottom right",
}

function PositionOptions:Build()
  local limits = { buffPerLine = Controls:Range("Icons per row", 1, 1, 30) }
  local args = {
    anchors = Controls:Row(1, {
      buffAnchorPoint = Controls:Select("Aura anchor", 1, anchors),
      plateAnchorPoint = Controls:Select("Nameplate anchor", 2, anchors),
    }),
    offsets = Controls:Row(2, {
      xOffset = Controls:Range("Horizontal offset", 1, -300, 300),
      yOffset = Controls:Range("Vertical offset", 2, -300, 300),
    }),
    spacing = Controls:Row(4, {
      xInterval = Controls:Range("Horizontal spacing", 1, -10, 100),
      yInterval = Controls:Range("Vertical spacing", 2, -10, 100),
    }),
  }
  if Client.modern then
    limits.buffPerLine.name = L["Row width (base-size icons)"]
    limits.buffPerLine.desc = L["Larger icons take more room. Rows grow upward."]
    limits.buffPerLine.width = Controls:Width(limits.buffPerLine.name)
    limits.modernMaxPerGroup = Controls:Range("Maximum icons per style group", 2, 1, 100)
    args.note = Controls:Description(
      "Blizzard limits each style group separately.\nIcons follow the native nameplate's opacity and scale.",
      5
    )
  else
    limits.numLines = Controls:Range("Maximum rows", 2, 1, 20)
    args.parentWorldFrame = Controls:Toggle("Always show icons with full opacity and size", 5)
    args.parentWorldFrame.width = "double"
  end
  args.limits = Controls:Row(3, limits)
  return { type = "group", name = L["Position"], order = 3, args = args }
end
