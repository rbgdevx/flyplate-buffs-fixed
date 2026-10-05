local _, fPB = ...

local ipairs = ipairs
local tostring = tostring
local GenerateClosure = GenerateClosure
local sfind = string.find
local tsort = table.sort

local SpellLookup = fPB.SpellLookup
local SpellRules = fPB.SpellRules

local SpellSearch = {}
fPB.SpellSearch = SpellSearch

local function compare(entries, a, b)
  if entries[a].sortName == entries[b].sortName then
    return tostring(a) < tostring(b)
  end
  return entries[a].sortName < entries[b].sortName
end

function SpellSearch:List(profile, query)
  local matches, entries = {}, {}
  local needle = SpellLookup:Normalize(query or "")
  for _, key in ipairs(SpellRules:Keys(profile)) do
    local rule = profile.Spells[key]
    local name = rule.name or tostring(key)
    local normalized = SpellLookup:Normalize(name)
    if sfind(normalized, needle, 1, true) or sfind(tostring(key), needle, 1, true) then
      entries[key] = { name = name, sortName = normalized }
      matches[#matches + 1] = key
    end
  end
  tsort(matches, GenerateClosure(compare, entries))
  return matches, entries
end
