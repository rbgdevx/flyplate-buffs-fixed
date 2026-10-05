local _, fPB = ...

local ipairs = ipairs
local next = next

local Controls = fPB.Controls
local Database = fPB.Database
local L = fPB.L
local Options = fPB.Options

local ProfileOptions = {}
fPB.ProfileOptions = ProfileOptions

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
      current = Controls:Description(L["Current profile:"] .. " " .. current, 1),
      choose = {
        type = "select",
        name = L["Existing profiles"],
        order = 2,
        width = "double",
        values = profiles,
        sorting = order,
        get = getCurrent,
        set = selectProfile,
      },
      new = {
        type = "input",
        name = L["New profile"],
        order = 3,
        width = "double",
        get = false,
        set = selectProfile,
        validate = validateName,
      },
      copy = {
        type = "select",
        name = L["Copy from"],
        order = 4,
        width = "double",
        desc = L["Replace this profile's settings with another profile's settings."],
        values = others,
        sorting = otherOrder,
        get = false,
        set = copyProfile,
        -- Nil keeps the main window's combat restriction inherited.
        disabled = next(others) == nil or nil,
      },
      reset = {
        type = "execute",
        name = L["Reset profile"],
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
  for _, key in ipairs({ "choose", "new", "copy", "reset", "delete" }) do
    local control = page.args[key]
    page.args[key .. "Row"] = Controls:Row(control.order, { [key] = control })
    page.args[key] = nil
  end
  return page
end
