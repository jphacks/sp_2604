import Dependencies
import DependenciesMacros

@DependencyClient
nonisolated struct UpdatePrivateCloudComputeConsentUseCase: Sendable {
    /// 初回超過時の確認と、PCC 設定画面での有効化・無効化の両方で使う。
    var execute: @Sendable (_ consent: PrivateCloudComputeConsent) -> Void
}

nonisolated extension UpdatePrivateCloudComputeConsentUseCase: DependencyKey {
    static let liveValue: UpdatePrivateCloudComputeConsentUseCase = {
        let impl = UpdatePrivateCloudComputeConsentUseCaseImpl()
        return UpdatePrivateCloudComputeConsentUseCase(execute: impl.execute(_:))
    }()
}

nonisolated extension DependencyValues {
    var updatePrivateCloudComputeConsentUseCase: UpdatePrivateCloudComputeConsentUseCase {
        get { self[UpdatePrivateCloudComputeConsentUseCase.self] }
        set { self[UpdatePrivateCloudComputeConsentUseCase.self] = newValue }
    }
}

private nonisolated struct UpdatePrivateCloudComputeConsentUseCaseImpl: Sendable {
    @Dependency(\.privateCloudComputeConsentRepository) private var privateCloudComputeConsentRepository

    func execute(_ consent: PrivateCloudComputeConsent) {
        privateCloudComputeConsentRepository.set(consent)
    }
}
