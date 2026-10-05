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
local SetCVar = C_CVar.SetCVar

local Client = fPB.Client
local Restrictions = fPB.Restrictions

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

local function setCVar(key, value)
  local current = GetCVar(key)
  if current ~= nil and current ~= tostring(value) then
    SetCVar(key, value)
  end
end

local function restoreSavedAuras(values)
  for key, value in pairs(values or {}) do
    setCVar(key, value)
  end
end

local function applyFriendlyDebuffs(profile)
  if profile.disableFriendlyDebuffs ~= nil then
    setCVar("nameplateShowDebuffsOnFriendly", profile.disableFriendlyDebuffs and 0 or 1)
  end
end

function Blizzard:SetCVar(key, value)
  setCVar(key, value)
end

function Blizzard:ResetCVar(key)
  local value = GetCVarDefault(key)
  if value ~= nil then
    setCVar(key, value)
  end
end

function Blizzard:HideAuras(profile)
  profile.hideBlizzardAuras = true
  if Restrictions:Active() then
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
    and (profile.enabled == false or not profile.hideBlizzardAuras or profile.blizzardAuras ~= hiddenProfileValues)
  then
    -- Reset/copy can replace the active profile while native icons are hidden.
    restoreSavedAuras(hiddenAuras)
    hiddenAuras, hiddenProfileValues = nil, nil
  end
  if profile.nameplateMaxDistance == false then
    Blizzard:ResetCVar("nameplateMaxDistance")
  end
  if profile.nameplateMaxDistance then
    Blizzard:SetCVar("nameplateMaxDistance", profile.nameplateMaxDistance)
  end
  if profile.nameplateInset then
    Blizzard:SetCVar("nameplateOtherTopInset", -1)
    Blizzard:SetCVar("nameplateOtherBottomInset", -1)
  elseif profile.nameplateInset == false then
    Blizzard:ResetCVar("nameplateOtherTopInset")
    Blizzard:ResetCVar("nameplateOtherBottomInset")
  end
  if profile.blizzardCountdown ~= nil then
    Blizzard:SetCVar("countdownForCooldowns", profile.blizzardCountdown and 1 or 0)
  end
  if Client.modern and profile.enabled ~= false and profile.hideBlizzardAuras then
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
  profile.hideBlizzardAuras = false
  restoreSavedAuras(hiddenAuras or profile.blizzardAuras)
  hiddenAuras, hiddenProfileValues = nil, nil
  applyFriendlyDebuffs(profile)
  profile.blizzardAuras = nil
end
