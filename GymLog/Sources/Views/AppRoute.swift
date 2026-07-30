import Foundation

enum AppRoute: Hashable {
    case routine(UUID)
    case exercise(UUID)
    case workoutSession(routineId: UUID, startIndex: Int)
    case exerciseLibrary
}
