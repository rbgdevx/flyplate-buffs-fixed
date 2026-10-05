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
        myScale = 0.45,
        baseWidth = 31,
        unknown = { keep = true },
        Spells = { [970] = { name = "Shadow Word: Pain", spellID = 970, show = 2, scale = 1.7, checkID = true } },
        ignoredDefaultSpells = { [118] = true },
      },
    },
  })
  H.equal(ns.Database:GetCurrentProfile(), "Raid", "profile on " .. interface)
  H.equal(ns.db.profile.myScale, 0.45)
  H.equal(ns.db.profile.Spells[970].scale, 1.7)
  H.equal(ns.db.profile.Spells[970].checkID, true)
  H.equal(ns.db.profile.unknown.keep, true)
  H.equal(ns.db.profile.ignoredDefaultSpells[118], true)
  H.equal(ns.db.profile.enabled, true)
  H.equal(ns.db.profile.targetOnly, false)
  H.equal(ns.db.profile.tooltipInCombat, true)
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
