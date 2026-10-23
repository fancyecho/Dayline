import Foundation

/// 在每个整分钟触发一次回调。
///
/// 每次只排一个单次定时器并对齐到下一个整分钟，而不是用 60 秒重复定时器：
/// 重复定时器按开机时长计时，睡眠和校时之后会与墙上时间错开。
@MainActor
final class MinuteTicker {
    private let onTick: () -> Void
    private var timer: Timer?

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    func start() {
        timer?.invalidate()
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        let now = Date().timeIntervalSince1970
        let nextMinute = Date(timeIntervalSince1970: (now / 60).rounded(.down) * 60 + 60)

        let timer = Timer(fire: nextMinute, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onTick()
                self?.scheduleNextTick()
            }
        }
        // 允许系统把唤醒合并到 0.25 秒内，省电且肉眼看不出延迟。
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
