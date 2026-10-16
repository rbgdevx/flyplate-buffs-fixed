local H = dofile("tests/helpers.lua")

for _, interface in ipairs({ 11509, 20506, 50504, 120100, 120105, 16001 }) do
  local state = H.environment(interface)
  local tooltip = state.env.GameTooltip
  local lines, spellID = {}, 589
  local spellReads, originalCalls, processorCalls = 0, 0, 0
  local function originalTooltipScript()
    originalCalls = originalCalls + 1
  end
  tooltip:SetScript("OnTooltipSetSpell", originalTooltipScript)
  function tooltip:GetSpell()
    spellReads = spellReads + 1
    return "Shadow Word: Pain", spellID
  end
  function tooltip:AddLine(line)
    lines[#lines + 1] = line
  end
  if state.env.TooltipDataProcessor then
    state.env.TooltipDataProcessor.AddTooltipPostCall = function()
      processorCalls = processorCalls + 1
    end
  end

  H.loadAddon(state)
  assert(state.ns.Settings.ready, "tooltip setup must not prevent runtime initialization")
  local dialog = state.env.LibStub("AceConfigDialog-3.0")
  local opened = 0
  function dialog:Open(name)
    H.equal(name, "flyPlateBuffsFixed")
    opened = opened + 1
  end
  state.env.SlashCmdList.FLYPLATEBUFFSFIXED("")
  state.env.SlashCmdList.FLYPLATEBUFFSFIXED("spells")
  H.equal(opened, 2, "both slash commands open the settings")
  H.equal(state.dialogSelection[1], "spells")
  H.equal(processorCalls, 0, "Classic spell tooltips use their native script even if a processor exists")

  if state.ns.Client.modern then
    H.equal(tooltip.scripts.OnTooltipSetSpell, originalTooltipScript, "modern clients receive no legacy hook")
  else
    tooltip.scripts.OnTooltipSetSpell(tooltip)
    H.equal(#lines, 0, "spell IDs remain opt-in")
    H.equal(spellReads, 0, "disabled spell IDs do no tooltip work")
    state.ns.db.profile.showSpellID = true
    tooltip.scripts.OnTooltipSetSpell(tooltip)
    H.equal(lines[1], "Spell ID: 589", "use the second GetSpell return value")
    spellID = nil
    tooltip.scripts.OnTooltipSetSpell(tooltip)
    H.equal(#lines, 1, "a tooltip without a spell ID adds no line")
    spellID = 589
    state.ns.db.profile.showSpellID = false
    tooltip.scripts.OnTooltipSetSpell(tooltip)
    H.equal(#lines, 1, "turning the option off takes effect immediately")
    H.equal(originalCalls, 4, "preserve the existing tooltip script")
  end
end

print("tooltip checks passed")
