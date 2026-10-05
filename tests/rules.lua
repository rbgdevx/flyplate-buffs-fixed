local H = dofile("tests/helpers.lua")
local function boot(interface)
  local state = H.environment(interface)
  H.loadAddon(state)
  return state, state.ns
end
local function aura(id, mine, helpful)
  return {
    auraInstanceID = id,
    spellId = id,
    name = "Shadow Word: Pain",
    sourceUnit = mine and "player" or "other",
    isHelpful = helpful or false,
    isHarmful = not helpful,
    applications = 1,
    duration = 18,
    expirationTime = 110,
    icon = 1,
  }
end
for _, interface in ipairs({ 11509, 20506, 50504 }) do
  local state, ns = boot(interface)
  local p = ns.db.profile
  p.Spells = { [589] = { show = 1, spellID = 589, name = "Shadow Word: Pain", scale = 1.5 } }
  p.ignoredDefaultSpells = {}
  p.showDebuffs = 4
  ns.SpellRules:Rebuild(p)
  H.equal(ns.ClassicRules:Evaluate(p, aura(589, false), false), nil, "Mine only gates listed spells")
  local mine = assert(ns.ClassicRules:Evaluate(p, aura(589, true), false))
  assert(math.abs(mine.scale - 1.8) < 0.0001, "legacy additive mine scale composes with individual scale")
  p.showDebuffs = 5
  H.equal(ns.ClassicRules:Evaluate(p, aura(589, true), false), nil, "None gates listed spells")
  p.showDebuffs = 3
  assert(ns.ClassicRules:Evaluate(p, aura(594, false), false), "name fallback covers other ranks")
  p.Spells[589].checkID = true
  ns.SpellRules:Rebuild(p)
  H.equal(ns.ClassicRules:Evaluate(p, aura(594, false), false), nil, "checkID is exact")
  p.Spells[589].show = 4
  assert(ns.ClassicRules:Evaluate(p, aura(589, false), true))
  H.equal(ns.ClassicRules:Evaluate(p, aura(589, false), false), nil)
  p.Spells[589].show = 5
  assert(ns.ClassicRules:Evaluate(p, aura(589, false), false))
  H.equal(ns.ClassicRules:Evaluate(p, aura(589, false), true), nil)
  p.Spells[589].show = 1
  local permanent = aura(589, true)
  permanent.duration = 0
  assert(ns.ClassicRules:Evaluate(p, permanent, false), "listed permanent spell overrides hidePermanent")
  p.Spells = {}
  p.showDebuffs = 1
  ns.SpellRules:Rebuild(p)
  H.equal(ns.ClassicRules:Evaluate(p, permanent, false), nil)
  local records = {
    { my = false, type = "HARMFUL", scale = 1, aura = aura(1, false) },
    { my = true, type = "HARMFUL", scale = 2, aura = aura(2, true) },
  }
  p.sortMode = { "my", "scale", "type", "expiration" }
  ns.ClassicRules:Sort(p, records)
  H.equal(records[1].my, true)
  p.sortMode[1.5] = true
  ns.ClassicRules:Sort(p, records)
  H.equal(records[1].my, false)
  print("Classic matching and sorting:", interface)
end
local function included(groups, id, mine)
  for _, group in ipairs(groups) do
    if group.candidates.includeSpellIDs and group.candidates.includeSpellIDs[id] and group.mine == mine then
      return true
    end
  end
  return false
end
local state, ns = boot(16001)
local p = ns.db.profile
p.Spells = {
  [970] = { spellID = 970, name = "Shadow Word: Pain", show = 1, scale = 1 },
  [594] = { spellID = 594, name = "Shadow Word: Pain", show = 3, checkID = true },
}
p.ignoredDefaultSpells = {}
p.showDebuffs = 2
ns.SpellRules:Rebuild(p)
local groups = ns.ModernRules:Build(p, false)
assert(included(groups, 589, false), "bundled all ranks include alternate ranks")
assert(not included(groups, 594, true), "explicit Never wins over expanded family")
p.showDebuffs = 4
groups = ns.ModernRules:Build(p, false)
assert(included(groups, 589, true))
assert(not included(groups, 589, false))
p.showDebuffs = 5
assert(#ns.ModernRules:Build(p, false) == 0)
p.showBuffs = 1
for _, group in ipairs(ns.ModernRules:Build(p, false)) do
  assert(
    not group.candidates.includeSpellIDs and not group.candidates.excludeSpellIDs,
    "enemy buffs cannot use individual ID filters"
  )
end
p.showDebuffs = 2
p.showBuffs = 3
p.Spells[970].show = 4
assert(not included(ns.ModernRules:Build(p, false), 970, true))
assert(included(ns.ModernRules:Build(p, true), 970, true))
p.Spells[970].show = 5
assert(not included(ns.ModernRules:Build(p, true), 970, true))
local info = assert(ns.SpellLookup:Resolve("viper sting"))
assert(info.spellID > 0)
assert(not ns.SpellLookup:Resolve("invalid spell name"))
assert(not ns.SpellLookup:Resolve("-1"))
assert(not ns.SpellLookup:Resolve("3.5"))
local results = ns.SpellSearch:List(p, "[")
H.equal(#results, 0, "literal search does not interpret patterns")
print("Modern native filters, rank precedence, literal search and lookup passed")

for _, interface in ipairs({ 120100, 16001 }) do
  local _, addon = boot(interface)
  local profile = addon.db.profile
  profile.Spells = { [118] = { spellID = 118, show = 1 } }
  profile.showDebuffs, profile.showBuffs = 2, 2
  profile.modernEnemyBuffs, profile.modernFriendlyDebuffs = { mode = "none" }, { mode = "none" }
  addon.SpellRules:Rebuild(profile)
  for _, friendly in ipairs({ false, true }) do
    local category = friendly and "friendlyBuffCategories" or "enemyDebuffCategories"
    local key = friendly and "defensive" or "crowdControl"
    local filter = friendly and "BIG_DEFENSIVE" or "CROWD_CONTROL"
    local original = addon.ModernRules:Build(profile, friendly)
    for _, group in ipairs(original) do
      assert(not group.filter:find("|!" .. filter, 1, true), "new category defaults preserve visibility")
    end
    profile[category][key] = false
    local updated = addon.ModernRules:Build(profile, friendly)
    local listed, unlisted = false, false
    for _, group in ipairs(updated) do
      if group.candidates.includeSpellIDs then
        assert(not group.filter:find("|!" .. filter, 1, true), "listed spell bypasses category exclusion")
        assert(group.candidates.includeSpellIDs[118])
        listed = true
      else
        assert(group.filter:find("|!" .. filter, 1, true), "unlisted auras use the category exclusion")
        assert(group.candidates.excludeSpellIDs[118])
        unlisted = true
      end
    end
    assert(listed and unlisted)
  end
  print("Listed spells bypass category exclusions:", interface)
end
