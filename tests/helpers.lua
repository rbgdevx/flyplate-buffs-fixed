local Helpers = {}

function Helpers.equal(actual, expected, message)
  assert(
    actual == expected,
    (message or "Mismatch") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
  )
end

function Helpers.copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, child in pairs(value) do
    result[key] = Helpers.copy(child)
  end
  return result
end

function Helpers.environment(interface, saved)
  local env = setmetatable({}, { __index = _G })
  env._G = env
  env.unpack = table.unpack
  local state = { frames = {}, plates = {}, auras = {}, cvars = {}, time = 100, combat = false, secret = false }
  local ns = {}
  local methods = {}
  local function frame(name, parent)
    local object = setmetatable(
      { scripts = {}, groups = {}, visible = true, width = 24, height = 24, name = name, parent = parent },
      { __index = methods }
    )
    if name then
      state.frames[name] = object
    end
    return object
  end
  for _, method in ipairs({
    "RegisterEvent",
    "UnregisterEvent",
    "SetPoint",
    "ClearAllPoints",
    "SetAllPoints",
    "SetTexture",
    "SetTexCoord",
    "SetColorTexture",
    "SetVertexColor",
    "SetDrawEdge",
    "SetReverse",
    "SetSwipeColor",
    "SetHideCountdownNumbers",
    "SetDrawSwipe",
    "SetFont",
    "SetTextColor",
    "SetIcon",
    "SetMouseClickEnabled",
    "SetMouseMotionEnabled",
    "SetHideTooltipInCombat",
    "SetTooltipAnchorPoint",
    "SetDurationText",
    "ClearDurationText",
    "SetApplicationCount",
    "ClearApplicationCount",
    "SetDurationCooldown",
    "ClearDurationCooldown",
    "ClearDispelTypeTextures",
    "AddDispelTypeTexture",
    "SetFlowLayoutMaximumLineSize",
    "SetFlowLayoutAnchorPoint",
    "SetFlowLayoutGrowthDirection",
    "SetAuraGroupLayout",
    "SetTitle",
    "SetStatusText",
    "SetLayout",
    "SetLabel",
    "SetValue",
    "EnableMouse",
    "SetUnitAuraByAuraInstanceID",
  }) do
    methods[method] = function() end
  end
  function methods:SetScript(name, callback)
    self.scripts[name] = callback
  end
  function methods:SetCallback(name, callback)
    self.scripts[name] = callback
  end
  function methods:Show()
    self.visible = true
  end
  function methods:Hide()
    self.visible = false
  end
  function methods:SetShown(shown)
    self.visible = shown
  end
  function methods:IsShown()
    return self.visible
  end
  function methods:IsForbidden()
    return self.forbidden or false
  end
  function methods:SetSize(width, height)
    self.width, self.height = width, height
  end
  function methods:SetWidth(width)
    self.width = width
  end
  function methods:SetHeight(height)
    self.height = height
  end
  function methods:GetWidth()
    return self.width
  end
  function methods:GetHeight()
    return self.height
  end
  function methods:SetParent(parent)
    self.parent = parent
  end
  function methods:GetParent()
    return self.parent
  end
  function methods:SetAlpha(alpha)
    self.alpha = alpha
  end
  function methods:GetFrameLevel()
    return self.level or 1
  end
  function methods:SetFrameLevel(level)
    self.level = level
  end
  function methods:CreateTexture()
    return frame(nil, self)
  end
  function methods:CreateFontString()
    return frame(nil, self)
  end
  function methods:GetCountdownFontString()
    self.countdown = self.countdown or frame(nil, self)
    return self.countdown
  end
  function methods:SetText(value)
    self.text = value
  end
  function methods:GetText()
    return self.text
  end
  function methods:GetStringWidth()
    return #(self.text or "") * 7 -- Layout fixture only; real labels are measured by the client.
  end
  function methods:SetCooldown(start, duration)
    self.cooldown = { start, duration }
    self.paused = false
  end
  function methods:Clear()
    self.cooldown = nil
  end
  function methods:Pause()
    self.paused = true
  end
  function methods:Resume()
    self.paused = false
  end
  function methods:SetEnabled(enabled)
    self.enabled = enabled
  end
  function methods:SetUnit(unit)
    self.unit = unit
  end
  function methods:GetUnit()
    return self.unit
  end
  function methods:SetOwner(owner)
    self.owner = owner
  end
  function methods:IsOwned(owner)
    return self.owner == owner
  end
  function methods:AddLine(line)
    self.line = line
  end
  function methods:AddChild(child)
    self.child = child
  end
  function methods:AddAuraGroup(key, filter, options)
    assert(options.sortMethod ~= nil and options.sortDirection ~= nil)
    self.groups[key] = { filter = filter, options = options, frames = {} }
    local button = frame(nil, self)
    options.initializeFrame(button)
    self.groups[key].frames[1] = button
  end
  function methods:SetAuraGroupFilterString(key, filter)
    self.groups[key].filter = filter
  end
  function methods:SetAuraGroupCandidateFilters(key, candidates)
    self.groups[key].options.candidateFilters = candidates
  end
  function methods:SetAuraGroupMaxFrameCount(key, count)
    self.groups[key].options.maxFrameCount = count
  end
  function methods:SetAuraGroupSortMethod(key, method)
    assert(method ~= nil)
    self.groups[key].options.sortMethod = method
  end
  function methods:GetAuraGroupFrameCount(key)
    return #self.groups[key].frames
  end
  function methods:GetAuraGroupFrame(key, index)
    return self.groups[key].frames[index]
  end
  function env.CreateFrame(_, name, parent)
    local result = frame(name, parent)
    state.created = state.created or {}
    table.insert(state.created, result)
    return result
  end
  env.UIParent, env.WorldFrame, env.GameTooltip = frame(), frame(), frame()
  env.GameTooltip.Hide = methods.Hide
  env.GetBuildInfo = function()
    return "test", "1", "date", interface
  end
  env.GetRealmName = function()
    return "Realm"
  end
  env.UnitName = function()
    return "Tester"
  end
  env.UnitNameUnmodified = function()
    return "Tester", interface == 16001 and "Surname" or nil
  end
  env.RegionalUniqueNamesEnabled = function()
    return interface == 16001
  end
  env.UnitFactionGroup = function()
    return "Alliance"
  end
  env.UnitClass = function()
    return "Mage", "MAGE"
  end
  env.UnitRace = function()
    return "Human", "Human"
  end
  env.GetLocale = function()
    return "enUS"
  end
  env.GetCurrentRegion = function()
    return 1
  end
  env.GetCurrentRegionName = function()
    return "US"
  end
  env.strlenutf8 = string.len
  env.C_Timer = {
    After = function(_, callback)
      callback()
    end,
  }
  env.GetTime = function()
    return state.time
  end
  env.InCombatLockdown = function()
    return state.combat
  end
  env.UnitAffectingCombat = function()
    return state.combat
  end
  env.UnitIsUnit = function(a, b)
    return a == b
  end
  env.UnitIsPlayer = function(unit)
    return unit == "player"
  end
  env.UnitPlayerControlled = function(unit)
    return unit == "player"
  end
  env.UnitCanAttack = function(_, unit)
    return unit ~= "friendly" and unit ~= "player"
  end
  env.UnitCanAssist = function(_, unit)
    return unit == "friendly" or unit == "player"
  end
  env.UnitReaction = function(_, unit)
    return unit == "friendly" and 5 or 3
  end
  env.GetUnitName = function(unit)
    return unit
  end
  env.wipe = function(t)
    for key in pairs(t) do
      t[key] = nil
    end
  end
  env.CopyTable = Helpers.copy
  env.securecallfunction = function(callback, ...)
    return callback(...)
  end
  env.GenerateClosure = function(callback, ...)
    local bound = table.pack(...)
    return function(...)
      local args = table.pack(...)
      local all = {}
      for i = 1, bound.n do
        all[i] = bound[i]
      end
      for i = 1, args.n do
        all[bound.n + i] = args[i]
      end
      return callback(table.unpack(all, 1, bound.n + args.n))
    end
  end
  state.hooks = {}
  env.hooksecurefunc = function(target, name, callback)
    if type(target) == "table" then
      local original = target[name]
      target[name] = function(...)
        local results = table.pack(original(...))
        callback(...)
        return table.unpack(results, 1, results.n)
      end
    else
      state.hooks[target] = name
    end
  end
  env.CompactUnitFrame_IsTapDenied = function()
    return state.tapDenied
  end
  env.CompactUnitFrame_IsOnThreatListWithPlayer = function()
    return state.threat
  end
  env.UnitSelectionColor = function()
    return 0, 1, 0
  end
  env.tCompare = function(a, b)
    if type(a) ~= type(b) then
      return false
    end
    if type(a) ~= "table" then
      return a == b
    end
    for k, v in pairs(a) do
      if not env.tCompare(v, b[k]) then
        return false
      end
    end
    for k in pairs(b) do
      if a[k] == nil then
        return false
      end
    end
    return true
  end
  env.SlashCmdList = {}
  env.Enum = {
    GameRule = {},
    TooltipDataType = { Spell = 1 },
    DurationTextBindingProperty = { RemainingPercent = 1 },
    CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 1 },
  }
  env.C_GameRules = {
    IsGameRuleActive = function()
      return false
    end,
  }
  env.TooltipDataProcessor = { AddTooltipPostCall = function() end }
  env.AuraContainerSortMethod =
    { Default = 0, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
  env.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
  env.AnchorUtil = { FlowDirection = { Right = 1, Up = 2 } }
  env.CreateColor = function(...)
    return { ... }
  end
  env.C_CurveUtil = {
    CreateColorCurve = function()
      return { AddPoint = function() end }
    end,
  }
  env.C_StringUtil = {
    CreateNumericRuleFormatter = function()
      return { AddBreakpoint = function() end }
    end,
  }
  env.C_Secrets = interface >= 120000 or interface == 16001 and {} or nil
  if env.C_Secrets then
    env.C_Secrets = {
      ShouldAurasBeSecret = function()
        return state.secret
      end,
      CanCompareUnitTokens = function()
        return true
      end,
      ShouldUnitComparisonBeSecret = function()
        return false
      end,
    }
  end
  local names = {
    [589] = "Shadow Word: Pain",
    [594] = "Shadow Word: Pain",
    [970] = "Shadow Word: Pain",
    [118] = "Polymorph",
    [8835] = "Grace of Air Totem",
  }
  env.C_AddOns = {
    GetAddOnMetadata = function()
      return "test-version"
    end,
  }
  env.C_Spell = {
    GetSpellInfo = function(value)
      if type(value) == "string" then
        if value == "Shadow Word: Pain" then
          value = 589
        else
          return nil
        end
      end
      if type(value) ~= "number" or value <= 0 or value == 999999999 then
        return nil
      end
      return { spellID = value, name = names[value] or "Spell " .. value, iconID = value }
    end,
    GetSpellName = function(id)
      local info = env.C_Spell.GetSpellInfo(id)
      return info and info.name
    end,
    GetSpellTexture = function(id)
      return id
    end,
  }
  env.C_CVar = {
    GetCVar = function(key)
      return state.cvars[key]
    end,
    GetCVarDefault = function(key)
      return state.cvars[key] and "1"
    end,
    SetCVar = function(key, value)
      state.cvars[key] = tostring(value)
    end,
  }
  env.C_NamePlate = {
    GetNamePlateForUnit = function(unit)
      return state.plates[unit]
    end,
    GetNamePlates = function()
      local list = {}
      for _, plate in pairs(state.plates) do
        list[#list + 1] = plate
      end
      return list
    end,
  }
  env.C_UnitAuras = {
    GetUnitAuras = function(unit, filter)
      assert(not ns.Client.modern, "Modern runtime read live aura records")
      local result = {}
      for _, aura in pairs(state.auras[unit] or {}) do
        if aura.isHelpful == (filter == "HELPFUL") then
          result[#result + 1] = aura
        end
      end
      return result
    end,
    GetAuraDataByAuraInstanceID = function(unit, id)
      return state.auras[unit][id]
    end,
  }
  env.flyPlateBuffsFixedDB = Helpers.copy(saved)
  local function load(path)
    return assert(loadfile(path, "t", env))("flyPlateBuffsFixed", ns)
  end
  load("libs/LibStub/LibStub.lua")
  load("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
  load("libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
  local registry = env.LibStub("AceConfigRegistry-3.0")
  local config = env.LibStub:NewLibrary("AceConfig-3.0", 999)
  function config:RegisterOptionsTable(name, options)
    registry:RegisterOptionsTable(name, options)
  end
  local dialog = env.LibStub:NewLibrary("AceConfigDialog-3.0", 999)
  for _, method in ipairs({ "SetDefaultSize", "AddToBlizOptions", "Open", "FeedGroup" }) do
    dialog[method] = function() end
  end
  dialog.OpenFrames = {}
  local dialogStatus = {}
  function dialog:GetStatusTable(appName, path)
    local key = appName .. ":" .. table.concat(path or {}, ":")
    dialogStatus[key] = dialogStatus[key] or {}
    return dialogStatus[key]
  end
  function dialog:SelectGroup(appName, ...)
    state.dialogSelection = { ... }
    state.dialogApp = appName
  end
  local media = env.LibStub:NewLibrary("LibSharedMedia-3.0", 999)
  function media:List()
    return { "Friz Quadrata TT" }
  end
  function media:Fetch()
    return "Fonts/FRIZQT__.TTF"
  end
  function media.RegisterCallback() end
  local gui = env.LibStub:NewLibrary("AceGUI-3.0", 999)
  function gui:Create()
    local widget = frame()
    widget.frame = frame()
    widget.content = frame()
    return widget
  end
  state.load, state.env, state.ns, state.registry = load, env, ns, registry
  function state:addPlate(unit)
    local plate = frame()
    plate.unit = unit
    plate.UnitFrame = frame()
    plate.UnitFrame.AurasFrame = frame()
    self.plates[unit] = plate
    self.auras[unit] = self.auras[unit] or {}
    return plate
  end
  return state
end

function Helpers.loadAddon(state)
  for line in io.lines("flyPlateBuffsFixed.toc") do
    if line:match("%.lua$") and not line:match("^libs/") then
      state.load(line)
    elseif line == "libs/SpellRankData/Forever.lua" then
      state.load(line)
    elseif line == "runtime/[Family]/load.xml" then
      local family = state.ns.Client.modern and "Mainline" or "Classic"
      for entry in io.lines("runtime/" .. family .. "/load.xml") do
        local path = entry:match('file="(.-)"')
        if path then
          state.load("runtime/" .. family .. "/" .. path)
        end
      end
    end
  end
  state.frames.flyPlateBuffsFixedFrame.scripts.OnEvent(nil, "ADDON_LOADED", "flyPlateBuffsFixed")
end

return Helpers
