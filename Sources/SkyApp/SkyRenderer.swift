import AppKit
import CoreGraphics
import ImageIO
import Metal
import MetalKit
import SkyCore
import UniformTypeIdentifiers
import simd

struct SkyUniformsGPU {
    var resolution: SIMD2<Float>
    var time: Float
    var sunElevation: Float
    var sunScreenPos: SIMD2<Float>
    var moonScreenPos: SIMD2<Float>
    var uvRect: SIMD4<Float>
    var virtualAspect: Float
    var moonElevation: Float
    var moonIllumination: Float
    var moonPhase: Float
    var showMoon: Float
    var cloudStrength: Float
    var cosmosStrength: Float
    var starIntensity: Float
    var weatherCloud: Float
    var rainIntensity: Float
    var snowIntensity: Float
    var lstRadians: Float
    var isMorning: Float
}

struct StarInstanceGPU {
    var position: SIMD2<Float>
    var color: SIMD3<Float>
    var brightness: Float
    var size: Float
    var twinkleSeed: Float
}

final class SkyMetalContext {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let skyPipeline: MTLRenderPipelineState
    let starPipeline: MTLRenderPipelineState

    static let shared: SkyMetalContext? = try? SkyMetalContext()

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            throw NSError(domain: "SkyMetalContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is unavailable on this Mac."])
        }
        self.device = device
        self.commandQueue = queue

        let library = try device.makeLibrary(source: SkyShaderSource.metalSource, options: nil)
        guard let skyVert = library.makeFunction(name: "skyVertex"),
              let skyFrag = library.makeFunction(name: "skyFragment"),
              let starVert = library.makeFunction(name: "starVertex"),
              let starFrag = library.makeFunction(name: "starFragment") else {
            throw NSError(domain: "SkyMetalContext", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load Metal shader functions."])
        }

        let skyDesc = MTLRenderPipelineDescriptor()
        skyDesc.vertexFunction = skyVert
        skyDesc.fragmentFunction = skyFrag
        skyDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.skyPipeline = try device.makeRenderPipelineState(descriptor: skyDesc)

        let starDesc = MTLRenderPipelineDescriptor()
        starDesc.vertexFunction = starVert
        starDesc.fragmentFunction = starFrag
        starDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        starDesc.colorAttachments[0].isBlendingEnabled = true
        starDesc.colorAttachments[0].rgbBlendOperation = .add
        starDesc.colorAttachments[0].alphaBlendOperation = .add
        starDesc.colorAttachments[0].sourceRGBBlendFactor = .one
        starDesc.colorAttachments[0].destinationRGBBlendFactor = .one
        starDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        starDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        self.starPipeline = try device.makeRenderPipelineState(descriptor: starDesc)
    }

    static func projectCelestialPoint(
        elevationDegrees: Double,
        azimuthDegrees: Double,
        latitudeDegrees: Double,
        aspectRatio: Double
    ) -> SIMD2<Float> {
        let viewCenterAz = latitudeDegrees >= 0.0 ? 180.0 : 0.0
        // Wide field of view adapts gracefully from portrait (0.56) to 3-monitor panorama (~4.0)
        let halfHFOV = max(68.0, min(112.0, 56.0 * max(min(aspectRatio, 2.2), 0.85)))
        var deltaAz = azimuthDegrees - viewCenterAz
        while deltaAz > 180.0 { deltaAz -= 360.0 }
        while deltaAz < -180.0 { deltaAz += 360.0 }

        let clampedAlt = max(-25.0, min(84.0, elevationDegrees))
        let cosAltFactor = 0.45 + 0.55 * cos(max(0.0, clampedAlt) * Double.pi / 180.0)
        let normX = 0.5 + (deltaAz * cosAltFactor) / (2.0 * halfHFOV)
        let normY: Double
        if clampedAlt >= 0.0 {
            normY = pow(min(1.0, clampedAlt / 84.0), 0.82)
        } else {
            normY = clampedAlt / 40.0
        }
        return SIMD2<Float>(Float(normX), Float(normY))
    }

    func renderPreviewPNG(
        to url: URL,
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool = false,
        starIntensity: Double,
        slice: DisplaySlice? = nil,
        weather: WeatherState? = nil,
        width: Int = 1920,
        height: Int = 1080,
        time: Float = 12.0
    ) throws {
        let cgImage = try renderOffscreenImage(
            snapshot: snapshot,
            style: style,
            showStars: showStars,
            showMoon: showMoon,
            starIntensity: starIntensity,
            slice: slice ?? DisplaySlice.fullScreen(aspect: Double(width) / Double(height)),
            weather: weather,
            width: width,
            height: height,
            time: time
        )
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "SkyMetalContext", code: 5, userInfo: nil)
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
    }

    func renderWallpaperJPEG(
        to url: URL,
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        slice: DisplaySlice,
        weather: WeatherState?,
        width: Int,
        height: Int
    ) throws {
        let cgImage = try renderOffscreenImage(
            snapshot: snapshot,
            style: style,
            showStars: showStars,
            showMoon: showMoon,
            starIntensity: starIntensity,
            slice: slice,
            weather: weather,
            width: width,
            height: height,
            time: 12.0
        )
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "SkyMetalContext", code: 6, userInfo: nil)
        }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.90]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    private func renderOffscreenImage(
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        slice: DisplaySlice,
        weather: WeatherState?,
        width: Int,
        height: Int,
        time: Float
    ) throws -> CGImage {
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        texDesc.usage = [.renderTarget, .shaderRead]
        texDesc.storageMode = .managed
        guard let texture = device.makeTexture(descriptor: texDesc) else {
            throw NSError(domain: "SkyMetalContext", code: 3, userInfo: nil)
        }

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = texture
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].storeAction = .store
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        var uniforms = makeUniforms(
            snapshot: snapshot,
            resolution: SIMD2<Float>(Float(width), Float(height)),
            time: time,
            style: style,
            showStars: showStars,
            showMoon: showMoon,
            starIntensity: starIntensity,
            slice: slice,
            weather: weather
        )

        let starGPU: [StarInstanceGPU] = showStars
            ? StarCatalog.projectVisibleStars(snapshot: snapshot, aspectRatio: slice.virtualAspect, starIntensity: starIntensity, style: style).map {
                StarInstanceGPU(position: $0.position, color: $0.color, brightness: $0.brightness, size: $0.size, twinkleSeed: $0.twinkleSeed)
            }
            : []

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else {
            throw NSError(domain: "SkyMetalContext", code: 4, userInfo: nil)
        }

        encoder.setRenderPipelineState(skyPipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SkyUniformsGPU>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        if !starGPU.isEmpty,
           let starBuf = device.makeBuffer(bytes: starGPU, length: MemoryLayout<StarInstanceGPU>.stride * starGPU.count, options: .storageModeShared) {
            encoder.setRenderPipelineState(starPipeline)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<SkyUniformsGPU>.stride, index: 0)
            encoder.setVertexBuffer(starBuf, offset: 0, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: starGPU.count)
        }

        encoder.endEncoding()
        if let blit = cmdBuf.makeBlitCommandEncoder() {
            blit.synchronize(resource: texture)
            blit.endEncoding()
        }
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&pixels, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw NSError(domain: "SkyMetalContext", code: 5, userInfo: nil)
        }
        return cgImage
    }

    func makeUniforms(
        snapshot: SkySnapshot,
        resolution: SIMD2<Float>,
        time: Float,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        slice: DisplaySlice,
        weather: WeatherState?
    ) -> SkyUniformsGPU {
        let sunPos = Self.projectCelestialPoint(
            elevationDegrees: snapshot.solar.elevationDegrees,
            azimuthDegrees: snapshot.solar.azimuthDegrees,
            latitudeDegrees: snapshot.location.latitude,
            aspectRatio: slice.virtualAspect
        )
        let moonPos = Self.projectCelestialPoint(
            elevationDegrees: snapshot.moon.elevationDegrees,
            azimuthDegrees: snapshot.moon.azimuthDegrees,
            latitudeDegrees: snapshot.location.latitude,
            aspectRatio: slice.virtualAspect
        )
        return SkyUniformsGPU(
            resolution: resolution,
            time: time,
            sunElevation: Float(snapshot.solar.elevationDegrees),
            sunScreenPos: sunPos,
            moonScreenPos: moonPos,
            uvRect: slice.uvRect,
            virtualAspect: Float(slice.virtualAspect),
            moonElevation: Float(snapshot.moon.elevationDegrees),
            moonIllumination: Float(snapshot.moon.illumination),
            moonPhase: Float(snapshot.moon.phaseFraction),
            showMoon: showMoon ? 1.0 : 0.0,
            cloudStrength: style == .cirrus ? 1.0 : 0.0,
            cosmosStrength: style == .cosmos ? 1.0 : 0.0,
            starIntensity: showStars ? Float(starIntensity) : 0.0,
            weatherCloud: Float(weather?.cloudCover ?? 0.0),
            rainIntensity: Float(weather?.rainIntensity ?? 0.0),
            snowIntensity: Float(weather?.snowIntensity ?? 0.0),
            lstRadians: Float(snapshot.localSiderealTimeDegrees * Double.pi / 180.0),
            isMorning: snapshot.solar.isMorning ? 1.0 : 0.0
        )
    }
}

final class SkyRenderer: NSObject, MTKViewDelegate {
    private let context: SkyMetalContext
    private var snapshot: SkySnapshot
    private var style: SkyStyle = .pure
    private var showStars: Bool = true
    private var showMoon: Bool = false
    private var starIntensity: Double = 1.0
    private var slice: DisplaySlice
    private var weather: WeatherState? = nil
    private var starBuffer: MTLBuffer?
    private var starCount: Int = 0
    private let startTime = CACurrentMediaTime()

    init(context: SkyMetalContext, initialSnapshot: SkySnapshot, slice: DisplaySlice) {
        self.context = context
        self.snapshot = initialSnapshot
        self.slice = slice
        super.init()
        rebuildStarBuffer()
    }

    func update(
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        slice: DisplaySlice,
        weather: WeatherState?
    ) {
        self.snapshot = snapshot
        self.style = style
        self.showStars = showStars
        self.showMoon = showMoon
        self.starIntensity = starIntensity
        self.slice = slice
        self.weather = weather
        rebuildStarBuffer()
    }

    private func rebuildStarBuffer() {
        guard showStars else {
            starCount = 0
            starBuffer = nil
            return
        }
        let projected = StarCatalog.projectVisibleStars(
            snapshot: snapshot,
            aspectRatio: slice.virtualAspect,
            starIntensity: starIntensity,
            style: style
        )
        starCount = projected.count
        guard !projected.isEmpty else {
            starBuffer = nil
            return
        }
        let gpuStars = projected.map {
            StarInstanceGPU(
                position: $0.position,
                color: $0.color,
                brightness: $0.brightness,
                size: $0.size,
                twinkleSeed: $0.twinkleSeed
            )
        }
        let byteCount = MemoryLayout<StarInstanceGPU>.stride * gpuStars.count
        if let existing = starBuffer, existing.length >= byteCount {
            memcpy(existing.contents(), gpuStars, byteCount)
        } else {
            starBuffer = context.device.makeBuffer(bytes: gpuStars, length: byteCount, options: .storageModeShared)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Explicit HiDPI sizing managed by DesktopWindowManager
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmdBuf = context.commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else {
            return
        }

        let size = view.drawableSize
        guard size.width > 0 && size.height > 0 else {
            encoder.endEncoding()
            return
        }

        let elapsed = Float(CACurrentMediaTime() - startTime)
        var uniforms = context.makeUniforms(
            snapshot: snapshot,
            resolution: SIMD2<Float>(Float(size.width), Float(size.height)),
            time: elapsed,
            style: style,
            showStars: showStars,
            showMoon: showMoon,
            starIntensity: starIntensity,
            slice: slice,
            weather: weather
        )

        encoder.setRenderPipelineState(context.skyPipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SkyUniformsGPU>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        if starCount > 0, let starBuf = starBuffer {
            encoder.setRenderPipelineState(context.starPipeline)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<SkyUniformsGPU>.stride, index: 0)
            encoder.setVertexBuffer(starBuf, offset: 0, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: starCount)
        }

        encoder.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}
