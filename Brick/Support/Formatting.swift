import Foundation

enum Format {
    /// "1h 30m", "45m" — for durations the user is choosing.
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval.rounded()) / 60
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, let m): return "\(m)m"
        case (let h, 0): return "\(h)h"
        case (let h, let m): return "\(h)h \(m)m"
        }
    }

    /// "43:12" / "1:02:11" — for a countdown that is ticking.
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// Spoken form for VoiceOver — "43 minutes", not "43:12".
    static func spokenRemaining(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded(.up))
        if minutes < 60 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0
            ? "\(hours) hour\(hours == 1 ? "" : "s")"
            : "\(hours) hour\(hours == 1 ? "" : "s") \(rest) minutes"
    }

    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func day(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
