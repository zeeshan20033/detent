import AppKit
import QuartzCore

/// Fires the Taptic Engine in the Force Touch trackpad, once per notch.
///
/// This used to have a second backend driving `MTActuatorActuate` from
/// MultitouchSupport.framework directly. It was removed: on this hardware the
/// call returns `IOReturn 0` and produces nothing you can feel, so it was
/// private API paying no rent — and worse, its success code suppressed the
/// fallback, leaving the trackpad silent.
final class HapticEngine {

    var enabled: Bool = true
    var strength: HapticStrength = .strong

    /// Adds a second pulse just behind the first. Off by default, because it
    /// can read as a double tick rather than a heavier one.
    var doublePulse: Bool = false

    /// Keeps notches distinct instead of blurring into a buzz.
    private let minIntervalMs: Double = 16
    private var lastTapMs: Double = 0

    func tap() {
        guard enabled else { return }
        let now = CACurrentMediaTime() * 1000
        guard now - lastTapMs >= minIntervalMs else { return }
        lastTapMs = now

        fire()
        if doublePulse {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.006) { [weak self] in
                self?.fire()
            }
        }
    }

    private func fire() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            strength.systemPattern, performanceTime: .now
        )
    }
}
