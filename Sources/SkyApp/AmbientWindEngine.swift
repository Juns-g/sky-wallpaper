import AVFoundation
import Foundation

/// Zero-asset procedural ambient wind synthesizer whose warmth & cadence shift with solar elevation
final class AmbientWindEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isRunning = false

    // Shared atomic-ish state accessed on audio render thread
    private let lock = NSLock()
    private var targetVolume: Float = 0.0
    private var currentVolume: Float = 0.0
    private var dayBrightness: Float = 0.5 // 0 = deep night hush, 1 = airy daytime breeze

    // Filter & noise state (audio thread only)
    private var rngState: UInt64 = 0x1234_5678_9ABC_DEF1
    private var pinkB0: Float = 0
    private var pinkB1: Float = 0
    private var pinkB2: Float = 0
    private var lpLeft: Float = 0
    private var lpRight: Float = 0
    private var lfoPhase1: Double = 0
    private var lfoPhase2: Double = 1.7

    init() {
        setupAudioGraph()
    }

    private func setupAudioGraph() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        let sampleRate = format.sampleRate

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            self.lock.lock()
            let tVol = self.targetVolume
            let bright = self.dayBrightness
            self.lock.unlock()

            let frames = Int(frameCount)
            let dt = 1.0 / sampleRate

            for frame in 0..<frames {
                // Smooth volume ramp to eliminate clicks
                self.currentVolume += (tVol - self.currentVolume) * 0.0015

                // Slow organic gusts (overlapping ~13s and ~21s cycles)
                self.lfoPhase1 += dt * 0.48
                self.lfoPhase2 += dt * 0.29
                let gust = Float(0.62 + 0.24 * sin(self.lfoPhase1) + 0.14 * sin(self.lfoPhase2))

                // Fast LCG white noise [-1, 1]
                self.rngState = self.rngState &* 6364136223846793005 &+ 1442695040888963407
                let white = Float(Int32(bitPattern: UInt32(truncatingIfNeeded: self.rngState >> 32))) / Float(Int32.max)

                // Lightweight pink noise approximation
                self.pinkB0 = 0.997 * self.pinkB0 + white * 0.029
                self.pinkB1 = 0.985 * self.pinkB1 + white * 0.032
                self.pinkB2 = 0.950 * self.pinkB2 + white * 0.048
                let pink = self.pinkB0 + self.pinkB1 + self.pinkB2 + white * 0.015

                // Cutoff shifts gently with time of day (warmer/deeper at night, airier during day)
                let baseCutoff: Float = 0.014 + bright * 0.026
                let cutoffL = min(0.12, baseCutoff * (0.75 + 0.45 * gust))
                let cutoffR = min(0.12, baseCutoff * (0.72 + 0.48 * Float(0.62 + 0.24 * cos(self.lfoPhase1) + 0.14 * sin(self.lfoPhase2 + 0.9))))

                self.lpLeft += cutoffL * (pink - self.lpLeft)
                self.lpRight += cutoffR * (pink - self.lpRight)

                let gain = self.currentVolume * gust * 0.42
                let outL = self.lpLeft * gain
                let outR = self.lpRight * gain

                if abl.count >= 2,
                   let ptrL = abl[0].mData?.assumingMemoryBound(to: Float.self),
                   let ptrR = abl[1].mData?.assumingMemoryBound(to: Float.self) {
                    ptrL[frame] = outL
                    ptrR[frame] = outR
                }
            }
            return noErr
        }

        self.sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func update(enabled: Bool, volume: Double, sunElevationDegrees: Double) {
        let normalizedDay = Float(max(0.0, min(1.0, (sunElevationDegrees + 12.0) / 36.0)))
        lock.lock()
        targetVolume = enabled ? Float(max(0.0, min(1.0, volume))) : 0.0
        dayBrightness = normalizedDay
        lock.unlock()

        if enabled && !isRunning {
            do {
                try engine.start()
                isRunning = true
            } catch {
                // Non-fatal if audio output device unavailable
            }
        } else if !enabled && isRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                let stillOff = self.targetVolume <= 0.001
                self.lock.unlock()
                if stillOff && self.isRunning {
                    self.engine.pause()
                    self.isRunning = false
                }
            }
        }
    }

    func stop() {
        if isRunning {
            engine.stop()
            isRunning = false
        }
    }
}
