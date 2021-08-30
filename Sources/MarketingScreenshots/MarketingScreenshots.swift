import Combine
import Foundation
import XCResultKit
import XMLCoder

public enum MarketingScreenshots {
    private static let currentDirectoryPath = FileManager.default.currentDirectoryPath
    private static let derivedDataPath = "\(currentDirectoryPath)/.DerivedDataMarketing"
    private static let exportFolder = "\(currentDirectoryPath)/.ExportedScreenshots"

    private static var cancellable: AnyCancellable? = nil

    public static func iOS(
        devices: [Device],
        projectName: String,
        planName: String = "Marketing"
    ) throws {
        let devices = [devices.first!]
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        cancellable = prepare()
            .flatMap { checkSimulatorAvailability(devices: devices) }
            .flatMap { _ -> AnyPublisher<Void, Error> in
                do {
                    return try generateScreenshots(
                        project: .iOS(projectName, devices),
                        planName: planName
                    )
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .tryMap { try openScreenshotsFolder() }
            .sink { completion in
                switch completion {
                case .finished: break
                case let .failure(error):
                    print("Process failed with error: \(error)")
                }
                dispatchGroup.leave()
            } receiveValue: { _ in
                print("...")
            }

        dispatchGroup.wait()
    }

    public static func macOS(
        projectName: String,
        planName: String = "Marketing"
    ) throws {
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        cancellable = prepare()
            .flatMap { _ -> AnyPublisher<Void, Error> in
                do {
                    return try generateScreenshots(project: .macOS(projectName), planName: planName)
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .tryMap { try openScreenshotsFolder() }
            .sink { completion in
                switch completion {
                case .finished: break
                case let .failure(error):
                    print("Process failed with error: \(error)")
                }
                dispatchGroup.leave()
            } receiveValue: { _ in
                print("...")
            }
        dispatchGroup.wait()
    }

    private static func prepare() -> AnyPublisher<Void, Error> {
        print("🗂 Working directory: \(currentDirectoryPath)")
        return Process.run(.mkdir, arguments: ["-p", exportFolder])
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
            .map { output -> (String?, Process) in
                print("🤖 Check simulators available and if they are ready to be used for screenshots")
                return output
            }
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
                        return Just(()).mapError { $0 }.eraseToAnyPublisher()
                    }
                    return createSimulator(name: device.simulatorName)
                })
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private static func createSimulator(name: String) -> AnyPublisher<Void, Error> {
        Process.run(.xcrun, arguments: ["simctl", "create", name, name])
            .map { output -> (String?, Process) in
                print("     📲 \(name) simulator is not available. Create it now")
                return output
            }
            .tryMap { output, process in
                guard process.terminationStatus == 0 else {
                    throw ExecutionError.commandFailed(
                        "xcrun simctl create failed for the device \(name)"
                    )
                }
            }
            .eraseToAnyPublisher()
    }

    private static func generateScreenshots(
        project: Project,
        planName: String
    ) throws -> AnyPublisher<Void, Error> {
        print("📺 Starting generating Marketing screenshots...")
        switch project {
        case let .iOS(projectName, devices):
            return Publishers.MergeMany(try devices.map { device in
                return try iOSScreenshots(
                    for: device,
                    projectName: projectName,
                    planName: planName
                )
            })
            .eraseToAnyPublisher()
        case let .macOS(projectName):
            return try macOSScreenshots(projectName: projectName, planName: planName)
        }
    }

    private static func iOSScreenshots(
        for device: Device,
        projectName: String,
        planName: String
    ) throws -> AnyPublisher<Void, Error> {
        try cleanUpDerivedDataIfNeeded()
        print("📱 Currently running on Simulator named: \(device.simulatorName) for screenshot size \(device.screenDescription)")
        print("     📲 Booting the device: \(device.simulatorName)")
        return Process.run(.xcrun, arguments: ["simctl", "boot", device.simulatorName])
            .tryMap { output, process in
                guard process.terminationStatus == 0 else {
                    throw ExecutionError.commandFailed("""
                    xcrun simctl boot \(device.simulatorName) failed with errors:
                    \(output ?? "Output unavailable")
                    """)
                }
            }
            .map {
                print("     👷‍♀️ Generation of screenshots for \(device.simulatorName) via test plan in progress")
                print("     🧵 This will run on thread \(Thread.current)")
                print("     🐢 This usually takes some time and some resources...")
                print("     🩺 Let's measure the RAM consumption before running the test")
                printMemoryUsage()
                return $0
            }
            .flatMap {
                Process.run(.xcodebuild, arguments: [
                    "test",
                    "-scheme", projectName,
                    "-destination", "platform=iOS Simulator,name=\(device.simulatorName)",
                    "-derivedDataPath", derivedDataPath,
                    "-testPlan", planName,
                ])
            }
            .map {
                print("     🩺 Let's measure the RAM consumption after running the test")
                printMemoryUsage()
                return $0
            }
            .tryMap {
                try extractScreenshots(
                    from: $0,
                    name: device.simulatorName,
                    screenDescription: device.screenDescription
                )
            }
            .flatMap { shutdownSimulator(named: device.simulatorName) }
            .eraseToAnyPublisher()
    }

    private static func macOSScreenshots(
        projectName: String,
        planName: String
    ) throws -> AnyPublisher<Void, Error> {
        try cleanUpDerivedDataIfNeeded()
        print("💻 Currently running on this mac")
        print("     👷‍♀️ Generation of screenshots for mac via test plan in progress")
        print("     🐢 This usually takes some time and some resources...")
        print("     🩺 Let's measure the RAM consumption before running the test")
        printMemoryUsage()

        return Process.run(.xcodebuild, arguments: [
            "test",
            "-scheme", projectName,
            "-derivedDataPath", derivedDataPath,
            "-testPlan", planName,
            "CODE_SIGNING_ALLOWED=NO",
        ])
        .map {
            print("     🩺 Let's measure the RAM consumption after running the test")
            printMemoryUsage()
            return $0
        }
        .tryMap {
            try extractScreenshots(
                from: $0,
                name: "mac",
                screenDescription: "mac screen"
            )
        }
        .eraseToAnyPublisher()
    }

    private static func cleanUpDerivedDataIfNeeded() throws {
        if FileManager.default.fileExists(atPath: derivedDataPath) {
            print("🧹 Clean the last derived data at path \(derivedDataPath)")
            try FileManager.default.removeItem(atPath: derivedDataPath)
        }
    }

    private static func extractScreenshots(
        from marketingTestPlan: (output: String?, process: Process),
        name: String,
        screenDescription: String
    ) throws {
        guard marketingTestPlan.process.terminationStatus == 0 else {
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
        print("     📱💤 Shutting down the device: \(name)")
        return Process.run(.xcrun, arguments: ["simctl", "shutdown", name])
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
