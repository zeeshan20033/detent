import AppKit

/// Every voice shipped in Resources/sounds, in menu order.
struct Voice {
    let id: String
    let name: String
    let blurb: String
}

let allVoices: [Voice] = [
    Voice(id: "detent", name: "Detent", blurb: "Crisp mechanical notch"),
    Voice(id: "tick",   name: "Tick",   blurb: "Dry vinyl tick"),
    Voice(id: "wood",   name: "Wood",   blurb: "Warm wooden tok"),
    Voice(id: "blip",   name: "Blip",   blurb: "Tight and high"),
    Voice(id: "plop",   name: "Plop",   blurb: "Low, round drop"),
    Voice(id: "snap",   name: "Snap",   blurb: "Rubbery snap"),
    Voice(id: "pop",    name: "Pop",    blurb: "Gluey upward pop"),
]

/// How far you must scroll to earn one click. Smaller = more clicks.
enum Density: Int, CaseIterable {
    case fine = 0, normal = 1, coarse = 2

    var spacing: Double {
        switch self {
        case .fine:   return 28
        case .normal: return 45
        case .coarse: return 72
        }
    }

    var name: String {
        switch self {
        case .fine:   return "Fine"
        case .normal: return "Normal"
        case .coarse: return "Coarse"
        }
    }
}

enum HapticStrength: Int, CaseIterable {
    case light = 0, medium = 1, strong = 2

    /// One tap per notch. macOS offers these three patterns and no intensity
    /// control; stacking pulses for extra strength felt worse in testing.
    var systemPattern: NSHapticFeedbackManager.FeedbackPattern {
        switch self {
        case .light:  return .alignment
        case .medium: return .generic
        case .strong: return .levelChange
        }
    }

    var name: String {
        switch self {
        case .light:  return "Light"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
}

/// Thin typed wrapper over UserDefaults.
final class Preferences {
    static let shared = Preferences()
    private let d = UserDefaults.standard

    private init() {
        d.register(defaults: [
            "active": true,
            "soundEnabled": true,
            "hapticsEnabled": true,
            "voice": "detent",
            "volume": 0.7,
            "density": Density.normal.rawValue,
            "hapticStrength": HapticStrength.strong.rawValue,
            "hapticDoublePulse": false,
            "clickDuringMomentum": true,
            "gesturesEnabled": true,
            "gesturePinch": true,
            "gestureRotate": true,
            "gestureSwipe": true,
            "gestureForceClick": false,
        ])
    }

    var active: Bool {
        get { d.bool(forKey: "active") }
        set { d.set(newValue, forKey: "active") }
    }

    var soundEnabled: Bool {
        get { d.bool(forKey: "soundEnabled") }
        set { d.set(newValue, forKey: "soundEnabled") }
    }

    var hapticsEnabled: Bool {
        get { d.bool(forKey: "hapticsEnabled") }
        set { d.set(newValue, forKey: "hapticsEnabled") }
    }

    var voice: String {
        get { d.string(forKey: "voice") ?? "detent" }
        set { d.set(newValue, forKey: "voice") }
    }

    var volume: Float {
        get { d.float(forKey: "volume") }
        set { d.set(newValue, forKey: "volume") }
    }

    var density: Density {
        get { Density(rawValue: d.integer(forKey: "density")) ?? .normal }
        set { d.set(newValue.rawValue, forKey: "density") }
    }

    var hapticStrength: HapticStrength {
        get { HapticStrength(rawValue: d.integer(forKey: "hapticStrength")) ?? .strong }
        set { d.set(newValue.rawValue, forKey: "hapticStrength") }
    }

    var hapticDoublePulse: Bool {
        get { d.bool(forKey: "hapticDoublePulse") }
        set { d.set(newValue, forKey: "hapticDoublePulse") }
    }

    var clickDuringMomentum: Bool {
        get { d.bool(forKey: "clickDuringMomentum") }
        set { d.set(newValue, forKey: "clickDuringMomentum") }
    }

    var gesturesEnabled: Bool {
        get { d.bool(forKey: "gesturesEnabled") }
        set { d.set(newValue, forKey: "gesturesEnabled") }
    }

    var gesturePinch: Bool {
        get { d.bool(forKey: "gesturePinch") }
        set { d.set(newValue, forKey: "gesturePinch") }
    }

    var gestureRotate: Bool {
        get { d.bool(forKey: "gestureRotate") }
        set { d.set(newValue, forKey: "gestureRotate") }
    }

    var gestureSwipe: Bool {
        get { d.bool(forKey: "gestureSwipe") }
        set { d.set(newValue, forKey: "gestureSwipe") }
    }

    var gestureForceClick: Bool {
        get { d.bool(forKey: "gestureForceClick") }
        set { d.set(newValue, forKey: "gestureForceClick") }
    }

}
