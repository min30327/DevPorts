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
        // デバッグ用: `DevPorts --snapshot out.png` でポップオーバーの内容を PNG に書き出して終了
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            MainActor.assumeIsolated { Self.snapshot(to: CommandLine.arguments[i + 1]) }
            exit(0)
        }
    }

    @MainActor
    private static func snapshot(to path: String) {
        let monitor = PortMonitor()
        let deadline = Date().addingTimeInterval(5)
        while monitor.lastUpdated == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let renderer = ImageRenderer(content: ContentView().environmentObject(monitor)
            .background(Color(nsColor: .windowBackgroundColor)))
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { print("render failed"); return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
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
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        monitor.$menuBarSymbol
            .removeDuplicates()
            .sink { [weak self] name in
                let image = NSImage(systemSymbolName: name, accessibilityDescription: "DevPorts")
                    ?? NSImage(systemSymbolName: "server.rack", accessibilityDescription: "DevPorts")
                image?.isTemplate = true
                self?.statusItem.button?.image = image
            }
            .store(in: &cancellables)

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
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
                // 最初のボタンにキーボードフォーカスが当たらないようにする
                window.makeFirstResponder(nil)
            }
            NSApp.activate()
        }
    }
}
