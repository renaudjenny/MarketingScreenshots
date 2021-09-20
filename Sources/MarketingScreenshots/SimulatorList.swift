import Foundation

struct SimulatorList: Decodable {
    let devices: [String: [Simulator]]

    func simulator(deviceTypeIdentifier: String) -> Simulator? {
        devices.flatMap { $0.value }.first { $0.deviceTypeIdentifier == deviceTypeIdentifier }
    }
}

struct Simulator: Decodable {
    let name: String
    let dataPath: String
    let logPath: String
    let udid: String
    let isAvailable: Bool
    let deviceTypeIdentifier: String
    let state: State

    enum State: String, Decodable {
        case shutdown = "Shutdown"
        case booted = "Booted"
    }
}
