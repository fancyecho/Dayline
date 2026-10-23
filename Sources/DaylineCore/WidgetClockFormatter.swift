import Foundation

/// 桌面小组件的三行文字：
///
///     THURSDAY        星期四
///     22 OCT 2026     2026年10月22日
///     11:45           11:45
public final class WidgetClockFormatter {
    public struct Parts: Equatable, Sendable {
        public var weekday: String
        public var date: String
        public var time: String

        public init(weekday: String, date: String, time: String) {
            self.weekday = weekday
            self.date = date
            self.time = time
        }
    }

    private let language: Language
    private let weekdayFormatter: DateFormatter
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    public init(timeZone: TimeZone, language: Language, uses24HourClock: Bool) {
        self.language = language
        let datePattern: String
        let timePattern: String
        switch language {
        case .chinese:
            datePattern = "yyyy年M月d日"
            timePattern = uses24HourClock ? "HH:mm" : "ah:mm"
        case .english:
            datePattern = "d MMM yyyy"
            timePattern = uses24HourClock ? "HH:mm" : "h:mm a"
        }
        weekdayFormatter = .fixed(pattern: "EEEE", timeZone: timeZone, language: language)
        dateFormatter = .fixed(pattern: datePattern, timeZone: timeZone, language: language)
        timeFormatter = .fixed(pattern: timePattern, timeZone: timeZone, language: language)
    }

    public func parts(from date: Date) -> Parts {
        let locale = language.locale
        return Parts(
            weekday: weekdayFormatter.string(from: date).uppercased(with: locale),
            date: dateFormatter.string(from: date).uppercased(with: locale),
            time: timeFormatter.string(from: date)
        )
    }
}
