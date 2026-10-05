# Pull request decisions

## PR #4: Settings require explicit approval — 2026-10-05

Status: final scope explicitly accepted by the maintainer in this chat on
2026-10-05, after reviewing the individual controls and dropdown choices.

Do not invent settings. New settings require the maintainer's explicit request
or approval; broad rewrite, UI cleanup, and parity requests do not authorize
unrelated controls. This policy applies to both FPB and Nameplate Auras.

Remove only these two controls from both addons:
- The internal Enable checkbox, its saved flag, and its runtime branches.
- The separate per-style-group icon cap, its saved value, and its live/preview
  limits. Classic FPB retains its original Icons per row and Maximum rows.

Keep all other controls discussed in the audit, including the six additional
modern sort methods (Name, NameOnly, AuraInstanceIDOnly, BigDefensive,
ImportantOnly, UnitFrameDebuff), listed-first group ordering, Allow tooltips in
combat, all nine choices in both anchor dropdowns, and Nameplate Auras' Show
stacks and extra duration/stack positions. Preserve their saved values and
existing defaults. Original FPB settings and directly requested additions,
including Target only, category filters, spell controls, and preview controls,
remain. Retaining NPA-only controls does not add them to FPB.

This final decision supersedes the earlier blanket-removal direction and the
intermediate removal of those subsequently approved controls. The initial
concern was the assistant-added Enable setting; the maintainer narrowed the
scope after distinguishing new controls from extra dropdown choices. No
internal-enable state or restore/reapply branch tied to it is retained.

The CVar ownership decision below remains in effect. Logout does not restore
explicit game-setting changes in anticipation of disable or uninstall.

Validation: the full local check script passes, including saved-profile
preservation and five-client lifecycle fixtures. The latest settings changes
have automated coverage only; they have not been deployed for client testing.

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
