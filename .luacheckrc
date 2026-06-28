-- Static analysis for the fly-plate-buffs-fixed WoW addon.  Run from the repo root: luacheck .
--
-- Tailored to the addon: WoW globals seeded from its .luarc.json and completed
-- with a harvest of APIs the code actually calls (luacheck has no WoW API
-- library of its own, unlike the LSP's WoW addon the .luarc.json leans on).
-- NOTE: luacheck must run under Lua <= 5.4 (it crashes on 5.5). The `luacheck`
-- on PATH is built against lua@5.4; we still lint WoW's 5.1 dialect via std.

std = "lua51"            -- WoW runs Lua 5.1
max_line_length = false  -- WoW addon lines are routinely wide

exclude_files = {
  ".claude", ".vscode",
  -- External embedded libraries (NOT ours).
  "libs/AceConfig-3.0", "libs/AceDB-3.0", "libs/AceDBOptions-3.0",
  "libs/AceGUI-3.0", "libs/AceGUI-3.0-SharedMediaWidgets",
  "libs/CallbackHandler-1.0", "libs/LibSharedMedia-3.0", "libs/LibStub",
}

-- WoW idioms that aren't defects, handled at config level:
--   unused_args=false — WoW event/callback/option handlers carry positional
--     params (event, unitID, option, widget...) that a given handler often
--     doesn't use. These are API-fixed signatures, not dead code.
--   432/self — `something:SetScript("OnX", function(self) ... end)` inside a
--     `:Method()` shadows the outer `self`. Idiomatic; the inner self is the
--     widget. (Non-self shadows are still flagged and fixed in source.)
unused_args = false
ignore = { "432/self" }

-- Globals the addon DEFINES/WRITES (saved-vars, slash handlers).
globals = {
  "flyPlateBuffsFixed", "flyPlateBuffsFixedDB",
  "SLASH_FLYPLATEBUFFSFIXED1", "SLASH_FLYPLATEBUFFSFIXED2", "SlashCmdList",
}

-- Blizzard client API (and optional deps) the addon READS.
read_globals = {
  "Clamp", "C_NamePlate", "C_Spell", "C_UnitAuras", "CompactUnitFrame_IsOnThreatListWithPlayer",
  "CompactUnitFrame_IsTapDenied", "CompactUnitFrame_UpdateName", "CreateFrame",
  "DEFAULT_CHAT_FRAME", "DISABLE", "ElvUI", "Enum", "GameTooltip", "GetCVar", "GetCVarDefault",
  "GetLocale", "GetNamePlateForUnit", "GetNamePlates", "GetSpellInfo", "GetSpellTexture",
  "GetTime", "GetUnitName", "InCombatLockdown", "IsInInstance", "Item", "LibStub",
  "Masque", "ReloadUI", "SetCVar", "Settings", "TooltipDataProcessor", "UIParent",
  "UnitAffectingCombat", "UnitAura", "UnitBuff", "UnitDebuff", "UnitIsEnemy",
  "UnitIsFriend", "UnitIsPlayer", "UnitIsUnit", "UnitName", "UnitPlayerControlled",
  "UnitSelectionColor", "WOW_PROJECT_CLASSIC", "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE",
  "WorldFrame", "abs", "ceil", "date", "debugprofilestop", "floor", "format", "geterrorhandler",
  "hooksecurefunc", "max", "min",
  "issecretvalue", "securecallfunction", "sort", "strfind", "strmatch", "strsplit",
  "strtrim", "time", "tinsert", "tremove", "wipe",
}
