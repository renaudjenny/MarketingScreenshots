import Combine
import Foundation

let currentDirectoryPath = FileManager.default.currentDirectoryPath

enum ShellCommand: String {
    case xcodebuild = "/usr/bin/xcodebuild"
    case plutil = "/usr/bin/plutil"
    case xmllint = "/usr/bin/xmllint"
    case open = "/usr/bin/open"
    case mkdir = "/bin/mkdir"
    case xcrun = "/usr/bin/xcrun"

    var url: URL { URL(fileURLWithPath: rawValue) }
}

// See https://stackoverflow.com/questions/26971240/how-do-i-run-a-terminal-command-in-a-swift-script-e-g-xcodebuild
func shell(command: ShellCommand, arguments: [String] = []) -> (output: String?, status: Int32) {
    let task = Process()
    task.executableURL = command.url
    task.currentDirectoryPath = currentDirectoryPath
    task.arguments = arguments
    task.qualityOfService = .userInteractive

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)
    task.waitUntilExit()
    return (output, task.terminationStatus)
}

extension Process {
    static func run(
        _ shellCommand: ShellCommand,
        arguments: [String] = []
    ) -> Future<(String?, Process), Error> {
        return Future { promise in
            do {
                let process = Process()
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                process.qualityOfService = .userInitiated

                process.terminationHandler = { process in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)
                    promise(.success((output, process)))
                }

                try process.run()
            } catch {
                promise(.failure(error))
            }
        }
    }
}

// TODO: Move to its own file

extension Publisher {
    func message(_ message: String) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveSubscription: { _ in Swift.print(message) })
    }
}
