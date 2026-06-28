local AddonName, fPB = ...
L = fPB.L

local C_NamePlate_GetNamePlateForUnit, C_NamePlate_GetNamePlates, CreateFrame, UnitDebuff, UnitBuff, UnitIsUnit, UnitIsPlayer, UnitPlayerControlled, UnitIsEnemy, UnitIsFriend, GetSpellInfo, table_sort, strmatch, wipe, pairs, GetTime =
  C_NamePlate.GetNamePlateForUnit,
  C_NamePlate.GetNamePlates,
  CreateFrame,
  C_UnitAuras.GetDebuffDataByIndex,
  C_UnitAuras.GetBuffDataByIndex,
  UnitIsUnit,
  UnitIsPlayer,
  UnitPlayerControlled,
  UnitIsEnemy,
  UnitIsFriend,
  C_Spell.GetSpellInfo,
  table.sort,
  strmatch,
  wipe,
  pairs,
  GetTime

local defaultLargeSpells, defaultMediumSpells, defaultHiddenSpells =
  fPB.defaultLargeSpells, fPB.defaultMediumSpells, fPB.defaultHiddenSpells

local LSM = LibStub("LibSharedMedia-3.0")
fPB.LSM = LSM
local MSQ, Group

local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

fPB.db = {}
local db

local tooltip = CreateFrame("GameTooltip", "fPBMouseoverTooltip", UIParent, "GameTooltipTemplate")

local fPBMainOptions
local fPBSpellsList
local fPBProfilesOptions

fPB.chatColor = "|cFFFFA500"
fPB.linkColor = "|cff71d5ff"
local chatColor = fPB.chatColor
local linkColor = fPB.linkColor

local cachedSpells = {}
local PlatesBuffs = {}

local ENUN_SPELL_LIST_DISPLAY_ALL = 1
local ENUM_SPELL_LIST_DISPLAY_MINE_AND_SPELL_LIST = 2
local ENUM_SPELL_LIST_DISPLAY_ONLY_SPELL_LIST = 3
local ENUM_SPELL_LIST_DISPLAY_ONLY_MINE = 4
local ENUM_SPELL_LIST_DISPLAY_NONE = 5

local ENUM_SPELL_DISPLAY_ALWAYS = 1
local ENUM_SPELL_DISPLAY_MINE = 2
local ENUM_SPELL_DISPLAY_NEVER = 3
local ENUM_SPELL_DISPLAY_ON_ALLY = 4
local ENUM_SPELL_DISPLAY_ON_ENEMY = 5

local DefaultSettings = {
  profile = {
    showDebuffs = ENUM_SPELL_LIST_DISPLAY_MINE_AND_SPELL_LIST,
    showBuffs = ENUM_SPELL_LIST_DISPLAY_ONLY_SPELL_LIST,
    showTooltip = false,
    hidePermanent = true,
    notHideOnPersonalResource = true,

    showOnPlayers = true,
    showOnPets = true,
    showOnNPC = true,

    showOnEnemy = true,
    showOnFriend = true,
    showOnNeutral = true,

    showOnlyInCombat = false,
    showUnitInCombat = false,

    parentWorldFrame = false,

    baseWidth = 24,
    baseHeight = 24,
    myScale = 0.2,
    cropTexture = true,

    buffAnchorPoint = "BOTTOM",
    plateAnchorPoint = "TOP",

    xInterval = 4,
    yInterval = 12,

    xOffset = 0,
    yOffset = 4,

    buffPerLine = 6,
    numLines = 3,

    showStdCooldown = true,
    showStdSwipe = false,

    showDuration = true,
    showDecimals = true,
    durationPosition = 1, -- 1 - under, 2 - on icon, 3 - above icon
    font = "Friz Quadrata TT", --durationFont
    durationSize = 10,
    colorTransition = true,
    colorSingle = { 1.0, 1.0, 1.0 },

    stackPosition = 1, -- 1 - on icon, 2 - under, 3 - above icon
    stackFont = "Friz Quadrata TT",
    stackSize = 10,
    stackColor = { 1.0, 1.0, 1.0 },

    blinkTimeleft = 0.2,

    borderStyle = 1, -- 1 = \\texture\\border.tga, 2 = Blizzard, 3 = none
    colorizeBorder = true,
    colorTypes = {
      Magic = { 0.20, 0.60, 1.00 },
      Curse = { 0.60, 0.00, 1.00 },
      Disease = { 0.60, 0.40, 0 },
      Poison = { 0.00, 0.60, 0 },
      none = { 0.80, 0, 0 },
      Buff = { 0.00, 1.00, 0 },
    },

    disableSort = false,
    sortMode = {
      "my", -- [1]
      "expiration", -- [2]
      "disable", -- [3]
      "disable", -- [4]
    },

    Spells = {},
    ignoredDefaultSpells = {},

    showSpellID = false,

    nameplateMaxDistance,
    nameplateInset,
    disableFriendlyDebuffs,
    blizzardCountdown,
    fixNames,
  },
}

do --add default spells
  for i = 1, #defaultLargeSpells do
    local spellID = defaultLargeSpells[i]
    local spellInfo = GetSpellInfo(spellID)
    if spellInfo then
      DefaultSettings.profile.Spells[spellID] = {
        name = spellInfo.name,
        spellID = spellID,
        scale = 2,
        durationSize = 18,
        show = 1, -- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy
        stackSize = 18,
      }
    end
  end

  for i = 1, #defaultMediumSpells do
    local spellID = defaultMediumSpells[i]
    local spellInfo = GetSpellInfo(spellID)
    if spellInfo then
      DefaultSettings.profile.Spells[spellID] = {
        name = spellInfo.name,
        spellID = spellID,
        scale = 1.5,
        durationSize = 14,
        show = 1, -- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy
        stackSize = 14,
      }
    end
  end

  for i = 1, #defaultHiddenSpells do
    local spellID = defaultHiddenSpells[i]
    local spellInfo = GetSpellInfo(spellID)
    if spellInfo then
      DefaultSettings.profile.Spells[spellID] = {
        name = spellInfo.name,
        spellID = spellID,
        scale = 1.0,
        durationSize = 14,
        show = 3, -- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy
        stackSize = 14,
      }
    end
  end
end

--timeIntervals
local minute, hour, day = 60, 3600, 86400
local aboutMinute, aboutHour, aboutDay = 59.5, 60 * 59.5, 3600 * 23.5

local function round(x)
  return floor(x + 0.5)
end

local function FormatTime(seconds)
  if seconds < 10 and db.showDecimals then
    return "%.1f", seconds
  elseif seconds < aboutMinute then
    local seconds = round(seconds)
    return seconds ~= 0 and seconds or ""
  elseif seconds < aboutHour then
    return "%dm", round(seconds / minute)
  elseif seconds < aboutDay then
    return "%dh", round(seconds / hour)
  else
    return "%dd", round(seconds / day)
  end
end

local function GetColorByTime(current, max)
  if max == 0 then
    max = 1
  end
  local percentage = (current / max) * 100
  local red, green = 0, 0
  if percentage >= 50 then
    --green to yellow
    green = 1
    red = ((100 - percentage) / 100) * 2
  else
    --yellow to red
    red = 1
    green = ((100 - (100 - percentage)) / 100) * 2
  end
  return red, green, 0
end

local function SortFunc(a, b)
  local i = 1
  while db.sortMode[i] do
    local mode, rev = db.sortMode[i], db.sortMode[i + 0.5]
    if mode ~= "disable" and a[mode] ~= b[mode] then
      if mode == "my" and not rev then -- self first
        return (a.my and 1 or 0) > (b.my and 1 or 0)
      elseif mode == "my" and rev then
        return (a.my and 1 or 0) < (b.my and 1 or 0)
      elseif mode == "expiration" and not rev then
        return (a.expiration > 0 and a.expiration or 5000000) < (b.expiration > 0 and b.expiration or 5000000)
      elseif mode == "expiration" and rev then
        return (a.expiration > 0 and a.expiration or 5000000) > (b.expiration > 0 and b.expiration or 5000000)
      elseif (mode == "type" or mode == "scale") and not rev then
        return a[mode] > b[mode]
      else
        return a[mode] < b[mode]
      end
    end
    i = i + 1
  end
end

local function GetAnchorFrame(nameplate)
  if nameplate.unitFrame then
    return nameplate.unitFrame
  elseif nameplate.UnitFrame then
    return nameplate.UnitFrame
  else
    return nameplate
  end
end

local function DrawOnPlate(frame)
  if not (#frame.fPBiconsFrame.iconsFrame > 0) then
    return
  end

  local maxWidth = 0
  local sumHeight = 0

  local buffIcon = frame.fPBiconsFrame.iconsFrame

  local breaked = false
  for l = 1, db.numLines do
    if breaked then
      break
    end

    local lineWidth = 0
    local lineHeight = 0

    for k = 1, db.buffPerLine do
      local i = db.buffPerLine * (l - 1) + k
      if not buffIcon[i] or not buffIcon[i]:IsShown() then
        breaked = true
        break
      end
      buffIcon[i]:ClearAllPoints()
      if l == 1 and k == 1 then
        buffIcon[i]:SetPoint("BOTTOMLEFT", frame.fPBiconsFrame, "BOTTOMLEFT", 0, 0)
      elseif k == 1 then
        buffIcon[i]:SetPoint("BOTTOMLEFT", buffIcon[i - db.buffPerLine], "TOPLEFT", 0, db.yInterval)
      else
        buffIcon[i]:SetPoint("BOTTOMLEFT", buffIcon[i - 1], "BOTTOMRIGHT", db.xInterval, 0)
      end

      lineWidth = lineWidth + buffIcon[i].width + db.xInterval
      lineHeight = (buffIcon[i].height > lineHeight) and buffIcon[i].height or lineHeight
    end
    maxWidth = max(maxWidth, lineWidth)
    sumHeight = sumHeight + lineHeight + db.yInterval
  end
  if #PlatesBuffs[frame] > db.numLines * db.buffPerLine then
    for i = db.numLines * db.buffPerLine + 1, #PlatesBuffs[frame] do
      buffIcon[i]:Hide()
    end
  end
  frame.fPBiconsFrame:SetWidth(maxWidth - db.xInterval)
  frame.fPBiconsFrame:SetHeight(sumHeight - db.yInterval)
  frame.fPBiconsFrame:ClearAllPoints()
  local anchorFrame = GetAnchorFrame(frame)
  frame.fPBiconsFrame:SetPoint(db.buffAnchorPoint, anchorFrame, db.plateAnchorPoint, db.xOffset, db.yOffset)
  if MSQ then
    Group:ReSkin()
  end
end

local function AddBuff(
  frame,
  type,
  icon,
  stack,
  debufftype,
  duration,
  expiration,
  my,
  id,
  scale,
  durationSize,
  stackSize
)
  if not PlatesBuffs[frame] then
    PlatesBuffs[frame] = {}
  end
  PlatesBuffs[frame][#PlatesBuffs[frame] + 1] = {
    type = type,
    icon = icon,
    stack = stack,
    debufftype = debufftype,
    duration = duration,
    expiration = expiration,
    scale = (my and db.myScale + 1 or 1) * (scale or 1),
    durationSize = durationSize,
    stackSize = stackSize,
    id = id,
  }
end

local function FilterBuffs(
  isAlly,
  frame,
  type,
  name,
  icon,
  stack,
  debufftype,
  duration,
  expiration,
  caster,
  spellID,
  id
)
  if type == "HARMFUL" and db.showDebuffs == 5 then
    return
  end
  if type == "HELPFUL" and db.showBuffs == 5 then
    return
  end

  local Spells = db.Spells
  local listedSpell
  local my = caster == "player"
  local cachedID = cachedSpells[name]

  if Spells[spellID] and not db.ignoredDefaultSpells[spellID] then
    listedSpell = Spells[spellID]
  elseif cachedID then
    if cachedID == "noid" then
      listedSpell = Spells[name]
    else
      listedSpell = Spells[cachedID]
    end
  end

  -- showDebuffs  1 = all, 2 = mine + spellList, 3 = only spellList, 4 = only mine, 5 = none
  -- listedSpell.show  -- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy
  if not listedSpell then
    if db.hidePermanent and duration == 0 then
      return
    end
    if
      (type == "HARMFUL" and (db.showDebuffs == 1 or ((db.showDebuffs == 2 or db.showDebuffs == 4) and my)))
      or (type == "HELPFUL" and (db.showBuffs == 1 or ((db.showBuffs == 2 or db.showBuffs == 4) and my)))
    then
      AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id)
      return
    else
      return
    end
  else --listedSpell
    if
      (type == "HARMFUL" and (db.showDebuffs == 4 and not my))
      or (type == "HELPFUL" and (db.showBuffs == 4 and not my))
    then
      return
    end
    if
      (listedSpell.show == 1)
      or (listedSpell.show == 2 and my)
      or (listedSpell.show == 4 and isAlly)
      or (listedSpell.show == 5 and not isAlly)
    then
      AddBuff(
        frame,
        type,
        icon,
        stack,
        debufftype,
        duration,
        expiration,
        my,
        id,
        listedSpell.scale,
        listedSpell.durationSize,
        listedSpell.stackSize
      )
      return
    end
  end
end

local function ScanUnitBuffs(nameplateID, frame)
  if PlatesBuffs[frame] then
    wipe(PlatesBuffs[frame])
  end
  local isAlly = UnitIsFriend(nameplateID, "player")
  local id = 1
  while UnitDebuff(nameplateID, id) do
    local aura = UnitDebuff(nameplateID, id)
    if aura then
      local name, icon, stack, debufftype, duration, expiration, caster, spellID =
        aura.name,
        aura.icon,
        aura.applications,
        aura.dispelName,
        aura.duration,
        aura.expirationTime,
        aura.sourceUnit,
        aura.spellId
      FilterBuffs(isAlly, frame, "HARMFUL", name, icon, stack, debufftype, duration, expiration, caster, spellID, id)
      id = id + 1
    end
  end

  id = 1
  while UnitBuff(nameplateID, id) do
    local aura = UnitBuff(nameplateID, id)
    if aura then
      local name, icon, stack, debufftype, duration, expiration, caster, spellID =
        aura.name,
        aura.icon,
        aura.applications,
        aura.dispelName,
        aura.duration,
        aura.expirationTime,
        aura.sourceUnit,
        aura.spellId
      FilterBuffs(isAlly, frame, "HELPFUL", name, icon, stack, debufftype, duration, expiration, caster, spellID, id)
      id = id + 1
    end
  end
end

local function FilterUnits(nameplateID)
  if db and db.showOnlyInCombat and not UnitAffectingCombat("player") then
    return true
  end -- InCombatLockdown()
  if db and db.showUnitInCombat and not UnitAffectingCombat(nameplateID) then
    return true
  end

  -- filter units
  if UnitIsUnit(nameplateID, "player") then
    return true
  end
  if UnitIsPlayer(nameplateID) and (db and not db.showOnPlayers) then
    return true
  end
  if UnitPlayerControlled(nameplateID) and not UnitIsPlayer(nameplateID) and (db and not db.showOnPets) then
    return true
  end
  if not UnitPlayerControlled(nameplateID) and not UnitIsPlayer(nameplateID) and (db and not db.showOnNPC) then
    return true
  end
  if UnitIsEnemy(nameplateID, "player") and (db and not db.showOnEnemy) then
    return true
  end
  if UnitIsFriend(nameplateID, "player") and (db and not db.showOnFriend) then
    return true
  end
  if
    not UnitIsFriend(nameplateID, "player")
    and not UnitIsEnemy(nameplateID, "player")
    and (db and not db.showOnNeutral)
  then
    return true
  end

  return false
end

local total = 0
local function iconOnUpdate(self, elapsed)
  total = total + elapsed
  if total > 0 then
    total = 0
    if self.expiration and self.expiration > 0 then
      local timeLeft = self.expiration - GetTime()
      if timeLeft < 0 then
        -- local frame = self:GetParent():GetParent()
        -- self:Hide()
        -- UpdateUnitAuras(frame.namePlateUnitToken)
        return
      end
      if db.showDuration then
        self.durationtext:SetFormattedText(FormatTime(timeLeft))
        if db.colorTransition then
          self.durationtext:SetTextColor(GetColorByTime(timeLeft, self.duration))
        end
        if db.durationPosition == 1 or db.durationPosition == 3 then
          self.durationBg:SetWidth(self.durationtext:GetStringWidth())
          self.durationBg:SetHeight(self.durationtext:GetStringHeight())
        end
      end
      if (timeLeft / (self.duration + 0.01)) < db.blinkTimeleft and timeLeft < 60 then --buff only has 20% timeleft and is less then 60 seconds.
        local alpha = GetTime() % 1
        if alpha > 0.5 then
          alpha = 1 - alpha
        end
        self:SetAlpha(Clamp(alpha * 3, 0, 1))
      end
      IsSafeToCallIsMouseOver, IsMouseOver = pcall(safeIsMouseOver)
      if IsSafeToCallIsMouseOver and IsMouseOver and db.showTooltip and tooltip:IsShown() then
        tooltip:SetUnitAura(self:GetParent():GetParent().namePlateUnitToken, self.id, self.type)
      end
    end
  end
end
local function safeIsMouseOver(object)
  return object:IsMouseOver()
end
local function GetTexCoordFromSize(frame, size, size2)
  local arg = size / size2
  local abj
  if arg > 1 then
    abj = 1 / size * ((size - size2) / 2)

    frame:SetTexCoord(0, 1, (0 + abj), (1 - abj))
  elseif arg < 1 then
    abj = 1 / size2 * ((size2 - size) / 2)

    frame:SetTexCoord((0 + abj), (1 - abj), 0, 1)
  else
    frame:SetTexCoord(0, 1, 0, 1)
  end
end
local function UpdateBuffIcon(self)
  self:SetAlpha(1)
  self.stacktext:Hide()
  self.border:Hide()
  self.cooldown:Hide()
  self.durationtext:Hide()
  self.durationBg:Hide()
  self.stackBg:Hide()

  self:SetWidth(self.width)
  self:SetHeight(self.height)

  self.texture:SetTexture(self.icon)
  if db.cropTexture then
    GetTexCoordFromSize(self.texture, self.width, self.height)
  else
    self.texture:SetTexCoord(0, 1, 0, 1)
  end

  if db.borderStyle ~= 3 then
    local color
    if self.type == "HELPFUL" then
      color = db.colorTypes.Buff
    else
      if db.colorizeBorder then
        color = self.debufftype and db.colorTypes[self.debufftype] or db.colorTypes.none
      else
        color = db.colorTypes.none
      end
    end
    self.border:SetVertexColor(color[1], color[2], color[3])
    self.border:Show()
  end

  if (db.showStdCooldown or db.showStdSwipe) and self.expiration > 0 then
    local start, duration = self.cooldown:GetCooldownTimes()
    if (start ~= (self.expiration - self.duration)) or duration ~= self.durationthen then
      self.cooldown:SetCooldown(self.expiration - self.duration, self.duration)
    end
  end

  if db.showDuration and self.expiration > 0 then
    if db.durationPosition == 1 or db.durationPosition == 3 then
      self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
      self.durationBg:Show()
    else
      self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "OUTLINE")
    end
    self.durationtext:Show()
  end
  if self.stack > 1 then
    self.stacktext:SetText(tostring(self.stack))
    if db.stackPosition == 2 or db.stackPosition == 3 then
      self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "NORMAL")
      self.stackBg:SetWidth(self.stacktext:GetStringWidth())
      self.stackBg:SetHeight(self.stacktext:GetStringHeight())
      self.stackBg:Show()
    else
      self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "OUTLINE")
    end
    self.stacktext:Show()
  end
end
local function UpdateBuffIconOptions(self, token)
  self.texture:SetAllPoints(self)

  self.border:SetAllPoints(self)
  if db.borderStyle == 1 then
    self.border:SetTexture("Interface\\Addons\\flyPlateBuffsFixed\\texture\\border.tga")
    self.border:SetTexCoord(0.08, 0.08, 0.08, 0.92, 0.92, 0.08, 0.92, 0.92) --хз почему отображает не на всю иконку по дефолту, цифры подбором
  elseif db.borderStyle == 2 then
    self.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    self.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625) -- if "Interface\\Buttons\\UI-Debuff-Overlays"
  end
  if db.showStdSwipe then
    self.cooldown:SetDrawSwipe(true)
    self.cooldown:SetSwipeColor(0, 0, 0, 0.6)
  else
    self.cooldown:SetDrawSwipe(false)
  end
  if db.showStdCooldown then
    self.cooldown:SetHideCountdownNumbers(false)
  else
    self.cooldown:SetHideCountdownNumbers(true)
  end

  if db.showDuration then
    self.durationtext:ClearAllPoints()
    self.durationBg:ClearAllPoints()
    if db.durationPosition == 1 then
      -- under icon
      self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
      self.durationtext:SetPoint("TOP", self, "BOTTOM", 0, -1)
      self.durationBg:SetPoint("CENTER", self.durationtext)
    elseif db.durationPosition == 3 then
      -- above icon
      self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
      self.durationtext:SetPoint("BOTTOM", self, "TOP", 0, 1)
      self.durationBg:SetPoint("CENTER", self.durationtext)
    else
      -- on icon
      self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "OUTLINE")
      self.durationtext:SetPoint("CENTER", self, "CENTER", 0, 0)
    end
    if not colorTransition then
      self.durationtext:SetTextColor(db.colorSingle[1], db.colorSingle[2], db.colorSingle[3], 1)
    end
  end

  self.stacktext:ClearAllPoints()
  self.stackBg:ClearAllPoints()
  self.stacktext:SetTextColor(db.stackColor[1], db.stackColor[2], db.stackColor[3], 1)
  if db.stackPosition == 1 then
    -- on icon
    self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "OUTLINE")
    self.stacktext:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 3)
  elseif db.stackPosition == 2 then
    -- under icon
    self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "NORMAL")
    self.stacktext:SetPoint("TOP", self, "BOTTOM", 0, -1)
    self.stackBg:SetPoint("CENTER", self.stacktext)
  else
    -- above icon
    self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "NORMAL")
    self.stacktext:SetPoint("BOTTOM", self, "TOP", 0, 1)
    self.stackBg:SetPoint("CENTER", self.stacktext)
  end

  if db.showTooltip then
    self:SetScript("OnEnter", function(self)
      if token then
        tooltip:SetOwner(self, "ANCHOR_LEFT")
        tooltip:SetUnitAura(token, self.id, self.type)
      end
    end)
    self:SetScript("OnLeave", function()
      tooltip:Hide()
    end)
  else
    self:EnableMouse(false)
  end
end
local function iconOnHide(self)
  self.stacktext:Hide()
  self.border:Hide()
  self.cooldown:Hide()
  self.durationtext:Hide()
  self.durationBg:Hide()
  self.stackBg:Hide()
end
local function CreateBuffIcon(frame, i)
  frame.fPBiconsFrame.iconsFrame[i] = CreateFrame("Button", AddonName .. "BuffIcon" .. i, frame.fPBiconsFrame)
  frame.fPBiconsFrame.iconsFrame[i]:SetParent(frame.fPBiconsFrame)
  local buffIcon = frame.fPBiconsFrame.iconsFrame[i]

  buffIcon.texture = buffIcon:CreateTexture(nil, "BACKGROUND")

  buffIcon.border = buffIcon:CreateTexture(nil, "BORDER")

  buffIcon.cooldown = CreateFrame("Cooldown", nil, buffIcon, "CooldownFrameTemplate")
  buffIcon.cooldown:SetReverse(true)
  buffIcon.cooldown:SetDrawEdge(false)

  buffIcon.durationtext = buffIcon:CreateFontString(nil, "ARTWORK")

  buffIcon.durationBg = buffIcon:CreateTexture(nil, "BORDER")
  buffIcon.durationBg:SetColorTexture(0, 0, 0, 0.75)

  buffIcon.stacktext = buffIcon:CreateFontString(nil, "ARTWORK")

  buffIcon.stackBg = buffIcon:CreateTexture(nil, "BORDER")
  buffIcon.stackBg:SetColorTexture(0, 0, 0, 0.75)

  UpdateBuffIconOptions(buffIcon, frame.namePlateUnitToken)

  buffIcon.stacktext:Hide()
  buffIcon.border:Hide()
  buffIcon.cooldown:Hide()
  buffIcon.durationtext:Hide()
  buffIcon.durationBg:Hide()
  buffIcon.stackBg:Hide()

  buffIcon:SetScript("OnHide", iconOnHide)
  buffIcon:SetScript("OnUpdate", iconOnUpdate)

  if MSQ then
    Group:AddButton(buffIcon, {
      Icon = buffIcon.texture,
      Cooldown = buffIcon.cooldown,
      Normal = buffIcon.border,
      Count = false,
      Duration = false,
      FloatingBG = false,
      Flash = false,
      Pushed = false,
      Disabled = false,
      Checked = false,
      Border = false,
      AutoCastable = false,
      Highlight = false,
      HotKey = false,
      Name = false,
      AutoCast = false,
    })
  end
end

local function UpdateUnitAuras(nameplateID, updateOptions)
  local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
  if not frame then
    return
  end -- modifying friendly nameplates is restricted in instances since 7.2

  if FilterUnits(nameplateID) then
    if frame.fPBiconsFrame then
      frame.fPBiconsFrame:Hide()
    end
    return
  end

  ScanUnitBuffs(nameplateID, frame)
  if not PlatesBuffs[frame] then
    if frame.fPBiconsFrame then
      frame.fPBiconsFrame:Hide()
    end
    return
  end
  if not db.disableSort then
    table_sort(PlatesBuffs[frame], SortFunc)
  end

  if not frame.fPBiconsFrame then
    -- if parent == frame then it will change scale and alpha with nameplates
    -- otherwise use UIParent, but this causes mess of icon/border textures
    frame.fPBiconsFrame = CreateFrame("Frame")
    local attachmentFrame = GetAnchorFrame(frame)
    frame.fPBiconsFrame:SetFrameStrata("HIGH")
    frame.fPBiconsFrame:SetFrameLevel(attachmentFrame:GetFrameLevel() + 1)
    local parent = db.parentWorldFrame and WorldFrame
    if not parent then
      parent = frame.unitFrame -- for ElvUI
    end
    if not parent then
      parent = frame.TPFrame -- for ThreatPlates
    end
    if not parent then
      parent = frame
    end
    frame.fPBiconsFrame:SetParent(parent)
  end
  if not frame.fPBiconsFrame.iconsFrame then
    frame.fPBiconsFrame.iconsFrame = {}
  end

  for i = 1, #PlatesBuffs[frame] do
    if not frame.fPBiconsFrame.iconsFrame[i] then
      CreateBuffIcon(frame, i)
    end

    local buff = PlatesBuffs[frame][i]
    local buffIcon = frame.fPBiconsFrame.iconsFrame[i]
    buffIcon.type = buff.type
    buffIcon.icon = buff.icon
    buffIcon.stack = buff.stack
    buffIcon.debufftype = buff.debufftype
    buffIcon.duration = buff.duration
    buffIcon.expiration = buff.expiration
    buffIcon.id = buff.id
    buffIcon.durationSize = buff.durationSize
    buffIcon.stackSize = buff.stackSize
    buffIcon.width = db.baseWidth * buff.scale
    buffIcon.height = db.baseHeight * buff.scale
    if updateOptions then
      UpdateBuffIconOptions(buffIcon, frame.namePlateUnitToken)
    end
    UpdateBuffIcon(buffIcon)
    buffIcon:Show()
  end
  frame.fPBiconsFrame:Show()

  if #frame.fPBiconsFrame.iconsFrame > #PlatesBuffs[frame] then
    for i = #PlatesBuffs[frame] + 1, #frame.fPBiconsFrame.iconsFrame do
      if frame.fPBiconsFrame.iconsFrame[i] then
        frame.fPBiconsFrame.iconsFrame[i]:Hide()
      end
    end
  end

  DrawOnPlate(frame)
end

function fPB.UpdateAllNameplates(updateOptions)
  for i, p in ipairs(C_NamePlate_GetNamePlates()) do
    local unit = p.namePlateUnitToken
    if not unit then --try ElvUI
      unit = p.unitFrame and p.unitFrame.unit
    end
    if unit then
      UpdateUnitAuras(unit, updateOptions)
    end
  end
end
local UpdateAllNameplates = fPB.UpdateAllNameplates

local function Nameplate_Added(...)
  local nameplateID = ...
  local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
  if frame.UnitFrame and frame.UnitFrame.BuffFrame then
    if db and db.notHideOnPersonalResource and UnitIsUnit(nameplateID, "player") then
      frame.UnitFrame.BuffFrame:SetAlpha(1)
    else
      frame.UnitFrame.BuffFrame:SetAlpha(0) --Hide terrible standard debuff frame
    end
  end

  UpdateUnitAuras(nameplateID)
end
local function Nameplate_Removed(...)
  local nameplateID = ...
  local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)

  if frame.fPBiconsFrame then
    frame.fPBiconsFrame:Hide()
  end
  if PlatesBuffs[frame] then
    PlatesBuffs[frame] = nil
  end
end

local function FixSpells()
  for spell, s in pairs(db.Spells) do
    if not s.name then
      local name
      local spellID = tonumber(spell) and tonumber(spell) or spell.spellID
      if spellID then
        local spellInfo = GetSpellInfo(spellID)
        if spellInfo then
          name = spellInfo.name
        end
      else
        name = tostring(spell)
      end
      db.Spells[spell].name = name
    end
  end
end
function fPB.CacheSpells() -- spells filtered by names, not checking id
  cachedSpells = {}
  for spell, s in pairs(db.Spells) do
    if not s.checkID and not db.ignoredDefaultSpells[spell] and s.name then
      if s.spellID then
        cachedSpells[s.name] = s.spellID
      else
        cachedSpells[s.name] = "noid"
      end
    end
  end
end
local CacheSpells = fPB.CacheSpells

function fPB.AddNewSpell(spell)
  local spellInfo = GetSpellInfo(spell)
  local spellID = spellInfo and spellInfo.spellID or spell

  local defaultSpell
  if db.ignoredDefaultSpells[spellID] then
    db.ignoredDefaultSpells[spellID] = nil
    defaultSpell = true
  end

  if db.Spells[spellID] and not defaultSpell then
    if spellID then
      if spellInfo then
        DEFAULT_CHAT_FRAME:AddMessage(
          chatColor
            .. L["Spell with this ID is already in the list. Its name is "]
            .. linkColor
            .. "|Hspell:"
            .. spellID
            .. "|h["
            .. spellInfo.name
            .. "]|h|r"
        )
      end
      return
    else
      DEFAULT_CHAT_FRAME:AddMessage(spellID .. chatColor .. L[" already in the list."] .. "|r")
      return
    end
  end
  if spellID and spellInfo then
    if not db.Spells[spellID] then
      db.Spells[spellID] = {
        show = 1,
        name = spellInfo.name,
        spellID = spellID,
        scale = 1,
        stackSize = db.stackSize,
        durationSize = db.durationSize,
      }
    end
  else
    db.Spells[spell] = {
      checkID = true,
      show = 1,
      name = spell,
      scale = 1,
      stackSize = db.stackSize,
      durationSize = db.durationSize,
    }
  end

  CacheSpells()
  fPB.BuildSpellList()
  UpdateAllNameplates(true)
end
function fPB.RemoveSpell(spell)
  if DefaultSettings.profile.Spells[spell] then
    db.ignoredDefaultSpells[spell] = true
  end
  db.Spells[spell] = nil
  CacheSpells()
  fPB.BuildSpellList()
  UpdateAllNameplates(true)
end
function fPB.ChangeSpellID(oldID, newID)
  if db.Spells[newID] then
    local spellInfo = GetSpellInfo(newID)
    if spellInfo then
      DEFAULT_CHAT_FRAME:AddMessage(
        chatColor
          .. L["Spell with this ID is already in the list. Its name is "]
          .. linkColor
          .. "|Hspell:"
          .. newID
          .. "|h["
          .. spellInfo.name
          .. "]|h|r"
      )
    end
    return
  end
  db.Spells[newID] = {}
  for k, v in pairs(db.Spells[oldID]) do
    db.Spells[newID][k] = v
    db.Spells[newID].spellID = newID
  end
  fPB.RemoveSpell(oldID)
  local spellInfo = GetSpellInfo(newID)
  if spellInfo then
    DEFAULT_CHAT_FRAME:AddMessage(
      spellInfo.name
        .. chatColor
        .. L[" ID changed "]
        .. "|r"
        .. (tonumber(oldID) or "nil")
        .. chatColor
        .. " -> |r"
        .. newID
    )
  end
  UpdateAllNameplates(true)
  fPB.BuildSpellList()
end

local function ConvertDBto2()
  local temp
  for _, p in pairs(flyPlateBuffsFixedDB.profiles) do
    if p.Spells then
      temp = {}
      for n, s in pairs(p.Spells) do
        local spellID = s.spellID
        if not spellID then
          for i = 1, #defaultLargeSpells do
            local spellInfo = GetSpellInfo(defaultLargeSpells[i])
            if spellInfo and n == spellInfo.name then
              spellID = defaultLargeSpells[i]
              break
            end
          end
        end
        if not spellID then
          for i = 1, #defaultMediumSpells do
            local spellInfo = GetSpellInfo(defaultMediumSpells[i])
            if spellInfo and n == spellInfo.name then
              spellID = defaultMediumSpells[i]
              break
            end
          end
        end
        local spell = spellID and spellID or n
        if spell then
          temp[spell] = {}
          for k, v in pairs(s) do
            temp[spell][k] = v
          end
          local spellInfo = GetSpellInfo(spell)
          temp[spell].name = spellInfo and spellInfo.name or n
        end
      end
      p.Spells = temp
    end
    if p.ignoredDefaultSpells then
      temp = {}
      for n, v in pairs(p.ignoredDefaultSpells) do
        local spellID
        for i = 1, #defaultLargeSpells do
          local spellInfo = GetSpellInfo(defaultLargeSpells[i])
          if spellInfo and n == spellInfo.name then
            spellID = defaultLargeSpells[i]
            break
          end
        end
        if not spellID then
          for i = 1, #defaultMediumSpells do
            local spellInfo = GetSpellInfo(defaultMediumSpells[i])
            if spellInfo and n == spellInfo.name then
              spellID = defaultMediumSpells[i]
              break
            end
          end
        end
        if spellID then
          temp[spellID] = true
        end
      end
      p.ignoredDefaultSpells = temp
    end
  end
  flyPlateBuffsFixedDB.version = 2
end
function fPB.OnProfileChanged()
  db = fPB.db.profile
  fPB.OptionsOnEnable()
  UpdateAllNameplates(true)
end
local function Initialize()
  if flyPlateBuffsFixedDB and (not flyPlateBuffsFixedDB.version or flyPlateBuffsFixedDB.version < 2) then
    ConvertDBto2()
  end

  fPB.db = LibStub("AceDB-3.0"):New("flyPlateBuffsFixedDB", DefaultSettings, true)
  fPB.db.RegisterCallback(fPB, "OnProfileChanged", "OnProfileChanged")
  fPB.db.RegisterCallback(fPB, "OnProfileCopied", "OnProfileChanged")
  fPB.db.RegisterCallback(fPB, "OnProfileReset", "OnProfileChanged")

  db = fPB.db.profile
  fPB.font = fPB.LSM:Fetch("font", db.font)
  fPB.stackFont = fPB.LSM:Fetch("font", db.stackFont)
  FixSpells()
  CacheSpells()

  config:RegisterOptionsTable(AddonName, fPB.MainOptionTable)
  dialog:AddToBlizOptions(AddonName, AddonName)

  config:RegisterOptionsTable(AddonName .. " Spells", fPB.SpellsTable)
  dialog:AddToBlizOptions(AddonName .. " Spells", L["Specific spells"], AddonName)

  config:RegisterOptionsTable(AddonName .. " Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(fPB.db))
  dialog:AddToBlizOptions(AddonName .. " Profiles", L["Profiles"], AddonName)

  SLASH_FLYPLATEBUFFSFIXED1, SLASH_FLYPLATEBUFFSFIXED2 = "/fpb", "/pb"
  function SlashCmdList.FLYPLATEBUFFSFIXED(msg, editBox)
    if msg == "spells" then
      dialog:Open(AddonName .. " Spells")
    elseif msg == "profiles" then
      dialog:Open(AddonName .. " Profiles")
    else
      dialog:Open(AddonName)
    end
  end
end

function fPB.RegisterCombat()
  fPB.Events:RegisterEvent("PLAYER_REGEN_DISABLED")
  fPB.Events:RegisterEvent("PLAYER_REGEN_ENABLED")
end
function fPB.UnregisterCombat()
  fPB.Events:UnregisterEvent("PLAYER_REGEN_DISABLED")
  fPB.Events:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

fPB.Events = CreateFrame("Frame")
fPB.Events:RegisterEvent("ADDON_LOADED")
fPB.Events:RegisterEvent("PLAYER_LOGIN")

fPB.Events:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" and (...) == AddonName then
    Initialize()
  elseif event == "PLAYER_LOGIN" then
    fPB.OptionsOnEnable()
    fPB.FixBlizzard()
    if db and db.showSpellID then
      fPB.ShowSpellID()
    end
    MSQ = LibStub("Masque", true)
    if MSQ then
      Group = MSQ:Group(AddonName)
      MSQ:Register(AddonName, function(addon, group, skinId, gloss, backdrop, colors, disabled)
        if disabled then
          UpdateAllNameplates(true)
        end
      end)
    end

    fPB.Events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    fPB.Events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    if db and db.showOnlyInCombat then
      fPB.RegisterCombat()
    else
      fPB.Events:RegisterEvent("UNIT_AURA")
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    fPB.Events:RegisterEvent("UNIT_AURA")
    UpdateAllNameplates()
  elseif event == "PLAYER_REGEN_ENABLED" then
    fPB.Events:UnregisterEvent("UNIT_AURA")
    UpdateAllNameplates()
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    Nameplate_Added(...)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    Nameplate_Removed(...)
  elseif event == "UNIT_AURA" then
    if strmatch((...), "nameplate%d+") then
      UpdateUnitAuras(...)
    end
  end
end)
