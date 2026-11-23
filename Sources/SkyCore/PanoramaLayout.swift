import CoreGraphics
import Foundation
import simd

public struct DisplaySlice: Sendable, Equatable {
    /// Normalized sub-rect inside the unified virtual sky dome: (originX, originY, sizeX, sizeY) in [0, 1]
    public let uvRect: SIMD4<Float>
    /// Aspect ratio of the unified virtual canvas (width / height)
    public let virtualAspect: Double

    public init(uvRect: SIMD4<Float>, virtualAspect: Double) {
        self.uvRect = uvRect
        self.virtualAspect = virtualAspect
    }

    public static func fullScreen(aspect: Double) -> DisplaySlice {
        DisplaySlice(uvRect: SIMD4<Float>(0, 0, 1, 1), virtualAspect: max(0.25, aspect))
    }
}

public enum PanoramaLayout {
    /// Compute seamless per-screen sky UV slices from Cocoa global screen frames.
    /// Horizontal coordinates span continuously across all connected displays (left -> center -> right),
    /// while vertical Y keeps each display anchored cleanly so the horizon never disappears off-screen on shorter monitors.
    public static func computeSlices(frames: [CGRect], spanAcrossDisplays: Bool) -> [DisplaySlice] {
        guard !frames.isEmpty else { return [] }

        if !spanAcrossDisplays || frames.count == 1 {
            return frames.map { frame in
                let aspect = Double(frame.width / max(1.0, frame.height))
                return DisplaySlice.fullScreen(aspect: aspect)
            }
        }

        let minX = frames.map(\.minX).min() ?? 0
        let maxX = frames.map(\.maxX).max() ?? 1
        let totalWidth = max(1.0, maxX - minX)

        // Use weighted reference height (max display height clamped so vertical monitors don't crush landscape horizons)
        let medianHeight = frames.map(\.height).sorted()[frames.count / 2]
        let refHeight = max(1.0, medianHeight)
        let virtualAspect = Double(totalWidth / refHeight)

        return frames.map { frame in
            let u0 = Float((frame.minX - minX) / totalWidth)
            let uw = Float(frame.width / totalWidth)
            // Keep horizon visible at bottom of every monitor while preserving natural vertical scale
            let vh = Float(min(1.0, max(0.75, frame.height / (refHeight * 1.15))))
            let v0: Float = 0.0
            return DisplaySlice(
                uvRect: SIMD4<Float>(u0, v0, uw, vh),
                virtualAspect: virtualAspect
            )
        }
    }
}
