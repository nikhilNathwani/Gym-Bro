# Device-install auto-refresh

## Why this exists

I sign into my phone with a free Apple ID ("Personal Team"), not a
paid Apple Developer Program membership ($99/year). Apple caps free
development signing at **7 days** — after that, the installed app simply
refuses to launch until it's rebuilt and reinstalled. This is a hard Apple
platform limit, not something configurable away.

My explicit requirement: I want to use the app for weeks at a time
with **zero manual intervention**, and I've ruled out paying for the
Developer Program. This automation is the answer — a scheduled job on my
Mac rebuilds and reinstalls the app every few days on its own, so the
7-day expiry never actually surfaces as something I have to think about.

## What runs, and when

- **`refresh-device-build.sh`** — rebuilds the app (Release configuration)
  and reinstalls it to my iPhone via `devicectl`. Retries the install
  step a few times (the device connection has been observed to fail
  transiently and succeed on an immediate retry). Silent on success;
  pushes a macOS notification only on failure — per my ask, this
  should never require me to check on it unless something's actually
  wrong.
- **`com.nikhilnathwani.gymlog.refresh.plist`** — the `launchd` (macOS's
  built-in scheduler) job definition. Fires the script daily at **3:01am**.
  The script itself checks a state file and only actually does the
  rebuild+reinstall work every **5th day** (safely under the 7-day
  expiry); other days it's an instant, silent no-op.
- **`sudo pmset repeat wake MTWRFSU 03:00:00`** — run once, outside this
  repo (a system-level power setting, not a file). Wakes the Mac from
  sleep at 3:00am daily (screen stays off) so the 3:01am job actually has
  a chance to run even during stretches where I haven't touched the
  Mac otherwise. `launchd` also remembers missed fires (e.g. Mac was off
  instead of asleep) and runs the job as soon as the Mac next wakes,
  rather than skipping it.

## Where everything lives

| What                                                  | Where                                                                                                                                                                                              |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The rebuild/install script                            | `scripts/refresh-device-build.sh` (this repo)                                                                                                                                               |
| The `launchd` job definition                          | `scripts/com.nikhilnathwani.gymlog.refresh.plist` (this repo) — symlinked from `~/Library/LaunchAgents/com.nikhilnathwani.gymlog.refresh.plist`, which is where macOS actually looks for it |
| Detailed run log                                      | `~/Library/Logs/gymlog-refresh.log`                                                                                                                                                                |
| Raw stdout/stderr from `launchd` itself               | `~/Library/Logs/gymlog-refresh-launchd.log`                                                                                                                                                        |
| State file (last successful run, as a Unix timestamp) | `~/Library/Application Support/GymLogRefresh/last-success-epoch`                                                                                                                                   |
| Build output for these auto-refresh builds            | `~/Library/Developer/GymLogAutoRefresh` (kept separate from normal interactive-dev `DerivedData` on purpose)                                                                                       |
| "Check Gym Log Refresh Status" Shortcut               | Shortcuts app (Mac) — see below; not a file in this repo, since Shortcuts don't export to plain text                                                                                               |

The `~/Library/...` paths above are **machine-local state, not tracked in
git** — only the script and the `.plist` are part of this repo.

## Checking on it

Easiest: run the **"Check Gym Log Refresh Status"** Shortcut (Shortcuts
app, or Spotlight → type its name) — a "Run Shell Script" action piped
into "Quick Look", built manually in the Shortcuts app (not a repo file,
since Shortcuts don't export to plain text). Its script content, kept here
so it can be recreated if lost:

```bash
if [ -f "$HOME/Library/Application Support/GymLogRefresh/last-success-epoch" ]; then
  last=$(cat "$HOME/Library/Application Support/GymLogRefresh/last-success-epoch")
  now=$(date +%s)
  days=$(( (now - last) / 86400 ))
  when=$(date -r "$last" '+%A, %b %d at %I:%M %p')
  if [ "$days" -le 5 ]; then
    echo "HEALTHY -- last refreshed $when ($days days ago)"
  else
    echo "CHECK THIS -- last refreshed $when ($days days ago, expected every 5)"
  fi
else
  echo "NEVER REFRESHED -- no successful run recorded yet"
fi
echo ""
echo "Most recent log entry:"
tail -1 "$HOME/Library/Logs/gymlog-refresh.log" 2>/dev/null
```

Deliberately shows a one-line health verdict plus just the single most
recent log line, not a full log dump — the raw log is mostly installer
noise (`bundleID`, `installationURL`, etc.) that isn't useful for a
glance-and-move-on check.

Or from a terminal, for the full history:

```bash
cat ~/Library/Logs/gymlog-refresh.log
```

It should also show up natively in **System Settings → General → Login
Items & Extensions**, since it's a registered background `launchd` item —
that's the built-in Apple UI for seeing/managing it without opening this
repo at all.

## One-time setup this depended on (already done on my Mac)

If this Mac is ever reset, or set up fresh on a new machine, these three
manual steps need to be redone — none of them are files this repo can
carry for you:

1. **Full Disk Access for `/bin/bash`** (System Settings → Privacy &
   Security → Full Disk Access → add `/bin/bash` via ⌘⇧G in the file
   picker). Without this, the script fails immediately with
   `Operation not permitted` the moment it tries to read anything under
   `~/Documents` (where this project lives) — `launchd`-spawned processes
   don't inherit the file-access grants an interactive Terminal session
   already has.
2. **`sudo pmset repeat wake MTWRFSU 03:00:00`** — the daily wake schedule
   described above.
3. **Load the `launchd` job**:
    ```bash
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nikhilnathwani.gymlog.refresh.plist
    ```
    (The symlink at that path needs to exist first — see the table above.)

## Deliberate design notes

- The script does **not** run `xcodegen generate`. This refresh only
  re-signs whatever's already built and committed — it's not meant to
  pick up new source files or dependency changes (that happens during an
  active coding session, where `xcodegen` is already run manually right
  after editing). Skipping it also avoids needing a _second_ Full Disk
  Access grant, since `xcodegen` is a separate binary from `bash` and
  doesn't inherit bash's grant — each executable in the chain needs its
  own.
- The project intentionally stays inside `~/Documents/Projects` (my
  preferred layout for colocating projects) rather than moving out of
  Apple's TCC-protected folders to sidestep the permission issue — the
  Full Disk Access grant above is the one-time cost of keeping that
  layout.
