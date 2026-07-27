import Foundation

enum AppRoute: Hashable {
    case routine(UUID)
    case exercise(UUID)
    case exerciseLibrary
}
