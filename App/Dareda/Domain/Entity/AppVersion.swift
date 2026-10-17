import Foundation

nonisolated struct AppVersion: Sendable, Equatable {
    /// `CFBundleShortVersionString`
    var version: String
    /// `CFBundleVersion`
    var build: String
}
