import ArgumentParser

@main
struct MarketingScreenshotsCommand: ParsableCommand {
    @Argument(help: "Path to the project")
    var path: String

    mutating func run() throws {
        print(path)
    }
}
