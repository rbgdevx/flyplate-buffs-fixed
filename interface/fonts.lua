local _, fPB = ...

local ipairs = ipairs

local GenerateClosure = GenerateClosure
local LibStub = LibStub

local SharedMedia = LibStub("LibSharedMedia-3.0")
local Fonts = {}
fPB.Fonts = Fonts

local function mediaChanged(onChange, event, mediaType, name)
  if mediaType == "font" then
    onChange(event, name)
  end
end

function Fonts:GetChoices()
  local choices = {}
  for _, name in ipairs(SharedMedia:List("font")) do
    choices[name] = name
  end

  return choices
end

function Fonts:GetPath(name)
  -- A font's supplying addon may be disabled or not loaded yet. Fetch keeps
  -- text readable with the locale default without changing the saved choice.
  return SharedMedia:Fetch("font", name)
end

function Fonts:Initialize(onChange)
  local callback = GenerateClosure(mediaChanged, onChange)
  SharedMedia.RegisterCallback(Fonts, "LibSharedMedia_Registered", callback)
  SharedMedia.RegisterCallback(Fonts, "LibSharedMedia_SetGlobal", callback)
end
