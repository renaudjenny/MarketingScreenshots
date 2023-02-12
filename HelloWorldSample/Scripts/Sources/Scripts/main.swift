import MarketingScreenshots

try MarketingScreenshots.iOS(
    devices: [
        .iPhone14Plus,
//        .iPhone14ProMax,
//        .iPhone14Pro,
//        .iPhone14,
//        .iPhone8Plus,
//        .iPhoneSE_3rd_Generation,
//
//        .iPadPro_129_6th_Generation,
//        .iPadPro_129_2nd_Generation,
//        .iPadPro_110_4th_Generation,
    ],
    projectName: "HelloWorldSample (iOS)"
)

try MarketingScreenshots.macOS(projectName: "HelloWorldSample (macOS)")
