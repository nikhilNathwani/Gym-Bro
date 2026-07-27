import SwiftUI

/// Port of page.tsx (home / "/"). Owns the app's single NavigationStack.
struct RoutinesListView: View {
    @State private var path = NavigationPath()
    @State private var routines: [Routine] = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if routines.isEmpty {
                        Text("No routines yet — create one below.")
                            .foregroundColor(Theme.foreground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                            NavigationLink(value: AppRoute.routine(routine.id)) {
                                HStack {
                                    Text(title(for: routine, index: index))
                                        .font(.system(size: 18, weight: .medium))
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(BorderedRowButtonStyle())
                        }
                    }

                    Button {
                        Task { await createRoutine() }
                    } label: {
                        Text(isCreating ? "Creating…" : "+ New routine")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(BorderedRowButtonStyle())
                    .disabled(isCreating)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Gym Bro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AppRoute.exerciseLibrary) {
                        Text("Exercises").font(.system(size: 13, weight: .medium))
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .routine(let id): RoutineDetailView(routineId: id)
                case .exercise(let id): ExerciseDetailView(exerciseId: id)
                case .exerciseLibrary: ExerciseLibraryView()
                }
            }
        }
        .task { await load() }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { Task { await load() } }
        }
        .errorAlert($errorMessage)
    }

    private func title(for routine: Routine, index: Int) -> String {
        let letter = RoutineLetter.forIndex(index)
        guard let label = routine.label, !label.isEmpty else { return letter }
        return "\(letter) - \(label)"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            routines = try await SupabaseService.shared.fetchRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createRoutine() async {
        isCreating = true
        defer { isCreating = false }
        do {
            let id = try await SupabaseService.shared.createRoutine(label: nil)
            routines = try await SupabaseService.shared.fetchRoutines()
            path.append(AppRoute.routine(id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
