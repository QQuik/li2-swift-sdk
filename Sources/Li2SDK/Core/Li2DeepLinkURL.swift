import Foundation

/// Stateless deep-link URL helpers. Foundation-only, Linux-testable.
enum Li2DeepLinkURL: Sendable {

    static let cidParam = "li2_cid"

    /// Returns the URL if the string carries a non-empty `li2_cid` query param
    /// (Li2 deferred link), else `nil`.
    static func parseLi2DeferredURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              items.contains(where: { $0.name == cidParam && ($0.value?.isEmpty == false) })
        else { return nil }
        return url
    }

    /// Strip `li2_cid` from a destination URL so the integrator receives a clean URL.
    static func sanitizedDestination(_ raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else {
            return URL(string: raw)
        }
        if let items = components.queryItems {
            let filtered = items.filter { $0.name != cidParam }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }
        return components.url ?? URL(string: raw)
    }
}
