local _, fPB = ...

local ipairs = ipairs
local unpack = unpack
local GenerateClosure = GenerateClosure

local Client = fPB.Client
local Controls = fPB.Controls
local Fonts = fPB.Fonts
local L = fPB.L
local Options = fPB.Options

local StyleOptions = {}
fPB.StyleOptions = StyleOptions

local function getDispel(key)
  return unpack(fPB.db.profile.colorTypes[key])
end

local function setDispel(key, _, r, g, b)
  fPB.db.profile.colorTypes[key] = { r, g, b }
  Options:Changed()
end

function StyleOptions:Build()
  local fontChoices = Fonts:GetChoices()
  local mine = Controls:Range("Additional scale for my auras", 3, -0.5, 1.5, 0.05)
  mine.isPercent = true
  local duration = {
    visibility = Controls:Row(1, {
      showDuration = Controls:Toggle("Show duration", 1),
      showDecimals = Controls:Toggle("Show decimals", 2),
    }),
    text = Controls:Row(2, {
      durationPosition = Controls:Select("Duration position", 1, { L["Below"], L["On icon"], L["Above"] }),
      font = Controls:Select("Duration font", 2, fontChoices),
      durationSize = Controls:Range("Duration font size", 3, 6, 40),
    }),
    colors = Controls:Row(3, {
      colorTransition = Controls:Toggle("Color by time remaining", 1),
      colorSingle = Controls:Color("colorSingle", "Duration color", 2),
    }),
  }
  if not Client.modern then
    local blink = Controls:Range("Blink when close to expiring", 1, 0, 0.5, 0.05)
    blink.isPercent = true
    blink.desc = L["Blink spell if below x% time left (only if it's below 60 seconds)"]
    duration.blink = Controls:Row(4, { blinkTimeleft = blink })
  end
  local borders = {
    appearance = Controls:Row(1, {
      borderStyle = Controls:Select("Border style", 1, { L["Square"], L["Blizzard"], L["None"] }),
      colorizeBorder = Controls:Toggle("Color by dispel type", 2),
    }),
  }
  for index, key in ipairs({ "Buff", "none", "Magic", "Curse", "Disease", "Poison" }) do
    borders["color" .. key] = {
      type = "color",
      name = L[key == "none" and "Other debuffs" or key],
      order = index + 1,
      width = Controls:Width(L[key == "none" and "Other debuffs" or key]),
      get = GenerateClosure(getDispel, key),
      set = GenerateClosure(setDispel, key),
    }
  end
  return {
    type = "group",
    name = L["Style"],
    order = 2,
    args = {
      icons = Controls:Group("Icons", 1, {
        size = Controls:Row(1, {
          baseWidth = Controls:Range("Icon width", 1, 5, 100),
          baseHeight = Controls:Range("Icon height", 2, 5, 100),
          myScale = mine,
        }),
        effects = Controls:Row(2, {
          cropTexture = Controls:Toggle("Prevent stretched icons", 1),
          showStdSwipe = Controls:Toggle("Show cooldown sweep", 2),
          showStdCooldown = Controls:Toggle("Show cooldown numbers", 3),
        }),
      }),
      duration = Controls:Group("Duration", 2, duration),
      stacks = Controls:Group("Stacks", 3, {
        text = Controls:Row(1, {
          stackPosition = Controls:Select("Stack position", 1, { L["On icon"], L["Below"], L["Above"] }),
          stackFont = Controls:Select("Stack font", 2, fontChoices),
          stackSize = Controls:Range("Stack font size", 3, 6, 40),
        }),
        stackColor = Controls:Color("stackColor", "Stack color", 2),
      }),
      borders = Controls:Group("Borders", 4, borders),
    },
  }
end
