local H = dofile("tests/helpers.lua")
for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local state = H.environment(interface)
  state.env.UnitIsUnit = function(a, b)
    return a == b or b == "target" and a == state.target
  end
  H.loadAddon(state)
  local ns = state.ns
  local profile = ns.db.profile
  assert(ns.Units:IsAllowed("nameplate1", profile))
  profile.enabled = false
  assert(not ns.Units:IsAllowed("nameplate1", profile))
  profile.enabled, profile.targetOnly = true, true
  assert(not ns.Units:IsAllowed("nameplate1", profile))
  state.target = "nameplate1"
  assert(ns.Units:IsAllowed("nameplate1", profile))
  assert(not ns.Units:IsAllowed("nameplate2", profile))
  profile.targetOnly = false
  local plate = state:addPlate("nameplate1")
  state.auras.nameplate1[1] = {
    auraInstanceID = 1,
    spellId = 589,
    name = "Shadow Word: Pain",
    icon = 1,
    isHelpful = false,
    isHarmful = true,
    applications = 2,
    duration = 18,
    expirationTime = 116,
    sourceUnit = "player",
  }
  local event = state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  local refreshes, refresh = 0, ns.Runtime.RefreshUnits
  ns.Runtime.RefreshUnits = function(self)
    refreshes = refreshes + 1
    return refresh(self)
  end
  event(nil, "PLAYER_TARGET_CHANGED")
  H.equal(refreshes, 0, "target changes do no work unless Target only is enabled")
  profile.targetOnly = true
  event(nil, "PLAYER_TARGET_CHANGED")
  H.equal(refreshes, 1)
  profile.targetOnly = false
  ns.Runtime.RefreshUnits = refresh
  event(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
  if ns.Client.modern then
    local active
    for _, frame in ipairs(state.created) do
      if frame.unit == "nameplate1" and frame.enabled then
        active = frame
      end
    end
    assert(active, "native container enabled")
    assert(not state.frames.flyPlateBuffsFixedFrame.scripts.UNIT_AURA)
    event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(not active.enabled)
    state.plates.nameplate1 = nil
    state.plates.friendly = plate
    plate.unit = "friendly"
    event(nil, "NAME_PLATE_UNIT_ADDED", "friendly")
    assert(not active.enabled, "previous hostile container stays disabled on recycled friendly plate")
    event(nil, "NAME_PLATE_UNIT_REMOVED", "friendly")
  else
    local button
    for _, frame in ipairs(state.created) do
      if frame.aura then
        button = frame
      end
    end
    assert(button and button.unit == "nameplate1")
    H.equal(button:GetWidth(), 24 * 1.2)
    profile.showTooltip, profile.tooltipInCombat = true, false
    ns.Settings:Apply()
    button.scripts.OnEnter(button)
    assert(state.env.GameTooltip:IsOwned(button) and state.env.GameTooltip:IsShown())
    state.combat = true
    event(nil, "PLAYER_REGEN_DISABLED")
    assert(not state.env.GameTooltip:IsShown(), "combat hides an already-open disallowed tooltip")
    button.scripts.OnEnter(button)
    assert(not state.env.GameTooltip:IsShown())
    state.combat = false
    event(nil, "PLAYER_REGEN_ENABLED")
    state.auras.nameplate1[1].applications = 4
    event(nil, "UNIT_AURA", "nameplate1", { updatedAuraInstanceIDs = { 1 } })
    H.equal(button.Stacks:GetText(), 4)
    state.auras.nameplate1[1] = nil
    event(nil, "UNIT_AURA", "nameplate1", { removedAuraInstanceIDs = { 1 } })
    assert(not button.visible and not button.scripts.OnUpdate)
    state.auras.nameplate1[2] = {
      auraInstanceID = 2,
      spellId = 589,
      name = "Shadow Word: Pain",
      icon = 1,
      isHelpful = false,
      applications = 1,
      duration = 18,
      expirationTime = 116,
      sourceUnit = "player",
    }
    event(nil, "UNIT_AURA", "nameplate1", { addedAuras = { state.auras.nameplate1[2] } })
    assert(button.visible and button.aura.auraInstanceID == 2)
    event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    assert(not button.visible and not button.aura and not button.unit)
  end
  ns.Preview:Toggle()
  ns.Preview:Refresh()
  ns.Preview:Toggle()
  local table = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
  table.args.spells.args.input.set(nil, "Shadow Word: Pain")
  assert(ns.Options.selectedSpell == 589)
  table = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
  table.args.spells.args["number:589"].args.remove.func({ "spells", "number:589", "remove", options = table })
  assert(ns.Options.selectedSpell == nil)
  -- Native recipe mutations wait until the real restriction boundary clears.
  if ns.Client.modern then
    state.combat = true
    ns.Settings:Apply()
    assert(ns.Settings.pending)
    local scans = 0
    local scan = ns.Runtime.Scan
    ns.Runtime.Scan = function(self)
      scans = scans + 1
      return scan(self)
    end
    state.combat = false
    event(nil, "PLAYER_REGEN_ENABLED")
    assert(not ns.Settings.pending)
    H.equal(scans, 1, "one scan after deferred settings")
  end
  print("Plate lifecycle, preview and immediate spell mutations:", interface)
end
