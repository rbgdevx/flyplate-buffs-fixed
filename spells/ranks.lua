local _, fPB = ...

local ipairs = ipairs
local slower = string.lower
local FoldCase = C_Intl and C_Intl.FoldCase
local GetSpellName = C_Spell.GetSpellName

local SpellRankFamilies = fPB.SpellRankFamilies

local SpellRanks = { available = SpellRankFamilies ~= nil }
fPB.SpellRanks = SpellRanks

local ranksByID = {}
local ranksByName
for _, family in ipairs(SpellRankFamilies or {}) do
  for _, id in ipairs(family) do
    ranksByID[id] = family
  end
end

local function nameKey(name)
  return (FoldCase and FoldCase(name)) or slower(name)
end

local function addName(names, name, family)
  local key = nameKey(name)
  if names[key] == nil or names[key] == family then
    names[key] = family
  else
    -- Different classes can have unrelated spells with the same name.
    names[key] = false
  end
end

local function buildNameLookup()
  local names = {}
  for _, family in ipairs(SpellRankFamilies) do
    addName(names, family.name, family)

    -- One representative ID per family supplies the client's localized name.
    local name = GetSpellName(family[1])
    if name and name ~= "" then
      addName(names, name, family)
    end
  end
  return names
end

function SpellRanks:Get(id)
  return ranksByID[id]
end

function SpellRanks:FindByName(name)
  if not SpellRanks.available then
    return nil
  end

  if not ranksByName then
    ranksByName = buildNameLookup()
  end
  return ranksByName[nameKey(name)] or nil
end
