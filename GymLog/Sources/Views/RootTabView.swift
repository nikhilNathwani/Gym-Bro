import SwiftUI

private enum RootTab: Hashable {
    case routines, exercises
}

/// App shell, styled after Todoist's bottom bar: a compact pill-shaped 2-item
/// nav control floats at the bottom-left to switch between the routines list
/// and the exercise library, and a separate accent-colored circular "+"
/// floats at the bottom-right to create/add into whatever's currently on
/// screen (a routine on the Routines tab root, an exercise within a pushed
/// routine, or an exercise on the Exercises tab).
/// Deliberately not a system `TabView` — Todoist's bar isn't a full-width
/// tab bar either, and mixing a create *action* into real navigation tabs
/// doesn't read as a tab. The selected item gets a glass capsule behind it
/// that slides between positions (`matchedGeometryEffect`), echoing the
/// system tab bar's own selection-indicator look.
struct RootTabView: View {
    @State private var selectedTab: RootTab = .routines
    @State private var createRoutineTrigger = false
    @State private var createExerciseTrigger = false
    @State private var addExerciseTrigger = false
    @State private var isRoutineDetailActive = false
    @State private var isWorkoutSessionActive = false
    @Namespace private var pillNamespace

    var body: some View {
        ZStack {
            RoutinesListView(
                createTrigger: $createRoutineTrigger,
                addExerciseTrigger: $addExerciseTrigger,
                isRoutineDetailActive: $isRoutineDetailActive,
                isWorkoutSessionActive: $isWorkoutSessionActive
            )
                .opacity(selectedTab == .routines ? 1 : 0)
                .allowsHitTesting(selectedTab == .routines)
                .accessibilityHidden(selectedTab != .routines)

            ExercisesTabView(createTrigger: $createExerciseTrigger)
                .opacity(selectedTab == .exercises ? 1 : 0)
                .allowsHitTesting(selectedTab == .exercises)
                .accessibilityHidden(selectedTab != .exercises)
        }
        // Todoist-style: the keyboard should float on top of the whole tab
        // shell, not push it up. This has to sit on the ZStack itself, not
        // just the pill/"+" overlay below — the overlay's position is
        // computed from this view's own frame, so if only the overlay
        // opted out, the frame it aligned against was still shrinking to
        // avoid the keyboard and dragging it up anyway.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            if !isWorkoutSessionActive {
                Color.clear.frame(height: 64)
            }
        }
        // Hidden during a workout session: tab-switching and the
        // context-aware "+" don't mean anything mid-workout, and the FAB
        // was overlapping/clipping WorkoutSessionView's own Next/Finish
        // button in that bottom-right corner.
        .overlay(alignment: .bottom) {
            if !isWorkoutSessionActive {
                HStack {
                    pillNav
                    Spacer()
                    addButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private var pillNav: some View {
        HStack(spacing: 2) {
            navButton(tab: .routines, systemImage: "list.bullet.clipboard", label: "Routines")
            navButton(tab: .exercises, systemImage: "dumbbell.fill", label: "Exercises")
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func navButton(tab: RootTab, systemImage: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.snappy(duration: 0.25)) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .medium))
                    .frame(height: 22)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 82, height: 58)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .matchedGeometryEffect(id: "pillHighlight", in: pillNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // Notes-app-style compose button, matching Todoist's separate circular
    // "+" at bottom-right; same accent blue as the selected nav item, so
    // it's clear what tapping + will create. Context-aware down to the
    // pushed screen, not just the tab: inside a routine it adds an exercise
    // to that routine rather than creating a new routine on the screen
    // behind it.
    private var addButton: some View {
        Button {
            switch selectedTab {
            case .routines:
                if isRoutineDetailActive {
                    addExerciseTrigger.toggle()
                } else {
                    createRoutineTrigger.toggle()
                }
            case .exercises: createExerciseTrigger.toggle()
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

/// Wraps ExerciseLibraryView in its own NavigationStack so it can serve as a
/// tab root and still push into ExerciseDetailView independently of the
/// Routines tab's stack.
private struct ExercisesTabView: View {
    @Binding var createTrigger: Bool

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ExerciseLibraryView(createTrigger: $createTrigger)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .exercise(let id): ExerciseDetailView(exerciseId: id)
                    case .routine, .workoutSession: EmptyView()
                    }
                }
        }
    }
}
