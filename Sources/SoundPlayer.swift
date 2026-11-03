import AVFoundation

/// Low-latency one-shot player for the click samples.
///
/// Your volume is baked directly into the sample data rather than set on a
/// node or mixer. Node and mixer gains are engine state, and the engine resets
/// that state whenever it reconfigures — an output device change, a sample-rate
/// change, an internal restart — which silently returns the click to full
/// volume mid-session. Amplitude that lives in the samples themselves cannot be
/// reset by anything.
final class SoundPlayer {

    var enabled: Bool = true

    /// 0…1 from the slider, applied on a perceptual curve: amplitude is not
    /// loudness, so a linear drop to 0.7 is barely audible while the squared
    /// curve below reads as a genuine halving around the midpoint.
    var volume: Float = 0.7 {
        didSet {
            guard abs(volume - oldValue) > 0.0001 else { return }
            rebuildPlaybackBuffer()
        }
    }

    private static func perceptual(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []

    /// The sample as loaded from disk, at full scale.
    private var sourceBuffer: AVAudioPCMBuffer?
    /// The same sample pre-multiplied by the current volume.
    private var playbackBuffer: AVAudioPCMBuffer?

    private var connectedFormat: AVAudioFormat?
    private var index = 0
    private let poolSize = 8

    init() {
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            players.append(node)
        }
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Diag.log("audio engine reconfigured — restarting")
            self?.restart()
        }
    }

    // MARK: Loading

    @discardableResult
    func load(voice: String) -> Bool {
        guard let url = Bundle.main.url(forResource: voice,
                                        withExtension: "wav",
                                        subdirectory: "sounds"),
              let file = try? AVAudioFile(forReading: url) else {
            return false
        }

        let format = file.processingFormat
        guard let buf = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { return false }

        do { try file.read(into: buf) } catch { return false }
        sourceBuffer = buf
        rebuildPlaybackBuffer()

        if connectedFormat == nil || !format.isEqual(connectedFormat!) {
            connect(format: format)
        }
        ensureRunning()
        return true
    }

    /// Produces the scaled copy that actually gets scheduled.
    private func rebuildPlaybackBuffer() {
        guard let source = sourceBuffer,
              let scaled = AVAudioPCMBuffer(pcmFormat: source.format,
                                            frameCapacity: source.frameCapacity),
              let src = source.floatChannelData,
              let dst = scaled.floatChannelData else {
            playbackBuffer = sourceBuffer
            return
        }

        scaled.frameLength = source.frameLength
        let g = Self.perceptual(volume)
        let frames = Int(source.frameLength)
        for channel in 0..<Int(source.format.channelCount) {
            let s = src[channel], d = dst[channel]
            for i in 0..<frames { d[i] = s[i] * g }
        }
        playbackBuffer = scaled
    }

    // MARK: Engine

    private func connect(format: AVAudioFormat) {
        let wasRunning = engine.isRunning
        if wasRunning { engine.stop() }
        for node in players {
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        connectedFormat = format
        if wasRunning { ensureRunning() }
    }

    private func ensureRunning() {
        guard !engine.isRunning, connectedFormat != nil else { return }
        engine.prepare()
        do {
            try engine.start()
            for node in players where !node.isPlaying { node.play() }
        } catch {
            Diag.log("audio engine failed to start — \(error)")
        }
    }

    private func restart() {
        engine.stop()
        ensureRunning()
    }

    // MARK: Playback

    /// Plays one click. `velocity` is scroll speed in points/ms and shapes the
    /// loudness on top of your volume, so easing through a list is softer than
    /// flinging a long page.
    func click(velocity: Double) {
        guard enabled, let buf = playbackBuffer else { return }
        ensureRunning()

        let node = players[index]
        index = (index + 1) % players.count

        node.volume = min(1.0, 0.35 + Float(velocity) * 0.16)
        node.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    /// Auditions the voice with velocity shaping neutralised, so the slider is
    /// the only thing changing what you hear.
    func preview() {
        guard let buf = playbackBuffer else { return }
        ensureRunning()
        let node = players[index]
        index = (index + 1) % players.count
        node.volume = 1.0
        node.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }
}
