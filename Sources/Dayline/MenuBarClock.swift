import AppKit
import DaylineCore
import SwiftUI

/// 菜单栏时间的样式开关，可以任意组合。
struct MenuBarStyle: Equatable {
    var emphasizesTime = false
    var usesWideTracking = false
    var rollsDigits = false
}

@MainActor
@Observable
final class MenuBarClockModel {
    var parts = ClockFormatter.Parts(leading: nil, time: "")
    var style = MenuBarStyle()
}

/// 状态栏项：文字由 SwiftUI 绘制，这样分钟变化时数字可以滚动。
@MainActor
final class MenuBarClock {
    private static let horizontalPadding: CGFloat = 8

    let statusItem: NSStatusItem
    private let model = MenuBarClockModel()
    private let hostingView: ClickThroughHostingView<MenuBarClockView>

    init(menu: NSMenu) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu

        hostingView = ClickThroughHostingView(rootView: MenuBarClockView(
            model: model,
            fontSize: NSFont.menuBarFont(ofSize: 0).pointSize
        ))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        guard let button = statusItem.button else { return }
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
    }

    /// `animated` 为真时，变化的数字向上滚动；样式切换等其他更新直接替换。
    func update(parts: ClockFormatter.Parts, style: MenuBarStyle, animated: Bool) {
        guard parts != model.parts || style != model.style else { return }

        if animated && style.rollsDigits && !model.parts.time.isEmpty {
            withAnimation(.smooth(duration: 0.45)) { model.parts = parts }
        } else {
            model.parts = parts
        }
        model.style = style

        statusItem.button?.setAccessibilityTitle(parts.joined)
        statusItem.length = ceil(hostingView.fittingSize.width) + Self.horizontalPadding
    }
}

struct MenuBarClockView: View {
    let model: MenuBarClockModel
    let fontSize: CGFloat

    var body: some View {
        let style = model.style
        let tracking: CGFloat = style.usesWideTracking ? fontSize * 0.1 : 0

        HStack(spacing: fontSize * 0.3 + tracking) {
            if let leading = model.parts.leading {
                Text(style.usesWideTracking ? leading.uppercased() : leading)
                    .fontWeight(style.usesWideTracking ? .light : .regular)
                    .foregroundStyle(style.emphasizesTime ? .secondary : .primary)
            }
            Text(model.parts.time)
                .fontWeight(timeWeight(for: style))
                .contentTransition(style.rollsDigits ? .numericText() : .identity)
        }
        .font(.system(size: fontSize).monospacedDigit())
        .tracking(tracking)
        .lineLimit(1)
        .fixedSize()
    }

    private func timeWeight(for style: MenuBarStyle) -> Font.Weight {
        if style.emphasizesTime { return .semibold }
        return style.usesWideTracking ? .medium : .regular
    }
}

/// 只负责显示，点击交给下面的状态栏按钮处理。
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
