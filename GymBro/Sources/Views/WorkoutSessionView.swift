import SwiftUI
import UIKit

/// Full-screen, one-exercise-at-a-time logging flow — reached from
/// `RoutineDetailView`'s "Start Workout" button.
///
/// Replaces an earlier inline-accordion design in the routine's own list:
/// the user only ever logs one exercise at a time in the gym, so expanding
/// exercises in place (still requiring the same amount of scrolling/tapping
/// to get to the next one) didn't actually solve anything. Here the current
/// exercise takes the whole screen and Prev/Next page between exercises —
/// reuses `InlineExerciseCard` for the actual last-time/stepper/notes/cues
/// content unchanged, since that content and its lazy-log-creation
/// persistence model are correct as-is; only the surrounding container
/// (full-screen page vs. List row) changes.
struct WorkoutSessionView: View {
    let routineId: UUID
    let startIndex: Int

    @State private var routine: RoutineDetail?
    @State private var isLoading = true
    @State private var currentIndex: Int
    @State private var errorMessage: String?
    // Hides the Prev/Next bar while the system keyboard (from tapping into a
    // stepper's weight/reps field) is up — the keyboard should simply cover
    // the content from the bottom, not have the nav bar ride up and stay
    // visible/tappable above it.
    @State private var isKeyboardVisible = false

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
            if isLoading && routine == nil {
                ProgressView()
            } else if exercises.isEmpty {
                ContentUnavailableView("No Exercises", systemImage: "exclamationmark.triangle")
            } else {
                content
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
        .errorAlert($errorMessage)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercises[currentIndex].name)
                    .font(.title.bold())
                InlineExerciseCard(
                    exercise: exercises[currentIndex],
                    onLogged: { await reload() },
                    onError: { errorMessage = $0 }
                )
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                navBar
            }
        }
    }

    // Next is disabled (not hidden behind a separate "Finish" action) on the
    // last exercise — exiting the session is always the toolbar's "Done"
    // button, so a distinct Finish button/style wasn't adding anything.
    private var navBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { currentIndex -= 1 }
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex == 0)
            .accessibilityIdentifier("previousExerciseButton")

            Button {
                withAnimation(.snappy(duration: 0.2)) { currentIndex += 1 }
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex == exercises.count - 1)
            .accessibilityIdentifier("nextExerciseButton")
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let detail = try await SupabaseService.shared.fetchRoutineDetail(id: routineId) {
                routine = detail
                currentIndex = min(currentIndex, max(0, detail.routineExercises.count - 1))
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
}
