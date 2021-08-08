import Foundation
import XCResultKit
import XMLCoder

public enum MarketingScreenshots {
    public static func run(
        devices: [Device],
        iOSProjectName: String,
        macProjectName: String,
        planName: String = "Marketing"
    ) throws {
        print("🗂 Working directory: \(currentDirectoryPath)")

        let derivedDataPath = "\(currentDirectoryPath)/.DerivedDataMarketing"
        let exportFolder = "\(currentDirectoryPath)/.ExportedScreenshots"

        guard shell(command: .mkdir, arguments: ["-p", exportFolder]).status == 0
        else {
            throw ExecutionError.commandFailed("mkdir failed to create the folder \(exportFolder)")
        }

        try checkSimulatorAvailability(devices: devices)

        try generateScreenshots(
            devices: devices,
            iOSProjectName: iOSProjectName,
            macProjectName: macProjectName,
            derivedDataPath: derivedDataPath,
            exportFolder: exportFolder,
            planName: planName
        )

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
            if device == .mac {
                print("     🖥 Mac is available. Nothing to do")
                continue
            } else if availableDevices.contains(device.simulatorName) {
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

    private static func generateScreenshots(
        devices: [Device],
        iOSProjectName: String,
        macProjectName: String,
        derivedDataPath: String,
        exportFolder: String,
        planName: String
    ) throws {
        print("📺 Starting generating Marketing screenshots...")
        for device in devices {
            try runTest(
                device: device,
                iOSProjectName: iOSProjectName,
                macProjectName: macProjectName,
                derivedDataPath: derivedDataPath,
                exportFolder: exportFolder,
                planName: planName
            )
        }
    }

    private static func runTest(
        device: Device,
        iOSProjectName: String,
        macProjectName: String,
        derivedDataPath: String,
        exportFolder: String,
        planName: String
    ) throws {
        print("🧹 Clean the last derived data at path \(derivedDataPath)")
        try FileManager.default.removeItem(atPath: derivedDataPath)

        if device != .mac {
            print("📱 Currently running on Simulator named: \(device.simulatorName) for screenshot size \(device.screenDescription)")
        } else {
            print("💻 Currently running on this mac")
        }
        print("     👷‍♀️ Generation of screenshots for \(device.simulatorName) via test plan in progress")
        print("     🐢 This usually takes some time...")

        let marketingTestPlan: (output: String?, status: Int32)
        if device == .mac {
            marketingTestPlan = shell(command: .xcodebuild, arguments: [
                "test",
                "-scheme", macProjectName,
                "-derivedDataPath", derivedDataPath,
                "-testPlan", planName,
                "CODE_SIGNING_ALLOWED=NO",
            ])
        } else {
            marketingTestPlan = shell(command: .xcodebuild, arguments: [
                "test",
                "-scheme", iOSProjectName,
                "-destination", "platform=iOS Simulator,name=\(device.simulatorName)",
                "-derivedDataPath", derivedDataPath,
                "-testPlan", planName,
            ])
        }

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
                    device: device,
                    result: result,
                    summary: summary,
                    test: test,
                    exportFolder: exportFolder
                )
            }
        }
    }

    private static func exportScreenshot(
        device: Device,
        result: XCResultFile,
        summary: ActionTestPlanRunSummary,
        test: ActionTestMetadata,
        exportFolder: String
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

        let path = "\(exportFolder)/Screenshot - \(device.screenDescription) - \(summary.name)"
            + " - \(normalizedTestName) - \(device.simulatorName).png"
        try screenshotData.write(to: URL(fileURLWithPath: path))
        print("              📸 \(normalizedTestName) is available here: \(path)")
    }
}
