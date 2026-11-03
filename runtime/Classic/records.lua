local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local wipe = wipe

local ClassicRules = fPB.ClassicRules
local Units = fPB.Units

local ClassicRecords = {}
fPB.ClassicRecords = ClassicRecords

local function rebuildRecords(state, profile, friendly)
  wipe(state.records)
  for _, id in ipairs(state.order) do
    state.records[id] = ClassicRules:Evaluate(profile, state.auras[id], friendly)
  end
end

local function updateDirtyRecords(state, profile, friendly)
  local changed, sort = false, false
  for id in pairs(state.dirty) do
    local previous = state.records[id]
    local aura = state.auras[id]
    local record = aura and ClassicRules:Evaluate(profile, aura, friendly)
    state.records[id] = record
    if previous or record then
      changed = true
      sort = ClassicRules:OrderChanged(profile, previous, record) or sort
    end
  end
  return changed, sort
end

local function rebuildVisible(state, profile)
  wipe(state.visible)
  for _, id in ipairs(state.order) do
    local record = state.records[id]
    if record then
      state.visible[#state.visible + 1] = record
    end
  end
  ClassicRules:Sort(profile, state.visible)
end

local function refreshVisible(state)
  for index, record in ipairs(state.visible) do
    state.visible[index] = state.records[record.aura.auraInstanceID]
  end
end

function ClassicRecords:Update(state, profile)
  local full = state.fullUpdate
  local changed, sort = full, full
  local friendly = Units:IsFriendly(state.unit)
  if full then
    rebuildRecords(state, profile, friendly)
  else
    changed, sort = updateDirtyRecords(state, profile, friendly)
  end

  wipe(state.dirty)
  state.fullUpdate = nil

  if sort then
    rebuildVisible(state, profile)
  elseif changed then
    refreshVisible(state)
  end
  return changed
end
