import AppKit
import Combine
import ServiceManagement

/// Single source of truth shared by the window and the menu bar.
///
/// Each published property writes straight through to `Preferences` and pushes
/// the value into whichever engine cares about it, so the two UIs can never
/// disagree with each other or with what you actually feel.
final class AppState: ObservableObject {

    static let shared = AppState()

    let monitor = ScrollMonitor()
    let gestures = GestureMonitor()
    let haptics = HapticEngine()
    let sound = SoundPlayer()

    private let prefs = Preferences.shared
    private var trustTimer: Timer?

    // MARK: Published settings

    @Published var active: Bool {
        didSet { prefs.active = active; syncMonitor() }
    }

    @Published var soundEnabled: Bool {
        didSet {
            prefs.soundEnabled = soundEnabled
            sound.enabled = soundEnabled
            if soundEnabled { sound.preview() }
        }
    }

    @Published var voice: String {
        didSet {
            prefs.voice = voice
            sound.load(voice: voice)
            if soundEnabled { sound.preview() }
        }
    }

    @Published var volume: Double {
        didSet {
            prefs.volume = Float(volume)
            sound.volume = Float(volume)
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            prefs.hapticsEnabled = hapticsEnabled
            haptics.enabled = hapticsEnabled
            if hapticsEnabled { haptics.tap() }
        }
    }

    @Published var hapticStrength: HapticStrength {
        didSet {
            prefs.hapticStrength = hapticStrength
            haptics.strength = hapticStrength
            if hapticsEnabled { haptics.tap() }
        }
    }

    @Published var doublePulse: Bool {
        didSet {
            prefs.hapticDoublePulse = doublePulse
            haptics.doublePulse = doublePulse
            if hapticsEnabled { haptics.tap() }
        }
    }

    @Published var density: Density {
        didSet {
            prefs.density = density
            monitor.notchSpacing = density.spacing
        }
    }

    @Published var clickDuringMomentum: Bool {
        didSet {
            prefs.clickDuringMomentum = clickDuringMomentum
            monitor.clickDuringMomentum = clickDuringMomentum
        }
    }

    @Published var gesturesEnabled: Bool {
        didSet { prefs.gesturesEnabled = gesturesEnabled; syncMonitor() }
    }

    @Published var gesturePinch: Bool {
        didSet { prefs.gesturePinch = gesturePinch; gestures.pinchEnabled = gesturePinch }
    }

    @Published var gestureRotate: Bool {
        didSet { prefs.gestureRotate = gestureRotate; gestures.rotateEnabled = gestureRotate }
    }

    @Published var gestureSwipe: Bool {
        didSet { prefs.gestureSwipe = gestureSwipe; gestures.swipeEnabled = gestureSwipe }
    }

    @Published var gestureForceClick: Bool {
        didSet {
            prefs.gestureForceClick = gestureForceClick
            gestures.forceClickEnabled = gestureForceClick
        }
    }

    @Published private(set) var accessibilityGranted: Bool = AXIsProcessTrusted()

    /// Live counter, so the window can show whether anything is actually
    /// happening without anyone having to read a log file.
    @Published private(set) var clicksFired = 0
    @Published private(set) var gesturesFired = 0

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Diag.log("login item change failed — \(error)")
            }
        }
    }

    // MARK: Lifecycle

    private init() {
        active = prefs.active
        soundEnabled = prefs.soundEnabled
        voice = prefs.voice
        volume = Double(prefs.volume)
        hapticsEnabled = prefs.hapticsEnabled
        hapticStrength = prefs.hapticStrength
        doublePulse = prefs.hapticDoublePulse
        density = prefs.density
        clickDuringMomentum = prefs.clickDuringMomentum
        gesturesEnabled = prefs.gesturesEnabled
        gesturePinch = prefs.gesturePinch
        gestureRotate = prefs.gestureRotate
        gestureSwipe = prefs.gestureSwipe
        gestureForceClick = prefs.gestureForceClick
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Pushes every stored value into the engines and starts listening.
    func start() {
        sound.enabled = soundEnabled
        sound.volume = Float(volume)
        let loaded = sound.load(voice: voice)

        haptics.enabled = hapticsEnabled
        haptics.strength = hapticStrength
        haptics.doublePulse = doublePulse

        monitor.notchSpacing = density.spacing
        monitor.clickDuringMomentum = clickDuringMomentum
        let emit: (Double) -> Void = { [weak self] velocity in
            guard let self else { return }
            self.haptics.tap()
            self.sound.click(velocity: velocity)
        }
        monitor.onNotch = emit

        gestures.pinchEnabled = gesturePinch
        gestures.rotateEnabled = gestureRotate
        gestures.swipeEnabled = gestureSwipe
        gestures.forceClickEnabled = gestureForceClick
        gestures.onNotch = emit
        gestures.onDeepPress = { [weak self] in self?.sound.click(velocity: 2.6) }

        Diag.log("sound '\(voice)' loaded = \(loaded)")
        Diag.log("prefs: active=\(active) sound=\(soundEnabled) haptics=\(hapticsEnabled) spacing=\(density.spacing)")

        syncMonitor()
        watchAccessibility()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSWorkspace.shared.open(URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!)
    }

    func testHaptic() { haptics.tap() }
    func testSound() { sound.preview() }

    // MARK: Internals

    private func syncMonitor() {
        guard active && accessibilityGranted else {
            monitor.stop()
            gestures.stop()
            return
        }
        monitor.start()
        if gesturesEnabled { gestures.start() } else { gestures.stop() }
    }

    /// The grant can arrive at any time and macOS does not notify us, so poll.
    /// The same tick refreshes the activity counters.
    private func watchAccessibility() {
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            guard let self else { return }

            if self.monitor.notchCount != self.clicksFired {
                self.clicksFired = self.monitor.notchCount
            }
            if self.gestures.gestureCount != self.gesturesFired {
                self.gesturesFired = self.gestures.gestureCount
            }
            let granted = AXIsProcessTrusted()
            guard granted != self.accessibilityGranted else { return }
            Diag.log("accessibility changed -> \(granted)")
            self.accessibilityGranted = granted
            self.syncMonitor()
        }
        RunLoop.main.add(trustTimer!, forMode: .common)
    }
}
