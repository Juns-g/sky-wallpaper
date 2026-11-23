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

        // Beijing summer solstice ~15h daylight, winter solstice ~9.3h daylight
        XCTAssertGreaterThan(summerInfo.daylightHours, 14.5)
        XCTAssertLessThan(summerInfo.daylightHours, 15.5)
        XCTAssertGreaterThan(winterInfo.daylightHours, 9.0)
        XCTAssertLessThan(winterInfo.daylightHours, 9.7)

        // Solar elevation much higher in June than December
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
        // Polaris is at Dec +89.26°, so its altitude in Beijing (39.9°N) must be ~39.9° ± 1°
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
        // Polaris should be near North (azimuth ~0° or ~360°)
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
}
