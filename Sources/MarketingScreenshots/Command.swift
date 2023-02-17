import ArgumentParser
import Foundation

@main
struct MarketingScreenshotsCommand: ParsableCommand {
    @Argument(help: "Path to the project", completion: .directory)
    var path: String

    @Argument(
        help: "Choose devices among this list:\n\(Device.allCases.map { "\t\($0.simulatorName)" }.joined(separator: "\n"))",
        completion: .list(Device.allCases.map(\.simulatorName)),
        transform: Device.init(name:)
    )
    var devices: [Device]

    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
        else { throw ExecutionError.projectFolderNotFound }

        try prepare()
        try checkSimulatorAvailability()
    }

    func prepare() throws {
        print("🗂 Project directory: \(path)")
        print("\tAdd export directory .ExportedScreenshots")
        let url = URL(filePath: (path as NSString).expandingTildeInPath).appending(component: ".ExportedScreenshots")
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func checkSimulatorAvailability() throws {
        print("Screenshots for these devices:\n\(devices.map { "\t\($0.simulatorName)" }.joined(separator: "\n"))")
    }

    typealias Device = MarketingScreenshots.Device
}

extension MarketingScreenshots.Device: Decodable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        self = try Self(name: name)
    }

    init(name: String) throws {
        guard let value = Self.allCases.first(where: { $0.simulatorName == name })
        else { throw ExecutionError.deviceNameUnknown(name) }
        self = value
    }
}
