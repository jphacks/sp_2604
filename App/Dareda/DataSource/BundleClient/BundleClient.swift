import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct BundleClient: Sendable {
    var infoValue: @Sendable (_ forKey: String) -> Any?
}

nonisolated extension BundleClient: DependencyKey {
    static let liveValue: BundleClient = {
        let impl = BundleClientImpl()
        return BundleClient(infoValue: impl.infoValue(forKey:))
    }()

    static let testValue = BundleClient.inMemory()
    static let previewValue = BundleClient.inMemory()
}

nonisolated extension DependencyValues {
    var bundleClient: BundleClient {
        get { self[BundleClient.self] }
        set { self[BundleClient.self] = newValue }
    }
}

nonisolated extension BundleClient {
    static func inMemory(info: [String: String] = [
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
    ]) -> Self {
        Self(infoValue: { info[$0] })
    }
}

private nonisolated struct BundleClientImpl: Sendable {
    func infoValue(forKey key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }
}
