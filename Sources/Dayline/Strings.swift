import DaylineCore

/// 菜单和提示框的文案。语言可以在 App 内切换，所以不用系统的 .strings 本地化。
struct Strings {
    let language: Language

    private func text(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }

    var timeZone: String { text("时区", "Time Zone") }
    var allTimeZones: String { text("全部时区", "All Time Zones") }
    var otherRegion: String { text("其他", "Other") }
    func followSystemTimeZone(_ identifier: String) -> String {
        text("跟随系统（\(identifier)）", "System (\(identifier))")
    }
    var followingSystemPrefix: String { text("跟随系统 · ", "System · ") }

    var showDate: String { text("显示日期", "Show Date") }
    var showWeekday: String { text("显示星期", "Show Day of Week") }
    var use24HourClock: String { text("24 小时制", "24-Hour Time") }

    var styleMenu: String { text("样式", "Style") }
    var emphasizeTime: String { text("突出时间", "Emphasize Time") }
    var wideTracking: String { text("宽字距", "Wide Letter Spacing") }
    var rollingDigits: String { text("数字滚动", "Rolling Digits") }

    var desktopWidgetMenu: String { text("桌面小组件", "Desktop Widget") }
    var showDesktopWidget: String { text("显示在屏幕中央", "Show on Desktop") }
    func widgetSize(_ size: WidgetSize) -> String {
        switch size {
        case .small: text("小", "Small")
        case .medium: text("中", "Medium")
        case .large: text("大", "Large")
        }
    }
    var widgetUsesEnglish: String { text("使用英文", "Always in English") }

    var languageMenu: String { text("语言", "Language") }
    var followSystemLanguage: String { text("跟随系统", "System") }

    var launchAtLogin: String { text("开机启动", "Launch at Login") }

    var checkForUpdates: String { text("检查更新…", "Check for Updates…") }
    var checkingForUpdates: String { text("正在检查更新…", "Checking for Updates…") }
    var checkAutomatically: String { text("自动检查更新", "Check for Updates Automatically") }
    var upToDate: String { text("已是最新版本", "You’re Up to Date") }
    func upToDateMessage(_ version: String) -> String {
        text("Dayline \(version) 是目前的最新版本。", "Dayline \(version) is the latest version.")
    }
    func updateAvailable(_ version: String) -> String {
        text("Dayline \(version) 可以更新了", "Dayline \(version) Is Available")
    }
    func updateAvailableMessage(current: String) -> String {
        text("当前版本是 \(current)。", "You have version \(current).")
    }
    var installAndRelaunch: String { text("安装并重启", "Install and Relaunch") }
    var viewReleasePage: String { text("查看发布页", "View Release") }
    var later: String { text("以后再说", "Later") }
    var updateFailed: String { text("更新失败", "Update Failed") }
    func updateErrorReason(_ error: Updater.UpdateError) -> String {
        switch error {
        case .badResponse:
            text("没能从 GitHub 获取版本信息。", "Couldn’t get release information from GitHub.")
        case .missingAssets:
            text("这个版本缺少更新包或签名文件。", "This release is missing the update archive or its signature.")
        case .invalidSignature:
            text("更新包的签名校验失败，已停止安装。", "The update’s signature didn’t verify, so it wasn’t installed.")
        case .unexpectedBundle:
            text("下载的 App 与当前 App 或版本不符。", "The downloaded app doesn’t match this app or version.")
        case .notReplaceable:
            text("Dayline 所在的位置无法直接替换。", "Dayline can’t be replaced where it is.")
        case .extractionFailed:
            text("解压更新包失败。", "Couldn’t unpack the update.")
        }
    }
    var updateFailedHint: String {
        text(
            "可以到发布页手动下载新版本。如果 Dayline 不在“应用程序”文件夹，请先把它移过去。",
            "You can download the new version from the release page. If Dayline isn’t in the Applications folder, move it there first."
        )
    }
    var quit: String { text("退出 Dayline", "Quit Dayline") }

    var launchAtLoginFailed: String { text("无法更改开机启动", "Couldn’t Change Launch at Login") }
    var approvalNeeded: String { text("需要在系统设置中允许", "Approval Needed") }
    var approvalMessage: String {
        text(
            "请在“系统设置 › 通用 › 登录项”中允许 Dayline 在登录时打开。",
            "Allow Dayline to open at login in System Settings › General › Login Items."
        )
    }
    var openSystemSettings: String { text("打开系统设置", "Open System Settings") }
    var cancel: String { text("取消", "Cancel") }
}
