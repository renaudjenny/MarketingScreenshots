public extension MarketingScreenshots {

    /// See [App Store Connect help about devices sizes](https://help.apple.com/app-store-connect/#/devd274dd925)
    enum Device: String, CaseIterable {
        case iPhone12ProMax = "iPhone 12 Pro Max"
        case iPhone12Pro = "iPhone 12 Pro"
        case iPhone8Plus = "iPhone 8 Plus"
        case iPhoneSE_2nd_Generation = "iPhone SE (2nd generation)"
        case iPhoneSE_1st_Generation = "iPhone SE (1st generation)"

        case iPadPro_129_4th_Generation = "iPad Pro (12.9-inch) (4th generation)"
        case iPadPro_129_2nd_Generation = "iPad Pro (12.9-inch) (2nd generation)"
        case iPadPro_110_1st_Generation = "iPad Pro (11-inch) (1st generation)"
        // For some reasons 10.5" isn't working properly,
        // the generated dimensions are 1620 × 2160 pixels,
        // but the ones Apple need is 1668 x 2224 pixels.
        // Then we just ignore this one, the fallback is the screenshots from 12.9"
        // case iPad_8th_Generation = "iPad (8th generation)",
        case iPadPro_97 = "iPad Pro (9.7-inch)"

        public var simulatorName: String { rawValue }

        public var screenDescription: String {
            switch self {
            case .iPhone12ProMax: return "6.5 inch"
            case .iPhone12Pro: return "5.8 inch"
            case .iPhone8Plus: return "5.5 inch"
            case .iPhoneSE_2nd_Generation: return "4.7 inch"
            case .iPhoneSE_1st_Generation: return "4 inch"

            case .iPadPro_129_4th_Generation: return "12.9 inch borderless"
            case .iPadPro_129_2nd_Generation: return "12.9 inch"
            case .iPadPro_110_1st_Generation: return "11 inch"
            // case .iPad_8th_Generation : return "10.5 inch"
            case .iPadPro_97: return "9.7 inch"
            }
        }
    }
}
