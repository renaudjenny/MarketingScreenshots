import Foundation

struct Commandline {
    private let process = Process()
    private let pipe = Pipe()
    private let errorPipe = Pipe()

    var lines: AsyncLineSequence<FileHandle.AsyncBytes> { pipe.fileHandleForReading.bytes.lines }
    var errorLines: AsyncLineSequence<FileHandle.AsyncBytes> { errorPipe.fileHandleForReading.bytes.lines }

    private let command: String

    init(_ command: String, currentDirectoryURL: URL? = nil) {
        self.command = command
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        currentDirectoryURL.map { process.currentDirectoryURL = $0 }
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.arguments = ["-c", command]
    }

    @discardableResult
    func run() -> Task<Void, Error> {
        Task {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try process.run()
                } catch {
                    continuation.resume(with: .failure(error))
                }
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(with: .failure(
                            ExecutionError.commandFailure(command, code: process.terminationStatus)
                        ))
                    }
                }
            }
        }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(quote value: String) {
        appendLiteral("\"\(value)\"")
    }
}
