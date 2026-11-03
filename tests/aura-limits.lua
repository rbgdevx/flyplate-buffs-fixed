-- Isolated settings, persistence and native-call fixtures; no rendered UI or FPS emulation.
local H = dofile("tests/helpers.lua")

local sections = {
  { name = "enemyDebuffs", key = "enemyDebuffLimit", dropdown = "showDebuffs", default = 6, value = 1 },
  { name = "enemyBuffs", key = "enemyBuffLimit", dropdown = "mode", default = 4, value = 10 },
  { name = "friendlyDebuffs", key = "friendlyDebuffLimit", dropdown = "mode", default = 6, value = 3 },
  { name = "friendlyBuffs", key = "friendlyBuffLimit", dropdown = "showBuffs", default = 4, value = 8 },
}

local function buildOptions(state)
  local options = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
  state.registry:ValidateOptionsTable(options, "FPB")
  return options
end

local function checkControls(state, options)
  local ns = state.ns
  local display = options.args.display.args
  for _, section in ipairs(sections) do
    if ns.Client.modern then
      local row = display[section.name].args.show
      local range = row.args[section.key]
      H.equal(range.type, "range")
      H.equal(range.name, "Maximum icons per group")
      H.equal(range.min, 1)
      H.equal(range.max, 10)
      H.equal(range.step, 1)
      H.equal(row.args[section.dropdown].width, "double")
      assert(range.order > row.args[section.dropdown].order, "the limit follows Show inside the same row")
      assert(range.desc:find("Multiple groups", 1, true), "the tooltip distinguishes per-group and total counts")
      H.equal(range.disabled, nil, "inherited aura visibility does not disable a section's own limit")
      local path = { "display", section.name, "show", section.key }
      H.equal(options.get(path), section.default)
      options.set(path, section.value)
      H.equal(options.get(path), section.value)
      H.equal(ns.db.profile[section.key], section.value)
    else
      H.equal(display[section.name], nil, "Classic does not expose the new native-group controls")
    end
  end
end

local function checkRecipe(groups, debuffs, buffs)
  local harmful, helpful = false, false
  for _, group in ipairs(groups) do
    if group.filter:sub(1, 7) == "HELPFUL" then
      H.equal(group.maxFrameCount, buffs)
      helpful = true
    else
      H.equal(group.maxFrameCount, debuffs)
      harmful = true
    end
  end
  assert(harmful and helpful, "both aura types participate in the fixture")
end

local function checkRecipes(ns)
  local profile = ns.db.profile
  profile.showDebuffs, profile.showBuffs = 1, 1
  profile.modernEnemyBuffs = { mode = "inherit" }
  profile.modernFriendlyDebuffs = { mode = "inherit" }
  profile.Spells = {
    [118] = { spellID = 118, show = 1, scale = 1.5 },
    [589] = { spellID = 589, show = 1, scale = 2 },
  }
  ns.SpellRules:Rebuild(profile)
  checkRecipe(ns.ModernRules:Build(profile, false), 1, 10)
  checkRecipe(ns.ModernRules:Build(profile, true), 3, 8)
  H.equal(profile.modernEnemyBuffs.mode, "inherit", "limits do not replace visibility inheritance")
  H.equal(profile.modernFriendlyDebuffs.mode, "inherit")
end

local function activeContainer(state, unit)
  for _, frame in ipairs(state.created) do
    if frame.unit == unit and frame.enabled then
      return frame
    end
  end
  error("Missing active fixture container for " .. unit)
end

local function checkContainer(frame, debuffs, buffs)
  local harmful, helpful = false, false
  for _, group in pairs(frame.groups) do
    if group.enabled and group.options.maxFrameCount > 0 then
      if group.filter:sub(1, 7) == "HELPFUL" then
        H.equal(group.options.maxFrameCount, buffs)
        helpful = true
      else
        H.equal(group.options.maxFrameCount, debuffs)
        harmful = true
      end
    end
  end
  assert(harmful and helpful)
end

local function checkRuntime(state, options)
  local ns = state.ns
  state:addPlate("nameplate1")
  state:addPlate("friendly")
  ns.Settings:Apply()
  local enemy, friendly = activeContainer(state, "nameplate1"), activeContainer(state, "friendly")
  checkContainer(enemy, 1, 10)
  checkContainer(friendly, 3, 8)

  local allocated = #state.created
  local restyles, apply = 0, ns.Style.Apply
  ns.Style.Apply = function(...)
    restyles = restyles + 1
    return apply(...)
  end
  for _, section in ipairs(sections) do
    local path = { "display", section.name, "show", section.key }
    for _, value in ipairs({ 1, 10 }) do
      options.set(path, value)
      checkContainer(enemy, ns.db.profile.enemyDebuffLimit, ns.db.profile.enemyBuffLimit)
      checkContainer(friendly, ns.db.profile.friendlyDebuffLimit, ns.db.profile.friendlyBuffLimit)
    end
    options.set(path, section.value)
  end
  H.equal(#state.created, allocated, "changing a cap reuses existing containers and fixture frames")
  H.equal(restyles, 0, "cap-only changes do not restyle native buttons")
  ns.Style.Apply = apply
  checkContainer(enemy, 1, 10)
  checkContainer(friendly, 3, 8)

  state.combat = true
  assert(options.disabled(), "the sliders inherit the existing restricted-settings boundary")
  state.combat = false
end

local function checkProfiles(state, interface)
  local ns = state.ns
  ns.Database:SetProfile("Limits fixture")
  for _, section in ipairs(sections) do
    H.equal(ns.db.profile[section.key], section.default, "new profiles get the performance defaults")
  end
  ns.Database:CopyProfile("Default")
  ns.Database:Save()
  local saved = H.copy(state.env.flyPlateBuffsFixedDB)
  for _, section in ipairs(sections) do
    H.equal(saved.profiles["Limits fixture"][section.key], section.value, "custom limits survive sparse save")
    H.equal(saved.profiles.Default[section.key], section.value, "copy preserves the source profile")
  end

  local restored = H.environment(interface, saved)
  H.loadAddon(restored)
  ns = restored.ns
  H.equal(ns.Database:GetCurrentProfile(), "Limits fixture")
  for _, section in ipairs(sections) do
    H.equal(ns.db.profile[section.key], section.value, "each limit survives reload")
  end
  ns.Database:ResetProfile()
  for _, section in ipairs(sections) do
    H.equal(ns.db.profile[section.key], section.default, "reset restores the approved defaults")
    H.equal(ns.db.sv.profiles.Default[section.key], section.value, "reset preserves the other profile")
  end
  ns.Database:Save()
  for _, section in ipairs(sections) do
    H.equal(ns.db.sv.profiles["Limits fixture"][section.key], nil, "default limits remain sparse")
  end
end

for _, interface in ipairs({ 11509, 20506, 50504, 120105, 16001 }) do
  local state = H.environment(interface)
  H.loadAddon(state)
  local options = buildOptions(state)
  checkControls(state, options)
  if state.ns.Client.modern then
    checkRecipes(state.ns)
    checkRuntime(state, options)
    checkProfiles(state, interface)
  end
  print("Per-section aura limits, existing controls and profile persistence:", interface)
end
