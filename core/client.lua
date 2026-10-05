local _, fPB = ...

local select = select
local GetBuildInfo = GetBuildInfo

local interface = select(4, GetBuildInfo())
fPB.Client = {
  interface = interface,
  forever = interface >= 16000 and interface < 20000,
  modern = interface >= 120000 or (interface >= 16000 and interface < 20000),
}
