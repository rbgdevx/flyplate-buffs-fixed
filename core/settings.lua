local _, fPB = ...

local Restrictions = fPB.Restrictions
local Runtime = fPB.Runtime
local SpellRules = fPB.SpellRules

local Settings = { ready = false, pending = false }
fPB.Settings = Settings

function Settings:Apply()
  if Restrictions:Active() then
    Settings.pending = true
    return
  end
  SpellRules:Rebuild(fPB.db.profile)
  Runtime:ApplySettings()
  Settings.ready, Settings.pending = true, false
  Runtime:Scan()
end
