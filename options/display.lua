local _, fPB = ...

local ipairs = ipairs
local GenerateClosure = GenerateClosure

local Client = fPB.Client
local Controls = fPB.Controls
local Defaults = fPB.Defaults
local L = fPB.L
local Options = fPB.Options
local Restrictions = fPB.Restrictions

local DisplayOptions = {}
fPB.DisplayOptions = DisplayOptions

local modes = { L["All + spell styles"], L["Mine + spell list"], L["Spell list only"], L["Mine only"], L["None"] }
local categories = {
  { "defensive", "Big defensives", true },
  { "important", "Important auras", true },
  { "external", "External defensives", true },
  { "crowdControl", "Crowd control", false },
  { "dispellable", "Dispellable" },
  { "stealable", "Stealable buffs", true },
}

local function getBroad(key)
  local settings = fPB.db.profile[key]
  return settings and settings.mode or "inherit"
end

local function setBroad(key, _, value)
  local profile = fPB.db.profile
  profile[key] = profile[key] or { categories = {} }
  profile[key].mode = value
  Options:Changed()
end

local function getCategory(key, category)
  local settings = fPB.db.profile[key]
  return settings and settings.categories[category] or false
end

local function setCategory(key, category, _, value)
  local profile = fPB.db.profile
  profile[key] = profile[key] or { mode = "inherit", categories = {} }
  profile[key].categories[category] = value
  Options:Changed()
end

local function categoryDisabled(key)
  local settings = fPB.db.profile[key]
  return Restrictions:Active() or not settings or settings.mode ~= "categories"
end

local function broadSection(key, title, order, helpful)
  local args = {
    note = Controls:Description("Blizzard supports categories here, not individual spell rules.", 1),
    mode = {
      type = "select",
      name = L["Show"],
      order = 2,
      width = "double",
      values = {
        inherit = L[helpful and "Use friendly buffs setting" or "Use enemy debuffs setting"],
        all = L["All"],
        mine = L["Only mine"],
        categories = L["Selected categories"],
        none = L["None"],
      },
      get = GenerateClosure(getBroad, key),
      set = GenerateClosure(setBroad, key),
    },
  }
  args.show = Controls:Row(2, { mode = args.mode })
  args.mode = nil
  local categoryOrder = 3
  for _, category in ipairs(categories) do
    if category[3] == nil or category[3] == helpful then
      local toggle = Controls:Toggle(category[2], categoryOrder)
      toggle.get = GenerateClosure(getCategory, key, category[1])
      toggle.set = GenerateClosure(setCategory, key, category[1])
      toggle.disabled = GenerateClosure(categoryDisabled, key)
      args[category[1]] = toggle
      categoryOrder = categoryOrder + 1
    end
  end
  return {
    type = "group",
    name = L[title],
    inline = true,
    order = order,
    args = args,
  }
end

local function getSpellCategory(key, category)
  return fPB.db.profile[key][category]
end

local function setSpellCategory(key, category, _, value)
  fPB.db.profile[key][category] = value
  Options:Changed()
end

local function spellSection(key, title, order)
  local show = Controls:Select("Show", 2, modes)
  show.width = "double"
  local categoryKey = key == "showDebuffs" and "enemyDebuffCategories" or "friendlyBuffCategories"
  local args = {
    note = Controls:Description("Choose a starting set, then customize individual spells in Spells.", 1),
    show = Controls:Row(2, { [key] = show }),
    showSpacing = Controls:Description("", 2.5),
    categoriesNote = Controls:Description(
      "Uncheck a category to hide matching auras that aren't in your spell list.",
      3
    ),
  }
  for index, category in ipairs(categories) do
    if Defaults.profile[categoryKey][category[1]] ~= nil then
      local toggle = Controls:Toggle(category[2], index + 3)
      toggle.get = GenerateClosure(getSpellCategory, categoryKey, category[1])
      toggle.set = GenerateClosure(setSpellCategory, categoryKey, category[1])
      args[category[1]] = toggle
    end
  end
  return {
    type = "group",
    name = L[title],
    inline = true,
    order = order,
    args = args,
  }
end

function DisplayOptions:Build()
  local general = {
    settings = Controls:Row(1, {
      hidePermanent = Controls:Toggle("Hide unlisted permanent auras", 1),
      showTooltip = Controls:Toggle("Show tooltip", 2),
    }),
  }
  local args = {
    targetOnly = Controls:Toggle("Target only", 0.5),
    general = Controls:Group("General", 5, general),
    units = Controls:Group("Which nameplates?", 20, {
      relation = Controls:Row(1, {
        showOnEnemy = Controls:Toggle("Show on enemies", 1),
        showOnFriend = Controls:Toggle("Show on allies", 2),
        showOnNeutral = Controls:Toggle("Show on neutral units", 3),
      }),
      types = Controls:Row(2, {
        showOnPlayers = Controls:Toggle("Show on players", 1),
        showOnPets = Controls:Toggle("Show on pets", 2),
        showOnNPC = Controls:Toggle("Show on NPCs", 3),
      }),
    }),
    combat = Controls:Group("Combat", 30, {
      settings = Controls:Row(1, {
        showOnlyInCombat = Controls:Toggle("Show only in combat", 1),
        showUnitInCombat = Controls:Toggle("Show only on units in combat", 2),
      }),
    }),
  }
  if Client.modern then
    args.enemyDebuffs = spellSection("showDebuffs", "Enemy debuffs", 1)
    args.enemyBuffs = broadSection("modernEnemyBuffs", "Enemy buffs", 2, true)
    args.friendlyDebuffs = broadSection("modernFriendlyDebuffs", "Friendly debuffs", 3, false)
    args.friendlyBuffs = spellSection("showBuffs", "Friendly buffs", 4)
  else
    args.targetRow = Controls:Row(0, { targetOnly = args.targetOnly })
    args.targetOnly = nil
    args.debuffsRow = Controls:Row(1, { showDebuffs = Controls:Select("Show debuffs", 1, modes) })
    args.buffsRow = Controls:Row(2, { showBuffs = Controls:Select("Show buffs", 1, modes) })
    general.personal = Controls:Row(2, {
      notHideOnPersonalResource = Controls:Toggle("Don't hide buffs on personal resource bar", 1),
    })
  end
  return { type = "group", name = L["Display"], order = 1, args = args }
end
