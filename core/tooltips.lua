local _, fPB = ...

local Enum = Enum
local TooltipDataProcessor = TooltipDataProcessor

local Client = fPB.Client

local Tooltips = {}
fPB.Tooltips = Tooltips

local function addSpellID(tooltip, data)
  if fPB.db.profile.showSpellID and data.id then
    tooltip:AddLine("Spell ID: " .. data.id)
  end
end

function Tooltips:Initialize()
  if not Client.modern then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, addSpellID)
  end
end
