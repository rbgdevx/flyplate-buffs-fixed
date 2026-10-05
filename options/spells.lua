local addonName, fPB = ...

local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type

local LibStub = LibStub

local GetSpellTexture = C_Spell.GetSpellTexture

local Client = fPB.Client
local Controls = fPB.Controls
local InputPlaceholder = fPB.InputPlaceholder
local L = fPB.L
local Options = fPB.Options
local SpellRanks = fPB.SpellRanks
local SpellRules = fPB.SpellRules
local SpellSearch = fPB.SpellSearch

local SpellOptions = { query = "", input = "" }
fPB.SpellOptions = SpellOptions

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local focusedInput, inputCursor

local function groupKey(key)
  return type(key) .. ":" .. tostring(key)
end

local function ruleKey(info)
  return info.options.args.spells.args[info[2]].arg
end

local function spellRule(info)
  local key = ruleKey(info)
  return not fPB.db.profile.ignoredDefaultSpells[key] and fPB.db.profile.Spells[key] or nil
end

local function getRule(info)
  local rule = spellRule(info)
  return rule and rule[info[#info]]
end

local function setRule(info, value)
  local rule = spellRule(info)
  if rule then
    rule[info[#info]] = value
    Options:Changed()
  end
end

local function getSearch()
  return SpellOptions.query
end

local function setSearch(_, value)
  if SpellOptions.query == value then
    return
  end
  SpellOptions.query = value
  Options.selectedSpell = nil
  Options:Refresh()
end

local function getInput()
  return SpellOptions.input
end

local function selectSpell(key)
  Options.selectedSpell = key
  AceConfigDialog:SelectGroup(addonName, "spells", groupKey(key))
end

local function addSpell(_, value)
  focusedInput = nil
  SpellOptions.input = value
  local id, err = SpellRules:Add(fPB.db.profile, value)
  SpellOptions.error = err
  if id then
    SpellOptions.input, SpellOptions.query = "", ""
    selectSpell(id)
    Options:Changed()
  else
    Options:Refresh()
  end
end

local function submitSpell()
  addSpell(nil, SpellOptions.input)
end

local function rememberFocus(widget, key)
  if widget.editbox:HasFocus() then
    focusedInput, inputCursor = key, widget.editbox:GetCursorPosition()
  end
end

local function searchChanged(widget, _, value)
  rememberFocus(widget, "search")
  setSearch(nil, value)
end

local function inputChanged(widget, _, value)
  SpellOptions.input = value
  if value == "" and SpellOptions.error then
    SpellOptions.error = nil
    rememberFocus(widget, "input")
    Options:Refresh()
  end
end

local function removeSpell(info)
  if spellRule(info) then
    SpellRules:Remove(fPB.db.profile, ruleKey(info))
    Options.selectedSpell = nil
    Options:Changed()
  end
end

local function getID(info)
  local rule = spellRule(info)
  return rule and tostring(rule.spellID or ruleKey(info)) or ""
end

local function replaceID(info, value)
  if not spellRule(info) then
    return
  end
  local id, err = SpellRules:Replace(fPB.db.profile, ruleKey(info), value)
  SpellOptions.error = err
  if id then
    SpellOptions.query = ""
    selectSpell(id)
    Options:Changed()
  else
    Options:Refresh()
  end
end

local function getAllRanks(info)
  local rule = spellRule(info)
  return rule and not rule.checkID and rule.allRanks ~= false or false
end

local function setAllRanks(info, value)
  local rule = spellRule(info)
  if rule then
    rule.allRanks, rule.checkID = value, not value
    Options:Changed()
  end
end

local function exactDisabled(info)
  local rule = spellRule(info)
  return not rule or not tonumber(rule.spellID or ruleKey(info))
end

local function spellLabel(rule, name)
  local color = "|cFFFFFF00"
  if rule.show == 1 then
    color = "|cFF00FF00"
  elseif rule.show == 3 then
    color = "|cFFFF0000"
  end
  return color .. name .. "|r"
end

local function editorGroup(key, rule, name, order)
  local args = {
    show = Controls:Select(
      "Show",
      1,
      { L["Always"], L["Only mine"], L["Never"], L["On ally only"], L["On enemy only"] }
    ),
    scale = Controls:Range("Icon scale", 2, 0.1, 5, 0.05),
    stackSize = Controls:Range("Stack font size", 3, 6, 40),
    durationSize = Controls:Range("Duration font size", 4, 6, 40),
    spellID = {
      type = "input",
      name = L["Spell ID"],
      order = 5,
      width = Controls:Width(L["Spell ID"]),
      get = getID,
      set = replaceID,
    },
    remove = {
      type = "execute",
      name = L["Remove spell"],
      order = 8,
      confirm = true,
      func = removeSpell,
    },
  }
  if SpellRanks.available then
    args.allRanks = Controls:Toggle("Include all ranks", 6)
    args.allRanks.get, args.allRanks.set = getAllRanks, setAllRanks
  elseif not Client.modern then
    args.checkID = Controls:Toggle("Check spell ID", 6)
    args.checkID.disabled = exactDisabled
  end
  if Client.modern then
    args.note = Controls:Description(
      "Spell rules apply to enemy debuffs and friendly buffs. Use the applied aura's ID when it differs from the casting spell.",
      7
    )
  end
  args.visibility = Controls:Row(1, { show = args.show, scale = args.scale })
  args.fonts = Controls:Row(2, { stackSize = args.stackSize, durationSize = args.durationSize })
  args.identity = Controls:Row(3, { spellID = args.spellID, allRanks = args.allRanks, checkID = args.checkID })
  args.show, args.scale, args.stackSize, args.durationSize = nil, nil, nil, nil
  args.spellID, args.allRanks, args.checkID = nil, nil, nil
  return {
    type = "group",
    name = spellLabel(rule, name),
    icon = GetSpellTexture(tonumber(rule.spellID or key) or 0),
    order = order,
    arg = key,
    get = getRule,
    set = setRule,
    args = args,
  }
end

function SpellOptions:Build()
  local profile = fPB.db.profile
  local keys, entries = SpellSearch:List(profile, SpellOptions.query)
  local args = {
    input = {
      type = "input",
      name = "",
      desc = L["Add by spell name or ID"],
      order = 2,
      width = 1.5,
      get = getInput,
      set = addSpell,
    },
    search = {
      type = "input",
      name = "",
      desc = L["Search spells by name or ID"],
      order = 1,
      width = 1.5,
      get = getSearch,
      set = setSearch,
    },
    add = { type = "execute", name = L["Add"], order = 3, width = "half", func = submitSpell },
    searchSpacing = Controls:Spacer(1.5),
    inputSpacing = Controls:Spacer(2.5),
  }
  if SpellOptions.error then
    args.error = Controls:Description(SpellOptions.error, 4)
  end
  for index, key in ipairs(keys) do
    args[groupKey(key)] = editorGroup(key, profile.Spells[key], entries[key].name, index + 10)
  end
  if #keys == 0 then
    args.empty = Controls:Description("No matching spells.", 5)
  end
  return { type = "group", name = L["Spells"], order = 5, childGroups = "tree", args = args }
end

function SpellOptions:ClearInputFocus()
  focusedInput = nil
end

function SpellOptions:BindInputs(container)
  for _, widget in ipairs(container.children or {}) do
    if widget.type == "EditBox" then
      local path = widget:GetUserDataTable().path
      local key = path[#path]
      if key == "input" or key == "search" then
        widget:DisableButton(true)
        InputPlaceholder:Attach(
          widget,
          L[key == "input" and "Add by spell name or ID" or "Search spells by name or ID"]
        )
        widget:SetCallback("OnTextChanged", key == "input" and inputChanged or searchChanged)
        if focusedInput == key then
          focusedInput = nil
          widget:SetFocus()
          widget.editbox:SetCursorPosition(inputCursor)
        end
      end
    end
  end
end
