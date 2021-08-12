import Foundation
import XCResultKit
import XMLCoder

public enum MarketingScreenshots {
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
        try openScreenshotsFolder()
    }

    public static func macOS(
        projectName: String,
        planName: String = "Marketing"
    ) throws {
        try prepare()
        try generateScreenshots(project: .macOS(planName), planName: planName)
        try openScreenshotsFolder()
    }

    private static func prepare() throws {
        print("🗂 Working directory: \(currentDirectoryPath)")

        guard shell(command: .mkdir, arguments: ["-p", exportFolder]).status == 0
        else {
            throw ExecutionError.commandFailed("mkdir failed to create the folder \(exportFolder)")
        }
    }

    private static func openScreenshotsFolder() throws {
        guard shell(command: .open, arguments: [exportFolder]).status == 0
        else {
            throw ExecutionError.commandFailed(
                "Cannot open the folder \(exportFolder) automatically"
            )
        }
    }

    private static func checkSimulatorAvailability(devices: [Device]) throws {
        print("🤖 Check simulators available and if they are ready to be used for screenshots")
        let deviceList = shell(
            command: .xcrun,
            arguments: ["simctl", "list", "-j", "devices", "available"]
        )
        guard deviceList.status == 0,
              let deviceListJSON = deviceList.output,
              let deviceListData = deviceListJSON.data(using: .utf8)
        else {
            throw ExecutionError.commandFailed(
                "xcrun simctl list -j devices available failed to found the devices list"
            )
        }

        let availableDevices = (try JSONDecoder().decode(SimulatorList.self, from: deviceListData))
            .devices.flatMap { $0.value.map { $0.name } }

        for device in devices {
            guard !availableDevices.contains(device.simulatorName) else {
                print("     📲 \(device.simulatorName) simulator is available. Nothing to do")
                continue
            }

            print("     📲 \(device.simulatorName) simulator is not available. Create it now")

            guard shell(
                command: .xcrun,
                arguments: ["simctl", "create", device.simulatorName, device.simulatorName]
            ).status == 0
            else {
                throw ExecutionError.commandFailed(
                    "xcrun simctl create failed for the device \(device.simulatorName)"
                )
            }
        }
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
        if FileManager.default.fileExists(atPath: derivedDataPath) {
            print("🧹 Clean the last derived data at path \(derivedDataPath)")
            try FileManager.default.removeItem(atPath: derivedDataPath)
        }

        print("📱 Currently running on Simulator named: \(device.simulatorName) for screenshot size \(device.screenDescription)")
        print("     👷‍♀️ Generation of screenshots for \(device.simulatorName) via test plan in progress")
        print("     🐢 This usually takes some time...")

        let marketingTestPlan = shell(command: .xcodebuild, arguments: [
            "test",
            "-scheme", projectName,
            "-destination", "platform=iOS Simulator,name=\(device.simulatorName)",
            "-derivedDataPath", derivedDataPath,
            "-testPlan", planName,
        ])

        guard marketingTestPlan.status == 0 else {
            marketingTestPlan.output.map {
                let lines = $0.split(separator: "\n")
                let twoFirstLines = lines.prefix(2)
                let thirtyLastLines = lines.suffix(30)
                let output = (twoFirstLines + ["..."] + thirtyLastLines).joined(separator: "\n")
                print("     🥺 Something went wrong... Let's print the 2 first lines and the 30 last lines of the output from Xcode test\n\(output)")
            } ?? print("     🥺 Cannot print xcodebuild errors...")

            throw ExecutionError.uiTestFailed("Marketing Test Plan failed. See errors above")
        }
        print("     ✅ Generation of screenshots for \(device.simulatorName) via test plan done")

        print("     👷‍♀️ Extraction and renaming of screenshots for \(device.simulatorName) in progress")

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
                    description: (name: device.simulatorName, screen: device.screenDescription),
                    result: result,
                    summary: summary,
                    test: test
                )
            }
        }
    }

    private static func macOSScreenshots(projectName: String, planName: String) throws {
        if FileManager.default.fileExists(atPath: derivedDataPath) {
            print("🧹 Clean the last derived data at path \(derivedDataPath)")
            try FileManager.default.removeItem(atPath: derivedDataPath)
        }
        print("💻 Currently running on this mac")
        print("     👷‍♀️ Generation of screenshots for mac via test plan in progress")
        print("     🐢 This usually takes some time...")

        let marketingTestPlan = shell(command: .xcodebuild, arguments: [
            "test",
            "-scheme", projectName,
            "-derivedDataPath", derivedDataPath,
            "-testPlan", planName,
            "CODE_SIGNING_ALLOWED=NO",
        ])

        guard marketingTestPlan.status == 0 else {
            marketingTestPlan.output.map {
                let lines = $0.split(separator: "\n")
                let twoFirstLines = lines.prefix(2)
                let thirtyLastLines = lines.suffix(30)
                let output = (twoFirstLines + ["..."] + thirtyLastLines).joined(separator: "\n")
                print("     🥺 Something went wrong... Let's print the 2 first lines and the 30 last lines of the output from Xcode test\n\(output)")
            } ?? print("     🥺 Cannot print xcodebuild errors...")

            throw ExecutionError.uiTestFailed("Marketing Test Plan failed. See errors above")
        }
        print("     ✅ Generation of screenshots for mac via test plan done")

        print("     👷‍♀️ Extraction and renaming of screenshots for mac in progress")

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
                    description: (name: "mac", screen: "mac"),
                    result: result,
                    summary: summary,
                    test: test
                )
            }
        }
    }

    private static func exportScreenshot(
        description: (name: String, screen: String),
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

        let path = "\(exportFolder)/Screenshot - \(description.screen) - \(summary.name)"
            + " - \(normalizedTestName) - \(description.name).png"
        try screenshotData.write(to: URL(fileURLWithPath: path))
        print("              📸 \(normalizedTestName) is available here: \(path)")
    }
}
