import Foundation

public enum SolarAstronomy {
    private static let deg2rad = Double.pi / 180.0
    private static let rad2deg = 180.0 / Double.pi

    /// Julian Day from Unix timestamp
    public static func julianDay(from date: Date) -> Double {
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    /// Greenwich Mean Sidereal Time in degrees [0, 360)
    public static func greenwichSiderealTimeDegrees(jd: Double) -> Double {
        let d = jd - 2451545.0
        let t = d / 36525.0
        var gmst = 280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - (t * t * t) / 38710000.0
        gmst = gmst.truncatingRemainder(dividingBy: 360.0)
        if gmst < 0 { gmst += 360.0 }
        return gmst
    }

    /// Local Sidereal Time in degrees [0, 360)
    public static func localSiderealTimeDegrees(date: Date, longitude: Double) -> Double {
        let jd = julianDay(from: date)
        var lst = greenwichSiderealTimeDegrees(jd: jd) + longitude
        lst = lst.truncatingRemainder(dividingBy: 360.0)
        if lst < 0 { lst += 360.0 }
        return lst
    }

    /// NOAA / Meeus solar position calculation
    public static func solarPosition(date: Date, location: SkyLocation) -> SolarPosition {
        let jd = julianDay(from: date)
        let t = (jd - 2451545.0) / 36525.0

        // Geometric mean longitude of Sun (degrees)
        var l0 = 280.46646 + t * (36000.76983 + t * 0.0003032)
        l0 = l0.truncatingRemainder(dividingBy: 360.0)
        if l0 < 0 { l0 += 360.0 }

        // Geometric mean anomaly of Sun (degrees)
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let mRad = m * deg2rad

        // Eccentricity of Earth's orbit
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        // Sun's equation of center (degrees)
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2.0 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3.0 * mRad) * 0.000289

        // Sun true longitude & apparent longitude
        let trueLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = trueLong - 0.00569 - 0.00478 * sin(omega * deg2rad)

        // Mean & corrected obliquity of ecliptic
        let eps0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let eps = eps0 + 0.00256 * cos(omega * deg2rad)

        let lambdaRad = lambda * deg2rad
        let epsRad = eps * deg2rad

        // Declination
        let sinDec = sin(epsRad) * sin(lambdaRad)
        let decRad = asin(max(-1.0, min(1.0, sinDec)))
        let decDeg = decRad * rad2deg

        // Equation of time (minutes)
        let y = pow(tan(epsRad / 2.0), 2.0)
        let l0Rad = l0 * deg2rad
        let eqTime = 4.0 * rad2deg * (
            y * sin(2.0 * l0Rad)
            - 2.0 * e * sin(mRad)
            + 4.0 * e * y * sin(mRad) * cos(2.0 * l0Rad)
            - 0.5 * y * y * sin(4.0 * l0Rad)
            - 1.25 * e * e * sin(2.0 * mRad)
        )

        // UTC minutes since midnight
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcComps = utcCal.dateComponents([.hour, .minute, .second], from: date)
        let utcMinutes = Double(utcComps.hour ?? 0) * 60.0
            + Double(utcComps.minute ?? 0)
            + Double(utcComps.second ?? 0) / 60.0

        // True solar time (minutes)
        var tst = utcMinutes + eqTime + 4.0 * location.longitude
        tst = tst.truncatingRemainder(dividingBy: 1440.0)
        if tst < 0 { tst += 1440.0 }

        // Hour angle (degrees): -180..+180 (negative in morning, positive in afternoon)
        let hourAngleDeg = tst / 4.0 - 180.0
        let haRad = hourAngleDeg * deg2rad
        let latRad = location.latitude * deg2rad

        // Zenith & elevation
        let cosZenith = max(-1.0, min(1.0,
            sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        ))
        let zenithRad = acos(cosZenith)
        let elevationRaw = 90.0 - zenithRad * rad2deg

        // Atmospheric refraction near horizon
        let refraction: Double
        if elevationRaw > 85.0 {
            refraction = 0.0
        } else if elevationRaw > 5.0 {
            let te = tan(elevationRaw * deg2rad)
            refraction = (58.1 / te - 0.07 / pow(te, 3) + 0.000086 / pow(te, 5)) / 3600.0
        } else if elevationRaw > -0.575 {
            refraction = (1735.0 + elevationRaw * (-518.2 + elevationRaw * (103.4 + elevationRaw * (-12.79 + elevationRaw * 0.711)))) / 3600.0
        } else {
            refraction = -20.774 / tan(elevationRaw * deg2rad) / 3600.0
        }
        let elevation = elevationRaw + (elevationRaw > -2.0 ? refraction : 0.0)

        // Azimuth (degrees clockwise from North)
        let sinZenith = sin(zenithRad)
        let azimuth: Double
        if abs(sinZenith) < 1e-6 {
            azimuth = 180.0
        } else {
            let cosAz = max(-1.0, min(1.0,
                (sin(decRad) - sin(latRad) * cosZenith) / (cos(latRad) * sinZenith)
            ))
            let azDeg = acos(cosAz) * rad2deg
            azimuth = hourAngleDeg > 0 ? (360.0 - azDeg) : azDeg
        }

        // Local hour
        let localHour = localHourOfDay(date: date, timeZone: location.timeZone)

        return SolarPosition(
            elevationDegrees: elevation,
            azimuthDegrees: azimuth,
            declinationDegrees: decDeg,
            isMorning: hourAngleDeg <= 0.0,
            localHour: localHour
        )
    }

    /// Approximate Moon position & phase (Meeus simplified)
    public static func moonPosition(date: Date, location: SkyLocation) -> MoonPosition {
        let jd = julianDay(from: date)
        let d = jd - 2451545.0

        // Ecliptic longitude, mean anomaly, mean distance
        let l = (218.316 + 13.176396 * d) * deg2rad
        let m = (134.963 + 13.064993 * d) * deg2rad
        let f = (93.272 + 13.229350 * d) * deg2rad

        let lon = l + 6.289 * deg2rad * sin(m)
        let lat = 5.128 * deg2rad * sin(f)
        let eps = 23.4397 * deg2rad

        let ra = atan2(sin(lon) * cos(eps) - tan(lat) * sin(eps), cos(lon))
        let dec = asin(max(-1.0, min(1.0, sin(lat) * cos(eps) + cos(lat) * sin(eps) * sin(lon))))

        let lst = localSiderealTimeDegrees(date: date, longitude: location.longitude) * deg2rad
        let ha = lst - ra
        let phi = location.latitude * deg2rad

        let sinAlt = max(-1.0, min(1.0, sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(ha)))
        let alt = asin(sinAlt)
        let cosAz = max(-1.0, min(1.0, (sin(dec) - sin(phi) * sinAlt) / max(1e-6, cos(phi) * cos(alt))))
        var az = acos(cosAz) * rad2deg
        if sin(ha) > 0 { az = 360.0 - az }

        // Synodic phase (reference new moon: JD 2451550.1)
        let synodicMonth = 29.530588853
        var phase = ((jd - 2451550.1) / synodicMonth).truncatingRemainder(dividingBy: 1.0)
        if phase < 0 { phase += 1.0 }
        let illumination = 0.5 * (1.0 - cos(2.0 * Double.pi * phase))

        return MoonPosition(
            elevationDegrees: alt * rad2deg,
            azimuthDegrees: az,
            phaseFraction: phase,
            illumination: illumination
        )
    }

    /// Compute sunrise, sunset, solar noon, and daylight duration for the local calendar day of `date`
    public static func daylightInfo(date: Date, location: SkyLocation) -> DaylightInfo {
        let tz = location.timeZone
        let startOfDay = startOfLocalDay(for: date, timeZone: tz)
        // Compute solar noon and declination at local noon
        let noonDate = startOfDay.addingTimeInterval(12.0 * 3600.0)
        let jd = julianDay(from: noonDate)
        let t = (jd - 2451545.0) / 36525.0

        var l0 = 280.46646 + t * (36000.76983 + t * 0.0003032)
        l0 = l0.truncatingRemainder(dividingBy: 360.0)
        if l0 < 0 { l0 += 360.0 }
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let mRad = m * deg2rad
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2.0 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3.0 * mRad) * 0.000289
        let omega = 125.04 - 1934.136 * t
        let lambda = (l0 + c) - 0.00569 - 0.00478 * sin(omega * deg2rad)
        let eps0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let eps = (eps0 + 0.00256 * cos(omega * deg2rad)) * deg2rad
        let decRad = asin(max(-1.0, min(1.0, sin(eps) * sin(lambda * deg2rad))))

        let y = pow(tan(eps / 2.0), 2.0)
        let l0Rad = l0 * deg2rad
        let eqTime = 4.0 * rad2deg * (
            y * sin(2.0 * l0Rad)
            - 2.0 * e * sin(mRad)
            + 4.0 * e * y * sin(mRad) * cos(2.0 * l0Rad)
            - 0.5 * y * y * sin(4.0 * l0Rad)
            - 1.25 * e * e * sin(2.0 * mRad)
        )

        let tzOffsetHours = Double(tz.secondsFromGMT(for: noonDate)) / 3600.0
        let solarNoonMinutes = 720.0 - 4.0 * location.longitude - eqTime + tzOffsetHours * 60.0
        let solarNoonHour = solarNoonMinutes / 60.0

        let latRad = location.latitude * deg2rad
        let zenithRad = 90.833 * deg2rad // standard sunrise/sunset zenith including refraction
        let cosHA = (cos(zenithRad) / (cos(latRad) * cos(decRad))) - tan(latRad) * tan(decRad)

        if cosHA > 1.0 {
            // Polar night
            return DaylightInfo(sunriseHour: nil, sunsetHour: nil, solarNoonHour: solarNoonHour, daylightHours: 0.0)
        } else if cosHA < -1.0 {
            // Midnight sun
            return DaylightInfo(sunriseHour: nil, sunsetHour: nil, solarNoonHour: solarNoonHour, daylightHours: 24.0)
        }

        let haDeg = acos(cosHA) * rad2deg
        let halfDayMinutes = haDeg * 4.0
        let sunriseHour = (solarNoonMinutes - halfDayMinutes) / 60.0
        let sunsetHour = (solarNoonMinutes + halfDayMinutes) / 60.0
        let daylightHours = (halfDayMinutes * 2.0) / 60.0

        return DaylightInfo(
            sunriseHour: sunriseHour,
            sunsetHour: sunsetHour,
            solarNoonHour: solarNoonHour,
            daylightHours: daylightHours
        )
    }

    public static func classifyPhase(elevation: Double, isMorning: Bool) -> DayPhase {
        if elevation <= -10.5 {
            return .night
        } else if elevation <= -0.8 {
            return isMorning ? .dawn : .dusk
        } else if elevation <= 9.0 {
            return isMorning ? .sunrise : .sunset
        } else {
            return .day
        }
    }

    public static func snapshot(date: Date, location: SkyLocation) -> SkySnapshot {
        let solar = solarPosition(date: date, location: location)
        let moon = moonPosition(date: date, location: location)
        let daylight = daylightInfo(date: date, location: location)
        let phase = classifyPhase(elevation: solar.elevationDegrees, isMorning: solar.isMorning)
        let lst = localSiderealTimeDegrees(date: date, longitude: location.longitude)
        return SkySnapshot(
            date: date,
            location: location,
            solar: solar,
            moon: moon,
            daylight: daylight,
            phase: phase,
            localSiderealTimeDegrees: lst
        )
    }

    /// Sample 49 points across the local 24h day (every 30 min) for the menu bar arc timeline
    public static func timelineSamples(for date: Date, location: SkyLocation, steps: Int = 48) -> [TimelineSample] {
        let start = startOfLocalDay(for: date, timeZone: location.timeZone)
        return (0...steps).map { idx in
            let hour = Double(idx) * (24.0 / Double(steps))
            let sampleDate = start.addingTimeInterval(hour * 3600.0)
            let solar = solarPosition(date: sampleDate, location: location)
            let phase = classifyPhase(elevation: solar.elevationDegrees, isMorning: solar.isMorning)
            return TimelineSample(id: idx, hour: hour, elevationDegrees: solar.elevationDegrees, phase: phase)
        }
    }

    public static func startOfLocalDay(for date: Date, timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.startOfDay(for: date)
    }

    public static func localHourOfDay(date: Date, timeZone: TimeZone) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        return Double(comps.hour ?? 0)
            + Double(comps.minute ?? 0) / 60.0
            + Double(comps.second ?? 0) / 3600.0
    }

    public static func formatHour(_ hour: Double) -> String {
        let wrapped = ((hour.truncatingRemainder(dividingBy: 24.0)) + 24.0).truncatingRemainder(dividingBy: 24.0)
        let totalMinutes = Int((wrapped * 60.0).rounded()) % 1440
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}
