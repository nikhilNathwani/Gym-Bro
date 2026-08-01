#!/bin/zsh
# Builds Gym Log for iOS Simulator and launches it — called by
# Automations/launchProject.sh's Gym Log branch as the Xcode-world
# equivalent of that script's "start dev server, open browser" step for
# web projects: a running, up-to-date build waiting by the time you're
# back at the keyboard, not just the source open in Xcode.
#
# Unlike scripts/refresh-device-build.sh (which deliberately skips
# `xcodegen generate` — see its own README), this runs it every time: this
# script only runs interactively at the start of a work session, not
# unattended, so the cheap/idempotent regenerate is worth it to avoid a
# stale-project build failure after pulling changes to project.yml.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "Regenerating Xcode project..."
xcodegen generate

echo "Building GymLog for iOS Simulator..."
xcodebuild -scheme GymLog -destination 'generic/platform=iOS Simulator' build

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/GymLog-*/Build/Products/Debug-iphonesimulator/GymLog.app -maxdepth 0 2>/dev/null | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "Could not find built .app under DerivedData — build may have failed."
    exit 1
fi

UDID=$(xcrun simctl list devices booted | grep -Eo '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
if [[ -z "$UDID" ]]; then
    echo "No booted simulator found — booting one..."
    UDID=$(xcrun simctl list devices available | grep -m1 "iPhone" | grep -Eo '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
    if [[ -z "$UDID" ]]; then
        echo "No available iPhone simulator found."
        exit 1
    fi
    xcrun simctl boot "$UDID"
fi

open -a Simulator
sleep 2

echo "Installing..."
xcrun simctl install "$UDID" "$APP_PATH"

echo "Launching..."
xcrun simctl launch "$UDID" com.nikhilnathwani.gymlog

echo "Done — GymLog is running in the Simulator."
