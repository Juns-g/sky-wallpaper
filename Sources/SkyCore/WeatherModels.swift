import Foundation

public enum WeatherConditionKind: String, Codable, Sendable, Equatable {
    case clear
    case partlyCloudy
    case overcast
    case fog
    case rain
    case snow

    public var chineseTitle: String {
        switch self {
        case .clear: return "晴"
        case .partlyCloudy: return "多云"
        case .overcast: return "阴"
        case .fog: return "雾"
        case .rain: return "雨"
        case .snow: return "雪"
        }
    }

    public var symbolName: String {
        switch self {
        case .clear: return "sun.max"
        case .partlyCloudy: return "cloud.sun"
        case .overcast: return "cloud"
        case .fog: return "cloud.fog"
        case .rain: return "cloud.rain"
        case .snow: return "cloud.snow"
        }
    }
}

public struct WeatherState: Codable, Sendable, Equatable {
    public let condition: WeatherConditionKind
    public let temperatureCelsius: Double
    /// 0.0 (clear) .. 1.0 (fully overcast)
    public let cloudCover: Double
    /// 0.0 .. 1.0 normalized rain intensity
    public let rainIntensity: Double
    /// 0.0 .. 1.0 normalized snow intensity
    public let snowIntensity: Double
    public let updatedAt: Date

    public init(
        condition: WeatherConditionKind,
        temperatureCelsius: Double,
        cloudCover: Double,
        rainIntensity: Double,
        snowIntensity: Double,
        updatedAt: Date = Date()
    ) {
        self.condition = condition
        self.temperatureCelsius = temperatureCelsius
        self.cloudCover = max(0, min(1, cloudCover))
        self.rainIntensity = max(0, min(1, rainIntensity))
        self.snowIntensity = max(0, min(1, snowIntensity))
        self.updatedAt = updatedAt
    }

    public var shortBadge: String {
        "\(Int(temperatureCelsius.rounded()))°C \(condition.chineseTitle)"
    }

    public static let none = WeatherState(
        condition: .clear,
        temperatureCelsius: 20,
        cloudCover: 0,
        rainIntensity: 0,
        snowIntensity: 0
    )

    /// Map WMO weather interpretation code (Open-Meteo standard) into rendering parameters
    public static func fromWMO(
        code: Int,
        temperatureCelsius: Double,
        cloudCoverPercent: Double,
        precipitationMM: Double,
        updatedAt: Date = Date()
    ) -> WeatherState {
        let cc = max(0.0, min(1.0, cloudCoverPercent / 100.0))
        let precipBoost = min(1.0, max(0.28, precipitationMM / 4.0))

        switch code {
        case 0, 1:
            return WeatherState(
                condition: .clear,
                temperatureCelsius: temperatureCelsius,
                cloudCover: cc * 0.25,
                rainIntensity: 0,
                snowIntensity: 0,
                updatedAt: updatedAt
            )
        case 2:
            return WeatherState(
                condition: .partlyCloudy,
                temperatureCelsius: temperatureCelsius,
                cloudCover: max(0.35, cc * 0.75),
                rainIntensity: 0,
                snowIntensity: 0,
                updatedAt: updatedAt
            )
        case 3:
            return WeatherState(
                condition: .overcast,
                temperatureCelsius: temperatureCelsius,
                cloudCover: max(0.75, cc),
                rainIntensity: 0,
                snowIntensity: 0,
                updatedAt: updatedAt
            )
        case 45, 48:
            return WeatherState(
                condition: .fog,
                temperatureCelsius: temperatureCelsius,
                cloudCover: max(0.65, cc),
                rainIntensity: 0,
                snowIntensity: 0,
                updatedAt: updatedAt
            )
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99:
            let heavy = (code == 65 || code == 82 || code >= 95) ? 0.92 : (code == 63 || code == 81 ? 0.65 : 0.42)
            return WeatherState(
                condition: .rain,
                temperatureCelsius: temperatureCelsius,
                cloudCover: max(0.70, cc),
                rainIntensity: max(heavy, precipBoost),
                snowIntensity: 0,
                updatedAt: updatedAt
            )
        case 71, 73, 75, 77, 85, 86:
            let heavy = (code == 75 || code == 86) ? 0.92 : (code == 73 ? 0.65 : 0.45)
            return WeatherState(
                condition: .snow,
                temperatureCelsius: temperatureCelsius,
                cloudCover: max(0.60, cc),
                rainIntensity: 0,
                snowIntensity: max(heavy, precipBoost),
                updatedAt: updatedAt
            )
        default:
            return WeatherState(
                condition: cc > 0.65 ? .overcast : (cc > 0.25 ? .partlyCloudy : .clear),
                temperatureCelsius: temperatureCelsius,
                cloudCover: cc,
                rainIntensity: 0,
                snowIntensity: 0,
                updatedAt: updatedAt
            )
        }
    }
}
