import Foundation

/// 桌面小组件的大小档位。
public enum WidgetSize: String, CaseIterable, Sendable {
    case small, medium, large
}

/// 用户选择的显示设置，保存在 UserDefaults 中。只影响 Dayline 自己的显示，从不改动系统设置。
public final class DisplaySettings {
    private enum Key {
        static let timeZoneIdentifier = "timeZoneIdentifier"
        static let uses24HourClock = "uses24HourClock"
        static let showsDate = "showsDate"
        static let showsWeekday = "showsWeekday"
        static let language = "language"
        static let emphasizesTime = "menuBar.emphasizesTime"
        static let usesWideTracking = "menuBar.usesWideTracking"
        static let rollsDigits = "menuBar.rollsDigits"
        static let showsDesktopWidget = "widget.isVisible"
        static let widgetSize = "widget.size"
        static let widgetUsesEnglish = "widget.usesEnglish"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 选定的时区标识符；`nil` 表示跟随系统时区。
    public var timeZoneIdentifier: String? {
        get {
            guard let identifier = defaults.string(forKey: Key.timeZoneIdentifier),
                  TimeZone(identifier: identifier) != nil
            else { return nil }
            return identifier
        }
        set {
            if let newValue, TimeZone(identifier: newValue) != nil {
                defaults.set(newValue, forKey: Key.timeZoneIdentifier)
            } else {
                defaults.removeObject(forKey: Key.timeZoneIdentifier)
            }
        }
    }

    public var uses24HourClock: Bool {
        get { bool(Key.uses24HourClock, default: true) }
        set { defaults.set(newValue, forKey: Key.uses24HourClock) }
    }

    public var showsDate: Bool {
        get { bool(Key.showsDate, default: true) }
        set { defaults.set(newValue, forKey: Key.showsDate) }
    }

    public var showsWeekday: Bool {
        get { bool(Key.showsWeekday, default: true) }
        set { defaults.set(newValue, forKey: Key.showsWeekday) }
    }

    // MARK: 菜单栏样式

    /// 日期星期变淡、时间加粗。
    public var emphasizesTime: Bool {
        get { bool(Key.emphasizesTime, default: false) }
        set { defaults.set(newValue, forKey: Key.emphasizesTime) }
    }

    /// 加宽字距，英文转为大写。
    public var usesWideTracking: Bool {
        get { bool(Key.usesWideTracking, default: false) }
        set { defaults.set(newValue, forKey: Key.usesWideTracking) }
    }

    /// 分钟变化时数字滚动。
    public var rollsDigits: Bool {
        get { bool(Key.rollsDigits, default: false) }
        set { defaults.set(newValue, forKey: Key.rollsDigits) }
    }

    // MARK: 桌面小组件

    public var showsDesktopWidget: Bool {
        get { bool(Key.showsDesktopWidget, default: false) }
        set { defaults.set(newValue, forKey: Key.showsDesktopWidget) }
    }

    public var widgetSize: WidgetSize {
        get { defaults.string(forKey: Key.widgetSize).flatMap(WidgetSize.init(rawValue:)) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Key.widgetSize) }
    }

    /// 小组件用英文（`THURSDAY`），不跟随界面语言。
    public var widgetUsesEnglish: Bool {
        get { bool(Key.widgetUsesEnglish, default: true) }
        set { defaults.set(newValue, forKey: Key.widgetUsesEnglish) }
    }

    public var widgetLanguage: Language {
        widgetUsesEnglish ? .english : language
    }

    /// 选定的语言；`nil` 表示跟随系统语言。
    public var languagePreference: Language? {
        get { defaults.string(forKey: Key.language).flatMap(Language.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.language)
            } else {
                defaults.removeObject(forKey: Key.language)
            }
        }
    }

    public var language: Language {
        languagePreference ?? .system
    }

    /// 实际用于显示的时区。跟随系统时读取当前系统时区，因此系统时区变化后会得到新值。
    public var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current
    }

    private func bool(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    public var clockOptions: ClockFormatter.Options {
        ClockFormatter.Options(
            uses24HourClock: uses24HourClock,
            showsDate: showsDate,
            showsWeekday: showsWeekday,
            language: language
        )
    }
}
