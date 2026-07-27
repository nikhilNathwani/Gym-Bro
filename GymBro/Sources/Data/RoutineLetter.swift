import Foundation

/// "Routine A", "Routine B", ... from a zero-based position in a
/// sort_order-ordered list. Port of src/lib/routine-letter.ts.
enum RoutineLetter {
    static func forIndex(_ index: Int) -> String {
        "Routine \(Character(UnicodeScalar(65 + index)!))"
    }
}
