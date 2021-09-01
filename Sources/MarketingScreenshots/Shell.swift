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
