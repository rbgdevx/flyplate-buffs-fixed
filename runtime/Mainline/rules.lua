local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local GenerateClosure = GenerateClosure
local mhuge = math.huge
local tconcat = table.concat
local tsort = table.sort

local Appearance = fPB.Appearance
local SpellRules = fPB.SpellRules

local ModernRules = {}
fPB.ModernRules = ModernRules

local categories = {
  { key = "defensive", name = "Big defensives", filter = "BIG_DEFENSIVE", helpful = true },
  { key = "important", name = "Important auras", filter = "IMPORTANT", helpful = true },
  { key = "external", name = "External defensives", filter = "EXTERNAL_DEFENSIVE", helpful = true },
  { key = "crowdControl", name = "Crowd control", filter = "CROWD_CONTROL", harmful = true },
  { key = "dispellable", name = "Dispellable", filter = "DISPELLABLE", helpful = true, harmful = true },
  { key = "stealable", name = "Stealable buffs", candidate = "isStealable", helpful = true },
}

local function copy(source)
  local result = {}
  for key, value in pairs(source) do
    result[key] = value
  end
  return result
end

local function append(groups, profile, filter, candidates, rule, mine, exact)
  if profile.hidePermanent and not rule then
    candidates.maxDuration = mhuge
  end
  local group = {
    filter = filter .. (mine and "|PLAYER" or "|!PLAYER"),
    candidates = candidates,
    style = Appearance:Spell(profile, rule, mine),
    mine = mine,
    exact = exact,
    order = #groups + 1,
  }
  groups[#groups + 1] = group
  return group
end

local function split(groups, profile, filter, candidates, onlyMine)
  for _, mine in ipairs(onlyMine and { true } or { true, false }) do
    append(groups, profile, filter, copy(candidates), nil, mine, false)
  end
end

local function unlistedFilter(profile, friendly, filter)
  local categorySettings = profile[friendly and "friendlyBuffCategories" or "enemyDebuffCategories"]
  for _, category in ipairs(categories) do
    if categorySettings and categorySettings[category.key] == false and category.filter then
      filter = filter .. "|!" .. category.filter
    end
  end
  return filter
end

local function addExact(groups, profile, friendly)
  local mode = friendly and profile.showBuffs or profile.showDebuffs
  if mode == 5 then
    return
  end
  local filter = friendly and "HELPFUL" or "HARMFUL"
  local exclusions, styles = {}, {}
  local spells = SpellRules:Exact()
  local ids = {}
  for id in pairs(spells) do
    ids[#ids + 1] = id
  end
  tsort(ids)
  for _, id in ipairs(ids) do
    local rule = spells[id]
    exclusions[id] = true
    local show = rule.show
    if show == 1 or show == 2 or show == 4 and friendly or show == 5 and not friendly then
      for _, mine in ipairs((mode == 4 or show == 2) and { true } or { true, false }) do
        local style = Appearance:Spell(profile, rule, mine)
        local key = tconcat({ style.scale, style.durationSize, style.stackSize, tostring(mine) }, ":")
        local group = styles[key]
        if not group then
          group = append(groups, profile, filter, { includeSpellIDs = {} }, rule, mine, true)
          styles[key] = group
        end
        group.candidates.includeSpellIDs[id] = true
      end
    end
  end
  if mode == 1 or mode == 2 or mode == 4 then
    split(groups, profile, unlistedFilter(profile, friendly, filter), { excludeSpellIDs = exclusions }, mode ~= 1)
  end
end

local function addBroad(groups, profile, friendly)
  local mode = friendly and profile.showDebuffs or profile.showBuffs
  local broad = profile[friendly and "modernFriendlyDebuffs" or "modernEnemyBuffs"]
  local filter = friendly and "HARMFUL" or "HELPFUL"
  local choice = broad and broad.mode or "inherit"
  if choice == "all" or choice == "mine" then
    split(groups, profile, filter, {}, choice == "mine")
  elseif choice == "inherit" then
    if mode == 1 or mode == 2 or mode == 4 then
      split(groups, profile, filter, {}, mode ~= 1)
    end
  elseif choice == "categories" then
    local excluded, excludedCandidates = "", {}
    for _, category in ipairs(categories) do
      if category[friendly and "harmful" or "helpful"] and broad.categories[category.key] then
        local candidates = copy(excludedCandidates)
        local categoryFilter = filter .. excluded
        if category.filter then
          categoryFilter = categoryFilter .. "|" .. category.filter
          excluded = excluded .. "|!" .. category.filter
        else
          candidates[category.candidate] = true
          excludedCandidates[category.candidate] = false
        end
        split(groups, profile, categoryFilter, candidates, false)
      end
    end
  end
end

local function compare(order, a, b)
  if order == "mine" and a.mine ~= b.mine then
    return a.mine
  end
  if order == "listed" and a.exact ~= b.exact then
    return a.exact
  end
  if order == "larger" and a.style.scale ~= b.style.scale then
    return a.style.scale > b.style.scale
  end
  return a.order < b.order
end

function ModernRules:SortGroups(groups, order)
  tsort(groups, GenerateClosure(compare, order or "mine"))
end

function ModernRules:Build(profile, friendly)
  local groups = {}
  addExact(groups, profile, friendly)
  addBroad(groups, profile, friendly)
  ModernRules:SortGroups(groups, profile.modernGroupOrder)
  return groups
end
