# CLAUDE.md

Project-specific rules for Gym Log. These supplement the user's global `~/.claude/CLAUDE.md`.

## Delete confirmations must gate the actual state change

Never remove a row/item from the UI or DB optimistically and then show the confirmation dialog after — the item must stay present and unchanged until the user confirms. An optimistic delete-then-reappear-on-cancel pattern has been reported and reverted twice as a bug (a set's delete, and a history row's delete both hit this). Confirm first, mutate state second.

## Supabase test fixtures must be uniquely-named and self-cleaning

The live Supabase DB backs both real workout data and automated UI tests — there is no separate test database. Any fixture created by a UI test or manual testing session must:
- Use a name that can't collide with real data (e.g. a `UITest `/`[Test] ` prefix).
- Be cleaned up by the test/session that created it, since leftover debris from a failed run breaks the next run (this caused repeated UI test failures: "no concurrent DB writes", "leftover test exercise").

## XcodeGen is the source of truth for the Xcode project

This project uses XcodeGen (`project.yml` at repo root). Adding, removing, or moving Swift files requires running `xcodegen generate` — never hand-edit `project.pbxproj` directly. `pbxproj` has explicit (non-synchronized) file entries, so a new file that isn't regenerated into the project won't compile even if it sits in the right folder on disk.
