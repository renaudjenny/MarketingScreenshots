import ArgumentParser
import Foundation

@main
struct MarketingScreenshotsCommand: AsyncParsableCommand {
    @Argument(help: "Path to the project", completion: .directory)
    var path: String

    @Argument(
        help: "Choose devices among this list:\n\(Device.allCases.map { "\t\($0.simulatorName)" }.joined(separator: "\n"))",
        completion: .list(Device.allCases.map(\.simulatorName)),
        transform: Device.init(name:)
    )
    var devices: [Device]

    mutating func run() async throws {
        guard FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
        else { throw ExecutionError.projectFolderNotFound }

        try prepare()
        try await checkSimulatorAvailability()

    }

    func prepare() throws {
        print("🗂 Project directory: \(path)")
        print("\tAdd export directory .ExportedScreenshots")
        let url = URL(filePath: (path as NSString).expandingTildeInPath).appending(component: ".ExportedScreenshots")
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func checkSimulatorAvailability() async throws {
        print("""
        🤖 Check local simulators for these devices:\n\(devices.map { "\t\($0.simulatorName)" }.joined(separator: "\n"))
        """)

        let availableSimulators = Commandline("xcrun simctl list -j devices available")
        availableSimulators.run()
        var json = ""
        for try await line in availableSimulators.lines { json += line }
        guard let data = json.data(using: .utf8) else { throw ExecutionError.stringToDataFailed }
        let simulators = try JSONDecoder().decode(SimulatorList.self, from: data)

        let availableDevices = simulators.devices.flatMap { $0.value.map(\.deviceTypeIdentifier) }
        for device in devices {
            if availableDevices.contains(device.rawValue) {
                print("\t\(device.simulatorName) simulator is available. Checking the status...")
                let simulator = simulators.simulator(deviceTypeIdentifier: device.rawValue)
                let state: String
                switch simulator?.state {
                case .booted: state = "Booted"
                case .shutdown: state = "Shutdown"
                case .none: state = "Unknown"
                }
                let availability = (simulator?.isAvailable ?? false) ? "Available" : "Unavailable"
                print("\t\tDevice state: \(state), availability: \(availability)")

                if simulator?.state != .shutdown {
                    print("\t\tShutting down the device: \(device.simulatorName)")
                    Commandline("xcrun simctl shutdown \(quote: device.simulatorName)").run()
                }
            } else {
                print("\t\(device.simulatorName) simulator is not available. Let's create it...")
                let deviceCreation = Commandline(
                    "xcrun simctl create \(quote: device.simulatorName) \(device.rawValue)"
                )
                deviceCreation.run()
                for try await line in deviceCreation.lines { print("\t\t\(line)") }
            }
        }

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
