local _, fPB = ...

local ipairs = ipairs
local wipe = wipe
local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID
local GetUnitAuras = C_UnitAuras.GetUnitAuras

local Auras = {}
fPB.Auras = Auras

local function scanAuras(state)
  state.fullUpdate = true
  wipe(state.dirty)
  wipe(state.auras)
  wipe(state.order)

  for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
    for _, aura in ipairs(GetUnitAuras(state.unit, filter)) do
      state.auras[aura.auraInstanceID] = aura
      state.order[#state.order + 1] = aura.auraInstanceID
    end
  end
end

local function addAuras(state, added)
  local changed = false
  for _, aura in ipairs(added or {}) do
    if not state.auras[aura.auraInstanceID] then
      state.order[#state.order + 1] = aura.auraInstanceID
    end
    state.auras[aura.auraInstanceID] = aura
    state.dirty[aura.auraInstanceID] = true
    changed = true
  end
  return changed
end

local function updateAuras(state, updated)
  local changed, removed = false, false
  for _, id in ipairs(updated or {}) do
    local aura = GetAuraDataByAuraInstanceID(state.unit, id)
    if aura and not state.auras[id] then
      state.order[#state.order + 1] = id
    end
    removed = removed or not aura and state.auras[id] ~= nil
    state.auras[id] = aura
    state.dirty[id] = true
    changed = true
  end
  return changed, removed
end

local function removeAuras(state, removed)
  local changed, compact = false, false
  for _, id in ipairs(removed or {}) do
    compact = compact or state.auras[id] ~= nil
    state.auras[id] = nil
    state.dirty[id] = true
    changed = true
  end
  return changed, compact
end

local function compactOrder(state)
  local count = 0
  for _, id in ipairs(state.order) do
    if state.auras[id] then
      count = count + 1
      state.order[count] = id
    end
  end
  for index = #state.order, count + 1, -1 do
    state.order[index] = nil
  end
end

function Auras:Update(state, update)
  if not update or update.isFullUpdate then
    scanAuras(state)
    return true
  end

  local added = addAuras(state, update.addedAuras)
  local updated, removed = updateAuras(state, update.updatedAuraInstanceIDs)
  local changed, compact = removeAuras(state, update.removedAuraInstanceIDs)
  if removed or compact then
    compactOrder(state)
  end
  return added or updated or changed
end
