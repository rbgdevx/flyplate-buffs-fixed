local _, fPB = ...

local ipairs = ipairs
local pairs = pairs
local CreateFrame = CreateFrame
local GetTimePreciseSec = GetTimePreciseSec
local tremove = table.remove

local AuraContainer = fPB.AuraContainer
local Restrictions = fPB.Restrictions

local Reserve = {}
fPB.Reserve = Reserve

local parking = CreateFrame("Frame")
parking:Hide()
local preparation = CreateFrame("Frame")
local roles = { "friendly", "enemy" }
local pools = { friendly = { all = {}, free = {} }, enemy = { all = {}, free = {} } }
local profile, recipes, resources, pending
local capacity = 41

local function createContainer(role)
  local state = AuraContainer:Create(parking, profile, recipes[role], resources)
  state.role = role
  local pool = pools[role]
  pool.all[#pool.all + 1] = state
  return state
end

local function finishPreparation()
  local free = pools[pending.role].free
  free[#free + 1] = pending
  pending = nil
end

local function beginPreparation(role)
  pending = AuraContainer:Create(parking, profile, {}, resources)
  pending.role = role

  local pool = pools[role]
  pool.all[#pool.all + 1] = pending
end

local function preparePool(role, started)
  local pool = pools[role]
  while pending or #recipes[role] > 0 and #pool.all < capacity do
    if not pending then
      beginPreparation(role)
    end

    if AuraContainer:PrepareGroup(pending, profile, recipes[pending.role], resources) then
      finishPreparation()
    end

    if GetTimePreciseSec() - started >= 0.003 then
      return true
    end
  end
  return false
end

local function prepare()
  if Restrictions:Active() then
    preparation:SetScript("OnUpdate", nil)
    return
  end

  local started = GetTimePreciseSec()
  for _, role in ipairs(roles) do
    if preparePool(role, started) then
      return
    end
  end
  preparation:SetScript("OnUpdate", nil)
end

local function configurePool(role, pool, previous, force)
  for _, state in ipairs(pool.all) do
    AuraContainer:ApplySettings(state, profile, recipes[role], previous, resources, force)
  end
end

function Reserve:Resume()
  if profile and not Restrictions:Active() then
    preparation:SetScript("OnUpdate", prepare)
  end
end

function Reserve:Configure(appearance, nextRecipes, nextResources, force)
  preparation:SetScript("OnUpdate", nil)
  local previous = recipes
  profile, recipes, resources = appearance, nextRecipes, nextResources

  for role, pool in pairs(pools) do
    configurePool(role, pool, previous and previous[role], force)
  end

  if pending then
    finishPreparation()
  end
  Reserve:Resume()
end

function Reserve:Acquire(role, plate)
  local state = tremove(pools[role].free)
  state = state or createContainer(role)
  AuraContainer:Attach(state, plate, profile)
  return state
end
