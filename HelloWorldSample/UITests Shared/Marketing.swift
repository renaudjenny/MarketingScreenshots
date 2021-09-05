import XCTest

class Marketing: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIApplication().launch()
    }

    func testMainScreenScreenshot() throws {
        // Do whatever you want to navigate, tap on buttons, etc.

        // These are the instructions to make a screenshot that we can extract later on with the script
        let screenshot = XCUIApplication().screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
