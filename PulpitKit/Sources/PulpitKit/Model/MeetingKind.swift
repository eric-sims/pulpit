import Foundation

/// The four kinds of sacrament meeting the app plans for.
///
/// A kind only *seeds* a meeting's item list — it never constrains it. Once created, any meeting
/// can have items added, removed, or reordered regardless of the kind it started as.
public enum MeetingKind: String, Codable, CaseIterable, Sendable, Hashable {
    case regular
    case fastAndTestimony
    case wardConference
    case specialProgram

    public var displayName: String {
        switch self {
        case .regular: "Sacrament Meeting"
        case .fastAndTestimony: "Fast & Testimony Meeting"
        case .wardConference: "Ward Conference"
        case .specialProgram: "Special Program"
        }
    }

    public var shortName: String {
        switch self {
        case .regular: "Regular"
        case .fastAndTestimony: "Fast & Testimony"
        case .wardConference: "Ward Conference"
        case .specialProgram: "Special Program"
        }
    }

    /// Whether the template seeds assigned speaker slots. Fast & testimony meetings have no
    /// assigned speakers — the congregation is invited to bear testimony instead.
    public var hasAssignedSpeakers: Bool {
        switch self {
        case .regular, .wardConference: true
        case .fastAndTestimony, .specialProgram: false
        }
    }

    /// Unknown values decode to `.regular` rather than failing, so a meeting from a future version
    /// of the app still imports.
    public init(tolerant raw: String?) {
        self = raw.flatMap(MeetingKind.init(rawValue:)) ?? .regular
    }
}
