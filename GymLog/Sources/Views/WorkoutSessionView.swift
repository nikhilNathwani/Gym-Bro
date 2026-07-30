import SwiftUI

/// Full-screen, one-exercise-at-a-time logging flow — reached from
/// `RoutineDetailView`'s "Start Workout" button.
///
/// Replaces an earlier inline-accordion design in the routine's own list:
/// the user only ever logs one exercise at a time in the gym, so expanding
/// exercises in place (still requiring the same amount of scrolling/tapping
/// to get to the next one) didn't actually solve anything. Here the current
/// exercise takes the whole screen and Prev/Next page between exercises.
///
/// One native `List` for the whole screen (reference material, sets,
/// notes) rather than a scrolling region glued to a separately-styled fixed
/// "dock" — that split, plus the dock's custom color and custom stepper
/// buttons, was a design-review finding of its own (see the workout-flow
/// design audit): most of what read as "homemade" here was reinventing
/// things iOS already has idiomatic answers for. Prev/Next now live in a
/// real `.toolbar(.bottomBar)`, which is the system's own answer to
/// "controls that stay reachable below scrolling content" — no custom tray
/// needed.
struct WorkoutSessionView: View {
    let routineId: UUID
    let startIndex: Int

    @State private var routine: RoutineDetail?
    @State private var isLoading = true
    @State private var currentIndex: Int
    @State private var errorMessage: String?
    @State private var controller: ExerciseLogController?
    @FocusState private var focusedField: LoggingFocusField?

    init(routineId: UUID, startIndex: Int) {
        self.routineId = routineId
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    private var exercises: [ExerciseDetail] {
        routine?.routineExercises.map { $0.exercise } ?? []
    }

    var body: some View {
        Group {
            if let controller {
                page(controller)
            } else if isLoading {
                ProgressView()
            } else if exercises.isEmpty {
                ContentUnavailableView("No Exercises", systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // No trailing "Done" button — this screen is pushed (not
        // presented as a sheet), so it already has the standard back
        // chevron, which does exactly the same dismiss. Having both read as
        // two exit affordances doing the same thing; the back chevron also
        // keeps the system's interactive swipe-to-go-back gesture working,
        // which `.navigationBarBackButtonHidden` would have disabled.
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !exercises.isEmpty {
                    Text("\(currentIndex + 1) of \(exercises.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            // The keyboard's own "Done" accessory commits whatever's
            // focused by clearing focus, which the `onChange` below turns
            // into an actual save — matches every other text-entry screen
            // in the app.
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            // Native bottom toolbar — a real system-drawn bar, not a
            // custom-colored tray, so Prev/Next stay reachable without
            // scrolling regardless of how long the sets list gets. Next is
            // disabled (not hidden behind a separate "Finish" action) on
            // the last exercise — exiting the session is always the back
            // chevron, so a distinct Finish control wasn't adding anything.
            if !exercises.isEmpty {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: goToPrevious) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                    }
                    .disabled(currentIndex == 0)
                    .accessibilityIdentifier("previousExerciseButton")

                    Spacer()

                    Button(action: goToNext) {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .disabled(currentIndex == exercises.count - 1)
                    .accessibilityIdentifier("nextExerciseButton")
                }
            }
        }
        .task { await load() }
        // Only re-creates the controller when moving to a different
        // exercise (Prev/Next) — a `reload()` triggered by that same
        // exercise's own logging (onLogged) must NOT reset it, or the user
        // would lose whatever they're mid-editing.
        .onChange(of: currentIndex) { _, _ in setUpController() }
        // Commits whatever field just lost focus (tapped away, or the
        // keyboard's own Done button above) — same pattern as every other
        // text-entry screen in the app.
        .onChange(of: focusedField) { oldValue, _ in
            guard let oldValue, let controller else { return }
            switch oldValue {
            case .name: controller.saveName()
            case .target: controller.saveTarget()
            case .cues: controller.saveCues()
            case .weight(let id): if let i = controller.setIndex(for: id) { controller.commitWeightText(at: i) }
            case .reps(let id): if let i = controller.setIndex(for: id) { controller.commitRepsText(at: i) }
            case .notes: controller.commitNotes()
            }
        }
        // Covers Prev/Next paging and add/delete-set, since all three just
        // mutate a count/index.
        .sensoryFeedback(.selection, trigger: currentIndex)
        .sensoryFeedback(.impact(weight: .light), trigger: controller?.sets.count)
        // Every stepper +/- tap (`stepTick`) and switching which set is
        // active via the "Edit" swipe action (`expandedSetNumber`).
        .sensoryFeedback(.impact(weight: .light), trigger: controller?.stepTick)
        .sensoryFeedback(.selection, trigger: controller?.expandedSetNumber)
        .errorAlert($errorMessage)
    }

    // Logging controls sit directly under the title/Last Time summary, not
    // below Cues — the user said having to scroll past cues to reach the
    // actual inputs bothered them, and cues are something you'd check
    // before a set anyway, not something that needs to be pinned above the
    // inputs. Cues (then History) sit at the bottom instead. Content itself
    // lives in `ExercisePageList`, shared with the standalone
    // `ExerciseDetailView` — this just adds the Prev/Next toolbar around it.
    private func page(_ controller: ExerciseLogController) -> some View {
        ExercisePageList(controller: controller, focusedField: $focusedField)
    }

    private func goToPrevious() {
        guard currentIndex > 0 else { return }
        withAnimation(.snappy(duration: 0.2)) { currentIndex -= 1 }
    }

    private func goToNext() {
        guard currentIndex < exercises.count - 1 else { return }
        withAnimation(.snappy(duration: 0.2)) { currentIndex += 1 }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let detail = try await SupabaseService.shared.fetchRoutineDetail(id: routineId) {
                routine = detail
                currentIndex = min(currentIndex, max(0, detail.routineExercises.count - 1))
                setUpController()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() async {
        do {
            if let detail = try await SupabaseService.shared.fetchRoutineDetail(id: routineId) {
                routine = detail
                currentIndex = min(currentIndex, max(0, detail.routineExercises.count - 1))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setUpController() {
        guard currentIndex < exercises.count else {
            controller = nil
            return
        }
        controller = ExerciseLogController(
            exercise: exercises[currentIndex],
            onLogged: { await reload() },
            onExerciseUpdated: { await reload() },
            onError: { errorMessage = $0 }
        )
    }
}
