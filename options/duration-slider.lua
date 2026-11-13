local _, fPB = ...

local GenerateClosure = GenerateClosure
local LibStub = LibStub

local Client = fPB.Client

local DurationSlider = { widgetType = "FPBFDurationSlider" }
fPB.DurationSlider = DurationSlider

local function fire(widget, event, ...)
  -- Ace's slider commits on OnMouseUp after a drag or numeric entry.
  if event ~= "OnValueChanged" then
    return widget.fireSliderEvent(widget, event, ...)
  end
end

local function onMouseWheel(slider, delta)
  local widget = slider.obj
  local previous = widget:GetValue()
  widget.scrollSlider(slider, delta)
  local value = widget:GetValue()
  if value ~= previous then
    widget.fireSliderEvent(widget, "OnValueChanged", value)
  end
end

local function create(ace)
  local widget = ace.WidgetRegistry.Slider()
  widget.type = DurationSlider.widgetType
  widget.fireSliderEvent, widget.Fire = widget.Fire, fire
  widget.scrollSlider = widget.slider:GetScript("OnMouseWheel")
  widget.slider:SetScript("OnMouseWheel", onMouseWheel)
  return widget
end

if Client.modern then
  local AceGUI = LibStub("AceGUI-3.0")
  AceGUI:RegisterWidgetType(DurationSlider.widgetType, GenerateClosure(create, AceGUI), 1)
end
