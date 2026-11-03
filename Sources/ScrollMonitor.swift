import AppKit
import QuartzCore

/// Watches every scroll event on the system and converts continuous scroll
/// distance into discrete detent notches.
///
/// The model is a distance accumulator: each notch costs `notchSpacing` points
/// of travel, so scrolling faster naturally produces more notches per second
/// rather than louder-but-equally-spaced ones. Two guards keep it from turning
/// into a buzz on a hard fling — a minimum interval between notches, and a cap
/// on how much travel the accumulator may bank.
final class ScrollMonitor {

    /// Called once per notch, with the instantaneous scroll speed in points/ms.
    var onNotch: ((Double) -> Void)?

    var notchSpacing: Double = 45
    var minIntervalMs: Double = 18
    var clickDuringMomentum: Bool = true

    /// Never bank more than this many notches' worth of unspent travel.
    private let backlogNotches: Double = 4

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var accumulator: Double = 0
    private var lastEventMs: Double = 0
    private var lastNotchMs: Double = 0

    private(set) var eventCount = 0
    private(set) var notchCount = 0

    var isRunning: Bool { globalMonitor != nil }

    func start() {
        guard !isRunning else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            self?.handle(event)
        }
        // Global monitors skip our own windows, so mirror it locally.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            self?.handle(event)
            return event
        }
        Diag.log("monitor started — global=\(globalMonitor != nil) spacing=\(notchSpacing)")
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
        accumulator = 0
    }

    private func handle(_ event: NSEvent) {
        eventCount += 1
        if eventCount <= 5 || eventCount % 500 == 0 {
            Diag.log(String(
                format: "event #%d dy=%.2f dx=%.2f precise=%@ phase=%lu momentum=%lu",
                eventCount, event.scrollingDeltaY, event.scrollingDeltaX,
                event.hasPreciseScrollingDeltas ? "yes" : "no",
                event.phase.rawValue, event.momentumPhase.rawValue))
        }

        let momentum = event.momentumPhase != []
        if momentum && !clickDuringMomentum { return }

        // A fresh gesture starts primed, so the very first movement clicks
        // immediately instead of after 45 points of silence.
        if event.phase.contains(.began) {
            accumulator = notchSpacing * 0.9
        }

        let now = CACurrentMediaTime() * 1000
        let dt = max(1.0, now - lastEventMs)
        lastEventMs = now

        var delta = abs(event.scrollingDeltaY)
        if delta == 0 { delta = abs(event.scrollingDeltaX) }
        guard delta > 0 else { return }

        // Fingers roll slightly during a physical click. That is not a scroll,
        // and macOS has already tapped the trackpad for the press.
        guard NSEvent.pressedMouseButtons == 0 else { return }

        // A classic wheel reports lines rather than points; scale it into the
        // same units so notchSpacing means one thing everywhere.
        if !event.hasPreciseScrollingDeltas { delta *= 10 }

        accumulator += delta

        if accumulator >= notchSpacing && (now - lastNotchMs) >= minIntervalMs {
            accumulator = accumulator.truncatingRemainder(dividingBy: notchSpacing)
            lastNotchMs = now
            notchCount += 1
            if notchCount <= 5 || notchCount % 500 == 0 {
                Diag.log(String(format: "notch #%d velocity=%.3f pt/ms",
                                notchCount, delta / dt))
            }
            onNotch?(delta / dt)
        } else if accumulator > notchSpacing * backlogNotches {
            // Drop the excess, otherwise a hard fling keeps clicking long
            // after the page has stopped moving.
            accumulator = notchSpacing * backlogNotches
        }
    }
}
