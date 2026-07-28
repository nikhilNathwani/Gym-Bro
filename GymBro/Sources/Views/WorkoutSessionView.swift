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
/// The screen is split into two independent regions sharing one
/// `ExerciseLogController`: read-only reference material (title, target,
/// last time, cues, open-full-page link) scrolls independently at the top,
/// while the actual input controls — set steppers, notes, and Prev/Next —
/// are collocated in one fixed dock at the bottom. The user only ever
/// interacts with one exercise's inputs at a time and asked for those
/// controls (plus the nav to move between exercises) to read as a single
/// widget rather than being separated by whatever's currently scrolled.
struct WorkoutSessionView: View {
    let routineId: UUID
    let startIndex: Int

    @State private var routine: RoutineDetail?
    @State private var isLoading = true
    @State private var currentIndex: Int
    @State private var errorMessage: String?
    @State private var controller: ExerciseLogController?

    @Environment(\.dismiss) private var dismiss

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
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !exercises.isEmpty {
                    Text("\(currentIndex + 1) of \(exercises.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task { await load() }
        // Only re-creates the controller when moving to a different
        // exercise (Prev/Next) — a `reload()` triggered by that same
        // exercise's own logging (onLogged) must NOT reset it, or the user
        // would lose whatever they're mid-editing.
        .onChange(of: currentIndex) { _, _ in setUpController() }
        .errorAlert($errorMessage)
    }

    private func page(_ controller: ExerciseLogController) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(exercises[currentIndex].name)
                        .font(.title.bold())
                    ExerciseReferenceSection(controller: controller)
                }
                .padding(16)
            }
            // One unified block for everything the user actually interacts
            // with (steppers, notes, Prev/Next) — a solid purple tray with
            // rounded top corners, rising from the bottom of the screen
            // (Notes' format bar is the closest analog). A translucent
            // `.regularMaterial` was tried first but reads as plain grey on
            // a static/plain backdrop like this one — no color of its own,
            // just a blur, so it never actually looked "glass" here. Fully
            // saturated `Color.accentColor` was tried before that; its
            // dark-mode shade is a light lavender, which made the
            // white/near-black systemBackground text-field chips inside it
            // look mismatched. `DockBackground` (Assets.xcassets) is a
            // custom color asset instead — a light lavender tint in light
            // mode, a genuinely dark purple in dark mode — so it stays
            // purple-tinted rather than neutral grey, and stays close in
            // tone to the systemBackground chips nested inside it so they
            // no longer clash. No separate top divider — the rounded
            // corners plus this color/shape change are already a clear
            // enough seam; a straight divider line sitting right above a
            // rounded corner looked like a rendering glitch.
            VStack(spacing: 20) {
                ExerciseLoggingDock(controller: controller)
                navBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                    .fill(Color("DockBackground"))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // Next is disabled (not hidden behind a separate "Finish" action) on the
    // last exercise — exiting the session is always the toolbar's "Done"
    // button, so a distinct Finish button/style wasn't adding anything.
    //
    // Text-only, not filled/bordered pills — this is secondary paging nav
    // (closer to Mail's thread prev/next links), and the previous bordered
    // buttons read as a second hero control competing with the actual
    // logging inputs above them.
    private var navBar: some View {
        HStack {
            Button {
                withAnimation(.snappy(duration: 0.2)) { currentIndex -= 1 }
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(currentIndex == 0 ? Color(.tertiaryLabel) : Color.accentColor)
            .disabled(currentIndex == 0)
            .accessibilityIdentifier("previousExerciseButton")

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.2)) { currentIndex += 1 }
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(currentIndex == exercises.count - 1 ? Color(.tertiaryLabel) : Color.accentColor)
            .disabled(currentIndex == exercises.count - 1)
            .accessibilityIdentifier("nextExerciseButton")
        }
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
            onError: { errorMessage = $0 }
        )
    }
}
