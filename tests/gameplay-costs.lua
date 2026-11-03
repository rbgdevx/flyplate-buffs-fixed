-- Fixtures verify contracts and avoided calls, not native performance or rendering.
local H = dofile("tests/helpers.lua")

local function createFixture(interface, neutral)
  local state = H.environment(interface)
  if neutral then
    state.env.UnitReaction = function()
      return 4
    end
  end
  local assist = state.env.UnitCanAssist
  local attack = state.env.UnitCanAttack
  local calls = { assist = 0, attack = 0 }
  state.env.UnitCanAssist = function(...)
    calls.assist = calls.assist + 1
    return assist(...)
  end
  state.env.UnitCanAttack = function(...)
    calls.attack = calls.attack + 1
    return attack(...)
  end
  H.loadAddon(state)
  return state, calls
end

local function checkEligibility(state)
  local units, profile = state.ns.Units, state.ns.db.profile
  local allowed, friendly = units:IsAllowed("friendly", profile)
  H.equal(allowed, profile.showOnFriend)
  H.equal(friendly, true)
  allowed, friendly = units:IsAllowed("enemy", profile)
  H.equal(allowed, profile.showOnEnemy)
  H.equal(friendly, false)

  state.env.UnitReaction = function()
    return 4
  end
  -- Units captures globals when it loads; reload only this isolated module.
  state.load("core/units.lua")
  allowed, friendly = state.ns.Units:IsAllowed("neutral", profile)
  H.equal(allowed, profile.showOnNeutral)
  H.equal(friendly, nil)
  profile.targetOnly = true
  allowed, friendly = state.ns.Units:IsAllowed("enemy", profile)
  H.equal(allowed, false)
  H.equal(friendly, nil)
end

local function checkRuntimeQueries(interface)
  local state, calls = createFixture(interface)
  for _, unit in ipairs({ "friendly", "enemy" }) do
    state:addPlate(unit)
    calls.assist, calls.attack = 0, 0
    state.ns.Runtime:AddUnit(unit)
    H.equal(calls.assist, 1, "one assist query for each allowed update")
    H.equal(calls.attack, unit == "friendly" and 1 or 0)
    state.ns.Runtime:RemoveUnit(unit)
    calls.assist, calls.attack = 0, 0
    state.ns.Runtime:AddUnit(unit)
    H.equal(calls.assist, 1, "reused plates also classify once")
  end

  local neutral, neutralCalls = createFixture(interface, true)
  neutral:addPlate("neutral")
  neutralCalls.assist, neutralCalls.attack = 0, 0
  neutral.ns.Runtime:AddUnit("neutral")
  H.equal(neutralCalls.assist, 1, "neutral eligibility falls back to relationship classification")

  state.ns.db.profile.targetOnly = true
  state.ns.Settings:Apply()
  calls.assist, calls.attack = 0, 0
  state.ns.Runtime:UpdateUnit("enemy")
  H.equal(calls.assist, 0, "early rejection performs no relationship query")
end

local function checkCandidateCreation(interface)
  local state = H.environment(interface)
  H.loadAddon(state)
  local ns = state.ns
  local appearance = ns.Appearance:Build(ns.db.profile)
  local resources = ns.StyleResources:Build(appearance.style)
  local cases = {
    { candidates = {}, omitted = true },
    { candidates = { includeSpellIDs = {} } },
    { candidates = { includeSpellIDs = { [589] = true } } },
    { candidates = { isStealable = false } },
  }
  for _, case in ipairs(cases) do
    local plate = state:addPlate("candidate-fixture")
    local group = H.copy(ns.ModernRules:Build(ns.db.profile, false)[1])
    group.candidates = case.candidates
    local container = ns.AuraContainer:Create(plate, appearance, { group }, resources)
    local actual = container.frame.groups["1"].options.candidateFilters
    if case.omitted then
      H.equal(actual, nil)
    else
      H.equal(actual, case.candidates)
    end
    H.equal(group.candidates, case.candidates, "recipe shape is preserved")
  end
end

for _, interface in ipairs({ 120105, 16001, 50504, 20506, 11509 }) do
  local state = createFixture(interface)
  checkEligibility(state)
  if state.ns.Client.modern then
    checkRuntimeQueries(interface)
    checkCandidateCreation(interface)
  end
end
print("Gameplay-cost contract checks passed")
