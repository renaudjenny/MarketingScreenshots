import Foundation
import ShellOut

extension ShellOutCommand {
    typealias Device = MarketingScreenshots.Device

    static func iOSTest(
        scheme: String,
        device: Device,
        derivedDataPath: String,
        testPlan: String
    ) -> ShellOutCommand {
        let command = "xcodebuild test -scheme \"\(scheme)\" -destination \"platform=iOS Simulator,name=\(device.rawValue)\" -derivedDataPath \(derivedDataPath) -testPlan \(testPlan)"
        return ShellOutCommand(string: command)
    }

    static func macTest(
        scheme: String,
        derivedDataPath: String,
        testPlan: String
    ) -> ShellOutCommand {
        let command = "xcodebuild test -scheme \"\(scheme)\" -derivedDataPath \(derivedDataPath) -testPlan \(testPlan)"
        return ShellOutCommand(string: command)
    }

    static var listSimulators: ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl list -j devices available")
    }

    static func createSimulator(_ device: Device) -> ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl create \"\(device.simulatorName)\" \(device.rawValue)")
    }

    static func bootSimulator(_ device: Device) -> ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl boot \"\(device.simulatorName)\"")
    }

    static func shutdownSimulator(_ device: Device) -> ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl shutdown \"\(device.simulatorName)\"")
    }

    static var availableDeviceTypes: ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl list devicetypes")
    }
}

@discardableResult func shellOut(
    to command: ShellOutCommand,
    arguments: [String] = [],
    at path: String = ".",
    process: Process = .init(),
    errorHandle: FileHandle? = nil,
    liveOutput: @escaping (String) -> Void
) throws -> String {
    let temporaryOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "shellout_live_output.temp"
    )
    if FileManager.default.fileExists(atPath: temporaryOutputURL.absoluteString) {
        try FileManager.default.removeItem(at: temporaryOutputURL)
    }
    try Data().write(to: temporaryOutputURL)
    let outputHandle = try FileHandle(forWritingTo: temporaryOutputURL)

    print("To read live output file directly in a terminal")
    print("tail -f \(temporaryOutputURL.path)")

    outputHandle.waitForDataInBackgroundAndNotify()
    let subscription = NotificationCenter.default.publisher(for: NSNotification.Name.NSFileHandleDataAvailable)
        .tryReduce("", { alreadyDisplayedContent, _ in
            let content = try String(contentsOf: temporaryOutputURL)
            liveOutput(String(content[alreadyDisplayedContent.endIndex...]))

            outputHandle.waitForDataInBackgroundAndNotify()
            return content
        })
        .sink(receiveCompletion: {
            switch $0 {
            case let .failure(error):
                print("Content of live output cannot be read: \(error)")
            case .finished: break
            }
        }, receiveValue: { _ in })

    let output = try shellOut(to: command, at: path, process: process, outputHandle: outputHandle, errorHandle: errorHandle)
    subscription.cancel()

    try FileManager.default.removeItem(at: temporaryOutputURL)

    return output
}

private extension Data {
    func shellOutput() -> String {
        guard let output = String(data: self, encoding: .utf8) else {
            return ""
        }

        guard !output.hasSuffix("\n") else {
            let endIndex = output.index(before: output.endIndex)
            return String(output[..<endIndex])
        }

        return output
    }
}
