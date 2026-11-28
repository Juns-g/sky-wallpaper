import CoreGraphics
import Foundation
import SkyCore
import XCTest

final class AstronomyTests: XCTestCase {
    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tzId: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tzId)!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return cal.date(from: comps)!
    }

    func testBeijingSeasonalDaylight() {
        let beijing = CityPreset.all[0]
        let summer = makeDate(year: 2026, month: 6, day: 21, hour: 12, tzId: "Asia/Shanghai")
        let winter = makeDate(year: 2026, month: 12, day: 21, hour: 12, tzId: "Asia/Shanghai")

        let summerInfo = SolarAstronomy.daylightInfo(date: summer, location: beijing)
        let winterInfo = SolarAstronomy.daylightInfo(date: winter, location: beijing)

        XCTAssertGreaterThan(summerInfo.daylightHours, 14.5)
        XCTAssertLessThan(summerInfo.daylightHours, 15.5)
        XCTAssertGreaterThan(winterInfo.daylightHours, 9.0)
        XCTAssertLessThan(winterInfo.daylightHours, 9.7)

        let summerNoon = SolarAstronomy.solarPosition(date: summer, location: beijing)
        let winterNoon = SolarAstronomy.solarPosition(date: winter, location: beijing)
        XCTAssertGreaterThan(summerNoon.elevationDegrees, 70.0)
        XCTAssertLessThan(winterNoon.elevationDegrees, 30.0)
        XCTAssertGreaterThan(winterNoon.elevationDegrees, 24.0)
    }

    func testMidnightIsNightAndNoonIsDay() {
        let shanghai = CityPreset.all[1]
        let noon = makeDate(year: 2026, month: 11, day: 23, hour: 12, tzId: "Asia/Shanghai")
        let midnight = makeDate(year: 2026, month: 11, day: 23, hour: 0, tzId: "Asia/Shanghai")

        let noonSnap = SolarAstronomy.snapshot(date: noon, location: shanghai)
        let nightSnap = SolarAstronomy.snapshot(date: midnight, location: shanghai)

        XCTAssertEqual(noonSnap.phase, .day)
        XCTAssertEqual(nightSnap.phase, .night)
        XCTAssertGreaterThan(noonSnap.solar.elevationDegrees, 25.0)
        XCTAssertLessThan(nightSnap.solar.elevationDegrees, -25.0)
    }

    func testPolarisAltitudeMatchesLatitude() {
        guard let polaris = StarCatalog.realBrightStars.first(where: { $0.decDegrees > 89.0 }) else {
            XCTFail("Polaris missing from catalog")
            return
        }
        let (alt, az) = StarCatalog.horizontalCoordinates(
            star: polaris,
            latitudeDegrees: 39.9042,
            lstDegrees: 120.0
        )
        XCTAssertEqual(alt, 39.9, accuracy: 1.0)
        let distFromNorth = min(az, 360.0 - az)
        XCTAssertLessThan(distFromNorth, 2.0)
    }

    func testStarsVisibleAtNightAndHiddenAtNoon() {
        let beijing = CityPreset.all[0]
        let noon = makeDate(year: 2026, month: 11, day: 23, hour: 12, tzId: "Asia/Shanghai")
        let night = makeDate(year: 2026, month: 11, day: 23, hour: 22, tzId: "Asia/Shanghai")

        let noonStars = StarCatalog.projectVisibleStars(
            snapshot: SolarAstronomy.snapshot(date: noon, location: beijing),
            aspectRatio: 16.0 / 9.0,
            starIntensity: 1.0
        )
        let nightStars = StarCatalog.projectVisibleStars(
            snapshot: SolarAstronomy.snapshot(date: night, location: beijing),
            aspectRatio: 16.0 / 9.0,
            starIntensity: 1.0
        )

        XCTAssertTrue(noonStars.isEmpty)
        XCTAssertGreaterThan(nightStars.count, 100)
    }

    func testPanoramaLayoutPartitionsThreeDisplaysSeamlessly() {
        // Mirrors real 3-screen setup: MacBook Left (-1512..0), 4K Center (0..1920), 4K Portrait Right (1920..3000)
        let frames = [
            CGRect(x: -1512, y: 0, width: 1512, height: 982),
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: -365, width: 1080, height: 1920)
        ]
        let slices = PanoramaLayout.computeSlices(frames: frames, spanAcrossDisplays: true)
        XCTAssertEqual(slices.count, 3)

        // Left starts at 0, center continues right where left ends, right ends at 1.0
        XCTAssertEqual(slices[0].uvRect.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(slices[0].uvRect.x + slices[0].uvRect.z, slices[1].uvRect.x, accuracy: 0.0001)
        XCTAssertEqual(slices[1].uvRect.x + slices[1].uvRect.z, slices[2].uvRect.x, accuracy: 0.0001)
        XCTAssertEqual(slices[2].uvRect.x + slices[2].uvRect.z, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThan(slices[0].virtualAspect, 3.5)

        // Independent mode gives each display [0, 0, 1, 1]
        let independent = PanoramaLayout.computeSlices(frames: frames, spanAcrossDisplays: false)
        for s in independent {
            XCTAssertEqual(s.uvRect, SIMD4<Float>(0, 0, 1, 1))
        }
    }

    func testPanoramaWithOneEnabledDisplayIsFullScreen() {
        // Two displays connected, one excluded: only the enabled frame is passed in, so it gets the whole sky
        let enabledOnly = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        let slices = PanoramaLayout.computeSlices(frames: enabledOnly, spanAcrossDisplays: true)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices[0], DisplaySlice.fullScreen(aspect: 1920.0 / 1080.0))
    }

    func testSettingsDecodeLegacyJSONWithoutDisabledDisplays() throws {
        let legacy = """
        {"location":{"name":"Tokyo","latitude":35.68,"longitude":139.69,"timeZoneIdentifier":"Asia/Tokyo"},
         "useAutoLocation":true,"style":"STYLE","showStars":false,"showMoon":true,"starIntensity":1.3,
         "ambientMotion":true,"spanAcrossDisplays":false,"liveWeatherEnabled":true,"syncSystemWallpaper":true,
         "syncSystemAppearance":true,"ambientWindEnabled":true,"ambientWindVolume":0.8,"isWallpaperActive":false}
        """
        .replacingOccurrences(of: "STYLE", with: SkyStyle.allCases.last!.rawValue)
        let decoded = try JSONDecoder().decode(SkySettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.disabledDisplayIDs, [])
        XCTAssertEqual(decoded.location.name, "Tokyo")
        XCTAssertEqual(decoded.style, SkyStyle.allCases.last!)
        XCTAssertTrue(decoded.useAutoLocation)
        XCTAssertFalse(decoded.showStars)
        XCTAssertTrue(decoded.showMoon)
        XCTAssertEqual(decoded.starIntensity, 1.3)
        XCTAssertFalse(decoded.spanAcrossDisplays)
        XCTAssertTrue(decoded.syncSystemWallpaper)
        XCTAssertEqual(decoded.ambientWindVolume, 0.8)
        XCTAssertFalse(decoded.isWallpaperActive)

        // Round-trip keeps the new field
        var updated = decoded
        updated.disabledDisplayIDs = ["ABC-123"]
        let again = try JSONDecoder().decode(SkySettings.self, from: JSONEncoder().encode(updated))
        XCTAssertEqual(again, updated)
    }

    func testWeatherWMOMapping() {
        let clear = WeatherState.fromWMO(code: 0, temperatureCelsius: 22, cloudCoverPercent: 5, precipitationMM: 0)
        XCTAssertEqual(clear.condition, .clear)
        XCTAssertEqual(clear.rainIntensity, 0)
        XCTAssertEqual(clear.snowIntensity, 0)

        let rain = WeatherState.fromWMO(code: 63, temperatureCelsius: 14, cloudCoverPercent: 90, precipitationMM: 3.2)
        XCTAssertEqual(rain.condition, .rain)
        XCTAssertGreaterThan(rain.rainIntensity, 0.5)
        XCTAssertEqual(rain.snowIntensity, 0)

        let snow = WeatherState.fromWMO(code: 73, temperatureCelsius: -3, cloudCoverPercent: 85, precipitationMM: 1.5)
        XCTAssertEqual(snow.condition, .snow)
        XCTAssertGreaterThan(snow.snowIntensity, 0.5)
        XCTAssertEqual(snow.rainIntensity, 0)
    }
}
