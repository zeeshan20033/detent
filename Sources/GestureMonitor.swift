import AppKit
import QuartzCore

/// Adds detents to trackpad gestures, alongside the ones on scrolling.
///
/// Two shapes of gesture, handled differently:
///
/// *Continuous* — pinch and rotate report a stream of small deltas, so they get
/// the same distance-accumulator treatment as scrolling: a notch every N units
/// of zoom or degrees of rotation, which turns a smooth pinch into a ratchet.
///
/// *Discrete* — a three-finger swipe or a smart-zoom double tap happens once and
/// is over, so it fires a single tap at the moment it lands.
///
/// A force click is the exception: macOS already taps the trackpad for a
/// physical press, so it gets a sound through `onDeepPress` and no second tap.
final class GestureMonitor {

    /// Called once per notch, with a nominal velocity for loudness shaping.
    var onNotch: ((Double) -> Void)?

    /// Called when a press deepens into a force click.
    var onDeepPress: (() -> Void)?

    var pinchEnabled = true
    var rotateEnabled = true
    var swipeEnabled = true
    var forceClickEnabled = false

    /// Magnification is a unitless scale delta; ~0.05 is a comfortable notch.
    var pinchStep: Double = 0.05
    /// Degrees of rotation per notch.
    var rotateStep: Double = 5.0

    private let minIntervalMs: Double = 18
    private let backlogSteps: Double = 4

    private var monitors: [Any] = []
    private var pinchAccumulator: Double = 0
    private var rotateAccumulator: Double = 0
    private var lastNotchMs: Double = 0
    private var deepPress = DeepPressDetector()

    private(set) var gestureCount = 0

    private static let mask: NSEvent.EventTypeMask =
        [.magnify, .rotate, .swipe, .smartMagnify, .pressure]

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard !isRunning else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: Self.mask, handler: {
            [weak self] event in self?.handle(event)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: Self.mask, handler: {
            [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
        Diag.log("gesture monitor started")
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        pinchAccumulator = 0
        rotateAccumulator = 0
    }

    // MARK: - Dispatch

    private func handle(_ event: NSEvent) {
        logIfNovel(event)

        switch event.type {
        case .magnify:
            guard pinchEnabled else { return }
            accumulate(&pinchAccumulator,
                       by: abs(Double(event.magnification)),
                       step: pinchStep,
                       phase: event.phase,
                       velocity: 1.4)

        case .rotate:
            guard rotateEnabled else { return }
            accumulate(&rotateAccumulator,
                       by: abs(Double(event.rotation)),
                       step: rotateStep,
                       phase: event.phase,
                       velocity: 1.4)

        case .swipe:
            guard swipeEnabled else { return }
            guard abs(event.deltaX) > 0.5 || abs(event.deltaY) > 0.5 else { return }
            fire(velocity: 2.6)

        case .smartMagnify:
            guard pinchEnabled else { return }
            fire(velocity: 2.6)

        case .pressure:
            guard forceClickEnabled else { return }
            if deepPress.update(stage: event.stage) {
                gestureCount += 1
                onDeepPress?()
            }

        default:
            break
        }
    }

    /// Records the first sighting of each gesture event type, with how many
    /// fingers were on the trackpad. If a gesture produces no line here, macOS
    /// consumed it before any app could see it.
    private var seenTypes = Set<UInt>()

    private func logIfNovel(_ event: NSEvent) {
        guard !seenTypes.contains(event.type.rawValue) else { return }
        seenTypes.insert(event.type.rawValue)

        let name: String
        switch event.type {
        case .magnify:      name = "magnify"
        case .rotate:       name = "rotate"
        case .swipe:        name = "swipe"
        case .smartMagnify: name = "smartMagnify"
        case .pressure:     name = "pressure"
        default:            name = "type \(event.type.rawValue)"
        }
        let fingers = event.allTouches().count
        Diag.log("gesture event seen: \(name) — touches=\(fingers)")
    }

    private func accumulate(_ accumulator: inout Double,
                            by amount: Double,
                            step: Double,
                            phase: NSEvent.Phase,
                            velocity: Double) {
        // Start primed so the gesture clicks the instant it begins.
        if phase.contains(.began) { accumulator = step * 0.9 }
        guard amount > 0 else { return }

        accumulator += amount
        let now = CACurrentMediaTime() * 1000

        if accumulator >= step && (now - lastNotchMs) >= minIntervalMs {
            accumulator = accumulator.truncatingRemainder(dividingBy: step)
            fire(velocity: velocity)
        } else if accumulator > step * backlogSteps {
            accumulator = step * backlogSteps
        }
    }

    private func fire(velocity: Double) {
        let now = CACurrentMediaTime() * 1000
        guard now - lastNotchMs >= minIntervalMs else { return }
        lastNotchMs = now
        gestureCount += 1
        if gestureCount <= 5 || gestureCount % 500 == 0 {
            Diag.log("gesture notch #\(gestureCount)")
        }
        onNotch?(velocity)
    }
}
