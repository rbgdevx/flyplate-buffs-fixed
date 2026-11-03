-- Verify queue ownership and fixed-ten scheduling; native timing and rendering are not emulated.
local H = dofile("tests/helpers.lua")

local function containers(state, count)
  local appearance = state.ns.Appearance:Build(state.ns.db.profile)
  local result = {}
  for index = 1, count do
    result[index] = state.ns.AuraContainer:Create(state.env.UIParent, appearance, {}, nil)
  end
  return result
end

local function shownCount(displays)
  local count = 0
  for _, display in ipairs(displays) do
    if display.frame:IsShown() then
      count = count + 1
    end
  end
  return count
end

local function checkFixedBudget(interface)
  local state = H.environment(interface)
  H.loadAddon(state)
  local displays = containers(state, 23)
  for _, display in ipairs(displays) do
    state.ns.AuraContainer:SetEnabled(display, true)
    state.ns.AuraContainer:SetEnabled(display, true)
  end
  H.equal(shownCount(displays), 0, "new displays wait for the queue update")
  state.ns.AuraContainer:SetEnabled(displays[11], false)
  state:tick(0.02)
  H.equal(shownCount(displays), 10)
  assert(displays[10].frame:IsShown() and not displays[12].frame:IsShown(), "cancellation preserves queue order")
  state:tick(0.02)
  H.equal(shownCount(displays), 20)
  state:tick(0.02)
  H.equal(shownCount(displays), 22)
  assert(not displays[11].frame:IsShown(), "canceled displays remain hidden")
  state:tick(0.02)
  H.equal(shownCount(displays), 22, "repeated activation requests do not duplicate queue entries")
end

local function checkCancellation(interface)
  local state = H.environment(interface)
  H.loadAddon(state)
  local displays = containers(state, 25)
  for _, display in ipairs(displays) do
    state.ns.AuraContainer:SetEnabled(display, true)
  end
  for _, index in ipairs({ 1, 13, 25 }) do
    state.ns.AuraContainer:SetEnabled(displays[index], false)
  end
  state:tick(0.02)
  H.equal(shownCount(displays), 10)
  state:tick(0.02)
  H.equal(shownCount(displays), 20)
  state:tick(0.02)
  H.equal(shownCount(displays), 22)
  for _, index in ipairs({ 1, 13, 25 }) do
    assert(not displays[index].frame:IsShown())
  end

  local single = containers(state, 1)[1]
  state.ns.AuraContainer:SetEnabled(single, true)
  state.ns.AuraContainer:SetEnabled(single, false)
  state:tick(0.02)
  assert(not single.frame:IsShown(), "canceling the sole queued display leaves it hidden")
  state.ns.AuraContainer:SetEnabled(single, true)
  state:tick(0.02)
  assert(single.frame:IsShown(), "the queue restarts after complete cancellation")
end

local function checkRecycling(interface)
  local state = H.environment(interface)
  H.loadAddon(state)
  local event = state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent
  local plate = state:addPlate("nameplate1")
  event(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
  local selected
  for _, object in ipairs(state.created) do
    if object.unit == "nameplate1" and object.enabled then
      selected = object
    end
  end
  assert(selected and not selected:IsShown())
  event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
  state.plates.nameplate1 = nil
  state.plates.nameplate2, plate.unit = plate, "nameplate2"
  event(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")
  state:tick(0.02)
  assert(selected:IsShown() and selected:GetUnit() == "nameplate2", "recycled displays bind the current unit")
  event(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate2")
  state:tick(0.02)
  assert(not selected:IsShown() and not selected:IsEnabled())
end

for _, interface in ipairs({ 120105, 16001 }) do
  checkFixedBudget(interface)
  checkCancellation(interface)
  checkRecycling(interface)
end
print("Fixed-ten activation, cancellation and recycled-unit ownership pass")
