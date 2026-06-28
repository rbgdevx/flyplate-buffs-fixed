local _, fPB = ...
function fPB.ShowSpellID()
  local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura =
    hooksecurefunc,
    select,
    C_UnitAuras.GetBuffDataByIndex,
    C_UnitAuras.GetDebuffDataByIndex,
    C_UnitAuras.GetAuraDataByIndex

  local types = {
    spell = "spell ID:",
    talent = "talent ID:",
  }

  local function addLine(tooltip, id, type)
    local found = false

    for i = 1, 15 do
      local frame = _G[tooltip:GetName() .. "TextLeft" .. i]
      local text
      if frame then
        text = frame:GetText()
      end
      if text and strmatch(text, type) then
        found = true
        break
      end
    end

    if not found then
      tooltip:AddLine(type .. " |cffffffff" .. id)
      tooltip:Show()
    end
  end

  local function onSetHyperlink(self, link)
    local type, id = string.match(link, "^(%a+):(%d+)")
    if not type or not id then
      return
    end
    if type == "spell" then
      addLine(self, id, types.spell)
    elseif type == "talent" then
      addLine(self, id, types.talent)
    end
  end

  hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)

  hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
    local aura = UnitBuff(...)
    if aura and aura.spellId then
      addLine(self, aura.spellId, types.spell)
    end
  end)

  hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
    local aura = UnitDebuff(...)
    if aura and aura.spellId then
      addLine(self, aura.spellId, types.spell)
    end
  end)

  hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
    local aura = UnitAura(...)
    if aura and aura.spellId then
      addLine(self, aura.spellId, types.spell)
    end
  end)

  local function OnTooltipSetItem(tooltip, data)
    local id = select(2, tooltip:GetSpell())
    if id then
      addLine(tooltip, id, types.spell)
    end
  end

  -- Replace 'Enum.TooltipDataType.Item' with an appropriate type for the tooltip
  -- data you are wanting to process; eg. use 'Enum.TooltipDataType.Spell' for
  -- replacing usage of OnTooltipSetSpell.
  --
  -- If you wish to respond to all tooltip data updates, you can instead replace
  -- the enum with 'TooltipDataProcessor.AllTypes' (or the string "ALL").

  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, OnTooltipSetItem)
end
