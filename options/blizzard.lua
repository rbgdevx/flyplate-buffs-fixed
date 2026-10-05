local _, fPB = ...

local tonumber = tonumber
local GenerateClosure = GenerateClosure
local InCombatLockdown = InCombatLockdown
local GetCVar = C_CVar.GetCVar

local Blizzard = fPB.Blizzard
local Client = fPB.Client
local Controls = fPB.Controls
local L = fPB.L
local Options = fPB.Options
local Restrictions = fPB.Restrictions

local BlizzardOptions = {}
fPB.BlizzardOptions = BlizzardOptions

local function unavailable(cvar)
  return InCombatLockdown() or Restrictions:Active() or GetCVar(cvar) == nil
end

local function friendlyDebuffsDisabled()
  return unavailable("nameplateShowDebuffsOnFriendly") or Client.modern and fPB.db.profile.hideBlizzardAuras
end

local function getDistance()
  return fPB.db.profile.nameplateMaxDistance or tonumber(GetCVar("nameplateMaxDistance")) or 40
end

local function setDistance(_, value)
  fPB.db.profile.nameplateMaxDistance = value
  Blizzard:SetCVar("nameplateMaxDistance", value)
  Options:Refresh()
end

local function resetDistance()
  fPB.db.profile.nameplateMaxDistance = false
  Blizzard:ResetCVar("nameplateMaxDistance")
  Options:Refresh()
end

local function getInset()
  return GetCVar("nameplateOtherTopInset") == "-1" and GetCVar("nameplateOtherBottomInset") == "-1"
end

local function setInset(_, value)
  fPB.db.profile.nameplateInset = value
  if value then
    Blizzard:SetCVar("nameplateOtherTopInset", -1)
    Blizzard:SetCVar("nameplateOtherBottomInset", -1)
  else
    Blizzard:ResetCVar("nameplateOtherTopInset")
    Blizzard:ResetCVar("nameplateOtherBottomInset")
  end
  Options:Refresh()
end

local function getCVarFlag(cvar, enabled)
  return GetCVar(cvar) == enabled
end

local function setCVarFlag(key, cvar, enabled, disabled, _, value)
  fPB.db.profile[key] = value
  Blizzard:SetCVar(cvar, value and enabled or disabled)
  Options:Refresh()
end

local function hideAuras()
  Blizzard:HideAuras(fPB.db.profile)
  Options:Refresh()
end

local function restoreAuras()
  Blizzard:RestoreAuras(fPB.db.profile)
  Options:Refresh()
end

function BlizzardOptions:Build()
  local args = {
    nameplateMaxDistance = {
      type = "range",
      name = L["Nameplate visible distance"],
      order = 1,
      width = Controls:Width(L["Nameplate visible distance"]),
      min = 20,
      max = 100,
      step = 5,
      get = getDistance,
      set = setDistance,
      disabled = GenerateClosure(unavailable, "nameplateMaxDistance"),
    },
    resetDistance = {
      type = "execute",
      name = L["Reset distance to default"],
      order = 2,
      width = Controls:Width(L["Reset distance to default"]),
      func = resetDistance,
      disabled = GenerateClosure(unavailable, "nameplateMaxDistance"),
    },
    nameplateInset = {
      type = "toggle",
      name = L["Stops nameplates from clamping to the screen"],
      order = 3,
      width = "full",
      get = getInset,
      set = setInset,
      disabled = GenerateClosure(unavailable, "nameplateOtherTopInset"),
    },
    disableFriendlyDebuffs = {
      type = "toggle",
      name = L["Disable debuffs on friendly nameplates"],
      order = 4,
      width = "full",
      get = GenerateClosure(getCVarFlag, "nameplateShowDebuffsOnFriendly", "0"),
      set = GenerateClosure(setCVarFlag, "disableFriendlyDebuffs", "nameplateShowDebuffsOnFriendly", "0", "1"),
      disabled = friendlyDebuffsDisabled,
    },
    blizzardCountdown = {
      type = "toggle",
      name = L["Enable blizzard Countdown"],
      order = 5,
      width = "full",
      get = GenerateClosure(getCVarFlag, "countdownForCooldowns", "1"),
      set = GenerateClosure(setCVarFlag, "blizzardCountdown", "countdownForCooldowns", "1", "0"),
      disabled = GenerateClosure(unavailable, "countdownForCooldowns"),
    },
  }
  if Client.modern then
    args.auraActions = Controls:Group("Blizzard's aura icons", 7, {
      hideRow = Controls:Row(1, {
        hide = {
          type = "execute",
          name = L["Hide Blizzard icons"],
          order = 1,
          width = Controls:Width(L["Hide Blizzard icons"]),
          func = hideAuras,
        },
      }),
      restoreRow = Controls:Row(2, {
        restore = {
          type = "execute",
          name = L["Restore previous values"],
          order = 1,
          width = Controls:Width(L["Restore previous values"]),
          func = restoreAuras,
        },
      }),
    })
  else
    args.fixNames = Controls:Toggle("Fix nameplates without names", 6)
    args.showSpellID = Controls:Toggle("Show spell ID in tooltips", 7)
  end
  args.distance = Controls:Row(1, {
    nameplateMaxDistance = args.nameplateMaxDistance,
  })
  args.resetDistanceRow = Controls:Row(2, {
    resetDistance = args.resetDistance,
  })
  args.nameplateMaxDistance, args.resetDistance = nil, nil
  return { type = "group", name = L["Blizzard"], order = 6, args = args }
end
