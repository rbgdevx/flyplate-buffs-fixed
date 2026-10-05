local _, fPB = ...

local ipairs = ipairs
local tostring = tostring
local unpack = unpack

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GenerateClosure = GenerateClosure
local GetTime = GetTime

local mmax = math.max
local mmin = math.min
local tconcat = table.concat
local tsort = table.sort

local CreateFlowLayout = fPB.Client.modern and AnchorUtil.CreateFlowLayout
local FlowDirection = fPB.Client.modern and AnchorUtil.FlowDirection
local GetSpellInfo = C_Spell.GetSpellInfo

local Appearance = fPB.Appearance
local ClassicRules = fPB.ClassicRules
local Client = fPB.Client
local Icons = fPB.Icons
local Layout = fPB.Layout
local ModernRules = fPB.ModernRules
local PreviewNameplate = fPB.PreviewNameplate
local PreviewViewport = fPB.PreviewViewport
local Style = fPB.Style

local PreviewScene = {}
fPB.PreviewScene = PreviewScene

local samples = {
  { id = 118, time = 4.8, total = 8, stacks = 5, mine = true, color = "Magic", priority = 1 },
  { id = 642, time = 7.3, total = 8, stacks = 2, mine = false, color = "Buff", priority = 2, defensive = true },
  { id = 853, time = 1.3, total = 6, stacks = 3, mine = false, color = "none", priority = 1 },
  { id = 339, time = 10, total = 20, stacks = 1, mine = false, color = "Magic", priority = 3 },
  { id = 1044, time = 12, total = 16, stacks = 1, mine = true, color = "Buff", priority = 3 },
  { id = 2094, time = 22, total = 30, stacks = 1, mine = false, color = "Poison", priority = 1 },
}
local anchorXY = {
  TOPLEFT = { -0.5, 0.5 },
  TOP = { 0, 0.5 },
  TOPRIGHT = { 0.5, 0.5 },
  LEFT = { -0.5, 0 },
  CENTER = { 0, 0 },
  RIGHT = { 0.5, 0 },
  BOTTOMLEFT = { -0.5, -0.5 },
  BOTTOM = { 0, -0.5 },
  BOTTOMRIGHT = { 0.5, -0.5 },
}

local function timing(scene, button, now, reset)
  local sample, profile = button.sample, scene.profile
  local remaining = scene.animate and (sample.time - (now - scene.started)) % sample.total or sample.time
  button.Duration:SetText(Icons:FormatTime(remaining, profile.showDecimals))
  if profile.colorTransition then
    local fraction = remaining / sample.total
    button.Duration:SetTextColor(mmin(1, 2 - fraction * 2), mmin(1, fraction * 2), 0)
  end
  if reset or remaining > button.remaining then
    button.Cooldown:SetCooldown(now - (sample.total - remaining), sample.total)
    if not scene.animate then
      button.Cooldown:Pause()
    end
  end
  if not Client.modern and scene.animate and remaining / sample.total < profile.blinkTimeleft then
    local phase = now % 1
    button:SetAlpha(mmin(1, (phase > 0.5 and 1 - phase or phase) * 3))
  else
    button:SetAlpha(1)
  end
  button.remaining = remaining
end

local function hover(hit)
  hit:SetBackdropBorderColor(1, 0.82, 0, 1)
  GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")
  GameTooltip:SetText(hit.hint)
  GameTooltip:Show()
end

local function leave(hit)
  hit:SetBackdropBorderColor(1, 0.82, 0, 0)
  if GameTooltip:IsOwned(hit) then
    GameTooltip:Hide()
  end
end

local function click(scene, kind, _, button)
  if button == "LeftButton" and scene.onSelect then
    scene.onSelect(kind)
  end
end

local function hitRegion(scene, parent, target, kind, hint)
  local hit = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  hit:SetAllPoints(target)
  hit:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  hit:SetBackdropBorderColor(1, 0.82, 0, 0)
  hit.hint = hint
  PreviewViewport:Bind(scene.viewport, hit)
  hit:SetScript("OnMouseDown", GenerateClosure(click, scene, kind))
  hit:SetScript("OnEnter", hover)
  hit:SetScript("OnLeave", leave)
  hit:SetScript("OnHide", leave)
  return hit
end

local function createButton(scene)
  local button
  if Client.modern then
    button = CreateFrame("Frame", nil, scene.block)
    Style:Create(button)
  else
    button = Icons:Create(scene.block)
  end
  button.IconHit =
    hitRegion(scene, button, button, "auras", "Click to open Position. Scroll to zoom; right-drag to pan.")
  button.DurationHit =
    hitRegion(scene, button.TextLayer, button.Duration, "duration", "Click to open duration settings.")
  button.StackHit = hitRegion(scene, button.TextLayer, button.Stacks, "stacks", "Click to open stack settings.")
  button.CountdownHit = hitRegion(
    scene,
    button.TextLayer,
    button.Cooldown:GetCountdownFontString(),
    "countdown",
    "Click to open cooldown settings."
  )
  return button
end

local function record(profile, sample, rule, mine, instanceID)
  local info = GetSpellInfo(sample.id)
  local style = Appearance:Spell(profile, rule, mine)
  return {
    sample = sample,
    style = style,
    scale = style.scale,
    my = mine,
    type = sample.color == "Buff" and "HELPFUL" or "HARMFUL",
    aura = {
      auraInstanceID = instanceID,
      name = info and info.name or tostring(sample.id),
      icon = info and info.iconID or 134400,
      applications = sample.stacks,
      duration = sample.total,
      expirationTime = GetTime() + sample.time,
      isHelpful = sample.color == "Buff",
      dispelName = sample.color,
    },
  }
end

local function sortValue(entry, method)
  if method == "Name" or method == "NameOnly" then
    return entry.aura.name
  elseif method == "Expiration" or method == "ExpirationOnly" then
    return entry.sample.time
  elseif method == "AuraInstanceIDOnly" then
    return entry.sample.id
  elseif method == "BigDefensive" then
    return entry.sample.defensive and 0 or 1
  end
  return entry.sample.priority or 1
end

local function compare(profile, a, b)
  local left, right =
    sortValue(a, profile.modernSortMethod or "ExpirationOnly"),
    sortValue(b, profile.modernSortMethod or "ExpirationOnly")
  if left == right then
    return a.sample.id < b.sample.id
  end
  return profile.modernSortReverse and left > right or not profile.modernSortReverse and left < right
end

local function buildGroups(profile, selected, more)
  local rule = selected and not profile.ignoredDefaultSpells[selected] and profile.Spells[selected]
  local records = {}
  if rule then
    records[1] = record(
      profile,
      { id = rule.spellID or selected, time = 4.8, total = 8, stacks = 5, color = "Magic" },
      rule,
      false,
      1
    )
  else
    for index = 1, more and 12 or 6 do
      local sample = samples[(index - 1) % 6 + 1]
      local mine = sample.mine
      if index > 6 then
        mine = not mine
      end
      records[index] = record(profile, sample, nil, mine, index)
    end
  end
  if not Client.modern then
    ClassicRules:Sort(profile, records)
    return { { records = records } }
  end
  local groups, indexed = {}, {}
  for _, entry in ipairs(records) do
    local style = entry.style
    local key = tconcat({ style.scale, style.durationSize, style.stackSize, tostring(entry.my) }, ":")
    local group = indexed[key]
    if not group then
      group = { records = {}, mine = entry.my, style = style, exact = rule ~= nil, order = #groups + 1 }
      groups[#groups + 1], indexed[key] = group, group
    end
    group.records[#group.records + 1] = entry
  end
  ModernRules:SortGroups(groups, profile.modernGroupOrder)
  for _, group in ipairs(groups) do
    tsort(group.records, GenerateClosure(compare, profile))
  end
  return groups
end

local function apply(scene, button, entry)
  local profile = scene.profile
  if Client.modern then
    Style:ApplyAppearance(button, scene.appearance, entry.style)
    button.Icon:SetTexture(entry.aura.icon)
    button.Stacks:SetText(entry.sample.stacks > 1 and entry.sample.stacks or "")
    button.StackBackground:SetShown(entry.sample.stacks > 1 and profile.stackPosition ~= 1)
    local color = entry.aura.isHelpful and profile.colorTypes.Buff
      or (profile.colorizeBorder and profile.colorTypes[entry.sample.color])
      or profile.colorTypes.none
    button.Border:SetVertexColor(unpack(color))
    button.Border:SetShown(profile.borderStyle ~= 3)
  else
    Icons:Apply(button, profile, scene.appearance.style, entry.style, entry.aura)
    button:SetScript("OnUpdate", nil)
  end
  button.sample = entry.sample
  button.DurationHit:SetShown(profile.showDuration)
  button.StackHit:SetShown(entry.sample.stacks > 1)
  button.CountdownHit:SetShown(profile.showStdCooldown)
  timing(scene, button, GetTime(), true)
  button:Show()
end

local function center(scene)
  local profile = scene.profile
  local width, height = scene.block:GetSize()
  local plateWidth, plateHeight = scene.plate:GetSize()
  local from, to = anchorXY[profile.buffAnchorPoint], anchorXY[profile.plateAnchorPoint]
  local x = to[1] * plateWidth + profile.xOffset - from[1] * width
  local y = to[2] * plateHeight + profile.yOffset - from[2] * height
  local left, right = mmin(-plateWidth / 2, x - width / 2), mmax(plateWidth / 2, x + width / 2)
  local bottom, top = mmin(-plateHeight / 2, y - height / 2 - 24), mmax(plateHeight / 2 + 16, y + height / 2 + 24)
  PreviewViewport:Center(scene.viewport, (left + right) / 2, (bottom + top) / 2)
end

function PreviewScene:Refresh(scene, profile, selected, more, animate)
  scene.profile, scene.appearance, scene.animate = profile, Appearance:Build(profile), animate
  scene.plate:Refresh()
  local count, flowGroups = 0, {}
  for _, group in ipairs(buildGroups(profile, selected, more)) do
    local elements = {}
    local limit = Client.modern and (profile.modernMaxPerGroup or profile.buffPerLine * profile.numLines)
      or profile.buffPerLine * profile.numLines
    for index = 1, mmin(#group.records, limit) do
      count = count + 1
      local button = scene.buttons[count] or createButton(scene)
      scene.buttons[count] = button
      apply(scene, button, group.records[index])
      elements[#elements + 1] = button
    end
    flowGroups[#flowGroups + 1] = {
      elements = elements,
      elementSpacing = profile.xInterval,
      lineSpacing = profile.yInterval,
      groupSpacing = 0,
      groupLineSpacing = 0,
    }
  end
  for index = count + 1, #scene.buttons do
    scene.buttons[index]:Hide()
  end
  if Client.modern then
    scene.layout:SetMaximumLineSize(
      profile.buffPerLine * profile.baseWidth + (profile.buffPerLine - 1) * profile.xInterval
    )
    scene.layout:Apply(scene.block, flowGroups)
    scene.block:ClearAllPoints()
    scene.block:SetPoint(
      profile.buffAnchorPoint,
      scene.plate,
      profile.plateAnchorPoint,
      profile.xOffset,
      profile.yOffset
    )
  else
    Layout:Arrange(scene.block, scene.buttons, count, profile, scene.plate)
  end
  center(scene)
end

function PreviewScene:Animate(scene, elapsed)
  scene.elapsed = scene.elapsed + elapsed
  if scene.elapsed < 0.05 then
    return
  end
  scene.elapsed = 0
  for _, button in ipairs(scene.buttons) do
    if button:IsShown() then
      timing(scene, button, GetTime(), false)
    end
  end
end

function PreviewScene:Create(parent)
  local scene = { buttons = {}, started = GetTime(), elapsed = 0 }
  scene.viewport = PreviewViewport:Create(parent)
  scene.plate = PreviewNameplate:Create(scene.viewport.scene)
  scene.block = CreateFrame("Frame", nil, scene.plate)
  if Client.modern then
    scene.layout = CreateFlowLayout()
    scene.layout:SetAnchorPoint("BOTTOMLEFT")
    scene.layout:SetGrowthDirection(FlowDirection.Right, FlowDirection.Up)
  end
  return scene
end
