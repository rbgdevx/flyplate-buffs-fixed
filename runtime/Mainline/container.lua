local _, fPB = ...

local ipairs = ipairs
local next = next
local tCompare = tCompare
local tostring = tostring
local AuraContainerSortDirection = AuraContainerSortDirection
local AuraContainerSortMethod = AuraContainerSortMethod
local CreateFrame = CreateFrame
local GenerateClosure = GenerateClosure
local OnUpdateMode = Enum.OnUpdateMode
local mmax = math.max
local ssub = string.sub
local FlowDirection = AnchorUtil.FlowDirection

local Activation = fPB.Activation
local Style = fPB.Style

local AuraContainer = {}
fPB.AuraContainer = AuraContainer

local function initializeFrame(slot, button)
  Style:Initialize(button, slot.profile, slot.style, slot.resources, slot.helpful)
end

local function createGroup(state, key, index, group, profile, resources)
  local slot = {
    profile = profile,
    style = group.style,
    resources = resources,
    helpful = ssub(group.filter, 1, 7) == "HELPFUL",
  }
  state.groups[index] = slot

  state.frame:AddAuraGroup(key, group.filter, {
    candidateFilters = next(group.candidates) and group.candidates or nil,
    maxFrameCount = group.maxFrameCount,
    sortMethod = AuraContainerSortMethod[profile.sorting.method],
    sortDirection = profile.sorting.reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal,
    initializeFrame = GenerateClosure(initializeFrame, slot),
  })
end

local function restyleGroup(container, key, profile, group, resources, helpful)
  for index = 1, container:GetAuraGroupFrameCount(key) do
    Style:Apply(container:GetAuraGroupFrame(key, index), profile, group.style, resources, helpful)
  end
end

local function updateGroup(container, slot, key, group, previous, profile, resources, force)
  local sorting = profile.sorting
  local previousSorting = slot.profile.sorting
  local helpful = ssub(group.filter, 1, 7) == "HELPFUL"
  local restyle = force
    or slot.helpful ~= helpful
    or not tCompare(slot.profile.style, profile.style, 4)
    or not tCompare(slot.style, group.style, 1)
    or slot.profile.tooltip ~= profile.tooltip
    or slot.profile.tooltipInCombat ~= profile.tooltipInCombat
  slot.profile = profile
  slot.style = group.style
  slot.resources = resources
  slot.helpful = helpful

  container:SetAuraGroupFilterString(key, group.filter)
  if not previous or not tCompare(previous.candidates, group.candidates, 2) then
    container:SetAuraGroupCandidateFilters(key, group.candidates)
  end

  container:SetAuraGroupMaxFrameCount(key, group.maxFrameCount)
  if sorting.method ~= previousSorting.method or sorting.reverse ~= previousSorting.reverse then
    container:SetAuraGroupSortMethod(
      key,
      AuraContainerSortMethod[sorting.method],
      sorting.reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
    )
  end

  if restyle then
    restyleGroup(container, key, profile, group, resources, helpful)
  end
end

local function positionContainer(state, profile)
  local container = state.frame
  local position = profile.position
  container:ClearAllPoints()
  container:SetPoint(position.anchor, state.plate, position.relativeAnchor, position.x, position.y)
  container:SetFlowLayoutMaximumLineSize(
    mmax(profile.style.width, position.perRow * profile.style.width + (position.perRow - 1) * position.gapX)
  )
  container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
  container:SetFlowLayoutGrowthDirection(FlowDirection.Right, FlowDirection.Up)
end

local function layoutGroup(container, key, index, position)
  container:SetAuraGroupLayout(key, {
    elementSpacing = position.gapX,
    lineSpacing = position.gapY,
    groupSpacing = 0,
    groupLineSpacing = 0,
    layoutIndex = index,
  })
end

local function configureGroup(state, profile, group, index, previous, resources, force)
  local container = state.frame
  local key = tostring(index)
  local slot = state.groups[index]
  local resized = slot
    and (
      slot.style.scale ~= group.style.scale
      or slot.profile.style.width ~= profile.style.width
      or slot.profile.style.height ~= profile.style.height
    )

  if slot then
    updateGroup(container, slot, key, group, previous, profile, resources, force)
  else
    createGroup(state, key, index, group, profile, resources)
  end

  if not state.layout or not tCompare(state.layout, profile.position, 1) or resized or not slot then
    layoutGroup(container, key, index, profile.position)
  end

  if container.SetAuraGroupEnabled and not container:IsAuraGroupEnabled(key) then
    container:SetAuraGroupEnabled(key, true)
  end
end

local function disableGroups(state, first)
  local container = state.frame
  for index = first, #state.groups do
    local key = tostring(index)
    if container.SetAuraGroupEnabled then
      if container:IsAuraGroupEnabled(key) then
        container:SetAuraGroupEnabled(key, false)
      end
    else
      container:SetAuraGroupMaxFrameCount(key, 0)
    end
  end
end

local function configure(state, profile, recipe, previousRecipe, resources, force)
  if not state.position or not tCompare(state.position, profile.position, 1) or state.width ~= profile.style.width then
    positionContainer(state, profile)
    state.position, state.width = profile.position, profile.style.width
  end

  for index, group in ipairs(recipe) do
    configureGroup(state, profile, group, index, previousRecipe and previousRecipe[index], resources, force)
  end
  state.layout = profile.position

  disableGroups(state, #recipe + 1)
end

function AuraContainer:Create(plate, profile, recipe, resources)
  local container = CreateFrame("AuraContainer", nil, plate, "CustomAuraContainerTemplate")
  container:SetEnabled(false)
  container:Hide()
  container:SetFlattensRenderLayers(true)

  local state = { frame = container, plate = plate, groups = {} }
  configure(state, profile, recipe, nil, resources)

  return state
end

function AuraContainer:SetEnabled(state, enabled)
  local container = state.frame
  local changed = container:IsEnabled() ~= enabled
  container:SetEnabled(enabled)
  if enabled then
    Activation:Show(state)
  else
    Activation:Hide(state)
  end

  if changed and not enabled then
    container:SetOnUpdateMode(OnUpdateMode.RunOnce)
  end
end

function AuraContainer:ApplySettings(state, profile, recipe, previousRecipe, resources, force)
  configure(state, profile, recipe, previousRecipe, resources, force)
end

function AuraContainer:ApplyCandidateFilters(state, recipe, indices)
  for _, index in ipairs(indices) do
    -- A reserve container can still be under construction.
    if not state.groups[index] then
      break
    end
    state.frame:SetAuraGroupCandidateFilters(tostring(index), recipe[index].candidates)
  end
end

function AuraContainer:Attach(state, plate, profile)
  state.plate = plate
  state.frame:SetParent(plate)
  positionContainer(state, profile)
end

function AuraContainer:PrepareGroup(state, profile, recipe, resources)
  local index = #state.groups + 1
  local group = recipe[index]
  if group then
    local key = tostring(index)
    createGroup(state, key, index, group, profile, resources)
    layoutGroup(state.frame, key, index, profile.position)
  end
  return #state.groups >= #recipe
end
