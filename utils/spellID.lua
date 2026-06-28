local _, fPB = ...
function fPB.ShowSpellID()
  -- MoP 5.5.4: UnitBuff/UnitDebuff/UnitAura return multiple values, no C_UnitAuras namespace
  local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura =
    hooksecurefunc,
    select,
    UnitBuff,
    UnitDebuff,
    UnitAura

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

  -- MoP Classic 5.5.4: modern signature, NO rank (name, icon, count, debuffType, duration, expTime, caster, _, _, spellId, ...) -> spellId at position 10
  hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
    local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(...)
    if spellId then
      addLine(self, spellId, types.spell)
    end
  end)

  hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
    local _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(...)
    if spellId then
      addLine(self, spellId, types.spell)
    end
  end)

  hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
    local _, _, _, _, _, _, _, _, _, spellId = UnitAura(...)
    if spellId then
      addLine(self, spellId, types.spell)
    end
  end)

  -- MoP: TooltipDataProcessor does not exist; use GetSpell() fallback via SetHyperlink hook above
end
