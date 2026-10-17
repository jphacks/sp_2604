import Foundation

nonisolated enum DeviceAvailability: Sendable, Equatable {
    case available
    case unsupported
    case temporarilyUnavailable(Reason)

    enum Reason: Sendable, Equatable {
        case appleIntelligenceDisabled
        case modelNotReady
        case unknown
    }

    var isAvailable: Bool {
        self == .available
    }
}
