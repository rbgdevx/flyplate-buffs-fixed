local _, fPB = ...

local ipairs = ipairs
local CreateFrame = CreateFrame
local GenerateClosure = GenerateClosure
local NamePlateEnemyFrameOptions = NamePlateEnemyFrameOptions
local NamePlateSetupOptions = NamePlateSetupOptions
local GetNamePlateSize = C_NamePlate.GetNamePlateSize

local PreviewNameplate = {}
fPB.PreviewNameplate = PreviewNameplate

local function showSampleLevel()
  -- Forever's native anchors reserve room for this ordinary NPC's level badge.
  return true
end

local function refreshPlate(unitFrame, self)
  self:SetSize(GetNamePlateSize())
  -- Apply only native layout/style, never SetUpFrame/SetUnit/UpdateAll.
  unitFrame:ApplyFrameOptions(NamePlateSetupOptions, NamePlateEnemyFrameOptions)
  -- Applying options queues CompactUnitFrame's deferred aura work; this
  -- unbound visual has neither live auras nor any unit updates to process.
  unitFrame:SetScript("OnUpdate", nil)
  unitFrame.LevelFrame:SetShown(NamePlateEnemyFrameOptions.showLevel)
  if NamePlateEnemyFrameOptions.colorNameBySelection then
    unitFrame.name:SetVertexColor(1, 0, 0)
  else
    unitFrame.name:SetVertexColor(1, 1, 1)
  end
end

local function createUnitFrame(plate)
  -- Own the visual template directly. Binding a real unit through the shared
  -- driver lets secret health reach addon-tainted CompactUnitFrame callbacks.
  local unitFrame = CreateFrame("Button", nil, plate, "NamePlateUnitFrameTemplate")
  unitFrame:SetAllPoints(plate)
  unitFrame:SetNamePlateFrame(plate)
  unitFrame:UnregisterAllEvents()
  unitFrame:SetScript("OnEvent", nil)
  unitFrame:SetScript("OnUpdate", nil)

  return unitFrame
end

local function hideLiveRegions(unitFrame)
  unitFrame.AurasFrame:Hide()
  unitFrame.CastBarsContainer:Hide()
  unitFrame.CastBarsContainer.castBar:UnregisterAllEvents()
  unitFrame.CastBarsContainer.castBar:SetScript("OnUpdate", nil)
  unitFrame.ClassificationFrame:Hide()
  unitFrame.RaidTargetFrame:Hide()
  unitFrame.SoftTargetFrame:Hide()
  unitFrame.behindCameraIcon:Hide()

  for _, texture in ipairs(unitFrame.aggroHighlightTextures) do
    texture:Hide()
  end

  for _, key in ipairs({
    "myHealPrediction",
    "otherHealPrediction",
    "totalAbsorb",
    "totalAbsorbOverlay",
    "overAbsorbGlow",
    "myHealAbsorb",
    "myHealAbsorbLeftShadow",
    "myHealAbsorbRightShadow",
    "overHealAbsorbGlow",
  }) do
    unitFrame[key]:Hide()
  end
end

local function setSampleValues(unitFrame)
  local healthBar = unitFrame.healthBar
  healthBar:SetMinMaxValues(0, 100)
  healthBar:SetValue(75)
  healthBar:SetStatusBarColor(1, 0, 0)
  healthBar:SetIsTarget(false)

  unitFrame.name:SetText("Example nameplate")
  unitFrame.LevelFrame.LevelText:SetText("60")
  unitFrame.LevelFrame.LevelText:SetVertexColor(1, 1, 0)
end

local function setSampleBadge(unitFrame)
  -- Forever's badge has a display predicate; Retail's separate PvP badge does not.
  local levelBadge = unitFrame.PlayerLevelDiffFrame
  if levelBadge and levelBadge.ShouldDisplay then
    levelBadge.ShouldDisplay = showSampleLevel
    levelBadge.playerLevelDiffText:SetPoint("CENTER", levelBadge.playerLevelDiffIcon, "CENTER", 0, 0)
    levelBadge.playerLevelDiffText:SetText("60")
    levelBadge.playerLevelDiffText:SetVertexColor(1, 1, 0)
    levelBadge.highLevelTexture:Hide()
    levelBadge:SetIsTarget(false)
    levelBadge:Show()
  end
end

function PreviewNameplate:Create(parent)
  local plate = CreateFrame("Frame", nil, parent, "NamePlateScriptBaseTemplate")
  plate:SetPoint("CENTER")
  plate:EnableMouse(false)

  local unitFrame = createUnitFrame(plate)
  hideLiveRegions(unitFrame)
  setSampleValues(unitFrame)
  setSampleBadge(unitFrame)

  plate.Refresh = GenerateClosure(refreshPlate, unitFrame)
  plate:SetScript("OnShow", plate.Refresh)
  plate:Refresh()

  return plate
end
