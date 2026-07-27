import SwiftUI

/// Port of exercises/page.tsx + ExerciseLibraryList.tsx. Uses native
/// `.searchable` in place of the web's custom search TextField, and a
/// `.sheet` for creation in place of the dedicated /exercises/new push.
struct ExerciseLibraryView: View {
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showNewExercise = false
    @State private var errorMessage: String?

    private var filtered: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    if filtered.isEmpty {
                        Text(exercises.isEmpty ? "No exercises yet — create one below." : "No matches.")
                            .foregroundColor(Theme.foreground)
                    } else {
                        ForEach(filtered) { exercise in
                            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                                Text(exercise.name).font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises…")
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewExercise = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("newExerciseButton")
            }
        }
        .sheet(isPresented: $showNewExercise) {
            NewExerciseView(onCreated: { _ in Task { await load() } })
        }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($errorMessage)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            exercises = try await SupabaseService.shared.fetchExercises()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
