import Foundation

public struct SkyLocation: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneIdentifier: String?

    public init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var timeZone: TimeZone {
        if let id = timeZoneIdentifier, let tz = TimeZone(identifier: id) {
            return tz
        }
        return .current
    }

    public var formattedCoordinates: String {
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"
        return String(format: "%.1f°%@ %.1f°%@", abs(latitude), latDir, abs(longitude), lonDir)
    }
}

public enum SkyStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case pure    // 纯净极简
    case cirrus  // 细丝卷云
    case cosmos  // 深空银河

    public var id: String { rawValue }

    public var chineseTitle: String {
        switch self {
        case .pure: return "纯净"
        case .cirrus: return "卷云"
        case .cosmos: return "深空"
        }
    }

    public var description: String {
        switch self {
        case .pure: return "无云雾干扰，极简澄澈大气与锐利星点"
        case .cirrus: return "日间与晨昏叠加高空细丝卷云，夜晚清透"
        case .cosmos: return "增强深空银河星带与高密微星，极清夜空"
        }
    }
}

public enum CityPreset {
    public static let all: [SkyLocation] = [
        SkyLocation(name: "北京", latitude: 39.9042, longitude: 116.4074, timeZoneIdentifier: "Asia/Shanghai"),
        SkyLocation(name: "上海", latitude: 31.2304, longitude: 121.4737, timeZoneIdentifier: "Asia/Shanghai"),
        SkyLocation(name: "杭州", latitude: 30.2741, longitude: 120.1551, timeZoneIdentifier: "Asia/Shanghai"),
        SkyLocation(name: "深圳", latitude: 22.5431, longitude: 114.0579, timeZoneIdentifier: "Asia/Shanghai"),
        SkyLocation(name: "成都", latitude: 30.5728, longitude: 104.0668, timeZoneIdentifier: "Asia/Shanghai"),
        SkyLocation(name: "新加坡", latitude: 1.3521, longitude: 103.8198, timeZoneIdentifier: "Asia/Singapore"),
        SkyLocation(name: "东京", latitude: 35.6762, longitude: 139.6503, timeZoneIdentifier: "Asia/Tokyo"),
        SkyLocation(name: "旧金山", latitude: 37.7749, longitude: -122.4194, timeZoneIdentifier: "America/Los_Angeles"),
        SkyLocation(name: "伦敦", latitude: 51.5074, longitude: -0.1278, timeZoneIdentifier: "Europe/London"),
        SkyLocation(name: "雷克雅未克", latitude: 64.1466, longitude: -21.9426, timeZoneIdentifier: "Atlantic/Reykjavik")
    ]

    public static func defaultForCurrentTimeZone() -> SkyLocation {
        let tz = TimeZone.current
        if tz.identifier == "Asia/Shanghai" || tz.identifier == "Asia/Chongqing" || tz.identifier == "Asia/Beijing" {
            return all[0] // 北京
        }
        let offsetHours = Double(tz.secondsFromGMT()) / 3600.0
        if abs(offsetHours - 8.0) < 0.5 {
            return all[1] // 上海
        }
        let approxLon = max(-180.0, min(180.0, offsetHours * 15.0))
        return SkyLocation(name: "当前时区", latitude: 35.0, longitude: approxLon, timeZoneIdentifier: tz.identifier)
    }
}

public enum DayPhase: String, CaseIterable, Sendable {
    case dawn      // 黎明
    case sunrise   // 日出
    case day       // 白昼
    case sunset    // 日落
    case dusk      // 暮色
    case night     // 星夜

    public var chineseTitle: String {
        switch self {
        case .dawn: return "黎明"
        case .sunrise: return "日出"
        case .day: return "白昼"
        case .sunset: return "日落"
        case .dusk: return "暮色"
        case .night: return "星夜"
        }
    }

    public var symbolName: String {
        switch self {
        case .dawn: return "sun.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .day: return "sun.max.fill"
        case .sunset: return "sunset.fill"
        case .dusk: return "moon.haze.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

public struct SolarPosition: Sendable, Equatable {
    public let elevationDegrees: Double
    public let azimuthDegrees: Double
    public let declinationDegrees: Double
    public let isMorning: Bool
    public let localHour: Double

    public init(
        elevationDegrees: Double,
        azimuthDegrees: Double,
        declinationDegrees: Double,
        isMorning: Bool,
        localHour: Double
    ) {
        self.elevationDegrees = elevationDegrees
        self.azimuthDegrees = azimuthDegrees
        self.declinationDegrees = declinationDegrees
        self.isMorning = isMorning
        self.localHour = localHour
    }
}

public struct MoonPosition: Sendable, Equatable {
    public let elevationDegrees: Double
    public let azimuthDegrees: Double
    public let phaseFraction: Double
    public let illumination: Double

    public init(elevationDegrees: Double, azimuthDegrees: Double, phaseFraction: Double, illumination: Double) {
        self.elevationDegrees = elevationDegrees
        self.azimuthDegrees = azimuthDegrees
        self.phaseFraction = phaseFraction
        self.illumination = illumination
    }
}

public struct DaylightInfo: Sendable, Equatable {
    public let sunriseHour: Double?
    public let sunsetHour: Double?
    public let solarNoonHour: Double
    public let daylightHours: Double

    public init(sunriseHour: Double?, sunsetHour: Double?, solarNoonHour: Double, daylightHours: Double) {
        self.sunriseHour = sunriseHour
        self.sunsetHour = sunsetHour
        self.solarNoonHour = solarNoonHour
        self.daylightHours = daylightHours
    }
}

public struct SkySnapshot: Sendable {
    public let date: Date
    public let location: SkyLocation
    public let solar: SolarPosition
    public let moon: MoonPosition
    public let daylight: DaylightInfo
    public let phase: DayPhase
    public let localSiderealTimeDegrees: Double

    public init(
        date: Date,
        location: SkyLocation,
        solar: SolarPosition,
        moon: MoonPosition,
        daylight: DaylightInfo,
        phase: DayPhase,
        localSiderealTimeDegrees: Double
    ) {
        self.date = date
        self.location = location
        self.solar = solar
        self.moon = moon
        self.daylight = daylight
        self.phase = phase
        self.localSiderealTimeDegrees = localSiderealTimeDegrees
    }
}

public struct TimelineSample: Sendable, Identifiable {
    public let id: Int
    public let hour: Double
    public let elevationDegrees: Double
    public let phase: DayPhase

    public init(id: Int, hour: Double, elevationDegrees: Double, phase: DayPhase) {
        self.id = id
        self.hour = hour
        self.elevationDegrees = elevationDegrees
        self.phase = phase
    }
}

public struct SkySettings: Codable, Equatable, Sendable {
    public var location: SkyLocation
    public var useAutoLocation: Bool
    public var style: SkyStyle
    public var showStars: Bool
    public var showMoon: Bool
    public var starIntensity: Double
    public var ambientWindEnabled: Bool
    public var ambientWindVolume: Double
    public var isWallpaperActive: Bool

    public init(
        location: SkyLocation = CityPreset.defaultForCurrentTimeZone(),
        useAutoLocation: Bool = false,
        style: SkyStyle = .pure,
        showStars: Bool = true,
        showMoon: Bool = false,
        starIntensity: Double = 1.0,
        ambientWindEnabled: Bool = false,
        ambientWindVolume: Double = 0.35,
        isWallpaperActive: Bool = true
    ) {
        self.location = location
        self.useAutoLocation = useAutoLocation
        self.style = style
        self.showStars = showStars
        self.showMoon = showMoon
        self.starIntensity = starIntensity
        self.ambientWindEnabled = ambientWindEnabled
        self.ambientWindVolume = ambientWindVolume
        self.isWallpaperActive = isWallpaperActive
    }

    private static let storageKey = "local.bian.SkyWallpaper.settings.v3"

    public static func load() -> SkySettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SkySettings.self, from: data) else {
            return SkySettings()
        }
        return decoded
    }

    public func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }
}
