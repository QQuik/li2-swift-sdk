import Foundation

/// Testability seam over `TrackOpenClient`.
/// `TrackOpenClient` conforms; tests inject a `MockTrackOpenCalling`.
public protocol TrackOpenCalling: Sendable {
    func open(_ request: TrackOpenRequest) async throws -> TrackOpenClient.OpenResult
}

extension TrackOpenClient: TrackOpenCalling {}
