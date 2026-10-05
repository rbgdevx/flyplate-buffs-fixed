local _, fPB = ...

local setmetatable = setmetatable

local function fallback(_, key)
  return key
end

fPB.L = setmetatable({}, { __index = fallback })
