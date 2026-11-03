local _, fPB = ...

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local CompactUnitFrame_IsOnThreatListWithPlayer = CompactUnitFrame_IsOnThreatListWithPlayer
local CompactUnitFrame_IsTapDenied = CompactUnitFrame_IsTapDenied
local CopyTable = CopyTable
local GetUnitName = GetUnitName
local InCombatLockdown = InCombatLockdown
local UnitIsUnit = UnitIsUnit
local UnitSelectionColor = UnitSelectionColor
local GetCVar = C_CVar.GetCVar
local GetCVarDefault = C_CVar.GetCVarDefault
local GetCVarInfo = C_CVar.GetCVarInfo
local SetCVar = C_CVar.SetCVar

local Client = fPB.Client

local Blizzard = {}
fPB.Blizzard = Blizzard

local namesHooked = false
local hiddenAuras
local hiddenProfileValues
local auraCVars = {
  "nameplateEnemyNpcAuraDisplay",
  "nameplateEnemyPlayerAuraDisplay",
  "nameplateFriendlyPlayerAuraDisplay",
  "nameplateShowDebuffsOnFriendly",
}

local function restoreName(frame)
  if not fPB.db.profile.fixNames or frame:IsForbidden() then
    return
  end
  if frame.name and frame.unit and not frame.name:IsShown() and not UnitIsUnit(frame.unit, "player") then
    frame.name:SetText(GetUnitName(frame.unit, true))
    if CompactUnitFrame_IsTapDenied(frame) then
      frame.name:SetVertexColor(0.5, 0.5, 0.5)
    elseif frame.optionTable.colorNameBySelection then
      if
        frame.optionTable.considerSelectionInCombatAsHostile
        and CompactUnitFrame_IsOnThreatListWithPlayer(frame.displayedUnit)
      then
        frame.name:SetVertexColor(1, 0, 0)
      else
        frame.name:SetVertexColor(UnitSelectionColor(frame.unit, frame.optionTable.colorNameWithExtendedColors))
      end
    else
      frame.name:SetVertexColor(1, 1, 1)
    end
    frame.name:Show()
  end
end

local function canSetCVar(key)
  if InCombatLockdown() or GetCVar(key) == nil then
    return false
  end
  local _, _, _, _, _, secure, readOnly = GetCVarInfo(key)
  return not secure and not readOnly
end

local function canSetValues(values)
  if InCombatLockdown() then
    return false
  end
  for key, value in pairs(values or {}) do
    if GetCVar(key) ~= tostring(value) and not canSetCVar(key) then
      return false
    end
  end
  return true
end

local function setCVar(key, value)
  local current = GetCVar(key)
  if current ~= nil and current ~= tostring(value) and canSetCVar(key) then
    SetCVar(key, value)
  end
end

local function restoreSavedAuras(values)
  if not canSetValues(values) then
    return false
  end
  for key, value in pairs(values or {}) do
    setCVar(key, value)
  end
  return true
end

local function applyFriendlyDebuffs(profile)
  if profile.disableFriendlyDebuffs ~= nil then
    setCVar("nameplateShowDebuffsOnFriendly", profile.disableFriendlyDebuffs and 0 or 1)
  end
end

function Blizzard:CanSetCVar(key)
  return canSetCVar(key)
end

function Blizzard:CanSetInsets()
  return canSetCVar("nameplateOtherTopInset") and canSetCVar("nameplateOtherBottomInset")
end

function Blizzard:CanHideAuras()
  if InCombatLockdown() then
    return false
  end
  for _, key in ipairs(auraCVars) do
    local value = GetCVar(key)
    if value ~= nil and value ~= "0" and not canSetCVar(key) then
      return false
    end
  end
  return true
end

function Blizzard:CanRestoreAuras(profile)
  return canSetValues(hiddenAuras or profile.blizzardAuras)
end

function Blizzard:SetCVar(key, value)
  setCVar(key, value)
end

function Blizzard:ResetCVar(key)
  if GetCVar(key) == nil then
    return
  end
  local value = GetCVarDefault(key)
  if value ~= nil then
    setCVar(key, value)
  end
end

function Blizzard:SetInsets(value)
  if not Blizzard:CanSetInsets() then
    return false
  end
  if value then
    setCVar("nameplateOtherTopInset", -1)
    setCVar("nameplateOtherBottomInset", -1)
  else
    Blizzard:ResetCVar("nameplateOtherTopInset")
    Blizzard:ResetCVar("nameplateOtherBottomInset")
  end
  return true
end

function Blizzard:HideAuras(profile)
  if not Blizzard:CanHideAuras() then
    return
  end
  profile.hideBlizzardAuras = true
  if not fPB.Settings.ready then
    return
  end
  profile.blizzardAuras = profile.blizzardAuras or {}
  for _, key in ipairs(auraCVars) do
    local value = GetCVar(key)
    if value ~= nil then
      if profile.blizzardAuras[key] == nil then
        profile.blizzardAuras[key] = value
      end
      Blizzard:SetCVar(key, 0)
    end
  end
  if hiddenProfileValues ~= profile.blizzardAuras then
    hiddenAuras = CopyTable(profile.blizzardAuras)
    hiddenProfileValues = profile.blizzardAuras
  end
end

function Blizzard:Apply(profile)
  if InCombatLockdown() then
    return
  end
  if
    Client.modern
    and hiddenAuras
    and (not profile.hideBlizzardAuras or profile.blizzardAuras ~= hiddenProfileValues)
  then
    -- Reset/copy can replace the active profile while native icons are hidden.
    if not restoreSavedAuras(hiddenAuras) then
      return
    end
    hiddenAuras, hiddenProfileValues = nil, nil
  end
  if profile.nameplateMaxDistance == false then
    Blizzard:ResetCVar("nameplateMaxDistance")
  end
  if profile.nameplateMaxDistance then
    Blizzard:SetCVar("nameplateMaxDistance", profile.nameplateMaxDistance)
  end
  if profile.nameplateInset ~= nil then
    Blizzard:SetInsets(profile.nameplateInset)
  end
  if profile.blizzardCountdown ~= nil then
    Blizzard:SetCVar("countdownForCooldowns", profile.blizzardCountdown and 1 or 0)
  end
  if Client.modern and profile.hideBlizzardAuras then
    Blizzard:HideAuras(profile)
  else
    applyFriendlyDebuffs(profile)
  end
  if not Client.modern and profile.fixNames and not namesHooked then
    hooksecurefunc("CompactUnitFrame_UpdateName", restoreName)
    namesHooked = true
  end
end

function Blizzard:RestoreAuras(profile)
  if not restoreSavedAuras(hiddenAuras or profile.blizzardAuras) then
    return
  end
  profile.hideBlizzardAuras = false
  hiddenAuras, hiddenProfileValues = nil, nil
  applyFriendlyDebuffs(profile)
  profile.blizzardAuras = nil
end
