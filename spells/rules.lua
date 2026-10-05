local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local type = type
local CopyTable = CopyTable
local tsort = table.sort

local Defaults = fPB.Defaults
local SpellLookup = fPB.SpellLookup
local SpellRanks = fPB.SpellRanks

local SpellRules = {}
fPB.SpellRules = SpellRules

local exact, names = {}, {}

local function compareKeys(a, b)
  if type(a) == type(b) then
    return a < b
  end
  return type(a) == "number"
end

function SpellRules:Keys(profile)
  local keys = {}
  for key in pairs(profile.Spells) do
    if not profile.ignoredDefaultSpells[key] then
      keys[#keys + 1] = key
    end
  end
  tsort(keys, compareKeys)
  return keys
end

function SpellRules:Rebuild(profile)
  exact, names = {}, {}
  local keys = SpellRules:Keys(profile)
  for _, key in ipairs(keys) do
    local rule = profile.Spells[key]
    local id = type(key) == "number" and key or tonumber(rule.spellID)
    if id then
      exact[id] = exact[id] or rule
    end
    if rule.name and not rule.checkID then
      names[rule.name] = names[rule.name] or rule
    end
  end
  for _, key in ipairs(keys) do
    local rule = profile.Spells[key]
    local family = not rule.checkID and rule.allRanks ~= false and SpellRanks:Get(tonumber(key) or rule.spellID)
    if family then
      for _, id in ipairs(family) do
        if not profile.ignoredDefaultSpells[id] then
          exact[id] = exact[id] or rule
        end
      end
    end
  end
end

function SpellRules:Match(id, name)
  return exact[id] or names[name]
end

function SpellRules:Exact()
  return exact
end

function SpellRules:Add(profile, value)
  local info, err = SpellLookup:Resolve(value)
  if not info then
    return nil, err
  end
  local id = info.spellID
  profile.ignoredDefaultSpells[id] = nil
  if not profile.Spells[id] then
    profile.Spells[id] = {
      name = info.name,
      spellID = id,
      show = 1,
      scale = 1,
      durationSize = profile.durationSize,
      stackSize = profile.stackSize,
      allRanks = SpellRanks.available or nil,
    }
  end
  return id
end

function SpellRules:Remove(profile, key)
  if Defaults.profile.Spells[key] then
    profile.ignoredDefaultSpells[key] = true
  end
  profile.Spells[key] = nil
end

function SpellRules:Replace(profile, key, value)
  if not tonumber(value) then
    return nil, "Enter a valid spell ID."
  end
  local info, err = SpellLookup:Resolve(value)
  if not info then
    return nil, err
  end
  local id = info.spellID
  if id == key then
    return id
  elseif profile.Spells[id] and not profile.ignoredDefaultSpells[id] then
    return nil, "That spell already has a rule."
  end
  local rule = CopyTable(profile.Spells[key])
  rule.name, rule.spellID = info.name, id
  SpellRules:Remove(profile, key)
  profile.ignoredDefaultSpells[id] = nil
  profile.Spells[id] = rule
  return id
end
