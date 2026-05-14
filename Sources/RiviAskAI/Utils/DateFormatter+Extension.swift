import Foundation

extension DateFormatter {
    /// Returns a date formatter configured for the API date format (MM/dd/yyyy)
    static var apiDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}

extension Date {
    /// Converts the date to API format string (MM/dd/yyyy)
    func toAPIDateString() -> String {
        return DateFormatter.apiDateFormatter.string(from: self)
    }

    /// Converts the date to ISO 8601 string with millisecond precision (e.g. `2026-05-05T07:12:56.744Z`)
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
}
