// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dayline",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dayline", targets: ["Dayline"]),
    ],
    targets: [
        // 与界面无关的时钟逻辑，菜单栏和以后的桌面小组件共用。
        .target(name: "DaylineCore"),
        .executableTarget(name: "Dayline", dependencies: ["DaylineCore"]),
        .testTarget(name: "DaylineCoreTests", dependencies: ["DaylineCore"]),
    ]
)
