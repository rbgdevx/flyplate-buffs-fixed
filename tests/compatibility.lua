local H = dofile("tests/helpers.lua")
local function boot(interface, saved)
  local state = H.environment(interface, saved)
  H.loadAddon(state)
  return state, state.ns
end

for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local state, ns = boot(interface, {
    version = 2,
    profileKeys = { ["Tester - Realm"] = "Raid" },
    profiles = {
      Raid = {
        enabled = false,
        tooltipInCombat = false,
        modernMaxPerGroup = 3,
        modernSortMethod = "NameOnly",
        modernGroupOrder = "listed",
        buffAnchorPoint = "TOP",
        plateAnchorPoint = "LEFT",
        myScale = 0.45,
        baseWidth = 31,
        unknown = { keep = true },
        Spells = { [970] = { name = "Shadow Word: Pain", spellID = 970, show = 2, scale = 1.7, checkID = true } },
        ignoredDefaultSpells = { [118] = true },
      },
      Inactive = { enabled = false, tooltipInCombat = false },
    },
  })
  H.equal(ns.Database:GetCurrentProfile(), "Raid", "profile on " .. interface)
  H.equal(ns.db.profile.myScale, 0.45)
  H.equal(ns.db.profile.Spells[970].scale, 1.7)
  H.equal(ns.db.profile.Spells[970].checkID, true)
  H.equal(ns.db.profile.unknown.keep, true)
  H.equal(ns.db.profile.ignoredDefaultSpells[118], true)
  H.equal(ns.db.profile.enabled, nil)
  H.equal(ns.db.profile.tooltipInCombat, false, "preserve the approved combat-tooltip choice")
  H.equal(ns.db.profile.modernMaxPerGroup, nil)
  H.equal(ns.db.profile.modernSortMethod, "NameOnly", "preserve the approved sorting choice")
  H.equal(ns.db.profile.modernGroupOrder, "listed", "preserve the approved group order")
  H.equal(ns.db.profile.buffAnchorPoint, "TOP", "preserve the approved aura anchor")
  H.equal(ns.db.profile.plateAnchorPoint, "LEFT", "preserve the approved nameplate anchor")
  H.equal(ns.db.sv.profiles.Inactive.enabled, nil, "remove the retired control from inactive profiles")
  H.equal(ns.db.sv.profiles.Inactive.tooltipInCombat, false)
  H.equal(ns.db.profile.targetOnly, false)
  H.equal(ns.db.profile.enemyDebuffCategories.crowdControl, true)
  ns.db.profile.enemyDebuffCategories.crowdControl = false
  ns.db.profile.friendlyBuffCategories.defensive = false
  ns.Database:Save()
  local _, reloaded = boot(interface, ns.db.sv)
  H.equal(reloaded.db.profile.enemyDebuffCategories.crowdControl, false)
  H.equal(reloaded.db.profile.friendlyBuffCategories.defensive, false)
  H.equal(reloaded.db.profile.Spells[970].scale, 1.7)
  state.registry:GetOptionsTable("flyPlateBuffsFixed", "dialog", "Test-1.0")
  local options = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
  assert(options.args.display and options.args.style and options.args.profiles)
  ns.Options.selectedSpell = 970
  state.registry:ValidateOptionsTable(state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0"), "FPB")
  local id, err = ns.SpellRules:Add(ns.db.profile, "Shadow Word: Pain")
  H.equal(id, 589, err)
  H.equal(ns.db.profile.Spells[id].scale, 1)
  ns.SpellRules:Remove(ns.db.profile, 118)
  H.equal(ns.db.profile.ignoredDefaultSpells[118], true)
  ns.SpellRules:Add(ns.db.profile, "118")
  H.equal(ns.db.profile.ignoredDefaultSpells[118], nil)
  ns.SpellRules:Remove(ns.db.profile, 589)
  H.equal(ns.db.profile.Spells[589], nil)
  local previous = ns.db.profile.Spells[970]
  local replaced = ns.SpellRules:Replace(ns.db.profile, 970, "594")
  H.equal(replaced, 594)
  H.equal(ns.db.profile.Spells[594].scale, previous.scale)
  ns.Database:SetProfile("Other")
  ns.Database:CopyProfile("Raid")
  H.equal(ns.db.profile.myScale, 0.45)
  ns.Database:ResetProfile()
  H.equal(ns.db.profile.myScale, 0.2)
  assert(next(ns.db.profile.ignoredDefaultSpells) == nil)
  print("Profile and AceConfig compatibility:", interface)
end

local state, ns = boot(16001, {
  version = 2,
  profileKeys = { ["Tester - Realm"] = "Old", ["Tester Surname"] = "Default" },
  profiles = { Old = { baseWidth = 37 }, Default = { baseWidth = 29 } },
})
H.equal(ns.Database:GetCurrentProfile(), "Default", "preserve explicit new profile association")
H.equal(ns.db.profile.baseWidth, 29)
local _, migrated = boot(11509, {
  profiles = {
    Default = {
      Spells = {
        [589] = { show = 3, spellID = 589 },
        ["Shadow Word: Pain"] = { show = 1, spellID = 589, custom = true },
        Unknown = { name = "Unknown", show = 4 },
      },
      ignoredDefaultSpells = { Unknown = true, [118] = true },
    },
  },
})
H.equal(migrated.db.profile.Spells[589].show, 3)
H.equal(migrated.db.profile.Spells["Shadow Word: Pain"].custom, true, "preserve colliding user rule")
H.equal(migrated.db.profile.Spells.Unknown.show, 4)
H.equal(migrated.db.profile.ignoredDefaultSpells.Unknown, true)
H.equal(migrated.db.profile.ignoredDefaultSpells[118], true)
H.equal(migrated.db.sv.version, 2)
print("Legacy migration, collisions and Forever profile identity passed")

for _, interface in ipairs({ 120100, 16001 }) do
  local name = "Shadow Word: Pain"
  local _, addon = boot(interface, {
    version = 2,
    profiles = {
      Default = {
        Spells = {
          [name] = { name = name, show = 1, scale = 1.7, checkID = false },
          Unknown = { name = "Unresolved legacy spell", show = 1, checkID = false },
        },
      },
    },
  })
  local profile = addon.db.profile
  local rule = profile.Spells[name]
  H.equal(addon.SpellRules:Exact()[589], rule, "resolve a version-2 name-only rule at runtime")
  if addon.Client.forever then
    H.equal(addon.SpellRules:Exact()[594], rule, "resolved name-only rules retain rank matching")
  end
  local included = false
  for _, group in ipairs(addon.ModernRules:Build(profile, false)) do
    if group.candidates.includeSpellIDs and group.candidates.includeSpellIDs[589] then
      included = true
    end
  end
  assert(included, "native containers receive the resolved legacy spell ID")
  profile.Spells[589] = { spellID = 589, name = name, show = 3, checkID = true }
  addon.SpellRules:Rebuild(profile)
  H.equal(addon.SpellRules:Exact()[589], profile.Spells[589], "explicit numeric rules retain precedence")
  profile.Spells[589] = nil
  rule.checkID = true
  addon.SpellRules:Rebuild(profile)
  H.equal(addon.SpellRules:Exact()[589], nil, "do not resolve rules that forbid name matching")
  rule.checkID = false
  profile.ignoredDefaultSpells[name] = true
  addon.SpellRules:Rebuild(profile)
  H.equal(addon.SpellRules:Exact()[589], nil, "ignored legacy name rules stay ignored")
  profile.ignoredDefaultSpells[name] = nil
  addon.Database:Save()
  H.equal(addon.db.sv.version, 2, "runtime matching needs no schema migration")
  H.equal(profile.Spells[name].spellID, nil, "preserve name-only storage")
  H.equal(profile.Spells[589], nil, "do not persist a numeric replacement")
  H.equal(profile.Spells.Unknown.name, "Unresolved legacy spell", "preserve unresolved entries")
  local _, reloaded = boot(interface, addon.db.sv)
  H.equal(reloaded.SpellRules:Exact()[589], reloaded.db.profile.Spells[name], "name alias survives reload")
end
print("Modern legacy name-only aliases, precedence and unchanged persistence passed")
