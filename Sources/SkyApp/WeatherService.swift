import Foundation
import SkyCore

/// Lightweight zero-API-key live weather client powered by Open-Meteo
@MainActor
final class WeatherService {
    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let cloud_cover: Double
            let precipitation: Double
        }
        let current: Current
    }

    private let session: URLSession
    private var inFlightTask: Task<Void, Never>?

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        self.session = URLSession(configuration: config)
    }

    func fetch(for location: SkyLocation, completion: @escaping @MainActor (Result<WeatherState, Error>) -> Void) {
        inFlightTask?.cancel()
        let lat = String(format: "%.4f", location.latitude)
        let lon = String(format: "%.4f", location.longitude)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,cloud_cover,precipitation"

        guard let url = URL(string: urlString) else { return }

        inFlightTask = Task { [session] in
            do {
                let (data, response) = try await session.data(from: url)
                try Task.checkCancellation()
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw NSError(domain: "WeatherService", code: http.statusCode, userInfo: nil)
                }
                let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let state = WeatherState.fromWMO(
                    code: decoded.current.weather_code,
                    temperatureCelsius: decoded.current.temperature_2m,
                    cloudCoverPercent: decoded.current.cloud_cover,
                    precipitationMM: decoded.current.precipitation
                )
                await MainActor.run {
                    completion(.success(state))
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    func cancel() {
        inFlightTask?.cancel()
    }
}
