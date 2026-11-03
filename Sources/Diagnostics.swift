import Foundation

/// Append-only trace at /tmp/detent-debug.log.
///
/// The app has no window, so when something isn't firing this file is the only
/// way to see which stage broke: permission, event delivery, notch detection,
/// or output.
enum Diag {

    static let path = "/tmp/detent-debug.log"

    private static let queue = DispatchQueue(label: "detent.diag")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func reset() {
        queue.async {
            try? FileManager.default.removeItem(atPath: path)
            write("--- Detent started, pid \(ProcessInfo.processInfo.processIdentifier) ---")
        }
    }

    static func log(_ message: String) {
        queue.async { write(message) }
    }

    private static func write(_ message: String) {
        let line = "\(formatter.string(from: Date()))  \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
