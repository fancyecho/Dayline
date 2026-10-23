import Foundation

/// 界面和时钟使用的语言。
public enum Language: String, CaseIterable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    /// 按系统首选语言决定：首选中文时用中文，其余用英文。
    public static var system: Language {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .chinese : .english
    }

    public var locale: Locale {
        switch self {
        case .chinese: Locale(identifier: "zh_Hans_CN")
        case .english: Locale(identifier: "en_US")
        }
    }

    /// 语言自己的名字，在任何界面语言下都这样显示。
    public var nativeName: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }
}
