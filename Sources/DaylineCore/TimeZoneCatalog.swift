import Foundation

public enum TimeZoneCatalog {
    /// 菜单里直接列出的常用时区。
    public static let common: [String] = [
        "Asia/Shanghai",
        "Asia/Hong_Kong",
        "Asia/Taipei",
        "Asia/Tokyo",
        "Asia/Seoul",
        "Asia/Singapore",
        "Asia/Kolkata",
        "Asia/Dubai",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Europe/Moscow",
        "America/New_York",
        "America/Chicago",
        "America/Denver",
        "America/Los_Angeles",
        "America/Sao_Paulo",
        "Australia/Sydney",
        "Pacific/Auckland",
        "UTC",
    ]

    /// 没有 `地区/城市` 结构的时区（如 `GMT`）归入的分组。
    public static let otherRegionName = "Other"

    public struct Region: Equatable {
        public let name: String
        public let identifiers: [String]
    }

    /// 系统时区数据库中的全部时区，按 `Asia`、`America` 这样的第一段分组。
    public static func regions() -> [Region] {
        let grouped = Dictionary(grouping: TimeZone.knownTimeZoneIdentifiers) { identifier in
            identifier.split(separator: "/", maxSplits: 1).count > 1
                ? String(identifier.prefix { $0 != "/" })
                : otherRegionName
        }
        return grouped
            .map { Region(name: $0.key, identifiers: $0.value.sorted()) }
            .sorted { $0.name < $1.name }
    }

    /// 某一时刻的 UTC 偏移，例如 `GMT+8`、`GMT-4`、`GMT+5:30`。
    public static func gmtOffset(of timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        guard seconds != 0 else { return "GMT" }

        let sign = seconds < 0 ? "-" : "+"
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        return minutes == 0
            ? "GMT\(sign)\(hours)"
            : String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }
}
