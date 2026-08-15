# Retail 12.1 research log

This is a research record, not an implementation plan. No conclusion here authorizes a refactor or behavior change.

## Evidence baseline

- Retail source snapshot: `Gethe/wow-ui-source` commit `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`, build `12.1.0 (69299)`, dated 2026-08-13.
- Primary source areas: `Blizzard_AuraContainer`, `Blizzard_NamePlates`, and generated API documentation in that snapshot.
- Supporting documentation: [Patch 12.1.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes), [Secret values](https://warcraft.wiki.gg/wiki/Secret_Values), and [TOC format](https://warcraft.wiki.gg/wiki/The_TOC_Format).

## Executive conclusion

Reviving the addon for Retail 12.1 on Blizzard's native nameplates is technically feasible, but it is not a compatible port of the Classic aura scanner. Retail needs an independent implementation built around `CustomAuraContainer`, its own SavedVariables database, and a settings surface that describes what Blizzard can securely select for each unit relationship.

The visual core survives: rows of aura icons above a native nameplate, icon textures, durations, cooldown swipes, stacks, colored borders, multiple sizes, spacing, anchoring, and tooltips all have supported 12.1 mechanisms. Exact enemy debuffs/CC and exact friendly buffs also survive. Enemy NPCs in PvE are supported by the same non-assistable-unit rules as enemy players, subject to having an accessible native nameplate.

The material losses are identity-driven. While aura secrecy is active, the addon cannot select exact enemy buffs or exact friendly/player debuffs. `NeverSecret` auras can individually participate in include/exclude matching, but that exemption does not make the surrounding restricted group exact-only. The addon also cannot run the current Lua aura scan, arbitrary four-stage comparator, or duration arithmetic. Enemy buffs and friendly debuffs can still be represented through Blizzard's broad categories, but not with the same per-spell guarantees. The exact Classic whole-button blink remains unproven rather than impossible.

## Settled scope and product decisions

- Classic behavior and its current settings remain unchanged.
- Retail gets separate implementation files, a new settings surface, and its own SavedVariables database. Existing Classic profiles are not migrated into the Retail database.
- The package can use `flyPlateBuffsFixed_Standard.toc` for normal Retail and `flyPlateBuffsFixed_Classic.toc` for all current Classic families. The TOCs can load different manifests and declare different SavedVariables.
- Plunderstorm is not a support target; normal third-party addons do not run there. It is not a user-facing decision.
- The first Retail release targets Blizzard's native nameplates only. Plater, ElvUI, Threat Plates, and other replacement compatibility is deferred.
- Retail remains an agnostic nameplate-aura addon: show auras on players, pets, NPCs, enemies, friendlies, and neutrals wherever the Retail API and native nameplate restrictions permit. It is not designed as PvP-only even though PvP is a common use case.
- Friendly nameplate limitations in restricted PvE content are accepted as platform limitations; they are not to be bypassed.
- Remove OmniCC-specific support and wording from Retail.
- Retail sorting and expiration behavior may differ from Classic. Retail should expose only settings supported by the new API, without disturbing Classic.
- Masque integration should use whatever its current Aura-button API genuinely supports. Do not invent an artificially reduced Masque feature set.
- Retail settings should not attempt to reconfigure restricted aura objects while combat/aura secrecy is active. The acceptable UX is to prevent or close configuration and apply changes only when unrestricted.

## Confirmed Retail aura capability boundary

When aura secrecy is active, old `C_UnitAuras` scanning cannot drive this addon. The Retail display must use `CustomAuraContainer`/`CustomAuraButton`, which lets Blizzard securely select and render auras without exposing their underlying identity and timing data to addon code.

Spell-ID include/exclude matching has an explicit relationship boundary in `AuraContainerUtil.CanApplyIdentityCandidateFilters`:

- Exact helpful buffs on assistable units: permitted.
- Exact harmful debuffs on non-assistable units: permitted.
- Helpful buffs on non-assistable units: spell-ID filters are skipped, unless the aura itself is `NeverSecret`.
- Harmful debuffs on assistable units: spell-ID filters are skipped, unless the aura itself is `NeverSecret`.

In ordinary terms, the new container can support an exact enemy-debuff/CC list and an exact friendly-buff list. It cannot promise an exact enemy-buff list or exact friendly-debuff list. This restriction is based on aura type plus unit relationship, not on a special PvP-only branch.

The `NeverSecret` exemption needs precise treatment. Blizzard evaluates identity permission per aura. If an enemy buff or friendly debuff is not `NeverSecret`, its `includeSpellIDs`/`excludeSpellIDs` check is skipped rather than made to fail. A `NeverSecret` aura can therefore be explicitly excluded from a broad restricted group (Blizzard cites Exhaustion/Sated on friendly units), but an include list containing that ID does not by itself exclude all other secret auras in the group. It is not a general escape hatch for exact restricted lists.

The absence of exact spell matching does not mean the entire aura class is invisible. Aura groups can still use Blizzard's filter strings and candidate categories, including dispel types, stealable state, player/pet source, priority/role/boss/nameplate flags, maximum base duration, and Blizzard-provided sort methods. Which enemy-buff categories ship by default is deliberately undecided.

Native friendly nameplate access is a separate limit from aura-filter capability. A theoretically permitted friendly-buff filter does not make inaccessible friendly nameplates modifiable inside restricted instances.

### Practical context matrix

This describes behavior that remains viable while auras are secret; it does not count an out-of-combat scanner that would lose information when restriction starts.

| Nameplate unit | Exact harmful/debuff rules | Exact helpful/buff rules | Broad/category display | Additional boundary |
| --- | --- | --- | --- | --- |
| Enemy player in battleground/arena | Yes | No | Yes | Exact CC/debuff lists survive. Enemy buffs must be broad/category-driven; individual `NeverSecret` exclusions remain possible. |
| Enemy NPC in combat, encounter, or Mythic+ | Yes | No | Yes | The same relationship rule applies; this is not a PvP-only restriction. |
| Neutral/non-assistable NPC | Yes | No | Yes | Follows non-assistable-unit behavior. |
| Friendly player/pet in accessible content | No | Yes | Yes | Friendly debuffs can be broad/category-driven and can exclude individual `NeverSecret` auras, but cannot become an exact encounter/debuff detector. |
| Player/personal nameplate | No | Yes | Yes | The anti-automation rule also prevents an exact player-debuff identity list. |
| Friendly unit in restricted dungeon/raid nameplate context | Aura filter may be legal, plate modification may not be | Aura filter may be legal, plate modification may not be | Not promised | Native friendly-nameplate access is the controlling limitation. |

Useful broad filter strings confirmed in 12.1 include `PLAYER`, `RAID`, `EXTERNAL_DEFENSIVE`, `CROWD_CONTROL`, `RAID_IN_COMBAT`, `RAID_PLAYER_DISPELLABLE`, `BIG_DEFENSIVE`, `IMPORTANT`, and `DISPELLABLE`, with `!` negation for most filters. Their existence does not settle which ones the addon should enable by default.

## Settings/UX consequences already established by source

The Retail settings cannot be a renamed copy of the Classic settings:

- Relationship and target-type toggles remain meaningful only where the native plate is accessible. The current 12.1 generated documentation does not mark `UnitIsPlayer`, `UnitPlayerControlled`, `UnitIsEnemy`, `UnitIsFriend`, `UnitCanAttack`, `UnitCanAssist`, `UnitReaction`, or `UnitAffectingCombat` as secret-returning APIs.
- Spell lists need to reflect the exact-identity matrix above; the Classic `Show all / mine / spell list` choices are not uniformly reproducible for every unit/aura relationship.
- Retail can expose Blizzard-provided group sorting and direction. The exact 12.1 methods are `Default`, `BigDefensive`, `UnitFrameDebuff`, `ImportantOnly`, `Expiration`, `ExpirationOnly`, `Name`, `NameOnly`, and `AuraInstanceIDOnly`, each with normal/reverse direction. It cannot reproduce the current arbitrary four-stage Lua comparator as-is while aura data is secret.
- Maximum icon count, group layout, icon size, spacing, line behavior, anchors, offsets, application counts, dispel visuals, cooldown swipe, duration text, duration bar, fonts, and text/region styling all have corresponding CustomAuraContainer/CustomAuraButton mechanisms.
- `maxDuration` filters maximum total duration, not remaining duration, and implicitly removes permanent auras.
- Tooltip behavior and any mouse interaction must use the CustomAuraButton-supported path; the Classic tooltip scanner cannot be reused during restriction.
- Any setting that changes group definitions, candidate filters, sort rules, layouts, or restricted button regions should be applied only while aura access is unrestricted.

CustomAuraContainer also constrains configuration topology:

- Creating an aura container in combat is intentionally rejected by the client, so container construction must happen before combat/restriction.
- `AddAuraGroup` allocates a batch of restricted aura buttons and runs `initializeFrame` before applying their access restrictions.
- Existing groups expose setters for filter string, maximum frame count, candidate filters, sort method/direction, and layout.
- `ClearAuraGroups` is intentionally private. Blizzard's comment says clearing would make internally pooled frames irrecoverable and directs users toward reconfiguring existing filters.

Consequently, a Retail profile can safely describe and reconfigure a known set of groups. A profile that changes the number or identity of groups would require recreation of the addon-owned container while unrestricted; there is no public live “clear and rebuild this container” method to rely on.

### Resulting Retail settings experience

This is the behavior boundary, not a proposed visual design:

- Classic users keep the existing pages and `flyPlateBuffsFixedDB` unchanged.
- Retail users get Retail-only pages backed by a different database; no Classic profile is silently interpreted under Retail rules.
- Retail shows only CustomAuraContainer-backed controls. Unsupported Classic controls are absent instead of being displayed but ineffective.
- Spell-rule controls must disclose where exact IDs apply. An exact enemy-debuff rule can work during PvP/PvE restriction; an exact enemy-buff rule cannot be offered with the same promise.
- Settings do not open, or close without applying changes, when either combat lockdown or aura secrecy is active. Changes are applied once unrestricted.
- Masque controls can cover only the button regions registered with Masque. Which regions and dynamic dispel-border behavior survive a skin change remains a prototype result, not an assumed limitation or guarantee.

### Existing Classic setting capability matrix

This maps current controls to platform capability; it does not choose the final Retail layout or defaults.

| Current area | Retail capability | Source-grounded boundary |
| --- | --- | --- |
| Show buffs / show debuffs | Replace | Broad helpful/harmful groups are supported, but `all / mine / spell list` is not uniformly available across every unit relationship. |
| Tooltip | Confirmed | AuraButton has intrinsic secure tooltip handling; the addon enables mouse motion instead of reading aura data itself. |
| Hide permanent effects | Confirmed | Any non-nil `maxDuration` candidate filter implicitly filters permanent auras. |
| Personal resource bar exception | No direct mapping | The current option manipulates Blizzard's old native buff frame. `UnitIsUnit` is secret when unit comparison is restricted, so the Classic identification path is also not safe to carry over by assumption. |
| Player in combat | Condition is confirmed; wrapper behavior needs live acceptance | `UnitAffectingCombat("player")` is not documented as secret. Hiding/showing the addon-owned outer display around restricted children still needs a stock-client test. |
| Unit in combat | Condition is confirmed; wrapper behavior needs live acceptance | `UnitAffectingCombat(nameplateUnit)` is not documented as secret. Nameplate event/update behavior and display visibility should still be exercised in restricted contexts. |
| Players / pets / NPCs / enemies / allies / neutrals | Classification is confirmed where the plate is accessible | The unit-type and reaction APIs used by the current logic are not documented as secret. Applying the resulting show/hide choice to the pooled Retail display still needs live acceptance; friendly-instance and forbidden-plate access are separate constraints. |
| Base width / height, crop, spacing, anchors, offsets | Confirmed | Button regions are created and styled during `initializeFrame`; CustomAuraContainer flow layout controls group sizing, spacing, growth, line size, and group order. |
| Larger self-cast auras | Confirmed | `PLAYER`/`!PLAYER` filter strings allow separate groups and presentation. |
| Per-spell icon scale and text sizes | Relationship-dependent | Can be represented through separately styled exact-ID groups only where spell-ID filtering is permitted. It cannot be promised for exact enemy buffs or exact friendly debuffs. |
| Duration text, decimals, position, font, size | Confirmed | `SetDurationText` uses a secure DurationTextBinding and accepts addon-defined numeric formatters; regions are positioned and styled before restriction. |
| Duration color transition | Confirmed | A DurationTextBinding color curve can use remaining percent, matching the current percentage-based green/yellow/red concept without exposing the duration to Lua. |
| Expiration blink | Prototype required | Animation is possible; the exact Classic compound trigger is not exposed. See the corrected blink section below. |
| Stack count, position, font, size, color | Confirmed | `SetApplicationCount` securely populates an addon-created FontString. |
| Cooldown swipe | Confirmed | `SetDurationCooldown` securely drives an addon-created Cooldown. OmniCC is not required. |
| Border style and dispel-type colors | Confirmed, with Masque interaction test | CustomAuraButton supports one or more dispel-type textures, built-in or custom assets, and custom color maps/curves. |
| Icons per row / maximum rows | Confirmed | Flow layout maximum line size plus group frame limits provide bounded rows and icon counts. |
| Parent to WorldFrame for fixed opacity/scale | Unproven and risky | 12.1 adds secret/forbidden anchoring and parent-change constraints. Do not carry this control forward without a live stock-nameplate prototype. |
| Four-stage arbitrary sorting | Not reproducible as-is | Retail provides one Blizzard comparator plus direction per group and explicit group ordering. Retail sorting needs different controls. |
| Nameplate distance / screen-clamp CVars | CVars still exist | These are nameplate-global controls, not aura-container features. Whether they belong in the new Retail UX remains a later scope decision. |
| Disable Blizzard friendly debuffs | CVar still exists; not a custom-aura feature | It controls Blizzard's own nameplate aura display and does not grant access to restricted friendly plates. |
| Blizzard countdown CVar | No longer required for this display | Retail duration text and swipe can be driven directly through CustomAuraButton. |
| Fix nameplates without names | No established Retail need | The option hooks old CompactUnitFrame behavior and should not be assumed valid against the 12.1 native nameplate rewrite. |
| Add/list/remove spell rules | Partial | Retail candidate identity rules use spell IDs. Name-only rules do not map to `includeSpellIDs`/`excludeSpellIDs`, and exact applicability follows the relationship matrix. |
| Per-spell Always / Mine / Never / Ally / Enemy | Partial | These choices can only affect contexts where exact identity filtering is permitted; they cannot restore forbidden enemy-buff or friendly-debuff identity filtering. |
| Profiles | Confirmed | The Retail TOC can declare a separate SavedVariables name and initialize a separate profile database without reading or migrating the Classic database. |

## Mapping the supplied screenshots to 12.1

The screenshots show one or more icon rows attached above a nameplate, differently sized important auras, icon textures, duration/count text, and colored borders. At that visual level, 12.1 provides all of the necessary primitives:

| Visible behavior | Retail status |
| --- | --- |
| Icons attached above a stock nameplate | Supported on ordinary, accessible Blizzard nameplates; offsets must be tested against every native style and size. |
| Multiple icons and wrapped rows | Supported through aura groups, frame-count limits, and flow layout. |
| Different icon sizes for selected spells | Supported where exact identity filters are legal; not guaranteed for individually named enemy buffs or friendly debuffs. Category-level groups can still have different sizes. |
| Icon artwork | Supported through the secure `SetIcon` binding; addon Lua does not need to read the texture. |
| Remaining time on or below icons | Supported through secure duration text; font, formatter, placement, and color curve are configurable before restriction. |
| Stack/application count | Supported through secure application-count binding. |
| Cooldown sweep | Supported directly; OmniCC integration is unnecessary. |
| Colored aura/dispel border | Supported by CustomAuraButton, with exact Masque interaction still requiring a live test. |
| Expiration pulse/blink | A blink-like animation is possible; exact current trigger semantics remain unproven. |

So the recognizable presentation can return. What changes is which auras are eligible for individually named rules and how Retail sorts them, not the basic ability to draw that presentation.

## Expiration blink: corrected status

The earlier conclusion that blink must be Classic-only was premature.

- An `AnimationGroup` can be created on each aura button during `initializeFrame`, before Blizzard applies the aura access restriction.
- The unresolved part is the trigger. Classic currently starts its whole-button pulse when both `remaining / total < configuredPercent` and `remaining < 60` are true. Tainted code cannot perform those comparisons on secret duration values.
- The public CustomAuraButton surface provides secure cooldown, duration text, duration bar, and pandemic-region bindings. The button's actual aura `LuaDurationObject` is private; the public bindings consume it but do not expose it to the initializer.
- A duration text color curve can key off one duration property such as remaining percent or remaining seconds, but it controls that FontString rather than a whole-button `AnimationGroup` and does not combine both Classic conditions.
- `AddPandemicRegion` is a secure timed visibility gate for an addon-created region. A pre-created repeating pulse on that region is a credible blink-like prototype, but Blizzard computes a refresh/pandemic window, not the addon's configured `percent AND under 60 seconds` window.
- No documented public API accepts the resulting secret duration condition as a `Play`/`Stop` gate for an `AnimationGroup`.

Therefore Retail blink remains a research/live-prototype item. A blink-like presentation may be possible; exact Classic semantics are not yet proven and must not be promised or ruled out without a prototype on the live client.

## Native Blizzard nameplate findings

12.1 substantially changed the native nameplate implementation as well as auras:

- Blizzard now creates ordinary and forbidden nameplate frame pools and handles `NAME_PLATE_*` plus `FORBIDDEN_NAME_PLATE_*` event families.
- `C_NamePlate.GetNamePlateForUnit` now has an `includeForbidden` argument defaulting to false. Blizzard passes `issecure()` internally; addon code does not thereby gain access to forbidden plates.
- Creating a `CustomAuraContainer` from addon code during combat intentionally errors. Since ordinary nameplates can be added during combat, the addon cannot wait for each `NAME_PLATE_UNIT_ADDED` event and then construct that plate's Retail aura display from scratch.
- A viable native-nameplate lifecycle therefore requires addon-owned display frames and their aura containers to be created/configured in an unrestricted state, pooled, then assigned a unit and attached when a plate appears. The supplied Platynator uses exactly this corroborating pattern: it preallocates display frames, each display creates its three aura containers during `OnLoad`, and the acquired outer display is later parented to an ordinary nameplate.
- Native frames now expose `AurasFrame`, `HealthBarsContainer`, and `CastBarsContainer`, with multiple nameplate styles and dynamically calculated sizes/anchors.
- Retail exposes seven nameplate styles (`Modern`, `Thin`, `Block`, `HealthFocus`, `CastFocus`, `Legacy`, and `Classic`) and five sizes. Aura attachment/offset behavior must be verified across them rather than assuming one fixed health-bar geometry.
- Blizzard's nameplate settings now separately control enemy-NPC buffs/debuffs/crowd-control, enemy-player buffs/debuffs/loss-of-control, and friendly-player aura categories. These govern Blizzard's `AurasFrame`; they do not change CustomAuraContainer identity permissions.
- The addon's current attempt to hide `frame.UnitFrame.BuffFrame` does not match the 12.1 native frame path, which is `frame.UnitFrame.AurasFrame` with separate buff/debuff list frames. Record this as an existing compatibility defect; do not fix it during research.

The first Retail implementation needs a stock-nameplate attachment audit and live verification across ordinary versus forbidden plates, all native style/size combinations, and coexistence with or suppression of Blizzard's own `AurasFrame`. Third-party frame-shape fallbacks in the Classic code are out of scope for the initial Retail release.

### Platynator comparison

The supplied Platynator copy is useful implementation corroboration but is not treated as Blizzard authority. Its Retail path:

- parents an addon-owned display to the ordinary Blizzard nameplate returned by `C_NamePlate.GetNamePlateForUnit`;
- creates separate `CustomAuraContainer` instances for buffs, debuffs, and crowd control;
- creates icon, cooldown, application text, countdown text, and dispel border regions inside `initializeFrame`;
- uses multiple aura groups for explicit priorities and broad Blizzard categories; and
- defines changes as restricted when either `InCombatLockdown()` or `C_Secrets.ShouldAurasBeSecret()` is true, avoiding aura-frame restyling in that state.

This demonstrates the same API path on native nameplates. It does not prove that every Platynator filter or interaction is correct in every live PvP/PvE context, and its all-client single-file branching is not adopted as an architectural requirement here.

## Masque status

- Masque `12.0.8` declares Retail 12.1 support and removed its own `SetParent` calls because of 12.1 restrictions.
- A CustomAuraButton is an AuraButton intrinsic based on Button, so `GetObjectType()` is `Button`; current Masque `Group:AddButton` accepts it. Registration can occur in `initializeFrame`, before Blizzard applies the aura access restriction.
- Current Masque group options include skin choice, backdrop, shadow, gloss, cooldown color/pulse, supported layer colors, and optional scale. Those options affect only regions the addon actually creates and supplies in the `AddButton` region map; Masque cannot skin a nonexistent layer.
- The addon's existing `Group:AddButton` pattern is directionally relevant, but the exact region map and post-registration reskin timing still require a live prototype.
- Masque source does not provide CustomAuraContainer-specific secret-state handling. The settled restriction UX avoids attempting a reskin while aura buttons are inaccessible.
- Masque's own options UI prevents changes during combat, but its source does not also check `C_Secrets.ShouldAurasBeSecret()`. A PvP-match restriction while out of combat therefore remains a live integration case rather than a proven-safe claim.
- Existing defect found: the addon calls deprecated `MSQ:Register`; in current Masque that is a no-op. Modern callbacks are group callbacks. Record only; do not fix during research.

## Existing defects observed; no fixes authorized

- Native 12.1 uses `frame.UnitFrame.AurasFrame`; the addon attempts to hide `frame.UnitFrame.BuffFrame`, so that compatibility path no longer addresses the native aura frame.
- The addon calls deprecated `MSQ:Register`; current Masque implements it as a no-op.
- `iconOnUpdate` refers to `safeIsMouseOver` before the local function is declared. In Lua that reference resolves to a global, so `pcall(safeIsMouseOver)` receives nil and the intended continuously refreshed hover tooltip path never succeeds.

## Deferred product questions

1. Which broad enemy-buff categories should be enabled by default: important, big defensive, dispellable/stealable, enrage-related, all, or a combination? Decide after the final capability matrix and live prototypes.
2. Rephrased spell-list question: should Retail expose two visibly separate exact-ID rule targets—harmful auras on enemies/neutrals and helpful auras on friendlies—or one spell-rule page where every rule is explicitly limited to those two supported relationships? The unsupported inverse relationships must not look configurable either way.
3. What Retail blink behavior is acceptable if a live prototype proves that the exact Classic compound threshold cannot drive the whole-button animation?
4. When the addon owns a custom Retail display, should Blizzard's native `AurasFrame` remain visible alongside it, or should the addon suppress the native display where safely possible? This needs the live suppression test before choosing.
5. Should the new Retail options retain global nameplate CVar controls such as distance and screen clamp, or leave those to Blizzard's nameplate settings? The CVars still exist, but they are not part of the aura-container feature.

## Live tests still required before implementation claims

- Create/configure aura containers before restriction, then enter combat, an encounter, Mythic+, a battleground, and arena.
- Exhaust and reuse the preallocated display pool while nameplates appear/disappear during combat; verify that the addon never attempts forbidden late container construction.
- Enemy player: exact harmful filter, broad helpful filters, sorting, counts, cooldown, duration text/bar, tooltip, dispel visual, and blink prototype.
- Enemy NPC in open-world and restricted PvE contexts.
- Friendly player/NPC nameplates in open world and instances, distinguishing aura-filter permission from native plate access.
- Ordinary versus forbidden native plates and behavior of `C_NamePlate.GetNamePlateForUnit` from addon code.
- All seven native nameplate styles and five native sizes, including runtime style/size changes.
- Safe suppression or coexistence with Blizzard's native `AurasFrame` without changing unrelated global user preferences.
- Masque initial skin, settings lockout, and post-restriction reskin.
