import XCResultKit

struct LogStoreManifest: Decodable {
    var dict: RootDict

    var lastXCResultFileName: String {
        return dict.dict.dicts.flatMap(\.strings).filter { $0.hasSuffix(".xcresult") }.sorted().last!
    }
}

struct RootDict: Decodable {
    var dict: LogsDict
}

struct LogsDict: Decodable {
    var dicts: [LogDict]

    enum CodingKeys: String, CodingKey {
        case dicts = "dict"
    }
}

struct LogDict: Decodable {
    var strings: [String]

    enum CodingKeys: String, CodingKey {
        case strings = "string"
    }
}
