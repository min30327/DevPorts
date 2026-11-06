import AppKit
import Combine
import SwiftUI

@main
struct DevPortsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // デバッグ用: `DevPorts --dump` で検出結果を標準出力に出して終了
        if CommandLine.arguments.contains("--dump") {
            let text = UserDefaults.standard.string(forKey: "portRanges") ?? PortRanges.defaultText
            let servers = PortScanner.scan(.init(ranges: PortRanges.parse(text), hideSystemProcesses: true))
            for s in servers {
                let ports = s.ports.map(String.init).joined(separator: ",")
                print("\(ports)\t\(s.framework.displayName)\t\(s.mode ?? "-")\t\(s.projectName)\tPID \(s.pid)\t\(s.elapsedText)\t\(s.displayPath ?? "-")")
            }
            exit(0)
        }
    }

    var body: some Scene {
        // UI はすべて AppDelegate の NSStatusItem / NSPopover で表示する
        Settings { EmptyView() }
    }
}

/// メニューバーのアイコンと NSPopover を管理する。
/// MenuBarExtra(.window) は内容の高さ変化に追従しないため、
/// sizingOptions = .preferredContentSize の NSHostingController を NSPopover で表示している。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = PortMonitor()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let hosting = NSHostingController(rootView: ContentView().environmentObject(monitor))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Dev Ports")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        monitor.$servers
            .map(\.count)
            .removeDuplicates()
            .sink { [weak self] count in
                self?.statusItem.button?.title = count > 0 ? " \(count)" : ""
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            monitor.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate()
        }
    }
}
