import SwiftUI

/// App shell — hosts the single root `NavigationStack` (rooted at
/// `RoutinesListView`, which also owns pushing into the Exercise Library —
/// see its own toolbar) plus a floating "+" FAB that stays contextual to
/// whatever's currently on screen.
///
/// Replaced a two-tab shell (Routines/Exercises, switched via a custom
/// bottom pill nav) once actual usage turned out to be almost entirely
/// inside a Routine — Exercises was rarely a *destination* in its own
/// right, so spending one of only two tab slots on it was disproportionate.
/// It's reached via a toolbar icon on the Routines root instead now, and
/// the FAB's context-awareness collapsed from "which tab, and is a detail
/// screen pushed within it" down to just "which screen is on top of the
/// one shared stack."
struct RootView: View {
    @State private var createRoutineTrigger = false
    @State private var createExerciseTrigger = false
    @State private var addExerciseTrigger = false
    @State private var isRoutineDetailActive = false
    @State private var isExerciseLibraryActive = false
    @State private var isWorkoutSessionActive = false

    var body: some View {
        RoutinesListView(
            createTrigger: $createRoutineTrigger,
            createExerciseTrigger: $createExerciseTrigger,
            addExerciseTrigger: $addExerciseTrigger,
            isRoutineDetailActive: $isRoutineDetailActive,
            isExerciseLibraryActive: $isExerciseLibraryActive,
            isWorkoutSessionActive: $isWorkoutSessionActive
        )
        // The keyboard should float on top of this whole shell, not push it
        // up. Has to sit here, not just on the FAB overlay below — the
        // overlay's position is computed from this view's own frame, so if
        // only the overlay opted out, the frame it aligned against was
        // still shrinking to avoid the keyboard and dragging it up anyway.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            if !isWorkoutSessionActive {
                Color.clear.frame(height: 64)
            }
        }
        // Hidden during a workout session: the context-aware "+" doesn't
        // mean anything mid-workout, and it overlapped
        // WorkoutSessionView's own Next/Finish button in that bottom-right
        // corner.
        .overlay(alignment: .bottomTrailing) {
            if !isWorkoutSessionActive {
                addButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    // Notes-app-style compose button: context-aware down to the pushed
    // screen, not just "are we anywhere under Routines vs. Exercises" the
    // way it used to be split by tab — a routine at the true root, an
    // exercise within a pushed routine, or a new exercise within the
    // pushed Exercise Library.
    private var addButton: some View {
        Button {
            if isRoutineDetailActive {
                addExerciseTrigger.toggle()
            } else if isExerciseLibraryActive {
                createExerciseTrigger.toggle()
            } else {
                createRoutineTrigger.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .accessibilityLabel("Add")
    }
}
