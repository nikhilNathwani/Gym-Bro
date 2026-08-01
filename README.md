# Gym Log

Personal iOS app for logging workouts — routines, exercises, sets, and history — backed by Supabase.

## Overview

Gym Log is a SwiftUI iOS app for tracking strength-training workouts. Routines (e.g. "Day A - Vertical", "Cardio") contain exercises, each with a target (sets × reps), reference cues, and a running history of past sessions. During a workout, Prev/Next paging steps through a routine's exercises on one shared editing surface — the same page used for standalone exercise lookups outside a workout. Nothing is logged until you actually act: opening an exercise to check cues or last time's numbers never silently creates a session.

## Highlights

- Routine → exercise → set hierarchy with lazy log creation (a workout session/exercise log only exists once a set is actually added)
- Optimistic, per-field persistence to Supabase, with the controller pinned to `@MainActor` to prevent concurrent stepper taps from racing each other and losing an update
- Full editable history per exercise — past sessions can be corrected or deleted, not just viewed after the fact
- One shared exercise page (name/target/cues/today's log/last time/history) reused mid-routine and standalone, replacing what used to be two separate, driftable pages
- Free-tier device installs (no paid Apple Developer account) kept alive indefinitely via a scheduled auto-rebuild/reinstall job — see `scripts/README.md`

## Tech Stack

- SwiftUI (iOS 17+)
- Supabase (Postgres backend via `supabase-swift`)
- XcodeGen (`project.yml` → generated `.xcodeproj`, not committed)
- XCTest UI tests

## Project Structure

```text
project.yml              # XcodeGen project definition
Secrets.xcconfig.example  # Template for local Supabase credentials

Sources/
  GymLogApp.swift         # App entry point
  Data/
    Models.swift           # Routine/Exercise/SetLog/ExerciseLog domain types
    SupabaseService.swift  # All Supabase reads/writes
    RoutineLetter.swift
  Components/
    ExerciseLogController.swift  # Editable state + persistence for one exercise
    ExerciseLoggingViews.swift   # Today's Log / Last Time / Cues / History sections
    HistoryEntryView.swift       # Past-session summary + inline batch editor
    AssignExercisePickerView.swift
    AddExerciseToRoutineSheet.swift
    Styles.swift
  Views/
    RoutinesListView.swift
    RoutineDetailView.swift
    WorkoutSessionView.swift    # Prev/Next paging through a routine's exercises
    ExerciseDetailView.swift    # Standalone (no paging) exercise page
    ExerciseLibraryView.swift
    NewExerciseView.swift
    AppRoute.swift

UITests/
  GymLogSmokeTests.swift

scripts/
  refresh-device-build.sh   # Rebuilds + reinstalls on-device every 5 days
  com.nikhilnathwani.gymlog.refresh.plist
  README.md                 # Why + how the auto-refresh automation works
```

## Environment Variables

Copy the example config and fill in real values:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

```text
SUPABASE_HOST = your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
```

`Secrets.xcconfig` is gitignored. Pull the Supabase host/anon key from the Supabase dashboard, or from the pre-Swift Next.js version of this app (see the commit before "Pivot Gym Bro from Next.js to native Swift/SwiftUI") if you still have its `.env.local` lying around.

## Getting Started

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open GymLog.xcodeproj
```

Build and run from Xcode onto a simulator or device (⌘R), or from the command line:

```bash
xcodebuild -scheme GymLog -destination 'generic/platform=iOS Simulator' build
```

## Scripts

`scripts/` handles keeping a free-tier (non-Developer-Program) device install alive past Apple's 7-day signing expiry, via a `launchd` job that rebuilds and reinstalls every 5 days with zero manual intervention. See `scripts/README.md` for the full setup, log locations, and how to check on it.

## Why This Project

Gym Log is a real app I use for my own workouts, not a demo — that shows in the details: careful handling of concurrent writes to a shared backend, a data model that only persists what you actually did (not what a UI defaulted to), and deployment automation solving an actual constraint (free-tier code-signing expiry) rather than a hypothetical one.
