local _, fPB = ...

local ipairs = ipairs
local next = next
local CreateFrame = CreateFrame
local LibStub = LibStub

local Controls = fPB.Controls
local Database = fPB.Database
local L = fPB.L
local Options = fPB.Options

local ProfileOptions = {}
fPB.ProfileOptions = ProfileOptions

local profileInputType = "FPBFProfileInput"
local AceGUI = LibStub("AceGUI-3.0")

local function updateCreateButton(widget)
  widget.createButton:SetEnabled(not widget.disabled and Database:IsValidProfileName(widget:GetText()))
end

local function profileNameChanged(editbox)
  updateCreateButton(editbox.obj)
end

local function submitProfileName(button)
  local editbox = button.input
  editbox:ClearFocus()
  editbox:GetScript("OnEnterPressed")(editbox)
end

local function acquireInput(widget)
  widget.acquireEditBox(widget)
  widget:DisableButton(true)
  updateCreateButton(widget)
end

local function setInputDisabled(widget, disabled)
  widget.setEditBoxDisabled(widget, disabled)
  updateCreateButton(widget)
end

local function createInput()
  local widget = AceGUI.WidgetRegistry.EditBox()
  widget.type = profileInputType
  local editbox = widget.editbox
  local button = CreateFrame("Button", nil, widget.frame, "UIPanelButtonTemplate")
  button:SetSize(85, 24)
  button:SetPoint("BOTTOMRIGHT")
  button:SetText(L["Create"])
  button.input = editbox
  button:SetScript("OnClick", submitProfileName)
  editbox:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -95, 0)
  editbox:HookScript("OnTextChanged", profileNameChanged)
  widget.createButton = button
  widget.acquireEditBox, widget.OnAcquire = widget.OnAcquire, acquireInput
  widget.setEditBoxDisabled, widget.SetDisabled = widget.SetDisabled, setInputDisabled
  return widget
end

AceGUI:RegisterWidgetType(profileInputType, createInput, 1)

local function getCurrent()
  return Database:GetCurrentProfile()
end

local function selectProfile(_, name)
  Database:SetProfile(name)
end

local function validateName(_, name)
  return Database:IsValidProfileName(name) or L["Enter a profile name between 1 and 50 characters."]
end

local function copyProfile(_, name)
  Database:CopyProfile(name)
end

local function deleteProfile(_, name)
  Database:DeleteProfile(name)
  Options:Refresh()
end

local function resetProfile()
  Database:ResetProfile()
end

local sections = {
  {
    key = "choose",
    title = "Profiles",
    description = "Share aura settings and spell rules between characters. Each character remembers its selected profile.",
  },
  {
    key = "new",
    title = "New profile",
    description = "New profiles start with the default aura settings and spell list.",
  },
  {
    key = "copy",
    title = "Copy settings",
    description = "Replace the current profile with a copy of another.",
  },
  {
    key = "reset",
    title = "Reset profile",
    description = "Restore this profile's default aura settings and spell list.",
  },
  {
    key = "delete",
    title = "Delete profile",
    description = "Delete a profile you are not currently using.",
  },
}

function ProfileOptions:Build()
  local current = Database:GetCurrentProfile()
  local profiles, others, order, otherOrder = {}, {}, {}, {}
  for _, name in ipairs(Database:GetProfiles()) do
    profiles[name] = name
    order[#order + 1] = name
    if name ~= current then
      others[name] = name
      otherOrder[#otherOrder + 1] = name
    end
  end
  local page = {
    type = "group",
    name = L["Profiles"],
    order = 7,
    args = {
      choose = {
        type = "select",
        name = L["Current profile"],
        order = 2,
        width = "double",
        values = profiles,
        sorting = order,
        get = getCurrent,
        set = selectProfile,
      },
      new = {
        type = "input",
        name = L["Profile name"],
        order = 3,
        width = "double",
        dialogControl = profileInputType,
        get = false,
        set = selectProfile,
        validate = validateName,
      },
      copy = {
        type = "select",
        name = L["Copy from"],
        order = 4,
        width = "double",
        values = others,
        sorting = otherOrder,
        get = false,
        set = copyProfile,
        -- Nil keeps the main window's combat restriction inherited.
        disabled = next(others) == nil or nil,
      },
      reset = {
        type = "execute",
        name = L["Reset current profile"],
        order = 5,
        width = "double",
        confirm = true,
        confirmText = L["Reset the current profile to its defaults?"],
        func = resetProfile,
      },
      delete = {
        type = "select",
        name = L["Delete profile"],
        order = 6,
        width = "double",
        values = others,
        sorting = otherOrder,
        get = false,
        set = deleteProfile,
        -- Nil keeps the main window's combat restriction inherited.
        disabled = next(others) == nil or nil,
        confirm = true,
        confirmText = L["Delete the selected profile?"],
      },
    },
  }
  for index, section in ipairs(sections) do
    local key = section.key
    local sectionOrder = (index - 1) * 3 + 1
    page.args[key .. "Heading"] = { type = "header", name = L[section.title], order = sectionOrder }
    page.args[key .. "Description"] = Controls:Description(section.description, sectionOrder + 1)
    page.args[key .. "Row"] = Controls:Row(sectionOrder + 2, { [key] = page.args[key] })
    page.args[key] = nil
  end
  return page
end
