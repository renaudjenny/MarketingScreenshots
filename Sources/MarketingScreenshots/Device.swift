/// See [App Store Connect help about devices sizes](https://help.apple.com/app-store-connect/#/devd274dd925)
enum Device: String, CaseIterable {
    case iPhone14Plus = "com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus"
    case iPhone14ProMax = "com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro-Max"
    case iPhone14Pro = "com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro"
    case iPhone14 = "com.apple.CoreSimulator.SimDeviceType.iPhone-14"
    case iPhone8Plus = "com.apple.CoreSimulator.SimDeviceType.iPhone-8-Plus"
    case iPhoneSE_3rd_Generation = "com.apple.CoreSimulator.SimDeviceType.iPhone-SE--3rd-generation-"

    case iPadPro_129_6th_Generation = "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--12-9-inch---6th-generation-"
    case iPadPro_129_2nd_Generation = "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--12-9-inch---2nd-generation-"
    case iPadPro_110_4th_Generation = "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--11-inch---4th-generation-"

    public var simulatorName: String {
        switch self {
        case .iPhone14Plus: return "iPhone 14 Plus"
        case .iPhone14ProMax: return "iPhone 14 Pro Max"
        case .iPhone14Pro: return "iPhone 14 Pro"
        case .iPhone14: return "iPhone 14"
        case .iPhone8Plus: return "iPhone 8 Plus"
        case .iPhoneSE_3rd_Generation: return "iPhone SE (3rd generation)"

        case .iPadPro_129_6th_Generation: return "iPad Pro (12.9-inch) (6th generation)"
        case .iPadPro_129_2nd_Generation: return "iPad Pro (12.9-inch) (2nd generation)"
        case .iPadPro_110_4th_Generation: return "iPad Pro (11-inch) (4th generation)"
        }
    }

    public var screenDescription: String {
        switch self {
        case .iPhone14Plus: return "6.5 inch"
        case .iPhone14ProMax: return "6.7 inch"
        case .iPhone14Pro: return "6.1 inch"
        case .iPhone14: return "5.8 inch"
        case .iPhone8Plus: return "5.5 inch"
        case .iPhoneSE_3rd_Generation: return "4.7 inch"

        case .iPadPro_129_6th_Generation: return "12.9 inch borderless"
        case .iPadPro_129_2nd_Generation: return "12.9 inch"
        case .iPadPro_110_4th_Generation: return "11 inch"
        }
    }
}
