local H = dofile("tests/helpers.lua")
local function create(interface, saved, secret)
  local state = H.environment(interface or 16001, saved)
  state.secret = secret or false
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
  state.cvars.nameplateMaxDistance = "45"
  state.cvars.countdownForCooldowns = "0"
  H.loadAddon(state)
  return state, state.ns
end
for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local fresh = H.environment(interface)
  local original = {
    nameplateEnemyNpcAuraDisplay = "2",
    nameplateEnemyPlayerAuraDisplay = "0",
    nameplateFriendlyPlayerAuraDisplay = "1",
    nameplateShowDebuffsOnFriendly = "1",
    nameplateOtherTopInset = ".15",
    nameplateOtherBottomInset = ".2",
    nameplateMaxDistance = "55",
    countdownForCooldowns = "0",
  }
  fresh.cvars = H.copy(original)
  local writes = 0
  local setCVar = fresh.env.C_CVar.SetCVar
  fresh.env.C_CVar.SetCVar = function(key, value)
    writes = writes + 1
    setCVar(key, value)
  end
  H.loadAddon(fresh)
  fresh.ns.Database:SetProfile("New")
  fresh.ns.Database:ResetProfile()
  fresh.frames.flyPlateBuffsFixedFrame.scripts.OnEvent(nil, "PLAYER_ENTERING_WORLD")
  H.equal(writes, 0, "fresh profiles never write CVars")
  for key, value in pairs(original) do
    H.equal(fresh.cvars[key], value, "preserve current " .. key)
  end
end
local state, ns = create()
local first = ns.db.profile
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "1", "native icon hiding is opt-in")
ns.Blizzard:HideAuras(first)
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "0", "explicitly hide native icons")
H.equal(first.blizzardAuras.nameplateEnemyNpcAuraDisplay, "1", "retain original value")
first.enabled = false
ns.Options:Changed()
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "1", "disabling restores native icons")
H.equal(first.hideBlizzardAuras, true, "disabling preserves the visibility preference")
ns.Blizzard:Apply(first)
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "1", "native icons stay restored while disabled")
first.enabled = true
ns.Options:Changed()
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "0", "reenabling reapplies native visibility")
H.equal(first.blizzardAuras.nameplateEnemyNpcAuraDisplay, "1", "reenabling keeps the original baseline")
first.disableFriendlyDebuffs = false
ns.Blizzard:Apply(first)
H.equal(state.cvars.nameplateShowDebuffsOnFriendly, "0", "hide all wins over explicit show friendly")
ns.Database:SetProfile("Second")
H.equal(state.cvars.nameplateEnemyNpcAuraDisplay, "1", "new profiles have no native hiding preference")
assert(ns.db.profile.blizzardAuras == nil)
ns.Blizzard:HideAuras(ns.db.profile)
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
  addon.Blizzard:HideAuras(addon.db.profile)
  if operation == "reset" then
    addon.Database:ResetProfile()
  else
    addon.db.sv.profiles.Source = { iconSize = 31 }
    addon.Database:CopyProfile("Source")
  end
  assert(addon.db.profile.blizzardAuras == nil, operation .. " does not opt into native hiding")
  H.equal(current.cvars.nameplateEnemyNpcAuraDisplay, "1", operation .. " restores the previous profile's hide action")
  addon.Blizzard:RestoreAuras(addon.db.profile)
  H.equal(current.cvars.nameplateEnemyNpcAuraDisplay, "1", operation .. " restores original native visibility")
end
for _, interface in ipairs({ 120100, 16001 }) do
  local restricted, addon =
    create(interface, { version = 2, profiles = { Default = { hideBlizzardAuras = true } } }, true)
  local event = restricted.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  assert(addon.Settings.pending and not addon.Settings.ready)
  H.equal(restricted.cvars.nameplateEnemyNpcAuraDisplay, "1", "keep native auras while initialization is deferred")
  assert(addon.db.profile.blizzardAuras == nil, "deferred hiding does not capture a baseline yet")
  restricted:addPlate("nameplate1")
  event(nil, "PLAYER_REGEN_ENABLED")
  H.equal(restricted.cvars.nameplateEnemyNpcAuraDisplay, "1", "combat end alone does not hide native auras")
  restricted.secret = false
  event(
    nil,
    "ADDON_RESTRICTION_STATE_CHANGED",
    restricted.env.Enum.AddOnRestrictionType.PvPMatch,
    restricted.env.Enum.AddOnRestrictionState.Inactive
  )
  assert(addon.Settings.ready and not addon.Settings.pending)
  H.equal(restricted.cvars.nameplateEnemyNpcAuraDisplay, "0", "apply the chosen hide preference after recovery")
  H.equal(addon.db.profile.blizzardAuras.nameplateEnemyNpcAuraDisplay, "1", "capture the original native visibility")
  local beforeLogout = H.copy(restricted.cvars)
  event(nil, "PLAYER_LOGOUT")
  for key, value in pairs(beforeLogout) do
    H.equal(restricted.cvars[key], value, "logout preserves chosen " .. key)
  end
  H.equal(addon.db.sv.profiles.Default.hideBlizzardAuras, true, "persist the explicit hide choice")
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
