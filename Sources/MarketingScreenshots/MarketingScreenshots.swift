import ArgumentParser
import Foundation
import XMLCoder
import XCResultKit

@main
struct MarketingScreenshots: AsyncParsableCommand {
    @Argument(help: "Path to the project", completion: .directory)
    var path: String

    @Option(help: "Scheme of the project, for instance: HelloWorldSample (iOS)")
    var scheme: String

    @Option(help: "Test Plan of the Marketing screenshots, for instance: Marketing")
    var testPlan = "Marketing"

    @Option(
        parsing: .upToNextOption,
        help: "Choose devices among this list:\n\(Device.allCases.map { "\t\($0.simulatorName)" }.joined(separator: "\n"))",
        completion: .list(Device.allCases.map(\.simulatorName)),
        transform: Device.init(name:)
    )
    var devices: [Device]

    var projectURL: URL { URL(filePath: (path as NSString).expandingTildeInPath) }
    var exportFolderURL: URL { projectURL.appending(component: ".ExportedScreenshots") }
    var derivedDataURL: URL { projectURL.appending(component: ".DerivedDataMarketing") }

    mutating func run() async throws {
        guard FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
        else { throw ExecutionError.projectFolderNotFound }

        try prepare()
        try await checkSimulatorAvailability()
        try await generateScreenshots()
    }

    private func prepare() throws {
        print("🗂 Project directory: \(path)")
        print("\tAdd export directory .ExportedScreenshots")
        try? FileManager.default.removeItem(at: exportFolderURL)
        try FileManager.default.createDirectory(at: exportFolderURL, withIntermediateDirectories: false)
    }

    private func checkSimulatorAvailability() async throws {
        print("""
        🤖 Check local simulators for these devices:\n\(devices.map { "\t\($0.simulatorName)" }.joined(separator: "\n"))
        """)

        let simulators = try await simulators()

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
                    try await Commandline("xcrun simctl shutdown \(quote: device.simulatorName)").run().value
                }
            } else {
                print("\t\(device.simulatorName) simulator is not available. Let's create it...")
                let deviceCreation = Commandline(
                    "xcrun simctl create \(quote: device.simulatorName) \(device.rawValue)"
                )
                let task = deviceCreation.run()
                for try await line in deviceCreation.lines { print("\t\t\(line)") }
                try await task.value
            }
        }
    }

    private func simulators() async throws -> SimulatorList {
        let availableSimulators = Commandline("xcrun simctl list -j devices available")
        let task = availableSimulators.run()
        var json = ""
        for try await line in availableSimulators.lines { json += line }
        try await task.value
        guard let data = json.data(using: .utf8) else { throw ExecutionError.stringToDataFailed }
        return try JSONDecoder().decode(SimulatorList.self, from: data)
    }

    private func generateScreenshots() async throws {
        print("📺 Starting generating \(testPlan) screenshots...")
        let simulators = try await simulators()
        for device in devices {
            print("""
            📱 Currently running on Simulator named: \(device.simulatorName)\
             for screenshot size \(device.screenDescription)
            """)
            print("\t📲 Booting the device: \(device.simulatorName)")
            try await Commandline("xcrun simctl boot \(quote: device.simulatorName)").run().value
            print("\t👷‍♀️ Generation of screenshots for \(device.simulatorName) via test plan in progress")

            guard let simulatorID = simulators.simulator(deviceTypeIdentifier: device.rawValue)?.udid
            else { throw ExecutionError.missingSimulatorID(for: device) }

            let destination = "platform=iOS Simulator,id=\(simulatorID)"

            for retry in 1...5 {
                if retry > 1 {
                    print("\t🔄 Previous test failed, let's retry. Attempts: \(retry)")
                }
                do {
                    try await runTest(destination: destination)
                    break
                } catch let ExecutionError.commandFailure(command, code) {
                    print("\t😥 Test has failed with code: \(code)")
                    if retry >= 5 { throw ExecutionError.commandFailure(command, code: code) }
                }
            }
            try await extractScreenshots(device: device)

            print("\t💤 Shutting down the device: \(device.simulatorName)")
            try await Commandline("xcrun simctl shutdown \(quote: device.simulatorName)").run().value
        }
    }

    private func runTest(destination: String) async throws {
        let screenshotGeneration = Commandline(
            """
            xcodebuild test\
             -scheme \(quote: scheme)\
             -destination \(quote: destination)\
             -derivedDataPath \(derivedDataURL.relativePath)\
             -testPlan \(testPlan)
            """,
            currentDirectoryURL: projectURL
        )

        let task = screenshotGeneration.run()
        // Filter non meaningful lines (or only display them on error)
        for try await line in screenshotGeneration.lines
        where line.starts(with: #/Test Suite|Test Case|t =|\*\*/#) { print("\t\(line)") }

        for try await line in screenshotGeneration.errorLines
        where line.contains(#/error/#.ignoresCase()) { print("\t\(line)") }

        try await task.value
    }

    private func extractScreenshots(device: Device) async throws {
        print("\t👷‍♀️ Extraction and renaming of screenshots for \(device.simulatorName) in progress")

        let testURL = derivedDataURL.appending(components: "Logs", "Test")

        let resultFileURL = testURL.appending(component: "LogStoreManifest.plist")
        let resultFile = try XMLDecoder().decode(LogStoreManifest.self, from: Data(contentsOf: resultFileURL))

        let lastXCResultFileNameURL = testURL.appending(component: resultFile.lastXCResultFileName)
        let result = XCResultFile(url: lastXCResultFileNameURL)

        guard let testPlanRunSummariesId = result.testPlanSummariesId
        else { throw ExecutionError.uiTestFailed("No TestPlan found!") }
        let summaries = result.getTestPlanRunSummaries(id: testPlanRunSummariesId)?.summaries ?? []
        for summary in summaries {
            guard let summaryName = summary.name else { throw ExecutionError.xcResultNameMissing("summary.name") }
            print("\t⛏ extraction for the configuration \(summaryName) in progress")
            for test in summary.screenshotTests ?? [] {
                guard let testName = test.name else { throw ExecutionError.xcResultNameMissing("test.name") }
                guard let summaryName = summary.name else { throw ExecutionError.xcResultNameMissing("summary.name") }

                let normalizedTestName = testName
                    .replacingOccurrences(of: "test", with: "")
                    .replacingOccurrences(of: "Screenshot()", with: "")
                print("\t👉 extraction of \(normalizedTestName) in progress")

                guard let summaryId = test.summaryRef?.id
                else {
                    throw ExecutionError.screenshotExtractionFailed(
                        "Cannot get summary id from \(summaryName) for \(testName)"
                    )
                }

                guard let payloadId = result.screenshotAttachmentPayloadId(summaryId: summaryId)
                else {
                    throw ExecutionError.screenshotExtractionFailed(
                        "Cannot get payload id from \(summaryName) for \(testName)"
                    )
                }

                guard let screenshotData = result.getPayload(id: payloadId)
                else {
                    throw ExecutionError.screenshotExtractionFailed(
                        "Cannot get data from the screenshot of \(summaryName) for \(testName)"
                    )
                }

                let screenshotName = """
                Screenshot - \(device.screenDescription) - \(summaryName)"\
                 - \(normalizedTestName) - \(device.simulatorName).png
                """
                let exportURL = exportFolderURL.appending(component: screenshotName)
                try screenshotData.write(to: exportURL)
                print("\t📸 \(normalizedTestName) is available here: \(exportURL.relativePath)")
            }
        }
    }
}

extension Device: Decodable {

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
