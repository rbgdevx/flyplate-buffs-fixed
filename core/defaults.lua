local _, fPB = ...

local ipairs = ipairs

local GetSpellInfo = C_Spell.GetSpellInfo

local defaultHiddenSpells = fPB.defaultHiddenSpells
local defaultLargeSpells = fPB.defaultLargeSpells
local defaultMediumSpells = fPB.defaultMediumSpells

local Defaults = {
  profile = {
    enabled = true,
    targetOnly = false,
    showDebuffs = 2,
    showBuffs = 3,
    showTooltip = false,
    tooltipInCombat = true,
    enemyDebuffCategories = { crowdControl = true, dispellable = true },
    friendlyBuffCategories = { defensive = true, important = true, external = true, dispellable = true },
    hidePermanent = true,
    notHideOnPersonalResource = true,
    hideBlizzardAuras = true,

    showOnPlayers = true,
    showOnPets = true,
    showOnNPC = true,

    showOnEnemy = true,
    showOnFriend = true,
    showOnNeutral = true,

    showOnlyInCombat = false,
    showUnitInCombat = false,

    parentWorldFrame = false,

    baseWidth = 24,
    baseHeight = 24,
    myScale = 0.2,
    cropTexture = true,

    buffAnchorPoint = "BOTTOM",
    plateAnchorPoint = "TOP",

    xInterval = 4,
    yInterval = 12,

    xOffset = 0,
    yOffset = 4,

    buffPerLine = 6,
    numLines = 3,

    showStdCooldown = true,
    showStdSwipe = false,

    showDuration = true,
    showDecimals = true,
    durationPosition = 1, -- 1 - under, 2 - on icon, 3 - above icon
    font = "Friz Quadrata TT", --durationFont
    durationSize = 10,
    colorTransition = true,
    colorSingle = { 1.0, 1.0, 1.0 },

    stackPosition = 1, -- 1 - on icon, 2 - under, 3 - above icon
    stackFont = "Friz Quadrata TT",
    stackSize = 10,
    stackColor = { 1.0, 1.0, 1.0 },

    blinkTimeleft = 0.2,

    borderStyle = 1, -- 1 = \\texture\\border.tga, 2 = Blizzard, 3 = none
    colorizeBorder = true,
    colorTypes = {
      Magic = { 0.20, 0.60, 1.00 },
      Curse = { 0.60, 0.00, 1.00 },
      Disease = { 0.60, 0.40, 0 },
      Poison = { 0.00, 0.60, 0 },
      none = { 0.80, 0, 0 },
      Buff = { 0.00, 1.00, 0 },
    },

    disableSort = false,
    sortMode = {
      "my", -- [1]
      "expiration", -- [2]
      "disable", -- [3]
      "disable", -- [4]
    },

    Spells = {},
    ignoredDefaultSpells = {},

    showSpellID = false,
  },
}

local function addDefaults(ids, scale, size, show)
  for _, id in ipairs(ids) do
    local info = GetSpellInfo(id)
    if info then
      Defaults.profile.Spells[id] = {
        name = info.name,
        spellID = id,
        scale = scale,
        durationSize = size,
        stackSize = size,
        show = show,
      }
    end
  end
end

function Defaults:Initialize()
  addDefaults(defaultLargeSpells, 2, 18, 1)
  addDefaults(defaultMediumSpells, 1.5, 14, 1)
  addDefaults(defaultHiddenSpells, 1, 14, 3)
end

fPB.Defaults = Defaults
