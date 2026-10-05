local H = dofile("tests/helpers.lua")
local function create()
  local state = H.environment(16001)
  for _, key in ipairs({
    "nameplateEnemyNpcAuraDisplay",
    "nameplateEnemyPlayerAuraDisplay",
    "nameplateFriendlyPlayerAuraDisplay",
    "nameplateShowDebuffsOnFriendly",
  }) do
    state.cvars[key] = "1"
  end
  state.cvars.nameplateOtherTopInset = ".1"
  state.cvars.nameplateOtherBottomInset = ".1"
  state.cvars.countdownForCooldowns = "0"
  H.loadAddon(state)
  return state, state.ns
end
local state, ns = create()
local first = ns.db.profile
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "0", "hide native icons on first run")
H.equal(first.blizzardAuras.nameplateEnemyNpcAuraDisplay, "1", "retain original value")
first.disableFriendlyDebuffs = false
ns.Blizzard:Apply(first)
H.equal(state.cvars.nameplateShowDebuffsOnFriendly, "0", "hide all wins over explicit show friendly")
ns.Database:SetProfile("Second")
H.equal(ns.db.profile.blizzardAuras.nameplateEnemyNpcAuraDisplay, "1", "new profile saves real pre-hide state")
ns.Blizzard:RestoreAuras(ns.db.profile)
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "1", "restore after profile switch")
ns.Blizzard:Apply(ns.db.profile)
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "1", "restore remains in force")
ns.Database:SetProfile("Default")
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "0")
ns.db.profile.disableFriendlyDebuffs = true
ns.Blizzard:RestoreAuras(ns.db.profile)
H.equal(state.cvars.nameplateShowDebuffsOnFriendly, "0", "explicit friendly hide survives overall restore")
ns.db.profile.nameplateInset = true
ns.db.profile.blizzardCountdown = true
ns.Blizzard:Apply(ns.db.profile)
H.equal(state.cvars.nameplateOtherTopInset, "-1")
H.equal(state.cvars.countdownForCooldowns, "1")
ns.db.profile.nameplateInset = false
ns.db.profile.blizzardCountdown = false
ns.Blizzard:Apply(ns.db.profile)
H.equal(state.cvars.nameplateOtherTopInset, "1")
H.equal(state.cvars.countdownForCooldowns, "0")
state.combat = true
ns.db.profile.blizzardCountdown = true
ns.Blizzard:Apply(ns.db.profile)
H.equal(state.cvars.countdownForCooldowns, "0", "do not change protected CVars in combat")
state.combat = false
state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED")
H.equal(state.cvars.countdownForCooldowns, "1", "deferred CVar change applies when combat ends")
for _, operation in ipairs({ "reset", "copy" }) do
  local current, addon = create()
  if operation == "reset" then
    addon.Database:ResetProfile()
  else
    addon.db.sv.profiles.Source = { iconSize = 31 }
    addon.Database:CopyProfile("Source")
  end
  H.equal(addon.db.profile.blizzardAuras.nameplateEnemyNpcAuraDisplay, "1", operation .. " keeps original baseline")
  addon.Blizzard:RestoreAuras(addon.db.profile)
  H.equal(current.cvars.nameplateEnemyNpcAuraDisplay, "1", operation .. " restores original native visibility")
end
print("Native icon visibility, profile switching, restore precedence and combat deferral passed")

for _, interface in ipairs({ 11509, 20506, 50504 }) do
  local current = H.environment(interface)
  H.loadAddon(current)
  local addon = current.ns
  local options = current.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
  options.set({ "blizzard", "fixNames" }, true)
  local hook = current.hooks.CompactUnitFrame_UpdateName
  local name = {
    shown = false,
    SetText = function(self, text)
      self.text = text
    end,
    Show = function(self)
      self.shown = true
    end,
    IsShown = function(self)
      return self.shown
    end,
    SetVertexColor = function(self, r, g, b)
      self.color = { r, g, b }
    end,
  }
  local frame = {
    unit = "nameplate1",
    displayedUnit = "nameplate1",
    name = name,
    IsForbidden = function()
      return false
    end,
    optionTable = { colorNameBySelection = true },
  }
  current.tapDenied = true
  hook(frame)
  H.equal(name.color[1], 0.5)
  assert(name.shown)
  current.tapDenied = false
  name.shown = false
  hook(frame)
  H.equal(name.color[2], 1)
  current.threat = true
  name.shown = false
  frame.optionTable.considerSelectionInCombatAsHostile = true
  hook(frame)
  H.equal(name.color[1], 1)
  H.equal(name.color[2], 0)
  current.combat = true
  name.shown = false
  hook(frame)
  assert(name.shown, "Classic name repair remains active during combat")
  addon.db.profile.fixNames = false
  name.shown = false
  hook(frame)
  assert(not name.shown)
end
print("Classic missing-name repair retains selection and tap colors")
