import AppKit
import DaylineCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// 一个对应某个布尔设置的勾选菜单项。
    private struct SettingToggle {
        let item: NSMenuItem
        let keyPath: ReferenceWritableKeyPath<DisplaySettings, Bool>
        let title: (Strings) -> String
    }

    private let settings = DisplaySettings()
    private var formatter: ClockFormatter!
    private var widgetFormatter: WidgetClockFormatter!
    private var menuBarClock: MenuBarClock!
    private let desktopWidget = DesktopWidget()
    private lazy var updater = Updater { [weak self] in self?.strings ?? Strings(language: .system) }

    private lazy var ticker = MinuteTicker { [weak self] in self?.refresh(animated: true) }
    private lazy var timeZoneMenu = TimeZoneMenu(settings: settings) { [weak self] in
        self?.displaySettingsDidChange()
    }

    private let timeZoneHeaderItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let timeZoneItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let styleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let desktopWidgetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var widgetSizeItems: [NSMenuItem] = []
    private let languageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let followSystemLanguageItem = NSMenuItem(title: "", action: #selector(selectLanguage(_:)), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let checkForUpdatesItem = NSMenuItem(title: "", action: #selector(checkForUpdates), keyEquivalent: "")
    private let automaticUpdatesItem = NSMenuItem(title: "", action: #selector(toggleAutomaticUpdates), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    private lazy var showDateToggle = makeToggle(\.showsDate, title: \.showDate)
    private lazy var showWeekdayToggle = makeToggle(\.showsWeekday, title: \.showWeekday)
    private lazy var hourCycleToggle = makeToggle(\.uses24HourClock, title: \.use24HourClock)
    private lazy var emphasizeTimeToggle = makeToggle(\.emphasizesTime, title: \.emphasizeTime)
    private lazy var wideTrackingToggle = makeToggle(\.usesWideTracking, title: \.wideTracking)
    private lazy var rollingDigitsToggle = makeToggle(\.rollsDigits, title: \.rollingDigits)
    private lazy var showWidgetToggle = makeToggle(\.showsDesktopWidget, title: \.showDesktopWidget)
    private lazy var widgetEnglishToggle = makeToggle(\.widgetUsesEnglish, title: \.widgetUsesEnglish)

    private var toggles: [SettingToggle] {
        [
            showDateToggle, showWeekdayToggle, hourCycleToggle,
            emphasizeTimeToggle, wideTrackingToggle, rollingDigitsToggle,
            showWidgetToggle, widgetEnglishToggle,
        ]
    }

    private var strings: Strings { Strings(language: settings.language) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarClock = MenuBarClock(menu: makeMenu())
        observeSystemEvents()
        displaySettingsDidChange()
        ticker.start()
        updater.scheduleAutomaticChecks()
    }

    // MARK: - Clock

    /// 每分钟更新菜单栏和小组件；`animated` 只在整分钟跳动时为真。
    private func refresh(animated: Bool = false) {
        let now = Date()
        let animated = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        menuBarClock.update(parts: formatter.parts(from: now), style: menuBarStyle, animated: animated)
        if desktopWidget.isVisible {
            desktopWidget.update(
                parts: widgetFormatter.parts(from: now),
                size: settings.widgetSize,
                rollsDigits: settings.rollsDigits,
                animated: animated
            )
        }
    }

    private var menuBarStyle: MenuBarStyle {
        MenuBarStyle(
            emphasizesTime: settings.emphasizesTime,
            usesWideTracking: settings.usesWideTracking,
            rollsDigits: settings.rollsDigits
        )
    }

    private func displaySettingsDidChange() {
        let timeZone = settings.timeZone
        formatter = ClockFormatter(timeZone: timeZone, options: settings.clockOptions)
        widgetFormatter = WidgetClockFormatter(
            timeZone: timeZone,
            language: settings.widgetLanguage,
            uses24HourClock: settings.uses24HourClock
        )

        if settings.showsDesktopWidget {
            desktopWidget.show()
        } else {
            desktopWidget.hide()
        }
        refresh()
    }

    /// 唤醒、解锁或系统校时之后，立即重画并重新对齐到整分钟。
    private func clockMayHaveJumped() {
        refresh()
        ticker.start()
    }

    private func systemTimeZoneDidChange() {
        NSTimeZone.resetSystemTimeZone()
        displaySettingsDidChange()
    }

    private func observeSystemEvents() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ] {
            observe(name, on: workspaceCenter) { $0.clockMayHaveJumped() }
        }
        observe(.NSSystemClockDidChange, on: .default) { $0.clockMayHaveJumped() }
        observe(.NSSystemTimeZoneDidChange, on: .default) { $0.systemTimeZoneDidChange() }
        // 跟随系统语言时，系统语言改了也要跟着变。
        observe(NSLocale.currentLocaleDidChangeNotification, on: .default) { $0.displaySettingsDidChange() }
        // 接上或拔掉显示器、改分辨率后，小组件重新居中。
        observe(NSApplication.didChangeScreenParametersNotification, on: .default) { $0.desktopWidget.recenter() }
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        perform action: @escaping @MainActor @Sendable (AppDelegate) -> Void
    ) {
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
    }

    // MARK: - Menu

    private func makeToggle(
        _ keyPath: ReferenceWritableKeyPath<DisplaySettings, Bool>,
        title: @escaping (Strings) -> String
    ) -> SettingToggle {
        let item = NSMenuItem(title: "", action: #selector(toggleSetting(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = keyPath
        return SettingToggle(item: item, keyPath: keyPath, title: title)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        timeZoneHeaderItem.isEnabled = false
        timeZoneItem.submenu = timeZoneMenu.menu
        styleItem.submenu = submenu([emphasizeTimeToggle.item, wideTrackingToggle.item, rollingDigitsToggle.item])
        desktopWidgetItem.submenu = makeDesktopWidgetMenu()
        languageItem.submenu = makeLanguageMenu()
        for item in [launchAtLoginItem, checkForUpdatesItem, automaticUpdatesItem] {
            item.target = self
        }

        menu.items = [
            timeZoneHeaderItem,
            .separator(),
            timeZoneItem,
            showDateToggle.item,
            showWeekdayToggle.item,
            hourCycleToggle.item,
            styleItem,
            .separator(),
            desktopWidgetItem,
            .separator(),
            languageItem,
            launchAtLoginItem,
            .separator(),
            checkForUpdatesItem,
            automaticUpdatesItem,
            .separator(),
            quitItem,
        ]
        return menu
    }

    private func submenu(_ items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.items = items
        return menu
    }

    private func makeDesktopWidgetMenu() -> NSMenu {
        widgetSizeItems = WidgetSize.allCases.map { size in
            let item = NSMenuItem(title: "", action: #selector(selectWidgetSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            return item
        }
        return submenu([showWidgetToggle.item, .separator()] + widgetSizeItems + [.separator(), widgetEnglishToggle.item])
    }

    private func makeLanguageMenu() -> NSMenu {
        followSystemLanguageItem.target = self
        let languageItems = Language.allCases.map { language in
            let item = NSMenuItem(title: language.nativeName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            return item
        }
        return submenu([followSystemLanguageItem, .separator()] + languageItems)
    }

    /// 每次打开菜单时按当前语言和设置刷新文字与勾选状态。
    func menuWillOpen(_ menu: NSMenu) {
        let strings = strings
        let timeZone = settings.timeZone
        let offset = TimeZoneCatalog.gmtOffset(of: timeZone, at: Date())
        let source = settings.timeZoneIdentifier == nil ? strings.followingSystemPrefix : ""
        timeZoneHeaderItem.title = "\(source)\(timeZone.identifier) · \(offset)"

        timeZoneItem.title = strings.timeZone
        styleItem.title = strings.styleMenu
        desktopWidgetItem.title = strings.desktopWidgetMenu
        languageItem.title = strings.languageMenu
        launchAtLoginItem.title = strings.launchAtLogin
        quitItem.title = strings.quit
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        checkForUpdatesItem.title = updater.isBusy ? strings.checkingForUpdates : strings.checkForUpdates
        automaticUpdatesItem.title = strings.checkAutomatically
        automaticUpdatesItem.state = updater.checksAutomatically ? .on : .off

        for toggle in toggles {
            toggle.item.title = toggle.title(strings)
            toggle.item.state = settings[keyPath: toggle.keyPath] ? .on : .off
        }

        for item in widgetSizeItems {
            guard let size = (item.representedObject as? String).flatMap(WidgetSize.init(rawValue:)) else { continue }
            item.title = strings.widgetSize(size)
            item.state = size == settings.widgetSize ? .on : .off
        }

        followSystemLanguageItem.title = strings.followSystemLanguage
        let preference = settings.languagePreference?.rawValue
        for item in languageItem.submenu?.items ?? [] where !item.isSeparatorItem {
            item.state = item.representedObject as? String == preference ? .on : .off
        }
    }

    @objc private func toggleSetting(_ sender: NSMenuItem) {
        guard let keyPath = sender.representedObject as? ReferenceWritableKeyPath<DisplaySettings, Bool> else { return }
        settings[keyPath: keyPath].toggle()
        displaySettingsDidChange()
    }

    @objc private func selectWidgetSize(_ sender: NSMenuItem) {
        guard let size = (sender.representedObject as? String).flatMap(WidgetSize.init(rawValue:)) else { return }
        settings.widgetSize = size
        displaySettingsDidChange()
    }

    /// 跟随系统那一项没有 representedObject，对应 `nil`。
    @objc private func selectLanguage(_ sender: NSMenuItem) {
        settings.languagePreference = (sender.representedObject as? String).flatMap(Language.init(rawValue:))
        displaySettingsDidChange()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates(userInitiated: true)
    }

    @objc private func toggleAutomaticUpdates() {
        updater.checksAutomatically.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let strings = strings
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            showAlert(title: strings.launchAtLoginFailed, message: error.localizedDescription)
            return
        }

        if LaunchAtLogin.requiresApproval {
            let openSettings = showAlert(
                title: strings.approvalNeeded,
                message: strings.approvalMessage,
                confirmTitle: strings.openSystemSettings
            )
            if openSettings {
                LaunchAtLogin.openSystemSettings()
            }
        }
    }

    /// 弹出提示；有确认按钮时返回用户是否点了它。
    @discardableResult
    private func showAlert(title: String, message: String, confirmTitle: String? = nil) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        if let confirmTitle {
            alert.addButton(withTitle: confirmTitle)
            alert.addButton(withTitle: strings.cancel)
        }
        return alert.runModal() == .alertFirstButtonReturn && confirmTitle != nil
    }
}
