import os.signpost

/// Lightweight signpost wrapper for Instruments profiling.
/// Spans appear in the "Points of Interest" track — import the "com.yaremchuk.app" subsystem.
enum Perf {
    static let log = OSLog(subsystem: "com.yaremchuk.app", category: .pointsOfInterest)

    @discardableResult
    @inline(__always)
    static func begin(_ name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    @inline(__always)
    static func end(_ name: StaticString, _ id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    /// One-shot event (no duration) — for counting occurrences.
    @inline(__always)
    static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name)
    }
}
