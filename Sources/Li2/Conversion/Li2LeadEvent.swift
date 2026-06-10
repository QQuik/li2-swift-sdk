import Foundation

/// A lead event to send via `Li2.trackLead(_:)`.
///
/// Three types based on `clickId` and `externalId`:
///
/// **Attributed identified** — `clickId` auto-filled (or explicit), `externalId` provided:
/// ```swift
/// Li2LeadEvent(eventName: "signup", externalId: "user_123", email: "u@example.com")
/// ```
///
/// **Attributed anonymous** — `clickId` auto-filled, `externalId` omitted.
/// The backend creates an `anon_<clickId>` customer profile:
/// ```swift
/// Li2LeadEvent(eventName: "add_to_cart")
/// ```
///
/// **Direct** — no deep link attribution, `externalId` required:
/// ```swift
/// Li2LeadEvent(eventName: "contact_form", externalId: "user_456", clickId: Li2.noAttribution)
/// ```
public struct Li2LeadEvent {

    /// Name of the lead event (e.g. `"signup"`, `"add_to_cart"`).
    public let eventName: String

    /// Attribution click ID.
    /// - `nil`: SDK auto-fills the last persisted `clickId` (from a `.matched` outcome), or `""` if none/expired.
    /// - `Li2.noAttribution` (`""`): explicit direct conversion — no attribution.
    /// - Any other value: used as-is.
    public var clickId: String?

    /// Customer identifier in your system.
    /// - Omit for anonymous leads (backend mints `anon_<clickId>` profile).
    /// - Required when `clickId == Li2.noAttribution` (direct lead).
    /// - Must **not** start with `"anon_"` — that prefix is reserved by the server.
    public var externalId: String?

    public var email: String?
    public var phone: String?
    public var name: String?

    /// Maps to `"avatar_url"` on the wire.
    public var avatarURL: String?

    public var metadata: [String: Any]?

    public init(
        eventName: String,
        clickId: String? = nil,
        externalId: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        name: String? = nil,
        avatarURL: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.eventName = eventName
        self.clickId = clickId
        self.externalId = externalId
        self.email = email
        self.phone = phone
        self.name = name
        self.avatarURL = avatarURL
        self.metadata = metadata
    }
}
