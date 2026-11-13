local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local CopyTable = CopyTable
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates

local Appearance = fPB.Appearance
local AuraContainer = fPB.AuraContainer
local ModernRules = fPB.ModernRules
local Reserve = fPB.Reserve
local StyleResources = fPB.StyleResources
local Units = fPB.Units

local Runtime = {}
fPB.Runtime = Runtime

local displays, units = {}, {}
local profile

local function disable(display, desired)
  for _, state in pairs(display.containers) do
    AuraContainer:SetEnabled(state, state == desired)
  end
end

local function update(display, unit)
  local desired
  local allowed, friendly = Units:IsAllowed(unit, profile)
  if allowed then
    if friendly == nil then
      friendly = Units:IsFriendly(unit)
    end
    local role = friendly and "friendly" or "enemy"
    desired = display.containers[role]
    if not desired then
      desired = Reserve:Acquire(role, display.plate)
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

function Runtime:ApplySettings(force)
  profile = CopyTable(fPB.db.profile)
  local appearance = Appearance:Build(profile)
  local recipes = { friendly = ModernRules:Build(profile, true), enemy = ModernRules:Build(profile, false) }
  Reserve:Configure(appearance, recipes, StyleResources:Build(appearance.style), force)
end

function Runtime:ApplyDurationLimit(prefix, friendly, helpful)
  local saved = fPB.db.profile
  local limit = not saved[prefix .. "NoDurationLimit"] and saved[prefix .. "MaxDuration"]
  Reserve:ApplyDurationLimit(friendly and "friendly" or "enemy", helpful, limit, saved.hidePermanent)
end

function Runtime:Prepare()
  Reserve:Resume()
end

function Runtime:Scan()
  Reserve:Resume()
  for _, plate in ipairs(GetNamePlates()) do
    local unit = plate:GetUnit()
    if unit then
      Runtime:AddUnit(unit)
    end
  end
end
