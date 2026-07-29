import Foundation
import Supabase

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        }
    }
}

/// One async throws function per web server action (src/app/**/actions.ts),
/// same behavior — except errors are thrown, not silently swallowed. The web
/// app's addLogEntry had a real bug where a silent `if (error) return` made
/// saves look successful when they weren't (see migration 006's commit
/// message); callers here surface failures via `.alert` instead.
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString),
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !urlString.isEmpty, !key.isEmpty
        else {
            fatalError("Missing SupabaseURL/SupabaseAnonKey in Info.plist — check Secrets.xcconfig")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    // MARK: - Routines

    func fetchRoutines() async throws -> [Routine] {
        try await client.from("routines")
            .select("id, label, sort_order")
            .order("sort_order")
            .execute()
            .value
    }

    /// Nested-embed ordering (routine_exercises -> exercise -> exercise_logs
    /// -> set_logs) isn't reliable through the query builder, so sort
    /// client-side after decode — same approach as routines/[id]/page.tsx.
    func fetchRoutineDetail(id: UUID) async throws -> RoutineDetail? {
        let detail: RoutineDetail? = try await client.from("routines")
            .select(
                "id, label, sort_order, routine_exercises(id, sort_order, exercise:exercises(id, name, subtitle, cues, exercise_logs(id, notes, created_at, set_logs(id, set_number, weight, reps))))"
            )
            .eq("id", value: id)
            .order("sort_order", referencedTable: "routine_exercises")
            .maybeSingle()
            .execute()
            .value

        guard var routine = detail else { return nil }
        routine.routineExercises = routine.routineExercises.map { entry in
            var entry = entry
            entry.exercise.exerciseLogs = sortedLogs(entry.exercise.exerciseLogs)
            return entry
        }
        return routine
    }

    @discardableResult
    func createRoutine(label: String?) async throws -> UUID {
        let countResponse = try await client.from("routines")
            .select("id", head: true, count: .exact)
            .execute()
        let inserted: Routine = try await client.from("routines")
            .insert(NewRoutine(label: label, sortOrder: countResponse.count ?? 0))
            .select("id, label, sort_order")
            .single()
            .execute()
            .value
        return inserted.id
    }

    func updateRoutineLabel(id: UUID, label: String?) async throws {
        try await client.from("routines")
            .update(RoutineLabelUpdate(label: label))
            .eq("id", value: id)
            .execute()
    }

    func deleteRoutine(id: UUID) async throws {
        try await client.from("routines").delete().eq("id", value: id).execute()
    }

    /// Bulk sort_order rewrite over the whole list, same approach as
    /// reorderRoutineExercises — native List.onMove hands back an arbitrary
    /// reorder, not a single step.
    func reorderRoutines(orderedIds: [UUID]) async throws {
        for (index, id) in orderedIds.enumerated() {
            try await client.from("routines")
                .update(RoutineSortOrderUpdate(sortOrder: index))
                .eq("id", value: id)
                .execute()
        }
    }

    func addExerciseToRoutine(routineId: UUID, exerciseId: UUID) async throws {
        let countResponse = try await client.from("routine_exercises")
            .select("id", head: true, count: .exact)
            .eq("routine_id", value: routineId)
            .execute()
        try await client.from("routine_exercises")
            .insert(
                NewRoutineExercise(
                    routineId: routineId, exerciseId: exerciseId, sortOrder: countResponse.count ?? 0)
            )
            .execute()
    }

    func removeExerciseFromRoutine(routineExerciseId: UUID) async throws {
        try await client.from("routine_exercises")
            .delete()
            .eq("id", value: routineExerciseId)
            .execute()
    }

    /// Replaces the web app's up/down pairwise swap (moveExerciseInRoutine)
    /// with a bulk sort_order rewrite over the whole list, since native
    /// List.onMove hands back an arbitrary reorder, not a single step.
    func reorderRoutineExercises(orderedIds: [UUID]) async throws {
        for (index, id) in orderedIds.enumerated() {
            try await client.from("routine_exercises")
                .update(RoutineExerciseSortOrderUpdate(sortOrder: index))
                .eq("id", value: id)
                .execute()
        }
    }

    // MARK: - Exercises

    func fetchExercises() async throws -> [Exercise] {
        try await client.from("exercises")
            .select("id, name, subtitle")
            .order("name")
            .execute()
            .value
    }

    func fetchExerciseDetail(id: UUID) async throws -> ExerciseDetail? {
        let detail: ExerciseDetail? = try await client.from("exercises")
            .select(
                "id, name, subtitle, cues, exercise_logs(id, notes, created_at, set_logs(id, set_number, weight, reps))"
            )
            .eq("id", value: id)
            .maybeSingle()
            .execute()
            .value

        guard var exercise = detail else { return nil }
        exercise.exerciseLogs = sortedLogs(exercise.exerciseLogs)
        return exercise
    }

    @discardableResult
    func createExercise(name: String, routineId: UUID?) async throws -> UUID {
        let inserted: Exercise = try await client.from("exercises")
            .insert(NewExercise(name: name))
            .select("id, name, subtitle")
            .single()
            .execute()
            .value

        if let routineId {
            try await addExerciseToRoutine(routineId: routineId, exerciseId: inserted.id)
        }
        return inserted.id
    }

    func updateExerciseName(id: UUID, name: String) async throws {
        try await client.from("exercises")
            .update(ExerciseNameUpdate(name: name))
            .eq("id", value: id)
            .execute()
    }

    func updateExerciseSubtitle(id: UUID, subtitle: String?) async throws {
        try await client.from("exercises")
            .update(ExerciseSubtitleUpdate(subtitle: subtitle))
            .eq("id", value: id)
            .execute()
    }

    func updateCues(exerciseId: UUID, cues: String?) async throws {
        try await client.from("exercises")
            .update(ExerciseCuesUpdate(cues: cues))
            .eq("id", value: exerciseId)
            .execute()
    }

    func deleteExercise(id: UUID) async throws {
        try await client.from("exercises").delete().eq("id", value: id).execute()
    }

    // MARK: - Log entries

    @discardableResult
    func addLogEntry(exerciseId: UUID, weights: [Double?], reps: [Int?], notes: String?) async throws -> UUID {
        let session: IDRow = try await client.from("workout_sessions")
            .insert(NewWorkoutSession())
            .select("id")
            .single()
            .execute()
            .value

        let log: IDRow = try await client.from("exercise_logs")
            .insert(NewExerciseLog(sessionId: session.id, exerciseId: exerciseId, notes: notes))
            .select("id")
            .single()
            .execute()
            .value

        try await insertSetLogs(exerciseLogId: log.id, weights: weights, reps: reps)
        return log.id
    }

    /// Deliberately does not touch created_at — editing a note days later
    /// should still leave the entry attributed to the day it was logged.
    func updateLogEntry(exerciseLogId: UUID, notes: String?, weights: [Double?], reps: [Int?]) async throws {
        try await client.from("exercise_logs")
            .update(ExerciseLogNotesUpdate(notes: notes))
            .eq("id", value: exerciseLogId)
            .execute()

        try await client.from("set_logs")
            .delete()
            .eq("exercise_log_id", value: exerciseLogId)
            .execute()

        try await insertSetLogs(exerciseLogId: exerciseLogId, weights: weights, reps: reps)
    }

    func deleteLogEntry(id: UUID) async throws {
        try await client.from("exercise_logs").delete().eq("id", value: id).execute()
    }

    /// Creates the workout_session + exercise_log for "today" with no sets
    /// yet — used by the routine page's inline logging, which must not log
    /// anything just because an exercise card was expanded/viewed. Callers
    /// invoke this lazily, only on the first real edit (a stepper tap, a
    /// typed value, or "Add set"), and add set_logs separately via
    /// createSetLog.
    @discardableResult
    func createExerciseLogForToday(exerciseId: UUID) async throws -> UUID {
        let session: IDRow = try await client.from("workout_sessions")
            .insert(NewWorkoutSession())
            .select("id")
            .single()
            .execute()
            .value

        let log: IDRow = try await client.from("exercise_logs")
            .insert(NewExerciseLog(sessionId: session.id, exerciseId: exerciseId, notes: nil))
            .select("id")
            .single()
            .execute()
            .value
        return log.id
    }

    @discardableResult
    func createSetLog(exerciseLogId: UUID, setNumber: Int, weight: Double?, reps: Int?) async throws -> UUID {
        let row: IDRow = try await client.from("set_logs")
            .insert(NewSetLog(exerciseLogId: exerciseLogId, setNumber: setNumber, weight: weight, reps: reps))
            .select("id")
            .single()
            .execute()
            .value
        return row.id
    }

    func updateSetLog(id: UUID, weight: Double?, reps: Int?) async throws {
        try await client.from("set_logs")
            .update(SetLogUpdate(weight: weight, reps: reps))
            .eq("id", value: id)
            .execute()
    }

    func deleteSetLog(id: UUID) async throws {
        try await client.from("set_logs").delete().eq("id", value: id).execute()
    }

    /// Notes-only update, independent of set_logs — unlike updateLogEntry
    /// (which destructively replaces every set_log), inline editing needs
    /// to touch just the note without disturbing sets edited elsewhere.
    func updateExerciseLogNotesOnly(id: UUID, notes: String?) async throws {
        try await client.from("exercise_logs")
            .update(ExerciseLogNotesUpdate(notes: notes))
            .eq("id", value: id)
            .execute()
    }

    private func insertSetLogs(exerciseLogId: UUID, weights: [Double?], reps: [Int?]) async throws {
        let setCount = max(weights.count, reps.count)
        let rows: [NewSetLog] = (0..<setCount).compactMap { i in
            let weight = i < weights.count ? weights[i] : nil
            let rep = i < reps.count ? reps[i] : nil
            guard weight != nil || rep != nil else { return nil }
            return NewSetLog(exerciseLogId: exerciseLogId, setNumber: i + 1, weight: weight, reps: rep)
        }
        guard !rows.isEmpty else { return }
        try await client.from("set_logs").insert(rows).execute()
    }

    private func sortedLogs(_ logs: [ExerciseLog]) -> [ExerciseLog] {
        logs
            .sorted { $0.createdAt > $1.createdAt }
            .map { log in
                var log = log
                log.setLogs.sort { $0.setNumber < $1.setNumber }
                return log
            }
    }
}

// MARK: - Comma-list parsing (port of exercises/actions.ts:175-193)

enum SetFieldsParsing {
    static func splitCommaList(_ text: String) -> [String] {
        text.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func parseDoubleOrNil(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value)
    }

    static func parseIntOrNil(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value)
    }
}
