import CoreLocation
import Foundation
import SkyCore

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var onLocationUpdated: ((SkyLocation) -> Void)?
    var onStatusMessage: ((String?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestCurrentLocation() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            onStatusMessage?("请在系统弹窗中允许定位权限…")
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            onStatusMessage?("正在获取当前位置…")
            manager.requestLocation()
        case .denied, .restricted:
            onStatusMessage?("未授予定位权限，可在系统设置 → 隐私与安全性 → 定位服务中开启")
        @unknown default:
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorized || status == .authorizedAlways {
                self.onStatusMessage?("正在获取当前位置…")
                self.manager.requestLocation()
            } else if status == .denied || status == .restricted {
                self.onStatusMessage?("定位权限被拒绝，已保持手动城市")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let fallback = SkyLocation(
                name: "当前位置",
                latitude: lat,
                longitude: lon,
                timeZoneIdentifier: TimeZone.current.identifier
            )
            self.onLocationUpdated?(fallback)
            self.onStatusMessage?(nil)

            self.geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
                guard let placemark = placemarks?.first else { return }
                let city = placemark.locality ?? placemark.administrativeArea ?? placemark.name ?? "当前位置"
                let tzId = placemark.timeZone?.identifier ?? TimeZone.current.identifier
                Task { @MainActor in
                    self?.onLocationUpdated?(SkyLocation(
                        name: city,
                        latitude: lat,
                        longitude: lon,
                        timeZoneIdentifier: tzId
                    ))
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.onStatusMessage?("定位失败，可先手动选择城市")
        }
    }
}
