import AppKit
import DaylineCore
import SwiftUI

@MainActor
@Observable
final class DesktopWidgetModel {
    var parts = WidgetClockFormatter.Parts(weekday: "", date: "", time: "")
    var size = WidgetSize.medium
    var rollsDigits = false
}

/// 屏幕中央的透明桌面时钟：位于壁纸之上、桌面图标之下，鼠标点击直接穿透，在所有桌面空间显示。
/// 关闭时整个窗口释放，不占资源。
@MainActor
final class DesktopWidget {
    private let model = DesktopWidgetModel()
    private var window: NSWindow?
    private var hostingView: NSHostingView<DesktopWidgetView>?

    var isVisible: Bool { window != nil }

    func show() {
        guard window == nil else { return }

        let hostingView = NSHostingView(rootView: DesktopWidgetView(model: model))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = hostingView

        self.window = window
        self.hostingView = hostingView
        recenter()
        window.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }

    func update(parts: WidgetClockFormatter.Parts, size: WidgetSize, rollsDigits: Bool, animated: Bool) {
        let sizeChanged = size != model.size
        guard parts != model.parts || sizeChanged || rollsDigits != model.rollsDigits else { return }

        if animated && rollsDigits && !model.parts.time.isEmpty {
            withAnimation(.smooth(duration: 0.6)) { model.parts = parts }
        } else {
            model.parts = parts
        }
        model.size = size
        model.rollsDigits = rollsDigits
        recenter()
    }

    /// 放在主屏幕（带菜单栏的那块）正中间。屏幕变化和内容尺寸变化后都要调用。
    func recenter() {
        guard let window, let hostingView, let screen = NSScreen.screens.first else { return }
        let size = hostingView.fittingSize
        let frame = screen.frame
        window.setFrame(
            NSRect(
                x: (frame.midX - size.width / 2).rounded(),
                y: (frame.midY - size.height / 2).rounded(),
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }
}

struct DesktopWidgetView: View {
    let model: DesktopWidgetModel

    var body: some View {
        let scale = model.size.weekdayPointSize
        let weekdayTracking = scale * 0.36
        let detailSize = scale * 0.26

        VStack(spacing: -scale * 0.04) {
            Text(model.parts.weekday)
                .font(WidgetFont.weekday(size: scale))
                .tracking(weekdayTracking)
                // 字距会加在最后一个字后面，左边补同样的距离，视觉上才居中。
                .padding(.leading, weekdayTracking)

            VStack(spacing: detailSize * 0.2) {
                Text(model.parts.date)
                    .font(WidgetFont.detail(size: detailSize))
                    .tracking(detailSize * 0.12)
                    .padding(.leading, detailSize * 0.12)
                Text("-\(model.parts.time)-")
                    .font(WidgetFont.detail(size: detailSize * 0.85).monospacedDigit())
                    .tracking(detailSize * 0.08)
                    .padding(.leading, detailSize * 0.08)
                    .contentTransition(model.rollsDigits ? .numericText() : .identity)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.22), radius: scale * 0.03, y: 1)
        .lineLimit(1)
        .fixedSize()
        .padding(scale * 0.25)
    }
}

/// 星期优先用 Anurati（参考图里的字体，需自行安装），没有时用系统自带的 Avenir Next。
private enum WidgetFont {
    static func weekday(size: CGFloat) -> Font {
        firstInstalled(["Anurati-Regular", "Anurati", "AvenirNext-Regular"], size: size)
            ?? .system(size: size, weight: .regular)
    }

    static func detail(size: CGFloat) -> Font {
        firstInstalled(["AvenirNext-Medium"], size: size) ?? .system(size: size, weight: .medium)
    }

    private static func firstInstalled(_ names: [String], size: CGFloat) -> Font? {
        names.first { NSFont(name: $0, size: size) != nil }.map { .custom($0, fixedSize: size) }
    }
}

extension WidgetSize {
    var weekdayPointSize: CGFloat {
        switch self {
        case .small: 56
        case .medium: 88
        case .large: 128
        }
    }
}
