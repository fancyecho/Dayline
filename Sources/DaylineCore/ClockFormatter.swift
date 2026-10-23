import Foundation

/// 把时刻格式化成菜单栏那一行，例如 `10月23日 周五 09:30` 或 `Fri Oct 23 09:30`。
///
/// 日期、星期和时间都按 `timeZone` 计算，与系统时区无关；夏令时由时区数据库处理。
public final class ClockFormatter {
    public struct Options: Equatable, Sendable {
        public var uses24HourClock: Bool
        public var showsDate: Bool
        public var showsWeekday: Bool
        public var language: Language

        public init(
            uses24HourClock: Bool = true,
            showsDate: Bool = true,
            showsWeekday: Bool = true,
            language: Language = .chinese
        ) {
            self.uses24HourClock = uses24HourClock
            self.showsDate = showsDate
            self.showsWeekday = showsWeekday
            self.language = language
        }
    }

    /// 时间前面的日期星期部分和时间部分分开给出，方便分别设置样式。
    public struct Parts: Equatable, Sendable {
        /// 日期和星期；两者都隐藏时为 `nil`。
        public var leading: String?
        public var time: String

        public init(leading: String?, time: String) {
            self.leading = leading
            self.time = time
        }

        public var joined: String {
            [leading, time].compactMap { $0 }.joined(separator: " ")
        }
    }

    public let timeZone: TimeZone
    public let options: Options

    private let leadingFormatter: DateFormatter?
    private let timeFormatter: DateFormatter

    public init(timeZone: TimeZone, options: Options) {
        self.timeZone = timeZone
        self.options = options

        let patterns = Self.patterns(for: options)
        leadingFormatter = patterns.leading.map {
            .fixed(pattern: $0, timeZone: timeZone, language: options.language)
        }
        timeFormatter = .fixed(pattern: patterns.time, timeZone: timeZone, language: options.language)
    }

    public func parts(from date: Date) -> Parts {
        Parts(leading: leadingFormatter?.string(from: date), time: timeFormatter.string(from: date))
    }

    public func string(from date: Date) -> String {
        parts(from: date).joined
    }

    /// 中文：`M月d日 EEE` + `HH:mm`；英文按系统时钟的顺序：`EEE MMM d` + `HH:mm`。
    private static func patterns(for options: Options) -> (leading: String?, time: String) {
        let weekday = options.showsWeekday ? "EEE" : nil
        let leading: [String?]
        let time: String

        switch options.language {
        case .chinese:
            leading = [options.showsDate ? "M月d日" : nil, weekday]
            time = options.uses24HourClock ? "HH:mm" : "ah:mm"
        case .english:
            leading = [weekday, options.showsDate ? "MMM d" : nil]
            time = options.uses24HourClock ? "HH:mm" : "h:mm a"
        }

        let leadingPattern = leading.compactMap { $0 }.joined(separator: " ")
        return (leadingPattern.isEmpty ? nil : leadingPattern, time)
    }
}

extension DateFormatter {
    /// 固定格式、公历、指定时区和语言的格式化器。
    static func fixed(pattern: String, timeZone: TimeZone, language: Language) -> DateFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter
    }
}
