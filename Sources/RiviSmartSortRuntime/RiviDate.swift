import Foundation

/// Dates for `FlightSearch` / `HotelSearch`. Smart Sort sends dates exactly as you give them, and the
/// gateway parses `%Y-%m-%dT%H:%M:%S.%fZ`, so a `Date` must be formatted with milliseconds, in UTC
/// (`2026-10-14T09:31:18.000Z`).
public enum RiviDate {
    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
