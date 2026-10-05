local addonName, fPB = ...

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local GenerateClosure = GenerateClosure
local LibStub = LibStub
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata

local BlizzardOptions = fPB.BlizzardOptions
local DisplayOptions = fPB.DisplayOptions
local Options = fPB.Options
local PositionOptions = fPB.PositionOptions
local Preview = fPB.Preview
local ProfileOptions = fPB.ProfileOptions
local Restrictions = fPB.Restrictions
local SortingOptions = fPB.SortingOptions
local SpellOptions = fPB.SpellOptions
local StyleOptions = fPB.StyleOptions

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function getValue(info)
  local key = info[#info]
  local profile = fPB.db.profile
  if key == "modernSortMethod" then
    return profile[key] or "ExpirationOnly"
  end
  if key == "modernGroupOrder" then
    return profile[key] or "mine"
  end
  if key == "modernMaxPerGroup" then
    return profile[key] or profile.buffPerLine * profile.numLines
  end
  return profile[key]
end

local function setValue(info, value)
  fPB.db.profile[info[#info]] = value
  Options:Changed()
end

local function previewLabel()
  return Preview:IsShown() and "Stop preview" or "Preview"
end

local function updatePreviewButton()
  local window = AceConfigDialog.OpenFrames[addonName]
  if not window then
    return
  end
  for _, control in ipairs(window.children) do
    if control.type == "Button" then
      local path = control:GetUserDataTable().path
      if path and #path == 1 and path[1] == "preview" then
        control:SetText(previewLabel())
      end
    end
  end
end

local function build()
  return {
    type = "group",
    name = addonName .. " v" .. GetAddOnMetadata(addonName, "Version"),
    childGroups = "tab",
    get = getValue,
    set = setValue,
    disabled = GenerateClosure(Restrictions.Active, Restrictions),
    args = {
      preview = {
        type = "execute",
        name = previewLabel,
        order = 0,
        func = GenerateClosure(Options.TogglePreview, Options),
      },
      display = DisplayOptions:Build(),
      style = StyleOptions:Build(),
      position = PositionOptions:Build(),
      sorting = SortingOptions:Build(),
      spells = SpellOptions:Build(),
      blizzard = BlizzardOptions:Build(),
      profiles = ProfileOptions:Build(),
    },
  }
end

local function groupShown(_, appName, options, container, _, path)
  if appName ~= addonName then
    return
  end
  if #path == 0 then
    if AceConfigDialog.OpenFrames[addonName] == container then
      Preview:Attach(container)
      updatePreviewButton()
    end
    return
  end
  local pageChanged = Options.selectedPage ~= path[1]
  Options.selectedPage = path[1]
  local selected
  if path[1] == "spells" then
    if #path == 1 then
      SpellOptions:BindInputs(container)
      if pageChanged then
        Preview:ContextChanged()
        updatePreviewButton()
      end
      return
    end
    selected = options.args.spells.args[path[2]].arg
  else
    SpellOptions:ClearInputFocus()
  end
  if Options.selectedSpell ~= selected or pageChanged then
    Options.selectedSpell = selected
    Preview:ContextChanged()
    updatePreviewButton()
  end
end

function Options:TogglePreview()
  Preview:Toggle()
  updatePreviewButton()
end

function Options:Initialize(callback)
  Options:SetCallbacks(callback, GenerateClosure(Preview.Refresh, Preview))
  AceConfig:RegisterOptionsTable(addonName, build)
  AceConfigDialog:SetDefaultSize(addonName, 900, 650)
  local spellStatus = AceConfigDialog:GetStatusTable(addonName, { "spells" })
  spellStatus.groups = spellStatus.groups or { treewidth = 230 }
  AceConfigDialog:AddToBlizOptions(addonName, addonName)
  -- AceConfig tree clicks have no option-table callback; observe the displayed group.
  hooksecurefunc(AceConfigDialog, "FeedGroup", groupShown)
end

function Options:Open(page)
  AceConfigDialog:Open(addonName)
  if
    page == "display"
    or page == "style"
    or page == "position"
    or page == "sorting"
    or page == "spells"
    or page == "blizzard"
    or page == "profiles"
  then
    AceConfigDialog:SelectGroup(addonName, page)
  end
end
