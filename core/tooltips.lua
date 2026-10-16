local _, fPB = ...

local GameTooltip = GameTooltip

local Client = fPB.Client

local Tooltips = {}
fPB.Tooltips = Tooltips

local function addSpellID(tooltip)
  if not fPB.db.profile.showSpellID then
    return
  end

  local _, spellID = tooltip:GetSpell()
  if spellID then
    tooltip:AddLine("Spell ID: " .. spellID)
  end
end

function Tooltips:Initialize()
  if not Client.modern then
    GameTooltip:HookScript("OnTooltipSetSpell", addSpellID)
  end
end
