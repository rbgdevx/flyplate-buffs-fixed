local _, fPB = ...

local ipairs = ipairs
local tCompare = tCompare
local tostring = tostring
local AuraContainerSortDirection = AuraContainerSortDirection
local AuraContainerSortMethod = AuraContainerSortMethod
local CreateFrame = CreateFrame
local GenerateClosure = GenerateClosure
local FlowDirection = AnchorUtil.FlowDirection

local Style = fPB.Style

local AuraContainer = {}
fPB.AuraContainer = AuraContainer

local function initializeFrame(slot, button)
  Style:Create(button)
  Style:Apply(button, slot.profile, slot.style)
end

local function createGroup(state, key, index, group, profile)
  local slot = { profile = profile, style = group.style }
  state.groups[index] = slot

  state.frame:AddAuraGroup(key, group.filter, {
    candidateFilters = group.candidates,
    maxFrameCount = profile.sorting.maxPerGroup,
    sortMethod = AuraContainerSortMethod[profile.sorting.method],
    sortDirection = profile.sorting.reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal,
    initializeFrame = GenerateClosure(initializeFrame, slot),
  })
end

local function updateGroup(container, slot, key, group, previous, profile)
  local sorting = profile.sorting
  local previousSorting = slot.profile.sorting
  slot.profile = profile
  slot.style = group.style

  container:SetAuraGroupFilterString(key, group.filter)
  if not previous or not tCompare(previous.candidates, group.candidates, 2) then
    container:SetAuraGroupCandidateFilters(key, group.candidates)
  end

  container:SetAuraGroupMaxFrameCount(key, sorting.maxPerGroup)
  if sorting.method ~= previousSorting.method or sorting.reverse ~= previousSorting.reverse then
    container:SetAuraGroupSortMethod(
      key,
      AuraContainerSortMethod[sorting.method],
      sorting.reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
    )
  end

  for frameIndex = 1, container:GetAuraGroupFrameCount(key) do
    Style:Apply(container:GetAuraGroupFrame(key, frameIndex), profile, group.style)
  end
end

local function positionContainer(state, profile)
  local container = state.frame
  local position = profile.position
  container:ClearAllPoints()
  container:SetPoint(position.anchor, state.plate, position.relativeAnchor, position.x, position.y)
  container:SetFlowLayoutMaximumLineSize(position.perRow * profile.style.width + (position.perRow - 1) * position.gapX)
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

local function configure(state, profile, recipe, previousRecipe)
  positionContainer(state, profile)

  local container = state.frame
  for index, group in ipairs(recipe) do
    local key = tostring(index)
    local slot = state.groups[index]
    if slot then
      updateGroup(container, slot, key, group, previousRecipe and previousRecipe[index], profile)
    else
      createGroup(state, key, index, group, profile)
    end

    layoutGroup(container, key, index, profile.position)
  end

  for index = #recipe + 1, #state.groups do
    container:SetAuraGroupMaxFrameCount(tostring(index), 0)
  end
end

function AuraContainer:Create(plate, profile, recipe)
  local container = CreateFrame("AuraContainer", nil, plate, "CustomAuraContainerTemplate")
  container:SetEnabled(false)

  local state = { frame = container, plate = plate, groups = {} }
  configure(state, profile, recipe)

  return state
end

function AuraContainer:ApplySettings(state, profile, recipe, previousRecipe)
  configure(state, profile, recipe, previousRecipe)
end
