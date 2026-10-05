local _, fPB = ...

local ipairs = ipairs
local next = next
local pairs = pairs
local strlenutf8 = strlenutf8
local tostring = tostring
local type = type
local CopyTable = CopyTable
local GetRealmName = GetRealmName
local RegionalUniqueNamesEnabled = RegionalUniqueNamesEnabled
local UnitName = UnitName
local UnitNameUnmodified = UnitNameUnmodified
local _G = _G
local sfind = string.find
local tsort = table.sort
local GetSpellInfo = C_Spell.GetSpellInfo

local defaultLargeSpells = fPB.defaultLargeSpells
local defaultMediumSpells = fPB.defaultMediumSpells
local Client = fPB.Client
local Defaults = fPB.Defaults

local Database = {}
fPB.Database = Database

local saved, characterKey, currentProfile, onProfileChanged

local function fillDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      target[key] = type(value) == "table" and CopyTable(value) or value
    elseif type(value) == "table" and type(target[key]) == "table" then
      fillDefaults(target[key], value)
    end
  end
end

local function removeDefaults(target, defaults)
  for key, value in pairs(defaults) do
    local stored = target[key]
    if type(value) == "table" and type(stored) == "table" then
      removeDefaults(stored, value)
      if next(stored) == nil then
        target[key] = nil
      end
    elseif stored == value then
      target[key] = nil
    end
  end
end

local function getCharacterKey()
  local name, surname = UnitNameUnmodified("player")
  if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
    return surname and name .. " " .. tostring(surname) or name
  end
  return name .. " - " .. GetRealmName()
end

local function validProfileName(name)
  return type(name) == "string" and strlenutf8(name) > 0 and strlenutf8(name) <= 50 and not sfind(name, "^ +$")
end

local function activateProfile(name)
  local profile = saved.profiles[name] or {}
  fillDefaults(profile, Defaults.profile)
  saved.profiles[name] = profile
  saved.profileKeys[characterKey] = name
  currentProfile = name
  fPB.db.profile = profile
end

local function defaultNames()
  local names = {}
  for _, ids in ipairs({ defaultLargeSpells, defaultMediumSpells }) do
    for _, id in ipairs(ids) do
      local info = GetSpellInfo(id)
      if info then
        names[info.name] = names[info.name] or id
      end
    end
  end
  return names
end

local function migrateProfile(profile, names)
  if profile.Spells then
    local moves = {}
    for key, rule in pairs(profile.Spells) do
      if type(key) == "string" then
        local id = rule.spellID or names[key]
        if id and id ~= key and not profile.Spells[id] and not moves[id] then
          moves[id] = { key = key, rule = rule }
        end
      end
    end
    for id, move in pairs(moves) do
      local info = GetSpellInfo(id)
      move.rule.name = info and info.name or move.rule.name or move.key
      profile.Spells[id], profile.Spells[move.key] = move.rule, nil
    end
  end

  -- Keep unresolved deletion markers and colliding entries rather than losing
  -- user data during the old name-to-ID migration.
  if profile.ignoredDefaultSpells then
    for name, id in pairs(names) do
      if profile.ignoredDefaultSpells[name] then
        profile.ignoredDefaultSpells[id] = true
      end
    end
  end
end

local function removeUnrequestedSettings(profile)
  profile.enabled = nil
  profile.modernMaxPerGroup = nil

  local anchor = profile.buffAnchorPoint
  if anchor ~= "BOTTOMLEFT" and anchor ~= "BOTTOM" and anchor ~= "BOTTOMRIGHT" then
    profile.buffAnchorPoint = nil
  end
  anchor = profile.plateAnchorPoint
  if anchor ~= "TOPLEFT" and anchor ~= "TOP" and anchor ~= "TOPRIGHT" then
    profile.plateAnchorPoint = nil
  end
end

function Database:Migrate(storage)
  for _, profile in pairs(storage and storage.profiles or {}) do
    removeUnrequestedSettings(profile)
  end

  if storage and (not storage.version or storage.version < 2) then
    local names = defaultNames()
    for _, profile in pairs(storage.profiles or {}) do
      migrateProfile(profile, names)
    end
    storage.version = 2
  end
end

function Database:Initialize(onChanged)
  saved = _G.flyPlateBuffsFixedDB or {}
  Database:Migrate(saved)
  Defaults:Initialize()
  saved.profiles = saved.profiles or {}
  saved.profileKeys = saved.profileKeys or {}
  saved.version = 2
  _G.flyPlateBuffsFixedDB = saved
  fPB.db = { sv = saved }
  characterKey = getCharacterKey()
  local name = saved.profileKeys[characterKey]

  -- Preserve the exact legacy Forever association when its new key is absent.
  if name == nil and Client.forever then
    local oldKey = UnitName("player") .. " - " .. GetRealmName()
    local previous = saved.profileKeys[oldKey]
    if previous and saved.profiles[previous] then
      name = previous
    end
  end
  activateProfile(validProfileName(name) and name or "Default")
  onProfileChanged = onChanged
end

function Database:IsValidProfileName(name)
  return validProfileName(name)
end

function Database:GetCurrentProfile()
  return currentProfile
end

function Database:GetProfiles()
  local names = {}
  for name in pairs(saved.profiles) do
    names[#names + 1] = name
  end
  tsort(names)
  return names
end

function Database:SetProfile(name)
  if not validProfileName(name) or name == currentProfile then
    return false
  end
  removeDefaults(fPB.db.profile, Defaults.profile)
  activateProfile(name)
  onProfileChanged()
  return true
end

function Database:CopyProfile(name)
  if name == currentProfile or not saved.profiles[name] then
    return false
  end
  saved.profiles[currentProfile] = CopyTable(saved.profiles[name])
  activateProfile(currentProfile)
  onProfileChanged()
  return true
end

function Database:ResetProfile()
  saved.profiles[currentProfile] = {}
  activateProfile(currentProfile)
  onProfileChanged()
end

function Database:DeleteProfile(name)
  if name == currentProfile or not saved.profiles[name] then
    return false
  end
  saved.profiles[name] = nil
  for key, profileName in pairs(saved.profileKeys) do
    if profileName == name then
      saved.profileKeys[key] = nil
    end
  end
  return true
end

function Database:Save()
  -- Keep the existing sparse SavedVariables format and future default updates.
  for _, profile in pairs(saved.profiles) do
    removeDefaults(profile, Defaults.profile)
  end
end
