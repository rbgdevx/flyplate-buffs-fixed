local _, fPB = ...

local mceil = math.ceil
local mmax = math.max
local mmin = math.min

local Layout = {}
fPB.Layout = Layout

function Layout:Arrange(frame, buttons, count, profile, anchor)
  local rows = mmin(profile.numLines, mceil(count / profile.buffPerLine))
  local width, height, previousHeight = 0, 0, 0
  for row = 1, rows do
    local lineWidth, lineHeight = 0, 0
    if row > 1 then
      height = height + previousHeight + profile.yInterval
    end
    for column = 1, profile.buffPerLine do
      local index = (row - 1) * profile.buffPerLine + column
      if index > count then
        break
      end
      local button = buttons[index]
      button:ClearAllPoints()
      button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", lineWidth, height)
      lineWidth = lineWidth + button:GetWidth() + profile.xInterval
      lineHeight = mmax(lineHeight, button:GetHeight())
    end
    width = mmax(width, lineWidth - profile.xInterval)
    previousHeight = lineHeight
  end
  frame:SetSize(mmax(1, width), mmax(1, height + previousHeight))
  frame:ClearAllPoints()
  frame:SetPoint(profile.buffAnchorPoint, anchor, profile.plateAnchorPoint, profile.xOffset, profile.yOffset)
end
