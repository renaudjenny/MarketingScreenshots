import Combine
import Foundation
import XCResultKit
import XMLCoder

public enum MarketingScreenshots {
    private static let derivedDataPath = "\(currentDirectoryPath)/.DerivedDataMarketing"
    private static let exportFolder = "\(currentDirectoryPath)/.ExportedScreenshots"

    private static var cancellable: AnyCancellable? = nil

    public static func iOS(
        devices: [Device],
        projectName: String,
        planName: String = "Marketing"
    ) throws {
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        cancellable = prepare()
//            .map { checkSimulatorAvailability(devices: devices) }
            .sink { completion in
                switch completion {
                case .finished: break
                case let .failure(error):
                    print("Process failed with error: \(error)")
                    dispatchGroup.leave()
                }
            } receiveValue: { _ in
                print("...")
                dispatchGroup.leave()
            }
//        try generateScreenshots(project: .iOS(projectName, devices), planName: planName)
//        try openScreenshotsFolder()

        dispatchGroup.wait()
    }

    public static func macOS(
        projectName: String,
        planName: String = "Marketing"
    ) throws {
//        try prepare()
//        try generateScreenshots(project: .macOS(projectName), planName: planName)
//        try openScreenshotsFolder()
    }

    private static func prepare() -> AnyPublisher<Void, Error> {
        Process.run(.mkdir, arguments: ["-p", exportFolder])
            .message("🗂 Working directory: \(currentDirectoryPath)")
            .tryMap { output, process in
                guard process.terminationStatus == 0 else {
                    throw ExecutionError.commandFailed("mkdir failed to create the folder \(exportFolder)")
                }
            }
            .eraseToAnyPublisher()
    }

    private static func openScreenshotsFolder() throws {
        guard shell(command: .open, arguments: [exportFolder]).status == 0
        else {
            throw ExecutionError.commandFailed(
                "Cannot open the folder \(exportFolder) automatically"
            )
        }
    }

    private static func checkSimulatorAvailability(devices: [Device]) -> AnyPublisher<Void, Error> {
        Process.run(.xcrun, arguments: ["simctl", "list", "-j", "devices", "available"])
            .message("🤖 Check simulators available and if they are ready to be used for screenshots")
            .tryCompactMap { output, process in
                guard process.terminationStatus == 0 else {
                    throw ExecutionError.commandFailed(
                        "xcrun simctl list -j devices available failed to found the devices list"
                    )
                }
                return output
            }
            .compactMap { (json: String) in json.data(using: .utf8) }
            .decode(type: SimulatorList.self, decoder: JSONDecoder())
            .flatMap { simulators -> AnyPublisher<Void, Error> in
                let availableDevices = simulators.devices.flatMap { $0.value.map(\.name) }

                return Publishers.MergeMany(devices.map { device -> AnyPublisher<Void, Error> in
                    if availableDevices.contains(device.simulatorName) {
                        print("     📲 \(device.simulatorName) simulator is created. Checking the status...")
                        let simulator = simulators.simulator(named: device.simulatorName)
                        let state: String
                        switch simulator?.state {
                        case .booted: state = "Booted"
                        case .shutdown: state = "Shutdown"
                        case .none: state = "Unknown"
                        }
                        let availability = (simulator?.isAvailable ?? false) ? "Available" : "Unavailable"
                        print("     🚥 Device state: \(state), availability: \(availability)")

                        if simulator?.state != .shutdown {
                            return shutdownSimulator(named: device.simulatorName)
                        }
                        return Future { $0(.success(())) }.eraseToAnyPublisher()
                    }
                    return createSimulator(name: device.simulatorName)
                })
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private static func createSimulator(name: String) -> AnyPublisher<Void, Error> {
        Process.run(.xcrun, arguments: ["simctl", "create", name, name])
            .message("     📲 \(name) simulator is not available. Create it now")
            .tryMap { output, process in
                guard process.terminationStatus == 0 else {
                    throw ExecutionError.commandFailed(
                        "xcrun simctl create failed for the device \(name)"
                    )
                }
            }
            .eraseToAnyPublisher()
    }

    private static func generateScreenshots(project: Project, planName: String) throws {
        print("📺 Starting generating Marketing screenshots...")
        switch project {
        case let .iOS(projectName, devices):
            for device in devices {
                try iOSScreenshots(for: device, projectName: projectName, planName: planName)
            }
        case let .macOS(projectName):
            try macOSScreenshots(projectName: projectName, planName: planName)
        }
    }

    private static func iOSScreenshots(
        for device: Device,
        projectName: String,
        planName: String
    ) throws {
        try cleanUpDerivedDataIfNeeded()
        print("📱 Currently running on Simulator named: \(device.simulatorName) for screenshot size \(device.screenDescription)")
        print("     📲 Booting the device: \(device.simulatorName)")
        let boot = shell(command: .xcrun, arguments: ["simctl", "boot", device.simulatorName])
        guard boot.status == 0 else {
            throw ExecutionError.commandFailed("""
            xcrun simctl boot \(device.simulatorName) failed with errors:
            \(boot.output ?? "Output unavailable")
            """)
        }

        print("     👷‍♀️ Generation of screenshots for \(device.simulatorName) via test plan in progress")
        print("     🧵 This will run on thread \(Thread.current)")
        print("     🐢 This usually takes some time and some resources...")
        print("     🩺 Let's measure the RAM consumption before running the test")
        printMemoryUsage()

        let marketingTestPlan = shell(command: .xcodebuild, arguments: [
            "test",
            "-scheme", projectName,
            "-destination", "platform=iOS Simulator,name=\(device.simulatorName)",
            "-derivedDataPath", derivedDataPath,
            "-testPlan", planName,
        ])

        print("     🩺 Let's measure the RAM consumption after running the test")
        printMemoryUsage()

        try extractScreenshots(
            from: marketingTestPlan,
            name: device.simulatorName,
            screenDescription: device.screenDescription
        )

        try shutdownSimulator(named: device.simulatorName)
    }

    private static func macOSScreenshots(projectName: String, planName: String) throws {
        try cleanUpDerivedDataIfNeeded()
        print("💻 Currently running on this mac")
        print("     👷‍♀️ Generation of screenshots for mac via test plan in progress")
        print("     🐢 This usually takes some time and some resources...")
        print("     🩺 Let's measure the RAM consumption before running the test")
        printMemoryUsage()

        let marketingTestPlan = shell(command: .xcodebuild, arguments: [
            "test",
            "-scheme", projectName,
            "-derivedDataPath", derivedDataPath,
            "-testPlan", planName,
            "CODE_SIGNING_ALLOWED=NO",
        ])

        print("     🩺 Let's measure the RAM consumption after running the test")
        printMemoryUsage()

        try extractScreenshots(
            from: marketingTestPlan,
            name: "mac",
            screenDescription: "mac screen"
        )
    }

    private static func cleanUpDerivedDataIfNeeded() throws {
        if FileManager.default.fileExists(atPath: derivedDataPath) {
            print("🧹 Clean the last derived data at path \(derivedDataPath)")
            try FileManager.default.removeItem(atPath: derivedDataPath)
        }
    }

    private static func extractScreenshots(
        from marketingTestPlan: (output: String?, status: Int32),
        name: String,
        screenDescription: String
    ) throws {
        guard marketingTestPlan.status == 0 else {
            marketingTestPlan.output.map {
                let lines = $0.split(separator: "\n")
                let twoFirstLines = lines.prefix(2)
                let thirtyLastLines = lines.suffix(50)
                let output = (twoFirstLines + ["..."] + thirtyLastLines).joined(separator: "\n")
                print("     🥺 Something went wrong... Let's print the 2 first lines and the 50 last lines of the output from Xcode test\n\(output)")
            } ?? print("     🥺 Cannot print xcodebuild errors...")

            throw ExecutionError.uiTestFailed("Marketing Test Plan failed. See errors above")
        }
        print("     ✅ Generation of screenshots for \(name) via test plan done")

        print("     👷‍♀️ Extraction and renaming of screenshots for \(name) in progress")

        let path = "\(derivedDataPath)/Logs/Test/LogStoreManifest.plist"

        let resultFile = try XMLDecoder().decode(
            LogStoreManifest.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )

        let lastXCResultFileNameURL = URL(
            fileURLWithPath: "\(derivedDataPath)/Logs/Test/\(resultFile.lastXCResultFileName)"
        )
        let result = XCResultFile(url: lastXCResultFileNameURL)

        guard let testPlanRunSummariesId = result.testPlanSummariesId
        else {
            throw ExecutionError.uiTestFailed("No TestPlan found!")
        }
        for summary in result.getTestPlanRunSummaries(id: testPlanRunSummariesId)?.summaries ?? [] {
            print("         ⛏ extraction for the configuration \(summary.name) in progress")
            for test in summary.screenshotTests ?? [] {
                try exportScreenshot(
                    name: name,
                    screenDescription: screenDescription,
                    result: result,
                    summary: summary,
                    test: test
                )
            }
        }
    }

    private static func exportScreenshot(
        name: String,
        screenDescription: String,
        result: XCResultFile,
        summary: ActionTestPlanRunSummary,
        test: ActionTestMetadata
    ) throws {
        let normalizedTestName = test.name
            .replacingOccurrences(of: "test", with: "")
            .replacingOccurrences(of: "Screenshot()", with: "")
        print("             👉 extraction of \(normalizedTestName) in progress")

        guard let summaryId = test.summaryRef?.id
        else {
            throw ExecutionError.screenshotExtractionFailed(
                "Cannot get summary id from \(summary.name) for \(test.name)"
            )
        }

        guard let payloadId = result.screenshotAttachmentPayloadId(summaryId: summaryId)
        else {
            throw ExecutionError.screenshotExtractionFailed(
                "Cannot get payload id from \(summary.name) for \(test.name)"
            )
        }

        guard let screenshotData = result.getPayload(id: payloadId)
        else {
            throw ExecutionError.screenshotExtractionFailed(
                "Cannot get data from the screenshot of \(summary.name) for \(test.name)"
            )
        }

        let path = "\(exportFolder)/Screenshot - \(screenDescription) - \(summary.name)"
            + " - \(normalizedTestName) - \(name).png"
        try screenshotData.write(to: URL(fileURLWithPath: path))
        print("              📸 \(normalizedTestName) is available here: \(path)")
    }

    private static func shutdownSimulator(named name: String) -> AnyPublisher<Void, Error> {
        Process.run(.xcrun, arguments: ["simctl", "shutdown", name])
            .message("     📱💤 Shutting down the device: \(name)")
            .tryMap { output, process in
                guard process.terminationStatus == 0 else {
                    throw ExecutionError.commandFailed("""
                    xcrun simctl shutdown \(name) failed with errors:
                    \(output ?? "Output unavailable")
                    """)
                }
            }
            .eraseToAnyPublisher()
    }

    // Code available here: https://gist.github.com/pejalo/671dd2f67e3877b18c38c749742350ca
    private static func getMemoryUsedAndDeviceTotalInMegabytes() -> (Float, Float) {

        // https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget/19692719#19692719
        // https://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info/27559770#27559770

        var used_megabytes: Float = 0

        let total_bytes = Float(ProcessInfo.processInfo.physicalMemory)
        let total_megabytes = total_bytes / 1024.0 / 1024.0

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            let used_bytes: Float = Float(info.resident_size)
            used_megabytes = used_bytes / 1024.0 / 1024.0
        }

        return (used_megabytes, total_megabytes)
    }

    private static func printMemoryUsage() {
        let (used, total) = getMemoryUsedAndDeviceTotalInMegabytes()
        let formattedUsed = String(format: "%.2f", used)
        let formattedTotal = String(format: "%.2f", total)
        print("     🗃 Memory used: \(formattedUsed)/\(formattedTotal)")
    }
}
