import Foundation

enum ExecutionError: Error {
    case uiTestFailed(String)
    case screenshotExtractionFailed(String)
    case stringToDataFailed
    case xcResultNameMissing(String)
    case projectFolderNotFound
    case deviceNameUnknown(String)
    case missingSimulatorID(for: MarketingScreenshots.Device)
    case commandFailure(String, code: Int32)
}
