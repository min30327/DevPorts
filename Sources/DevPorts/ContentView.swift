import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: PortMonitor
    @State private var showSettings = false
    @State private var confirmStopAll = false
    private let maxVisibleRows = 7

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showSettings {
                SettingsPanel()
                Divider()
            }
            if let error = monitor.errorMessage {
                errorBanner(error)
            }
            serverList
            Divider()
            footer
        }
        .frame(width: 480)
        // 内容の理想の高さを NSPopover のサイズとして伝える
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .foregroundStyle(.secondary)
            Text("Dev Ports")
                .font(.system(size: 15, weight: .semibold))
            Text("\(monitor.servers.count)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            Spacer()
            IconButton(systemName: "arrow.clockwise", help: "今すぐ更新") { monitor.refresh() }
            IconButton(systemName: showSettings ? "gearshape.fill" : "gearshape", help: "設定") {
                showSettings.toggle()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Spacer()
            IconButton(systemName: "xmark", help: "閉じる") { monitor.errorMessage = nil }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - List

    @ViewBuilder
    private var serverList: some View {
        if monitor.servers.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("起動中の開発サーバーはありません")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("監視中: \(monitor.portRangesText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            let rows = VStack(spacing: 2) {
                ForEach(monitor.servers) { server in
                    ServerRow(server: server, isStopping: monitor.stopping.contains(server.pid))
                }
            }
            .padding(6)

            // 高さを確定させるため、件数が多いときだけ固定高さのスクロールにする
            if monitor.servers.count <= maxVisibleRows {
                rows
            } else {
                ScrollView { rows }
                    .frame(height: CGFloat(maxVisibleRows) * 74)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !monitor.servers.isEmpty {
                Button(role: .destructive) {
                    if confirmStopAll {
                        monitor.stopAll()
                        confirmStopAll = false
                    } else {
                        confirmStopAll = true
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            confirmStopAll = false
                        }
                    }
                } label: {
                    Label(confirmStopAll ? "もう一度クリックで全停止" : "すべて停止",
                          systemImage: "stop.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(confirmStopAll ? .red : .secondary)
            }
            Spacer()
            if let updated = monitor.lastUpdated {
                Text(updated, format: .dateTime.hour().minute().second())
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Button("終了") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Row

struct ServerRow: View {
    @EnvironmentObject var monitor: PortMonitor
    let server: DevServer
    let isStopping: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            FrameworkBadge(framework: server.framework)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(server.projectName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(server.framework.displayName + (server.mode.map { " · \($0)" } ?? ""))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    ForEach(server.ports, id: \.self) { port in
                        Button {
                            monitor.open(server, port: port)
                        } label: {
                            Text(":\(String(port))")
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(server.framework.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(server.framework.color == .primary ? Color.primary : server.framework.color)
                        }
                        .buttonStyle(.plain)
                        .help("http://localhost:\(String(port)) を開く")
                    }
                    Text("PID \(String(server.pid))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    if !server.elapsedText.isEmpty {
                        Text("· \(server.elapsedText)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                if let path = server.displayPath {
                    Text(path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(server.command)
                }
            }
            Spacer(minLength: 4)

            HStack(spacing: 2) {
                IconButton(systemName: "safari", help: "ブラウザで開く") { monitor.open(server) }
                IconButton(systemName: "folder", help: "Finder で表示") { monitor.revealInFinder(server) }
                    .disabled(server.cwd == nil)
                if isStopping {
                    ProgressView().controlSize(.small).frame(width: 26, height: 26)
                } else {
                    IconButton(systemName: "stop.circle.fill", help: "停止 (SIGTERM)", tint: .red) {
                        monitor.stop(server)
                    }
                }
            }
            .opacity(hovering || isStopping ? 1 : 0.55)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(hovering ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .opacity(isStopping ? 0.5 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("ブラウザで開く") { monitor.open(server) }
            Button("URL をコピー") { monitor.copy(server.url.absoluteString) }
            Divider()
            Button("Finder で表示") { monitor.revealInFinder(server) }.disabled(server.cwd == nil)
            Button("ターミナルで開く") { monitor.openInTerminal(server) }.disabled(server.cwd == nil)
            Button("パスをコピー") { monitor.copy(server.cwd ?? "") }.disabled(server.cwd == nil)
            Button("コマンドをコピー") { monitor.copy(server.command) }
            Button("PID をコピー") { monitor.copy(String(server.pid)) }
            Divider()
            Button("停止 (SIGTERM)") { monitor.stop(server) }
            Button("強制終了 (SIGKILL)") { monitor.stop(server, force: true) }
        }
    }
}

struct FrameworkBadge: View {
    let framework: Framework

    var body: some View {
        Text(framework.badge)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(framework.color == .primary ? Color.primary : framework.color)
            .frame(width: 34, height: 34)
            .background(framework.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(framework.color.opacity(0.3), lineWidth: 1))
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    var tint: Color = .secondary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(hovering ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

// MARK: - Settings

struct SettingsPanel: View {
    @EnvironmentObject var monitor: PortMonitor
    @State private var rangesDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("監視するポート").font(.system(size: 12)).foregroundStyle(.secondary)
                HStack {
                    TextField("3000-3999, 5173", text: $rangesDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(apply)
                    Button("適用", action: apply)
                        .disabled(rangesDraft == monitor.portRangesText)
                }
                Text("カンマ区切りで範囲（3000-3999）や単体（5173）を指定")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }

            HStack {
                Text("更新間隔").font(.system(size: 12)).foregroundStyle(.secondary)
                Picker("", selection: $monitor.refreshInterval) {
                    Text("1秒").tag(1.0)
                    Text("3秒").tag(3.0)
                    Text("5秒").tag(5.0)
                    Text("10秒").tag(10.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            Toggle("macOS のシステムプロセスを隠す", isOn: $monitor.hideSystemProcesses)
                .font(.system(size: 12))
            Toggle("ログイン時に起動", isOn: Binding(
                get: { monitor.launchAtLogin },
                set: { monitor.launchAtLogin = $0 }
            ))
            .font(.system(size: 12))
        }
        .toggleStyle(.switch)
        .controlSize(.regular)
        .padding(12)
        .background(.quaternary.opacity(0.4))
        .onAppear { rangesDraft = monitor.portRangesText }
    }

    private func apply() {
        guard !PortRanges.parse(rangesDraft).isEmpty else {
            monitor.errorMessage = "ポートの指定が正しくありません"
            return
        }
        monitor.portRangesText = rangesDraft
    }
}
