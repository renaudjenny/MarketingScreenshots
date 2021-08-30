import Combine
import Foundation

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
    ) -> Deferred<Future<(String?, Process), Error>> {
        Deferred {
            Future { promise in
                let process = Process()
                process.executableURL = shellCommand.url
                process.arguments = arguments
                process.qualityOfService = .userInitiated

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                #if DEBUG
                pipe.fileHandleForReading.readabilityHandler = { pipe in
                    guard let output = String(data: pipe.availableData, encoding: .utf8) else {
                        print("Unreadable debug data")
                        return
                    }
                    guard
                        !output.isEmpty,
                        !output.starts(with: "output")
                    else { return }
                    print(output)
                }
                #endif

                process.terminationHandler = { process in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)
                    promise(.success((output, process)))
                }

                do {
                    try process.run()
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }
}
