import Foundation

enum ExecutionError: Error {
    case commandFailed(String)
    case uiTestFailed(String)
    case screenshotExtractionFailed(String)
}
