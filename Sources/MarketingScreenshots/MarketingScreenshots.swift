import Combine
import Foundation
import XCResultKit
import XMLCoder
import ShellOut

public enum MarketingScreenshots {
    private static let currentDirectoryPath = FileManager.default.currentDirectoryPath
    private static let derivedDataPath = "\(currentDirectoryPath)/.DerivedDataMarketing"
    private static let exportFolder = "\(currentDirectoryPath)/.ExportedScreenshots"

    public static func iOS(
        devices: [Device],
        projectName: String,
        planName: String = "Marketing"
    ) throws {
        try prepare()
        try checkSimulatorAvailability(devices: devices)
        try generateScreenshots(project: .iOS(projectName, devices), planName: planName)
        try shellOut(to: .openFile(at: exportFolder))
    }

    public static func macOS(
        projectName: String,
        planName: String = "Marketing"
    ) throws {
        try prepare()
        try generateScreenshots(project: .macOS(projectName), planName: planName)
        try shellOut(to: .openFile(at: exportFolder))
    }

    private static func prepare() throws {
        print("🗂 Working directory: \(currentDirectoryPath)")
        try shellOut(to: "mkdir -p \(exportFolder)")
    }

    private static func checkSimulatorAvailability(devices: [Device]) throws {
        print("🤖 Check simulators available and if they are ready to be used for screenshots")
        let json = try shellOut(to: .listSimulators)
        guard let data = json.data(using: .utf8) else { throw ExecutionError.stringToDataFailed }
        let simulators = try JSONDecoder().decode(SimulatorList.self, from: data)
        let availableDevices = simulators.devices.flatMap { $0.value.map(\.name) }
        try devices.forEach { device in
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
                    print("     📱💤 Shutting down the device: \(device.simulatorName)")
                    try shellOut(to: .shutdownSimulator(named: device.simulatorName))
                }
            } else {
                try shellOut(to: .createSimulator(name: device.simulatorName))
            }
        }
    }

    private static func generateScreenshots(project: Project, planName: String) throws {
        print("📺 Starting generating Marketing screenshots...")
        switch project {
        case let .iOS(projectName, devices):
            try devices.forEach { device in
                try iOSScreenshots(
                    for: device,
                    projectName: projectName,
                    planName: planName
                )
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
        print("📱 Currently running on Simulator named: \(device.simulatorName) for screenshot size \(device.screenDescription)")
        print("     📲 Booting the device: \(device.simulatorName)")
        try shellOut(to: .bootSimulator(named: device.simulatorName))
        print("     👷‍♀️ Generation of screenshots for \(device.simulatorName) via test plan in progress")
        print("     🧵 This will run on thread \(Thread.current)")
        print("     🐢 This usually takes some time and some resources...")
        print("     🩺 Let's measure the RAM consumption before running the test")
        printMemoryUsage()

        var retry = 5
        while true {
            guard retry > 0 else {
                print("     ❌ Failure. Too many retries")
                break
            }

            do {
                try shellOut(
                    to: .iOSTest(
                        scheme: projectName,
                        simulatorName: device.simulatorName,
                        derivedDataPath: derivedDataPath,
                        testPlan: planName
                    )
                ) { print($0) }

                print("     🩺 Let's measure the RAM consumption after running the test")
                printMemoryUsage()

                try extractScreenshots(
                    name: device.simulatorName,
                    screenDescription: device.screenDescription
                )
                retry = 0
            } catch {
                print("     ❌ Failed. Let's retry. \(retry - 1) attempts left.")
                retry -= 1
            }
        }
        try shellOut(to: .shutdownSimulator(named: device.simulatorName))
    }

    private static func macOSScreenshots(projectName: String, planName: String) throws {
        print("💻 Currently running on this mac")
        print("     👷‍♀️ Generation of screenshots for mac via test plan in progress")
        print("     🐢 This usually takes some time and some resources...")
        print("     🩺 Let's measure the RAM consumption before running the test")
        printMemoryUsage()
        try shellOut(to: .macTest(
            scheme: projectName,
            derivedDataPath: derivedDataPath,
            testPlan: planName
        ))
        print("     🩺 Let's measure the RAM consumption after running the test")
        printMemoryUsage()
        try extractScreenshots(name: "mac", screenDescription: "mac screen")
    }

    private static func cleanUpDerivedDataIfNeeded() throws {
        if FileManager.default.fileExists(atPath: derivedDataPath) {
            print("🧹 Clean the last derived data at path \(derivedDataPath)")
            try FileManager.default.removeItem(atPath: derivedDataPath)
        }
    }

    private static func extractScreenshots(name: String, screenDescription: String) throws {
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
        let summaries = result.getTestPlanRunSummaries(id: testPlanRunSummariesId)?.summaries ?? []
        for summary in summaries {
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
