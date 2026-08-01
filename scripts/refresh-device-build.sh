#!/bin/bash
# Keeps the free-tier ("Personal Team") signature on Nikhil's phone from
# expiring. Apple caps free development provisioning at 7 days — after that
# the installed app simply refuses to launch until it's rebuilt and
# reinstalled. This script does that rebuild+reinstall on a recurring
# schedule (see com.nikhilnathwani.gymlog.refresh.plist) so it never comes
# up as something Nikhil has to remember.
#
# Deliberately quiet on success (append to the log only) and only pushes a
# macOS notification on failure — per Nikhil's ask: "don't require
# intervention from me unless there is an issue."
#
# Requires the Mac to be awake and the phone on the same Wi-Fi network at
# run time. Triggered daily at 3:01am (see the .plist's StartCalendarInterval)
# — 1 minute after `sudo pmset repeat wake` brings the Mac up — but only
# actually rebuilds+reinstalls every REFRESH_INTERVAL_DAYS; every other day
# this exits immediately after the freshness check below, near-instant and
# silent, and requiring no permissions on its own to reach $STATE_FILE (a
# path outside any TCC-protected folder).

set -uo pipefail

PROJECT_DIR="/Users/nikhilnathwani/Documents/Projects/Gym Log"
DEVICE_ID="EBE19FC4-41CE-59E7-8F79-3BD8735FD6C4"
BUNDLE_ID="com.nikhilnathwani.gymlog"
DERIVED_DATA="$HOME/Library/Developer/GymLogAutoRefresh"
LOG_FILE="$HOME/Library/Logs/gymlog-refresh.log"
APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/GymLog.app"
STATE_FILE="$HOME/Library/Application Support/GymLogRefresh/last-success-epoch"
REFRESH_INTERVAL_DAYS=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

mkdir -p "$(dirname "$STATE_FILE")"
if [ -f "$STATE_FILE" ]; then
    last_success=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    days_since=$(( (now - last_success) / 86400 ))
    if [ "$days_since" -lt "$REFRESH_INTERVAL_DAYS" ]; then
        log "not due yet (last success ${days_since}d ago, refreshing every ${REFRESH_INTERVAL_DAYS}d) — skipping"
        exit 0
    fi
fi

# xcodebuild/xcrun/xcodegen live under Xcode's own bin dirs, which a
# launchd job's minimal environment doesn't have on PATH by default.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"

notify_failure() {
    osascript -e "display notification \"$1\" with title \"Gym Log auto-refresh failed\" sound name \"Basso\"" >/dev/null 2>&1 || true
}

log "=== refresh starting ==="

cd "$PROJECT_DIR" || { log "FATAL: project dir not found"; notify_failure "Project directory missing"; exit 1; }

# Deliberately does NOT run `xcodegen generate` — this refresh exists only
# to re-sign whatever's already built and committed, not to pick up new
# source files or dependency changes (that happens during an active
# session, where xcodegen is already run manually right after editing).
# Skipping it also avoids needing a separate Full Disk Access grant for
# xcodegen specifically, on top of bash's.
xcodebuild -project GymLog.xcodeproj -scheme GymLog \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=iOS' -allowProvisioningUpdates build >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    log "FATAL: build failed"
    notify_failure "Build failed — check ~/Library/Logs/gymlog-refresh.log"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    log "FATAL: built app not found at $APP_PATH"
    notify_failure "Built app missing after successful build (unexpected)"
    exit 1
fi

# The device connection has been observed to fail transiently and succeed
# on an immediate retry (same behavior seen manually), so retry a few times
# before treating it as a real failure.
installed=false
for attempt in 1 2 3 4 5; do
    if xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" >> "$LOG_FILE" 2>&1; then
        installed=true
        break
    fi
    log "install attempt $attempt failed, retrying in 20s"
    sleep 20
done

if [ "$installed" = false ]; then
    log "FATAL: install failed after 5 attempts (phone likely off Wi-Fi or unreachable)"
    notify_failure "Couldn't reach your phone after 5 tries — is it on your home Wi-Fi?"
    exit 1
fi

date +%s > "$STATE_FILE"
log "=== refresh succeeded ==="
exit 0
