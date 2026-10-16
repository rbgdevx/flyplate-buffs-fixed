local _, fPB = ...

local select = select
local GetBuildInfo = GetBuildInfo

local interface = select(4, GetBuildInfo())
local IsForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
fPB.Client = {
  interface = interface,
  forever = IsForever,
  modern = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or IsForever,
}
