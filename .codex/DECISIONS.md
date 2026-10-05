# Pull request decisions

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
