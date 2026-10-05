local _, fPB = ...

local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAssist = UnitCanAssist
local UnitCanAttack = UnitCanAttack
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitPlayerControlled = UnitPlayerControlled
local UnitReaction = UnitReaction
local CanCompareUnitTokens = C_Secrets and C_Secrets.CanCompareUnitTokens
local ShouldUnitComparisonBeSecret = C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret

local Units = {}
fPB.Units = Units

function Units:IsPlayer(unit)
  if
    CanCompareUnitTokens and (not CanCompareUnitTokens(unit, "player") or ShouldUnitComparisonBeSecret(unit, "player"))
  then
    return false
  end
  return UnitIsUnit(unit, "player")
end

function Units:IsFriendly(unit)
  return UnitCanAssist("player", unit, true, true) and not UnitCanAttack("player", unit)
end

function Units:IsAllowed(unit, profile)
  if profile.enabled == false then
    return false
  end
  if profile.targetOnly then
    if
      CanCompareUnitTokens
      and (not CanCompareUnitTokens(unit, "target") or ShouldUnitComparisonBeSecret(unit, "target"))
    then
      return false
    end
    if not UnitIsUnit(unit, "target") then
      return false
    end
  end
  if Units:IsPlayer(unit) then
    return false
  end
  if profile.showOnlyInCombat and not UnitAffectingCombat("player") then
    return false
  elseif profile.showUnitInCombat and not UnitAffectingCombat(unit) then
    return false
  end
  if UnitIsPlayer(unit) then
    if not profile.showOnPlayers then
      return false
    end
  elseif UnitPlayerControlled(unit) then
    if not profile.showOnPets then
      return false
    end
  elseif not profile.showOnNPC then
    return false
  end
  if UnitReaction("player", unit) == 4 then
    return profile.showOnNeutral
  elseif Units:IsFriendly(unit) then
    return profile.showOnFriend
  end
  return profile.showOnEnemy
end
