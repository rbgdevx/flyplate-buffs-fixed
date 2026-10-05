local _, fPB = ...

local GenerateClosure = GenerateClosure
local UnitIsUnit = UnitIsUnit
local mhuge = math.huge
local tsort = table.sort

local Appearance = fPB.Appearance
local SpellRules = fPB.SpellRules

local ClassicRules = {}
fPB.ClassicRules = ClassicRules

local function compare(profile, a, b)
  for index = 1, 4 do
    local mode, reverse = profile.sortMode[index], profile.sortMode[index + 0.5]
    if mode ~= "disable" and mode then
      local left, right = a[mode], b[mode]
      if mode == "expiration" then
        left = a.aura.expirationTime > 0 and a.aura.expirationTime or mhuge
        right = b.aura.expirationTime > 0 and b.aura.expirationTime or mhuge
      elseif mode == "my" then
        left, right = a.my and 1 or 0, b.my and 1 or 0
      end
      if left ~= right then
        if mode == "expiration" then
          return reverse and left > right or not reverse and left < right
        end
        return reverse and left < right or not reverse and left > right
      end
    end
  end
  return a.aura.auraInstanceID < b.aura.auraInstanceID
end

function ClassicRules:Evaluate(profile, aura, friendly)
  local mode = aura.isHelpful and profile.showBuffs or profile.showDebuffs
  if mode == 5 then
    return nil
  end
  local mine = aura.sourceUnit and UnitIsUnit(aura.sourceUnit, "player") or false
  if mode == 4 and not mine then
    return nil
  end
  local rule = SpellRules:Match(aura.spellId, aura.name)
  if rule then
    local show = rule.show
    if not (show == 1 or show == 2 and mine or show == 4 and friendly or show == 5 and not friendly) then
      return nil
    end
  elseif not (mode == 1 or (mode == 2 or mode == 4) and mine) or profile.hidePermanent and aura.duration == 0 then
    return nil
  end
  local style = Appearance:Spell(profile, rule, mine)
  return { aura = aura, style = style, my = mine, type = aura.isHelpful and "HELPFUL" or "HARMFUL", scale = style.scale }
end

function ClassicRules:Sort(profile, records)
  if not profile.disableSort then
    tsort(records, GenerateClosure(compare, profile))
  end
end
