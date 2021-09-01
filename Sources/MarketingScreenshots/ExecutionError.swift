import Foundation

enum ExecutionError: Error {
    case uiTestFailed(String)
    case screenshotExtractionFailed(String)
    case stringToDataFailed
}
