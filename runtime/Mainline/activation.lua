local _, fPB = ...

local CreateFrame = CreateFrame

local Activation = {}
fPB.Activation = Activation

local worker = CreateFrame("Frame")
local first, last
local budget = 10

local function removePending(state)
  local previous, following = state.activationPrevious, state.activationNext
  if previous then
    previous.activationNext = following
  else
    first = following
  end
  if following then
    following.activationPrevious = previous
  else
    last = previous
  end
  state.activationPrevious, state.activationNext, state.activationQueued = nil, nil, nil
end

local function showNext()
  local state = first
  removePending(state)
  state.frame:SetShown(true)
end

local function drain()
  local shown = 0
  while first and shown < budget do
    showNext()
    shown = shown + 1
  end

  if not first then
    worker:SetScript("OnUpdate", nil)
  end
end

local function enqueue(state)
  state.activationQueued = true
  state.activationPrevious = last
  if last then
    last.activationNext = state
  else
    first = state
    worker:SetScript("OnUpdate", drain)
  end
  last = state
end

function Activation:Show(state)
  if state.activationQueued or state.frame:IsShown() then
    return
  end

  enqueue(state)
end

function Activation:Hide(state)
  if state.activationQueued then
    removePending(state)
    if not first then
      worker:SetScript("OnUpdate", nil)
    end
  end

  state.frame:SetShown(false)
end
