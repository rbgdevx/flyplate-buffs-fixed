local _, fPB = ...

local GenerateClosure = GenerateClosure

local Client = fPB.Client
local Controls = fPB.Controls
local L = fPB.L
local Options = fPB.Options

local SortingOptions = {}
fPB.SortingOptions = SortingOptions

local function getSort(index)
  return fPB.db.profile.sortMode[index]
end

local function setSort(index, _, value)
  fPB.db.profile.sortMode[index] = value
  Options:Changed()
end

function SortingOptions:Build()
  local args = {}
  if Client.modern then
    args.modernSortMethod = Controls:Select("Sort within groups", 1, {
      Default = "Blizzard default",
      ExpirationOnly = "Expiration",
      Expiration = "Expiration + Blizzard priority",
      Name = "Name + Blizzard priority",
      NameOnly = "Name only",
      AuraInstanceIDOnly = "Aura application order",
      BigDefensive = "Big defensives",
      ImportantOnly = "Important first",
      UnitFrameDebuff = "Blizzard debuff priority",
    })
    args.modernSortReverse = Controls:Toggle("Reverse sorting", 2)
    args.modernGroupOrder = Controls:Select(
      "Group order",
      3,
      { mine = "Mine first", listed = "Listed first", larger = "Larger first", default = "Default" }
    )
    args = {
      method = Controls:Row(1, { modernSortMethod = args.modernSortMethod }),
      reverse = Controls:Row(2, { modernSortReverse = args.modernSortReverse }),
      groups = Controls:Row(3, { modernGroupOrder = args.modernGroupOrder }),
    }
    args.method.args.modernSortMethod.width = "double"
    args.groups.args.modernGroupOrder.width = "double"
  else
    args.enabled = Controls:Row(1, { disableSort = Controls:Toggle("Disable sorting", 1) })
    for index = 1, 4 do
      local select = Controls:Select("Priority " .. index, index * 2, {
        disable = L["None"],
        my = L["Mine first"],
        expiration = L["Expiration"],
        type = L["Aura type"],
        scale = L["Icon scale"],
      })
      select.get, select.set = GenerateClosure(getSort, index), GenerateClosure(setSort, index)
      local reverse = Controls:Toggle("Reverse priority " .. index, index * 2 + 1)
      reverse.get, reverse.set = GenerateClosure(getSort, index + 0.5), GenerateClosure(setSort, index + 0.5)
      select.width = "double"
      args["priority" .. index .. "Row"] = Controls:Row(index + 1, {
        ["priority" .. index] = select,
        ["reverse" .. index] = reverse,
      })
    end
  end
  return { type = "group", name = L["Sorting"], order = 4, args = args }
end
