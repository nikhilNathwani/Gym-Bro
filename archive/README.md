# Archive

`react-native-spike.bundle` — full git history (2 commits) of the React
Native spike that was compared against native SwiftUI before committing to
Swift (see the "Pivot Gym Bro from Next.js to native Swift/SwiftUI" commit
for the verdict and rationale). It lived in a sibling `Gym Bro React`
folder that was never itself a git repo, so this bundle is the only
surviving copy of that history.

To restore it as a working checkout:

```bash
git clone archive/react-native-spike.bundle /path/to/restore
```

The original web app (Next.js + Supabase) that preceded the Swift rewrite
doesn't need a bundle — it's already in this repo's own history, see the
commit right before the pivot.
