import Foundation

struct Commandline {
    private let process = Process()
    private let pipe = Pipe()
    private let errorPipe = Pipe()

    var lines: AsyncLineSequence<FileHandle.AsyncBytes> { pipe.fileHandleForReading.bytes.lines }
    var errorLines: AsyncLineSequence<FileHandle.AsyncBytes> { errorPipe.fileHandleForReading.bytes.lines }

    init(_ command: String) {
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.arguments = ["-c", command]
    }

    func run() {
        do {
            try process.run()
        } catch {
            print(error)
        }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(quote value: String) {
        appendLiteral("\"\(value)\"")
    }
}
