// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ProjectLumina",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ProjectLumina", targets: ["ProjectLumina"])
    ],
    targets: [
        .executableTarget(
            name: "ProjectLumina",
            path: ".",
            exclude: [
                "SPEC.md",
                "TASK_LIST.MD",
                "README.md",
                "appsettings.json",
                "Initial Prompt.md"
            ],
            sources: [
                "App",
                "Domain",
                "Data",
                "Presentation",
                "Infrastructure"
            ],
            resources: [
                .copy("appsettings.json")
            ]
        )
    ]
)
