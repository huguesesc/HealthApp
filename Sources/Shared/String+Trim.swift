import Foundation

extension String {
    /// Whitespace- and newline-trimmed copy.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
