import AppKit
import DaylineCore

/// 从 GitHub Releases 检查并安装更新。
///
/// 只在用户点“检查更新”或打开了“自动检查更新”时联网。下载的更新包必须带有与内置公钥匹配的
/// Ed25519 签名，校验通过后才替换当前 App 并重启。
@MainActor
final class Updater {
    private static let feedURL = URL(string: "https://api.github.com/repos/fancyecho/Dayline/releases/latest")!
    /// 与 ~/.config/dayline/update-signing-key 配对的公钥，见 scripts/sign-update.swift。
    private static let publicKey = "TirAWx5JtHW78n9BP/vamwHpIdAaBjMWoJiWUTZmUgs="
    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    private enum Key {
        static let checksAutomatically = "updates.checksAutomatically"
        static let lastCheck = "updates.lastCheck"
        /// 仅供测试：指向本地模拟的 Release 接口。签名校验照常进行。
        static let feedOverride = "updates.feedURL"
    }

    enum UpdateError: Error {
        case badResponse
        case missingAssets
        case invalidSignature
        case unexpectedBundle
        case notReplaceable
        case extractionFailed
    }

    private let defaults = UserDefaults.standard
    private let strings: () -> Strings
    private var timer: Timer?
    private(set) var isBusy = false

    init(strings: @escaping () -> Strings) {
        self.strings = strings
    }

    static var currentVersion: AppVersion {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            .flatMap(AppVersion.init) ?? AppVersion("0")!
    }

    var checksAutomatically: Bool {
        get { defaults.bool(forKey: Key.checksAutomatically) }
        set {
            defaults.set(newValue, forKey: Key.checksAutomatically)
            scheduleAutomaticChecks()
        }
    }

    /// 打开自动检查时，距上次检查满一天就检查一次；之后每天一次。
    func scheduleAutomaticChecks() {
        timer?.invalidate()
        timer = nil
        guard checksAutomatically else { return }

        let lastCheck = defaults.object(forKey: Key.lastCheck) as? Date ?? .distantPast
        let firstCheck = max(lastCheck.addingTimeInterval(Self.automaticCheckInterval), Date().addingTimeInterval(30))
        let timer = Timer(fire: firstCheck, interval: Self.automaticCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForUpdates(userInitiated: false) }
        }
        timer.tolerance = 60 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func checkForUpdates(userInitiated: Bool) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await check(userInitiated: userInitiated)
            } catch where userInitiated {
                showFailure(error, pageURL: nil)
            } catch {
                // 自动检查失败（如离线）时不打扰用户，下次再试。
            }
        }
    }

    // MARK: - Steps

    private func check(userInitiated: Bool) async throws {
        let release = try await fetchLatestRelease()
        defaults.set(Date(), forKey: Key.lastCheck)
        let strings = strings()
        let current = Self.currentVersion

        guard let version = release.version, version > current else {
            if userInitiated {
                alert(title: strings.upToDate, message: strings.upToDateMessage(current.description), buttons: [])
            }
            return
        }

        let notes = (release.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let message = strings.updateAvailableMessage(current: current.description)
            + (notes.isEmpty ? "" : "\n\n" + String(notes.prefix(600)))
        let choice = alert(
            title: strings.updateAvailable(version.description),
            message: message,
            buttons: [strings.installAndRelaunch, strings.viewReleasePage, strings.later]
        )
        switch choice {
        case .alertFirstButtonReturn:
            do {
                try await install(release, version: version)
            } catch {
                showFailure(error, pageURL: release.pageURL)
            }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(release.pageURL)
        default:
            break
        }
    }

    private func fetchLatestRelease() async throws -> UpdateRelease {
        let url = defaults.string(forKey: Key.feedOverride).flatMap(URL.init(string:)) ?? Self.feedURL
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Dayline/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
        return try JSONDecoder().decode(UpdateRelease.self, from: data)
    }

    private func install(_ release: UpdateRelease, version: AppVersion) async throws {
        let appURL = Bundle.main.bundleURL
        // 从“下载”里直接打开的 App 会被系统隔离到只读的临时位置，无法原地替换。
        guard !appURL.path.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path)
        else { throw UpdateError.notReplaceable }

        guard let archiveURL = release.archiveURL, let signatureURL = release.signatureURL else {
            throw UpdateError.missingAssets
        }
        let archive = try await download(archiveURL)
        let signatureFile = try await download(signatureURL)
        guard let signature = UpdateSignature.decode(signatureFile: signatureFile),
              UpdateSignature.isValid(signature: signature, for: archive, publicKeyBase64: Self.publicKey)
        else { throw UpdateError.invalidSignature }

        // 解压到与当前 App 同一卷上的临时目录，替换才能是一次原子的改名。
        let workURL = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: appURL,
            create: true
        )
        defer { try? FileManager.default.removeItem(at: workURL) }

        let archiveFile = workURL.appendingPathComponent(UpdateRelease.archiveName)
        try archive.write(to: archiveFile)
        try await Self.run("/usr/bin/ditto", ["-x", "-k", archiveFile.path, workURL.path])

        let newAppURL = workURL.appendingPathComponent("Dayline.app")
        guard let newBundle = Bundle(url: newAppURL),
              newBundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              (newBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
                .flatMap(AppVersion.init) == version
        else { throw UpdateError.unexpectedBundle }

        _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newAppURL)
        relaunch(appURL)
    }

    private func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
        return data
    }

    /// 等当前进程退出后重新打开新版本。
    private func relaunch(_ appURL: URL) {
        let script = "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), appURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    private nonisolated static func run(_ tool: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError.extractionFailed)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Alerts

    private func showFailure(_ error: Error, pageURL: URL?) {
        let strings = strings()
        let buttons = pageURL == nil ? [] : [strings.viewReleasePage, strings.cancel]
        let reason = (error as? UpdateError).map(strings.updateErrorReason) ?? error.localizedDescription
        let response = alert(
            title: strings.updateFailed,
            message: reason + "\n\n" + strings.updateFailedHint,
            buttons: buttons
        )
        if response == .alertFirstButtonReturn, let pageURL {
            NSWorkspace.shared.open(pageURL)
        }
    }

    @discardableResult
    private func alert(title: String, message: String, buttons: [String]) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        return alert.runModal()
    }
}
