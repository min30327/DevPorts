import AppKit
import Foundation
import ServiceManagement

@MainActor
final class PortMonitor: ObservableObject {
    @Published private(set) var servers: [DevServer] = []
    @Published private(set) var stopping: Set<Int32> = []
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    @Published var portRangesText: String {
        didSet { UserDefaults.standard.set(portRangesText, forKey: Keys.ranges); refresh() }
    }
    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Keys.interval); restartLoop() }
    }
    @Published var hideSystemProcesses: Bool {
        didSet { UserDefaults.standard.set(hideSystemProcesses, forKey: Keys.hideSystem); refresh() }
    }

    private enum Keys {
        static let ranges = "portRanges"
        static let interval = "refreshInterval"
        static let hideSystem = "hideSystemProcesses"
    }

    private var loopTask: Task<Void, Never>?
    private var scanning = false

    init() {
        let d = UserDefaults.standard
        portRangesText = d.string(forKey: Keys.ranges) ?? PortRanges.defaultText
        refreshInterval = d.object(forKey: Keys.interval) as? Double ?? 3
        hideSystemProcesses = d.object(forKey: Keys.hideSystem) as? Bool ?? true
        restartLoop()
    }

    // MARK: - スキャン

    private func restartLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                let interval = self?.refreshInterval ?? 3
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func refresh() {
        guard !scanning else { return }
        scanning = true
        let options = PortScanner.Options(
            ranges: PortRanges.parse(portRangesText),
            hideSystemProcesses: hideSystemProcesses
        )
        Task.detached(priority: .utility) {
            let result = PortScanner.scan(options)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.servers != result { self.servers = result }
                self.stopping.formIntersection(result.map(\.pid))
                self.lastUpdated = Date()
                self.scanning = false
            }
        }
    }

    // MARK: - 停止

    /// SIGTERM を送り、3 秒以内に終了しなければ SIGKILL する
    func stop(_ server: DevServer, force: Bool = false) {
        let pid = server.pid
        stopping.insert(pid)
        if kill(pid, force ? SIGKILL : SIGTERM) != 0 {
            stopping.remove(pid)
            errorMessage = "PID \(pid) を停止できませんでした（\(String(cString: strerror(errno)))）"
            return
        }
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(100))
                if kill(pid, 0) != 0 { break }
            }
            if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
            try? await Task.sleep(for: .milliseconds(200))
            refresh()
        }
    }

    func stopAll() {
        servers.forEach { stop($0) }
    }

    // MARK: - アクション

    func open(_ server: DevServer, port: Int? = nil) {
        let p = port ?? server.primaryPort
        if let url = URL(string: "http://localhost:\(p)") { NSWorkspace.shared.open(url) }
    }

    func revealInFinder(_ server: DevServer) {
        guard let cwd = server.cwd else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cwd)
    }

    func openInTerminal(_ server: DevServer) {
        guard let cwd = server.cwd,
              let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
        else { return }
        NSWorkspace.shared.open([URL(fileURLWithPath: cwd)], withApplicationAt: terminal,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - ログイン時に起動

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                errorMessage = "ログイン項目の設定に失敗しました: \(error.localizedDescription)"
            }
            objectWillChange.send()
        }
    }
}
