local _, fPB = ...

local next = next
local pairs = pairs
local CreateFrame = CreateFrame
local GetTime = GetTime

local IconTimers = {}
fPB.IconTimers = IconTimers

local frame = CreateFrame("Frame")
local active = {}
local elapsed = 0

local function update(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.05 then
    return
  end
  elapsed = 0
  local now = GetTime()
  for button, callback in pairs(active) do
    if button:IsVisible() then
      callback(button, now)
    else
      active[button] = nil
    end
  end
  if not next(active) then
    frame:SetScript("OnUpdate", nil)
  end
end

function IconTimers:Set(button, callback)
  local empty = not next(active)
  active[button] = callback
  if not next(active) then
    frame:SetScript("OnUpdate", nil)
    elapsed = 0
  elseif empty then
    elapsed = 0
    frame:SetScript("OnUpdate", update)
  end
end
