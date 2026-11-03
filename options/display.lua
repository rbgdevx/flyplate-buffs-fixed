local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local GenerateClosure = GenerateClosure
local InCombatLockdown = InCombatLockdown

local Client = fPB.Client
local Controls = fPB.Controls
local Defaults = fPB.Defaults
local L = fPB.L
local Options = fPB.Options

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
  return InCombatLockdown() or not settings or settings.mode ~= "categories"
end

local function limitDisabled(prefix)
  return InCombatLockdown() or fPB.db.profile[prefix .. "Unlimited"]
end

local function confirmUnlimited(_, value)
  return value
end

local function unlimitedToggle()
  local toggle = Controls:Toggle("Unlimited icons", 4)
  toggle.confirm = confirmUnlimited
  toggle.confirmText = L["Unlimited icons may impact performance."]
  return toggle
end

local function groupLimit(prefix)
  local limit = Controls:Range("Maximum icons per group", 3, 1, 10)
  limit.desc = L["Each group can display this many icons. Multiple groups can show more icons above one nameplate."]
  limit.disabled = GenerateClosure(limitDisabled, prefix)
  return limit
end

local function limitControls(key, show, prefix)
  local args = {
    [key] = show,
    [prefix .. "Limit"] = groupLimit(prefix),
    [prefix .. "Unlimited"] = unlimitedToggle(),
  }
  for _, control in pairs(args) do
    control.width = "relative"
    control.relWidth = 1 / 3
  end
  return Controls:Group("", 2, args)
end

local function broadMode(key, helpful)
  local mode = Controls:Select("Show", 2, {
    inherit = L[helpful and "Use friendly buffs setting" or "Use enemy debuffs setting"],
    all = L["All"],
    mine = L["Only mine"],
    categories = L["Selected categories"],
    none = L["None"],
  })
  mode.width = "double"
  mode.get = GenerateClosure(getBroad, key)
  mode.set = GenerateClosure(setBroad, key)
  return mode
end

local function broadCategory(key, category, order)
  local toggle = Controls:Toggle(category[2], order)
  toggle.get = GenerateClosure(getCategory, key, category[1])
  toggle.set = GenerateClosure(setCategory, key, category[1])
  toggle.disabled = GenerateClosure(categoryDisabled, key)
  return toggle
end

local function broadSection(key, title, order, helpful, prefix)
  local args = {
    note = Controls:Description("Blizzard supports categories here, not individual spell rules.", 1),
    show = limitControls("mode", broadMode(key, helpful), prefix),
  }
  local categoryOrder = 3
  for _, category in ipairs(categories) do
    if category[3] == nil or category[3] == helpful then
      args[category[1]] = broadCategory(key, category, categoryOrder)
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

local function spellCategory(key, category, order)
  local toggle = Controls:Toggle(category[2], order)
  toggle.get = GenerateClosure(getSpellCategory, key, category[1])
  toggle.set = GenerateClosure(setSpellCategory, key, category[1])
  return toggle
end

local function spellSection(key, title, order, prefix)
  local show = Controls:Select("Show", 2, modes)
  show.width = "double"
  local categoryKey = key == "showDebuffs" and "enemyDebuffCategories" or "friendlyBuffCategories"
  local args = {
    note = Controls:Description("Choose a starting set, then customize individual spells in Spells.", 1),
    show = limitControls(key, show, prefix),
    showSpacing = Controls:Description("", 2.5),
    categoriesNote = Controls:Description(
      "Uncheck a category to hide matching auras that aren't in your spell list.",
      3
    ),
  }
  for index, category in ipairs(categories) do
    if Defaults.profile[categoryKey][category[1]] ~= nil then
      args[category[1]] = spellCategory(categoryKey, category, index + 3)
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
  local visibility = {
    targetOnly = Controls:Toggle("Target only", 1),
  }
  local general = {
    settings = Controls:Row(1, {
      hidePermanent = Controls:Toggle("Hide unlisted permanent auras", 1),
      showTooltip = Controls:Toggle("Show tooltip", 2),
      tooltipInCombat = Controls:Toggle("Allow tooltips in combat", 3),
    }),
  }
  general.settings.args.tooltipInCombat.disabled = function()
    return not fPB.db.profile.showTooltip
  end
  local args = {
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
    args.enemyDebuffs = spellSection("showDebuffs", "Enemy debuffs", 1, "enemyDebuff")
    args.enemyBuffs = broadSection("modernEnemyBuffs", "Enemy buffs", 2, true, "enemyBuff")
    args.friendlyDebuffs = broadSection("modernFriendlyDebuffs", "Friendly debuffs", 3, false, "friendlyDebuff")
    args.friendlyBuffs = spellSection("showBuffs", "Friendly buffs", 4, "friendlyBuff")
  else
    args.debuffsRow = Controls:Row(1, { showDebuffs = Controls:Select("Show debuffs", 1, modes) })
    args.buffsRow = Controls:Row(2, { showBuffs = Controls:Select("Show buffs", 1, modes) })
    visibility.notHideOnPersonalResource = Controls:Toggle("Don't hide buffs on personal resource bar", 2)
  end
  general.visibility = Controls:Row(2, visibility)
  return { type = "group", name = L["Display"], order = 1, args = args }
end
