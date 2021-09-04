import Foundation
import ShellOut

extension ShellOutCommand {
    static func iOSTest(
        scheme: String,
        simulatorName: String,
        derivedDataPath: String,
        testPlan: String
    ) -> ShellOutCommand {
        let command = "xcodebuild test -scheme \"\(scheme)\" -destination \"platform=iOS Simulator,name=\(simulatorName)\" -derivedDataPath \(derivedDataPath) -testPlan \(testPlan)"
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

    static func createSimulator(name: String) -> ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl create \"\(name)\"")
    }

    static func bootSimulator(named name: String) -> ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl boot \"\(name)\"")
    }

    static func shutdownSimulator(named name: String) -> ShellOutCommand {
        ShellOutCommand(string: "xcrun simctl shutdown \"\(name)\"")
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
    let outputQueue = DispatchQueue(label: "bash-live-output-queue")

    let temporaryOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "shellout_live_output.temp"
    )
    if FileManager.default.fileExists(atPath: temporaryOutputURL.absoluteString) {
        try FileManager.default.removeItem(at: temporaryOutputURL)
    }
    try Data().write(to: temporaryOutputURL)
    let outputHandle = try FileHandle(forUpdating: temporaryOutputURL)

    #if DEBUG
    print("To read live output file directly in a terminal")
    print("tail -f \(temporaryOutputURL.path)")
    #endif

    outputHandle.readabilityHandler = { handler in
        do {
            guard let data = try handler.readToEnd() else {
                print("data nil")
                return
            }
            outputQueue.async {
                liveOutput(data.shellOutput())
            }
        } catch {
            print("Error happened. Cannot readToEnd: \(error)")
        }
    }

//    errorPipe.fileHandleForReading.readabilityHandler = { handler in
//        let data = handler.availableData
//        outputQueue.async {
//            errorData.append(data)
//            errorHandle?.write(data)
//        }
//    }


    return try outputQueue.sync {
        let output = try shellOut(to: command, at: path, process: process, outputHandle: outputHandle, errorHandle: errorHandle)

        try FileManager.default.removeItem(at: temporaryOutputURL)

        return output
    }
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
