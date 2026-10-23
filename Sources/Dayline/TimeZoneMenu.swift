import AppKit
import DaylineCore

/// “时区”子菜单：跟随系统、常用时区，以及按地区分组的全部时区。
/// 菜单内容在每次打开时才生成，平时不占内存。
@MainActor
final class TimeZoneMenu: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let settings: DisplaySettings
    private let onChange: () -> Void
    private lazy var regions = TimeZoneCatalog.regions()

    init(settings: DisplaySettings, onChange: @escaping () -> Void) {
        self.settings = settings
        self.onChange = onChange
        super.init()
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === self.menu {
            rebuildRootMenu()
        } else if let region = regions.first(where: { $0.name == menu.title }) {
            let now = Date()
            menu.items = region.identifiers.map { identifier in
                let label = identifier.hasPrefix(region.name + "/")
                    ? String(identifier.dropFirst(region.name.count + 1))
                    : identifier
                return item(for: identifier, label: label, at: now)
            }
        }
    }

    private func rebuildRootMenu() {
        let now = Date()
        let selected = settings.timeZoneIdentifier
        let strings = Strings(language: settings.language)

        let followSystem = NSMenuItem(title: "", action: #selector(selectSystemTimeZone), keyEquivalent: "")
        followSystem.target = self
        followSystem.state = selected == nil ? .on : .off
        followSystem.attributedTitle = Self.title(
            strings.followSystemTimeZone(TimeZone.current.identifier),
            detail: TimeZoneCatalog.gmtOffset(of: .current, at: now)
        )

        var quickPicks = TimeZoneCatalog.common
        if let selected, !quickPicks.contains(selected) {
            quickPicks.insert(selected, at: 0)
        }

        let allZones = NSMenuItem(title: strings.allTimeZones, action: nil, keyEquivalent: "")
        let allZonesMenu = NSMenu()
        allZonesMenu.items = regions.map { region in
            let label = region.name == TimeZoneCatalog.otherRegionName ? strings.otherRegion : region.name
            let regionItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            // 子菜单标题只用来在 menuNeedsUpdate 里认出是哪个地区，不会显示出来。
            let regionMenu = NSMenu(title: region.name)
            regionMenu.delegate = self
            regionItem.submenu = regionMenu
            return regionItem
        }
        allZones.submenu = allZonesMenu

        menu.items = [followSystem, .separator()]
            + quickPicks.map { item(for: $0, label: $0, at: now) }
            + [.separator(), allZones]
    }

    private func item(for identifier: String, label: String, at date: Date) -> NSMenuItem {
        let item = NSMenuItem(title: label, action: #selector(selectTimeZone(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = identifier
        item.state = settings.timeZoneIdentifier == identifier ? .on : .off
        if let timeZone = TimeZone(identifier: identifier) {
            item.attributedTitle = Self.title(label, detail: TimeZoneCatalog.gmtOffset(of: timeZone, at: date))
        }
        return item
    }

    @objc private func selectSystemTimeZone() {
        settings.timeZoneIdentifier = nil
        onChange()
    }

    @objc private func selectTimeZone(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        settings.timeZoneIdentifier = identifier
        onChange()
    }

    /// 左侧名称、右侧灰色 UTC 偏移的菜单标题。
    private static func title(_ label: String, detail: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
        let font = NSFont.menuFont(ofSize: 0)

        let title = NSMutableAttributedString(
            string: label + "\t",
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        title.append(NSAttributedString(
            string: detail,
            attributes: [.font: font, .paragraphStyle: paragraph, .foregroundColor: NSColor.secondaryLabelColor]
        ))
        return title
    }
}
