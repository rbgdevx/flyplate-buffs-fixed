-- Source-level work and lifecycle checks. Native rendering and FPS are not emulated.
local H = dofile("tests/helpers.lua")

local function aura(id, helpful)
  return {
    auraInstanceID = id,
    spellId = 10000 + id,
    name = "Fixture aura " .. id,
    icon = id,
    isHelpful = helpful,
    isHarmful = not helpful,
    applications = 1,
    duration = 18,
    expirationTime = 118,
    sourceUnit = "player",
  }
end

local function stepColor(curve, x)
  local previous
  for point in pairs(curve.points) do
    if point <= x and (not previous or point > previous) then
      previous = point
    end
  end
  return curve.points[previous]
end

local function createClassicFixture(interface)
  local state = H.environment(interface)
  local counts = { sort = 0, layout = 0, apply = 0, cooldown = 0, font = 0, text = 0, clockReads = 0 }
  state.env.GetTime = function()
    counts.clockReads = counts.clockReads + 1
    return state.time
  end
  H.loadAddon(state)
  local ns, profile = state.ns, state.ns.db.profile
  profile.showDebuffs, profile.showBuffs, profile.hidePermanent, profile.showDecimals = 1, 5, false, false
  state:addPlate("nameplate1")
  for id = 1, 7 do
    state.auras.nameplate1[id] = aura(id, id == 7)
  end
  ns.Settings:Apply()
  local event = state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  local buttons = {}
  for _, object in ipairs(state.created) do
    if object.aura then
      buttons[#buttons + 1] = object
    end
  end
  H.equal(#buttons, 6)
  local methods = getmetatable(buttons[1]).__index
  for _, item in ipairs({
    { ns.ClassicRules, "Sort", "sort" },
    { ns.Layout, "Arrange", "layout" },
    { ns.Icons, "Apply", "apply" },
    { methods, "SetCooldown", "cooldown" },
    { methods, "SetFont", "font" },
    { methods, "SetText", "text" },
  }) do
    local object, key, counter = item[1], item[2], item[3]
    local original = object[key]
    object[key] = function(...)
      counts[counter] = counts[counter] + 1
      return original(...)
    end
  end
  return state, buttons, counts, event
end

local function checkClassicDeltas(state, buttons, counts, event)
  event(nil, "UNIT_AURA", "nameplate1", { updatedAuraInstanceIDs = { 7 } })
  state:tick(0)
  H.equal(counts.apply, 0, "filtered-out aura changes do not reapply shown icons")
  H.equal(counts.sort, 0)
  H.equal(counts.layout, 0)

  state.auras.nameplate1[1].applications = 2
  event(nil, "UNIT_AURA", "nameplate1", { updatedAuraInstanceIDs = { 1 } })
  H.equal(counts.apply, 0, "drawing waits for the display frame")
  state:tick(0)
  H.equal(counts.apply, 1, "only the changed icon is applied")
  H.equal(buttons[1].Stacks:GetText(), 2)
  H.equal(counts.cooldown, 0, "unchanged cooldowns are not reset")
  H.equal(counts.font, 0)
  H.equal(counts.sort, 0)
  H.equal(counts.layout, 0)

  for key in pairs(counts) do
    counts[key] = 0
  end
  for id = 1, 3 do
    state.auras.nameplate1[id].applications = id + 2
    event(nil, "UNIT_AURA", "nameplate1", { updatedAuraInstanceIDs = { id } })
  end
  H.equal(counts.apply, 0)
  state:tick(0)
  H.equal(counts.apply, 3, "all deltas survive the consolidated draw")
  H.equal(counts.sort, 0)
  H.equal(counts.layout, 0)
  H.equal(counts.cooldown, 0)

  state.auras.nameplate1[6].expirationTime = 105
  event(nil, "UNIT_AURA", "nameplate1", { updatedAuraInstanceIDs = { 6 } })
  state:tick(0)
  H.equal(counts.sort, 1, "changed sort inputs reorder the list")
  H.equal(buttons[1].aura.auraInstanceID, 6)
  H.equal(counts.layout, 0, "equal-size reordered content needs no new anchors")
  assert(counts.cooldown > 0, "reassigned cooldowns receive the new aura timing")
end

local function checkClassicTimers(state, buttons, counts)
  counts.text = 0
  counts.clockReads = 0
  state:tick(0.05)
  H.equal(counts.clockReads, 1, "active countdowns share one clock read")
  H.equal(counts.text, 0, "unchanged rounded text is not written")
  for _, button in ipairs(buttons) do
    assert(not button.scripts.OnUpdate, "icons have no individual frame tick")
  end
end

local function checkClassicRemoval(state, buttons, counts, event)
  event(nil, "UNIT_AURA", "nameplate1", { updatedAuraInstanceIDs = { 1 } })
  event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
  local applied = counts.apply
  state:tick(0.05)
  H.equal(counts.apply, applied, "removal cancels pending drawing")
  for _, button in ipairs(buttons) do
    assert(not button.aura and not button.durationUpdate)
  end
end

local function checkClassicEligibility(interface)
  local excluded = H.environment(interface)
  local reads = 0
  local original = excluded.env.C_UnitAuras.GetUnitAuras
  excluded.env.C_UnitAuras.GetUnitAuras = function(...)
    reads = reads + 1
    return original(...)
  end
  excluded.env.UnitIsUnit = function(a, b)
    return a == b or b == "target" and a == excluded.target
  end
  H.loadAddon(excluded)
  excluded.ns.db.profile.targetOnly = true
  excluded.ns.db.profile.showDebuffs = 1
  excluded.ns.Settings:Apply()
  excluded:addPlate("nameplate1")
  local dispatch = excluded.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  dispatch(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
  H.equal(reads, 0, "excluded plates do not fetch aura lists")
  excluded.auras.nameplate1[1] = aura(1, false)
  dispatch(nil, "UNIT_AURA", "nameplate1", { addedAuras = { excluded.auras.nameplate1[1] } })
  H.equal(reads, 0)
  excluded.target = "nameplate1"
  dispatch(nil, "PLAYER_TARGET_CHANGED")
  H.equal(reads, 2, "a newly eligible unit receives a fresh snapshot")
  local shown = false
  for _, object in ipairs(excluded.created) do
    shown = shown or object.aura and object.aura.auraInstanceID == 1
  end
  assert(shown)
  print("Classic incremental work, cancellation and timer ownership:", interface)
end

local function testClassicUpdates(interface)
  local state, buttons, counts, event = createClassicFixture(interface)
  checkClassicDeltas(state, buttons, counts, event)
  checkClassicTimers(state, buttons, counts)
  checkClassicRemoval(state, buttons, counts, event)
  checkClassicEligibility(interface)
end

local function checkBorderPalette(state, profile, resources)
  local harmful, helpful = resources.borders[1].customDispelColorCurve, resources.borders[2].customDispelColorCurve
  for id, kind in pairs({
    [0] = "None",
    "Magic",
    "Curse",
    "Disease",
    "Poison",
    "Stealth",
    "Invisibility",
    "All",
    "Special",
    "Enrage",
    "Unknown",
    "Bleed",
    "Unknown",
  }) do
    local supported = id <= 4 or id == 9
    local rgb = supported and (profile.style.colors[kind] or profile.style.colors.None)
      or state.env.AuraUtil.GetAuraBorderColor(kind)
    local buff = supported and profile.style.colors.Buff or state.env.AuraUtil.GetAuraBorderColor(kind)
    for channel = 1, 3 do
      H.equal(stepColor(harmful, id)[channel], rgb[channel], "harmful border palette parity")
      H.equal(stepColor(helpful, id)[channel], buff[channel], "helpful border palette parity")
    end
  end
  H.equal(resources.duration.textFormatter.breakpoints[2].threshold, 10)
end

local function checkGroupBorderBinding(state, profile, group, resources)
  local ns = state.ns
  local methods = getmetatable(state.env.UIParent).__index
  local add, clear = methods.AddDispelTypeTexture, methods.ClearDispelTypeTextures
  local bindings = {}
  methods.AddDispelTypeTexture = function(button, texture, options)
    bindings[button][#bindings[button] + 1] = { texture = texture, options = options }
  end
  methods.ClearDispelTypeTextures = function(button)
    bindings[button] = {}
  end
  local recipe = {
    { filter = "HELPFUL|PLAYER", candidates = {}, style = group, maxFrameCount = 4 },
    { filter = "HARMFUL|PLAYER", candidates = {}, style = group, maxFrameCount = 6 },
  }
  local container = ns.AuraContainer:Create(state.env.UIParent, profile, recipe, resources)
  H.equal(container.frame.groups["1"].options.maxFrameCount, 4, "new helpful groups use the buff limit")
  H.equal(container.frame.groups["2"].options.maxFrameCount, 6, "new harmful groups use the debuff limit")
  local buff = container.frame:GetAuraGroupFrame("1", 1)
  local debuff = container.frame:GetAuraGroupFrame("2", 1)
  H.equal(#bindings[buff], 1, "a buff-only group binds one native border")
  H.equal(#bindings[debuff], 1, "a debuff-only group binds one native border")
  H.equal(bindings[buff][1].options, resources.borders[2])
  H.equal(bindings[debuff][1].options, resources.borders[1])
  H.equal(bindings[buff][1].texture, buff.Border)
  H.equal(bindings[debuff][1].texture, debuff.Border)

  local swapped = { recipe[2], recipe[1] }
  ns.AuraContainer:ApplySettings(container, profile, swapped, recipe, resources)
  H.equal(container.frame.groups["1"].options.maxFrameCount, 6, "a group changed to harmful uses the debuff limit")
  H.equal(container.frame.groups["2"].options.maxFrameCount, 4, "a group changed to helpful uses the buff limit")
  H.equal(#bindings[buff], 1)
  H.equal(#bindings[debuff], 1)
  H.equal(bindings[buff][1].options, resources.borders[1], "changed filter updates its border without a style change")
  H.equal(bindings[debuff][1].options, resources.borders[2])

  local border = buff.Border
  local disabled = H.copy(profile)
  disabled.style.border = "none"
  ns.AuraContainer:ApplySettings(container, disabled, swapped, swapped, ns.StyleResources:Build(disabled.style))
  H.equal(#bindings[buff], 0)
  assert(not buff.Border:IsShown())
  ns.AuraContainer:ApplySettings(container, profile, swapped, swapped, resources)
  H.equal(buff.Border, border, "reenabling borders retains the existing texture")
  H.equal(#bindings[buff], 1)
  H.equal(bindings[buff][1].options, resources.borders[1])
  methods.AddDispelTypeTexture, methods.ClearDispelTypeTextures = add, clear
end

local function checkOptionalRegions(state, group)
  local ns = state.ns
  local saved = ns.db.profile
  saved.showDuration, saved.showStdSwipe, saved.showStdCooldown, saved.borderStyle = false, false, false, 3
  local minimal = ns.Appearance:Build(saved)
  local button = state.env.CreateFrame("Frame")
  ns.Style:Initialize(button, minimal, group, ns.StyleResources:Build(minimal.style), false)
  assert(
    not button.Duration and not button.Cooldown and not button.Border,
    "disabled optional regions are not constructed"
  )
  saved.showDuration, saved.showStdCooldown, saved.borderStyle = true, true, 1
  local enabled = ns.Appearance:Build(saved)
  ns.Style:Apply(button, enabled, group, ns.StyleResources:Build(enabled.style), false)
  assert(button.Duration and button.Cooldown and button.Border)
  local duration, cooldown, border = button.Duration, button.Cooldown, button.Border
  ns.Style:Apply(button, enabled, group, ns.StyleResources:Build(enabled.style), false)
  assert(button.Duration == duration and button.Cooldown == cooldown and button.Border == border)

  return button, enabled
end

local function checkStyleInvalidation(state, button, enabled, group)
  local ns = state.ns
  local writes = { font = 0, icon = 0, stacks = 0 }
  local methods = getmetatable(button).__index
  for key, counter in pairs({ SetFont = "font", SetIcon = "icon", SetApplicationCount = "stacks" }) do
    local method, name = key, counter
    local original = methods[method]
    methods[method] = function(...)
      writes[name] = writes[name] + 1
      return original(...)
    end
  end
  local container = ns.AuraContainer:Create(
    state.env.UIParent,
    enabled,
    { { filter = "HARMFUL", candidates = {}, style = group, maxFrameCount = 6 } },
    ns.StyleResources:Build(enabled.style)
  )
  writes.font, writes.icon, writes.stacks = 0, 0, 0
  local shifted = H.copy(enabled)
  shifted.position.x = shifted.position.x + 5
  local recipe = { { filter = "HARMFUL", candidates = {}, style = group, maxFrameCount = 6 } }
  local styleCalls, applyStyle = 0, ns.Style.Apply
  ns.Style.Apply = function(...)
    styleCalls = styleCalls + 1
    return applyStyle(...)
  end
  ns.AuraContainer:ApplySettings(container, shifted, recipe, recipe, ns.StyleResources:Build(shifted.style))
  H.equal(styleCalls, 0, "group ownership skips unchanged buttons entirely")
  H.equal(writes.font, 0, "anchor-only changes do not restyle fonts")
  H.equal(writes.icon, 0, "icon bindings remain attached")
  H.equal(writes.stacks, 0, "stack bindings remain attached")
  ns.AuraContainer:ApplySettings(container, shifted, recipe, recipe, ns.StyleResources:Build(shifted.style), true)
  assert(writes.font > 0, "media changes force a refresh with the same saved font name")
  H.equal(writes.icon, 0, "restyling retains fixed native bindings")
  ns.Style.Apply = applyStyle
end

local function checkContainerLifecycle(state, profile, group, resources)
  local ns = state.ns
  local recipe = { { filter = "HARMFUL", candidates = {}, style = group, maxFrameCount = 6 } }
  local container = ns.AuraContainer:Create(state.env.UIParent, profile, recipe, resources)
  local frame = container.frame
  assert(not frame:IsEnabled() and not frame:IsShown(), "unused displays start disabled and hidden")
  local groupWrites = state.groupEnableWrites or 0

  ns.AuraContainer:SetEnabled(container, true)
  state:tick(0)
  assert(frame:IsEnabled() and frame:IsShown(), "selected displays are enabled and shown")
  H.equal(frame.onUpdateMode, nil, "activation does not request a hidden cleanup update")

  ns.AuraContainer:SetEnabled(container, false)
  assert(not frame:IsEnabled() and not frame:IsShown(), "retired displays stay hidden")
  H.equal(frame.onUpdateMode, state.env.Enum.OnUpdateMode.RunOnce, "retirement requests one hidden native update")

  frame.onUpdateMode = nil
  ns.AuraContainer:SetEnabled(container, false)
  H.equal(frame.onUpdateMode, nil, "already inactive displays do not request another cleanup")

  ns.AuraContainer:SetEnabled(container, true)
  state:tick(0)
  assert(frame:IsEnabled() and frame:IsShown(), "retired displays can return")
  H.equal(state.groupEnableWrites or 0, groupWrites, "retirement and return leave aura groups configured")
end

local function checkRepeatedPlateRemoval(state, plate, enemy)
  local event = state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  local parents, anchors = 0, 0
  local methods = getmetatable(enemy.frame).__index
  local setParent, clearPoints = methods.SetParent, methods.ClearAllPoints
  methods.SetParent = function(...)
    parents = parents + 1
    return setParent(...)
  end
  methods.ClearAllPoints = function(...)
    anchors = anchors + 1
    return clearPoints(...)
  end
  local allocated = #state.created
  for _ = 1, 100 do
    event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(not enemy.frame.enabled and not enemy.frame:IsShown() and enemy.frame:GetParent() == plate)
    event(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    state:tick(0)
    assert(enemy.frame.enabled and enemy.frame:IsShown())
  end
  H.equal(parents, 0, "warm plate recycling never reparents native containers")
  H.equal(anchors, 0, "warm plate recycling never rebuilds native anchors")
  H.equal(#state.created, allocated, "warm plate recycling keeps all prepared regions")
  methods.SetParent, methods.ClearAllPoints = setParent, clearPoints
end

local function checkAssignedContainerReuse(state, plate)
  local ns = state.ns
  local event = state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  local assignments, assigned = 0, nil
  local acquire = ns.Reserve.Acquire
  ns.Reserve.Acquire = function(self, ...)
    assignments = assignments + 1
    assigned = acquire(self, ...)
    return assigned
  end
  event(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
  local enemy = assigned
  H.equal(assignments, 1)
  assert(enemy.frame.enabled and enemy.frame:GetParent() == plate)

  checkRepeatedPlateRemoval(state, plate, enemy)
  H.equal(assignments, 1, "plate recycling retains its assigned container")

  event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
  state.plates.nameplate1, state.plates.friendly, plate.unit = nil, plate, "friendly"
  event(nil, "NAME_PLATE_UNIT_ADDED", "friendly")
  state:tick(0)
  local friendly = assigned
  H.equal(assignments, 2, "a different role receives its own prepared container once")
  assert(friendly ~= enemy and friendly.frame.enabled and friendly.frame:IsShown())
  assert(not enemy.frame.enabled and not enemy.frame:IsShown())
  event(nil, "NAME_PLATE_UNIT_REMOVED", "friendly")
  assert(not friendly.frame.enabled and not friendly.frame:IsShown() and friendly.frame:GetParent() == plate)
  state.plates.friendly, state.plates.nameplate1, plate.unit = nil, plate, "nameplate1"
  event(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
  H.equal(assignments, 2, "returning to the previous role reuses its retained container")
  state:tick(0)
  assert(enemy.frame.enabled and enemy.frame:IsShown())
  assert(not friendly.frame.enabled and not friendly.frame:IsShown())
  ns.Reserve.Acquire = acquire
end

local function checkReserveLifecycle(state)
  local ns = state.ns
  state:tick(0)
  local plate = state:addPlate("nameplate1")
  local allocated = #state.created
  checkAssignedContainerReuse(state, plate)
  H.equal(#state.created, allocated, "first assignments consume prepared containers")
  for _ = 1, 42 do
    ns.Reserve:Acquire("enemy", plate)
  end
  assert(#state.created > allocated, "capacity is preparation, not a display cap")
  ns.Settings:Apply()
  state.combat = true
  local before = #state.created
  state:tick(0)
  H.equal(#state.created, before, "combat pauses reserve construction")
  ns.Settings:Apply(true)
  assert(ns.Settings.pending and ns.Settings.forceAppearance)
  state.combat = false
  state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED")
  assert(not ns.Settings.pending and not ns.Settings.forceAppearance, "deferred media refresh is preserved")
end

local function testMainlineResources(interface)
  local state = H.environment(interface)
  H.loadAddon(state)
  local ns = state.ns
  local profile = ns.Appearance:Build(ns.db.profile)
  local group = ns.Appearance:Spell(ns.db.profile, nil, false)
  local resources = ns.StyleResources:Build(profile.style)
  local formatterCount, curveCount = state.formatters, state.colorCurves
  for _ = 1, 20 do
    local button = state.env.CreateFrame("Frame")
    ns.Style:Initialize(button, profile, group, resources, false)
  end
  H.equal(state.formatters, formatterCount, "button creation shares formatters")
  H.equal(state.colorCurves, curveCount, "button creation shares curves")
  H.equal(ns.StyleResources:Build(profile.style).borders, resources.borders)
  checkContainerLifecycle(state, profile, group, resources)
  checkBorderPalette(state, profile, resources)
  checkGroupBorderBinding(state, profile, group, resources)
  local button, enabled = checkOptionalRegions(state, group)
  checkStyleInvalidation(state, button, enabled, group)
  checkReserveLifecycle(state)
  print("Native resources, optional regions and reserve lifecycle:", interface)
end

local function checkPreparationSlice(state)
  local prepared = 0
  for _, object in ipairs(state.created) do
    local count = 0
    for _ in pairs(object.groups) do
      count = count + 1
    end
    if count > 0 then
      H.equal(count, 1, "each preparation slice advances one group at the mocked budget")
      prepared = prepared + 1
    end
  end
  H.equal(prepared, 1)
end

local function checkScaleInvalidation(state)
  local ns = state.ns
  ns.Settings:Apply()
  state:tick(0)
  local plate = state:addPlate("nameplate1")
  local reserve = ns.Reserve:Acquire("enemy", plate)
  local methods = getmetatable(reserve.frame).__index
  local layouts, original = 0, methods.SetAuraGroupLayout
  methods.SetAuraGroupLayout = function(...)
    layouts = layouts + 1
    return original(...)
  end
  ns.db.profile.myScale = ns.db.profile.myScale + 0.1
  ns.Settings:Apply()
  assert(layouts > 0, "changed group dimensions invalidate native layout")
end

local function testPreparationLifecycle(interface)
  local state = H.environment(interface)
  local clock = 0
  state.env.GetTimePreciseSec = function()
    clock = clock + 0.004
    return clock
  end
  H.loadAddon(state)
  state:tick(0)
  checkPreparationSlice(state)
  checkScaleInvalidation(state)
  print("Native preparation slicing and scale invalidation:", interface)
end

for _, interface in ipairs({ 11509, 20506, 50504 }) do
  testClassicUpdates(interface)
end

for _, interface in ipairs({ 120105, 16001 }) do
  testMainlineResources(interface)
  testPreparationLifecycle(interface)
end
