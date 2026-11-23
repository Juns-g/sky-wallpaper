import Foundation
import simd

public struct CelestialStar: Sendable {
    public let raDegrees: Double
    public let decDegrees: Double
    public let magnitude: Float
    public let bvIndex: Float
    public let twinkleSeed: Float
    public let isMilkyWayCluster: Bool

    public init(
        raHours: Double,
        decDegrees: Double,
        magnitude: Float,
        bvIndex: Float,
        twinkleSeed: Float,
        isMilkyWayCluster: Bool = false
    ) {
        self.raDegrees = raHours * 15.0
        self.decDegrees = decDegrees
        self.magnitude = magnitude
        self.bvIndex = bvIndex
        self.twinkleSeed = twinkleSeed
        self.isMilkyWayCluster = isMilkyWayCluster
    }

    public init(
        raDegrees: Double,
        decDegrees: Double,
        magnitude: Float,
        bvIndex: Float,
        twinkleSeed: Float,
        isMilkyWayCluster: Bool = false
    ) {
        self.raDegrees = raDegrees
        self.decDegrees = decDegrees
        self.magnitude = magnitude
        self.bvIndex = bvIndex
        self.twinkleSeed = twinkleSeed
        self.isMilkyWayCluster = isMilkyWayCluster
    }
}

public struct ProjectedStar: Sendable {
    public let position: SIMD2<Float>
    public let color: SIMD3<Float>
    public let brightness: Float
    public let size: Float
    public let twinkleSeed: Float

    public init(
        position: SIMD2<Float>,
        color: SIMD3<Float>,
        brightness: Float,
        size: Float,
        twinkleSeed: Float
    ) {
        self.position = position
        self.color = color
        self.brightness = brightness
        self.size = size
        self.twinkleSeed = twinkleSeed
    }
}

public enum StarCatalog {
    /// Curated real bright stars & recognizable constellations (J2000 RA in hours, Dec in degrees, Vmag, B-V)
    public static let realBrightStars: [CelestialStar] = {
        let raw: [(Double, Double, Float, Float)] = [
            (6.7525, -16.7161, -1.46, 0.00),  // Sirius
            (6.3992, -52.6957, -0.74, 0.15),  // Canopus
            (14.2610, 19.1824, -0.05, 1.23),  // Arcturus
            (14.6601, -60.8339, -0.01, 0.71), // Rigil Kentaurus
            (18.6156, 38.7837, 0.03, 0.00),   // Vega
            (5.2782, 45.9980, 0.08, 0.80),    // Capella
            (5.2423, -8.2016, 0.13, -0.03),   // Rigel
            (7.6550, 5.2250, 0.34, 0.42),     // Procyon
            (1.6286, -57.2367, 0.46, -0.16),  // Achernar
            (5.9195, 7.4071, 0.50, 1.85),     // Betelgeuse
            (14.0637, -60.3730, 0.61, -0.23), // Hadar
            (19.8464, 8.8683, 0.76, 0.22),    // Altair
            (12.4433, -63.0991, 0.77, -0.24), // Acrux
            (4.5987, 16.5093, 0.86, 1.54),    // Aldebaran
            (16.4901, -26.4320, 0.96, 1.83),  // Antares
            (13.4199, -11.1613, 0.97, -0.23), // Spica
            (7.7553, 28.0262, 1.14, 1.00),    // Pollux
            (22.9608, -29.6222, 1.16, 0.09),  // Fomalhaut
            (20.6905, 45.2803, 1.25, 0.09),   // Deneb
            (12.7953, -59.6888, 1.25, -0.23), // Mimosa
            (10.1395, 11.9672, 1.35, -0.11),  // Regulus
            (6.9771, -28.9721, 1.50, -0.21),  // Adhara
            (7.5767, 31.8883, 1.58, 0.03),    // Castor
            (17.5601, -37.1038, 1.62, -0.22), // Shaula
            (5.4189, 6.3497, 1.64, -0.22),    // Bellatrix
            (5.4382, 28.6074, 1.65, -0.13),   // Elnath
            (9.2200, -69.7172, 1.67, 0.00),   // Miaplacidus
            (5.6036, -1.2019, 1.69, -0.18),   // Alnilam (Orion belt)
            (12.5194, -57.1132, 1.63, 1.59),  // Gacrux
            (22.1372, -46.9610, 1.74, -0.13), // Alnair
            (12.9005, 55.9598, 1.77, -0.02),  // Alioth (Big Dipper)
            (5.6793, -1.9426, 1.77, -0.21),   // Alnitak (Orion belt)
            (11.0621, 61.7510, 1.79, 1.07),   // Dubhe (Big Dipper)
            (3.4054, 49.8612, 1.79, 0.48),    // Mirfak
            (6.3783, -17.9559, 1.98, -0.24),  // Mirzam
            (13.7923, 49.3133, 1.86, -0.19),  // Alkaid (Big Dipper)
            (18.4029, -34.3846, 1.85, -0.03), // Kaus Australis
            (5.9921, 44.9474, 1.90, 0.03),    // Menkalinan
            (16.8111, -69.0277, 1.92, 1.44),  // Atria
            (6.6285, 16.3993, 1.93, 0.00),    // Alhena
            (2.5302, 89.2641, 1.98, 0.60),    // Polaris
            (9.4598, -8.6586, 1.98, 1.44),    // Alphard
            (2.1196, 23.4624, 2.00, 1.15),    // Hamal
            (0.7265, -17.9866, 2.04, 1.02),   // Diphda
            (10.3329, 19.8415, 2.01, 1.15),   // Algieba
            (0.1398, 29.0904, 2.06, -0.11),   // Alpheratz
            (1.1622, 35.6206, 2.05, 1.58),    // Mirach
            (5.7959, -9.6696, 2.06, -0.18),   // Saiph
            (14.8451, 74.1555, 2.08, 1.47),   // Kochab
            (17.5822, 12.5600, 2.08, 0.15),   // Rasalhague
            (3.1361, 40.9556, 2.12, -0.05),   // Algol
            (11.8177, 14.5721, 2.14, 0.09),   // Denebola
            (20.3705, 40.2567, 2.20, 0.68),   // Sadr (Cygnus)
            (13.3987, 54.9254, 2.23, 0.02),   // Mizar (Big Dipper)
            (15.5781, 26.7147, 2.23, -0.02),  // Alphecca
            (5.5334, -0.2991, 2.23, -0.22),   // Mintaka (Orion belt)
            (0.6751, 56.5373, 2.23, 1.17),    // Schedar (Cassiopeia)
            (17.9434, 51.4889, 2.23, 1.52),   // Eltanin
            (0.1529, 59.1498, 2.27, 0.34),    // Caph (Cassiopeia)
            (0.9451, 60.7167, 2.15, -0.15),   // Gamma Cassiopeiae
            (11.0307, 56.3824, 2.37, -0.02),  // Merak (Big Dipper)
            (11.8972, 53.6948, 2.44, 0.00),   // Phecda (Big Dipper)
            (12.2571, 57.0326, 3.31, 0.08),   // Megrez (Big Dipper)
            (1.4303, 60.2353, 2.68, 0.13),    // Ruchbah (Cassiopeia)
            (1.9066, 63.6701, 3.38, -0.15),   // Segin (Cassiopeia)
            (21.7364, 9.8750, 2.39, 1.52),    // Enif
            (23.0629, 28.0828, 2.42, 1.67),   // Scheat (Pegasus)
            (23.0793, 15.2053, 2.49, -0.04),  // Markab (Pegasus)
            (0.2206, 15.1836, 2.83, -0.23),   // Algenib (Pegasus)
            (20.7702, 33.9703, 2.46, 1.03),   // Gienah Cygni
            (19.5120, 27.9597, 3.08, 1.13),   // Albireo
            (19.7496, 45.1308, 2.87, -0.03),  // Fawaris (Cygnus)
            (14.7498, 27.0742, 2.37, 0.97),   // Izar
            (13.9114, 18.3977, 2.68, 0.58),   // Muphrid
            (16.0055, -22.6217, 2.32, -0.12), // Dschubba
            (16.0906, -19.8055, 2.62, -0.07), // Acrab
            (16.8361, -34.2932, 2.29, 1.15),  // Epsilon Scorpii
            (17.6220, -42.9978, 1.87, 0.40),  // Sargas
            (18.9211, -26.2967, 2.02, -0.20), // Nunki
            (18.4666, -25.4217, 2.81, 1.04),  // Kaus Borealis
            (18.3499, -29.8281, 2.70, 1.38),  // Kaus Media
            (19.0435, -29.8801, 2.60, 0.08),  // Ascella
            (11.2351, 20.5237, 2.56, 0.12),   // Zosma
            (9.8793, 26.0070, 2.98, 0.80),    // Rasalas
            (3.7914, 24.1051, 2.87, -0.09),   // Alcyone (Pleiades)
            (4.4769, 19.1804, 3.53, 0.99),    // Ain (Hyades)
            (5.6274, 21.1425, 3.00, -0.19),   // Tianguan
            (6.3827, 22.5136, 2.88, 1.64),    // Tejat
            (6.6285, 25.1311, 2.98, 0.80),    // Mebsuta
            (7.3357, 21.9823, 3.53, 0.34),    // Wasat
            (15.2834, -9.3829, 2.61, -0.11),  // Zubeneschamali
            (14.8480, -16.0418, 2.75, 0.15),  // Zubenelgenubi
            (12.2634, -17.5419, 2.59, -0.11), // Gienah Corvi
            (12.5733, -23.3968, 2.65, 0.89),  // Kraz
            (16.5038, 21.4896, 2.77, 0.94),   // Kornephoros
            (16.7149, 31.6027, 2.81, 0.65),   // Zeta Herculis
            (17.2441, 14.3903, 3.06, 1.44),   // Rasalgethi
            (18.9156, 33.3627, 3.24, 0.00),   // Sulafat (Lyra)
            (18.8347, 32.6896, 3.52, 0.00),   // Sheliak (Lyra)
            (19.7710, 10.6133, 2.72, 1.52),   // Tarazed
            (19.9219, 6.4068, 3.71, 0.86),    // Alshain
            (21.3096, 62.5856, 2.44, 0.22),   // Alderamin (Cepheus)
            (23.6558, 77.6323, 3.21, 1.03),   // Errai
            (21.4777, 70.5607, 3.23, -0.22),  // Alfirk
            (2.0650, 42.3297, 2.10, 1.21),    // Almach
            (1.8841, 29.5788, 3.41, 0.49),    // Mothallah
            (2.7196, 27.2605, 3.00, 0.13),    // Sheratan
            (3.0379, 4.0897, 2.53, 1.64),     // Menkar
            (2.3224, -2.9776, 3.04, 1.42),    // Mira
            (3.9672, -13.5085, 2.95, 1.59),   // Zaurak
            (5.1308, -5.0864, 2.79, 0.13),    // Cursa
            (8.7453, -54.7088, 1.96, 0.04),   // Alsephina
            (9.1333, -43.4326, 2.21, 1.66),   // Suhail
            (8.1589, -47.3366, 1.83, -0.22),  // Regor
            (8.0597, -40.0031, 2.25, -0.27),  // Naos
            (9.2856, -59.2752, 2.26, 0.18),   // Aspidiske
            (15.7378, 6.4256, 2.65, 1.17),    // Unukalhai
            (17.1730, -15.7249, 2.43, 0.06),  // Sabik
            (16.2389, -3.6943, 2.74, 1.58),   // Yed Prior
            (22.0964, -0.3199, 2.96, 0.98),   // Sadalmelik
            (21.5260, -5.5712, 2.91, 0.83),   // Sadalsuud
            (20.3502, -14.7815, 3.08, 0.79),  // Dabih
            (21.7840, -16.1273, 2.87, 0.29),  // Deneb Algedi
            (14.0732, 64.3758, 3.65, 1.40),   // Thuban
            (17.5072, 52.3014, 2.79, 0.98),   // Rastaban
            (16.3999, 61.5142, 2.74, 0.91),   // Athebyne
            (12.9338, 38.3184, 2.90, -0.12),  // Cor Caroli
            (15.3456, 71.8340, 3.05, 0.05),   // Pherkad
            (4.9499, 33.1661, 2.69, 1.53)     // Hassaleh
        ]

        return raw.enumerated().map { idx, item in
            CelestialStar(
                raHours: item.0,
                decDegrees: item.1,
                magnitude: item.2,
                bvIndex: item.3,
                twinkleSeed: Float(idx) * 1.6180339
            )
        }
    }()

    /// Combined catalog: real named stars + crisp 4K faint celestial field + authentic galactic-plane Milky Way pinpoint clusters
    public static let allStars: [CelestialStar] = {
        var result = realBrightStars
        result.reserveCapacity(2600)

        var state: UInt64 = 0x5EED_C0DE_2026_54A7
        func nextUnit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 11) & 0x1F_FFFF_FFFF_FFFF) / Double(1 << 53)
        }

        // 1,650 crisp pinpoint background stars uniformly across the celestial sphere
        for i in 0..<1650 {
            let raDeg = nextUnit() * 360.0
            let u = nextUnit() * 2.0 - 1.0
            let decDeg = asin(max(-1.0, min(1.0, u))) * 180.0 / Double.pi
            let mRand = nextUnit()
            let mag = Float(2.85 + pow(mRand, 0.58) * 3.15) // 2.85 .. 6.0
            let bv = Float(-0.22 + nextUnit() * 1.5)
            let seed = Float(i + 200) * 2.3999632
            result.append(CelestialStar(
                raDegrees: raDeg,
                decDegrees: decDeg,
                magnitude: mag,
                bvIndex: bv,
                twinkleSeed: seed
            ))
        }

        // 800 fine pinpoint Milky Way stars along the real J2000 Galactic plane
        // North Galactic Pole: RA = 192.8595°, Dec = +27.1283°
        let ngpRA = 192.8595 * Double.pi / 180.0
        let ngpDec = 27.1283 * Double.pi / 180.0
        let lNCP = 122.9319 * Double.pi / 180.0

        for i in 0..<800 {
            let lDeg = nextUnit() * 360.0
            // Gaussian-like concentration near galactic equator (b within ±14°)
            let g1 = nextUnit() + nextUnit() + nextUnit() - 1.5
            let bDeg = g1 * 9.5
            let l = lDeg * Double.pi / 180.0
            let b = bDeg * Double.pi / 180.0

            // Galactic (l, b) -> Equatorial (RA, Dec)
            let sinDec = sin(b) * sin(ngpDec) + cos(b) * cos(ngpDec) * cos(lNCP - l)
            let decRad = asin(max(-1.0, min(1.0, sinDec)))
            let y = cos(b) * sin(lNCP - l)
            let x = sin(b) * cos(ngpDec) - cos(b) * sin(ngpDec) * cos(lNCP - l)
            var raDeg = (ngpRA + atan2(y, x)) * 180.0 / Double.pi
            raDeg = raDeg.truncatingRemainder(dividingBy: 360.0)
            if raDeg < 0 { raDeg += 360.0 }

            let mag = Float(3.8 + pow(nextUnit(), 0.5) * 2.4)
            let bv = Float(-0.18 + nextUnit() * 0.95)
            result.append(CelestialStar(
                raDegrees: raDeg,
                decDegrees: decRad * 180.0 / Double.pi,
                magnitude: mag,
                bvIndex: bv,
                twinkleSeed: Float(i + 2000) * 1.73205,
                isMilkyWayCluster: true
            ))
        }

        return result
    }()

    public static func color(forBV bv: Float) -> SIMD3<Float> {
        let clamped = max(-0.35, min(2.0, bv))
        let rgb: SIMD3<Float>
        if clamped < 0.0 {
            let t = (clamped + 0.35) / 0.35
            rgb = mix(SIMD3<Float>(0.68, 0.82, 1.00), SIMD3<Float>(0.90, 0.94, 1.00), t: t)
        } else if clamped < 0.4 {
            let t = clamped / 0.4
            rgb = mix(SIMD3<Float>(0.90, 0.94, 1.00), SIMD3<Float>(1.00, 0.98, 0.95), t: t)
        } else if clamped < 1.0 {
            let t = (clamped - 0.4) / 0.6
            rgb = mix(SIMD3<Float>(1.00, 0.98, 0.95), SIMD3<Float>(1.00, 0.88, 0.70), t: t)
        } else {
            let t = (clamped - 1.0) / 1.0
            rgb = mix(SIMD3<Float>(1.00, 0.88, 0.70), SIMD3<Float>(1.00, 0.68, 0.42), t: t)
        }
        return mix(rgb, SIMD3<Float>(1.0, 1.0, 1.0), t: 0.22)
    }

    public static func horizontalCoordinates(
        star: CelestialStar,
        latitudeDegrees: Double,
        lstDegrees: Double
    ) -> (altitudeDegrees: Double, azimuthDegrees: Double) {
        let deg2rad = Double.pi / 180.0
        let rad2deg = 180.0 / Double.pi

        let phi = latitudeDegrees * deg2rad
        let dec = star.decDegrees * deg2rad
        let ha = (lstDegrees - star.raDegrees) * deg2rad

        let sinAlt = max(-1.0, min(1.0, sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(ha)))
        let alt = asin(sinAlt)
        let cosAlt = cos(alt)
        let az: Double
        if abs(cosAlt) < 1e-6 {
            az = 0.0
        } else {
            let cosAz = max(-1.0, min(1.0, (sin(dec) - sin(phi) * sinAlt) / max(1e-6, cos(phi) * cosAlt)))
            var azDeg = acos(cosAz) * rad2deg
            if sin(ha) > 0 { azDeg = 360.0 - azDeg }
            az = azDeg
        }
        return (alt * rad2deg, az)
    }

    public static func projectVisibleStars(
        snapshot: SkySnapshot,
        aspectRatio: Double,
        starIntensity: Double,
        style: SkyStyle = .pure
    ) -> [ProjectedStar] {
        let sunElev = snapshot.solar.elevationDegrees
        let twilightFade = smoothstep(edge0: -1.2, edge1: -11.0, x: sunElev)
        if twilightFade <= 0.002 || starIntensity <= 0.001 {
            return []
        }

        let lat = snapshot.location.latitude
        let lst = snapshot.localSiderealTimeDegrees
        let viewCenterAz = lat >= 0.0 ? 180.0 : 0.0
        let halfHFOV = max(68.0, min(92.0, 56.0 * max(aspectRatio, 0.85)))
        let maxAltShown = 84.0
        let isCosmos = (style == .cosmos)
        // Pure & Cirrus modes show a curated, serene, uncluttered constellation sky; Cosmos unlocks dense Milky Way micro-stars
        let maxMagnitude: Float = isCosmos ? 6.0 : 4.35
        let styleBoost: Double = isCosmos ? 1.18 : 1.0

        var projected: [ProjectedStar] = []
        projected.reserveCapacity(isCosmos ? 900 : 280)

        for star in allStars {
            if !isCosmos && (star.isMilkyWayCluster || star.magnitude > maxMagnitude) {
                continue
            }
            let (alt, az) = horizontalCoordinates(star: star, latitudeDegrees: lat, lstDegrees: lst)
            guard alt > 2.0 else { continue }

            var deltaAz = az - viewCenterAz
            while deltaAz > 180.0 { deltaAz -= 360.0 }
            while deltaAz < -180.0 { deltaAz += 360.0 }

            let cosAltFactor = 0.45 + 0.55 * cos(alt * Double.pi / 180.0)
            let normX = 0.5 + (deltaAz * cosAltFactor) / (2.0 * halfHFOV)
            let normY = pow(min(1.0, alt / maxAltShown), 0.82)

            guard normX >= -0.02 && normX <= 1.02 && normY >= 0.04 && normY <= 0.992 else { continue }

            let horizonFade = smoothstep(edge0: 3.0, edge1: 18.0, x: alt)

            // Clean natural brightness hierarchy: bright constellation anchors shine clearly, faint stars stay whisper-subtle
            let magFactor = pow(10.0, Double(-0.34 * (star.magnitude - 1.15)))
            let clusterMul = star.isMilkyWayCluster ? 0.95 : styleBoost
            let clampedBright = min(1.65, max(0.16, magFactor * clusterMul))
            let brightness = Float(clampedBright * twilightFade * horizonFade * starIntensity)
            guard brightness > 0.05 else { continue }

            // Crisp Retina 4K pinpoint radii
            let baseSize: Float
            if star.magnitude < 0.2 {
                baseSize = 3.2
            } else if star.magnitude < 1.5 {
                baseSize = 2.5
            } else if star.magnitude < 2.6 {
                baseSize = 1.95
            } else if star.magnitude < 3.8 {
                baseSize = 1.5
            } else {
                baseSize = 1.15
            }

            projected.append(ProjectedStar(
                position: SIMD2<Float>(Float(normX), Float(normY)),
                color: color(forBV: star.bvIndex),
                brightness: brightness,
                size: baseSize,
                twinkleSeed: star.twinkleSeed
            ))
        }

        return projected
    }

    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        a + (b - a) * max(0, min(1, t))
    }

    private static func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        let t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
        return t * t * (3.0 - 2.0 * t)
    }
}
