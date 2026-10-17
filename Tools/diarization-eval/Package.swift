// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "diarization-eval",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "diarization-eval", targets: ["DiarizationEval"]),
    ],
    dependencies: [
        // アプリ (App/Dareda.xcodeproj) と同じバージョンに揃える
        .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.17.7"),
    ],
    targets: [
        .executableTarget(
            name: "DiarizationEval",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
