local addonName, fPB = ...

local ipairs = ipairs
local CreateFrame = CreateFrame
local Enum = Enum
local SlashCmdList = SlashCmdList
local _G = _G

local Blizzard = fPB.Blizzard
local Client = fPB.Client
local Database = fPB.Database
local Fonts = fPB.Fonts
local Options = fPB.Options
local Runtime = fPB.Runtime
local Settings = fPB.Settings
local Tooltips = fPB.Tooltips

local frame = CreateFrame("Frame", addonName .. "Frame")
local initialized = false

local function settingsChanged()
  Blizzard:Apply(fPB.db.profile)
  Settings:Apply()
end

local function profileChanged()
  if not initialized then
    return
  end
  Options.selectedSpell = nil
  settingsChanged()
  Options:Refresh()
end

local function mediaChanged()
  Settings:Apply()
  Options:Refresh()
end

local function slash(message)
  if message == "preview" then
    Options:TogglePreview()
  else
    Options:Open(message)
  end
end

local function initialize()
  Database:Initialize(profileChanged)
  Options:Initialize(settingsChanged)
  Tooltips:Initialize()
  Fonts:Initialize(mediaChanged)
  initialized = true
  profileChanged()
  _G.SLASH_FLYPLATEBUFFSFIXED1, _G.SLASH_FLYPLATEBUFFSFIXED2 = "/fpb", "/pb"
  SlashCmdList.FLYPLATEBUFFSFIXED = slash
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_FACTION",
    "UNIT_FLAGS",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
  }) do
    frame:RegisterEvent(event)
  end
  if Client.modern then
    frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  else
    frame:RegisterEvent("UNIT_AURA")
  end
end

local function onEvent(_, event, unit, update)
  if event == "ADDON_LOADED" then
    if unit == addonName then
      frame:UnregisterEvent("ADDON_LOADED")
      initialize()
    end
  elseif event == "PLAYER_LOGOUT" then
    Database:Save()
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    Runtime:RemoveUnit(unit)
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if update == Enum.AddOnRestrictionState.Inactive then
      if Settings.pending then
        Settings:Apply()
      end
      Options:Refresh()
    end
  elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
    Blizzard:Apply(fPB.db.profile)
    if Settings.pending then
      Settings:Apply()
    elseif Settings.ready then
      Runtime:Scan()
      Runtime:RefreshUnits()
    end
    Options:Refresh()
  elseif event == "PLAYER_REGEN_DISABLED" then
    if Settings.ready then
      Runtime:RefreshUnits()
    end
    Options:Refresh()
  elseif Settings.ready then
    if event == "PLAYER_TARGET_CHANGED" then
      if fPB.db.profile.targetOnly then
        Runtime:RefreshUnits()
      end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
      Runtime:AddUnit(unit)
    elseif event == "UNIT_AURA" then
      Runtime:UpdateAuras(unit, update)
    elseif unit == "player" then
      Runtime:RefreshUnits()
    else
      Runtime:UpdateUnit(unit)
    end
  end
end

frame:SetScript("OnEvent", onEvent)
frame:RegisterEvent("ADDON_LOADED")
