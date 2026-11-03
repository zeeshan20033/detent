/// Spots a force click in the stream of `.pressure` events.
///
/// Stage 1 is an ordinary click and stage 2 is a deep press, so only the step
/// into stage 2 counts.
struct DeepPressDetector {
    private var lastStage = 0

    mutating func update(stage: Int) -> Bool {
        defer { lastStage = stage }
        return stage >= 2 && lastStage < 2
    }
}
