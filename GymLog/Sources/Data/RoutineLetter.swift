import Foundation

/// "Routine A", "Routine B", ... from a zero-based position in a
/// sort_order-ordered list. Port of src/lib/routine-letter.ts.
enum RoutineLetter {
    static func forIndex(_ index: Int) -> String {
        guard index >= 0, let scalar = UnicodeScalar(65 + index) else {
            return "Routine \(index + 1)"
        }
        return "Routine \(Character(scalar))"
    }
}
