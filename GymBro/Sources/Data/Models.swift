import Foundation

// MARK: - Read models (mirror src/lib/types.ts)

struct Routine: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, label
        case sortOrder = "sort_order"
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String?
}

struct SetLog: Codable, Identifiable, Hashable {
    let id: UUID
    var setNumber: Int
    var weight: Double?
    var reps: Int?

    enum CodingKeys: String, CodingKey {
        case id, weight, reps
        case setNumber = "set_number"
    }
}

struct ExerciseLog: Codable, Identifiable, Hashable {
    let id: UUID
    var notes: String?
    var createdAt: Date
    var setLogs: [SetLog]

    enum CodingKeys: String, CodingKey {
        case id, notes
        case createdAt = "created_at"
        case setLogs = "set_logs"
    }

    /// Compact "45×10 · 40×10" rendering of this log's sets, shared between
    /// the "Last Time" peek (ExerciseReferenceSection) and the routine
    /// list's inline today's-progress preview (RoutineDetailView).
    var setsSummary: String {
        setLogs
            .sorted { $0.setNumber < $1.setNumber }
            .map { set in
                let weight = set.weight.map(formatNumber) ?? "–"
                let reps = set.reps.map(String.init) ?? "–"
                return "\(weight)×\(reps)"
            }
            .joined(separator: " · ")
    }
}

struct ExerciseDetail: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String?
    var cues: String?
    var exerciseLogs: [ExerciseLog]

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, cues
        case exerciseLogs = "exercise_logs"
    }
}

struct RoutineExercise: Codable, Identifiable, Hashable {
    let id: UUID
    var sortOrder: Int
    var exercise: ExerciseDetail

    enum CodingKeys: String, CodingKey {
        case id, exercise
        case sortOrder = "sort_order"
    }
}

struct RoutineDetail: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String?
    var sortOrder: Int
    var routineExercises: [RoutineExercise]

    enum CodingKeys: String, CodingKey {
        case id, label
        case sortOrder = "sort_order"
        case routineExercises = "routine_exercises"
    }
}

// MARK: - Write payloads
//
// Small, single-purpose Encodable structs (rather than a generic
// [String: Any] update) so each save touches only the field it owns —
// mirrors updateExercise()'s "only update the field present in formData"
// behavior in the web app's exercises/actions.ts.

struct NewRoutine: Encodable {
    var label: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case label
        case sortOrder = "sort_order"
    }
}

struct RoutineLabelUpdate: Encodable {
    var label: String?
}

struct RoutineSortOrderUpdate: Encodable {
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case sortOrder = "sort_order"
    }
}

struct NewRoutineExercise: Encodable {
    var routineId: UUID
    var exerciseId: UUID
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case routineId = "routine_id"
        case exerciseId = "exercise_id"
        case sortOrder = "sort_order"
    }
}

struct RoutineExerciseSortOrderUpdate: Encodable {
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case sortOrder = "sort_order"
    }
}

struct NewExercise: Encodable {
    var name: String
}

struct ExerciseNameUpdate: Encodable {
    var name: String
}

struct ExerciseSubtitleUpdate: Encodable {
    var subtitle: String?
}

struct ExerciseCuesUpdate: Encodable {
    var cues: String?
}

struct NewWorkoutSession: Encodable {}

struct NewExerciseLog: Encodable {
    var sessionId: UUID
    var exerciseId: UUID
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case notes
    }
}

struct ExerciseLogNotesUpdate: Encodable {
    var notes: String?
}

struct NewSetLog: Encodable {
    var exerciseLogId: UUID
    var setNumber: Int
    var weight: Double?
    var reps: Int?

    enum CodingKeys: String, CodingKey {
        case exerciseLogId = "exercise_log_id"
        case setNumber = "set_number"
        case weight, reps
    }
}

struct SetLogUpdate: Encodable {
    var weight: Double?
    var reps: Int?
}

struct IDRow: Decodable {
    let id: UUID
}
