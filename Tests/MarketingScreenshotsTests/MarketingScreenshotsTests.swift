import XCTest
import ShellOut
@testable import MarketingScreenshots

final class MarketingScreenshotsTests: XCTestCase {
    func testHelloWorldSample() throws {
        try shellOut(
            to: "swift run --package-path Scripts",
            at: "~/Sources/MarketingScreenshots/HelloWorldSample"
        )
    }

    static var allTests = [
        ("testHelloWorldSample", testHelloWorldSample),
    ]
}
