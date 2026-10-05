local _, fPB = ...

local ipairs = ipairs
local pairs = pairs

local CopyTable = CopyTable

local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates

local Appearance = fPB.Appearance
local AuraContainer = fPB.AuraContainer
local ModernRules = fPB.ModernRules
local Units = fPB.Units

local Runtime = {}
fPB.Runtime = Runtime

local displays, units = {}, {}
local profile, appearance, recipes

local function disable(display, desired)
  for _, state in pairs(display.containers) do
    state.frame:SetEnabled(state == desired)
  end
end

local function update(display, unit)
  local desired
  if Units:IsAllowed(unit, profile) then
    local role = Units:IsFriendly(unit) and "friendly" or "enemy"
    desired = display.containers[role]
    if not desired then
      desired = AuraContainer:Create(display.plate, appearance, recipes[role])
      display.containers[role] = desired
    end
    desired.frame:SetUnit(unit)
  end
  disable(display, desired)
end

function Runtime:AddUnit(unit)
  local plate = GetNamePlateForUnit(unit)
  if not plate or plate:IsForbidden() then
    return
  end
  local display = displays[plate]
  if not display then
    display = { plate = plate, containers = {} }
    displays[plate] = display
  elseif display.unit and display.unit ~= unit then
    units[display.unit] = nil
    disable(display)
  end
  display.unit, units[unit] = unit, display
  update(display, unit)
end

function Runtime:RemoveUnit(unit)
  local display = units[unit]
  if display then
    disable(display)
    display.unit, units[unit] = nil, nil
  end
end

function Runtime:UpdateUnit(unit)
  if units[unit] then
    update(units[unit], unit)
  end
end

function Runtime:RefreshUnits()
  for unit, display in pairs(units) do
    update(display, unit)
  end
end

function Runtime:ApplySettings()
  local previous = recipes
  profile = CopyTable(fPB.db.profile)
  appearance = Appearance:Build(profile)
  recipes = { friendly = ModernRules:Build(profile, true), enemy = ModernRules:Build(profile, false) }
  for _, display in pairs(displays) do
    for role, state in pairs(display.containers) do
      AuraContainer:ApplySettings(state, appearance, recipes[role], previous and previous[role])
    end
  end
end

function Runtime:Scan()
  for _, plate in ipairs(GetNamePlates()) do
    local unit = plate:GetUnit()
    if unit then
      Runtime:AddUnit(unit)
    end
  end
end
