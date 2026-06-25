import Foundation

// Keep only utility types or types not present in DatabaseModels.swift

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Date Formatting

enum AppDateFormatter {
    private static let isoPlain = ISO8601DateFormatter()

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let manualFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let manualPlain: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let mediumDateShortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortDateShortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    static func parseISODate(_ string: String) -> Date? {
        isoPlain.date(from: string)
            ?? isoFractional.date(from: string)
            ?? manualFractional.date(from: string)
            ?? manualPlain.date(from: string)
            ?? DateFormatter.iso8601Full.date(from: string)
    }

    static func jobPostedDate(_ string: String, fallback: String = "Recently", today: String = "Today", yesterday: String = "Yesterday") -> String {
        guard let date = parseISODate(string) else { return fallback }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return today
        } else if calendar.isDateInYesterday(date) {
            return yesterday
        } else {
            return shortDateFormatter.string(from: date)
        }
    }

    static func mediumDate(_ string: String, fallback: String? = nil) -> String {
        guard let date = parseISODate(string) else { return fallback ?? string }
        return mediumDateFormatter.string(from: date)
    }

    static func mediumDateShortTime(_ string: String, fallback: String? = nil) -> String {
        guard let date = parseISODate(string) else { return fallback ?? string }
        return mediumDateShortTimeFormatter.string(from: date)
    }

    static func shortDateShortTime(_ string: String?, fallback: String = "") -> String {
        guard let string, let date = parseISODate(string) else { return fallback }
        return shortDateShortTimeFormatter.string(from: date)
    }

    static func shortTime(_ string: String, fallback: String = "") -> String {
        guard let date = parseISODate(string) else { return fallback }
        return shortTimeFormatter.string(from: date)
    }

    static func monthYear(_ string: String?, fallback: String = "Unknown") -> String {
        guard let string, let date = parseISODate(string) else { return fallback }
        return monthYearFormatter.string(from: date)
    }

    static func presenceTimeAgo(_ string: String?, fallback: String = "Never", invalidFallback: String = "Unknown") -> String {
        guard let string else { return fallback }
        guard let date = parseISODate(string) else { return invalidFallback }
        return presenceTimeAgo(from: date)
    }

    static func presenceTimeAgo(from date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    static func localizedRelativeTime(_ string: String, fallback: String = "Unknown time") -> String {
        guard let date = parseISODate(string) else { return fallback }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    static func compactRelativeTime(_ string: String, fallback: String? = nil) -> String {
        guard let date = parseISODate(string) else { return fallback ?? string }
        let timeInterval = Date().timeIntervalSince(date)

        if timeInterval < 60 {
            return "just now"
        }

        let minutes = Int(timeInterval / 60)
        if minutes < 60 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        }

        let hours = Int(timeInterval / 3600)
        if hours < 24 {
            return hours == 1 ? "1 h ago" : "\(hours) h ago"
        }

        let days = Int(timeInterval / 86400)
        if days < 7 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }

        let weeks = Int(timeInterval / 604800)
        if weeks < 4 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }

        return mediumDateFormatter.string(from: date)
    }

    static func recentWork(_ string: String?, fallback: String = "No recent work", invalidFallback: String = "Unknown") -> String {
        guard let string else { return fallback }
        guard let date = parseISODate(string) else { return invalidFallback }

        let days = Int(Date().timeIntervalSince(date) / 86400)
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 30 {
            return "\(days) days ago"
        } else {
            return "Over a month ago"
        }
    }

    static func lastUpdated(_ string: String?, fallback: String = "Unknown") -> String {
        guard let string, let date = parseISODate(string) else { return fallback }

        let days = Int(Date().timeIntervalSince(date) / 86400)
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else {
            return "Over a week ago"
        }
    }
}
