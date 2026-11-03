local _, fPB = ...

local ipairs = ipairs
local next = next
local pairs = pairs
local wipe = wipe
local CopyTable = CopyTable
local CreateFrame = CreateFrame
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates

local Appearance = fPB.Appearance
local Auras = fPB.Auras
local ClassicDisplay = fPB.ClassicDisplay
local ClassicRecords = fPB.ClassicRecords
local Units = fPB.Units

local Runtime = {}
fPB.Runtime = Runtime

local displays, units, pending = {}, {}, {}
local updates = CreateFrame("Frame")
local profile, appearance

local function cancel(state)
  pending[state] = nil
  if not next(pending) then
    updates:SetScript("OnUpdate", nil)
  end
end

local function clear(state)
  cancel(state)
  if not state.active then
    return
  end
  ClassicDisplay:Clear(state)

  state.active = false
  state.count, state.layout = 0, nil
  state.fullUpdate = nil

  wipe(state.auras)
  wipe(state.order)
  wipe(state.dirty)
  wipe(state.records)
  wipe(state.visible)
end

local function render(state)
  if ClassicRecords:Update(state, profile) then
    ClassicDisplay:Render(state, profile, appearance)
  end
end

local function reconcile(state, snapshot)
  cancel(state)
  if not Units:IsAllowed(state.unit, profile) then
    clear(state)
    return
  end
  if snapshot or not state.active then
    Auras:Update(state)
  end
  state.active, state.fullUpdate = true, true
  render(state)
end

local function drawPending()
  updates:SetScript("OnUpdate", nil)
  for state in pairs(pending) do
    pending[state] = nil
    if Units:IsAllowed(state.unit, profile) then
      render(state)
    else
      clear(state)
    end
  end
end

local function queue(state)
  if not next(pending) then
    updates:SetScript("OnUpdate", drawPending)
  end
  pending[state] = true
end

local function createDisplay(plate)
  return {
    plate = plate,
    frame = ClassicDisplay:Create(plate),
    buttons = {},
    auras = {},
    order = {},
    dirty = {},
    records = {},
    visible = {},
    count = 0,
  }
end

function Runtime:AddUnit(unit)
  local plate = GetNamePlateForUnit(unit)
  if not plate or plate:IsForbidden() then
    return
  end
  local blizzard = plate.UnitFrame and plate.UnitFrame.AurasFrame
  if blizzard then
    blizzard:SetAlpha(Units:IsPlayer(unit) and profile.notHideOnPersonalResource and 1 or 0)
  end
  local state = displays[plate]
  if not state then
    state = createDisplay(plate)
    displays[plate] = state
  elseif state.unit and state.unit ~= unit then
    units[state.unit] = nil
    clear(state)
  end
  state.unit, units[unit] = unit, state
  reconcile(state, true)
end

function Runtime:RemoveUnit(unit)
  local state = units[unit]
  if state then
    clear(state)
    state.unit, units[unit] = nil, nil
  end
end

function Runtime:UpdateAuras(unit, update)
  local state = units[unit]
  if not state then
    return
  end
  if not Units:IsAllowed(unit, profile) then
    clear(state)
  elseif not state.active then
    reconcile(state, true)
  elseif Auras:Update(state, update) then
    queue(state)
  end
end

function Runtime:UpdateUnit(unit)
  if units[unit] then
    reconcile(units[unit])
  end
end

function Runtime:RefreshUnits()
  for _, state in pairs(units) do
    reconcile(state)
  end
end

function Runtime:ApplySettings()
  profile = CopyTable(fPB.db.profile)
  appearance = Appearance:Build(profile)
end

function Runtime:Scan()
  for _, plate in ipairs(GetNamePlates()) do
    local unit = plate:GetUnit()
    if unit then
      Runtime:AddUnit(unit)
    end
  end
end
