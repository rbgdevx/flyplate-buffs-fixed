local addonName, fPB = ...

local LibStub = LibStub

local Options = {}
fPB.Options = Options

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local onChange, onRefresh

function Options:SetCallbacks(changed, refreshed)
  onChange, onRefresh = changed, refreshed
end

function Options:Refresh()
  AceConfigRegistry:NotifyChange(addonName)
  if onRefresh then
    onRefresh()
  end
end

function Options:Changed()
  onChange()
  Options:Refresh()
end
