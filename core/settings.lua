local _, fPB = ...

local IsLoggedIn = IsLoggedIn

local Restrictions = fPB.Restrictions
local Runtime = fPB.Runtime
local SpellRules = fPB.SpellRules

local Settings = { ready = false, pending = false }
fPB.Settings = Settings

function Settings:Apply(force)
  Settings.forceAppearance = force or Settings.forceAppearance
  if IsLoggedIn() and Restrictions:Active() then
    Settings.pending = true
    return
  end
  SpellRules:Rebuild(fPB.db.profile)
  Runtime:ApplySettings(Settings.forceAppearance)
  Settings.forceAppearance = nil
  Settings.ready, Settings.pending = true, false
  Runtime:Scan()
end

function Settings:ApplyDurationLimit(prefix, friendly, helpful)
  if not Settings.ready or Settings.pending or Restrictions:Active() then
    Settings:Apply()
    return
  end
  Runtime:ApplyDurationLimit(prefix, friendly, helpful)
end
