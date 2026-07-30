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
/// doesn't read as a tab. The selected item gets a solid accent-colored
/// capsule behind it that slides between positions
/// (`matchedGeometryEffect`), echoing the system tab bar's own
/// selection-indicator look (see `navButton`'s doc comment for why this
/// is solid color, not glass/material).
struct RootTabView: View {
    @State private var selectedTab: RootTab = .routines
    @State private var createRoutineTrigger = false
    @State private var createExerciseTrigger = false
    @State private var addExerciseTrigger = false
    @State private var isRoutineDetailActive = false
    @State private var isWorkoutSessionActive = false
    @State private var popRoutinesTrigger = false
    @State private var popExercisesTrigger = false
    // A single counter driving `.sensoryFeedback` below, bumped on every
    // pill tap — both a tab switch and a re-tap-to-pop-to-root (which
    // doesn't change `selectedTab` at all, so that alone can't be the
    // trigger) should get the same haptic.
    @State private var navTapTick = 0
    @Namespace private var pillNamespace

    var body: some View {
        ZStack {
            RoutinesListView(
                createTrigger: $createRoutineTrigger,
                addExerciseTrigger: $addExerciseTrigger,
                isRoutineDetailActive: $isRoutineDetailActive,
                isWorkoutSessionActive: $isWorkoutSessionActive,
                popToRootTrigger: $popRoutinesTrigger
            )
                .opacity(selectedTab == .routines ? 1 : 0)
                .allowsHitTesting(selectedTab == .routines)
                .accessibilityHidden(selectedTab != .routines)

            ExercisesTabView(createTrigger: $createExerciseTrigger, popToRootTrigger: $popExercisesTrigger)
                .opacity(selectedTab == .exercises ? 1 : 0)
                .allowsHitTesting(selectedTab == .exercises)
                .accessibilityHidden(selectedTab != .exercises)
        }
        .sensoryFeedback(.selection, trigger: navTapTick)
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

    // Tried real Liquid Glass here (`GlassEffectContainer` + `.glassEffect()`,
    // iOS 26+) to match the bottom-bar Prev/Next buttons' native glass —
    // reverted after two real problems surfaced: the selected label/icon
    // read as illegible ("foggy/dark") against the tint, and it broke actual
    // navigation — with it active, tapping WorkoutSessionView's back button
    // stopped popping the stack at all (caught by `testGoldenPath`, isolated
    // by bisection to this exact code). Back to a plain material capsule.
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
            navTapTick += 1
            if selectedTab == tab {
                // Re-tapping the already-active tab: same convention as the
                // system tab bar (tap the current tab again to pop to root),
                // not a no-op — previously this silently did nothing since
                // `selectedTab` wasn't actually changing.
                switch tab {
                case .routines: popRoutinesTrigger.toggle()
                case .exercises: popExercisesTrigger.toggle()
                }
            } else {
                withAnimation(.snappy(duration: 0.25)) { selectedTab = tab }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .medium))
                    .frame(height: 22)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            // A solid accent-colored capsule + white icon/label for the
            // selected state, not accentColor text over a translucent
            // material highlight (tried first) — the material blurred
            // whatever sat behind it into a similar tone to the accent
            // color itself, so the "selected" icon/label read as murky and
            // low-contrast ("foggy") rather than clearly picked out. Solid
            // color behind white content is unambiguous in both light and
            // dark mode, same idea as Todoist's own selected pill state.
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .frame(width: 82, height: 58)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
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
    @Binding var popToRootTrigger: Bool

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
        .onChange(of: popToRootTrigger) { _, _ in path = NavigationPath() }
    }
}
