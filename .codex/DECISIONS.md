# Pull request decisions

## PR #4: Settings require explicit approval — 2026-10-05

Status: directed by the maintainer in this chat.

Do not invent settings. New settings require an explicit request or approval
before implementation; broad rewrite, UI cleanup, or parity requests do not
authorize unrelated controls. This policy applies to both FPB and Nameplate
Auras. The maintainer explicitly ordered removal of assistant-invented settings
after discovering the in-addon Enable checkbox.

Remove the in-addon Enable and Allow tooltips in combat settings, their runtime
branches, and their saved flags. Preserve original FPB settings and additions
with a direct user request, including Target only (2026-10-01), the category
controls, and the requested preview controls. Nameplate Auras also loses its
unrequested Show stacks switch; original FPB always rendered stacks.

Remove the separately scoped per-group icon cap on modern clients. Keep the
Classic total row limit. Restrict aura and plate anchor menus to the original
bottom-three and top-three choices. Modern sorting keeps duration, default,
reverse, mine-first, and larger-first behavior; remove name, application-order,
defensive, important, debuff-priority, and listed-first additions. Clear only
retired saved keys/choices so they cannot keep controlling hidden behavior.

This supersedes the internal-enable behavior introduced during this PR,
including its native-aura restore/reapply branches. The CVar policy below
remains in effect.

Follow-up: after seeing the individual controls, the maintainer explicitly
approved keeping all six additional modern sort methods (Name, NameOnly,
AuraInstanceIDOnly, BigDefensive, ImportantOnly, UnitFrameDebuff) and the
listed-first group order in both addons. Restore those choices and preserve
their saved values without removing original sorting choices. He also approved
keeping Nameplate Auras' Show stacks switch and extra duration/stack positions.
This supersedes their removal above. Enable, combat-tooltip permission, and
the per-style-group cap remain removed. The anchor question requested an
explanation; it did not approve restoring the extra anchor choices or adding
Nameplate Auras-only controls to FPB.

Validation: the full local check script passes, including saved-profile cleanup
and five-client lifecycle fixtures. No live-client validation of these removals
has been performed.

## PR #4: CVar ownership — 2026-10-05

Status: accepted by the maintainer.

- Fresh profiles leave the user's current game CVars untouched. Native aura
  hiding is opt-in; existing explicit saved CVar preferences remain supported.
- Deliberate CVar changes persist through logout and exit. Do not restore CVars
  automatically to anticipate the user later disabling or uninstalling FPB.

The maintainer stated this policy in the chat while addressing the
[logout-restoration review comment](https://github.com/rbgdevx/flyplate-buffs-fixed/pull/4#discussion_r4188333199).
It supersedes automatic native-aura hiding for fresh FPB profiles in this PR.

Validation: mocked tests cover unchanged CVars on fresh profiles across all five
client interfaces, persistence of an explicit hide preference, and unchanged
CVars on logout. This is not an in-game validation.
