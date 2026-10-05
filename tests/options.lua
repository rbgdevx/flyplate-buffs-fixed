local H = dofile("tests/helpers.lua")

for _, interface in ipairs({ 11509, 20506, 50504, 120100, 16001 }) do
  local state = H.environment(interface, {
    version = 2,
    profiles = {
      Default = {
        Spells = {
          [589] = { name = "Shadow Word: Pain", spellID = 589, show = 1, scale = 1.2 },
          [594] = { name = "Shadow Word: Pain", spellID = 594, show = 3, scale = 1.6 },
          ["589"] = { name = "Saved name rule", spellID = 970, show = 2, scale = 1.4 },
        },
      },
    },
  })
  H.loadAddon(state)
  local ns = state.ns
  local dialog = state.env.LibStub("AceConfigDialog-3.0")
  local function build()
    local options = state.registry:GetOptionsTable("flyPlateBuffsFixed")("dialog", "Test-1.0")
    state.registry:ValidateOptionsTable(options, "FPB")
    return options
  end
  local options = build()
  local spells = options.args.spells
  local first = spells.args["number:589"]
  H.equal(spells.childGroups, "tree")
  H.equal(first.arg, 589)
  H.equal(spells.args["string:589"].arg, "589", "numeric and legacy string keys remain distinct")
  -- AceConfig calls FeedGroup for a selected tree node, then its enclosing groups.
  dialog:FeedGroup("flyPlateBuffsFixed", options, nil, nil, { "spells", "number:589" })
  dialog:FeedGroup("flyPlateBuffsFixed", options, { children = {} }, nil, { "spells" })
  dialog:FeedGroup("flyPlateBuffsFixed", options, {}, nil, {})
  H.equal(ns.Options.selectedSpell, 589, "preview follows the displayed rule")
  H.equal(ns.Options.selectedPage, "spells")
  dialog:FeedGroup("OtherAddon", {}, nil, nil, { "other" })
  H.equal(ns.Options.selectedSpell, 589, "other addons cannot change the preview")
  dialog:FeedGroup("flyPlateBuffsFixed", options, nil, nil, { "spells", "number:594" })
  H.equal(ns.Options.selectedSpell, 594)
  -- Editor callbacks address the displayed group's key, never a stale preview selection.
  local info = { "spells", "number:589", "scale", options = options }
  first.set(info, 1.8)
  H.equal(ns.db.profile.Spells[589].scale, 1.8)
  H.equal(ns.db.profile.Spells[594].scale, 1.6)
  H.equal(first.get(info), 1.8)
  dialog:FeedGroup("flyPlateBuffsFixed", options, nil, nil, { "display" })
  H.equal(ns.Options.selectedSpell, nil, "other tabs return to the general preview")
  H.equal(ns.Options.selectedPage, "display")
  spells.args.search.set(nil, "no matching spell")
  H.equal(ns.Options.selectedSpell, nil)
  options = build()
  assert(options.args.spells.args.empty)
  local methods = getmetatable(state.env.UIParent).__index
  function methods:SetJustifyH() end
  function methods:SetWordWrap() end
  function methods:IsVisible()
    return self.visible
  end
  function methods:HasFocus()
    return self.focus
  end
  function methods:HookScript(key, callback)
    local previous = self.scripts[key]
    self.scripts[key] = function(...)
      if previous then
        previous(...)
      end
      callback(...)
    end
  end
  local function inputWidget(key, focused, cursor)
    local widget = { type = "EditBox", callbacks = {}, user = { path = { "spells", key } } }
    widget.editbox = state.env.CreateFrame("EditBox")
    widget.editbox.focus = focused
    widget.editbox:SetText("")
    local create = widget.editbox.CreateFontString
    function widget.editbox:CreateFontString(...)
      widget.placeholder = create(self, ...)
      return widget.placeholder
    end
    function widget.editbox:GetCursorPosition()
      return cursor
    end
    function widget.editbox:SetCursorPosition(value)
      widget.cursor = value
    end
    function widget:GetUserDataTable()
      return self.user
    end
    function widget:DisableButton(value)
      self.buttonDisabled = value
    end
    function widget:SetCallback(event, callback)
      self.callbacks[event] = callback
    end
    function widget:SetFocus()
      self.focused = true
      self.editbox.focus = true
      self.editbox.scripts.OnEditFocusGained()
    end
    return widget
  end
  local search, input = inputWidget("search", true, 3), inputWidget("input")
  ns.SpellOptions:BindInputs({ children = { search, input } })
  assert(search.buttonDisabled and input.buttonDisabled)
  assert(input.placeholder:IsShown() and not search.placeholder:IsShown())
  input.editbox.focus = true
  input.editbox.scripts.OnEditFocusGained()
  assert(not input.placeholder:IsShown())
  input.editbox.focus = false
  input.editbox.scripts.OnEditFocusLost()
  assert(input.placeholder:IsShown())
  input.editbox:SetText("118")
  input.editbox.scripts.OnTextChanged()
  assert(not input.placeholder:IsShown())
  input.editbox:SetText("")
  input.user = {}
  input.editbox.scripts.OnShow()
  assert(not input.placeholder:IsShown(), "Ace-pooled inputs do not retain FPB placeholders for other consumers")
  search.callbacks.OnTextChanged(search, "OnTextChanged", "Pain")
  H.equal(ns.SpellOptions.query, "Pain", "search updates without pressing Enter")
  local refreshedSearch = inputWidget("search")
  ns.SpellOptions:BindInputs({ children = { refreshedSearch } })
  assert(refreshedSearch.focused and refreshedSearch.cursor == 3)
  search.callbacks.OnTextChanged(search, "OnTextChanged", "Pain")
  dialog:FeedGroup("flyPlateBuffsFixed", options, nil, nil, { "display" })
  local returningSearch = inputWidget("search")
  ns.SpellOptions:BindInputs({ children = { returningSearch } })
  assert(not returningSearch.focused, "switching tabs clears pending input focus")
  input.callbacks.OnTextChanged(input, "OnTextChanged", "not a spell")
  options.args.spells.args.add.func()
  assert(ns.SpellOptions.error)
  input.callbacks.OnTextChanged(input, "OnTextChanged", "")
  H.equal(ns.SpellOptions.error, nil, "clearing Add clears its error")
  input.callbacks.OnTextChanged(input, "OnTextChanged", "118")
  options.args.spells.args.add.func()
  H.equal(ns.Options.selectedSpell, 118)
  H.equal(state.dialogSelection[1], "spells")
  H.equal(state.dialogSelection[2], "number:118", "add selects the new rule and clears the search")
  options = build()
  assert(options.args.spells.args["number:118"])
  local removeInfo = { "spells", "number:118", "remove", options = options }
  local removedGroup = options.args.spells.args["number:118"]
  assert(removedGroup.args.remove.confirm)
  removedGroup.args.remove.func(removeInfo)
  H.equal(ns.db.profile.Spells[118], nil, "confirmed removal persists immediately")
  H.equal(ns.db.profile.ignoredDefaultSpells[118], true)
  removedGroup.args.remove.func(removeInfo)
  H.equal(removedGroup.get(removeInfo), nil, "late callbacks safely see the removed rule")
  local idInfo = { "spells", "number:589", "spellID", options = options }
  options.args.spells.args["number:589"].args.identity.args.spellID.set(idInfo, "970")
  H.equal(ns.db.profile.Spells[589], nil)
  H.equal(ns.db.profile.Spells[970].scale, 1.8)
  H.equal(ns.db.profile.Spells["589"].scale, 1.4, "ID replacement keeps the unrelated legacy key")
  H.equal(state.dialogSelection[2], "number:970")
  options = build()
  local display = options.args.display.args
  if ns.Client.modern then
    -- Moving fields into sections must preserve the existing profile keys and inheritance.
    local debuffs = { "display", "enemyDebuffs", "showDebuffs" }
    local buffs = { "display", "friendlyBuffs", "showBuffs" }
    assert(display.enemyDebuffs.args.show.args.showDebuffs and display.friendlyBuffs.args.show.args.showBuffs)
    options.set(debuffs, 4)
    options.set(buffs, 3)
    H.equal(ns.db.profile.showDebuffs, 4)
    H.equal(ns.db.profile.showBuffs, 3)
    H.equal(options.get(debuffs), 4)
    H.equal(display.enemyBuffs.args.show.args.mode.get(), "inherit")
    H.equal(display.friendlyDebuffs.args.show.args.mode.get(), "inherit")
    display.friendlyDebuffs.args.show.args.mode.set(nil, "categories")
    display.friendlyDebuffs.args.crowdControl.set(nil, true)
    H.equal(ns.db.profile.modernFriendlyDebuffs.categories.crowdControl, true)
    assert(display.friendlyDebuffs.args.crowdControl.get())
    assert(not display.enemyBuffs.args.crowdControl)
    assert(not display.friendlyDebuffs.args.stealable)
    H.equal(display.enemyDebuffs.args.crowdControl.get(), true)
    H.equal(display.friendlyBuffs.args.defensive.get(), true)
    display.enemyDebuffs.args.crowdControl.set(nil, false)
    display.friendlyBuffs.args.defensive.set(nil, false)
    H.equal(ns.db.profile.enemyDebuffCategories.crowdControl, false)
    H.equal(ns.db.profile.friendlyBuffCategories.defensive, false)
    assert(not display.enemyDebuffs.args.defensive and not display.friendlyBuffs.args.crowdControl)
    assert(not display.friendlyDebuffs.args.crowdControl.disabled())
    state.combat = true
    assert(display.friendlyDebuffs.args.crowdControl.disabled(), "category controls keep the restriction")
  else
    assert(display.debuffsRow.args.showDebuffs and display.buffsRow.args.showBuffs)
    local editor = options.args.spells.args["number:970"]
    state.combat = true
    assert(not editor.args.identity.args.checkID.disabled({ "spells", "number:970", "checkID", options = options }))
  end
  print("Spell tree callbacks, preview selection and display settings:", interface)
end
