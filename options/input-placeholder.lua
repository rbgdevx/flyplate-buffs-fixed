local _, fPB = ...

local setmetatable = setmetatable
local GenerateClosure = GenerateClosure

local InputPlaceholder = {}
fPB.InputPlaceholder = InputPlaceholder

local labels = setmetatable({}, { __mode = "k" })

local function refresh(widget)
  local input = widget.editbox
  -- Ace clears userdata on release, so pooled inputs never retain FPB's hint.
  local text = widget:GetUserDataTable().fpbPlaceholder
  labels[widget]:SetShown(text ~= nil and input:IsVisible() and input:GetText() == "" and not input:HasFocus())
end

function InputPlaceholder:Attach(widget, text)
  local label = labels[widget]
  if not label then
    local input = widget.editbox
    label = input:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("LEFT", 2, 0)
    label:SetPoint("RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    labels[widget] = label
    local update = GenerateClosure(refresh, widget)
    input:HookScript("OnTextChanged", update)
    input:HookScript("OnEditFocusGained", update)
    input:HookScript("OnEditFocusLost", update)
    input:HookScript("OnShow", update)
    input:HookScript("OnHide", update)
  end
  widget:GetUserDataTable().fpbPlaceholder = text
  label:SetText(text)
  refresh(widget)
end
