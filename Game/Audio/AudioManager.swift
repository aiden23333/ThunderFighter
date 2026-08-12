import AVFoundation
import UIKit

/// All sound effects. The first version ships without audio asset files, so the
/// manager gracefully falls back to lightweight synthesized tones and never
/// crashes if a file is missing (per the stability / degradation requirement).
enum SoundEffect: String, CaseIterable {
    case mainFire, missileLock, laserFire, enemyFire
    case bossAlert, explosion, pickup, playerHit, victory, defeat

    /// (frequency Hz, duration s) used by the synthesized fallback.
    var tone: (frequency: Float, duration: Float) {
        switch self {
        case .mainFire:   return (220, 0.08)
        case .missileLock: return (520, 0.06)
        case .laserFire:  return (330, 0.18)
        case .enemyFire:  return (160, 0.06)
        case .bossAlert:  return (90,  0.5)
        case .explosion:  return (70,  0.25)
        case .pickup:     return (660, 0.08)
        case .playerHit:  return (110, 0.2)
        case .victory:    return (440, 0.6)
        case .defeat:     return (80,  0.8)
        }
    }

    var fileName: String { rawValue }
}

/// Owns audio playback + haptics. Tries to load real asset files first; if they
/// are absent it synthesizes a short tone instead. Every failure is caught and
/// logged, never thrown to the game loop.
final class AudioManager {

    static let shared = AudioManager()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var enabled = true
    private let engine = AVAudioEngine()

    private init() {
        startEngine()
        preloadAssets()
    }

    // MARK: Setup
    private func startEngine() {
        guard !engine.isRunning else { return }
        do { try engine.start() }
        catch { log("audio engine unavailable (tones disabled): \(error)") }
    }

    private func preloadAssets() {
        for s in SoundEffect.allCases {
            if let url = Bundle.main.url(forResource: s.fileName, withExtension: "caf")
                ?? Bundle.main.url(forResource: s.fileName, withExtension: "mp3") {
                do {
                    let p = try AVAudioPlayer(contentsOf: url)
                    p.prepareToPlay()
                    players[s] = p
                } catch {
                    log("could not load \(s.fileName): \(error)")
                }
            } else {
                log("asset missing: \(s.fileName) — using tone fallback")
            }
        }
    }

    // MARK: Playback
    func play(_ s: SoundEffect) {
        guard enabled else { return }
        if let p = players[s] {
            p.stop()
            p.currentTime = 0
            p.play()
        } else {
            playTone(s)
        }
    }

    /// Synthesized fallback so the game still feels alive without asset files.
    private func playTone(_ s: SoundEffect) {
        guard enabled, engine.isRunning else { return }
        let (freq, dur) = s.tone
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let length = AVAudioFrameCount(sampleRate * Double(dur))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length) else { return }
        buffer.frameLength = length
        let step = Float(2 * Double.pi * Double(freq) / sampleRate)
        if let channels = buffer.floatChannelData {
            for i in 0..<Int(length) {
                let env = Float(1.0 - Double(i) / Double(length)) // simple decay
                let sample = sin(step * Float(i)) * env * 0.25
                channels[0][i] = sample
                if format.channelCount > 1 { channels[1][i] = sample }
            }
        }
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.outputNode, format: buffer.format)
        node.scheduleBuffer(buffer) {
            node.stop()
            self.engine.disconnectNodeOutput(node)
        }
        node.play()
    }

    // MARK: Freeze / resume (background)
    func pauseAll() {
        engine.pause()
    }

    func resumeAll() {
        startEngine()
    }

    func setMuted(_ muted: Bool) {
        enabled = !muted
    }

    // MARK: Haptics (guarded — simulators / unsupported devices just skip)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    func notifyHit() { impact(.heavy) }
    func notifyPickup() { impact(.light) }

    private func log(_ message: String) {
        #if DEBUG
        print("[AudioManager] \(message)")
        #endif
    }
}
