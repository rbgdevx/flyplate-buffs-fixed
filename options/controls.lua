local _, fPB = ...

local pairs = pairs
local unpack = unpack

local CreateFrame = CreateFrame
local GenerateClosure = GenerateClosure

local mceil = math.ceil
local mmax = math.max

local L = fPB.L
local Options = fPB.Options

local Controls = {}
fPB.Controls = Controls

local measurement = CreateFrame("Frame"):CreateFontString(nil, "OVERLAY", "GameFontNormal")
measurement:Hide()

local function getColor(key)
  return unpack(fPB.db.profile[key])
end

local function setColor(key, _, r, g, b)
  fPB.db.profile[key] = { r, g, b }
  Options:Changed()
end

function Controls:Width(label)
  measurement:SetText(label)
  -- Ace widths are multiples of 170; reserve room for checkbox/swatch chrome.
  return mmax(255, mceil(measurement:GetStringWidth()) + 32) / 170
end

function Controls:Toggle(label, order, description)
  return {
    type = "toggle",
    name = L[label],
    desc = description and L[description],
    order = order,
    width = Controls:Width(L[label]),
  }
end

function Controls:Range(label, order, minimum, maximum, step)
  return {
    type = "range",
    name = L[label],
    order = order,
    width = Controls:Width(L[label]),
    min = minimum,
    max = maximum,
    step = step or 1,
  }
end

function Controls:Select(label, order, values)
  return {
    type = "select",
    name = L[label],
    order = order,
    width = Controls:Width(L[label]),
    values = values,
    style = "dropdown",
  }
end

function Controls:Description(text, order)
  return { type = "description", name = L[text], order = order, width = "full" }
end

function Controls:Color(key, label, order)
  return {
    type = "color",
    name = L[label],
    order = order,
    width = Controls:Width(L[label]),
    get = GenerateClosure(getColor, key),
    set = GenerateClosure(setColor, key),
  }
end

function Controls:Group(label, order, args)
  return { type = "group", name = L[label], order = order, inline = true, args = args }
end

function Controls:Spacer(order)
  return { type = "description", name = "", order = order, width = 0.1 }
end

function Controls:Row(order, args)
  local row, last = {}, 0
  for key, control in pairs(args) do
    row[key] = control
    last = mmax(last, control.order)
  end
  for key, control in pairs(args) do
    if control.order < last then
      row[key .. "Spacing"] = Controls:Spacer(control.order + 0.01)
    end
  end
  return Controls:Group("", order, row)
end
