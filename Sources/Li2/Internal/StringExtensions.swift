import Foundation

extension String {
    func trimmingTrailingSlashes() -> String {
        var s = self; while s.hasSuffix("/") { s.removeLast() }; return s
    }
}
