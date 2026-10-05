local _, fPB = ...

local CreateFrame = CreateFrame
local GenerateClosure = GenerateClosure
local GetCursorPosition = GetCursorPosition
local LibStub = LibStub
local mmax = math.max
local mmin = math.min

local PreviewViewport = {}
fPB.PreviewViewport = PreviewViewport

local AceGUI = LibStub("AceGUI-3.0")

local function update(view)
  view.zoomLabel:SetText("Zoom - " .. view.zoom .. "%")
  view.scene:SetScale(view.zoom / 100)
  view.scene:ClearAllPoints()
  view.scene:SetPoint("CENTER", view, "CENTER", view.panX - view.centerX, view.panY - view.centerY)
  view.reset.frame:SetShown(view.zoom ~= 100 or view.panX ~= 0 or view.panY ~= 0)
end

local function mouseWheel(view, _, delta)
  AceGUI:ClearFocus()
  view.zoom = mmax(25, mmin(300, view.zoom + delta * 25))
  update(view)
end

local function resetView(view)
  AceGUI:ClearFocus()
  view.panX, view.panY, view.zoom = 0, 0, 100
  update(view)
end

local function stopPan(view)
  view:SetScript("OnUpdate", nil)
end

local function pan(view)
  local x, y = GetCursorPosition()
  local scale = view.scene:GetEffectiveScale()
  view.panX = view.panX + (x - view.previousX) / scale
  view.panY = view.panY + (y - view.previousY) / scale
  view.previousX, view.previousY = x, y
  update(view)
end

local function startPan(view)
  AceGUI:ClearFocus()
  view.previousX, view.previousY = GetCursorPosition()
  view:SetScript("OnUpdate", pan)
end

local function resetDrag(target)
  target.dragged = false
end

local function startDrag(view, background, target, button)
  if button == "LeftButton" and view.movingFrame then
    target.dragged = true
    AceGUI:ClearFocus()
    view.movingFrame:StartMoving()
  elseif background or button == "RightButton" then
    target.dragged = true
    startPan(view)
  end
end

local function stopDrag(view)
  if view.movingFrame then
    view.movingFrame:StopMovingOrSizing()
  end
  stopPan(view)
end

function PreviewViewport:Bind(view, target, background)
  target:EnableMouse(true)
  target:EnableMouseWheel(true)
  target:RegisterForDrag("LeftButton", "RightButton")
  target:SetScript("OnMouseWheel", GenerateClosure(mouseWheel, view))
  target:SetScript("OnMouseDown", resetDrag)
  target:SetScript("OnDragStart", GenerateClosure(startDrag, view, background))
  target:SetScript("OnDragStop", GenerateClosure(stopDrag, view))
end

function PreviewViewport:SetMovingFrame(view, frame)
  view.movingFrame = frame
  view.instructions:SetText(frame and "Left-drag moves, right-drag pans" or "Scroll to zoom, drag to pan")
end

function PreviewViewport:Center(view, x, y)
  view.centerX, view.centerY = x, y
  update(view)
end

function PreviewViewport:Create(parent)
  local view = CreateFrame("Frame", nil, parent)
  view:SetPoint("TOPLEFT", 16, -16)
  view:SetPoint("BOTTOMRIGHT", -16, 42)
  view:SetClipsChildren(true)
  view.zoom, view.panX, view.panY, view.centerX, view.centerY = 100, 0, 0, 0, 0
  view.scene = CreateFrame("Frame", nil, view)
  view.scene:SetSize(1, 1)
  PreviewViewport:Bind(view, view, true)
  view:SetScript("OnHide", GenerateClosure(stopDrag, view))

  view.zoomLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  view.zoomLabel:SetPoint("BOTTOMLEFT", 18, 20)
  view.instructions = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  view.instructions:SetText("Scroll to zoom, drag to pan")
  view.instructions:SetPoint("LEFT", view.zoomLabel, "RIGHT", 12, 0)
  view.instructions:SetJustifyH("LEFT")
  view.instructions:SetWordWrap(false)
  view.reset = AceGUI:Create("Button")
  view.reset.frame:SetParent(parent)
  view.reset:SetText("Reset")
  view.reset:SetWidth(70)
  view.reset:SetCallback("OnClick", GenerateClosure(resetView, view))
  view.reset.frame:SetPoint("LEFT", view.instructions, "RIGHT", 8, 0)
  update(view)
  return view
end
