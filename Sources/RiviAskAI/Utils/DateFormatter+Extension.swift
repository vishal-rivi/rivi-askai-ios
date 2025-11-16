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
}
