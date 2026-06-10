import Foundation

enum Li2DeepLinkURL {

    static let cidParam = "li2_cid"

    /// Returns the URL if `raw` parses as a URL carrying a non-empty `li2_cid`
    /// query item — i.e. a Li2 deferred link pasted from the clipboard.
    static func parseLi2DeferredURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              items.contains(where: { $0.name == cidParam && ($0.value?.isEmpty == false) })
        else { return nil }
        return url
    }

    /// Strip `li2_cid` from a destination URL before handing it to the developer.
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

    /// Returns the `li2_cid` value from a URL's query items, if present.
    static func extractClickId(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == cidParam })?
            .value
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
