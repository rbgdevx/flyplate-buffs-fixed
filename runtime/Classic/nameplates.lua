local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local CopyTable = CopyTable
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local WorldFrame = WorldFrame
local mmin = math.min
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate.GetNamePlates

local Appearance = fPB.Appearance
local Auras = fPB.Auras
local ClassicRules = fPB.ClassicRules
local Icons = fPB.Icons
local Layout = fPB.Layout
local Units = fPB.Units

local Runtime = {}
fPB.Runtime = Runtime

local displays, units = {}, {}
local profile, appearance

local function hideTooltip(button)
  if GameTooltip:IsOwned(button) then
    GameTooltip:Hide()
  end
end

local function showTooltip(button)
  if not button.profile.tooltipInCombat and InCombatLockdown() then
    return
  end
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetUnitAuraByAuraInstanceID(button.unit, button.aura.auraInstanceID)
  if button.profile.showSpellID then
    GameTooltip:AddLine("Spell ID: " .. button.aura.spellId)
  end
  GameTooltip:Show()
end

local function clear(state)
  for _, button in ipairs(state.buttons) do
    hideTooltip(button)
    Icons:Release(button)
  end
  state.frame:Hide()
end

local function render(state)
  if not Units:IsAllowed(state.unit, profile) then
    clear(state)
    return
  end
  local records = {}
  local friendly = Units:IsFriendly(state.unit)
  for _, id in ipairs(state.order) do
    local aura = state.auras[id]
    local record = ClassicRules:Evaluate(profile, aura, friendly)
    if record then
      records[#records + 1] = record
    end
  end
  ClassicRules:Sort(profile, records)
  local count = mmin(#records, profile.buffPerLine * profile.numLines)
  state.frame:SetParent(profile.parentWorldFrame and WorldFrame or state.plate)
  for index = 1, count do
    local button = state.buttons[index]
    if not button then
      button = Icons:Create(state.frame)
      button:SetScript("OnEnter", showTooltip)
      button:SetScript("OnLeave", hideTooltip)
      state.buttons[index] = button
    end
    button.unit = state.unit
    local tooltip = profile.showTooltip and (profile.tooltipInCombat or not InCombatLockdown())
    button:EnableMouse(tooltip)
    if not tooltip then
      hideTooltip(button)
    end
    Icons:Apply(button, profile, appearance.style, records[index].style, records[index].aura)
  end
  for index = count + 1, #state.buttons do
    hideTooltip(state.buttons[index])
    Icons:Release(state.buttons[index])
  end
  Layout:Arrange(state.frame, state.buttons, count, profile, state.plate.UnitFrame or state.plate)
  state.frame:SetShown(count > 0)
end

function Runtime:AddUnit(unit)
  local plate = GetNamePlateForUnit(unit)
  if not plate or plate:IsForbidden() then
    return
  end
  local blizzard = plate.UnitFrame and plate.UnitFrame.AurasFrame
  if blizzard then
    blizzard:SetAlpha(
      (profile.enabled == false or Units:IsPlayer(unit) and profile.notHideOnPersonalResource) and 1 or 0
    )
  end
  local state = displays[plate]
  if not state then
    state = { plate = plate, frame = CreateFrame("Frame", nil, plate), buttons = {}, auras = {}, order = {} }
    displays[plate] = state
  elseif state.unit and state.unit ~= unit then
    units[state.unit] = nil
    clear(state)
  end
  state.unit, units[unit] = unit, state
  Auras:Update(state)
  render(state)
end

function Runtime:RemoveUnit(unit)
  local state = units[unit]
  if state then
    clear(state)
    wipe(state.auras)
    wipe(state.order)
    state.unit, units[unit] = nil, nil
  end
end

function Runtime:UpdateAuras(unit, update)
  local state = units[unit]
  if state then
    if Auras:Update(state, update) then
      render(state)
    end
  end
end

function Runtime:UpdateUnit(unit)
  if units[unit] then
    render(units[unit])
  end
end

function Runtime:RefreshUnits()
  for _, state in pairs(units) do
    render(state)
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
