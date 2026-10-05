local _, fPB = ...

local ipairs = ipairs
local wipe = wipe

local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID
local GetUnitAuras = C_UnitAuras.GetUnitAuras

local Auras = {}
fPB.Auras = Auras

function Auras:Update(state, update)
  local auras, order = state.auras, state.order
  if not update or update.isFullUpdate then
    wipe(auras)
    wipe(order)
    for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
      for _, aura in ipairs(GetUnitAuras(state.unit, filter)) do
        auras[aura.auraInstanceID] = aura
        order[#order + 1] = aura.auraInstanceID
      end
    end
    return true
  end
  local changed = false
  for _, aura in ipairs(update.addedAuras or {}) do
    if not auras[aura.auraInstanceID] then
      order[#order + 1] = aura.auraInstanceID
    end
    auras[aura.auraInstanceID] = aura
    changed = true
  end
  for _, id in ipairs(update.updatedAuraInstanceIDs or {}) do
    local aura = GetAuraDataByAuraInstanceID(state.unit, id)
    if aura and not auras[id] then
      order[#order + 1] = id
    end
    auras[id] = aura
    changed = true
  end
  for _, id in ipairs(update.removedAuraInstanceIDs or {}) do
    auras[id] = nil
    changed = true
  end
  if changed then
    local count = 0
    for _, id in ipairs(order) do
      if auras[id] then
        count = count + 1
        order[count] = id
      end
    end
    for index = #order, count + 1, -1 do
      order[index] = nil
    end
  end
  return changed
end
