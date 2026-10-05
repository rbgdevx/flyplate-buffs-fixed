local H = dofile("tests/helpers.lua")

for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local state = H.environment(interface, {
    version = 2,
    profileKeys = { ["Tester - Realm"] = "Raid", ["Friend - Realm"] = "Spare" },
    profiles = {
      Raid = {
        showDuration = false,
        myScale = 0.65,
        colorTypes = { Magic = { 0.1, 0.2, 0.3 } },
        Spells = { [970] = { show = 2, spellID = 970, name = "Shadow Word: Pain", scale = 1.7, checkID = true } },
        ignoredDefaultSpells = { [118] = true },
        unknown = { nested = "keep" },
      },
      Spare = { baseWidth = 42, Spells = { Other = { name = "Other", show = 4 } } },
    },
    global = { legacy = "untouched" },
  })
  H.loadAddon(state)
  local ns, database = state.ns, state.ns.Database
  assert(not state.env.LibStub("AceDB-3.0", true))
  assert(not state.env.LibStub("AceDBOptions-3.0", true))
  local function options()
    local args = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0").args.profiles.args
    local fields = {}
    for _, key in ipairs({ "choose", "new", "copy", "reset", "delete" }) do
      fields[key] = args[key .. "Row"].args[key]
    end
    return fields
  end
  local controls = options()
  H.equal(controls.choose.get(), "Raid")
  assert(controls.choose.values.Spare and not controls.copy.values.Raid)
  assert(not controls.delete.values.Raid)
  H.equal(controls.copy.disabled, nil, "copy inherits the window restriction")
  H.equal(controls.delete.disabled, nil, "delete inherits the window restriction")
  assert(controls.new.validate(nil, "New") == true)
  assert(controls.new.validate(nil, "   ") ~= true)
  assert(controls.new.validate(nil, string.rep("x", 51)) ~= true)
  assert(not database:SetProfile(""))
  assert(not database:DeleteProfile("Raid"))
  assert(not database:CopyProfile("missing"))

  ns.Options.selectedSpell = 970
  controls.new.set(nil, "New")
  H.equal(database:GetCurrentProfile(), "New")
  H.equal(ns.Options.selectedSpell, nil, "profile change clears previous spell editor")
  H.equal(ns.db.profile.myScale, 0.2)
  controls = options()
  controls.copy.set(nil, "Raid")
  H.equal(ns.db.profile.myScale, 0.65)
  H.equal(ns.db.profile.showDuration, false)
  H.equal(ns.db.profile.colorTypes.Magic[1], 0.1)
  H.equal(ns.db.profile.Spells[970].checkID, true)
  H.equal(ns.db.profile.ignoredDefaultSpells[118], true)
  ns.db.profile.Spells[970].scale = 2.1
  H.equal(ns.db.sv.profiles.Raid.Spells[970].scale, 1.7, "copy must not alias source")
  assert(ns.Settings.ready, "profile callback updates the runtime")

  local event = state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  event(nil, "PLAYER_LOGOUT")
  local saved = H.copy(state.env.flyPlateBuffsFixedDB)
  H.equal(saved.profiles.New.baseWidth, nil, "unchanged defaults stay sparse")
  H.equal(saved.profiles.New.showDuration, false, "explicit false survives save")
  H.equal(saved.profiles.New.unknown.nested, "keep")
  H.equal(saved.global.legacy, "untouched")
  local restored = H.environment(interface, saved)
  H.loadAddon(restored)
  ns, database, state = restored.ns, restored.ns.Database, restored
  H.equal(database:GetCurrentProfile(), "New", "active profile survives reload")
  H.equal(ns.db.profile.baseWidth, 24)
  H.equal(ns.db.profile.Spells[970].scale, 2.1)
  H.equal(ns.db.profile.colorTypes.Magic[3], 0.3)
  H.equal(ns.SpellRules:Exact()[118], nil, "deleted default does not reappear after reload")
  H.equal(ns.db.profile.ignoredDefaultSpells[118], true)
  assert(database:DeleteProfile("Spare"))
  H.equal(ns.db.sv.profileKeys["Friend - Realm"], nil)
  H.equal(ns.db.sv.profiles.Spare, nil)
  H.equal(options().reset.confirm, true, "AceConfig confirmation uses the boolean form")
  H.equal(options().delete.confirm, true)
  assert(type(options().reset.confirmText) == "string" and type(options().delete.confirmText) == "string")
  options().reset.func()
  H.equal(ns.db.profile.myScale, 0.2)
  H.equal(ns.db.profile.unknown, nil)
  assert(next(ns.db.profile.ignoredDefaultSpells) == nil)
  H.equal(ns.db.sv.profiles.Raid.unknown.nested, "keep", "reset affects only active profile")
  print("Owned profiles, UI actions and save/reload compatibility:", interface)
end

local state = H.environment(16001, {
  version = 2,
  profileKeys = { ["Tester"] = "Surname-free" },
  profiles = { ["Surname-free"] = { baseWidth = 38 } },
})
state.env.UnitNameUnmodified = function()
  return "Tester"
end
state.env.strlenutf8 = utf8.len
H.loadAddon(state)
H.equal(state.ns.Database:GetCurrentProfile(), "Surname-free")
assert(state.ns.Database:IsValidProfileName(string.rep(utf8.char(233), 50)))
assert(not state.ns.Database:IsValidProfileName(string.rep(utf8.char(233), 51)))
print("Regional name without surname and Unicode profile names passed")
