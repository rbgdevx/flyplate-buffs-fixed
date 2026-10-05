local _, fPB = ...

local tonumber = tonumber
local mfloor = math.floor
local slower = string.lower
local smatch = string.match
local FoldCase = C_Intl and C_Intl.FoldCase
local GetSpellInfo = C_Spell.GetSpellInfo

local SpellRanks = fPB.SpellRanks

local SpellLookup = {}
fPB.SpellLookup = SpellLookup

function SpellLookup:Normalize(value)
  return FoldCase and FoldCase(value) or slower(value)
end

function SpellLookup:Resolve(value)
  value = smatch(value, "^%s*(.-)%s*$")
  if value == "" then
    return nil, "Enter a spell name or ID."
  end
  local id = tonumber(value)
  if id and (id <= 0 or id ~= mfloor(id)) then
    return nil, "Enter a valid spell ID."
  end
  local info = GetSpellInfo(id or value)
  if not info and not id then
    local family = SpellRanks:FindByName(value)
    info = family and GetSpellInfo(family[1])
  end
  if not info then
    return nil, "Spell not found. Try an exact spell ID."
  end
  return info
end
